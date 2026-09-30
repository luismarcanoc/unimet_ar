import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'schedule.dart';

class RoutePoint {
  const RoutePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.floor,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String floor;
}

class RouteEdge {
  const RouteEdge({
    required this.from,
    required this.to,
    this.accessible = true,
  });

  final String from;
  final String to;
  final bool accessible;
}

class CampusRoute {
  const CampusRoute({required this.points, required this.distanceMeters});

  final List<RoutePoint> points;
  final double distanceMeters;

  RoutePoint get nextPoint => points.length > 1 ? points[1] : points.first;

  double bearingFrom(double latitude, double longitude) =>
      Geolocator.bearingBetween(
        latitude,
        longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );

  String instructionFrom(double latitude, double longitude, double? heading) {
    if (heading == null) return 'Continúa hacia el siguiente tramo';
    final relative =
        (bearingFrom(latitude, longitude) - heading + 540) % 360 - 180;
    if (relative.abs() <= 18) return 'Continúa recto';
    if (relative.abs() >= 150) return 'Da la vuelta';
    return relative > 0 ? 'Gira a la derecha' : 'Gira a la izquierda';
  }
}

class RouteNetwork {
  const RouteNetwork({
    required this.nodes,
    required this.edges,
    required this.destinations,
  });

  final Map<String, RoutePoint> nodes;
  final List<RouteEdge> edges;
  final Map<String, String> destinations;

  bool get isEmpty => nodes.isEmpty || edges.isEmpty;

  static Future<RouteNetwork> loadAsset() async {
    final raw = await rootBundle.loadString('assets/campus_routes.json');
    return RouteNetwork.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory RouteNetwork.fromJson(Map<String, dynamic> json) {
    final nodes = <String, RoutePoint>{};
    for (final value in (json['nodes'] as List? ?? const [])) {
      final item = Map<String, dynamic>.from(value as Map);
      final point = RoutePoint(
        id: item['id'] as String,
        latitude: (item['latitude'] as num).toDouble(),
        longitude: (item['longitude'] as num).toDouble(),
        floor: item['floor']?.toString() ?? '',
      );
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude.abs() > 90 ||
          point.longitude.abs() > 180 ||
          nodes.containsKey(point.id)) {
        throw const FormatException(
          'La red peatonal contiene nodos inválidos.',
        );
      }
      nodes[point.id] = point;
    }
    final edges = <RouteEdge>[];
    for (final value in (json['edges'] as List? ?? const [])) {
      final item = Map<String, dynamic>.from(value as Map);
      final edge = RouteEdge(
        from: item['from'] as String,
        to: item['to'] as String,
        accessible: item['accessible'] as bool? ?? true,
      );
      if (!nodes.containsKey(edge.from) || !nodes.containsKey(edge.to)) {
        throw const FormatException(
          'Una conexión de la red apunta a un nodo inexistente.',
        );
      }
      edges.add(edge);
    }
    final destinations = <String, String>{};
    for (final entry in Map<String, dynamic>.from(
      json['destinations'] as Map? ?? const {},
    ).entries) {
      if (!nodes.containsKey(entry.value)) {
        throw const FormatException('Un salón apunta a un nodo inexistente.');
      }
      destinations[roomKey(entry.key)] = entry.value as String;
    }
    return RouteNetwork(nodes: nodes, edges: edges, destinations: destinations);
  }

  CampusRoute? route({
    required double latitude,
    required double longitude,
    required String destinationName,
    required double destinationLatitude,
    required double destinationLongitude,
    required String startFloor,
    required String destinationFloor,
    double maximumSnapMeters = 35,
  }) {
    final destinationId = destinations[roomKey(destinationName)];
    if (destinationId == null) return null;
    final destination = nodes[destinationId];
    if (destination == null ||
        (destinationFloor.isNotEmpty &&
            destination.floor.isNotEmpty &&
            floorKeyForRoute(destination.floor) !=
                floorKeyForRoute(destinationFloor))) {
      return null;
    }
    final candidates = nodes.values.where(
      (node) =>
          startFloor.isEmpty ||
          node.floor.isEmpty ||
          floorKeyForRoute(node.floor) == floorKeyForRoute(startFloor),
    );
    RoutePoint? start;
    var snapDistance = double.infinity;
    for (final node in candidates) {
      final distance = _distance(
        latitude,
        longitude,
        node.latitude,
        node.longitude,
      );
      if (distance < snapDistance) {
        start = node;
        snapDistance = distance;
      }
    }
    if (start == null || snapDistance > maximumSnapMeters) return null;

    final adjacency = <String, List<RoutePoint>>{};
    for (final edge in edges.where((edge) => edge.accessible)) {
      adjacency.putIfAbsent(edge.from, () => []).add(nodes[edge.to]!);
      adjacency.putIfAbsent(edge.to, () => []).add(nodes[edge.from]!);
    }
    final open = <String>{start.id};
    final cameFrom = <String, String>{};
    final score = <String, double>{start.id: 0};
    final estimate = <String, double>{start.id: _between(start, destination)};
    while (open.isNotEmpty) {
      final currentId = open.reduce(
        (a, b) =>
            (estimate[a] ?? double.infinity) <= (estimate[b] ?? double.infinity)
            ? a
            : b,
      );
      if (currentId == destination.id) {
        final ids = <String>[currentId];
        while (cameFrom.containsKey(ids.last)) {
          ids.add(cameFrom[ids.last]!);
        }
        final path = ids.reversed.map((id) => nodes[id]!).toList();
        final remainingPath = snapDistance <= 3 && path.length > 1
            ? path.skip(1)
            : path;
        final points = <RoutePoint>[
          RoutePoint(
            id: 'current',
            latitude: latitude,
            longitude: longitude,
            floor: startFloor,
          ),
          ...remainingPath,
          RoutePoint(
            id: 'destination',
            latitude: destinationLatitude,
            longitude: destinationLongitude,
            floor: destinationFloor,
          ),
        ];
        return CampusRoute(
          points: points,
          distanceMeters: _pathDistance(points),
        );
      }
      open.remove(currentId);
      for (final neighbor in adjacency[currentId] ?? const <RoutePoint>[]) {
        final tentative =
            (score[currentId] ?? double.infinity) +
            _between(nodes[currentId]!, neighbor);
        if (tentative < (score[neighbor.id] ?? double.infinity)) {
          cameFrom[neighbor.id] = currentId;
          score[neighbor.id] = tentative;
          estimate[neighbor.id] = tentative + _between(neighbor, destination);
          open.add(neighbor.id);
        }
      }
    }
    return null;
  }
}

String floorKeyForRoute(String value) {
  final key = searchKey(value).replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (['PB', 'PLANTABAJA', '0', 'PISO0', 'P0', 'NIVEL0'].contains(key)) {
    return 'PB';
  }
  final match = RegExp(r'^(?:PISO|P|NIVEL)?0*([1-9][0-9]*)$').firstMatch(key);
  return match?[1] ?? key;
}

double _between(RoutePoint a, RoutePoint b) =>
    _distance(a.latitude, a.longitude, b.latitude, b.longitude);

double _distance(double aLat, double aLng, double bLat, double bLng) =>
    Geolocator.distanceBetween(aLat, aLng, bLat, bLng);

double _pathDistance(List<RoutePoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _between(points[i - 1], points[i]);
  }
  return total;
}

double routeTurnAngle(RoutePoint before, RoutePoint corner, RoutePoint after) {
  final incoming = Geolocator.bearingBetween(
    before.latitude,
    before.longitude,
    corner.latitude,
    corner.longitude,
  );
  final outgoing = Geolocator.bearingBetween(
    corner.latitude,
    corner.longitude,
    after.latitude,
    after.longitude,
  );
  return (outgoing - incoming + 540) % 360 - 180;
}

double metersPerLongitudeDegree(double latitude) =>
    111320 * math.cos(latitude * math.pi / 180);
