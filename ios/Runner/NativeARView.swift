import ARKit
import Flutter
import SceneKit
import UIKit
import simd

final class UnimetARViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    UnimetARPlatformView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class UnimetARPlatformView: NSObject, FlutterPlatformView {
  private enum ViewMode {
    case qr
    case navigation
  }

  private let sceneView: ARSCNView
  private let channel: FlutterMethodChannel
  private let routeRoot = SCNNode()
  private let mode: ViewMode
  private let markerId: String
  private let markerPhysicalWidth: CGFloat
  private let markerCenterHeight: Float
  private let routeLength: Float
  private var detectedAnchorId: UUID?
  private var lastTrackingMessage = ""
  private var arrowNodes: [SCNNode] = []
  private var destinationNode: SCNNode?
  private var navigationTargetBearing: Float
  private var navigationDistance: Float
  private var detectedFloorY: Float?
  private var bestFloorScore = Float.greatestFiniteMagnitude
  private var floorEventSent = false
  private var lastHeadingEmission: TimeInterval = 0
  private var lastRouteOrigin: SIMD3<Float>?

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    let parameters = args as? [String: Any]
    mode = parameters?["mode"] as? String == "navigation" ? .navigation : .qr
    markerId = parameters?["markerId"] as? String ?? "CASA-QR-001"
    markerPhysicalWidth = CGFloat(parameters?["physicalWidth"] as? Double ?? 0.20)
    markerCenterHeight = Float(parameters?["markerCenterHeight"] as? Double ?? 1.50)
    routeLength = Float(parameters?["routeLength"] as? Double ?? 3.0)
    navigationTargetBearing = Float(parameters?["targetBearing"] as? Double ?? 0)
    navigationDistance = Float(parameters?["distance"] as? Double ?? 3.0)
    sceneView = ARSCNView(frame: frame)
    channel = FlutterMethodChannel(
      name: "unimet_ar/arkit_view_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    configureSceneView()
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "reset":
        self?.startSession(reset: true)
        result(nil)
      case "stop":
        self?.sceneView.session.pause()
        self?.routeRoot.isHidden = true
        result(nil)
      case "updateNavigation":
        self?.updateNavigation(call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    DispatchQueue.main.async { [weak self] in
      self?.startSession(reset: true)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
    sceneView.session.pause()
  }

  func view() -> UIView {
    sceneView
  }

  private func configureSceneView() {
    sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    sceneView.delegate = self
    sceneView.session.delegate = self
    sceneView.automaticallyUpdatesLighting = true
    sceneView.antialiasingMode = .multisampling4X
    sceneView.scene.rootNode.addChildNode(routeRoot)

    let coaching = ARCoachingOverlayView()
    coaching.session = sceneView.session
    coaching.goal = mode == .navigation ? .horizontalPlane : .tracking
    coaching.activatesAutomatically = true
    coaching.translatesAutoresizingMaskIntoConstraints = false
    sceneView.addSubview(coaching)
    NSLayoutConstraint.activate([
      coaching.topAnchor.constraint(equalTo: sceneView.topAnchor),
      coaching.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor),
      coaching.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor),
      coaching.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor),
    ])
  }

  private func startSession(reset: Bool) {
    guard ARWorldTrackingConfiguration.isSupported else {
      emit("error", ["message": "Este iPhone no es compatible con ARKit World Tracking."])
      return
    }
    detectedAnchorId = nil
    lastTrackingMessage = ""
    lastHeadingEmission = 0
    routeRoot.isHidden = false
    routeRoot.childNodes.forEach { $0.removeFromParentNode() }
    arrowNodes = []
    destinationNode = nil
    detectedFloorY = nil
    bestFloorScore = Float.greatestFiniteMagnitude
    floorEventSent = false
    lastRouteOrigin = nil

    let configuration = ARWorldTrackingConfiguration()
    if mode == .navigation {
      configuration.worldAlignment = .gravityAndHeading
      configuration.planeDetection = [.horizontal]
    } else {
      guard
        let markerImage = UIImage(named: "TestARMarker"),
        let markerCGImage = markerImage.cgImage
      else {
        emit("error", ["message": "No se encontro el marcador QR incluido en la app."])
        return
      }
      let referenceImage = ARReferenceImage(
        markerCGImage,
        orientation: .up,
        physicalWidth: markerPhysicalWidth
      )
      referenceImage.name = markerId
      configuration.worldAlignment = .gravity
      configuration.planeDetection = [.horizontal, .vertical]
      configuration.detectionImages = [referenceImage]
      configuration.maximumNumberOfTrackedImages = 1
    }
    if #available(iOS 12.0, *) {
      configuration.environmentTexturing = .automatic
    }

    var options: ARSession.RunOptions = []
    if reset {
      options = [.resetTracking, .removeExistingAnchors]
    }
    sceneView.session.run(configuration, options: options)
    emit("arReady", [
      "mode": mode == .navigation ? "navigation" : "qr",
      "markerId": markerId,
    ])
  }

  private func updateNavigation(_ arguments: Any?) {
    guard mode == .navigation else { return }
    let values = arguments as? [String: Any]
    let nextBearing = Float(values?["targetBearing"] as? Double ?? Double(navigationTargetBearing))
    let nextDistance = Float(values?["distance"] as? Double ?? Double(navigationDistance))
    let bearingChange = abs(shortestAngle(nextBearing - navigationTargetBearing))
    let distanceChange = abs(nextDistance - navigationDistance)
    navigationTargetBearing = normalizedDegrees(nextBearing)
    navigationDistance = max(0, nextDistance)
    if bearingChange >= 2 || distanceChange >= 0.5 || arrowNodes.isEmpty {
      buildNavigationRoute()
    }
  }

  private func addMarkerConfirmation(
    to node: SCNNode,
    referenceImage: ARReferenceImage
  ) {
    let plane = SCNPlane(
      width: referenceImage.physicalSize.width,
      height: referenceImage.physicalSize.height
    )
    plane.cornerRadius = 0.012
    plane.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.28)
    plane.firstMaterial?.emission.contents = UIColor.systemGreen.withAlphaComponent(0.12)
    plane.firstMaterial?.isDoubleSided = true

    let planeNode = SCNNode(geometry: plane)
    planeNode.eulerAngles.x = -.pi / 2
    planeNode.position.y = 0.003
    node.addChildNode(planeNode)
  }

  private func buildRoute(using markerTransform: simd_float4x4) {
    let markerPosition = SIMD3<Float>(
      markerTransform.columns.3.x,
      markerTransform.columns.3.y,
      markerTransform.columns.3.z
    )
    var routeDirection = SIMD3<Float>(
      markerTransform.columns.0.x,
      0,
      markerTransform.columns.0.z
    )
    if simd_length(routeDirection) < 0.001 {
      routeDirection = SIMD3<Float>(1, 0, 0)
    } else {
      routeDirection = simd_normalize(routeDirection)
    }

    let floorY = markerPosition.y - markerCenterHeight + 0.035
    let arrowCount = 4
    if arrowNodes.count != arrowCount {
      arrowNodes.forEach { $0.removeFromParentNode() }
      arrowNodes = (0..<arrowCount).map { _ in
        let arrow = makeArrowNode()
        routeRoot.addChildNode(arrow)
        return arrow
      }
    }
    for index in 1...arrowCount {
      let distance = routeLength * Float(index) / Float(arrowCount)
      let position = SIMD3<Float>(
        markerPosition.x + routeDirection.x * distance,
        floorY,
        markerPosition.z + routeDirection.z * distance
      )
      let arrow = arrowNodes[index - 1]
      arrow.position = SCNVector3(position.x, position.y, position.z)
      let lookTarget = position + routeDirection
      arrow.look(
        at: SCNVector3(lookTarget.x, lookTarget.y, lookTarget.z),
        up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, -1)
      )
    }

    let destination = markerPosition + routeDirection * routeLength
    if destinationNode == nil {
      let node = makeDestinationNode()
      routeRoot.addChildNode(node)
      destinationNode = node
    }
    destinationNode?.position = SCNVector3(
      destination.x,
      floorY + 0.04,
      destination.z
    )
  }

  private func considerFloor(_ planeAnchor: ARPlaneAnchor) {
    guard mode == .navigation, planeAnchor.alignment == .horizontal else { return }
    guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else { return }

    let candidateY = planeAnchor.transform.columns.3.y
    let cameraY = cameraTransform.columns.3.y
    let height = cameraY - candidateY
    let isClassifiedFloor = planeAnchor.classification == .floor
    guard height >= 0.85, height <= 2.2 else { return }

    var score = abs(height - 1.35)
    if isClassifiedFloor { score -= 1 }
    guard detectedFloorY == nil || score < bestFloorScore - 0.04 else { return }

    detectedFloorY = candidateY + 0.025
    bestFloorScore = score
    buildNavigationRoute()
    if !floorEventSent {
      floorEventSent = true
      emit("floorDetected", ["cameraHeight": Double(height)])
    }
  }

  private func buildNavigationRoute() {
    guard mode == .navigation else { return }
    guard
      let floorY = detectedFloorY,
      let cameraTransform = sceneView.session.currentFrame?.camera.transform
    else { return }

    let bearing = normalizedDegrees(navigationTargetBearing)
    let radians = bearing * .pi / 180
    let direction = SIMD3<Float>(sin(radians), 0, -cos(radians))
    let cameraPosition = SIMD3<Float>(
      cameraTransform.columns.3.x,
      cameraTransform.columns.3.y,
      cameraTransform.columns.3.z
    )
    let visibleLength = min(max(navigationDistance, 1.6), 4.2)
    let arrowCount = min(6, max(3, Int(ceil(visibleLength / 0.72))))

    if arrowNodes.count != arrowCount {
      arrowNodes.forEach { $0.removeFromParentNode() }
      arrowNodes = (0..<arrowCount).map { index in
        let arrow = makeArrowNode()
        arrow.opacity = 0.82 + CGFloat(index) * 0.03
        routeRoot.addChildNode(arrow)
        return arrow
      }
    }

    for index in 0..<arrowCount {
      let progress = Float(index + 1) / Float(arrowCount)
      let distance = 0.55 + (visibleLength - 0.55) * progress
      let position = SIMD3<Float>(
        cameraPosition.x + direction.x * distance,
        floorY,
        cameraPosition.z + direction.z * distance
      )
      let arrow = arrowNodes[index]
      arrow.position = SCNVector3(position.x, position.y, position.z)
      let lookTarget = position + direction
      arrow.look(
        at: SCNVector3(lookTarget.x, lookTarget.y, lookTarget.z),
        up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, -1)
      )
    }

    if navigationDistance <= 4.6 {
      let destination = cameraPosition + direction * max(navigationDistance, 1.0)
      if destinationNode == nil {
        let node = makeDestinationNode()
        routeRoot.addChildNode(node)
        destinationNode = node
      }
      destinationNode?.isHidden = false
      destinationNode?.position = SCNVector3(destination.x, floorY + 0.04, destination.z)
    } else {
      destinationNode?.isHidden = true
    }
    lastRouteOrigin = cameraPosition
  }

  private func makeArrowNode() -> SCNNode {
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 0, y: 0.34))
    path.addLine(to: CGPoint(x: 0.33, y: -0.02))
    path.addLine(to: CGPoint(x: 0.15, y: -0.18))
    path.addLine(to: CGPoint(x: 0, y: -0.03))
    path.addLine(to: CGPoint(x: -0.15, y: -0.18))
    path.addLine(to: CGPoint(x: -0.33, y: -0.02))
    path.close()

    let shape = SCNShape(path: path, extrusionDepth: 0.045)
    shape.chamferRadius = 0.018

    let faceMaterial = SCNMaterial()
    faceMaterial.diffuse.contents = UIColor(red: 0.08, green: 0.43, blue: 0.94, alpha: 1)
    faceMaterial.metalness.contents = 0.18
    faceMaterial.roughness.contents = 0.32
    faceMaterial.emission.contents = UIColor(red: 0.01, green: 0.10, blue: 0.28, alpha: 0.18)

    let sideMaterial = SCNMaterial()
    sideMaterial.diffuse.contents = UIColor(red: 0.02, green: 0.18, blue: 0.48, alpha: 1)
    shape.materials = [faceMaterial, sideMaterial, faceMaterial]

    let faceNode = SCNNode(geometry: shape)
    faceNode.eulerAngles.x = -.pi / 2
    faceNode.castsShadow = true

    let container = SCNNode()
    container.addChildNode(faceNode)
    return container
  }

  private func normalizedDegrees(_ degrees: Float) -> Float {
    let value = degrees.truncatingRemainder(dividingBy: 360)
    return value < 0 ? value + 360 : value
  }

  private func shortestAngle(_ degrees: Float) -> Float {
    return (degrees + 540).truncatingRemainder(dividingBy: 360) - 180
  }

  private func makeDestinationNode() -> SCNNode {
    let ring = SCNTorus(ringRadius: 0.28, pipeRadius: 0.045)
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.systemGreen
    material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.25)
    ring.materials = [material]
    let node = SCNNode(geometry: ring)
    return node
  }

  private func emit(_ method: String, _ arguments: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod(method, arguments: arguments)
    }
  }
}

extension UnimetARPlatformView: ARSCNViewDelegate {
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    if mode == .navigation, let planeAnchor = anchor as? ARPlaneAnchor {
      considerFloor(planeAnchor)
      return
    }
    guard let imageAnchor = anchor as? ARImageAnchor else { return }
    guard detectedAnchorId == nil else { return }

    detectedAnchorId = imageAnchor.identifier
    addMarkerConfirmation(to: node, referenceImage: imageAnchor.referenceImage)
    buildRoute(using: imageAnchor.transform)
    emit("markerDetected", [
      "markerId": imageAnchor.referenceImage.name ?? markerId,
      "routeLength": Double(routeLength),
    ])
  }

  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    if mode == .navigation, let planeAnchor = anchor as? ARPlaneAnchor {
      considerFloor(planeAnchor)
      return
    }
    guard
      let imageAnchor = anchor as? ARImageAnchor,
      imageAnchor.identifier == detectedAnchorId,
      imageAnchor.isTracked
    else { return }
    buildRoute(using: imageAnchor.transform)
  }
}

extension UnimetARPlatformView: ARSessionDelegate {
  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard mode == .navigation else { return }

    let cameraTransform = frame.camera.transform
    let forward = SIMD3<Float>(
      -cameraTransform.columns.2.x,
      0,
      -cameraTransform.columns.2.z
    )
    if simd_length(forward) > 0.001,
       frame.timestamp - lastHeadingEmission >= 0.10 {
      let direction = simd_normalize(forward)
      let radians = atan2(direction.x, -direction.z)
      let heading = normalizedDegrees(radians * 180 / .pi)
      lastHeadingEmission = frame.timestamp
      emit("cameraHeading", ["heading": Double(heading)])
    }

    if let origin = lastRouteOrigin, detectedFloorY != nil {
      let current = SIMD3<Float>(
        cameraTransform.columns.3.x,
        cameraTransform.columns.3.y,
        cameraTransform.columns.3.z
      )
      let horizontalMovement = SIMD2<Float>(current.x - origin.x, current.z - origin.z)
      if simd_length(horizontalMovement) >= 0.9 {
        buildNavigationRoute()
      }
    }
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    let message: String
    switch camera.trackingState {
    case .normal:
      message = "normal"
    case .notAvailable:
      message = "no_disponible"
    case .limited(let reason):
      switch reason {
      case .initializing:
        message = "inicializando"
      case .excessiveMotion:
        message = "movimiento_excesivo"
      case .insufficientFeatures:
        message = "pocos_detalles"
      case .relocalizing:
        message = "relocalizando"
      @unknown default:
        message = "limitado"
      }
    }
    guard message != lastTrackingMessage else { return }
    lastTrackingMessage = message
    emit("trackingState", ["state": message])
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    let nativeError = error as NSError
    session.pause()
    routeRoot.isHidden = true
    emit("error", [
      "message": error.localizedDescription,
      "domain": nativeError.domain,
      "code": nativeError.code,
    ])
  }
}
