import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:unimet_ar/schedule.dart';
import 'package:unimet_ar/schedule_import.dart';
import 'package:unimet_ar/campus_home.dart';
import 'package:unimet_ar/main.dart' show InterestPoint;
import 'package:unimet_ar/floor_markers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory('OCR_horario');
  final catalog = Map<String, String>.from(
    jsonDecode(File('${root.path}/data/materias.json').readAsStringSync())
        as Map,
  );
  final samples = root
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pdf') && !f.path.contains('Flujograma'))
      .toList();
  setUpAll(() async {
    await pdfrxInitialize();
  });

  for (final sample in samples) {
    final name = sample.uri.pathSegments.last;
    test('reads actual PDF $name and agrees with the Python export', () async {
      final doc = await PdfDocument.openFile(sample.path);
      try {
        final text = (await Future.wait(
          doc.pages.map(extractPdfPageText),
        )).join('\n');
        final actual = parseScheduleText(text, source: name, catalog: catalog);
        final expected = parseScheduleCsv(
          File(
            '${root.path}/resultados/${name.replaceAll('.pdf', '.csv')}',
          ).readAsStringSync(),
          source: name,
        );
        String signature(ScheduleClass c) => searchKey(
          jsonEncode([
            c.days,
            c.time,
            c.room,
            c.subject,
            c.section,
            c.professor,
          ]),
        );
        expect(
          actual.classes.map(signature).toSet(),
          expected.classes.map(signature).toSet(),
        );
        expect(actual.classes.length, expected.classes.length);
        expect(
          ScheduleData.decode(actual.encode()).classes.length,
          actual.classes.length,
        );
        expect(
          parseScheduleCsv(actual.toCsv(), source: name).classes.length,
          actual.classes.length,
        );
      } finally {
        await doc.dispose();
      }
    });
  }

  test(
    'rejects a flowchart, coordinates CSV and mixed historical schedules',
    () {
      expect(
        () => parseScheduleText(
          'Flujograma de Sistemas',
          source: 'x.pdf',
          catalog: catalog,
        ),
        throwsFormatException,
      );
      expect(
        () => parseScheduleCsv(
          'nombreSalon,piso,latitud,longitud\nA1-101,1,10,-66',
          source: 'x.csv',
        ),
        throwsFormatException,
      );
      expect(
        () => parseScheduleCsv(
          File(
            'OCR_horario/resultados/todos_los_horarios.csv',
          ).readAsStringSync(),
          source: 'todos.csv',
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects malformed class times and mismatched subject codes', () {
    const header = 'PLAN HORARIO PERIODO: 2025 - 007 ASIGNATURA PROFESOR\n';
    for (final row in [
      'Lunes 25:00-26:00 A1-101 FPTSP01 BASES FPTSP01-1 Apellido, Nombre',
      'Lunes 10:00-11:00 A1-101 FPTSP02 BASES FPTSP01-1 Apellido, Nombre',
      'Lunes HORA ILEGIBLE A1-101 FPTSP01 BASES FPTSP01-1 Apellido, Nombre',
    ]) {
      expect(
        () =>
            parseScheduleText('$header$row', source: 'x.pdf', catalog: catalog),
        throwsFormatException,
      );
    }
  });

  test(
    'matches exact normalized room codes but never substitutes nearby rooms',
    () {
      InterestPoint room(String id, String name, bool imported) =>
          InterestPoint(
            id: id,
            name: name,
            latitude: 10.5,
            longitude: -66.8,
            accuracy: 5,
            createdAt: DateTime(2026),
            isImported: imported,
          );
      final rooms = [
        room('a', 'A1-002', true),
        room('b', 'A1-020', true),
        room('c', 'A1-002', false),
      ];
      expect(matchingRooms(' a1 - OO2 ', rooms).single.id, 'a');
      expect(matchingRooms('A1-003', rooms), isEmpty);
      expect(
        matchingRooms('A1-002', [...rooms, room('d', 'A1-002', true)]).length,
        2,
      );
    },
  );

  test(
    'floor QR accepts only registered payloads and uses explicit floor metadata',
    () {
      final registry =
          jsonDecode(File('docs/markers/floor_anchors.json').readAsStringSync())
              as Map;
      expect(
        (registry['markers'] as List).map((m) => m['payload']).toList(),
        floorMarkers.map((m) => m.payload).toList(),
      );
      for (final marker in floorMarkers) {
        expect(parseFloorMarker(marker.payload), marker);
      }
      expect(parseFloorMarker('https://example.com'), isNull);
      expect(parseFloorMarker('unimet-ar://floor/A1/PB?v=2'), isNull);
      expect(floorMarkers.first.matchesRoom('A1-002', 'Planta baja'), isTrue);
      expect(floorMarkers.first.matchesRoom('A2-002', 'PB'), isFalse);
      expect(floorMarkers.last.matchesRoom('A1-101', 'Piso 1'), isTrue);
    },
  );

  test('OCR words are rebuilt in rows rather than column order', () {
    expect(
      textRows(const [
        TextPiece('Lunes', 0, 0, 20, 10),
        TextPiece('Martes', 0, 20, 20, 10),
        TextPiece('10:00-11:00', 30, 0, 90, 10),
        TextPiece('12:00-13:00', 30, 20, 90, 10),
      ]),
      'Lunes 10:00-11:00\nMartes 12:00-13:00',
    );
  });

  test('refuses merged PDF periods and rows with unreadable day names', () {
    const header = 'PLAN HORARIO PERIODO: 2025 - 007 ASIGNATURA PROFESOR\n';
    const row =
        'Lunes 10:00-11:00 A1-101 FPTSP01 BASES FPTSP01-1 Apellido, Nombre\n';
    expect(
      () => parseScheduleText(
        '$header${row}PERIODO: 2025 - 008\n$row',
        source: 'x.pdf',
        catalog: catalog,
      ),
      throwsFormatException,
    );
    expect(
      () => parseScheduleText(
        '$header$row${row.replaceFirst('Lunes', 'Lxnes')}',
        source: 'x.pdf',
        catalog: catalog,
      ),
      throwsFormatException,
    );
  });

  testWidgets(
    'schedule categories fit a small phone and unknown rooms cannot navigate',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const item = ScheduleClass(
        days: ['Lunes', 'Miércoles'],
        time: '10:30-12:00',
        room: 'A1-106',
        subject: 'Gestión de la Cadena de Suministro I',
        section: '4',
        professor: 'Mariela Castillo Nava',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleClassTile(item: item, matches: 0),
            ),
          ),
        ),
      );
      expect(find.textContaining('Sin coordenadas'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
