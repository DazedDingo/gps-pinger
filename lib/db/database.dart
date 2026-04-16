import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'keystore_key.dart';

/// Singleton wrapper around the encrypted SQLite database.
///
/// Two consumers:
/// 1. The Flutter UI isolate (main), which keeps a long-lived handle.
/// 2. The WorkManager background isolate, which opens + closes per job. That
///    isolate cannot share handles with the UI isolate because they live in
///    separate Dart VMs; each calls [TrailDatabase.open] independently.
///
/// We intentionally do NOT cache the DB handle statically — WorkManager kills
/// the isolate after each job and holding a reference risks lingering file
/// handles.
class TrailDatabase {
  static const _fileName = 'trail.db';
  static const _schemaVersion = 1;

  /// Open (or create) the encrypted DB. Caller owns the returned handle and
  /// is responsible for `close()`.
  static Future<Database> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _fileName);
    final passphrase = await KeystoreKey.getOrCreate();
    return openDatabase(
      path,
      password: passphrase,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
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
    await db.execute(
      'CREATE INDEX idx_pings_ts_utc ON pings(ts_utc DESC);',
    );
    await db.execute('''
      CREATE TABLE emergency_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone_e164 TEXT NOT NULL
      );
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // No-op in Phase 1 — schema is v1. Future phases append new tables /
    // ALTER statements here, guarded by oldVersion checks.
  }
}
