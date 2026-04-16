import 'package:flutter/services.dart';

/// Passive cell-tower ID + Wi-Fi SSID capture.
///
/// These fields are optional — the native plugin returns nulls when the
/// relevant permissions are missing or the radios are off. We NEVER trigger
/// active scans; everything here reads last-known state. See PLAN.md
/// "Battery budget" hard rules.
///
/// Implementation lives in native Kotlin (`CellWifiPlugin.kt`) because
/// `TelephonyManager.getAllCellInfo()` and `WifiManager.getConnectionInfo()`
/// have no Flutter plugin that matches our battery-first read-only contract.
class CellWifiService {
  static const _channel = MethodChannel('com.dazeddingo.trail/cell_wifi');

  /// Last-known primary cell ID as a string (e.g. "LTE:12345678"). Null if
  /// unavailable / permission denied / radio off.
  Future<String?> cellId() async {
    try {
      final v = await _channel.invokeMethod<String?>('getCellId');
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Last-known connected Wi-Fi SSID. Returns null if not connected, or the
  /// ACCESS_FINE_LOCATION permission was not granted (required on Android
  /// 10+ for SSID access).
  Future<String?> wifiSsid() async {
    try {
      final v = await _channel.invokeMethod<String?>('getWifiSsid');
      return v;
    } catch (_) {
      return null;
    }
  }
}
