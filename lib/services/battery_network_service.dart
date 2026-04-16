import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Snapshot of battery + network state, captured per-ping.
class BatteryNetworkSnapshot {
  final int? batteryPct;
  final String networkState;
  const BatteryNetworkSnapshot(this.batteryPct, this.networkState);
}

/// Passive reads only. No listeners registered, no scan-triggering calls.
/// Must be cheap — this runs inside every 4h worker wake.
class BatteryNetworkService {
  Future<BatteryNetworkSnapshot> snapshot() async {
    int? pct;
    try {
      pct = await Battery().batteryLevel;
    } catch (_) {
      pct = null;
    }
    String net = 'unknown';
    try {
      final results = await Connectivity().checkConnectivity();
      net = pickNetworkLabel(results);
    } catch (_) {
      net = 'unknown';
    }
    return BatteryNetworkSnapshot(pct, net);
  }

  /// Picks the best label for a set of concurrent connectivity results.
  /// connectivity_plus v6 returns a list because a device can have e.g.
  /// wifi + mobile simultaneously; we pick the strongest/cheapest for the
  /// user. Priority: wifi > mobile > ethernet > none.
  ///
  /// Pure function, exposed for testing — this is the only network-state
  /// decision the app makes on every wake.
  static String pickNetworkLabel(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'wifi';
    if (results.contains(ConnectivityResult.mobile)) return 'mobile';
    if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
    if (results.contains(ConnectivityResult.none)) return 'none';
    return 'unknown';
  }
}
