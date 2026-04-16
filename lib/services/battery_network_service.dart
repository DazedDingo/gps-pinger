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
      // connectivity_plus v6 returns a List — take the strongest available.
      if (results.contains(ConnectivityResult.wifi)) {
        net = 'wifi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        net = 'mobile';
      } else if (results.contains(ConnectivityResult.ethernet)) {
        net = 'ethernet';
      } else if (results.contains(ConnectivityResult.none)) {
        net = 'none';
      }
    } catch (_) {
      net = 'unknown';
    }
    return BatteryNetworkSnapshot(pct, net);
  }
}
