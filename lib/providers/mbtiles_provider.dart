import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mbtiles_service.dart';

/// List of every `.mbtiles` region installed in the app documents dir.
///
/// Invalidate after install/delete to refresh the Regions screen.
final installedRegionsProvider = FutureProvider<List<MBTilesRegion>>((ref) {
  return MBTilesService.listInstalled();
});

/// Currently active region, or `null` when the user hasn't chosen one
/// (or the file is missing from disk). The viewer uses this to decide
/// between a local MBTiles tile source and the online OSM TileLayer.
final activeRegionProvider = FutureProvider<MBTilesRegion?>((ref) {
  return MBTilesService.getActive();
});
