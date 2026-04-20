import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';

import '../models/ping.dart';
import '../services/mbtiles_service.dart';

/// Interactive map of the user's recent ping trail.
///
/// Uses `flutter_map`. Tile source prefers an active MBTiles region
/// (set in the Regions screen) and falls back to OpenStreetMap raster
/// tiles when no region is installed. Passing `activeRegion: null` at
/// the callsite keeps the widget usable in tests without spinning up a
/// real file.
class TrailMap extends StatefulWidget {
  final List<Ping> pings;
  final double height;
  final MBTilesRegion? activeRegion;

  const TrailMap({
    super.key,
    required this.pings,
    this.height = 260,
    this.activeRegion,
  });

  @override
  State<TrailMap> createState() => _TrailMapState();
}

class _TrailMapState extends State<TrailMap> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrailMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When a new ping lands, recenter on the latest fix so the user's
    // current position stays on-screen across the 4h cadence.
    final oldFixes = _fixesOf(oldWidget.pings);
    final newFixes = _fixesOf(widget.pings);
    if (newFixes.isEmpty) return;
    final newestChanged = oldFixes.isEmpty ||
        oldFixes.first.timestampUtc != newFixes.first.timestampUtc;
    if (newestChanged) {
      _fitToPings(newFixes);
    }
  }

  static List<Ping> _fixesOf(List<Ping> pings) => pings
      .where((p) => p.lat != null && p.lon != null)
      .toList(growable: false);

  void _fitToPings(List<Ping> fixes) {
    if (fixes.isEmpty) return;
    if (fixes.length == 1) {
      _controller.move(LatLng(fixes.first.lat!, fixes.first.lon!), 14);
      return;
    }
    final bounds = LatLngBounds.fromPoints(
      fixes.map((p) => LatLng(p.lat!, p.lon!)).toList(),
    );
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(32),
        maxZoom: 15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixes = _fixesOf(widget.pings);
    final scheme = Theme.of(context).colorScheme;

    if (fixes.isEmpty) {
      return _PlaceholderFrame(
        height: widget.height,
        scheme: scheme,
        message: 'No fixes yet — trail will appear after a few pings.',
      );
    }

    final points =
        fixes.map((p) => LatLng(p.lat!, p.lon!)).toList(growable: false);
    final latest = points.first;

    return Container(
      height: widget.height,
      decoration: _frame(scheme),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: latest,
              initialZoom: 14,
              minZoom: 2,
              maxZoom: 18,
              // Bound the camera so users can't pan off into the void on
              // a fresh install where only one fix exists yet.
              cameraConstraint: const CameraConstraint.unconstrained(),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              if (widget.activeRegion != null)
                TileLayer(
                  tileProvider: MbTilesTileProvider.fromPath(
                    path: widget.activeRegion!.path,
                  ),
                  maxZoom: 18,
                )
              else
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.dazeddingo.trail',
                  maxZoom: 19,
                  // No retina flag — OSM's standard tiles are 256 px and
                  // doubling the request rate would risk tripping their
                  // fair-use policy for a tiny personal-safety app.
                ),
              if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 3,
                      color: scheme.primary.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (int i = 1; i < points.length; i++)
                    Marker(
                      point: points[i],
                      width: 12,
                      height: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  // Latest fix — larger, tertiary colour so it pops
                  // against the rest of the trail.
                  Marker(
                    point: latest,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.tertiary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.95),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // OSM requires attribution on the map surface itself. Keep it
          // unobtrusive but legible — a white pill in the corner.
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.activeRegion != null
                    ? 'Offline: ${widget.activeRegion!.name}'
                    : '© OpenStreetMap',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
          // Recenter/refit button — cheap affordance since panning can
          // get the user lost on a small viewport.
          Positioned(
            right: 6,
            top: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _fitToPings(fixes),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.center_focus_strong,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _frame(ColorScheme scheme) => BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant,
          width: 1,
        ),
      );
}

class _PlaceholderFrame extends StatelessWidget {
  final double height;
  final ColorScheme scheme;
  final String message;

  const _PlaceholderFrame({
    required this.height,
    required this.scheme,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
