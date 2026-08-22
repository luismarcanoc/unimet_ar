import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = [];
  }

  runApp(UnimetArApp(cameras: cameras));
}

class UnimetArApp extends StatelessWidget {
  const UnimetArApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIMET AR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F73FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}

enum PointKind { current, classroom, area }

class IndoorPoint {
  const IndoorPoint({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.floor,
    required this.kind,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final int floor;
  final PointKind kind;
}

const demoPoints = <IndoorPoint>[
  IndoorPoint(
    id: 'CASA-ENTRADA',
    name: 'Entrada',
    x: 0,
    y: 0,
    floor: 1,
    kind: PointKind.current,
  ),
  IndoorPoint(
    id: 'CASA-SALA',
    name: 'Sala',
    x: 2,
    y: 1,
    floor: 1,
    kind: PointKind.classroom,
  ),
  IndoorPoint(
    id: 'CASA-COCINA',
    name: 'Cocina',
    x: 5,
    y: 1,
    floor: 1,
    kind: PointKind.classroom,
  ),
  IndoorPoint(
    id: 'CASA-CUARTO',
    name: 'Cuarto',
    x: 5,
    y: -2,
    floor: 1,
    kind: PointKind.classroom,
  ),
  IndoorPoint(
    id: 'CASA-BANO',
    name: 'Bano',
    x: 3,
    y: -2,
    floor: 1,
    kind: PointKind.area,
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  IndoorPoint current = demoPoints.first;
  IndoorPoint destination = demoPoints[2];

  void setCurrent(IndoorPoint point) {
    setState(() {
      current = point;
      if (destination.id == current.id) {
        destination = demoPoints.firstWhere((item) => item.id != current.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final distance = distanceBetween(current, destination);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const Text(
              'UNIMET AR',
              style: TextStyle(
                color: Color(0xFF0B1D4D),
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prototipo fisico con coordenadas locales. Usa tu casa como edificio de prueba.',
              style: TextStyle(
                color: Color(0xFF607195),
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SelectionCard(
              title: 'Estoy en',
              value: current,
              points: demoPoints,
              onChanged: setCurrent,
            ),
            const SizedBox(height: 14),
            SelectionCard(
              title: 'Quiero ir a',
              value: destination,
              points: demoPoints.where((point) => point.id != current.id).toList(),
              onChanged: (point) => setState(() => destination = point),
            ),
            const SizedBox(height: 18),
            RouteSummary(current: current, destination: destination),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.view_in_ar_rounded),
              label: Text(
                'Abrir guia AR (${distance.toStringAsFixed(1)} m)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArGuideScreen(
                      cameras: widget.cameras,
                      current: current,
                      destination: destination,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SelectionCard extends StatelessWidget {
  const SelectionCard({
    super.key,
    required this.title,
    required this.value,
    required this.points,
    required this.onChanged,
  });

  final String title;
  final IndoorPoint value;
  final List<IndoorPoint> points;
  final ValueChanged<IndoorPoint> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A396B).withOpacity(0.11),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF607195),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<IndoorPoint>(
            value: points.any((point) => point.id == value.id) ? value : points.first,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FBFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: points
                .map(
                  (point) => DropdownMenuItem(
                    value: point,
                    child: Text('${point.id} - ${point.name}'),
                  ),
                )
                .toList(),
            onChanged: (point) {
              if (point != null) onChanged(point);
            },
          ),
        ],
      ),
    );
  }
}

class RouteSummary extends StatelessWidget {
  const RouteSummary({
    super.key,
    required this.current,
    required this.destination,
  });

  final IndoorPoint current;
  final IndoorPoint destination;

  @override
  Widget build(BuildContext context) {
    final bearing = bearingBetween(current, destination);
    final distance = distanceBetween(current, destination);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D4D),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ruta calculada',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${distance.toStringAsFixed(1)} m hacia ${cardinalFromDegrees(bearing)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bearing ${bearing.toStringAsFixed(0)} grados desde ${current.name} hasta ${destination.name}.',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class ArGuideScreen extends StatefulWidget {
  const ArGuideScreen({
    super.key,
    required this.cameras,
    required this.current,
    required this.destination,
  });

  final List<CameraDescription> cameras;
  final IndoorPoint current;
  final IndoorPoint destination;

  @override
  State<ArGuideScreen> createState() => _ArGuideScreenState();
}

class _ArGuideScreenState extends State<ArGuideScreen> {
  CameraController? controller;
  Future<void>? cameraReady;
  double headingDegrees = 0;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      cameraReady = controller!.initialize();
    }
  }

  @override
  void dispose() {
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = distanceBetween(widget.current, widget.destination);
    final targetBearing = bearingBetween(widget.current, widget.destination);
    final relativeBearing = normalizeDegrees(targetBearing - headingDegrees);
    final arrowTurns = relativeBearing / 360;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraBackdrop(controller: controller, cameraReady: cameraReady),
          Container(color: Colors.black.withOpacity(0.18)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TopGuideBar(
                    destination: widget.destination,
                    distance: distance,
                    bearing: targetBearing,
                  ),
                  const Spacer(),
                  Transform.rotate(
                    angle: arrowTurns * 2 * math.pi,
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 132,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    instructionFor(relativeBearing),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  HeadingControl(
                    headingDegrees: headingDegrees,
                    targetBearing: targetBearing,
                    onChanged: (value) => setState(() => headingDegrees = value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraBackdrop extends StatelessWidget {
  const CameraBackdrop({
    super.key,
    required this.controller,
    required this.cameraReady,
  });

  final CameraController? controller;
  final Future<void>? cameraReady;

  @override
  Widget build(BuildContext context) {
    if (controller == null || cameraReady == null) {
      return const _CameraFallback();
    }

    return FutureBuilder<void>(
      future: cameraReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _CameraFallback(message: 'Inicializando camara...');
        }

        if (!controller!.value.isInitialized) {
          return const _CameraFallback();
        }

        return CameraPreview(controller!);
      },
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({this.message = 'Camara no disponible en este dispositivo'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF142857), Color(0xFF050914)],
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class TopGuideBar extends StatelessWidget {
  const TopGuideBar({
    super.key,
    required this.destination,
    required this.distance,
    required this.bearing,
  });

  final IndoorPoint destination;
  final double distance;
  final double bearing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination.id,
                  style: const TextStyle(
                    color: Color(0xFF0B1D4D),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${distance.toStringAsFixed(1)} m - ${cardinalFromDegrees(bearing)}',
                  style: const TextStyle(
                    color: Color(0xFF607195),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HeadingControl extends StatelessWidget {
  const HeadingControl({
    super.key,
    required this.headingDegrees,
    required this.targetBearing,
    required this.onChanged,
  });

  final double headingDegrees;
  final double targetBearing;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orientacion simulada',
                style: TextStyle(
                  color: Color(0xFF0B1D4D),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${headingDegrees.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Color(0xFF2F73FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: headingDegrees,
            min: 0,
            max: 359,
            divisions: 359,
            label: '${headingDegrees.toStringAsFixed(0)}°',
            onChanged: onChanged,
          ),
          Text(
            'Destino real: ${targetBearing.toStringAsFixed(0)}°. Ajusta el slider para simular hacia donde apunta el telefono.',
            style: const TextStyle(color: Color(0xFF607195), height: 1.3),
          ),
        ],
      ),
    );
  }
}

double distanceBetween(IndoorPoint a, IndoorPoint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return math.sqrt(dx * dx + dy * dy);
}

double bearingBetween(IndoorPoint a, IndoorPoint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final radians = math.atan2(dx, dy);
  return normalizeDegrees(radians * 180 / math.pi);
}

double normalizeDegrees(double degrees) {
  final normalized = degrees % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

String cardinalFromDegrees(double degrees) {
  const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((normalizeDegrees(degrees) + 22.5) / 45).floor() % labels.length;
  return labels[index];
}

String instructionFor(double relativeBearing) {
  final angle = normalizeDegrees(relativeBearing);
  if (angle <= 15 || angle >= 345) return 'Sigue derecho';
  if (angle < 75) return 'Gira un poco a la derecha';
  if (angle < 135) return 'Gira a la derecha';
  if (angle < 225) return 'Date la vuelta';
  if (angle < 285) return 'Gira a la izquierda';
  return 'Gira un poco a la izquierda';
}
