import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/ping.dart';
import '../providers/mbtiles_provider.dart';
import '../providers/pings_provider.dart';
import '../services/mbtiles_service.dart';

/// Full-screen history map with time slider + path toggle + bbox-fit.
///
/// Tile source preference, in order:
///   1. Active MBTiles region (fully offline) — picked in Regions screen.
///   2. OpenStreetMap online tiles — fallback when nothing is installed.
///
/// The time slider filters pings down to those logged at-or-before the
/// slider's timestamp; dragging it back in time rewinds the trail. This
/// is the cheapest way to give the user a feel for movement across a
/// day / week without shipping a full playback animation.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _controller = MapController();
  bool _showPath = true;
  DateTime? _sliderMax;
  bool _initialFitDone = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pingsAsync = ref.watch(allPingsProvider);
    final activeRegion = ref.watch(activeRegionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trail map'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            tooltip: _showPath ? 'Hide path line' : 'Show path line',
            icon: Icon(_showPath ? Icons.timeline : Icons.scatter_plot),
            onPressed: () => setState(() => _showPath = !_showPath),
          ),
          IconButton(
            tooltip: 'Regions',
            icon: const Icon(Icons.layers_outlined),
            onPressed: () => context.go('/regions'),
          ),
        ],
      ),
      body: pingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pings) {
          // `allPingsProvider` returns oldest-first. Drop null-coord
          // rows up front so the slider's visibleCount reflects real
          // fixes, not "no_fix"/boot rows that never plot anywhere.
          final fixes = pings
              .where((p) => p.lat != null && p.lon != null)
              .toList(growable: false);
          if (fixes.isEmpty) {
            return const _EmptyState();
          }
          return _buildMap(context, fixes, activeRegion.valueOrNull);
        },
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    List<Ping> fixes,
    MBTilesRegion? region,
  ) {
    // Already chronological (oldest-first) thanks to allPingsProvider.
    final chrono = fixes;
    final first = chrono.first.timestampUtc;
    final last = chrono.last.timestampUtc;
    final sliderMax = _sliderMax ?? last;
    final visible = chrono
        .where((p) => !p.timestampUtc.isAfter(sliderMax))
        .toList(growable: false);

    final points =
        visible.map((p) => LatLng(p.lat!, p.lon!)).toList(growable: false);
    final scheme = Theme.of(context).colorScheme;
    final hasMultiple = points.length >= 2;
    final latest = points.isNotEmpty ? points.last : null;

    // Lazy bbox-fit after first paint. `addPostFrameCallback` is the
    // only safe place to touch MapController in initial build.
    if (!_initialFitDone && points.isNotEmpty) {
      _initialFitDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
    }

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: latest ?? const LatLng(0, 0),
              initialZoom: 13,
              minZoom: 2,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              _tileLayer(region),
              if (_showPath && hasMultiple)
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
                  for (int i = 0; i < points.length - 1; i++)
                    Marker(
                      point: points[i],
                      width: 10,
                      height: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  if (latest != null)
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
              _attribution(region),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _fit(points),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.center_focus_strong,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _TimeSlider(
          first: first,
          last: last,
          current: sliderMax,
          visibleCount: visible.length,
          totalCount: chrono.length,
          onChanged: (v) => setState(() => _sliderMax = v),
          onReset: () => setState(() => _sliderMax = null),
        ),
      ],
    );
  }

  Widget _tileLayer(MBTilesRegion? region) {
    if (region != null) {
      return TileLayer(
        tileProvider: MbTilesTileProvider.fromPath(path: region.path),
        maxZoom: 18,
      );
    }
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.dazeddingo.trail',
      maxZoom: 19,
    );
  }

  Widget _attribution(MBTilesRegion? region) {
    final text = region != null
        ? 'Offline: ${region.name}'
        : '© OpenStreetMap';
    return Positioned(
      left: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }

  void _fit(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.first, 14);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
        maxZoom: 15,
      ),
    );
  }
}

class _TimeSlider extends StatelessWidget {
  final DateTime first;
  final DateTime last;
  final DateTime current;
  final int visibleCount;
  final int totalCount;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onReset;

  const _TimeSlider({
    required this.first,
    required this.last,
    required this.current,
    required this.visibleCount,
    required this.totalCount,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = last.millisecondsSinceEpoch - first.millisecondsSinceEpoch;
    final currentMs = current.millisecondsSinceEpoch - first.millisecondsSinceEpoch;
    // If all pings happened at the exact same millisecond (test fixtures,
    // fresh install with one ping), the slider has nothing to slide.
    final disabled = totalMs <= 0;
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM d, HH:mm');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${fmt.format(current.toLocal())} · '
                  '$visibleCount / $totalCount fixes shown',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(onPressed: onReset, child: const Text('Latest')),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
            ),
            child: Slider(
              min: 0,
              max: totalMs <= 0 ? 1 : totalMs.toDouble(),
              value: disabled
                  ? 0
                  : currentMs.clamp(0, totalMs).toDouble(),
              onChanged: disabled
                  ? null
                  : (v) => onChanged(
                        first.add(Duration(milliseconds: v.toInt())),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          'No fixes yet — trail will appear after a few pings.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
