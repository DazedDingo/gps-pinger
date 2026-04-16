import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Whether the user has completed the first-run onboarding flow.
///
/// Stored in secure storage so it survives app upgrades but not reinstall.
/// A `ValueNotifier` wrapped via `StateProvider` so the router can
/// synchronously read it inside `redirect` without async plumbing.
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

class OnboardingGate {
  static const _key = 'trail_onboarded_v1';
  static final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> isComplete() async {
    try {
      final v = await _secure.read(key: _key);
      return v == '1';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markComplete() async {
    try {
      await _secure.write(key: _key, value: '1');
    } catch (e) {
      debugPrint('[OnboardingGate] persist failed: $e');
    }
  }
}
