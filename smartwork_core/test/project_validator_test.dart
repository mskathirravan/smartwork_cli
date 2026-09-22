import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// A fake [ProcessRunner] that maps each expected validation command to
/// a canned exit code, recording every invocation so tests can assert
/// on exact ordering and fail-fast behavior.
class _FakeProcess {
  final List<List<String>> calls = [];
  final Map<String, int> exitCodes;

  _FakeProcess(this.exitCodes);

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add([executable, ...arguments]);
    final key = '$executable ${arguments.join(' ')}';
    final exitCode = exitCodes[key] ?? 0;
    return ProcessResult(0, exitCode, '', exitCode == 0 ? '' : 'failed');
  }
}

const _formatCmd = 'dart format --output=none --set-exit-if-changed .';
const _pubGetCmd = 'flutter pub get';
const _genL10nCmd = 'flutter gen-l10n';
const _analyzeCmd = 'flutter analyze';
const _testCmd = 'flutter test';

void main() {
  group('ProjectValidator', () {
    // These tests exercise the Format/Dependencies/Analyze/Tests phases
    // in isolation from the Platforms phase — passing an empty
    // `appTargets` set makes Platforms trivially pass (nothing to
    // check), regardless of the fake, non-existent `/some/project` path
    // these tests use, since Platforms is the only phase that ever
    // touches the real filesystem.
    test(
        'runs the Platforms phase plus all four process phases in order, '
        'reporting success when every process exits 0', () async {
      final fake = _FakeProcess({});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate('/some/project', appTargets: {});

      expect(result.passed, isTrue);
      expect(result.phases.map((p) => p.phase), [
        ValidationPhase.platforms,
        ValidationPhase.format,
        ValidationPhase.dependencies,
        ValidationPhase.analyze,
        ValidationPhase.tests,
      ]);
      expect(result.phases.every((p) => p.passed), isTrue);
      expect(fake.calls, [
        _formatCmd.split(' '),
        _pubGetCmd.split(' '),
        _analyzeCmd.split(' '),
        _testCmd.split(' '),
      ]);
    });

    test('stops at the first failing phase — later phases never run', () async {
      final fake = _FakeProcess({_analyzeCmd: 1});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate('/some/project', appTargets: {});

      expect(result.passed, isFalse);
      expect(result.phases.map((p) => p.phase), [
        ValidationPhase.platforms,
        ValidationPhase.format,
        ValidationPhase.dependencies,
        ValidationPhase.analyze,
      ]);
      expect(result.phases.last.passed, isFalse);
      expect(fake.calls, hasLength(3),
          reason: 'flutter test must never run once analyze has failed');
    });

    test(
        'a failing Format phase stops immediately — dependencies, '
        'analyze, and tests never run', () async {
      final fake = _FakeProcess({_formatCmd: 1});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate('/some/project', appTargets: {});

      expect(result.passed, isFalse);
      expect(result.phases, hasLength(2));
      expect(result.phases.first.phase, ValidationPhase.platforms);
      expect(result.phases.first.passed, isTrue);
      expect(result.phases.last.phase, ValidationPhase.format);
      expect(result.phases.last.passed, isFalse);
      expect(fake.calls, hasLength(1));
    });

    test(
        'a failing Tests phase is reported after Platforms/Format/'
        'Dependencies/Analyze all passed', () async {
      final fake = _FakeProcess({_testCmd: 1});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate('/some/project', appTargets: {});

      expect(result.passed, isFalse);
      expect(result.phases, hasLength(5));
      expect(result.phases[0].phase, ValidationPhase.platforms);
      expect(result.phases[0].passed, isTrue);
      expect(result.phases[1].passed, isTrue);
      expect(result.phases[2].passed, isTrue);
      expect(result.phases[3].passed, isTrue);
      expect(result.phases[4].passed, isFalse);
      expect(result.phases[4].phase, ValidationPhase.tests);
    });

    test(
        'every command runs with the given project path as its working '
        'directory', () async {
      String? capturedCwd;
      final validator = ProjectValidator(
        runProcess: (executable, arguments, {workingDirectory}) async {
          capturedCwd ??= workingDirectory;
          return ProcessResult(0, 0, '', '');
        },
      );

      await validator.validate('/my/project/path', appTargets: {});

      expect(capturedCwd, '/my/project/path');
    });

    test(
        'a missing executable on PATH is treated as a validation '
        'failure, not a crash', () async {
      final validator = ProjectValidator(
        runProcess: (executable, arguments, {workingDirectory}) async {
          throw ProcessException(executable, arguments, 'not found');
        },
      );

      final result = await validator.validate('/some/project', appTargets: {});

      expect(result.passed, isFalse);
      expect(result.phases.last.phase, ValidationPhase.format);
      expect(result.phases.last.passed, isFalse);
    });

    test('ValidationPhase labels match the exact required report text', () {
      expect(ValidationPhase.platforms.label, 'Platforms');
      expect(ValidationPhase.format.label, 'Format');
      expect(ValidationPhase.dependencies.label, 'Dependencies');
      expect(ValidationPhase.analyze.label, 'Analyze');
      expect(ValidationPhase.tests.label, 'Tests');
    });
  });

  group('ProjectValidator: Platforms phase', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_validator_platforms_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'passes, before any process phase runs, when every selected '
        "target's platform folder exists", () async {
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      final fake = _FakeProcess({});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate(
        tempDir.path,
        appTargets: {AppTarget.android, AppTarget.ios},
      );

      expect(result.phases.first.phase, ValidationPhase.platforms);
      expect(result.phases.first.passed, isTrue);
      expect(result.passed, isTrue);
    });

    test(
        'never requires a platform folder for an AppTarget that was '
        'not selected', () async {
      // Only android/ios exist on disk (web/windows/macos/linux were
      // never selected) — validation for {android, ios} must not care
      // that the other four platform folders are absent.
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      final validator = ProjectValidator(runProcess: _FakeProcess({}).run);

      final result = await validator.validate(
        tempDir.path,
        appTargets: {AppTarget.android, AppTarget.ios},
      );

      expect(result.phases.first.passed, isTrue);
    });

    test(
        'fails fast — before Format/Dependencies/Analyze/Tests ever run '
        '— when a selected target has no platform folder', () async {
      Directory('${tempDir.path}/android').createSync();
      // ios/ deliberately missing, even though ios is selected below.
      final fake = _FakeProcess({});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate(
        tempDir.path,
        appTargets: {AppTarget.android, AppTarget.ios},
      );

      expect(result.passed, isFalse);
      expect(result.phases, hasLength(1));
      expect(result.phases.single.phase, ValidationPhase.platforms);
      expect(result.phases.single.output, contains('ios'));
      expect(fake.calls, isEmpty,
          reason: 'no subprocess should run once Platforms has failed');
    });

    test('reports every missing platform, not only the first', () async {
      final validator = ProjectValidator(runProcess: _FakeProcess({}).run);

      final result = await validator.validate(
        tempDir.path,
        appTargets: {AppTarget.windows, AppTarget.macos, AppTarget.linux},
      );

      expect(result.passed, isFalse);
      final output = result.phases.single.output;
      expect(output, contains('windows'));
      expect(output, contains('macos'));
      expect(output, contains('linux'));
    });

    test('passes trivially when appTargets is empty', () async {
      final fake = _FakeProcess({});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate(tempDir.path, appTargets: {});

      expect(result.phases.first.passed, isTrue);
    });

    test('requires all six platform folders when all six are selected',
        () async {
      for (final target in [
        AppTarget.android,
        AppTarget.ios,
        AppTarget.web,
        AppTarget.windows,
        AppTarget.macos,
      ]) {
        Directory('${tempDir.path}/${target.platformFolder}').createSync();
      }
      // linux/ deliberately missing.
      final validator = ProjectValidator(runProcess: _FakeProcess({}).run);

      final result = await validator.validate(
        tempDir.path,
        appTargets: Set<AppTarget>.from(AppTarget.values),
      );

      expect(result.passed, isFalse);
      expect(result.phases.single.output, contains('linux'));
    });
  });

  group('ProjectValidator localization (V1.1-6)', () {
    test('localizationEnabled: false never runs flutter gen-l10n', () async {
      final fake = _FakeProcess({});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate(
        '/some/project',
        appTargets: {},
        localizationEnabled: false,
      );

      expect(result.passed, isTrue);
      expect(fake.calls, isNot(contains(_genL10nCmd.split(' '))));
    });

    test(
        'localizationEnabled: true runs flutter gen-l10n immediately '
        'after a successful flutter pub get, before Analyze', () async {
      final fake = _FakeProcess({});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate(
        '/some/project',
        appTargets: {},
        localizationEnabled: true,
      );

      expect(result.passed, isTrue);
      final joinedCalls = fake.calls.map((c) => c.join(' ')).toList();
      final pubGetIndex = joinedCalls.indexOf(_pubGetCmd);
      final genL10nIndex = joinedCalls.indexOf(_genL10nCmd);
      final analyzeIndex = joinedCalls.indexOf(_analyzeCmd);
      expect(pubGetIndex, greaterThanOrEqualTo(0));
      expect(genL10nIndex, greaterThan(pubGetIndex));
      expect(analyzeIndex, greaterThan(genL10nIndex));
    });

    test(
        'a failing flutter gen-l10n fails the Dependencies phase and '
        'stops before Analyze', () async {
      final fake = _FakeProcess({_genL10nCmd: 1});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate(
        '/some/project',
        appTargets: {},
        localizationEnabled: true,
      );

      expect(result.passed, isFalse);
      expect(result.phases.last.phase, ValidationPhase.dependencies);
      expect(result.phases.last.passed, isFalse);
      expect(fake.calls, isNot(contains(_analyzeCmd.split(' '))));
    });

    test(
        'flutter gen-l10n never runs when flutter pub get itself '
        'already failed', () async {
      final fake = _FakeProcess({_pubGetCmd: 1});
      final validator = ProjectValidator(runProcess: fake.run);

      final result = await validator.validate(
        '/some/project',
        appTargets: {},
        localizationEnabled: true,
      );

      expect(result.passed, isFalse);
      expect(fake.calls, isNot(contains(_genL10nCmd.split(' '))));
    });
  });

  group('ProjectValidationFailedException', () {
    test('toString names the phase that failed', () async {
      final fake = _FakeProcess({_analyzeCmd: 1});
      final validator = ProjectValidator(runProcess: fake.run);
      final result = await validator.validate('/some/project', appTargets: {});

      final exception = ProjectValidationFailedException(result);

      expect(exception.toString(), contains('Analyze'));
    });
  });
}
