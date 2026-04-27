import 'package:flutter/services.dart' show rootBundle;

/// Builds the MapLibre style JSON for the offline map viewer.
///
/// Loads the bundled OSM Liberty `style.json` (already rewritten to use
/// `asset://` URLs for glyphs and sprites) and substitutes the
/// `__TRAIL_ACTIVE_REGION__` placeholder with the absolute `pmtiles://`
/// URL of the active region's file. The bundled style references no
/// remote resources — fully offline once a region is installed.
class TrailStyle {
  static const _placeholder = 'pmtiles://__TRAIL_ACTIVE_REGION__';
  static const _styleAsset = 'assets/maptiles/style.json';

  /// Returns the style JSON string with the active region's file path
  /// substituted in. Returns `null` when no region is active — caller
  /// must render a placeholder instead of mounting `MapLibreMap`.
  static Future<String?> loadForRegion(String? activeRegionPath) async {
    if (activeRegionPath == null) return null;
    final raw = await rootBundle.loadString(_styleAsset);
    return substituteRegionPath(raw, activeRegionPath);
  }

  /// Performs the placeholder substitution without touching the asset
  /// bundle — split out so unit tests can pin the exact URL format
  /// without spinning up a `WidgetTester`.
  ///
  /// The PMTiles URL form on Android is `pmtiles://file://<abs-path>`
  /// per the MapLibre Native Android 11.7+ docs — the bare
  /// `pmtiles://<abs-path>` form does *not* resolve on Android and
  /// silently renders as a tile-less white background. The conventional
  /// triple-slash arises because Android documents-dir paths begin with
  /// `/`, so `file://` + `/data/...` becomes `file:///data/...`.
  static String substituteRegionPath(String rawStyleJson, String activeRegionPath) =>
      rawStyleJson.replaceAll(_placeholder, 'pmtiles://file://$activeRegionPath');
}
