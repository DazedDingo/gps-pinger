import 'package:flutter_test/flutter_test.dart';
import 'package:trail/services/trail_style.dart';

void main() {
  group('TrailStyle.substituteRegionPath', () {
    test('PMTiles paths get pmtiles://file:// prefix', () {
      // Regression: 0.8.0+29 shipped without `file://` and rendered
      // tile-less white. MapLibre Native 11.7+ docs require
      // `pmtiles://file://<path>` for local PMTiles.
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

    test('MBTiles paths use bare mbtiles:// scheme (no file:// inner)', () {
      // MapLibre's MBTiles file source strips `mbtiles://` and reads
      // the rest as an absolute path directly — *not* layered on top of
      // `file://` like PMTiles. Adding `file://` here would break the
      // resolver, mirroring the PMTiles bug in reverse.
      const raw = '"url": "pmtiles://__TRAIL_ACTIVE_REGION__"';
      const path = '/data/user/0/com.dazeddingo.trail/files/tiles/gb.mbtiles';

      final out = TrailStyle.substituteRegionPath(raw, path);

      expect(
        out,
        contains('mbtiles:///data/user/0/com.dazeddingo.trail/'
            'files/tiles/gb.mbtiles'),
      );
      expect(out, isNot(contains('file://')));
      expect(out, isNot(contains('__TRAIL_ACTIVE_REGION__')));
    });

    test('extension match is case-insensitive', () {
      const raw = '"url": "pmtiles://__TRAIL_ACTIVE_REGION__"';
      expect(
        TrailStyle.substituteRegionPath(raw, '/x.MBTILES'),
        contains('mbtiles:///x.MBTILES'),
      );
      expect(
        TrailStyle.substituteRegionPath(raw, '/x.PMTiles'),
        contains('pmtiles://file:///x.PMTiles'),
      );
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
