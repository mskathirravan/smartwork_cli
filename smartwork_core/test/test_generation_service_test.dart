import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

ProjectScanResult _scan(Map<String, String> dartFiles) => ProjectScanResult(
      projectPath: '/fake/project',
      pubspecYaml: {'name': 'demo_app'},
      dartFiles: dartFiles,
    );

void main() {
  group('TestGenerationService', () {
    test('generates a real smoke test for a dependency-free missing subject',
        () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes, hasLength(1));
      final change = plan.changes.single;
      expect(change.kind, TestChangeKind.create);
      expect(change.filePath, 'test/features/auth/state/login_cubit_test.dart');
      expect(change.content, contains("group('LoginCubit'"));
      expect(change.content, contains('LoginCubit()'));
      expect(change.content, isNot(contains('skip:')));
    });

    test(
        'imports package:flutter_test and the real production file — '
        'regression: the original template imported package:test (not a '
        'dependency of any real Flutter project) and never imported the '
        'subject at all, so flutter analyze failed on every generated '
        'file', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      final content = plan.changes.single.content;
      expect(content,
          contains("import 'package:flutter_test/flutter_test.dart';"));
      expect(
        content,
        contains(
            "import 'package:demo_app/features/auth/state/login_cubit.dart';"),
      );
      expect(content, isNot(contains('package:test/test.dart')));
    });

    test(
        'throws UnknownPackageNameException rather than generate an '
        'unresolvable import when pubspec.yaml has no name', () {
      final scan = ProjectScanResult(
        projectPath: '/fake/project',
        pubspecYaml: null,
        dartFiles: {
          'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        },
      );
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      expect(
        () => TestGenerationService().generate(scan, discovery, scenarios),
        throwsA(isA<UnknownPackageNameException>()),
      );
    });

    test(
        'generates a skip-marked scaffold, never a guessed fake, for a '
        'subject with a required constructor dependency', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': '''
class LoginCubit {
  LoginCubit({required this.repository});
  final AuthRepository repository;
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes, hasLength(1));
      expect(plan.changes.single.content, contains('skip:'));
      expect(plan.changes.single.content, isNot(contains('AuthRepository(')));
    });

    test(
        'generates a skip scaffold for a required *positional* '
        'constructor parameter, not just a named one — regression: a '
        'real generated Clean Architecture repository '
        '(AuthRepositoryImpl(this.dataSource), no `required` keyword at '
        'all since positional params are implicitly required) was '
        'wrongly treated as zero-argument, producing '
        'AuthRepositoryImpl() which flutter analyze correctly rejected '
        'with "1 positional argument expected... but 0 found"', () {
      final scan = _scan({
        'lib/features/auth/data/repositories/auth_repository_impl.dart': '''
class AuthRepositoryImpl {
  final AuthDataSource dataSource;
  const AuthRepositoryImpl(this.dataSource);
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes.single.content, contains('skip:'));
      expect(
          plan.changes.single.content, isNot(contains('AuthRepositoryImpl()')));
    });

    test(
        'generates a skip scaffold for a class with no public '
        'constructor at all — regression: a private/singleton '
        'constructor pattern (ClassName._(), SmartWork\'s own service '
        'convention) has no callable ClassName() at all', () {
      final scan = _scan({
        'lib/features/auth/state/auth_singleton.dart': '''
class AuthSingleton {
  static final instance = AuthSingleton._();
  AuthSingleton._();
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes.single.content, contains('skip:'));
      expect(plan.changes.single.content, isNot(contains('AuthSingleton()')));
    });

    test(
        'still generates a real smoke test for a positional constructor '
        'that is fully optional (bracketed)', () {
      final scan = _scan({
        'lib/features/auth/domain/entities/auth.dart': '''
class Auth {
  const Auth([this.token]);
  final String? token;
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes.single.content, contains('Auth()'));
      expect(plan.changes.single.content, isNot(contains('skip:')));
    });

    test(
        'never generates a change for a covered or outdated scenario — '
        'only missing scenarios produce a new file', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        'test/features/auth/state/login_cubit_test.dart':
            'void main() { LoginCubit(); }',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes, isEmpty);
      expect(plan.skipped, hasLength(1));
      expect(plan.skipped.single.status, TestScenarioStatus.covered);
    });

    test(
        'never overwrites a file already present at the mirrored test '
        "path, even if it doesn't reference the subject", () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        'test/features/auth/state/login_cubit_test.dart':
            'void main() { /* covers something else entirely */ }',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes, isEmpty);
      expect(plan.skipped.single.status, TestScenarioStatus.missing);
    });

    test(
        'a generated smoke test matches real `dart format` output exactly '
        '(verified against a real dart format run during this milestone\'s '
        'own E2E validation)', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);
      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes.single.content, '''
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_app/features/auth/state/login_cubit.dart';

void main() {
  group('LoginCubit', () {
    test('can be constructed', () {
      expect(LoginCubit(), isNotNull);
    });
  });
}
''');
    });

    test(
        'a generated skip scaffold matches real `dart format` output '
        'exactly', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': '''
class LoginCubit {
  LoginCubit({required this.repository});
  final AuthRepository repository;
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);
      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes.single.content, '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginCubit', () {
    test(
      'LoginCubit needs a real test — fill in its constructor dependencies',
      () {},
      skip: 'LoginCubit has a required constructor argument; smartwork test generate cannot safely guess a fake for it. Supply one and replace this scaffold.',
    );
  });
}
''');
    });

    test(
        'never generates a naive construction test for an abstract '
        'class — regression: AuthState() does not compile for '
        '`abstract class AuthState {}`', () {
      final scan = _scan({
        'lib/features/auth/state/auth_state.dart': '''
abstract class AuthState {
  const AuthState();
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);
      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes.single.content, contains('skip:'));
      expect(plan.changes.single.content, isNot(contains('AuthState()')));
      expect(plan.changes.single.content, contains('abstract class'));
    });

    test(
        'combines several subjects declared in the same production '
        'file into one TestChange, never several competing changes to '
        'the identical mirrored test path — regression: a real BLoC '
        'state hierarchy (AuthInitial/AuthLoading/AuthLoaded/AuthError, '
        'all in auth_state.dart) originally produced 4 separate changes '
        'that would have overwritten one another on apply', () {
      final scan = _scan({
        'lib/features/auth/state/auth_state.dart': '''
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthLoaded extends AuthState {}
class AuthError extends AuthState {}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);
      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes, hasLength(1));
      final change = plan.changes.single;
      expect(change.filePath, 'test/features/auth/state/auth_state_test.dart');
      expect(change.scenarios, hasLength(5));
      for (final name in [
        'AuthState',
        'AuthInitial',
        'AuthLoading',
        'AuthLoaded',
        'AuthError',
      ]) {
        expect(change.content, contains("group('$name'"));
      }
      // Real subclasses have no required dependency — real smoke tests.
      expect(change.content, contains('AuthInitial()'));
      expect(change.content, contains('AuthError()'));
      // The abstract base never gets a naive construction call.
      expect(change.content, isNot(contains('AuthState()')));
      // Exactly one shared production import — never one per subject.
      expect(
        'import'.allMatches(change.content).length,
        2, // flutter_test + the one shared production import
      );
    });

    test('a combined multi-subject file is itself dart-format-clean', () {
      final scan = _scan({
        'lib/features/auth/state/auth_state.dart': '''
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoaded extends AuthState {}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);
      final plan = TestGenerationService().generate(scan, discovery, scenarios);

      expect(plan.changes.single.content, '''
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_app/features/auth/state/auth_state.dart';

void main() {
  group('AuthState', () {
    test(
      'AuthState needs a real test — fill in its constructor dependencies',
      () {},
      skip: 'AuthState is an abstract class and cannot be constructed directly; test it through a concrete subclass instead.',
    );
  });
  group('AuthInitial', () {
    test('can be constructed', () {
      expect(AuthInitial(), isNotNull);
    });
  });
  group('AuthLoaded', () {
    test('can be constructed', () {
      expect(AuthLoaded(), isNotNull);
    });
  });
}
''');
    });
  });

  group('TestGenerationLifecycle', () {
    late String tempDir;

    setUp(() async {
      tempDir =
          (await Directory.systemTemp.createTemp('test_generation_')).path;
      await File('$tempDir/pubspec.yaml').create(recursive: true);
      await File('$tempDir/pubspec.yaml').writeAsString('name: demo_app\n');
    });

    tearDown(() async {
      await Directory(tempDir).delete(recursive: true);
    });

    test('plan() throws for an unknown feature', () async {
      await Directory('$tempDir/lib/features/auth').create(recursive: true);
      await File('$tempDir/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      expect(
        () => TestGenerationLifecycle().plan(tempDir, 'billing'),
        throwsA(isA<FeatureNotFoundForTestingException>()),
      );
    });

    test(
        'apply() writes exactly the files the plan describes, nothing '
        'more', () async {
      await Directory('$tempDir/lib/features/auth/state')
          .create(recursive: true);
      await File('$tempDir/lib/features/auth/state/login_cubit.dart')
          .writeAsString('class LoginCubit {}');

      final lifecycle = TestGenerationLifecycle();
      final plan = await lifecycle.plan(tempDir, 'auth');
      expect(plan.changes, hasLength(1));

      await lifecycle.apply(tempDir, plan);

      final written =
          File('$tempDir/test/features/auth/state/login_cubit_test.dart');
      expect(await written.exists(), isTrue);
      expect(await written.readAsString(), contains('LoginCubit'));
    });
  });
}
