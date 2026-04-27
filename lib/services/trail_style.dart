import 'package:flutter/services.dart' show rootBundle;

/// Builds the MapLibre style JSON for the offline map viewer.
///
/// Loads the bundled OSM Liberty `style.json` and substitutes the
/// `pmtiles://__TRAIL_ACTIVE_REGION__` placeholder with the URL of the
/// active region's file — picking the right URL scheme based on the
/// file extension. The bundled style references no remote resources —
/// fully offline once a region is installed.
class TrailStyle {
  static const _placeholder = 'pmtiles://__TRAIL_ACTIVE_REGION__';
  static const _styleAsset = 'assets/maptiles/style.json';

  /// Returns the style JSON string with the active region's URL
  /// substituted in. Returns `null` when no region is active — caller
  /// must render a placeholder instead of mounting `MapLibreMap`.
  ///
  /// **Diagnostic mode:** if the active region's path is the sentinel
  /// `__remote_demo__` (set by the Regions screen's bug-icon button),
  /// substitute a public Protomaps demo URL. Used to tell apart
  /// "renderer broken" from "local file broken" without native code.
  static Future<String?> loadForRegion(String? activeRegionPath) async {
    if (activeRegionPath == null) return null;
    final raw = await rootBundle.loadString(_styleAsset);
    if (activeRegionPath == _diagnosticRemoteSentinel) {
      return raw.replaceAll(
        _placeholder,
        'pmtiles://https://demo-bucket.protomaps.com/v4.pmtiles',
      );
    }
    return substituteRegionPath(raw, activeRegionPath);
  }

  /// Sentinel path used to flip the renderer into the remote-PMTiles
  /// diagnostic mode. The Regions screen's "Use remote demo PMTiles"
  /// action stores this string as the active region path.
  static const _diagnosticRemoteSentinel = '__remote_demo__';
  static const diagnosticRemoteSentinel = _diagnosticRemoteSentinel;

  /// Substitutes the bundled-style placeholder with the right MapLibre
  /// URL for the active region's file. Public for unit testing — same
  /// substitution used by [loadForRegion] but without touching the
  /// asset bundle.
  ///
  /// URL formats per MapLibre Native:
  ///   - `*.mbtiles` → `mbtiles:///<abs-path>` (older, more battle-tested
  ///     code path on Android — works as of v11+)
  ///   - `*.pmtiles` → `pmtiles://file://<abs-path>` (added v11.7,
  ///     verified locally broken in maplibre 0.3.5 Flutter package on
  ///     Android — kept here for completeness and so a future plugin
  ///     fix can drop the MBTiles workaround)
  ///   - anything else (incl. `*.pmtiles` files) defaults to PMTiles
  ///     for backwards compatibility
  static String substituteRegionPath(
    String rawStyleJson,
    String activeRegionPath,
  ) {
    final lower = activeRegionPath.toLowerCase();
    final url = lower.endsWith('.mbtiles')
        ? 'mbtiles://$activeRegionPath'
        : 'pmtiles://file://$activeRegionPath';
    return rawStyleJson.replaceAll(_placeholder, url);
  }
}
