import 'package:flutter_test/flutter_test.dart';
import 'package:trail/services/scheduler/scheduler_mode.dart';

void main() {
  group('SchedulerEvent.fromJson', () {
    test('parses every field the Kotlin side emits', () {
      final ev = SchedulerEvent.fromJson({
        'tsMs': 1713600000000,
        'kind': 'EXACT_FIRED',
        'note': 'alarm delivered',
      });
      expect(ev.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1713600000000));
      expect(ev.kind, 'EXACT_FIRED');
      expect(ev.note, 'alarm delivered');
    });

    test('note is nullable (most events have no note attached)', () {
      final ev = SchedulerEvent.fromJson({
        'tsMs': 0,
        'kind': 'EXACT_SCHEDULED',
      });
      expect(ev.note, isNull);
    });

    test('tsMs accepts num (Kotlin may send Int or Long-as-double)', () {
      final fromInt = SchedulerEvent.fromJson(
          {'tsMs': 1713600000000, 'kind': 'x'});
      final fromDouble = SchedulerEvent.fromJson(
          {'tsMs': 1713600000000.0, 'kind': 'x'});
      expect(fromInt.timestamp, fromDouble.timestamp);
    });

    test('unknown / missing kind falls back to "unknown"', () {
      final ev = SchedulerEvent.fromJson({'tsMs': 0});
      expect(ev.kind, 'unknown');
    });
  });

  group('SchedulerMode.fromWire', () {
    test('"exact" → exact', () {
      expect(SchedulerMode.fromWire('exact'), SchedulerMode.exact);
    });

    test('"workmanager" → workmanager', () {
      expect(
        SchedulerMode.fromWire('workmanager'),
        SchedulerMode.workmanager,
      );
    });

    test('null defaults to workmanager (safe-by-default on fresh install)',
        () {
      expect(SchedulerMode.fromWire(null), SchedulerMode.workmanager);
    });

    test('garbage / legacy wire string defaults to workmanager', () {
      expect(
        SchedulerMode.fromWire('not-a-real-mode'),
        SchedulerMode.workmanager,
      );
    });
  });
}
