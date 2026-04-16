import 'package:geolocator/geolocator.dart';

/// Thin wrapper over the static [Geolocator] API so [LocationService] can
/// be unit-tested without a device. The production impl delegates straight
/// to the plugin; tests inject a fake.
abstract class GeoClient {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<Position> getCurrentPosition({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  });
}

class GeoClientImpl implements GeoClient {
  const GeoClientImpl();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<Position> getCurrentPosition({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) =>
      Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
}
