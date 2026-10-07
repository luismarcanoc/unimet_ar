import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:unimet_ar/gps_navigation.dart';
import 'package:unimet_ar/main.dart';

final start = DateTime.utc(2026, 9, 22, 12);
Position fix(int second, {double metersNorth = 0, double accuracy = 5}) =>
    Position(
      latitude: 10.5 + metersNorth / 111195,
      longitude: -66.8,
      timestamp: start.add(Duration(seconds: second)),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

WalkingPositionFilter settled() {
  final filter = WalkingPositionFilter();
  for (var second = 0; second < 3; second++) {
    filter.add(fix(second), start.add(Duration(seconds: second)));
  }
  return filter;
}

void main() {
  test('waits for independent fixes and expires without new GPS events', () {
    final filter = WalkingPositionFilter();
    final position = fix(0);
    for (var i = 0; i < 4; i++) {
      filter.add(position, start);
    }
    expect(filter.settled, isFalse);
    expect(filter.acceptedCount, 1);
    filter.add(fix(1), start.add(const Duration(seconds: 1)));
    filter.add(fix(2), start.add(const Duration(seconds: 2)));
    expect(
        filter.guidance(
            now: start.add(const Duration(seconds: 2)),
            distance: 30,
            destinationAccuracy: 5),
        GpsGuidance.ready);
    expect(
        filter.guidance(
            now: start.add(const Duration(seconds: 11)),
            distance: 30,
            destinationAccuracy: 5),
        GpsGuidance.stale);
  });

  test('rejects a teleport and recovers with a nearby walking fix', () {
    final filter = settled();
    expect(
        filter.add(
            fix(3, metersNorth: 200), start.add(const Duration(seconds: 3))),
        isFalse);
    expect(filter.rejectedCount, 1);
    expect(
        filter.guidance(
            now: start.add(const Duration(seconds: 3)),
            distance: 100,
            destinationAccuracy: 5),
        GpsGuidance.poorAccuracy);
    expect(
        filter.add(
            fix(4, metersNorth: 2), start.add(const Duration(seconds: 4))),
        isTrue);
    expect(filter.rejection, isNull);
  });

  test(
      'reacquires after interruption rather than permanently rejecting a new position',
      () {
    final filter = settled();
    for (var second = 20; second <= 22; second++) {
      filter.add(
          fix(second, metersNorth: 100), start.add(Duration(seconds: second)));
      expect(filter.settled, second == 22);
    }
  });

  test('filters jitter without claiming a better accuracy', () {
    final filter = settled();
    filter.add(fix(3, metersNorth: 6, accuracy: 8),
        start.add(const Duration(seconds: 3)));
    final meters = Geolocator.distanceBetween(
        10.5, -66.8, filter.position!.latitude, filter.position!.longitude);
    expect(meters, closeTo(3, 0.1));
    expect(filter.position!.accuracy, greaterThanOrEqualTo(8));
  });

  test('rejects invalid, old and future readings', () {
    final filter = WalkingPositionFilter();
    for (final sample in [
      fix(0, accuracy: 0),
      fix(0, accuracy: double.nan),
      fix(0, accuracy: 120),
      fix(-20),
      fix(10)
    ]) {
      expect(filter.add(sample, start), isFalse);
    }
    expect(filter.position, isNull);
  });

  test('keeps a recent 70 m fix available for approximate guidance', () {
    final filter = WalkingPositionFilter();
    expect(filter.add(fix(0, accuracy: 70), start), isTrue);
    expect(hasRecentApproximateFix(filter.position, start), isTrue);
    expect(hasRecentApproximateFix(
        filter.position, start.add(const Duration(seconds: 9))), isFalse);
    expect(filter.guidance(
        now: start, distance: 150, destinationAccuracy: 5),
        GpsGuidance.poorAccuracy);
  });

  test('includes destination error and never declares exact arrival', () {
    final filter = settled();
    final now = start.add(const Duration(seconds: 2));
    expect(filter.guidance(now: now, distance: 30, destinationAccuracy: 5),
        GpsGuidance.ready);
    expect(filter.guidance(now: now, distance: 30, destinationAccuracy: 20),
        GpsGuidance.uncertain);
    expect(filter.guidance(now: now, distance: 30, destinationAccuracy: 0),
        GpsGuidance.uncertain);
    expect(filter.guidance(now: now, distance: 2, destinationAccuracy: 5),
        GpsGuidance.nearDestination);
    expect(
        gpsGuidanceMessage(GpsGuidance.nearDestination), contains('confirma'));
  });

  test('heading smoothing crosses north and is independent of event rate', () {
    final slow = HeadingSmoother()..update(350, start);
    final fast = HeadingSmoother()..update(350, start);
    slow.update(10, start.add(const Duration(milliseconds: 200)));
    for (var t = 20; t <= 200; t += 20) {
      fast.update(10, start.add(Duration(milliseconds: t)));
    }
    expect(slow.value, closeTo(fast.value!, 0.00001));
    expect(slow.value, inInclusiveRange(0, 10));
    expect(
        preferredCameraHeading(
            isIOS: false, heading: -1, headingForCameraMode: null),
        isNull);
  });

  testWidgets(
      'paused panel has no arrow and fits a narrow phone with larger text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
      child: Scaffold(
          body: Padding(
              padding: EdgeInsets.all(16),
              child: NavigationPanel(
                distance: 12,
                relativeBearing: 90,
                headingDegrees: 15,
                compassAccuracyDegrees: 22,
                headingSource: 'ARKit',
                targetBearing: 105,
                horizontalAccuracy: 20,
                sensorProblem: null,
                instruction: 'Sin precisión para indicar un giro',
                guidanceEnabled: false,
                destinationAccuracy: 0,
                gpsAgeSeconds: 3,
                arTrackingState: 'Recuperando la ubicación',
                floorDetected: false,
              ))),
    )));
    expect(find.byIcon(Icons.navigation_rounded), findsNothing);
    expect(find.textContaining('PAUSA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel arrow points to the destination relative to the camera',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: NavigationPanel(
      distance: 50,
      relativeBearing: 90,
      headingDegrees: 15,
      compassAccuracyDegrees: 5,
      headingSource: 'ARKit',
      targetBearing: 105,
      horizontalAccuracy: 5,
      sensorProblem: null,
      instruction: 'Gira a la derecha',
      guidanceEnabled: true,
      destinationAccuracy: 5,
      gpsAgeSeconds: 0,
      arTrackingState: 'Seguimiento estable',
      floorDetected: true,
    ))));
    final transform = tester.widget<Transform>(find
        .ancestor(
            of: find.byIcon(Icons.navigation_rounded),
            matching: find.byType(Transform))
        .first);
    expect(transform.transform.entry(0, 1), closeTo(-1, 0.0001));
    expect(tester.takeException(), isNull);
  });
}
