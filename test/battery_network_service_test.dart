import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trail/services/battery_network_service.dart';

void main() {
  group('BatteryNetworkService.pickNetworkLabel', () {
    test('wifi wins over mobile — cheaper + stronger for the user', () {
      expect(
        BatteryNetworkService.pickNetworkLabel(
            [ConnectivityResult.mobile, ConnectivityResult.wifi]),
        'wifi',
      );
    });

    test('wifi wins over ethernet + mobile combined', () {
      expect(
        BatteryNetworkService.pickNetworkLabel([
          ConnectivityResult.ethernet,
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
        'wifi',
      );
    });

    test('mobile wins over ethernet when wifi is absent', () {
      expect(
        BatteryNetworkService.pickNetworkLabel(
            [ConnectivityResult.ethernet, ConnectivityResult.mobile]),
        'mobile',
      );
    });

    test('single-mode lists return that mode', () {
      expect(BatteryNetworkService.pickNetworkLabel([ConnectivityResult.wifi]),
          'wifi');
      expect(
          BatteryNetworkService.pickNetworkLabel([ConnectivityResult.mobile]),
          'mobile');
      expect(
          BatteryNetworkService.pickNetworkLabel(
              [ConnectivityResult.ethernet]),
          'ethernet');
      expect(BatteryNetworkService.pickNetworkLabel([ConnectivityResult.none]),
          'none');
    });

    test('empty list → unknown (distinct from "none")', () {
      // "none" means radios on + no network. Empty list is the API failing
      // to tell us anything — we must not confuse the two.
      expect(BatteryNetworkService.pickNetworkLabel([]), 'unknown');
    });

    test(
        '`none` never outranks a real connection — guards against a regression '
        'where `none` in a mixed list would shadow wifi/mobile', () {
      expect(
        BatteryNetworkService.pickNetworkLabel(
            [ConnectivityResult.none, ConnectivityResult.wifi]),
        'wifi',
      );
      expect(
        BatteryNetworkService.pickNetworkLabel(
            [ConnectivityResult.none, ConnectivityResult.mobile]),
        'mobile',
      );
    });

    test('unknown ConnectivityResult values (e.g. bluetooth/vpn) → unknown',
        () {
      // connectivity_plus enumerates bluetooth/vpn/other but we don't
      // choose labels for them; they should fall through to "unknown",
      // not crash.
      expect(
        BatteryNetworkService.pickNetworkLabel([ConnectivityResult.bluetooth]),
        'unknown',
      );
      expect(
        BatteryNetworkService.pickNetworkLabel([ConnectivityResult.vpn]),
        'unknown',
      );
    });

    test('return values are the exact strings CSV/GPX exporters emit', () {
      // Changing these silently would break historical export files — the
      // whole point of the 4h log is time-comparable rows.
      expect(BatteryNetworkService.pickNetworkLabel([ConnectivityResult.wifi]),
          'wifi');
      expect(
          BatteryNetworkService.pickNetworkLabel([ConnectivityResult.mobile]),
          'mobile');
      expect(
          BatteryNetworkService.pickNetworkLabel(
              [ConnectivityResult.ethernet]),
          'ethernet');
      expect(BatteryNetworkService.pickNetworkLabel([ConnectivityResult.none]),
          'none');
    });
  });
}
