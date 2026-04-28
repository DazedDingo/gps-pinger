import '../../models/ping.dart';
import '../home_location_service.dart';

/// Stats screen building blocks. Pure functions over `List<Ping>` so
/// each is unit-testable without a `WidgetTester` harness or a fake
/// DB. Every function copes with empty input — empty in, empty out —
/// because the stats screen mounts on a fresh install before any
/// fixes have arrived.
class StatsService {
  StatsService._();

  /// Counts pings per **local-day** date. Key is `DateTime(y, m, d)`
  /// at local midnight; value is the row count for that day. Used by
  /// the calendar-heatmap section. `no_fix` rows are included on
  /// purpose: even an attempt-without-fix is a sign the worker ran,
  /// which is the gist of the heatmap ("did Trail do anything that
  /// day").
  static Map<DateTime, int> dailyCounts(List<Ping> pings) {
    final out = <DateTime, int>{};
    for (final p in pings) {
      final local = p.timestampUtc.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      out[day] = (out[day] ?? 0) + 1;
    }
    return out;
  }

  /// Counts **successful** fixes per local hour 0-23. Returns a
  /// length-24 list, `result[h]` = fixes that fired between `h:00`
  /// and `h:59` local. Unlike [dailyCounts] this skips `no_fix`
  /// rows: the chart's intent is "when in the day are you actually
  /// out and about", and on motion-aware-skip phones the `no_fix`
  /// rows are dominated by stationary ticks that would flatten the
  /// pattern.
  static List<int> hourlyCounts(List<Ping> pings) {
    final out = List<int>.filled(24, 0);
    for (final p in pings) {
      if (p.lat == null || p.lon == null) continue;
      final local = p.timestampUtc.toLocal();
      out[local.hour]++;
    }
    return out;
  }

  /// Buckets pings on an [gridDeg]-degree lat/lon grid (default 0.01°
  /// ≈ 1.1 km at 50° N) and returns the [limit] most populous buckets,
  /// most-visited first. `no_fix` rows are skipped — we need real
  /// coords to bucket. The returned [PlaceBucket.lat]/[lon] is the
  /// bucket centre (so a UI can drop a pin at it).
  static List<PlaceBucket> topPlaces(
    List<Ping> pings, {
    int limit = 10,
    double gridDeg = 0.01,
  }) {
    final counts = <(int, int), int>{};
    for (final p in pings) {
      if (p.lat == null || p.lon == null) continue;
      final keyLat = (p.lat! / gridDeg).floor();
      final keyLon = (p.lon! / gridDeg).floor();
      final k = (keyLat, keyLon);
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) {
      final (kLat, kLon) = e.key;
      return PlaceBucket(
        lat: kLat * gridDeg + gridDeg / 2,
        lon: kLon * gridDeg + gridDeg / 2,
        count: e.value,
      );
    }).toList();
  }

  /// Detects "trips" — runs of consecutive pings strictly farther than
  /// [awayThresholdMeters] from [home]. A run becomes a trip only if
  /// it spans at least [minDuration] (default 6 h) — short out-and-back
  /// errands are not "trips".
  ///
  /// A single near-home ping ends a trip (no smoothing). With Trail's
  /// 30 min – 4 h cadences, a one-off near-home ping inside an away
  /// run is rare enough that the false-split rate is acceptable; the
  /// alternative (windowed mode-of-N filter) doubles the code and the
  /// gain is marginal. If users complain, revisit.
  static List<Trip> detectTrips(
    List<Ping> pings,
    HomeLocation home, {
    double awayThresholdMeters = 10000,
    Duration minDuration = const Duration(hours: 6),
  }) {
    final sorted = pings
        .where((p) => p.lat != null && p.lon != null)
        .toList(growable: false)
      ..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));

    final trips = <Trip>[];
    final current = <Ping>[];

    void flush() {
      if (current.isEmpty) return;
      final start = current.first.timestampUtc;
      final end = current.last.timestampUtc;
      if (end.difference(start) >= minDuration) {
        var maxDist = 0.0;
        var sumLat = 0.0;
        var sumLon = 0.0;
        for (final p in current) {
          final d = home.distanceMetersTo(p.lat!, p.lon!);
          if (d > maxDist) maxDist = d;
          sumLat += p.lat!;
          sumLon += p.lon!;
        }
        trips.add(Trip(
          startUtc: start,
          endUtc: end,
          maxDistanceMeters: maxDist,
          pingCount: current.length,
          centroidLat: sumLat / current.length,
          centroidLon: sumLon / current.length,
        ));
      }
      current.clear();
    }

    for (final p in sorted) {
      final isAway =
          home.distanceMetersTo(p.lat!, p.lon!) > awayThresholdMeters;
      if (isAway) {
        current.add(p);
      } else {
        flush();
      }
    }
    flush();

    // Most-recent-first reads better in the UI list.
    return trips.reversed.toList(growable: false);
  }
}

/// One row in the "Top places" leaderboard.
class PlaceBucket {
  final double lat;
  final double lon;
  final int count;

  const PlaceBucket({
    required this.lat,
    required this.lon,
    required this.count,
  });
}

/// One detected trip — a stretch of pings far from home.
class Trip {
  final DateTime startUtc;
  final DateTime endUtc;
  final double maxDistanceMeters;
  final int pingCount;
  final double centroidLat;
  final double centroidLon;

  const Trip({
    required this.startUtc,
    required this.endUtc,
    required this.maxDistanceMeters,
    required this.pingCount,
    required this.centroidLat,
    required this.centroidLon,
  });

  Duration get duration => endUtc.difference(startUtc);
}
