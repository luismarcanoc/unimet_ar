import 'schedule.dart';

class FloorMarker {
  const FloorMarker(this.id, this.building, this.floor, this.label);
  final String id, building, floor, label;
  String get payload => 'unimet-ar://floor/$building/$floor?v=1';
  bool matchesRoom(String name, String recordedFloor) =>
      roomKey(name).startsWith('$building-') &&
      floorKey(recordedFloor) == floorKey(floor);
}

const floorMarkers = [
  FloorMarker('A1-PB', 'A1', 'PB', 'A1 · Planta baja'),
  FloorMarker('A1-P1', 'A1', '1', 'A1 · Piso 1'),
];

String floorKey(String value) {
  final key = searchKey(value).replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (['PB', 'PLANTABAJA', '0', 'PISO0', 'P0', 'NIVEL0'].contains(key)) {
    return 'PB';
  }
  final match = RegExp(r'^(?:PISO|P|NIVEL)?0*([1-9][0-9]*)$').firstMatch(key);
  return match?[1] ?? key;
}

FloorMarker? parseFloorMarker(String value) {
  for (final marker in floorMarkers) {
    if (value.trim() == marker.payload) return marker;
  }
  return null;
}
