import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/ping_dao.dart';
import '../models/ping.dart';
import '../services/geocoding_service.dart';

/// All four providers share one `Database` handle (see [TrailDatabase.shared]).
/// Opening four SQLCipher connections in parallel on the home-screen build
/// raced Keystore key derivation + schema create on first install, which
/// surfaced as a generic "database exception" in 0.1.3.

/// Loads the N most recent pings. Re-runs on invalidation — call
/// `ref.invalidate(recentPingsProvider)` after an export or a manual
/// ping-now action.
final recentPingsProvider = FutureProvider<List<Ping>>((ref) async {
  final db = await TrailDatabase.shared();
  return PingDao(db).recent();
});

/// Full chronological (oldest-first) history. Used by the Phase 4 full
/// map screen where the time slider sweeps forward through the day — no
/// pagination, the entire `pings` table is loaded into memory once
/// because raster tiles are the byte-heavy thing, not 100-byte rows.
final allPingsProvider = FutureProvider<List<Ping>>((ref) async {
  final db = await TrailDatabase.shared();
  return PingDao(db).all();
});

/// Date-bounded chronological history. Same shape as
/// [allPingsProvider] but clipped at the SQL layer so a "last
/// weekend" filter doesn't round-trip the full `pings` table only to
/// drop most rows in Dart. Pass `null` to fall back to the unbounded
/// query — equivalent to `allPingsProvider` but goes through this
/// provider's family identity so the map screen can switch between
/// filtered and unfiltered without flipping providers.
final pingsByRangeProvider =
    FutureProvider.family<List<Ping>, DateTimeRange?>((ref, range) async {
  final db = await TrailDatabase.shared();
  final dao = PingDao(db);
  if (range == null) return dao.all();
  // The user-facing range is local-day; convert to UTC for the
  // SQL where-clause. End-of-day is `start-of-next-day - 1ms` so
  // a single-day filter actually catches the entire day.
  final startUtc = range.start.toUtc();
  final endUtc = range.end
      .add(const Duration(days: 1) - const Duration(milliseconds: 1))
      .toUtc();
  return dao.byDateRange(startUtc, endUtc);
});

/// Last successful fix (null-coord rows excluded). Feeds the home-screen
/// "last successful ping" card.
final lastSuccessfulPingProvider = FutureProvider<Ping?>((ref) async {
  final db = await TrailDatabase.shared();
  return PingDao(db).latestSuccessful();
});

/// Heartbeat health: red if `now - lastPingTs > 5h` (PLAN.md: 5h buffer on
/// the 4h cadence). Independent of success — any recent attempt counts,
/// since a `no_fix` row still proves the worker ran.
final heartbeatHealthyProvider = FutureProvider<bool>((ref) async {
  final db = await TrailDatabase.shared();
  final latest = await PingDao(db).latest();
  if (latest == null) return false;
  final age = DateTime.now().toUtc().difference(latest.timestampUtc);
  return age < const Duration(hours: 5);
});

/// Total ping count (all sources). Shown on home screen for confidence.
final pingCountProvider = FutureProvider<int>((ref) async {
  final db = await TrailDatabase.shared();
  return PingDao(db).count();
});

/// Singleton so callers can inject a fake in tests.
final geocodingServiceProvider = Provider<GeocodingService>(
  (ref) => GeocodingService(),
);

/// Reverse-geocoded label for ([lat], [lon]) — "Cambridge, MA" or similar.
/// Returns `null` when the system geocoder has nothing (no cache, no net).
/// Keyed by a rounded string so small GPS jitter doesn't blow out the cache
/// on every re-fetch.
final approxLocationProvider =
    FutureProvider.family<String?, ({double lat, double lon})>(
  (ref, coords) async {
    final svc = ref.watch(geocodingServiceProvider);
    return svc.reverseLookup(coords.lat, coords.lon);
  },
);
