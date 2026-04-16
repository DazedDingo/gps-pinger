import 'package:geolocator/geolocator.dart';

import '../models/ping.dart';
import 'battery_network_service.dart';
import 'cell_wifi_service.dart';

/// Wraps geolocator + ancillary sensors into a single "get a ping" call.
///
/// Critical battery invariants (PLAN.md "Hard rules"):
/// - Uses `LocationAccuracy.high`, never `best`, for scheduled fixes.
/// - Time-limited: honours a 2-minute budget, then returns null.
/// - Never leaves updates streaming. `getCurrentPosition` acquires once and
///   releases the underlying GPS client when the future completes.
/// - Cell / Wi-Fi reads are passive (see [CellWifiService]).
class LocationService {
  final BatteryNetworkService _batteryNet;
  final CellWifiService _cellWifi;

  LocationService({
    BatteryNetworkService? batteryNet,
    CellWifiService? cellWifi,
  })  : _batteryNet = batteryNet ?? BatteryNetworkService(),
        _cellWifi = cellWifi ?? CellWifiService();

  /// Attempts a single fix with [accuracy] inside a [timeout] budget.
  /// Returns a populated [Ping] (with `source`), or a `no_fix` Ping with the
  /// failure reason in `note` — callers should log both kinds.
  Future<Ping> getScheduledPing({
    PingSource source = PingSource.scheduled,
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final now = DateTime.now().toUtc();
    final bn = await _batteryNet.snapshot();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Ping(
        timestampUtc: now,
        batteryPct: bn.batteryPct,
        networkState: bn.networkState,
        source: PingSource.noFix,
        note: 'location_service_disabled',
      );
    }

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return Ping(
        timestampUtc: now,
        batteryPct: bn.batteryPct,
        networkState: bn.networkState,
        source: PingSource.noFix,
        note: 'permission_denied',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
      // Passive cell/Wi-Fi — best-effort, failures leave the fields null.
      final cellId = await _cellWifi.cellId();
      final ssid = await _cellWifi.wifiSsid();
      return Ping(
        timestampUtc: DateTime.fromMillisecondsSinceEpoch(
          pos.timestamp.millisecondsSinceEpoch,
          isUtc: true,
        ),
        lat: pos.latitude,
        lon: pos.longitude,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        heading: pos.heading,
        speed: pos.speed,
        batteryPct: bn.batteryPct,
        networkState: bn.networkState,
        cellId: cellId,
        wifiSsid: ssid,
        source: source,
      );
    } catch (e) {
      return Ping(
        timestampUtc: now,
        batteryPct: bn.batteryPct,
        networkState: bn.networkState,
        source: PingSource.noFix,
        note: 'fix_failed:${e.runtimeType}',
      );
    }
  }
}
