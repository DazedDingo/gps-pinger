import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trail/models/ping.dart';
import 'package:trail/services/battery_network_service.dart';
import 'package:trail/services/cell_wifi_service.dart';
import 'package:trail/services/geo_client.dart';
import 'package:trail/services/location_service.dart';

// --- Fakes -----------------------------------------------------------------

class _FakeBatteryNet extends BatteryNetworkService {
  final BatteryNetworkSnapshot _snap;
  _FakeBatteryNet(this._snap);
  @override
  Future<BatteryNetworkSnapshot> snapshot() async => _snap;
}

class _FakeCellWifi extends CellWifiService {
  final String? _cell;
  final String? _ssid;
  _FakeCellWifi({String? cell, String? ssid})
      : _cell = cell,
        _ssid = ssid;
  @override
  Future<String?> cellId() async => _cell;
  @override
  Future<String?> wifiSsid() async => _ssid;
}

class _FakeGeo implements GeoClient {
  final bool service;
  final LocationPermission perm;
  final Position? pos;
  final Object? error;
  _FakeGeo({
    this.service = true,
    this.perm = LocationPermission.whileInUse,
    this.pos,
    this.error,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => service;

  @override
  Future<LocationPermission> checkPermission() async => perm;

  @override
  Future<Position> getCurrentPosition({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) async {
    if (error != null) throw error!;
    return pos!;
  }
}

Position _pos({
  required double lat,
  required double lon,
  DateTime? ts,
  double accuracy = 8.0,
  double altitude = 10.0,
  double heading = 0.0,
  double speed = 0.0,
}) =>
    Position(
      latitude: lat,
      longitude: lon,
      timestamp: ts ?? DateTime.utc(2026, 4, 15, 12, 0),
      accuracy: accuracy,
      altitude: altitude,
      altitudeAccuracy: 0,
      heading: heading,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

// --- Tests -----------------------------------------------------------------

void main() {
  group('LocationService.getScheduledPing — error branches', () {
    test('location services disabled → no_fix row with that exact note', () {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(80, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(service: false),
      );
      return svc.getScheduledPing().then((p) {
        expect(p.source, PingSource.noFix);
        expect(p.note, 'location_service_disabled');
        expect(p.lat, isNull);
        expect(p.lon, isNull);
        // Battery + network are still captured on the error row so the
        // history shows context for the gap.
        expect(p.batteryPct, 80);
        expect(p.networkState, 'wifi');
      });
    });

    test('permission denied → no_fix with permission_denied note', () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(50, 'mobile')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(perm: LocationPermission.denied),
      );
      final p = await svc.getScheduledPing();
      expect(p.source, PingSource.noFix);
      expect(p.note, 'permission_denied');
      expect(p.networkState, 'mobile');
    });

    test('deniedForever is also treated as permission_denied', () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(50, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(perm: LocationPermission.deniedForever),
      );
      final p = await svc.getScheduledPing();
      expect(p.source, PingSource.noFix);
      expect(p.note, 'permission_denied');
    });

    test('fix throws (e.g. timeout) → no_fix with fix_failed:<type> note',
        () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(70, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(error: TimeoutException()),
      );
      final p = await svc.getScheduledPing();
      expect(p.source, PingSource.noFix);
      expect(p.note, startsWith('fix_failed:'));
      // The exception type is embedded so the history distinguishes timeout
      // from permission revocation mid-flight.
      expect(p.note, contains('TimeoutException'));
    });

    test('error branches never populate coords (callers check for null)',
        () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(10, 'none')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(error: StateError('boom')),
      );
      final p = await svc.getScheduledPing();
      expect(p.lat, isNull);
      expect(p.lon, isNull);
      expect(p.accuracy, isNull);
    });
  });

  group('LocationService.getScheduledPing — success path', () {
    test('populates every field from the Position + sensor fakes', () async {
      final fixTs = DateTime.utc(2026, 4, 15, 12, 30);
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(88, 'wifi')),
        cellWifi: _FakeCellWifi(cell: 'LTE:42', ssid: 'home'),
        geo: _FakeGeo(
          pos: _pos(
            lat: 51.5,
            lon: -0.12,
            ts: fixTs,
            accuracy: 6.0,
            altitude: 20.5,
            heading: 95.0,
            speed: 1.4,
          ),
        ),
      );
      final p = await svc.getScheduledPing();
      expect(p.source, PingSource.scheduled);
      expect(p.lat, 51.5);
      expect(p.lon, -0.12);
      expect(p.accuracy, 6.0);
      expect(p.altitude, 20.5);
      expect(p.heading, 95.0);
      expect(p.speed, 1.4);
      expect(p.batteryPct, 88);
      expect(p.networkState, 'wifi');
      expect(p.cellId, 'LTE:42');
      expect(p.wifiSsid, 'home');
      expect(p.timestampUtc, fixTs);
    });

    test('success uses the Position timestamp, NOT wall-clock now', () async {
      // Worker might run hours after the fix was actually acquired (unusual,
      // but possible on resumed devices). We trust the GPS clock, not ours.
      final fixTs = DateTime.utc(2024, 1, 1, 0, 0);
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(90, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(pos: _pos(lat: 1.0, lon: 2.0, ts: fixTs)),
      );
      final p = await svc.getScheduledPing();
      expect(p.timestampUtc, fixTs);
    });

    test(
        'success respects the caller-provided source (panic uses the same '
        'path)', () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(90, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(pos: _pos(lat: 1.0, lon: 2.0)),
      );
      final p = await svc.getScheduledPing(source: PingSource.panic);
      expect(p.source, PingSource.panic);
    });

    test('cell/wifi null when radio off — fix still succeeds', () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(90, 'wifi')),
        cellWifi: _FakeCellWifi(), // both null
        geo: _FakeGeo(pos: _pos(lat: 1.0, lon: 2.0)),
      );
      final p = await svc.getScheduledPing();
      expect(p.cellId, isNull);
      expect(p.wifiSsid, isNull);
      expect(p.source, PingSource.scheduled);
    });

    test('equator fix (lat=0, lon=0) is a real fix, not treated as no_fix',
        () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(80, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(pos: _pos(lat: 0.0, lon: 0.0)),
      );
      final p = await svc.getScheduledPing();
      expect(p.source, PingSource.scheduled);
      expect(p.lat, 0.0);
      expect(p.lon, 0.0);
    });
  });

  group('LocationService.getScheduledPing — branch ordering', () {
    test(
        'service-disabled wins over permission (we never ask perm if the '
        'service is off)', () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(50, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(
          service: false,
          perm: LocationPermission.denied, // would also fail if checked
        ),
      );
      final p = await svc.getScheduledPing();
      expect(p.note, 'location_service_disabled');
    });

    test('whileInUse permission is sufficient — does not fall into denied',
        () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(80, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(
          perm: LocationPermission.whileInUse,
          pos: _pos(lat: 1.0, lon: 2.0),
        ),
      );
      final p = await svc.getScheduledPing();
      expect(p.source, PingSource.scheduled);
    });

    test('always permission is also sufficient', () async {
      final svc = LocationService(
        batteryNet: _FakeBatteryNet(const BatteryNetworkSnapshot(80, 'wifi')),
        cellWifi: _FakeCellWifi(),
        geo: _FakeGeo(
          perm: LocationPermission.always,
          pos: _pos(lat: 1.0, lon: 2.0),
        ),
      );
      final p = await svc.getScheduledPing();
      expect(p.source, PingSource.scheduled);
    });
  });
}

class TimeoutException implements Exception {
  @override
  String toString() => 'TimeoutException';
}
