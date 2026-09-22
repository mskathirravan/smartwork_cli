import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('VersionResolver', () {
    test('resolve() returns ^<fetched version> when the fetch succeeds',
        () async {
      final resolver = VersionResolver(fetch: (package) async => '9.9.9');

      final version = await resolver.resolve('http', '^1.0.0');

      expect(version, '^9.9.9');
    });

    test(
        'resolve() falls back when the fetch returns null (package not '
        'found, non-200, malformed response)', () async {
      final resolver = VersionResolver(fetch: (package) async => null);

      final version = await resolver.resolve('http', '^1.0.0');

      expect(version, '^1.0.0');
    });

    test(
        'resolve() falls back when the fetch throws (network error, '
        'timeout)', () async {
      final resolver = VersionResolver(
        fetch: (package) async => throw Exception('network unreachable'),
      );

      final version = await resolver.resolve('http', '^1.0.0');

      expect(version, '^1.0.0');
    });

    test(
        'resolve() caches the resolved version, never fetching the same '
        'package twice', () async {
      var callCount = 0;
      final resolver = VersionResolver(fetch: (package) async {
        callCount++;
        return '2.0.0';
      });

      final first = await resolver.resolve('http', '^1.0.0');
      final second = await resolver.resolve('http', '^1.0.0');

      expect(first, '^2.0.0');
      expect(second, '^2.0.0');
      expect(callCount, 1);
    });

    test(
        'resolve() caches a fallback result too — a failed fetch is never '
        'retried within the same resolver instance', () async {
      var callCount = 0;
      final resolver = VersionResolver(fetch: (package) async {
        callCount++;
        return null;
      });

      await resolver.resolve('http', '^1.0.0');
      await resolver.resolve('http', '^1.0.0');

      expect(callCount, 1);
    });

    test('resolve() caches independently per package', () async {
      final resolver = VersionResolver(
        fetch: (package) async => package == 'http' ? '1.1.1' : '2.2.2',
      );

      final http = await resolver.resolve('http', '^0.0.0');
      final dio = await resolver.resolve('dio', '^0.0.0');

      expect(http, '^1.1.1');
      expect(dio, '^2.2.2');
    });

    test('two separate VersionResolver instances never share a cache',
        () async {
      var callCount = 0;

      final a = VersionResolver(fetch: (package) async {
        callCount++;
        return '1.0.0';
      });
      final b = VersionResolver(fetch: (package) async {
        callCount++;
        return '1.0.0';
      });

      await a.resolve('http', '^0.0.0');
      await b.resolve('http', '^0.0.0');

      expect(callCount, 2);
    });
  });
}
