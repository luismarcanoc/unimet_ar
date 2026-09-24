import 'package:flutter_test/flutter_test.dart';
import 'package:unimet_ar/salon_csv.dart';

void main() {
  test('imports the CSV exported by formulario_salones', () {
    const source = '''
id,fecha,nombrePersona,nombreSalon,piso,referencia,latitud,longitud,precisionMetros,alturaMetros,precisionAlturaMetros,metodo
abc,2026-09-14,Luis,A1-202,2,Frente a escaleras,10.5001,-66.8002,3.4,980.2,12,gps
''';

    final result = parseSalonCsv(source);

    expect(result.skippedRows, 0);
    expect(result.records, hasLength(1));
    expect(result.records.single.name, 'A1-202');
    expect(result.records.single.floor, '2');
    expect(result.records.single.reference, 'Frente a escaleras');
    expect(result.records.single.latitude, 10.5001);
    expect(result.records.single.longitude, -66.8002);
    expect(result.records.single.altitude, 980.2);
  });

  test('accepts common aliases and skips malformed rows', () {
    const source = '''
salon,piso,latitude,longitude,accuracy
Paraninfo,PB,10.1,-66.2,5
Sin coordenadas,PB,no,-66.2,5
''';

    final result = parseSalonCsv(source);

    expect(result.records.single.name, 'Paraninfo');
    expect(result.skippedRows, 1);
  });

  test('rejects files without the required schema', () {
    expect(
      () => parseSalonCsv('materia,profesor\nCálculo,Ana'),
      throwsA(isA<SalonCsvFormatException>()),
    );
  });

  test('rejects non-finite coordinates and ignores non-finite accuracy', () {
    final result = parseSalonCsv(
      'salon,piso,latitude,longitude,accuracy\n'
      'A1-101,1,10.5,-66.8,NaN\n'
      'A1-102,1,NaN,-66.8,5\n'
      'A1-103,1,10.5,Infinity,5',
    );
    expect(result.records.single.name, 'A1-101');
    expect(result.records.single.accuracy, 0);
    expect(result.skippedRows, 2);
  });
}
