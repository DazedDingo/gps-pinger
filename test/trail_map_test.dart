import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trail/models/ping.dart';
import 'package:trail/widgets/trail_map.dart';

Ping _fix({required DateTime ts, double lat = 42.37, double lon = -71.10}) =>
    Ping(
      timestampUtc: ts,
      lat: lat,
      lon: lon,
      source: PingSource.scheduled,
    );

Ping _noFix(DateTime ts) => Ping(
      timestampUtc: ts,
      source: PingSource.noFix,
    );

Future<void> _pumpWith(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: child),
    ),
  );
  // flutter_map kicks off async tile + layout work on first frame. Without
  // a settle pump, widget-tree assertions race the map's initial build and
  // intermittently can't find FlutterMap's child layers.
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('TrailMap', () {
    testWidgets('renders a helpful message when there are zero fixes',
        (tester) async {
      await _pumpWith(tester, const TrailMap(pings: []));
      expect(find.textContaining('No fixes yet'), findsOneWidget);
      // Placeholder path — no map should be built at all.
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('ignores rows without lat/lon when counting fixes',
        (tester) async {
      // Two no_fix rows + zero real fixes should hit the placeholder,
      // not render an empty map.
      await _pumpWith(
        tester,
        TrailMap(pings: [
          _noFix(DateTime.utc(2026, 4, 18, 10)),
          _noFix(DateTime.utc(2026, 4, 18, 18)),
        ]),
      );
      expect(find.textContaining('No fixes yet'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('renders a FlutterMap centered on a single fix',
        (tester) async {
      // A single fix is enough to drop a pin — no reason to hide the map.
      await _pumpWith(
        tester,
        TrailMap(pings: [_fix(ts: DateTime.utc(2026, 4, 18))]),
      );
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.textContaining('© OpenStreetMap'), findsOneWidget);
    });

    testWidgets('renders polyline + markers with multiple fixes',
        (tester) async {
      final pings = List.generate(
        5,
        (i) => _fix(
          ts: DateTime.utc(2026, 4, 18, i * 4),
          lat: 42.37 + i * 0.01,
          lon: -71.10 + i * 0.01,
        ),
      );
      await _pumpWith(tester, TrailMap(pings: pings));
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
    });

    testWidgets('handles degenerate bbox (all pings at one spot)',
        (tester) async {
      // Three fixes at identical coords — fitCamera mustn't NaN on a
      // zero-span LatLngBounds.
      final pings = List.generate(
        3,
        (i) => _fix(
          ts: DateTime.utc(2026, 4, 18, i * 4),
          lat: 42.37,
          lon: -71.10,
        ),
      );
      await _pumpWith(tester, TrailMap(pings: pings));
      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('has a recenter button in the corner', (tester) async {
      final pings = List.generate(
        3,
        (i) => _fix(
          ts: DateTime.utc(2026, 4, 18, i * 4),
          lat: 42.37 + i * 0.01,
          lon: -71.10 + i * 0.01,
        ),
      );
      await _pumpWith(tester, TrailMap(pings: pings));
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
    });
  });
}
