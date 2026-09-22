import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

const gpsFreshness = Duration(seconds: 8);

enum GpsGuidance {
  acquiring,
  stale,
  poorAccuracy,
  nearDestination,
  uncertain,
  ready
}

/// A short walking filter. Reported uncertainty is never reduced by averaging.
class WalkingPositionFilter {
  Position? position;
  Position? lastRaw;
  DateTime? _firstTimestamp;
  int acceptedCount = 0;
  int rejectedCount = 0;
  String? rejection;

  bool add(Position sample, DateTime now) {
    if (!sample.latitude.isFinite ||
        !sample.longitude.isFinite ||
        sample.latitude.abs() > 90 ||
        sample.longitude.abs() > 180 ||
        !sample.accuracy.isFinite ||
        sample.accuracy <= 0) {
      return _reject('Lectura GPS inválida');
    }
    final age = now.difference(sample.timestamp);
    if (age > gpsFreshness || age < const Duration(seconds: -2)) {
      return _reject('Lectura GPS antigua');
    }
    if (lastRaw != null && !sample.timestamp.isAfter(lastRaw!.timestamp)) {
      // Cached or repeated samples must not count as independent fixes.
      return false;
    }
    if (sample.accuracy > 50) return _reject('Lectura GPS demasiado imprecisa');

    final previous = lastRaw;
    final seconds = previous == null
        ? 0.0
        : sample.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    final reacquiring = previous == null || seconds > gpsFreshness.inSeconds;
    if (!reacquiring) {
      final jump = Geolocator.distanceBetween(previous.latitude,
          previous.longitude, sample.latitude, sample.longitude);
      final allowance = 4 * seconds + previous.accuracy + sample.accuracy;
      if (jump > allowance) return _reject('Salto GPS descartado');
    }

    double latitude = sample.latitude;
    double longitude = sample.longitude;
    var accuracy = sample.accuracy;
    if (reacquiring) {
      acceptedCount = 0;
      _firstTimestamp = sample.timestamp;
    } else {
      final old = position!;
      final movement = Geolocator.distanceBetween(
          old.latitude, old.longitude, sample.latitude, sample.longitude);
      final factor = sample.accuracy < previous.accuracy * 0.6
          ? 1.0
          : (seconds / 2.0).clamp(0.3, 1.0);
      latitude = old.latitude + (sample.latitude - old.latitude) * factor;
      final longitudeDelta =
          (sample.longitude - old.longitude + 540) % 360 - 180;
      longitude = (old.longitude + longitudeDelta * factor + 540) % 360 - 180;
      accuracy = math.max(sample.accuracy, movement * (1 - factor));
    }
    position = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: sample.timestamp,
      accuracy: accuracy,
      altitude: sample.altitude,
      altitudeAccuracy: sample.altitudeAccuracy,
      heading: sample.heading,
      headingAccuracy: sample.headingAccuracy,
      speed: sample.speed,
      speedAccuracy: sample.speedAccuracy,
      floor: sample.floor,
      isMocked: sample.isMocked,
    );
    lastRaw = sample;
    acceptedCount++;
    rejection = null;
    return true;
  }

  bool _reject(String reason) {
    rejectedCount++;
    rejection = reason;
    return false;
  }

  bool get settled =>
      acceptedCount >= 3 &&
      _firstTimestamp != null &&
      position!.timestamp.difference(_firstTimestamp!) >=
          const Duration(seconds: 2);

  GpsGuidance guidance(
      {required DateTime now,
      required double distance,
      required double destinationAccuracy}) {
    final fix = position;
    if (fix == null) return GpsGuidance.acquiring;
    if (now.difference(fix.timestamp) > gpsFreshness) return GpsGuidance.stale;
    if (rejection != null || fix.accuracy > 25) return GpsGuidance.poorAccuracy;
    if (!settled) return GpsGuidance.acquiring;
    final uncertainty =
        fix.accuracy + effectiveDestinationAccuracy(destinationAccuracy);
    if (distance <= math.max(5, uncertainty)) {
      return GpsGuidance.nearDestination;
    }
    if (distance < uncertainty * 2) return GpsGuidance.uncertain;
    return GpsGuidance.ready;
  }
}

double effectiveDestinationAccuracy(double accuracy) =>
    accuracy.isFinite && accuracy > 0 ? accuracy : 15;

String gpsGuidanceMessage(GpsGuidance state) => switch (state) {
      GpsGuidance.acquiring => 'Estabilizando ubicación',
      GpsGuidance.stale => 'Esperando un GPS actualizado',
      GpsGuidance.poorAccuracy => 'Ubicación imprecisa',
      GpsGuidance.nearDestination => 'Zona del destino; confirma el salón',
      GpsGuidance.uncertain => 'Sin precisión para indicar un giro',
      GpsGuidance.ready => 'Dirección al destino',
    };

class HeadingSmoother {
  double? value;
  DateTime? timestamp;

  double update(double next, DateTime now) {
    final dt = timestamp == null
        ? 1.0
        : now.difference(timestamp!).inMicroseconds / 1e6;
    final delta = value == null ? 0.0 : (next - value! + 540) % 360 - 180;
    final factor = 1 - math.exp(-math.max(0, dt) / 0.15);
    value = value == null || dt > 1
        ? next % 360
        : (value! + delta * factor + 360) % 360;
    timestamp = now;
    return value!;
  }

  void reset() {
    value = null;
    timestamp = null;
  }
}
