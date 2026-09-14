import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimet_ar/main.dart';

void main() {
  group('navigation calculations', () {
    test('normalizes angles around north', () {
      expect(normalizeDegrees(-10), 350);
      expect(normalizeDegrees(370), 10);
      expect(shortestSignedAngle(350), -10);
    });

    test('calculates cardinal bearings', () {
      expect(coordinateBearingDegrees(0, 0, 1, 0), closeTo(0, 0.01));
      expect(coordinateBearingDegrees(0, 0, 0, 1), closeTo(90, 0.01));
    });

    test('calculates short distances in meters', () {
      final distance = coordinateDistanceMeters(10.5, -66.8, 10.50001, -66.8);
      expect(distance, closeTo(1.11, 0.05));
    });

    test('chooses turn instructions from signed direction', () {
      expect(instructionFor(0), 'Sigue derecho');
      expect(instructionFor(90), 'Gira a la derecha');
      expect(instructionFor(270), 'Gira a la izquierda');
      expect(instructionFor(180), 'Date la vuelta');
    });

    test('calculates direction relative to the camera', () {
      expect(relativeBearingDegrees(0, 0), 0);
      expect(relativeBearingDegrees(90, 0), 90);
      expect(relativeBearingDegrees(0, 90), 270);
      expect(relativeBearingDegrees(5, 355), 10);
    });

    test('uses camera mode heading only on iOS', () {
      expect(
        preferredCameraHeading(
          isIOS: true,
          heading: 10,
          headingForCameraMode: 100,
        ),
        100,
      );
      expect(
        preferredCameraHeading(
          isIOS: false,
          heading: 10,
          headingForCameraMode: 0,
        ),
        10,
      );
    });

    test('smooths headings across geographic north', () {
      expect(
        smoothHeadingDegrees(previous: 350, next: 10, factor: 0.5),
        closeTo(0, 0.001),
      );
    });

    test('flags bearings hidden by GPS uncertainty', () {
      expect(
        navigationBearingIsReliable(distance: 20, horizontalAccuracy: 5),
        isTrue,
      );
      expect(
        navigationBearingIsReliable(distance: 5, horizontalAccuracy: 5),
        isFalse,
      );
    });
  });

  testWidgets('renders the perspective navigation arrow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PerspectiveNavigationArrow(relativeBearing: 90),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CSV controls fit a narrow phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalonCsvPanel(
            busy: false,
            salonCount: 41,
            onImport: () {},
            onClear: () {},
          ),
        ),
      ),
    );

    expect(find.text('41 salones cargados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
