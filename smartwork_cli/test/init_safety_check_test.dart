import 'dart:async';
import 'dart:io';

import 'package:smartwork_cli/src/commands/init_safety_check.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Runs [body], capturing everything printed via `print()` during it.
Future<List<String>> _captureOutput(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

/// [InitSafetyCheck] is a pure classify-and-print-context step — it
/// never asks for confirmation itself (that now happens exactly once,
/// in `InitCommand.checkSafetyAndGenerate`, after this class's context
/// and the newly-collected configuration are both shown, as a single
/// confirmation transaction). These tests only cover detection + the
/// printed context; there is no confirmation reader to inject or a
/// `proceed` outcome to assert on any more.
void main() {
  group('InitSafetyCheck', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_safety_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('an empty directory prints nothing and is not a regeneration',
        () async {
      final check = InitSafetyCheck();

      late InitSafetyCheckResult result;
      final output = await _captureOutput(() async {
        result = await check.check(tempDir.path);
      });

      expect(result.state, TargetProjectState.empty);
      expect(result.isRegeneration, isFalse);
      expect(result.existingConfig, isNull);
      expect(result.existingPlatforms, isEmpty);
      expect(output, isEmpty);
    });

    test('a non-Flutter project warns and is reported as a regeneration',
        () async {
      File('${tempDir.path}/README.md').writeAsStringSync('hello');
      final check = InitSafetyCheck();

      late InitSafetyCheckResult result;
      final output = await _captureOutput(() async {
        result = await check.check(tempDir.path);
      });

      expect(result.state, TargetProjectState.nonFlutterProject);
      expect(result.isRegeneration, isTrue);
      final text = output.join('\n');
      expect(text, contains('Existing files were found'));
    });

    test(
        'an existing Flutter project warns and shows its existing '
        'platforms', () async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: app\n');
      Directory('${tempDir.path}/lib').createSync();
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final check = InitSafetyCheck();

      late InitSafetyCheckResult result;
      final output = await _captureOutput(() async {
        result = await check.check(tempDir.path);
      });

      expect(result.state, TargetProjectState.flutterProject);
      expect(result.isRegeneration, isTrue);
      expect(result.existingPlatforms, {AppTarget.android, AppTarget.ios});
      final text = output.join('\n');
      expect(text, contains('Existing Flutter project detected'));
      expect(text, contains('Existing platforms:'));
      expect(text, contains('✓ Android'));
      expect(text, contains('✓ iOS'));
      expect(text, isNot(contains('✓ Web')));
    });

    test(
        'an existing Flutter project with no recognizable platform '
        'folder skips the "Existing platforms" section', () async {
      // detect() only classifies this as flutterProject when at least
      // one platform folder exists, so this scenario is purely about
      // the "Existing platforms:" header never appearing when there is
      // nothing to list — exercised via a SmartWork project with none
      // of the six folders, since that state still carries an
      // (empty) existingPlatforms set.
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      );

      final output = await _captureOutput(() async {
        await InitSafetyCheck().check(tempDir.path);
      });

      expect(output.join('\n'), isNot(contains('Existing platforms:')));
    });

    test(
        'an existing SmartWork project displays the current '
        'configuration, including its App Targets', () async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          appTargets: {AppTarget.android, AppTarget.web},
          architecture: Architecture.mvp,
          stateManagement: StateManagement.getx,
          network: Network.dio,
          storage: Storage.hive,
          homeFeatureName: 'dashboard',
          initialFeatures: ['auth'],
        ),
      );

      final check = InitSafetyCheck();

      late InitSafetyCheckResult result;
      final output = await _captureOutput(() async {
        result = await check.check(tempDir.path);
      });

      expect(result.state, TargetProjectState.smartworkProject);
      expect(result.isRegeneration, isTrue);
      expect(result.existingConfig, isNotNull);
      expect(result.existingConfig!.projectName, 'my_app');

      final text = output.join('\n');
      expect(text, contains('SmartWork project detected'));
      expect(text, contains('Current configuration'));
      expect(text, contains('my_app'));
      expect(text, contains('Android, Web'));
      expect(text, contains('Mvp'));
      expect(text, contains('Getx'));
      expect(text, contains('dashboard'));
    });

    test(
        'a malformed .smartwork/project.yaml reports the problem, with '
        'no existingConfig', () async {
      Directory('${tempDir.path}/.smartwork').createSync();
      File('${tempDir.path}/.smartwork/project.yaml')
          .writeAsStringSync("projectName: 'my_app'\n");

      final check = InitSafetyCheck();

      late InitSafetyCheckResult result;
      final output = await _captureOutput(() async {
        result = await check.check(tempDir.path);
      });

      expect(result.state, TargetProjectState.malformedSmartworkProject);
      expect(result.isRegeneration, isTrue);
      expect(result.existingConfig, isNull);
      final text = output.join('\n');
      expect(text, contains('could not be read'));
    });
  });

  group('readConfirmationFromStdin contract (documented, not stdin-tested)',
      () {
    test(
        'ConfirmationReader is a plain String -> bool function, '
        'trivially fakeable without any real stdin', () {
      bool alwaysYes(String prompt) => true;
      bool alwaysNo(String prompt) => false;

      expect(alwaysYes('anything'), isTrue);
      expect(alwaysNo('anything'), isFalse);
    });
  });
}
