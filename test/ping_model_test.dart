import 'package:flutter_test/flutter_test.dart';
import 'package:trail/models/ping.dart';

void main() {
  group('PingSource', () {
    test('round-trips through DB value', () {
      for (final s in PingSource.values) {
        expect(PingSource.fromDb(s.dbValue), s);
      }
    });

    test('falls back to scheduled for unknown', () {
      expect(PingSource.fromDb('nonsense'), PingSource.scheduled);
    });
  });

  group('Ping serialization', () {
    test('toMap / fromMap round-trip', () {
      final t = DateTime.utc(2026, 4, 15, 12, 30);
      final p = Ping(
        timestampUtc: t,
        lat: 51.5,
        lon: -0.12,
        accuracy: 8.5,
        altitude: 20.0,
        heading: 45.0,
        speed: 1.2,
        batteryPct: 83,
        networkState: 'wifi',
        cellId: 'LTE:12345',
        wifiSsid: 'home',
        source: PingSource.scheduled,
        note: null,
      );
      final round = Ping.fromMap(p.toMap()..['id'] = 1);
      expect(round.lat, 51.5);
      expect(round.lon, -0.12);
      expect(round.batteryPct, 83);
      expect(round.source, PingSource.scheduled);
      expect(round.timestampUtc, t);
    });

    test('preserves no_fix rows with null coords', () {
      final p = Ping(
        timestampUtc: DateTime.utc(2026, 1, 1),
        batteryPct: 3,
        source: PingSource.noFix,
        note: 'skipped_low_battery',
      );
      final round = Ping.fromMap(p.toMap());
      expect(round.source, PingSource.noFix);
      expect(round.lat, isNull);
      expect(round.note, 'skipped_low_battery');
    });
  });
}
