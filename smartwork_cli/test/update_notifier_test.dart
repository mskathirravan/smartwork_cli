import 'dart:convert';
import 'dart:io';

import 'package:smartwork_cli/src/update_notifier.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateNotifier', () {
    late Directory tempDir;
    late File cacheFile;
    final now = DateTime.utc(2026, 9, 25, 12);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_notifier_');
      cacheFile = File('${tempDir.path}/.smartwork/update_check.json');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    UpdateNotifier notifier({
      String current = '1.0.2',
      Future<String?> Function(String)? fetch,
      DateTime? at,
    }) =>
        UpdateNotifier(
          currentVersion: current,
          cacheFile: cacheFile,
          fetchLatest: fetch ?? (_) async => '1.0.3',
          now: () => at ?? now,
        );

    test('tells the developer to run smartwork update when pub.dev is newer',
        () async {
      final notice = await notifier().check();

      expect(notice, contains('1.0.2 → 1.0.3'));
      expect(notice, contains('smartwork update'));
    });

    test('says nothing when this CLI is already the latest', () async {
      expect(await notifier(current: '1.0.3').check(), isNull);
    });

    test('asks pub.dev about smartwork_cli and caches the answer', () async {
      String? asked;
      await notifier(fetch: (package) async {
        asked = package;
        return '1.0.3';
      }).check();

      expect(asked, 'smartwork_cli');
      final cache = jsonDecode(cacheFile.readAsStringSync()) as Map;
      expect(cache['latest'], '1.0.3');
    });

    test('within 24 hours uses the cached answer without the network',
        () async {
      await notifier().check();
      var fetched = false;

      final notice = await notifier(
        fetch: (_) async {
          fetched = true;
          return null;
        },
        at: now.add(const Duration(hours: 23)),
      ).check();

      expect(fetched, isFalse);
      expect(notice, contains('1.0.3'));
    });

    test('after 24 hours asks pub.dev again', () async {
      await notifier().check();

      final notice = await notifier(
        fetch: (_) async => '1.1.0',
        at: now.add(const Duration(hours: 25)),
      ).check();

      expect(notice, contains('1.0.2 → 1.1.0'));
    });

    test('offline: falls back to the last known answer, or says nothing',
        () async {
      expect(
        await notifier(fetch: (_) async => throw const SocketException('x'))
            .check(),
        isNull,
      );

      await notifier().check();
      final notice = await notifier(
        fetch: (_) async => null,
        at: now.add(const Duration(days: 2)),
      ).check();
      expect(notice, contains('1.0.3'));
    });

    test('a corrupt cache file is ignored, never an error', () async {
      cacheFile
        ..createSync(recursive: true)
        ..writeAsStringSync('{not json');

      expect(await notifier().check(), contains('1.0.3'));
    });
  });

  group('UpdateNotifier.isNewer', () {
    test('compares major.minor.patch numerically', () {
      expect(UpdateNotifier.isNewer('1.0.10', than: '1.0.9'), isTrue);
      expect(UpdateNotifier.isNewer('1.1.0', than: '1.0.9'), isTrue);
      expect(UpdateNotifier.isNewer('2.0.0', than: '1.9.9'), isTrue);
      expect(UpdateNotifier.isNewer('1.0.2', than: '1.0.2'), isFalse);
      expect(UpdateNotifier.isNewer('1.0.1', than: '1.0.2'), isFalse);
    });

    test('never offers a pre-release; a release beats its pre-release', () {
      expect(UpdateNotifier.isNewer('1.0.3-dev.1', than: '1.0.2'), isFalse);
      expect(UpdateNotifier.isNewer('1.0.3', than: '1.0.3-dev.1'), isTrue);
    });

    test('unparsable versions are never "newer"', () {
      expect(UpdateNotifier.isNewer('latest', than: '1.0.2'), isFalse);
      expect(UpdateNotifier.isNewer('1.0.3', than: 'dev'), isFalse);
    });
  });
}
