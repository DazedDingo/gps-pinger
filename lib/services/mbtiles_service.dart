import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single installed raster `.mbtiles` region.
///
/// `name` is the filename without extension — we don't parse the MBTiles
/// metadata table for a display name because tilemaker / OpenMapTiles
/// builds often leave `name` blank, and the user picked the filename
/// intentionally (e.g. "uk.mbtiles").
class MBTilesRegion {
  final String name;
  final String path;
  final int bytes;

  const MBTilesRegion({
    required this.name,
    required this.path,
    required this.bytes,
  });
}

/// Manages the on-device MBTiles library.
///
/// Storage layout:
///   `<appDocumentsDir>/mbtiles/<region>.mbtiles`
///
/// The active-region filename is kept in [SharedPreferences] under
/// [_activeKey] rather than in the encrypted DB — the choice of basemap
/// is a UX preference, not sensitive data, and we want it readable from
/// any isolate without plumbing.
///
/// **File sizes:** UK-wide raster MBTiles from tilemaker typically run
/// 200-600 MB. [install] copies the picked file into the app dir
/// because Android's SAF URIs can go stale (user deletes, moves to SD,
/// etc.); copying once makes offline use reliable across reboots and
/// SAF permission expiry.
class MBTilesService {
  static const _activeKey = 'trail_active_mbtiles_v1';
  static const _dirName = 'mbtiles';

  /// Lists every `.mbtiles` file currently installed. Returns `[]` if
  /// the directory doesn't exist yet (fresh install).
  static Future<List<MBTilesRegion>> listInstalled() async {
    final dir = await _ensureDir();
    if (!await dir.exists()) return const [];
    final entries = await dir.list().toList();
    final regions = <MBTilesRegion>[];
    for (final e in entries) {
      if (e is! File) continue;
      if (!e.path.toLowerCase().endsWith('.mbtiles')) continue;
      final stat = await e.stat();
      regions.add(MBTilesRegion(
        name: _nameFromPath(e.path),
        path: e.path,
        bytes: stat.size,
      ));
    }
    regions.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return regions;
  }

  /// Copies [sourcePath] into the MBTiles dir. Returns the installed
  /// region. Overwrites any existing region with the same filename —
  /// this is the user's explicit action via the picker, so "latest
  /// install wins" matches expectations.
  static Future<MBTilesRegion> install(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('Picked file does not exist: $sourcePath');
    }
    final dir = await _ensureDir();
    final filename = _filenameOnly(sourcePath);
    final dest = File('${dir.path}${Platform.pathSeparator}$filename');
    await src.copy(dest.path);
    final stat = await dest.stat();
    return MBTilesRegion(
      name: _nameFromPath(dest.path),
      path: dest.path,
      bytes: stat.size,
    );
  }

  /// Deletes a region from disk. If it was the active region, clears
  /// the active preference so the viewer falls back to OSM instead of
  /// pointing at a missing file.
  static Future<void> delete(MBTilesRegion region) async {
    final f = File(region.path);
    if (await f.exists()) await f.delete();
    final active = await getActive();
    if (active?.path == region.path) {
      await clearActive();
    }
  }

  static Future<void> setActive(MBTilesRegion region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, region.path);
  }

  static Future<void> clearActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }

  /// Returns the currently active region, or `null` if none is set /
  /// the file on disk is gone. We check existence rather than trusting
  /// the pref so a user who deletes the file from outside the app still
  /// gets a clean fallback to OSM.
  static Future<MBTilesRegion?> getActive() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_activeKey);
    if (path == null) return null;
    final f = File(path);
    if (!await f.exists()) {
      await prefs.remove(_activeKey);
      return null;
    }
    final stat = await f.stat();
    return MBTilesRegion(
      name: _nameFromPath(path),
      path: path,
      bytes: stat.size,
    );
  }

  static Future<Directory> _ensureDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _nameFromPath(String path) {
    final file = _filenameOnly(path);
    final idx = file.lastIndexOf('.');
    return idx <= 0 ? file : file.substring(0, idx);
  }

  static String _filenameOnly(String path) {
    final sep = path.contains(Platform.pathSeparator)
        ? Platform.pathSeparator
        : '/';
    final idx = path.lastIndexOf(sep);
    return idx < 0 ? path : path.substring(idx + 1);
  }
}
