import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

ProjectScanResult _scan(Map<String, String> dartFiles) => ProjectScanResult(
      projectPath: '/fake/project',
      pubspecYaml: null,
      dartFiles: dartFiles,
    );

void main() {
  group('TestDiscoveryService', () {
    test('finds every production subject under the feature, sorted', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': '''
class LoginCubit {}
class _PrivateHelper {}
''',
        'lib/features/auth/data/auth_repository_impl.dart': '''
class AuthRepositoryImpl {}
''',
        'lib/features/profile/state/profile_cubit.dart': '''
class ProfileCubit {}
''',
      });

      final result = TestDiscoveryService().discover(scan, 'auth');

      expect(result.feature, 'auth');
      expect(result.productionFiles, [
        'lib/features/auth/data/auth_repository_impl.dart',
        'lib/features/auth/state/login_cubit.dart',
      ]);
      expect(
        result.subjects.map((s) => s.name),
        containsAll(['LoginCubit', 'AuthRepositoryImpl']),
      );
      expect(
        result.subjects.map((s) => s.name),
        isNot(contains('_PrivateHelper')),
      );
      expect(
        result.subjects.map((s) => s.name),
        isNot(contains('ProfileCubit')),
      );
    });

    test('maps an existing test file to the subject it references', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        'test/features/auth/state/login_cubit_test.dart': '''
import 'package:test/test.dart';
void main() {
  test('LoginCubit emits success', () {
    final cubit = LoginCubit();
  });
}
''',
      });

      final result = TestDiscoveryService().discover(scan, 'auth');

      expect(result.testFiles, [
        'test/features/auth/state/login_cubit_test.dart',
      ]);
      expect(
        result.testFilesForSubject['LoginCubit'],
        ['test/features/auth/state/login_cubit_test.dart'],
      );
      expect(result.untestedSubjects, isEmpty);
    });

    test('reports a subject with no referencing test file as untested', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        'lib/features/auth/data/auth_repository_impl.dart':
            'class AuthRepositoryImpl {}',
        'test/features/auth/state/login_cubit_test.dart': '''
void main() {
  LoginCubit();
}
''',
      });

      final result = TestDiscoveryService().discover(scan, 'auth');

      expect(
          result.untestedSubjects.map((s) => s.name), ['AuthRepositoryImpl']);
    });

    test('a feature with no lib/ or test/ folder at all reports empty', () {
      final result = TestDiscoveryService().discover(_scan({}), 'ghost');

      expect(result.productionFiles, isEmpty);
      expect(result.subjects, isEmpty);
      expect(result.testFiles, isEmpty);
      expect(result.testFilesForSubject, isEmpty);
      expect(result.untestedSubjects, isEmpty);
    });

    test(
        'never matches a subject name that is only a substring of another '
        "identifier in a test file's content", () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class Login {}',
        'test/features/auth/state/login_cubit_test.dart': '''
void main() {
  LoginCubitTest();
}
''',
      });

      final result = TestDiscoveryService().discover(scan, 'auth');

      expect(result.untestedSubjects.map((s) => s.name), ['Login']);
    });
  });
}
