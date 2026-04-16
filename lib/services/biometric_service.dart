import 'package:local_auth/local_auth.dart';

/// Biometric unlock gate for the app.
///
/// Uses device-PIN as the mandatory fallback — see `AuthenticationOptions`
/// `biometricOnly: false`. If the user has no biometric enrolled we still
/// fall back to their lock screen credentials (pattern/PIN/password), which
/// is what the PLAN.md onboarding promises.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Returns true on successful authentication. Errors (user cancelled,
  /// lock-out, etc.) are surfaced as false — callers then keep the lock
  /// screen visible and offer a retry button.
  Future<bool> authenticate({String reason = 'Unlock Trail'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
