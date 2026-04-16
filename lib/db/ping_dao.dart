import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/ping.dart';

/// Thin repository for the `pings` table.
///
/// Stateless — pass in a [Database] per call. Both the UI isolate and the
/// WorkManager background isolate instantiate their own DB handle, so a
/// cached static handle would cross isolate boundaries incorrectly.
class PingDao {
  final Database db;
  PingDao(this.db);

  Future<int> insert(Ping p) async {
    final map = p.toMap()..remove('id');
    return db.insert('pings', map);
  }

  /// Most-recent ping regardless of source. `null` on a brand-new install.
  Future<Ping?> latest() async {
    final rows = await db.query(
      'pings',
      orderBy: 'ts_utc DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Ping.fromMap(rows.first);
  }

  /// Most-recent successful fix — used by the "last successful ping" card
  /// on the home screen. Rejects `no_fix` and null-coord rows.
  Future<Ping?> latestSuccessful() async {
    final rows = await db.query(
      'pings',
      where: "source != 'no_fix' AND lat IS NOT NULL AND lon IS NOT NULL",
      orderBy: 'ts_utc DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Ping.fromMap(rows.first);
  }

  Future<List<Ping>> recent({int limit = 200}) async {
    final rows = await db.query(
      'pings',
      orderBy: 'ts_utc DESC',
      limit: limit,
    );
    return rows.map(Ping.fromMap).toList();
  }

  Future<List<Ping>> all() async {
    final rows = await db.query('pings', orderBy: 'ts_utc ASC');
    return rows.map(Ping.fromMap).toList();
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM pings');
    return (r.first['c'] as int?) ?? 0;
  }
}
