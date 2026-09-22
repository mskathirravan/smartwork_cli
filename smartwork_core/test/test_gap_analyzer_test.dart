import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

ProjectScanResult _scan(Map<String, String> dartFiles) => ProjectScanResult(
      projectPath: '/fake/project',
      pubspecYaml: null,
      dartFiles: dartFiles,
    );

void main() {
  group('TestGapAnalyzer', () {
    test('a subject with no referencing test is missing', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      expect(scenarios, hasLength(1));
      expect(scenarios.single.status, TestScenarioStatus.missing);
      expect(scenarios.single.subject, 'LoginCubit');
      expect(scenarios.single.reason, contains('LoginCubit'));
    });

    test(
        'a subject referenced by a test, with no constructor drift, '
        'is covered', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': '''
class LoginCubit {
  LoginCubit({required this.repository});
  final AuthRepository repository;
}
''',
        'test/features/auth/state/login_cubit_test.dart': '''
void main() {
  LoginCubit(repository: FakeAuthRepository());
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      expect(scenarios.single.status, TestScenarioStatus.covered);
      expect(scenarios.single.existingTest,
          'test/features/auth/state/login_cubit_test.dart');
    });

    test(
        'a constructor parameter never mentioned in the referencing test '
        'is reported outdated, naming the exact missing parameter', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': '''
class LoginCubit {
  LoginCubit({required this.repository, required this.analytics});
  final AuthRepository repository;
  final AnalyticsService analytics;
}
''',
        'test/features/auth/state/login_cubit_test.dart': '''
void main() {
  LoginCubit(repository: FakeAuthRepository());
}
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      expect(scenarios.single.status, TestScenarioStatus.outdated);
      expect(scenarios.single.reason, contains('analytics'));
      expect(scenarios.single.reason, isNot(contains('repository')));
    });

    test(
        'a feature with several subjects produces one scenario per '
        'subject, independently classified', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        'lib/features/auth/data/auth_repository_impl.dart':
            'class AuthRepositoryImpl {}',
        'test/features/auth/state/login_cubit_test.dart': '''
void main() { LoginCubit(); }
''',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');

      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      expect(scenarios, hasLength(2));
      expect(
        scenarios.firstWhere((s) => s.subject == 'LoginCubit').status,
        TestScenarioStatus.covered,
      );
      expect(
        scenarios.firstWhere((s) => s.subject == 'AuthRepositoryImpl').status,
        TestScenarioStatus.missing,
      );
    });
  });

  group('TestGapAnalyzer.withCoverage', () {
    test(
        'downgrades a covered scenario to partial when real coverage '
        'shows an uncovered line in its own file', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        'test/features/auth/state/login_cubit_test.dart':
            'void main() { LoginCubit(); }',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);
      expect(scenarios.single.status, TestScenarioStatus.covered);

      final coverage = CoverageReport(files: [
        FileCoverage(
          file: 'lib/features/auth/state/login_cubit.dart',
          linesFound: 3,
          linesHit: 2,
          gaps: [
            CoverageGap(
              file: 'lib/features/auth/state/login_cubit.dart',
              line: 7,
            ),
          ],
        ),
      ]);

      final enriched = TestGapAnalyzer().withCoverage(scenarios, coverage);

      expect(enriched.single.status, TestScenarioStatus.partial);
      expect(enriched.single.reason, contains('line(s) 7'));
    });

    test(
        'leaves a covered scenario alone when coverage shows no gap '
        'for its file', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
        'test/features/auth/state/login_cubit_test.dart':
            'void main() { LoginCubit(); }',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);

      final coverage = CoverageReport(files: [
        FileCoverage(
          file: 'lib/features/auth/state/login_cubit.dart',
          linesFound: 3,
          linesHit: 3,
        ),
      ]);

      final enriched = TestGapAnalyzer().withCoverage(scenarios, coverage);

      expect(enriched.single.status, TestScenarioStatus.covered);
    });

    test(
        'never touches a missing or outdated scenario, regardless of '
        'coverage data', () {
      final scan = _scan({
        'lib/features/auth/state/login_cubit.dart': 'class LoginCubit {}',
      });
      final discovery = TestDiscoveryService().discover(scan, 'auth');
      final scenarios = TestGapAnalyzer().analyze(scan, discovery);
      expect(scenarios.single.status, TestScenarioStatus.missing);

      final coverage = CoverageReport(files: [
        FileCoverage(
          file: 'lib/features/auth/state/login_cubit.dart',
          linesFound: 1,
          linesHit: 0,
          gaps: [
            CoverageGap(
              file: 'lib/features/auth/state/login_cubit.dart',
              line: 1,
            ),
          ],
        ),
      ]);

      final enriched = TestGapAnalyzer().withCoverage(scenarios, coverage);

      expect(enriched.single.status, TestScenarioStatus.missing);
    });
  });

  group('TestAnalysisLifecycle', () {
    late String tempDir;

    setUp(() async {
      tempDir = (await Directory.systemTemp.createTemp('test_analysis_')).path;
    });

    tearDown(() async {
      await Directory(tempDir).delete(recursive: true);
    });

    test('throws FeatureNotFoundForTestingException for an unknown feature',
        () async {
      await Directory('$tempDir/lib/features/auth').create(recursive: true);
      await File('$tempDir/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      expect(
        () => TestAnalysisLifecycle().analyze(tempDir, 'billing'),
        throwsA(isA<FeatureNotFoundForTestingException>()),
      );
    });

    test('produces a TestAnalysis for a real feature on disk', () async {
      await Directory('$tempDir/lib/features/auth/state')
          .create(recursive: true);
      await File('$tempDir/lib/features/auth/state/login_cubit.dart')
          .writeAsString('class LoginCubit {}');

      final analysis = await TestAnalysisLifecycle().analyze(tempDir, 'auth');

      expect(analysis.feature, 'auth');
      expect(analysis.missing.map((s) => s.subject), ['LoginCubit']);
      expect(analysis.covered, isEmpty);
    });

    test(
        'folds in an existing coverage/lcov.info on disk, downgrading '
        'a covered scenario to partial, without running any process', () async {
      await Directory('$tempDir/lib/features/auth/state')
          .create(recursive: true);
      await File('$tempDir/lib/features/auth/state/login_cubit.dart')
          .writeAsString('class LoginCubit {}');
      await Directory('$tempDir/test/features/auth/state')
          .create(recursive: true);
      await File('$tempDir/test/features/auth/state/login_cubit_test.dart')
          .writeAsString('void main() { LoginCubit(); }');
      await Directory('$tempDir/coverage').create(recursive: true);
      await File('$tempDir/coverage/lcov.info').writeAsString('''
SF:lib/features/auth/state/login_cubit.dart
DA:1,1
DA:2,0
LF:2
LH:1
end_of_record
''');

      final analysis = await TestAnalysisLifecycle().analyze(tempDir, 'auth');

      expect(analysis.scenarios.single.status, TestScenarioStatus.partial);
      expect(analysis.coverage, isNotNull);
      expect(analysis.coverage!.files, hasLength(1));
    });

    test('leaves coverage null when no coverage/lcov.info exists', () async {
      await Directory('$tempDir/lib/features/auth').create(recursive: true);
      await File('$tempDir/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final analysis = await TestAnalysisLifecycle().analyze(tempDir, 'auth');

      expect(analysis.coverage, isNull);
    });
  });
}
