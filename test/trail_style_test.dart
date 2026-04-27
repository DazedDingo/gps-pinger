import 'package:flutter_test/flutter_test.dart';
import 'package:trail/services/trail_style.dart';

void main() {
  group('TrailStyle.substituteRegionPath', () {
    test('inserts file:// before the absolute path', () {
      // Regression test: 0.8.0+29 shipped without `file://` and rendered
      // a tile-less white map on Android. MapLibre Native 11.7+ docs are
      // explicit that local PMTiles must use `pmtiles://file://<path>`.
      const raw = '"url": "pmtiles://__TRAIL_ACTIVE_REGION__"';
      const path = '/data/user/0/com.dazeddingo.trail/files/tiles/gb.pmtiles';

      final out = TrailStyle.substituteRegionPath(raw, path);

      expect(
        out,
        contains('pmtiles://file:///data/user/0/com.dazeddingo.trail/'
            'files/tiles/gb.pmtiles'),
      );
      expect(out, isNot(contains('__TRAIL_ACTIVE_REGION__')));
    });

    test('leaves a style without the placeholder unchanged', () {
      const raw = '{"layers":[]}';
      expect(TrailStyle.substituteRegionPath(raw, '/x.pmtiles'), raw);
    });

    test('replaces every occurrence (multiple sources, defensively)', () {
      const raw = 'a pmtiles://__TRAIL_ACTIVE_REGION__ b '
          'pmtiles://__TRAIL_ACTIVE_REGION__ c';
      final out = TrailStyle.substituteRegionPath(raw, '/r.pmtiles');
      expect(
        out,
        'a pmtiles://file:///r.pmtiles b pmtiles://file:///r.pmtiles c',
      );
    });
  });
}
