import 'package:permission_handler/permission_handler.dart';

/// Staged permission flow used by the onboarding screens.
///
/// Ordering matters: on Android 11+ the system will NOT prompt for
/// background-location until fine-location has been granted. Trying to
/// request them together silently collapses to "denied".
class PermissionsService {
  Future<PermissionStatus> requestFineLocation() =>
      Permission.location.request();

  Future<PermissionStatus> requestBackgroundLocation() =>
      Permission.locationAlways.request();

  Future<PermissionStatus> requestNotifications() =>
      Permission.notification.request();

  /// Pops the system "Ignore battery optimisation" dialog. No-op if already
  /// granted. Required so WorkManager runs survive deep Doze on some OEM
  /// skins (Samsung, Xiaomi).
  Future<PermissionStatus> requestIgnoreBatteryOptimizations() =>
      Permission.ignoreBatteryOptimizations.request();

  /// Phase 1 stub — the actual MethodChannel to request
  /// `SCHEDULE_EXACT_ALARM` lands in Phase 5 behind the dual-path scheduler.
  /// Here we only ensure the manifest permission is declared; the OS grants
  /// it by default on < Android 14.
  Future<void> touchScheduleExactAlarm() async {}

  /// Deep-links into the app's system settings page. Used when background
  /// location is "denied forever" and we can't re-prompt.
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
