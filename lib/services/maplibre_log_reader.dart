import 'package:flutter/services.dart';

/// Pulls maplibre-native's internal log output captured by the Kotlin
/// `MapLibreLogTrap` (in `android/app/src/main/kotlin/.../`). Used by
/// the home-screen diagnostic overlay so we can see what the renderer
/// is complaining about without adb logcat.
class MapLibreLogReader {
  static const _channel =
      MethodChannel('com.dazeddingo.trail/maplibre_logs');

  /// Returns the most-recent ring-buffer entries (oldest first). The
  /// trap caps the buffer at 200 entries; tile-level errors typically
  /// fire one per failing tile so this is enough headroom for a few
  /// minutes of map use.
  static Future<List<String>> getRecent() async {
    try {
      final list = await _channel.invokeMethod<List<dynamic>>('getRecent');
      return list?.map((e) => e.toString()).toList(growable: false) ??
          const [];
    } catch (e) {
      return ['[failed to read maplibre logs: $e]'];
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod('clear');
    } catch (_) {
      // Trap doesn't exist (shouldn't happen on Android), swallow.
    }
  }
}
