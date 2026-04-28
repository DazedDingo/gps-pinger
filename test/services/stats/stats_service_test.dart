import 'package:flutter_test/flutter_test.dart';
import 'package:trail/models/ping.dart';
import 'package:trail/services/home_location_service.dart';
import 'package:trail/services/stats/stats_service.dart';

Ping _ping(
  DateTime ts, {
  double? lat,
  double? lon,
  PingSource source = PingSource.scheduled,
}) =>
    Ping(
      timestampUtc: ts.toUtc(),
      lat: lat,
      lon: lon,
      source: source,
    );

void main() {
  group('StatsService.dailyCounts', () {
    test('empty input returns empty map', () {
      expect(StatsService.dailyCounts(const []), isEmpty);
    });

    test('groups by local-day midnight', () {
      final base = DateTime(2026, 4, 28, 14);
      final pings = [
        _ping(base),
        _ping(base.add(const Duration(hours: 2))),
        _ping(base.add(const Duration(days: 1))),
      ];
      final counts = StatsService.dailyCounts(pings);
      expect(counts.length, 2);
      expect(counts[DateTime(2026, 4, 28)], 2);
      expect(counts[DateTime(2026, 4, 29)], 1);
    });

    test('counts no_fix rows alongside successful fixes', () {
      final base = DateTime(2026, 4, 28, 9);
      final counts = StatsService.dailyCounts([
        _ping(base, lat: 1, lon: 2),
        _ping(base.add(const Duration(hours: 1)), source: PingSource.noFix),
      ]);
      expect(counts[DateTime(2026, 4, 28)], 2);
    });
  });

  group('StatsService.hourlyCounts', () {
    test('empty input is 24 zeros', () {
      final h = StatsService.hourlyCounts(const []);
      expect(h.length, 24);
      expect(h.every((c) => c == 0), isTrue);
    });

    test('buckets successful fixes into the local-hour slot', () {
      final pings = [
        _ping(DateTime(2026, 4, 28, 9, 0), lat: 1, lon: 2),
        _ping(DateTime(2026, 4, 28, 9, 59), lat: 1, lon: 2),
        _ping(DateTime(2026, 4, 28, 14, 0), lat: 1, lon: 2),
      ];
      final h = StatsService.hourlyCounts(pings);
      expect(h[9], 2);
      expect(h[14], 1);
      expect(h[10], 0);
    });

    test('skips no_fix rows so motion-aware skips don\'t flatten the chart',
        () {
      final pings = [
        _ping(DateTime(2026, 4, 28, 9, 0), lat: 1, lon: 2),
        _ping(DateTime(2026, 4, 28, 9, 30), source: PingSource.noFix),
        _ping(DateTime(2026, 4, 28, 11, 0), lat: 1, lon: 2),
      ];
      final h = StatsService.hourlyCounts(pings);
      expect(h[9], 1);
      expect(h[11], 1);
    });
  });

  group('StatsService.topPlaces', () {
    test('empty input returns empty list', () {
      expect(StatsService.topPlaces(const []), isEmpty);
    });

    test('skips rows without coordinates', () {
      final out = StatsService.topPlaces([
        _ping(DateTime(2026, 4, 28), source: PingSource.noFix),
      ]);
      expect(out, isEmpty);
    });

    test('groups jittered fixes into the same bucket', () {
      final ts = DateTime(2026, 4, 28);
      // 0.01° grid; all four fall inside the same cell.
      final pings = [
        _ping(ts, lat: 52.201, lon: 0.121),
        _ping(ts, lat: 52.205, lon: 0.123),
        _ping(ts, lat: 52.209, lon: 0.129),
        _ping(ts, lat: 52.200, lon: 0.120),
      ];
      final out = StatsService.topPlaces(pings);
      expect(out.length, 1);
      expect(out.first.count, 4);
      // Centroid is the bucket centre — between [52.20, 52.21).
      expect(out.first.lat, closeTo(52.205, 1e-9));
      expect(out.first.lon, closeTo(0.125, 1e-9));
    });

    test('sorts by count descending and clamps to limit', () {
      final ts = DateTime(2026, 4, 28);
      final pings = <Ping>[
        for (var i = 0; i < 5; i++) _ping(ts, lat: 51.50, lon: -0.10), // A x 5
        for (var i = 0; i < 3; i++) _ping(ts, lat: 51.51, lon: -0.10), // B x 3
        for (var i = 0; i < 1; i++) _ping(ts, lat: 51.52, lon: -0.10), // C x 1
      ];
      final top2 = StatsService.topPlaces(pings, limit: 2);
      expect(top2.length, 2);
      expect(top2[0].count, 5);
      expect(top2[1].count, 3);
    });
  });

  group('StatsService.detectTrips', () {
    final home = HomeLocation(
      lat: 52.205,
      lon: 0.119,
      savedAtUtc: DateTime(2026, 1, 1).toUtc(),
    );

    Ping awayPing(DateTime ts) =>
        // Edinburgh is ~430 km from the Cambridge home — far enough to be
        // unambiguous against the 10 km away threshold.
        _ping(ts, lat: 55.9533, lon: -3.1883);
    Ping homePing(DateTime ts) => _ping(ts, lat: 52.205, lon: 0.119);

    test('empty input returns empty list', () {
      expect(StatsService.detectTrips(const [], home), isEmpty);
    });

    test('skips runs shorter than minDuration', () {
      // A 4 h trip with default minDuration of 6 h should not register.
      final base = DateTime(2026, 4, 1, 10);
      final pings = [
        homePing(base.subtract(const Duration(hours: 1))),
        awayPing(base),
        awayPing(base.add(const Duration(hours: 4))),
        homePing(base.add(const Duration(hours: 5))),
      ];
      expect(StatsService.detectTrips(pings, home), isEmpty);
    });

    test('records a multi-day trip with metadata', () {
      final start = DateTime(2026, 4, 1, 10);
      final pings = <Ping>[
        homePing(start.subtract(const Duration(hours: 1))),
        for (var i = 0; i <= 24; i++)
          awayPing(start.add(Duration(hours: i * 4))),
        homePing(start.add(const Duration(days: 5))),
      ];
      final trips = StatsService.detectTrips(pings, home);
      expect(trips.length, 1);
      final t = trips.single;
      expect(t.pingCount, 25);
      expect(t.duration.inHours, greaterThanOrEqualTo(96));
      // Edinburgh from Cambridge is ~430 km.
      expect(t.maxDistanceMeters, greaterThan(400000));
      expect(t.centroidLat, closeTo(55.9533, 1e-6));
    });

    test('most-recent trip listed first', () {
      final pings = <Ping>[
        // Trip 1 (Apr 1, two-day trip)
        for (var i = 0; i <= 12; i++)
          awayPing(DateTime(2026, 4, 1, 10).add(Duration(hours: i * 4))),
        homePing(DateTime(2026, 4, 5, 10)),
        // Trip 2 (Apr 10, two-day trip)
        for (var i = 0; i <= 12; i++)
          awayPing(DateTime(2026, 4, 10, 10).add(Duration(hours: i * 4))),
        homePing(DateTime(2026, 4, 14, 10)),
      ];
      final trips = StatsService.detectTrips(pings, home);
      expect(trips.length, 2);
      expect(trips.first.startUtc.month, 4);
      expect(trips.first.startUtc.day, 10);
      expect(trips.last.startUtc.day, 1);
    });

    test('respects custom away threshold', () {
      // 2 km from home: outside the 1 km threshold but inside 10 km.
      final ts = DateTime(2026, 4, 1, 10);
      final pings = <Ping>[
        for (var i = 0; i <= 24; i++)
          _ping(
            ts.add(Duration(hours: i)),
            lat: 52.225,
            lon: 0.119,
          ),
      ];
      // 10 km default → no trip detected.
      expect(StatsService.detectTrips(pings, home), isEmpty);
      // 1 km override → one trip detected.
      final tripsTight = StatsService.detectTrips(
        pings,
        home,
        awayThresholdMeters: 1000,
      );
      expect(tripsTight.length, 1);
    });
  });
}
