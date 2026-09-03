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
}
