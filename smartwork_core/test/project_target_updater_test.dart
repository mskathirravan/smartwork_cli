import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

ProjectConfig _config({Set<AppTarget>? appTargets}) {
  return ProjectConfig(
    projectName: 'demo_app',
    appTargets: appTargets ?? {AppTarget.android},
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.http,
    storage: Storage.sharedPreferences,
    initialFeatures: ['home'],
  );
}

/// Simulates real `flutter create --platforms=...`: records the
/// requested platforms, creates the matching directories, and writes
/// back the stock `test/widget_test.dart` smoke test — exactly what a
/// real `flutter create` re-run does, the same fixture shape
/// `smartwork_cli`'s own `target_command_test.dart` already
/// establishes.
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

ProjectValidator _passingValidator() => ProjectValidator(
      runProcess: (executable, arguments, {workingDirectory}) async =>
          ProcessResult(0, 0, '', ''),
    );

ProjectValidator _failingValidator() => ProjectValidator(
      runProcess: (executable, arguments, {workingDirectory}) async =>
          ProcessResult(0, 1, '', 'boom'),
    );

/// [ProjectTargetUpdater] — the real `smartwork target` sequence
/// (compute plan → create only genuinely-missing platforms → clean up
/// the stale widget test → persist config → validate → gate
/// documentation), extracted (V1 MCP-3) from `smartwork_cli`'s
/// `TargetCommand.applyTargetChange` so `smartwork_mcp`'s
/// `smartwork_target_apply` tool reuses the exact same pipeline.
void main() {
  group('ProjectTargetUpdater', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_core_target_');
      Directory('${tempDir.path}/android').createSync();
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: demo_app
dependencies:
  flutter:
    sdk: flutter
''');
      Directory('${tempDir.path}/lib').createSync();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'adding a target creates only the genuinely-missing platform '
        'folder', () async {
      final bootstrap = _RecordingFlutterBootstrap();
      final updater = ProjectTargetUpdater(
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
      );

      final result = await updater.apply(
        projectPath: tempDir.path,
        config: _config(),
        requestedTargets: {AppTarget.android, AppTarget.ios},
      );

      expect(result.platformsCreated, {AppTarget.ios});
      expect(bootstrap.calls.single, {'ios'});
      expect(Directory('${tempDir.path}/ios').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/android').existsSync(), isTrue,
          reason: 'the already-existing platform must be untouched');

      final config = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(config.appTargets, {AppTarget.android, AppTarget.ios});
    });

    test(
        're-adding a target whose folder already exists on disk never '
        'recreates it', () async {
      Directory('${tempDir.path}/ios').createSync();
      final bootstrap = _RecordingFlutterBootstrap();
      final updater = ProjectTargetUpdater(
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
      );

      final result = await updater.apply(
        projectPath: tempDir.path,
        config: _config(appTargets: {AppTarget.android}),
        requestedTargets: {AppTarget.android, AppTarget.ios},
      );

      expect(result.platformsCreated, isEmpty);
      expect(bootstrap.calls, isEmpty,
          reason: 'flutter create must never be invoked when nothing is '
              'genuinely missing');
    });

    test(
        'removing a target only drops it from configuration — the '
        'platform folder is never deleted', () async {
      Directory('${tempDir.path}/ios').createSync();
      final updater = ProjectTargetUpdater(
        flutterBootstrap: _RecordingFlutterBootstrap().build(tempDir),
        projectValidator: _passingValidator(),
      );

      await updater.apply(
        projectPath: tempDir.path,
        config: _config(appTargets: {AppTarget.android, AppTarget.ios}),
        requestedTargets: {AppTarget.android},
      );

      expect(Directory('${tempDir.path}/ios').existsSync(), isTrue,
          reason: 'removing a target never deletes its platform folder');
      final config = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(config.appTargets, {AppTarget.android});
    });

    test(
        'a failing validation throws ProjectValidationFailedException '
        'and never regenerates documentation', () async {
      final updater = ProjectTargetUpdater(
        flutterBootstrap: _RecordingFlutterBootstrap().build(tempDir),
        projectValidator: _failingValidator(),
      );

      await expectLater(
        updater.apply(
          projectPath: tempDir.path,
          config: _config(),
          requestedTargets: {AppTarget.android, AppTarget.ios},
        ),
        throwsA(isA<ProjectValidationFailedException>()),
      );
      expect(File('${tempDir.path}/README.md').existsSync(), isFalse);
    });

    test(
        'a no-op request (identical target set) still persists '
        'configuration and validates, creating no platform', () async {
      final bootstrap = _RecordingFlutterBootstrap();
      final updater = ProjectTargetUpdater(
        flutterBootstrap: bootstrap.build(tempDir),
        projectValidator: _passingValidator(),
      );

      final result = await updater.apply(
        projectPath: tempDir.path,
        config: _config(),
        requestedTargets: {AppTarget.android},
      );

      expect(result.plan.hasChanges, isFalse);
      expect(bootstrap.calls, isEmpty);
      expect(File('${tempDir.path}/README.md').existsSync(), isTrue);
    });
  });
}
