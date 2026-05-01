import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _homeMapHeightKey = 'trail_home_map_height_v1';

/// User-selectable vertical envelope for the inline `FullMapPanel` on
/// the home screen. 0.11.1 shipped a hard-coded 800 px which dominated
/// most viewports and squeezed the recent-pings list to nothing —
/// 0.11.2 makes it a three-step preset so users can dial it to their
/// device.
enum HomeMapHeight {
  compact(280, 'Compact'),
  standard(440, 'Standard'),
  large(640, 'Large');

  final double pixels;
  final String label;
  const HomeMapHeight(this.pixels, this.label);

  static HomeMapHeight fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return HomeMapHeight.standard;
  }
}

final homeMapHeightProvider =
    AsyncNotifierProvider<HomeMapHeightNotifier, HomeMapHeight>(
  HomeMapHeightNotifier.new,
);

class HomeMapHeightNotifier extends AsyncNotifier<HomeMapHeight> {
  @override
  Future<HomeMapHeight> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return HomeMapHeight.fromName(prefs.getString(_homeMapHeightKey));
    } catch (_) {
      return HomeMapHeight.standard;
    }
  }

  Future<void> set(HomeMapHeight v) async {
    state = AsyncData(v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_homeMapHeightKey, v.name);
    } catch (_) {
      // In-memory state is still correct; user can retry from
      // Settings if persistence failed transiently.
    }
  }
}
