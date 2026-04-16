import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trail/db/ping_dao.dart';
import 'package:trail/models/ping.dart';

/// In-memory sqflite-ffi harness. Schema mirrors production exactly (see
/// [TrailDatabase._onCreate]) — keep them in lock-step when bumping the
/// schema version.
Future<Database> _openMemDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE pings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ts_utc INTEGER NOT NULL,
      lat REAL,
      lon REAL,
      accuracy REAL,
      altitude REAL,
      heading REAL,
      speed REAL,
      battery_pct INTEGER,
      network_state TEXT,
      cell_id TEXT,
      wifi_ssid TEXT,
      source TEXT NOT NULL,
      note TEXT
    );
  ''');
  await db.execute('CREATE INDEX idx_pings_ts_utc ON pings(ts_utc DESC);');
  return db;
}

Ping _p(
  DateTime t, {
  double? lat,
  double? lon,
  PingSource source = PingSource.scheduled,
  String? note,
}) =>
    Ping(
      timestampUtc: t,
      lat: lat,
      lon: lon,
      source: source,
      note: note,
    );

void main() {
  late Database db;
  late PingDao dao;

  setUp(() async {
    db = await _openMemDb();
    dao = PingDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PingDao.insert', () {
    test('returns the generated rowid', () async {
      final id =
          await dao.insert(_p(DateTime.utc(2026, 1, 1), lat: 1.0, lon: 2.0));
      expect(id, isNonZero);
    });

    test('strips caller-provided id (autoincrement owns it)', () async {
      final ping = Ping(
        id: 999,
        timestampUtc: DateTime.utc(2026, 1, 1),
        lat: 1.0,
        lon: 2.0,
        source: PingSource.scheduled,
      );
      final id = await dao.insert(ping);
      // A fresh table starts at 1; if we didn't strip, this would be 999.
      expect(id, 1);
    });

    test('persists a no_fix row with null coords (gap visibility)', () async {
      final id = await dao.insert(_p(
        DateTime.utc(2026, 1, 1),
        source: PingSource.noFix,
        note: 'permission_denied',
      ));
      expect(id, isNonZero);
      final rows = await db.query('pings');
      expect(rows.first['lat'], isNull);
      expect(rows.first['source'], 'no_fix');
    });
  });

  group('PingDao.latest', () {
    test('returns null on an empty table', () async {
      expect(await dao.latest(), isNull);
    });

    test('returns the row with the greatest ts_utc', () async {
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10), lat: 1, lon: 2));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 12), lat: 3, lon: 4));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 11), lat: 5, lon: 6));
      final latest = await dao.latest();
      expect(latest!.timestampUtc, DateTime.utc(2026, 1, 1, 12));
      expect(latest.lat, 3);
    });

    test('no_fix rows are eligible — latest() does NOT filter by source',
        () async {
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10), lat: 1, lon: 2));
      await dao.insert(_p(
        DateTime.utc(2026, 1, 1, 12),
        source: PingSource.noFix,
        note: 'permission_denied',
      ));
      final latest = await dao.latest();
      expect(latest!.source, PingSource.noFix);
      expect(latest.lat, isNull);
    });
  });

  group('PingDao.latestSuccessful', () {
    test('returns null when every row is a no_fix', () async {
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10),
          source: PingSource.noFix, note: 'a'));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 12),
          source: PingSource.noFix, note: 'b'));
      expect(await dao.latestSuccessful(), isNull);
    });

    test(
        'skips a more-recent no_fix and returns the previous successful fix',
        () async {
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10), lat: 1, lon: 2));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 12),
          source: PingSource.noFix, note: 'boom'));
      final latest = await dao.latestSuccessful();
      expect(latest!.timestampUtc, DateTime.utc(2026, 1, 1, 10));
      expect(latest.lat, 1);
    });

    test('rejects rows with null lat/lon even if source is scheduled', () async {
      // Defensive — a scheduled row without coords shouldn't exist in theory,
      // but if a bug ever inserts one, the "last successful fix" card must
      // NOT treat it as successful.
      await dao.insert(Ping(
        timestampUtc: DateTime.utc(2026, 1, 1, 12),
        source: PingSource.scheduled,
        // lat/lon deliberately null
      ));
      expect(await dao.latestSuccessful(), isNull);
    });

    test('boot-source rows with coords ARE considered successful', () async {
      // A boot-triggered fix is as valid as any scheduled one.
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10),
          lat: 51.5, lon: -0.1, source: PingSource.boot));
      final latest = await dao.latestSuccessful();
      expect(latest, isNotNull);
      expect(latest!.source, PingSource.boot);
    });

    test('panic-source rows with coords ARE considered successful', () async {
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10),
          lat: 1, lon: 2, source: PingSource.panic));
      final latest = await dao.latestSuccessful();
      expect(latest, isNotNull);
      expect(latest!.source, PingSource.panic);
    });
  });

  group('PingDao.recent', () {
    test('returns rows in descending timestamp order', () async {
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10), lat: 1, lon: 1));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 12), lat: 2, lon: 2));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 11), lat: 3, lon: 3));
      final rows = await dao.recent();
      expect(rows.map((r) => r.timestampUtc).toList(), [
        DateTime.utc(2026, 1, 1, 12),
        DateTime.utc(2026, 1, 1, 11),
        DateTime.utc(2026, 1, 1, 10),
      ]);
    });

    test('default limit is 200 (battery: never deserialize more by default)',
        () async {
      // Insert 250 rows then ask for recent() with no args.
      final batch = db.batch();
      for (var i = 0; i < 250; i++) {
        batch.insert('pings', {
          'ts_utc': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch + i,
          'lat': 1.0,
          'lon': 2.0,
          'source': 'scheduled',
        });
      }
      await batch.commit(noResult: true);
      final rows = await dao.recent();
      expect(rows.length, 200);
    });

    test('custom limit is honoured', () async {
      for (var i = 0; i < 10; i++) {
        await dao.insert(_p(
          DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          lat: 1,
          lon: 2,
        ));
      }
      expect((await dao.recent(limit: 3)).length, 3);
    });

    test('empty table returns an empty list, not null', () async {
      expect(await dao.recent(), isEmpty);
    });
  });

  group('PingDao.all', () {
    test('returns rows in ASCENDING order (opposite of recent())', () async {
      // This asymmetry matters for exports — GPX readers expect
      // chronological order, not reverse. A regression that swapped this
      // would invert every exported track.
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 12), lat: 1, lon: 1));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 10), lat: 2, lon: 2));
      await dao.insert(_p(DateTime.utc(2026, 1, 1, 11), lat: 3, lon: 3));
      final rows = await dao.all();
      expect(rows.map((r) => r.timestampUtc).toList(), [
        DateTime.utc(2026, 1, 1, 10),
        DateTime.utc(2026, 1, 1, 11),
        DateTime.utc(2026, 1, 1, 12),
      ]);
    });

    test('returns EVERY row — no implicit limit on all()', () async {
      for (var i = 0; i < 300; i++) {
        await dao.insert(_p(
          DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          lat: 1,
          lon: 2,
        ));
      }
      expect((await dao.all()).length, 300);
    });
  });

  group('PingDao.count', () {
    test('returns 0 on an empty table', () async {
      expect(await dao.count(), 0);
    });

    test('counts every row regardless of source', () async {
      await dao.insert(_p(DateTime.utc(2026, 1, 1), lat: 1, lon: 2));
      await dao.insert(_p(DateTime.utc(2026, 1, 2),
          source: PingSource.noFix, note: 'x'));
      await dao.insert(_p(DateTime.utc(2026, 1, 3),
          source: PingSource.boot, note: 'device_boot'));
      expect(await dao.count(), 3);
    });
  });
}
