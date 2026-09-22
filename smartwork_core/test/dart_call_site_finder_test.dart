import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('DartCallSiteFinder.findCalls', () {
    test('finds a bare call and reports its positional argument count', () {
      const source = "login('a@test.com', 'password');";
      final sites = DartCallSiteFinder().findCalls(source, 'login');

      expect(sites, hasLength(1));
      expect(sites.single.positionalArgumentCount, 2);
      expect(sites.single.namedArgumentNames, isEmpty);
      expect(sites.single.argumentsSource, "'a@test.com', 'password'");
    });

    test('finds a member call (bloc.login(...))', () {
      const source = "await bloc.login('a@test.com', 'password');";
      final sites = DartCallSiteFinder().findCalls(source, 'login');

      expect(sites, hasLength(1));
      expect(sites.single.positionalArgumentCount, 2);
    });

    test('reports named argument names separately from positional count', () {
      const source = "login('a@test.com', 'password', rememberMe: true);";
      final sites = DartCallSiteFinder().findCalls(source, 'login');

      expect(sites.single.positionalArgumentCount, 2);
      expect(sites.single.namedArgumentNames, {'rememberMe'});
    });

    test('never matches a call inside a comment or string literal', () {
      const source = '''
// login('a@test.com', 'password');
final msg = 'call login(1, 2) here';
real();
''';
      final sites = DartCallSiteFinder().findCalls(source, 'login');
      expect(sites, isEmpty);
    });

    test(
        'finds every call site when the same method is called more '
        'than once', () {
      const source = '''
void main() {
  login('a', 'b');
  login('c', 'd', rememberMe: true);
}
''';
      final sites = DartCallSiteFinder().findCalls(source, 'login');
      expect(sites, hasLength(2));
    });

    test('reports exact argument-list offsets usable for a splice', () {
      const source = 'login(a, b)';
      final sites = DartCallSiteFinder().findCalls(source, 'login');

      final site = sites.single;
      expect(
        source.substring(site.argumentsStart, site.argumentsEnd),
        site.argumentsSource,
      );
    });

    test(
        'correctly counts arguments across a nested call, never '
        'splitting on the nested call\'s own commas', () {
      const source = 'login(compute(1, 2), password)';
      final sites = DartCallSiteFinder().findCalls(source, 'login');

      expect(sites.single.positionalArgumentCount, 2);
    });
  });

  group('DartCallSiteFinder.referencesIdentifier', () {
    test('finds a real code reference to an identifier', () {
      const source = 'expect(bloc.state, isA<LoginSuccess>());';
      expect(
        DartCallSiteFinder().referencesIdentifier(source, 'LoginSuccess'),
        isTrue,
      );
    });

    test('never counts a reference inside a comment or string', () {
      const source = "// LoginSuccess\nfinal x = 'LoginSuccess';";
      expect(
        DartCallSiteFinder().referencesIdentifier(source, 'LoginSuccess'),
        isFalse,
      );
    });

    test('never matches a substring of a longer identifier', () {
      const source = 'final x = LoginSuccessfulEvent();';
      expect(
        DartCallSiteFinder().referencesIdentifier(source, 'LoginSuccess'),
        isFalse,
      );
    });
  });
}
