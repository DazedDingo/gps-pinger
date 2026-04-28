import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_tile_server.dart';
import 'mbtiles_provider.dart';

/// Spins up [LocalTileServer.instance] for the active MBTiles region
/// and exposes the bound port. `null` when the active region is absent
/// or isn't an `.mbtiles` file (PMTiles still goes through the
/// `pmtiles://file://` URL — broken on the current native SDK, but we
/// keep the path open in case the upstream fix lands).
///
/// MapLibre Native 13.0.x silently fails to render tiles via
/// `mbtiles://` and `pmtiles://file://` on Android even when the file
/// is present and the style parses. The HTTP loopback works because
/// MapLibre's standard remote-tile path is in good shape — we proved
/// it with the Protomaps demo URL diagnostic.
final tileServerProvider = FutureProvider<int?>((ref) async {
  final region = await ref.watch(activeRegionProvider.future);
  final server = LocalTileServer.instance;
  if (region == null) {
    await server.stop();
    return null;
  }
  if (!region.path.toLowerCase().endsWith('.mbtiles')) {
    await server.stop();
    return null;
  }
  return server.start(region.path);
});
