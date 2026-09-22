import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

ProjectScanResult _scan(Map<String, String> dartFiles) => ProjectScanResult(
      projectPath: '/fake/project',
      pubspecYaml: {'name': 'demo_app'},
      dartFiles: dartFiles,
    );

void main() {
  group('TestMaintenanceAnalyzer — method call arguments', () {
    test(
        'HIGH confidence: a new required bool parameter with a '
        "declared default proposes exactly that default — the "
        'milestone\'s own worked example (AuthBloc.login gains '
        'rememberMe)', () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password, bool rememberMe) async {}
}
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
void main() {
  final bloc = AuthBloc();
  test('login succeeds', () async {
    await bloc.login('a@test.com', 'password');
  });
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);

      expect(updates, hasLength(1));
      final update = updates.single;
      expect(update.confidence, TestUpdateConfidence.high);
      expect(update.kind, TestUpdateKind.methodCallArguments);
      expect(update.reason, contains('rememberMe'));
      expect(update.oldSnippet, "'a@test.com', 'password'");
      expect(update.newSnippet, "'a@test.com', 'password', false");
      expect(update.diff, contains('- '));
      expect(update.diff, contains('+ '));
    });

    test(
        'HIGH confidence: a newly required nullable parameter proposes '
        'null, regardless of its underlying type', () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password, {required Device? device}) async {}
}
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
void main() {
  final bloc = AuthBloc();
  bloc.login('a', 'b');
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);

      expect(updates.single.confidence, TestUpdateConfidence.high);
      expect(updates.single.newSnippet, "'a', 'b', device: null");
    });

    test(
        'MEDIUM confidence: a newly required parameter with a custom '
        'class type and no default cannot be safely auto-filled', () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password, {required AuthOptions options}) async {}
}
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
void main() {
  final bloc = AuthBloc();
  bloc.login('a', 'b');
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);

      expect(updates.single.confidence, TestUpdateConfidence.medium);
      expect(updates.single.newSnippet, isNull);
      expect(updates.single.diff, isNull);
    });

    test(
        'LOW confidence: more than one new required parameter is never '
        'auto-proposed', () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password, String otp, bool rememberMe) async {}
}
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
void main() {
  final bloc = AuthBloc();
  bloc.login('a', 'b');
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);

      expect(updates.single.confidence, TestUpdateConfidence.low);
      expect(updates.single.newSnippet, isNull);
    });

    test(
        'no update at all when the call already satisfies the current '
        'signature', () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password) async {}
}
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
void main() {
  final bloc = AuthBloc();
  bloc.login('a', 'b');
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);
      expect(updates, isEmpty);
    });

    test(
        'preserves every unrelated character in the surrounding test '
        'file — the update only ever describes the argument-list '
        'splice, never the whole file', () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password, bool rememberMe) async {}
}
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
// A developer comment that must survive untouched.
void main() {
  final bloc = AuthBloc();
  test('login succeeds', () async {
    await bloc.login('a@test.com', 'password'); // trailing comment
    expect(bloc.state, isA<AuthLoading>());
  });
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);
      final update = updates.single;

      // The offsets point at exactly the argument list, nothing more.
      final testSource =
          scan.dartFiles['test/features/auth/state/auth_bloc_test.dart']!;
      expect(
        testSource.substring(update.startOffset!, update.endOffset!),
        update.oldSnippet,
      );
    });
  });

  group('TestMaintenanceAnalyzer — constructor arguments', () {
    test(
        'HIGH confidence for a newly required nullable constructor '
        'parameter', () {
      final scan = _scan({
        'lib/features/auth/data/repositories/auth_repository_impl.dart': '''
class AuthRepositoryImpl {
  const AuthRepositoryImpl(this.dataSource, {required TokenStore? tokenStore});
  final dynamic dataSource;
}
''',
        'test/features/auth/data/repositories/auth_repository_impl_test.dart':
            '''
void main() {
  AuthRepositoryImpl(FakeDataSource());
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);

      expect(updates.single.kind, TestUpdateKind.constructorArguments);
      expect(updates.single.confidence, TestUpdateConfidence.high);
      expect(updates.single.newSnippet, 'FakeDataSource(), tokenStore: null');
    });
  });

  group('TestMaintenanceAnalyzer — stale identifiers', () {
    test(
        'LOW confidence when a test references a sealed-hierarchy '
        'member that no longer exists — the milestone\'s own explicit '
        'ambiguous-change negative scenario, never guessed', () {
      final scan = _scan({
        'lib/features/auth/state/auth_state.dart': '''
abstract class AuthState {}
class AuthInitial extends AuthState {}
class Authenticated extends AuthState {}
class OtpRequired extends AuthState {}
''',
        'test/features/auth/state/auth_state_test.dart': '''
void main() {
  final AuthState current = bloc.state;
  expect(current, isA<LoginSuccess>());
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);

      expect(updates, hasLength(1));
      expect(updates.single.kind, TestUpdateKind.staleIdentifier);
      expect(updates.single.confidence, TestUpdateConfidence.low);
      expect(updates.single.newSnippet, isNull);
      expect(updates.single.reason, contains('LoginSuccess'));
    });

    test('never flags a member that still currently exists', () {
      final scan = _scan({
        'lib/features/auth/state/auth_state.dart': '''
abstract class AuthState {}
class AuthInitial extends AuthState {}
''',
        'test/features/auth/state/auth_state_test.dart': '''
void main() {
  final AuthState current = bloc.state;
  expect(current, isA<AuthInitial>());
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);
      expect(updates, isEmpty);
    });

    test(
        'never flags a well-known non-feature type used in an '
        'unrelated is-check', () {
      final scan = _scan({
        'lib/features/auth/state/auth_state.dart': '''
abstract class AuthState {}
class AuthInitial extends AuthState {}
''',
        'test/features/auth/state/auth_state_test.dart': '''
void main() {
  final AuthState current = bloc.state;
  expect(current, isA<AuthInitial>());
  expect(someValue, isA<String>());
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);
      expect(updates, isEmpty);
    });
  });

  group('TestMaintenanceAnalyzer — malformed/unsupported source', () {
    test(
        'never throws and reports no updates for production source with '
        'an unmatched opening brace — DartSignatureAnalyzer/'
        'DartLexicalScanner return null rather than guess at a '
        "declaration's true extent", () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password) async {
    // missing closing brace for the method and the class
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
void main() {
  final bloc = AuthBloc();
  bloc.login('a@test.com', 'password');
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      expect(
        () => TestMaintenanceAnalyzer().analyze(scan, discovery),
        returnsNormally,
      );
      expect(TestMaintenanceAnalyzer().analyze(scan, discovery), isEmpty);
    });

    test(
        'a call wrapped inside a complex custom helper is only ever '
        "matched at the call site itself — the helper's own body is "
        'never touched, since detection operates on the call, not the '
        'surrounding function', () {
      final scan = _scan({
        'lib/features/auth/state/auth_bloc.dart': '''
class AuthBloc {
  Future<void> login(String email, String password, bool rememberMe) async {}
}
''',
        'test/features/auth/state/auth_bloc_test.dart': '''
// A complex, developer-authored helper — must never be modified.
Future<void> loginWithRetries(AuthBloc bloc, int attempts) async {
  for (var i = 0; i < attempts; i++) {
    try {
      await bloc.login('a@test.com', 'password');
      return;
    } catch (_) {
      if (i == attempts - 1) rethrow;
    }
  }
}

void main() {
  final bloc = AuthBloc();
  loginWithRetries(bloc, 3);
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final updates = TestMaintenanceAnalyzer().analyze(scan, discovery);

      expect(updates, hasLength(1));
      final update = updates.single;
      expect(update.oldSnippet, "'a@test.com', 'password'");
      expect(update.newSnippet, "'a@test.com', 'password', false");
      expect(update.oldSnippet, isNot(contains('loginWithRetries')));
      expect(update.oldSnippet, isNot(contains('for (var i')));
    });
  });
}
