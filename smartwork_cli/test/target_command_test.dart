@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/target_command.dart';
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

ProjectConfig _config({
  String projectName = 'demo_app',
  Set<AppTarget>? appTargets,
}) {
  return ProjectConfig(
    projectName: projectName,
    appTargets: appTargets ?? {AppTarget.android, AppTarget.ios},
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.http,
    storage: Storage.sharedPreferences,
    initialFeatures: ['home'],
  );
}

/// A [FlutterBootstrap] fake recording every `--platforms` value it was
/// asked to create, and simulating real `flutter create --platforms=...`
/// by actually creating the matching platform directories *and* writing
/// back the stock `test/widget_test.dart` counter-app smoke test — real
/// `flutter create` does this every time it runs, including when
/// re-run against an already-generated project to add a platform (the
/// exact scenario `smartwork target` hits) — so tests can assert
/// `TargetCommand` cleans it up again, the same way
/// `ProjectGenerator.generate()` already does for `smartwork init`.
class _RecordingFlutterBootstrap {
  final List<Set<String>> calls = [];

  FlutterBootstrap build(Directory tempDir) {
    return FlutterBootstrap(
      runProcess: (executable, arguments, {workingDirectory}) async {
        final platformsArg = arguments.firstWhere(
          (a) => a.startsWith('--platforms='),
          orElse: () => '',
        );
        final platforms = platformsArg.isEmpty
            ? <String>{}
            : platformsArg.substring('--platforms='.length).split(',').toSet();
        calls.add(platforms);
        for (final platform in platforms) {
          Directory('${tempDir.path}/$platform').createSync(recursive: true);
        }
        Directory('${tempDir.path}/test').createSync(recursive: true);
        File('${tempDir.path}/test/widget_test.dart')
            .writeAsStringSync('// stock counter-app smoke test\n');
        return ProcessResult(0, 0, '', '');
      },
    );
  }
}

ProjectValidator _passingValidator() {
  return ProjectValidator(
    runProcess: (executable, arguments, {workingDirectory}) async {
      return ProcessResult(0, 0, '', '');
    },
  );
}

ProjectValidator _failingValidator() {
  return ProjectValidator(
    runProcess: (executable, arguments, {workingDirectory}) async {
      return ProcessResult(0, 1, '', 'boom');
    },
  );
}

void main() {
  group('TargetCommand.run() — project detection', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_target_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'refuses to run against a directory with no .smartwork/'
        'project.yaml, making zero filesystem changes', () async {
      File('${tempDir.path}/some_file.txt').writeAsStringSync('hello');
      final before = Directory(tempDir.path)
          .listSync(recursive: true)
          .map((e) => e.path)
          .toSet();

      final runner = CommandRunner('smartwork', 'test')
        ..addCommand(TargetCommand(projectPath: tempDir.path));
      final previousExitCode = exitCode;
      exitCode = 0;
      final output = await _captureOutput(() => runner.run(['target']));
      final code = exitCode;
      exitCode = previousExitCode;

      expect(code, 1);
      final text = output.join('\n');
      expect(text, contains('✗ This is not a SmartWork-generated project.'));
      expect(text, contains('smartwork target can only modify App Targets'));

      final after = Directory(tempDir.path)
          .listSync(recursive: true)
          .map((e) => e.path)
          .toSet();
      expect(after, before);
    });

    test('refuses to run against an empty directory', () async {
      final runner = CommandRunner('smartwork', 'test')
        ..addCommand(TargetCommand(projectPath: tempDir.path));
      final previousExitCode = exitCode;
      exitCode = 0;
      final output = await _captureOutput(() => runner.run(['target']));
      final code = exitCode;
      exitCode = previousExitCode;

      expect(code, 1);
      expect(output.join('\n'),
          contains('✗ This is not a SmartWork-generated project.'));
    });

    test('refuses to run against a plain (non-SmartWork) Flutter project',
        () async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: app\n');
      Directory('${tempDir.path}/lib').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final runner = CommandRunner('smartwork', 'test')
        ..addCommand(TargetCommand(projectPath: tempDir.path));
      final previousExitCode = exitCode;
      exitCode = 0;
      final output = await _captureOutput(() => runner.run(['target']));
      final code = exitCode;
      exitCode = previousExitCode;

      expect(code, 1);
      expect(output.join('\n'),
          contains('✗ This is not a SmartWork-generated project.'));
    });

    test('proceeds (past detection) for a genuine SmartWork project', () async {
      await ProjectConfigFile(projectPath: tempDir.path).write(_config());
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final command = TargetCommand(
        projectPath: tempDir.path,
        selectionReader: (prompt) => '1,2',
        confirmationReader: (prompt) => false,
      );
      final output = await _captureOutput(() => command.run());
      final text = output.join('\n');

      expect(text, isNot(contains('not a SmartWork-generated project')));
      expect(text, contains('Current App Targets'));
      expect(text, contains('✓ Android'));
      expect(text, contains('✓ iOS'));
      expect(text, contains('Available App Targets'));
    });
  });

  group(
      'TargetCommand.applyTargetChange — single confirmation, then '
      'the whole transaction, or nothing at all', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_target_apply_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'declining performs zero filesystem changes: no platform is '
        'created, .smartwork/project.yaml is not rewritten, and neither '
        'validation nor documentation ever runs', () async {
      final config = _config(appTargets: {AppTarget.android, AppTarget.ios});
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      final before = Directory(tempDir.path)
          .listSync(recursive: true)
          .map((e) => e.path)
          .toSet();

      final bootstrap = _RecordingFlutterBootstrap();
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (prompt) => false,
      );

      final output = await _captureOutput(() => command.applyTargetChange(
            config: config,
            requestedTargets: {AppTarget.android, AppTarget.ios, AppTarget.web},
          ));

      expect(output.join('\n'), contains('Operation cancelled.'));
      expect(output.join('\n'), contains('No changes were made.'));
      expect(bootstrap.calls, isEmpty,
          reason: 'declining must never invoke flutter create');

      final after = Directory(tempDir.path)
          .listSync(recursive: true)
          .map((e) => e.path)
          .toSet();
      expect(after, before);

      final stillOriginal =
          await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(stillOriginal.appTargets,
          unorderedEquals({AppTarget.android, AppTarget.ios}));
    });

    test(
        'confirming applies the whole transaction in one shot: new '
        'platform(s) created, config updated, validated, and '
        'documented — with only the one confirmation ever asked', () async {
      final config = _config(appTargets: {AppTarget.android, AppTarget.ios});
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      // A minimal pubspec so ProjectGenerator.generateDocumentation()
      // (which only needs paths.docs's parent to exist) can write.
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('name: demo_app\n');

      final bootstrap = _RecordingFlutterBootstrap();
      var confirmationCalls = 0;
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (prompt) {
          confirmationCalls++;
          return true;
        },
      );

      final output = await _captureOutput(() => command.applyTargetChange(
            config: config,
            requestedTargets: {
              AppTarget.android,
              AppTarget.ios,
              AppTarget.web,
              AppTarget.macos,
            },
          ));

      expect(confirmationCalls, 1,
          reason: 'exactly one confirmation for the entire operation');
      expect(
          bootstrap.calls,
          [
            {'web', 'macos'}
          ],
          reason: 'only the newly-added platforms are ever requested');

      expect(Directory('${tempDir.path}/web').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/macos').existsSync(), isTrue);

      final updated = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(
        updated.appTargets,
        unorderedEquals(
            {AppTarget.android, AppTarget.ios, AppTarget.web, AppTarget.macos}),
      );

      expect(File('${tempDir.path}/README.md').existsSync(), isTrue);
      final text = output.join('\n');
      expect(text, contains('Validation successful.'));
      expect(text, contains('README.md'));
    });

    test(
        'regression: cleans up the stock test/widget_test.dart that a '
        'real flutter create --platforms=... writes back when adding a '
        'platform, the same way smartwork init already does — leaving '
        'it in place would fail flutter test unconditionally afterwards',
        () async {
      final config = _config(appTargets: {AppTarget.android});
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();

      final bootstrap = _RecordingFlutterBootstrap();
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (prompt) => true,
      );

      await command.applyTargetChange(
        config: config,
        requestedTargets: {AppTarget.android, AppTarget.web},
      );

      expect(
          File('${tempDir.path}/test/widget_test.dart').existsSync(), isFalse);
    });

    test(
        'removing a target from the requested set drops it from '
        'configuration but never deletes its platform directory', () async {
      final config = _config(
        appTargets: {AppTarget.android, AppTarget.ios, AppTarget.web},
      );
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      Directory('${tempDir.path}/web').createSync();
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('name: demo_app\n');

      final bootstrap = _RecordingFlutterBootstrap();
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (prompt) => true,
      );

      final output = await _captureOutput(() => command.applyTargetChange(
            config: config,
            requestedTargets: {AppTarget.android, AppTarget.ios},
          ));

      expect(bootstrap.calls, isEmpty,
          reason: 'removing a target never triggers flutter create');
      expect(Directory('${tempDir.path}/web').existsSync(), isTrue,
          reason: 'an existing platform directory is preserved even when '
              'its target is removed from configuration');

      final updated = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(updated.appTargets,
          unorderedEquals({AppTarget.android, AppTarget.ios}));

      expect(
          output.join('\n'),
          contains('Existing platform directories '
              'will be preserved.'));
    });

    test(
        're-adding a target removed earlier restores it in '
        'configuration without re-running flutter create — its '
        'folder was never actually deleted', () async {
      final config = _config(
        appTargets: {AppTarget.android, AppTarget.ios, AppTarget.web},
      );
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      Directory('${tempDir.path}/web').createSync();
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('name: demo_app\n');

      final bootstrap = _RecordingFlutterBootstrap();
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (prompt) => true,
      );

      // Step 1: remove web from configuration (folder physically
      // stays, per the non-destructive-removal guarantee).
      await command.applyTargetChange(
        config: config,
        requestedTargets: {AppTarget.android, AppTarget.ios},
      );
      final afterRemoval =
          await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(afterRemoval.appTargets,
          unorderedEquals({AppTarget.android, AppTarget.ios}));
      expect(Directory('${tempDir.path}/web').existsSync(), isTrue);

      // Step 2: re-add web. Its folder is still there (it was never
      // deleted), so flutter create must not be invoked for it again.
      final output = await _captureOutput(() => command.applyTargetChange(
            config: afterRemoval,
            requestedTargets: {
              AppTarget.android,
              AppTarget.ios,
              AppTarget.web,
            },
          ));

      expect(bootstrap.calls, isEmpty,
          reason: "web's folder already existed on disk, so re-adding it "
              'must never re-run flutter create');

      final afterRestore =
          await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(
        afterRestore.appTargets,
        unorderedEquals({AppTarget.android, AppTarget.ios, AppTarget.web}),
      );

      expect(
        output.join('\n'),
        contains('Platform(s) already present, not recreated: Web'),
      );
    });

    test(
        'the planned-changes summary lists additions and removals '
        'before the single confirmation is asked', () async {
      final config = _config(
        appTargets: {AppTarget.android, AppTarget.ios},
      );
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final bootstrap = _RecordingFlutterBootstrap();
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (prompt) => false,
      );

      final output = await _captureOutput(() => command.applyTargetChange(
            config: config,
            requestedTargets: {AppTarget.android, AppTarget.web},
          ));
      final text = output.join('\n');

      expect(text, contains('Planned changes:'));
      expect(text, contains('Add:'));
      expect(text, contains('✓ Web'));
      expect(text, contains('Remove from SmartWork configuration:'));
      expect(text, contains('iOS'));
    });

    test(
        'a no-op selection (identical to the current set) reports no '
        'additions or removals', () async {
      final config = _config(
        appTargets: {AppTarget.android, AppTarget.ios},
      );
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final bootstrap = _RecordingFlutterBootstrap();
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (prompt) => false,
      );

      final output = await _captureOutput(() => command.applyTargetChange(
            config: config,
            requestedTargets: {AppTarget.ios, AppTarget.android},
          ));
      final text = output.join('\n');

      expect(text, contains('Add:\n    None'));
      expect(text, contains('Remove from SmartWork configuration:\n    None'));
    });

    test(
        'a validation failure is reported, and documentation is not '
        'generated/updated', () async {
      final config = _config(appTargets: {AppTarget.android});
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('name: demo_app\n');

      final bootstrap = _RecordingFlutterBootstrap();
      final command = TargetCommand(
        projectPath: tempDir.path,
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _failingValidator(),
        confirmationReader: (prompt) => true,
      );

      await expectLater(
        command.applyTargetChange(
          config: config,
          requestedTargets: {AppTarget.android, AppTarget.ios},
        ),
        throwsA(isA<ProjectValidationFailedException>()),
      );

      expect(File('${tempDir.path}/README.md').existsSync(), isFalse);
    });
  });

  group('TargetCommand.run() — interactive selection loop', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_target_prompt_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        're-prompts after an invalid selection, then proceeds once a '
        'valid one is given', () async {
      final config = _config(appTargets: {AppTarget.android});
      await ProjectConfigFile(projectPath: tempDir.path).write(config);
      Directory('${tempDir.path}/android').createSync();

      // '1,1' is deliberately not in this list: a repeated number is
      // normalized (see AppTargetSelection.parse), not invalid, so it
      // would end the retry loop rather than continuing it.
      final responses = ['', '9', '1,2'];
      var call = 0;

      final command = TargetCommand(
        projectPath: tempDir.path,
        selectionReader: (prompt) => responses[call++],
        confirmationReader: (prompt) => false,
      );

      final output = await _captureOutput(() => command.run());
      final text = output.join('\n');

      expect(call, 3, reason: 'kept re-prompting until a valid selection');
      expect(text, contains('❌'));
      expect(text, contains('Planned changes:'));
    });
  });
}
