import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trail/services/mbtiles_service.dart';

/// Fake path_provider that points `getApplicationDocumentsDirectory()`
/// at a temp dir so [MBTilesService] can create its `mbtiles/` subdir
/// without touching the real app docs directory.
class _TempDocsPathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _TempDocsPathProvider(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late Directory tempRoot;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempRoot = await Directory.systemTemp.createTemp('mbtiles_svc_test_');
    PathProviderPlatform.instance = _TempDocsPathProvider(tempRoot.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  /// Writes a fake `.mbtiles` file (just arbitrary bytes) and returns
  /// its path. Size coming back from `listInstalled` uses the file's
  /// real byte count, which is what [makeFake] writes.
  Future<String> makeFake(String name, {int size = 64}) async {
    final f = File('${tempRoot.path}${Platform.pathSeparator}$name');
    await f.writeAsBytes(List<int>.filled(size, 0));
    return f.path;
  }

  group('MBTilesService.listInstalled', () {
    test('returns empty list on a fresh install (no installed regions)',
        () async {
      final regions = await MBTilesService.listInstalled();
      expect(regions, isEmpty);
    });

    test('skips non-mbtiles files in the regions directory', () async {
      final sourceMbtiles = await makeFake('uk.mbtiles', size: 128);
      await MBTilesService.install(sourceMbtiles);
      // Drop a stray non-mbtiles file into the regions dir — listInstalled
      // should ignore it rather than reporting it as a broken region.
      final stray = File(
        '${tempRoot.path}${Platform.pathSeparator}mbtiles'
        '${Platform.pathSeparator}readme.txt',
      );
      await stray.writeAsString('hello');

      final regions = await MBTilesService.listInstalled();
      expect(regions, hasLength(1));
      expect(regions.first.name, 'uk');
    });

    test('sorts regions alphabetically (case-insensitive)', () async {
      await MBTilesService.install(await makeFake('Zulu.mbtiles'));
      await MBTilesService.install(await makeFake('alpha.mbtiles'));
      await MBTilesService.install(await makeFake('Mike.mbtiles'));

      final regions = await MBTilesService.listInstalled();
      expect(regions.map((r) => r.name).toList(), ['alpha', 'Mike', 'Zulu']);
    });
  });

  group('MBTilesService.install', () {
    test('copies the source file into the app dir and reports size',
        () async {
      final source = await makeFake('uk.mbtiles', size: 256);
      final region = await MBTilesService.install(source);

      expect(region.name, 'uk');
      expect(region.bytes, 256);
      expect(await File(region.path).exists(), isTrue);
      // The install path must NOT be the original — install() copies so
      // the source can be deleted/moved without breaking the viewer.
      expect(region.path, isNot(source));
    });

    test('throws when the source file does not exist', () async {
      expect(
        () => MBTilesService.install(
          '${tempRoot.path}${Platform.pathSeparator}does_not_exist.mbtiles',
        ),
        throwsStateError,
      );
    });

    test('overwrites an existing region with the same name', () async {
      await MBTilesService.install(await makeFake('uk.mbtiles', size: 100));
      final second = await MBTilesService.install(
        await makeFake('uk.mbtiles', size: 300),
      );
      expect(second.bytes, 300);

      final regions = await MBTilesService.listInstalled();
      expect(regions, hasLength(1));
      expect(regions.first.bytes, 300);
    });
  });

  group('MBTilesService active region', () {
    test('getActive returns null when nothing is set', () async {
      expect(await MBTilesService.getActive(), isNull);
    });

    test('setActive / getActive round-trip', () async {
      final region = await MBTilesService.install(await makeFake('uk.mbtiles'));
      await MBTilesService.setActive(region);

      final active = await MBTilesService.getActive();
      expect(active, isNotNull);
      expect(active!.path, region.path);
      expect(active.name, 'uk');
    });

    test('clearActive reverts getActive to null', () async {
      final region = await MBTilesService.install(await makeFake('uk.mbtiles'));
      await MBTilesService.setActive(region);
      await MBTilesService.clearActive();
      expect(await MBTilesService.getActive(), isNull);
    });

    test(
        'getActive auto-clears stale pref when the file is gone '
        '(user deleted from outside the app)', () async {
      final region = await MBTilesService.install(await makeFake('uk.mbtiles'));
      await MBTilesService.setActive(region);
      // Simulate out-of-band file deletion.
      await File(region.path).delete();

      expect(await MBTilesService.getActive(), isNull);
      // And the pref should have been cleared, so a second call returns
      // null just as quickly without hitting the filesystem check again.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('trail_active_mbtiles_v1'), isNull);
    });
  });

  group('MBTilesService.delete', () {
    test('removes the file from disk', () async {
      final region = await MBTilesService.install(await makeFake('uk.mbtiles'));
      await MBTilesService.delete(region);
      expect(await File(region.path).exists(), isFalse);
    });

    test('clears the active pref when deleting the active region',
        () async {
      final region = await MBTilesService.install(await makeFake('uk.mbtiles'));
      await MBTilesService.setActive(region);
      await MBTilesService.delete(region);
      expect(await MBTilesService.getActive(), isNull);
    });

    test('leaves the active pref alone when deleting a non-active region',
        () async {
      final r1 = await MBTilesService.install(await makeFake('uk.mbtiles'));
      final r2 = await MBTilesService.install(await makeFake('de.mbtiles'));
      await MBTilesService.setActive(r1);
      await MBTilesService.delete(r2);

      final active = await MBTilesService.getActive();
      expect(active, isNotNull);
      expect(active!.path, r1.path);
    });

    test('is a no-op when the file has already vanished', () async {
      final region = await MBTilesService.install(await makeFake('uk.mbtiles'));
      await File(region.path).delete();
      // Should not throw.
      await MBTilesService.delete(region);
    });
  });
}
