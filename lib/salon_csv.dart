import 'package:csv/csv.dart';

class SalonCsvRecord {
  const SalonCsvRecord({
    required this.id,
    required this.name,
    required this.floor,
    required this.reference,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.altitudeAccuracy,
  });

  final String id;
  final String name;
  final String floor;
  final String reference;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? altitudeAccuracy;
}

class SalonCsvImportResult {
  const SalonCsvImportResult({
    required this.records,
    required this.skippedRows,
  });

  final List<SalonCsvRecord> records;
  final int skippedRows;
}

class SalonCsvFormatException implements Exception {
  const SalonCsvFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

SalonCsvImportResult parseSalonCsv(String contents) {
  final normalizedContents =
      contents.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n')
      .convert(normalizedContents)
      .where((row) => row.any((value) => value.toString().trim().isNotEmpty))
      .toList();
  if (rows.isEmpty) {
    throw const SalonCsvFormatException('El CSV está vacío.');
  }

  final headers = rows.first
      .map((value) => _normalizeHeader(value.toString()))
      .toList(growable: false);
  final nameIndex = _requiredColumn(headers, ['nombresalon', 'salon', 'aula']);
  final floorIndex = _requiredColumn(headers, ['piso']);
  final latitudeIndex = _requiredColumn(headers, ['latitud', 'latitude']);
  final longitudeIndex = _requiredColumn(headers, ['longitud', 'longitude']);
  final idIndex = _optionalColumn(headers, ['id']);
  final referenceIndex = _optionalColumn(headers, ['referencia', 'reference']);
  final accuracyIndex = _optionalColumn(
    headers,
    ['precisionmetros', 'precision', 'accuracy'],
  );
  final altitudeIndex = _optionalColumn(
    headers,
    ['alturametros', 'altura', 'altitude'],
  );
  final altitudeAccuracyIndex = _optionalColumn(
    headers,
    ['precisionalturametros', 'precisionaltura', 'altitudeaccuracy'],
  );

  final records = <SalonCsvRecord>[];
  var skippedRows = 0;
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.every((value) => value.toString().trim().isEmpty)) continue;

    final name = _cell(row, nameIndex);
    final floor = _cell(row, floorIndex);
    final latitude = _number(_cell(row, latitudeIndex));
    final longitude = _number(_cell(row, longitudeIndex));
    if (name.isEmpty ||
        floor.isEmpty ||
        latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      skippedRows++;
      continue;
    }

    final sourceId = idIndex == null ? '' : _cell(row, idIndex);
    records.add(
      SalonCsvRecord(
        id: sourceId.isEmpty ? 'fila-$rowIndex' : sourceId,
        name: name,
        floor: floor,
        reference: referenceIndex == null ? '' : _cell(row, referenceIndex),
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracyIndex == null
            ? 0
            : (_number(_cell(row, accuracyIndex)) ?? 0),
        altitude:
            altitudeIndex == null ? null : _number(_cell(row, altitudeIndex)),
        altitudeAccuracy: altitudeAccuracyIndex == null
            ? null
            : _number(_cell(row, altitudeAccuracyIndex)),
      ),
    );
  }

  if (records.isEmpty) {
    throw const SalonCsvFormatException(
      'El archivo no contiene salones con coordenadas válidas.',
    );
  }
  return SalonCsvImportResult(records: records, skippedRows: skippedRows);
}

int _requiredColumn(List<String> headers, List<String> aliases) {
  final index = _optionalColumn(headers, aliases);
  if (index == null) {
    throw SalonCsvFormatException(
      'Falta la columna obligatoria “${aliases.first}”.',
    );
  }
  return index;
}

int? _optionalColumn(List<String> headers, List<String> aliases) {
  for (final alias in aliases) {
    final index = headers.indexOf(alias);
    if (index >= 0) return index;
  }
  return null;
}

String _normalizeHeader(String value) {
  return value
      .replaceFirst('\ufeff', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]'), '');
}

String _cell(List<dynamic> row, int index) {
  if (index >= row.length) return '';
  return row[index].toString().trim();
}

double? _number(String value) {
  if (value.isEmpty) return null;
  return double.tryParse(value.replaceAll(',', '.'));
}
