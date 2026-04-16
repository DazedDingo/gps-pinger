import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/ping_dao.dart';
import '../models/ping.dart';

/// Loads the N most recent pings. Re-runs on invalidation — call
/// `ref.invalidate(recentPingsProvider)` after an export or a manual
/// ping-now action.
final recentPingsProvider = FutureProvider<List<Ping>>((ref) async {
  final db = await TrailDatabase.open();
  try {
    return PingDao(db).recent();
  } finally {
    await db.close();
  }
});

/// Last successful fix (null-coord rows excluded). Feeds the home-screen
/// "last successful ping" card.
final lastSuccessfulPingProvider = FutureProvider<Ping?>((ref) async {
  final db = await TrailDatabase.open();
  try {
    return PingDao(db).latestSuccessful();
  } finally {
    await db.close();
  }
});

/// Heartbeat health: red if `now - lastPingTs > 5h` (PLAN.md: 5h buffer on
/// the 4h cadence). Independent of success — any recent attempt counts,
/// since a `no_fix` row still proves the worker ran.
final heartbeatHealthyProvider = FutureProvider<bool>((ref) async {
  final db = await TrailDatabase.open();
  try {
    final latest = await PingDao(db).latest();
    if (latest == null) return false;
    final age = DateTime.now().toUtc().difference(latest.timestampUtc);
    return age < const Duration(hours: 5);
  } finally {
    await db.close();
  }
});

/// Total ping count (all sources). Shown on home screen for confidence.
final pingCountProvider = FutureProvider<int>((ref) async {
  final db = await TrailDatabase.open();
  try {
    return PingDao(db).count();
  } finally {
    await db.close();
  }
});
