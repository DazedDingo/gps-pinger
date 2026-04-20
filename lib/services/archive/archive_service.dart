import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../db/database.dart';
import '../../db/ping_dao.dart';
import '../export/csv_exporter.dart';
import '../export/gpx_exporter.dart';

/// Format selector for the archive export. GPX is what OsmAnd /
/// other trail apps expect; CSV is the raw dump including all
/// Trail-specific columns (battery, cell, network). The archive
/// flow writes both by default so the user can pick on restore.
enum ArchiveFormat { gpxAndCsv, csvOnly, gpxOnly }

/// Summary of what [ArchiveService.preview] found — shown on the
/// Archive screen before the user confirms the destructive step.
class ArchivePreview {
  /// Row count that would be archived (`ts_utc < cutoffUtc`).
  final int count;
  /// Timestamp of the earliest row in the archive range, or `null`
  /// when [count] is zero.
  final DateTime? earliest;
  /// Timestamp of the latest row in the archive range, or `null`
  /// when [count] is zero. Always strictly before [cutoffUtc].
  final DateTime? latest;
  final DateTime cutoffUtc;

  const ArchivePreview({
    required this.count,
    required this.earliest,
    required this.latest,
    required this.cutoffUtc,
  });
}

/// Result of a successful archive run.
class ArchiveResult {
  /// Temp file paths produced by the selected [ArchiveFormat].
  /// Callers pass these straight to `share_plus` for the user to
  /// save to cloud storage / email / etc.
  final List<String> exportedFiles;
  /// Number of rows deleted from the DB after a successful export.
  final int deletedCount;

  const ArchiveResult({
    required this.exportedFiles,
    required this.deletedCount,
  });
}

/// Export-then-delete archive flow.
///
/// **Safety model:** the DB write is NOT atomic with the filesystem
/// write — SQLite transactions can't enlist external files. We
/// instead enforce order:
///   1. Query rows in range.
///   2. Build + persist the export file(s) to a temp directory.
///   3. Only after every write succeeds, delete the rows.
/// If step 2 throws for any file, step 3 is skipped and the DB is
/// untouched. Worst case the user ends up with an unused temp file,
/// never missing data.
///
/// Rows are read via the UI isolate's shared DB handle so we don't
/// race SQLCipher key derivation (the 0.1.3 bug — see CLAUDE.md).
class ArchiveService {
  /// Shows what would be archived without touching the DB.
  static Future<ArchivePreview> preview(DateTime cutoffUtc) async {
    final db = await TrailDatabase.shared();
    final dao = PingDao(db);
    final count = await dao.countOlderThan(cutoffUtc);
    if (count == 0) {
      return ArchivePreview(
        count: 0,
        earliest: null,
        latest: null,
        cutoffUtc: cutoffUtc,
      );
    }
    final rows = await dao.olderThan(cutoffUtc);
    return ArchivePreview(
      count: count,
      earliest: rows.first.timestampUtc,
      latest: rows.last.timestampUtc,
      cutoffUtc: cutoffUtc,
    );
  }

  /// Exports every ping with `ts_utc < cutoffUtc` to the requested
  /// format(s) in the temp directory, then deletes those rows.
  /// Returns the exported paths and the deleted row count.
  ///
  /// Throws [StateError] if there are no rows to archive — caller
  /// should gate on [preview] to avoid.
  static Future<ArchiveResult> archive({
    required DateTime cutoffUtc,
    ArchiveFormat format = ArchiveFormat.gpxAndCsv,
  }) async {
    final db = await TrailDatabase.shared();
    final dao = PingDao(db);
    final rows = await dao.olderThan(cutoffUtc);
    if (rows.isEmpty) {
      throw StateError('No pings to archive before $cutoffUtc');
    }

    final files = <String>[];
    // Write every requested format first — if ANY write throws, we
    // bail before deleting so the user never loses rows to a partial
    // export.
    if (format == ArchiveFormat.gpxAndCsv ||
        format == ArchiveFormat.gpxOnly) {
      files.add(await _writeExport(
        GpxExporter().build(rows),
        suffix: 'gpx',
        stampUtc: cutoffUtc,
      ));
    }
    if (format == ArchiveFormat.gpxAndCsv ||
        format == ArchiveFormat.csvOnly) {
      files.add(await _writeExport(
        CsvExporter().build(rows),
        suffix: 'csv',
        stampUtc: cutoffUtc,
      ));
    }

    final deleted = await dao.deleteOlderThan(cutoffUtc);
    return ArchiveResult(exportedFiles: files, deletedCount: deleted);
  }

  static Future<String> _writeExport(
    String content, {
    required String suffix,
    required DateTime stampUtc,
  }) async {
    final dir = await getTemporaryDirectory();
    final ymd = '${stampUtc.year.toString().padLeft(4, '0')}'
        '${stampUtc.month.toString().padLeft(2, '0')}'
        '${stampUtc.day.toString().padLeft(2, '0')}';
    final file = File(p.join(dir.path, 'trail_archive_before_$ymd.$suffix'));
    await file.writeAsString(content);
    return file.path;
  }
}

/// Testable overload of [ArchiveService.archive] for unit tests that
/// supply their own in-memory DB and temp dir rather than the shared
/// production path.
///
/// Not for UI use — call [ArchiveService.archive] instead.
Future<ArchiveResult> archiveWithHandle({
  required PingDao dao,
  required DateTime cutoffUtc,
  required Directory writeDir,
  ArchiveFormat format = ArchiveFormat.gpxAndCsv,
}) async {
  final rows = await dao.olderThan(cutoffUtc);
  if (rows.isEmpty) {
    throw StateError('No pings to archive before $cutoffUtc');
  }
  final files = <String>[];
  if (format == ArchiveFormat.gpxAndCsv || format == ArchiveFormat.gpxOnly) {
    files.add(await _writeTo(
      GpxExporter().build(rows),
      dir: writeDir,
      suffix: 'gpx',
      stampUtc: cutoffUtc,
    ));
  }
  if (format == ArchiveFormat.gpxAndCsv || format == ArchiveFormat.csvOnly) {
    files.add(await _writeTo(
      CsvExporter().build(rows),
      dir: writeDir,
      suffix: 'csv',
      stampUtc: cutoffUtc,
    ));
  }
  final deleted = await dao.deleteOlderThan(cutoffUtc);
  return ArchiveResult(exportedFiles: files, deletedCount: deleted);
}

Future<String> _writeTo(
  String content, {
  required Directory dir,
  required String suffix,
  required DateTime stampUtc,
}) async {
  final ymd = '${stampUtc.year.toString().padLeft(4, '0')}'
      '${stampUtc.month.toString().padLeft(2, '0')}'
      '${stampUtc.day.toString().padLeft(2, '0')}';
  final file = File(p.join(dir.path, 'trail_archive_before_$ymd.$suffix'));
  await file.writeAsString(content);
  return file.path;
}

