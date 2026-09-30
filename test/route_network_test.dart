import 'package:flutter_test/flutter_test.dart';
import 'package:unimet_ar/route_network.dart';

void main() {
  RouteNetwork network({bool shortcutAccessible = false}) =>
      RouteNetwork.fromJson({
        'nodes': [
          {
            'id': 'west',
            'latitude': 10.0,
            'longitude': -66.00010,
            'floor': 'Piso 1',
          },
          {
            'id': 'northWest',
            'latitude': 10.00010,
            'longitude': -66.00010,
            'floor': '1',
          },
          {
            'id': 'northEast',
            'latitude': 10.00010,
            'longitude': -66.0,
            'floor': '1',
          },
          {'id': 'door', 'latitude': 10.0, 'longitude': -66.0, 'floor': '1'},
        ],
        'edges': [
          {'from': 'west', 'to': 'northWest'},
          {'from': 'northWest', 'to': 'northEast'},
          {'from': 'northEast', 'to': 'door'},
          {'from': 'west', 'to': 'door', 'accessible': shortcutAccessible},
        ],
        'destinations': {'A1-202': 'door'},
      });

  test('routes around a blocked direct segment using walkable edges', () {
    final route = network().route(
      latitude: 10.0,
      longitude: -66.00011,
      destinationName: 'a1 - 202',
      destinationLatitude: 10.0,
      destinationLongitude: -66.0,
      startFloor: '1',
      destinationFloor: '1',
    );
    expect(route, isNotNull);
    expect(route!.points.map((point) => point.id), [
      'current',
      'northWest',
      'northEast',
      'door',
      'destination',
    ]);
    expect(route.distanceMeters, greaterThan(30));
  });

  test('never invents a route for an unmapped room or distant user', () {
    expect(
      network().route(
        latitude: 10,
        longitude: -66.0001,
        destinationName: 'A1-999',
        destinationLatitude: 10,
        destinationLongitude: -66,
        startFloor: '1',
        destinationFloor: '1',
      ),
      isNull,
    );
    expect(
      network().route(
        latitude: 11,
        longitude: -67,
        destinationName: 'A1-202',
        destinationLatitude: 10,
        destinationLongitude: -66,
        startFloor: '1',
        destinationFloor: '1',
      ),
      isNull,
    );
  });

  test('validates edges, destination nodes and floor aliases', () {
    expect(floorKeyForRoute('Piso 1'), '1');
    expect(floorKeyForRoute('Planta baja'), 'PB');
    expect(
      () => RouteNetwork.fromJson({
        'nodes': [],
        'edges': [
          {'from': 'missing', 'to': 'also-missing'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('turn instructions describe the next walkable segment', () {
    final route = network().route(
      latitude: 10.0,
      longitude: -66.00011,
      destinationName: 'A1-202',
      destinationLatitude: 10,
      destinationLongitude: -66,
      startFloor: '1',
      destinationFloor: '1',
    )!;
    expect(route.instructionFrom(10, -66.00011, 0), 'Continúa recto');
    expect(route.instructionFrom(10, -66.00011, 270), 'Gira a la derecha');
  });
}
