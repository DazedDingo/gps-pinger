import 'package:flutter/services.dart' show rootBundle;

/// Builds the MapLibre style JSON for the offline map viewer.
///
/// Loads the bundled OSM Liberty `style.json` and substitutes the
/// `pmtiles://__TRAIL_ACTIVE_REGION__` placeholder with the right URL
/// for the active region — using the localhost HTTP server when an
/// MBTiles file is active (workaround for MapLibre Native 13.0.x's
/// broken local-file rendering on Android), or the native
/// `pmtiles://file://` form for PMTiles (in case the upstream fix
/// lands).
class TrailStyle {
  static const _placeholder = 'pmtiles://__TRAIL_ACTIVE_REGION__';
  static const _styleAsset = 'assets/maptiles/style.json';

  /// Sentinel path used by the Regions screen's diagnostic-mode button
  /// to flip the renderer to the public Protomaps demo PMTiles URL.
  /// Used to tell apart "renderer broken" from "local file broken"
  /// without writing native code.
  static const _diagnosticRemoteSentinel = '__remote_demo__';
  static const diagnosticRemoteSentinel = _diagnosticRemoteSentinel;

  /// Returns the style JSON string with the active region's URL
  /// substituted in. Returns `null` when no region is active — caller
  /// must render a placeholder instead of mounting the map.
  ///
  /// [tileServerPort] is the port from
  /// `LocalTileServer.instance` (via `tileServerProvider`); when
  /// non-null and the active region is an `.mbtiles`, the substitution
  /// points the source at `http://127.0.0.1:<port>/tilejson.json`
  /// instead of the broken `mbtiles://<path>` URL.
  static Future<String?> loadForRegion(
    String? activeRegionPath, {
    int? tileServerPort,
  }) async {
    if (activeRegionPath == null) return null;
    final raw = await rootBundle.loadString(_styleAsset);
    if (activeRegionPath == _diagnosticRemoteSentinel) {
      return raw.replaceAll(
        _placeholder,
        'pmtiles://https://demo-bucket.protomaps.com/v4.pmtiles',
      );
    }
    return substituteRegionPath(
      raw,
      activeRegionPath,
      tileServerPort: tileServerPort,
    );
  }

  /// Substitutes the bundled-style placeholder with the right MapLibre
  /// URL for the active region's file. Public for unit testing — same
  /// substitution used by [loadForRegion] but without touching the
  /// asset bundle.
  ///
  /// URL formats:
  ///   - `*.mbtiles` + [tileServerPort] non-null →
  ///     `http://127.0.0.1:<port>/tilejson.json` (the workaround path,
  ///     served by `LocalTileServer`).
  ///   - `*.mbtiles` + no port → `mbtiles:///<abs-path>` (native code
  ///     path; broken on Android 13.0.x but kept for parity).
  ///   - `*.pmtiles` → `pmtiles://file://<abs-path>` (also broken on
  ///     Android, kept for when the upstream fix lands).
  static String substituteRegionPath(
    String rawStyleJson,
    String activeRegionPath, {
    int? tileServerPort,
  }) {
    final lower = activeRegionPath.toLowerCase();
    final tileUrl = switch ((lower.endsWith('.mbtiles'), tileServerPort)) {
      // 0.8.0+46: bypass TileJSON entirely. The bundled style declares
      // `tiles: ["pmtiles://__TRAIL_ACTIVE_REGION__"]`; we substitute
      // the placeholder with a per-tile URL template so MapLibre
      // fetches MVT directly without a TileJSON round-trip.
      (true, final int port) =>
        'http://127.0.0.1:$port/{z}/{x}/{y}.pbf',
      (true, _) => 'mbtiles://$activeRegionPath',
      _ => 'pmtiles://file://$activeRegionPath',
    };
    // 0.8.0+49: glyphs and sprites also go through the loopback now.
    // maplibre_gl on Android can't read `asset://flutter_assets/...`
    // URLs (confirmed by the +48 log capture: "Could not read asset"
    // for every Roboto fontstack), and a missing-glyphs failure
    // cascades — maplibre cancels in-flight tile requests and
    // renders nothing. LocalTileServer now serves
    // `/glyphs/<fontstack>/<range>.pbf` and `/sprites/<name>` from
    // the bundled rootBundle, so we get a single delivery path the
    // renderer is happy with.
    final glyphsBase = tileServerPort != null
        ? 'http://127.0.0.1:$tileServerPort/glyphs'
        : 'asset://flutter_assets/assets/maptiles/glyphs';
    final spriteBase = tileServerPort != null
        ? 'http://127.0.0.1:$tileServerPort/sprites/osm-liberty'
        : 'asset://flutter_assets/assets/maptiles/sprites/osm-liberty';
    return rawStyleJson
        .replaceAll(_placeholder, tileUrl)
        .replaceAll('__TRAIL_GLYPHS__', glyphsBase)
        .replaceAll('__TRAIL_SPRITE__', spriteBase);
  }
}
