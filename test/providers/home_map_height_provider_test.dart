import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trail/providers/home_map_height_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HomeMapHeight enum', () {
    test('fromName round-trips every shipped value', () {
      for (final v in HomeMapHeight.values) {
        expect(HomeMapHeight.fromName(v.name), v);
      }
    });

    test('fromName falls back to standard on null', () {
      expect(HomeMapHeight.fromName(null), HomeMapHeight.standard);
    });

    test('fromName falls back to standard on unknown', () {
      expect(HomeMapHeight.fromName('giant'), HomeMapHeight.standard);
      expect(HomeMapHeight.fromName(''), HomeMapHeight.standard);
    });

    test('pixel presets are monotonic and span the previous extremes', () {
      expect(HomeMapHeight.compact.pixels, lessThan(HomeMapHeight.standard.pixels));
      expect(HomeMapHeight.standard.pixels, lessThan(HomeMapHeight.large.pixels));
      // Standard sits between the previous 320 (too small) and 800
      // (too big) — the regression this preset is fixing.
      expect(HomeMapHeight.standard.pixels, greaterThan(320));
      expect(HomeMapHeight.standard.pixels, lessThan(800));
    });
  });

  group('homeMapHeightProvider', () {
    test('default is standard on a fresh install', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = await container.read(homeMapHeightProvider.future);
      expect(value, HomeMapHeight.standard);
    });

    test('reads a persisted value back on build', () async {
      SharedPreferences.setMockInitialValues({
        'trail_home_map_height_v1': HomeMapHeight.large.name,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = await container.read(homeMapHeightProvider.future);
      expect(value, HomeMapHeight.large);
    });

    test('unknown persisted value falls back to standard', () async {
      SharedPreferences.setMockInitialValues({
        'trail_home_map_height_v1': 'gigantic',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = await container.read(homeMapHeightProvider.future);
      expect(value, HomeMapHeight.standard);
    });

    test('set() updates state and persists for the next build', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Wait for the initial build before mutating.
      await container.read(homeMapHeightProvider.future);

      await container
          .read(homeMapHeightProvider.notifier)
          .set(HomeMapHeight.compact);
      expect(
        container.read(homeMapHeightProvider).asData?.value,
        HomeMapHeight.compact,
      );

      // Verify the write hit shared-prefs by rebuilding in a fresh
      // container against the same in-memory store.
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      final reloaded = await fresh.read(homeMapHeightProvider.future);
      expect(reloaded, HomeMapHeight.compact);
    });
  });
}
