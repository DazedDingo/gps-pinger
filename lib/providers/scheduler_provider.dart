import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/scheduler/scheduler_mode.dart';

/// Current scheduling mode (WorkManager vs exact alarms).
final schedulerModeProvider = FutureProvider<SchedulerMode>((ref) {
  return SchedulerModeStore.get();
});

/// API 31+ exact-alarm permission state — `true` on API < 31 because
/// the permission didn't exist there (manifest grant covers it).
final exactAlarmPermissionProvider = FutureProvider<bool>((ref) {
  return ExactAlarmBridge.canScheduleExactAlarms();
});

/// Last 20 scheduler events, newest-first. Invalidated after every
/// mode switch and every UI-triggered ping so the Settings screen
/// always shows the freshest timeline.
final schedulerEventsProvider = FutureProvider<List<SchedulerEvent>>((ref) {
  return ExactAlarmBridge.recentEvents();
});
