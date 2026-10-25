import 'dart:async';

import 'package:geolocator/geolocator.dart';
import '../core/app_logger.dart';

enum LocationIssue { serviceOff, denied, deniedForever, unavailable }

class LocationResult {
  final Position? position;
  final LocationIssue? issue;

  const LocationResult.found(Position this.position) : issue = null;
  const LocationResult.failed(LocationIssue this.issue) : position = null;
}

class LocationService {
  Future<LocationResult> locate() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult.failed(LocationIssue.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationIssue.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(LocationIssue.denied);
      }
    } catch (e, stack) {
      AppLogger.error('Location permission check failed', e, stack);
      return const LocationResult.failed(LocationIssue.unavailable);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));
      return LocationResult.found(position);
    } catch (e) {
      AppLogger.info(
          'Live location unavailable, trying last known: ${e.runtimeType}');
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LocationResult.found(last);
    } catch (e, stack) {
      AppLogger.error('Last known location failed', e, stack);
    }
    return const LocationResult.failed(LocationIssue.unavailable);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
}
