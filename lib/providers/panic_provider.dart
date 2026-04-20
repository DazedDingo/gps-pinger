import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/panic/panic_service.dart';

/// User-configurable continuous-panic duration. Stored in secure storage so
/// it survives app restart but is still behind Keystore alongside the DB
/// passphrase — we don't want this leaking into backups unnecessarily.
const _durationKey = 'trail_panic_duration_v1';

final panicDurationProvider =
    AsyncNotifierProvider<PanicDurationNotifier, PanicDuration>(
  PanicDurationNotifier.new,
);

class PanicDurationNotifier extends AsyncNotifier<PanicDuration> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<PanicDuration> build() async {
    PanicDuration resolved;
    try {
      final raw = await _storage.read(key: _durationKey);
      resolved = _parse(raw) ?? PanicDuration.min30;
    } catch (_) {
      // Secure storage is flaky in test environments — fall back to the
      // default rather than breaking the UI on a transient read error.
      resolved = PanicDuration.min30;
    }
    // Ensure the native SharedPreferences mirror matches on every app
    // start, in case the user changed duration on one phone and restored
    // onto another before the first Settings-screen interaction.
    await PanicService.syncDurationToNative(resolved);
    return resolved;
  }

  Future<void> set(PanicDuration d) async {
    state = AsyncData(d);
    try {
      await _storage.write(key: _durationKey, value: d.name);
    } catch (_) {
      // Write failure is non-fatal — the in-memory state is still correct
      // and the user can retry on next panic. No point crashing here.
    }
    // Mirror to native SharedPreferences so the Phase 3 quick-settings
    // tile + home-screen widget start the FG service with the same
    // duration the Settings screen displays.
    await PanicService.syncDurationToNative(d);
  }

  PanicDuration? _parse(String? raw) {
    if (raw == null) return null;
    for (final d in PanicDuration.values) {
      if (d.name == raw) return d;
    }
    return null;
  }
}
