import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/ping.dart';

/// Streaming CSV writer. Pure-Dart, no dependencies — keeps APK small.
class CsvExporter {
  /// Writes a CSV of [pings] to a temp file and returns the file path.
  Future<String> export(List<Ping> pings) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'trail_export_$ts.csv'));
    final sink = file.openWrite();
    sink.writeln(
      'timestamp_utc,lat,lon,accuracy_m,altitude_m,heading_deg,'
      'speed_mps,battery_pct,network_state,cell_id,wifi_ssid,source,note',
    );
    for (final pg in pings) {
      sink.writeln([
        pg.timestampUtc.toIso8601String(),
        pg.lat ?? '',
        pg.lon ?? '',
        pg.accuracy ?? '',
        pg.altitude ?? '',
        pg.heading ?? '',
        pg.speed ?? '',
        pg.batteryPct ?? '',
        _csvEscape(pg.networkState),
        _csvEscape(pg.cellId),
        _csvEscape(pg.wifiSsid),
        pg.source.dbValue,
        _csvEscape(pg.note),
      ].join(','));
    }
    await sink.flush();
    await sink.close();
    return file.path;
  }

  String _csvEscape(String? v) {
    if (v == null) return '';
    final needsQuote = v.contains(',') || v.contains('"') || v.contains('\n');
    if (!needsQuote) return v;
    final escaped = v.replaceAll('"', '""');
    return '"$escaped"';
  }
}
