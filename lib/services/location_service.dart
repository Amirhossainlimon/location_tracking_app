import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentLocation() async {
    await _ensureLocationPermission();

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
  }

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServicesDisabledFailure();
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedFailure();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedFailure();
    }
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

class LocationServicesDisabledFailure implements Exception {
  const LocationServicesDisabledFailure();
}

class LocationPermissionDeniedFailure implements Exception {
  const LocationPermissionDeniedFailure();
}

class LocationPermissionPermanentlyDeniedFailure implements Exception {
  const LocationPermissionPermanentlyDeniedFailure();
}

String formatCoordinate(double value) => value.toStringAsFixed(6);
