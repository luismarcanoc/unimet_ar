import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:unimet_ar/campus_home.dart';
import 'package:unimet_ar/main.dart';
import 'package:unimet_ar/schedule.dart';

class FakeFilePicker extends FilePicker {
  FilePickerResult? next;
  Uint8List? exported;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => next;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    exported = bytes;
    return 'horario.csv';
  }

  void select(String name, String content) {
    final bytes = utf8.encode(content);
    next = FilePickerResult([
      PlatformFile(name: name, size: bytes.length, bytes: bytes),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFilePicker picker;
  final source = File(
    'OCR_horario/resultados/2024_0072847234420240908224952.csv',
  ).readAsStringSync();
  final schedule = parseScheduleCsv(source, source: 'horario.csv');
  // Synthetic coordinates exist only in tests, never in the app catalog.
  final room = InterestPoint(
    id: 'csv:test',
    name: 'A1-106',
    floor: '1',
    latitude: 10.5,
    longitude: -66.8,
    accuracy: 5,
    createdAt: DateTime(2026),
    isImported: true,
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FilePicker.platform = picker = FakeFilePicker();
  });

  Future<void> saved({bool withSchedule = true}) async {
    final prefs = SharedPreferencesAsync();
    if (withSchedule) {
      await prefs.setString('campus_schedule_v1', schedule.encode());
    }
    await prefs.setStringList('imported_salons_v1', [
      jsonEncode(room.toJson()),
    ]);
    await prefs.setStringList('saved_interest_points_v1', [
      jsonEncode({
        ...room.toJson(),
        'name': 'Sala de casa',
        'isImported': false,
      }),
    ]);
  }

  Future<void> open(WidgetTester tester, {double width = 390}) async {
    await tester.binding.setSurfaceSize(Size(width, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const UnimetArApp(cameras: []));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'starts empty without personal points or synthetic destinations',
    (tester) async {
      await open(tester, width: 320);
      expect(find.text('Cargar horario'), findsOneWidget);
      await tester.tap(find.text('Salones'));
      await tester.pumpAndSettle();
      expect(find.text('0 salones registrados'), findsOneWidget);
      expect(find.text('Sala de casa'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restores schedule and real catalog independently of old personal points',
    (tester) async {
      await saved();
      await open(tester, width: 320);
      expect(find.byType(ScheduleClassTile), findsWidgets);
      await tester.tap(find.text('Salones'));
      await tester.pumpAndSettle();
      expect(find.text('A1-106'), findsOneWidget);
      expect(find.text('Sala de casa'), findsNothing);
      await tester.enterText(find.byType(TextField), 'no existe');
      await tester.pumpAndSettle();
      expect(find.text('No hay salones con esos filtros.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid stored schedule does not hide the room catalog', (
    tester,
  ) async {
    await saved(withSchedule: false);
    await SharedPreferencesAsync().setString('campus_schedule_v1', 'invalid');
    await open(tester);
    await tester.tap(find.text('Salones'));
    await tester.pumpAndSettle();
    expect(find.text('A1-106'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'schedule import previews then persists only after confirmation',
    (tester) async {
      picker.select('horario.csv', source);
      await open(tester);
      await tester.tap(find.text('Cargar horario'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar horario'), findsOneWidget);
      expect(
        await SharedPreferencesAsync().getString('campus_schedule_v1'),
        isNull,
      );
      await tester.tap(find.text('Confirmar horario'));
      await tester.pumpAndSettle();
      final stored = await SharedPreferencesAsync().getString(
        'campus_schedule_v1',
      );
      expect(
        ScheduleData.decode(stored!).classes.length,
        schedule.classes.length,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelling or invalid import preserves the previous schedule', (
    tester,
  ) async {
    await saved();
    await open(tester);
    await tester.tap(find.byTooltip('Reemplazar horario'));
    await tester.pumpAndSettle();
    expect(
      await SharedPreferencesAsync().getString('campus_schedule_v1'),
      schedule.encode(),
    );
    picker.select(
      'wrong.csv',
      'nombreSalon,piso,latitud,longitud\nA1-106,1,10.5,-66.8',
    );
    await tester.tap(find.byTooltip('Reemplazar horario'));
    await tester.pumpAndSettle();
    expect(
      await SharedPreferencesAsync().getString('campus_schedule_v1'),
      schedule.encode(),
    );
    expect(find.textContaining('Selecciona el CSV de horario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exported CSV retains the loaded schedule', (tester) async {
    await saved();
    await open(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(
      parseScheduleCsv(
        utf8.decode(picker.exported!),
        source: 'export.csv',
      ).classes.length,
      schedule.classes.length,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removing schedule retains imported and historical personal records',
    (tester) async {
      await saved();
      await open(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar horario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getString('campus_schedule_v1'), isNull);
      expect(await prefs.getStringList('imported_salons_v1'), hasLength(1));
      expect(
        await prefs.getStringList('saved_interest_points_v1'),
        hasLength(1),
      );
    },
  );

  testWidgets('room import requires confirmation and refuses duplicate IDs', (
    tester,
  ) async {
    await saved(withSchedule: false);
    await open(tester);
    await tester.tap(find.text('Salones'));
    await tester.pumpAndSettle();
    picker.select(
      'salones.csv',
      'id,nombreSalon,piso,latitud,longitud\na,A1-202,2,10.5,-66.8',
    );
    await tester.tap(find.byTooltip('Importar coordenadas CSV'));
    // The progress indicator remains animated behind the confirmation dialog.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Actualizar salones'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('A1-202')),
      findsOneWidget,
    );
    picker.select(
      'salones.csv',
      'id,nombreSalon,piso,latitud,longitud\na,A1-203,2,10.5,-66.8\na,A1-204,2,10.5,-66.8',
    );
    await tester.tap(find.byTooltip('Importar coordenadas CSV'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('A1-202')),
      findsOneWidget,
    );
    expect(find.textContaining('identificadores duplicados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('CAPTURE_UI')) {
    testWidgets('captures actual home and schedule for visual review', (
      tester,
    ) async {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final font = Platform.environment['UI_TEST_FONT'];
      if (font != null) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
          );
        await loader.load();
      }
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> capture(String name) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: const UnimetArApp(cameras: []),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('tmp/ui/$name.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }

      await capture('home');
      await saved();
      await capture('schedule');
    });
  }
}
