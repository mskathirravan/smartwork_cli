@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/doctor_command.dart';
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

/// A [ProcessRunner] that succeeds for both `dart --version` and
/// `flutter --version`, returning realistic output.
ProcessRunner _bothToolsAvailable() {
  return (executable, arguments, {workingDirectory}) async {
    if (executable == 'dart') {
      return ProcessResult(0, 0, 'Dart SDK version: 3.9.0 (stable)', '');
    }
    if (executable == 'flutter') {
      return ProcessResult(0, 0, 'Flutter 3.35.0 • channel stable', '');
    }
    throw ProcessException(executable, arguments, 'unexpected executable');
  };
}

void main() {
  group('DoctorCommand.checkEnvironment', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_doctor_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'reports all environment checks passing when dart and flutter '
        'are both available', () async {
      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      expect(report.allPassed, isTrue);
      final labels = report.environment.map((c) => c.label).toList();
      expect(labels,
          containsAll(['SmartWork', 'Dart', 'Flutter executable', 'Flutter']));
      for (final check in report.environment) {
        expect(check.status, DoctorCheckStatus.pass,
            reason: '${check.label} should pass');
      }
    });

    test(
        'shows the SmartWork version when a version reader is '
        'available', () async {
      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '1.2.3',
      );

      final report = await command.checkEnvironment();

      final smartwork =
          report.environment.firstWhere((c) => c.label == 'SmartWork');
      expect(smartwork.detail, contains('1.2.3'));
    });

    test('never fails just because a version reader returns null', () async {
      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => null,
      );

      final report = await command.checkEnvironment();

      final smartwork =
          report.environment.firstWhere((c) => c.label == 'SmartWork');
      expect(smartwork.status, DoctorCheckStatus.pass);
    });

    test(
        'Dart unavailable (executable not found) fails the Dart check '
        'and the overall summary', () async {
      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (executable == 'dart') {
            throw ProcessException(executable, arguments, 'not found');
          }
          return ProcessResult(0, 0, 'Flutter 3.35.0', '');
        },
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      final dart = report.environment.firstWhere((c) => c.label == 'Dart');
      expect(dart.status, DoctorCheckStatus.fail);
      expect(dart.detail, contains('not found'));
      expect(report.allPassed, isFalse);
    });

    test(
        'Flutter unavailable (executable not found) fails both the '
        '"Flutter executable" and "Flutter" checks', () async {
      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (executable == 'flutter') {
            throw ProcessException(executable, arguments, 'not found');
          }
          return ProcessResult(0, 0, 'Dart SDK version: 3.9.0', '');
        },
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      final flutterExe =
          report.environment.firstWhere((c) => c.label == 'Flutter executable');
      final flutter =
          report.environment.firstWhere((c) => c.label == 'Flutter');
      expect(flutterExe.status, DoctorCheckStatus.fail);
      expect(flutter.status, DoctorCheckStatus.fail);
      expect(report.allPassed, isFalse);
    });

    test(
        'Flutter command failing (found on PATH, but exits non-zero) '
        'passes "Flutter executable" while still failing "Flutter"', () async {
      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (executable == 'flutter') {
            return ProcessResult(0, 1, '', 'some flutter internal error');
          }
          return ProcessResult(0, 0, 'Dart SDK version: 3.9.0', '');
        },
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      final flutterExe =
          report.environment.firstWhere((c) => c.label == 'Flutter executable');
      final flutter =
          report.environment.firstWhere((c) => c.label == 'Flutter');
      expect(flutterExe.status, DoctorCheckStatus.pass,
          reason: 'the executable was found and ran, even though it '
              'exited with an error');
      expect(flutter.status, DoctorCheckStatus.fail);
      expect(report.allPassed, isFalse);
    });

    test(
        'a non-Flutter directory reports informational context, never '
        'a failure', () async {
      File('${tempDir.path}/README.md').writeAsStringSync('hello');
      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      expect(report.project, hasLength(1));
      expect(report.project.single.status, DoctorCheckStatus.info);
      expect(report.allPassed, isTrue);
    });

    test(
        'a normal (non-SmartWork) Flutter project reports Flutter '
        'project passing and SmartWork project as informational', () async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: app\n');
      Directory('${tempDir.path}/lib').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      final flutterCheck =
          report.project.firstWhere((c) => c.label == 'Flutter project');
      final smartworkCheck =
          report.project.firstWhere((c) => c.label == 'SmartWork project');
      expect(flutterCheck.status, DoctorCheckStatus.pass);
      expect(smartworkCheck.status, DoctorCheckStatus.info);
      expect(report.allPassed, isTrue);
    });

    test(
        'a valid SmartWork project with every selected platform present '
        'reports all project checks passing', () async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          appTargets: {AppTarget.android, AppTarget.ios},
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      );
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      expect(report.project, hasLength(5));
      for (final check in report.project) {
        expect(check.status, DoctorCheckStatus.pass,
            reason: '${check.label} should pass for a valid project');
      }
      expect(report.allPassed, isTrue);
      expect(
        report.project.any((c) => c.label == 'App Targets: Android, iOS'),
        isTrue,
      );
      expect(
        report.project.any((c) => c.label == 'Services: (none)'),
        isTrue,
      );
    });

    test('reports configured Production Services, read-only', () async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          appTargets: {AppTarget.android},
          services: {Service.secureSession.id, Service.analytics.id},
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      );
      Directory('${tempDir.path}/android').createSync();

      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      final servicesCheck =
          report.project.firstWhere((c) => c.label.startsWith('Services:'));
      expect(servicesCheck.label, 'Services: Secure Session, Analytics');
      expect(servicesCheck.status, DoctorCheckStatus.pass);
    });

    test(
        'a valid SmartWork project missing a selected platform folder '
        'fails with a clear "Missing platform" check', () async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          appTargets: {AppTarget.android, AppTarget.ios, AppTarget.web},
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      );
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      // web/ deliberately missing.

      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      final missing = report.project
          .where((c) => c.label == 'Missing platform: web/')
          .toList();
      expect(missing, hasLength(1));
      expect(missing.single.status, DoctorCheckStatus.fail);
      expect(report.allPassed, isFalse);

      // The App Targets summary line itself still reports the full
      // configured set — the missing-platform check is separate,
      // additional information, not a rewrite of what's configured.
      expect(
        report.project.any((c) => c.label == 'App Targets: Android, iOS, Web'),
        isTrue,
      );
    });

    test(
        'malformed SmartWork metadata fails the summary and reports '
        'the problem clearly, without ever modifying the project', () async {
      Directory('${tempDir.path}/.smartwork').createSync();
      File('${tempDir.path}/.smartwork/project.yaml')
          .writeAsStringSync("projectName: 'my_app'\n");
      final before =
          File('${tempDir.path}/.smartwork/project.yaml').readAsStringSync();

      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );

      final report = await command.checkEnvironment();

      final smartworkCheck =
          report.project.firstWhere((c) => c.label == 'SmartWork project');
      final configCheck =
          report.project.firstWhere((c) => c.label == 'Configuration valid');
      expect(smartworkCheck.status, DoctorCheckStatus.fail);
      expect(configCheck.status, DoctorCheckStatus.fail);
      expect(configCheck.detail, isNotNull);
      expect(report.allPassed, isFalse);

      final after =
          File('${tempDir.path}/.smartwork/project.yaml').readAsStringSync();
      expect(after, before, reason: 'doctor must never modify the project');
    });

    test(
        'doctor never writes any file, even in a valid SmartWork '
        'project directory', () async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.dio,
          storage: Storage.hive,
          initialFeatures: ['auth'],
        ),
      );
      final filesBefore = Directory(tempDir.path)
          .listSync(recursive: true)
          .map((e) => e.path)
          .toSet();

      final command = DoctorCommand(
        projectPath: tempDir.path,
        runProcess: _bothToolsAvailable(),
        readVersion: () => '0.1.0',
      );
      await _captureOutput(() => command.checkEnvironment());

      final filesAfter = Directory(tempDir.path)
          .listSync(recursive: true)
          .map((e) => e.path)
          .toSet();
      expect(filesAfter, filesBefore);
    });
  });

  group('DoctorCommand.run() output and exit code', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_doctor_output_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    /// Runs `smartwork doctor` through a real [CommandRunner] (exactly
    /// as `bin/smartwork.dart` does), saving/restoring the process-
    /// global `exitCode` around it so this never leaks into the test
    /// runner's own exit status — the same pattern
    /// `feature_command_lifecycle_test.dart` already establishes.
    Future<int> runDoctor(DoctorCommand command) async {
      final runner = CommandRunner('smartwork', 'test')..addCommand(command);
      final previousExitCode = exitCode;
      exitCode = 0;
      await runner.run(['doctor']);
      final result = exitCode;
      exitCode = previousExitCode;
      return result;
    }

    test(
        'prints a status-oriented report with Environment/Project/'
        'Summary sections, and exits 0 when everything passes', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await runDoctor(DoctorCommand(
          projectPath: tempDir.path,
          runProcess: _bothToolsAvailable(),
          readVersion: () => '0.1.0',
        ));
      });

      expect(code, 0);
      final text = output.join('\n');
      expect(text, contains('SmartWork Doctor'));
      expect(text, contains('Environment'));
      expect(text, contains('Project'));
      expect(text, contains('Summary'));
      expect(text, contains('All checks passed.'));
      expect(text, contains('✓ SmartWork'));
      expect(text, contains('✓ Dart'));
      expect(text, contains('✓ Flutter'));
    });

    test(
        'exits non-zero and reports "Some checks failed." when a '
        'check fails', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await runDoctor(DoctorCommand(
          projectPath: tempDir.path,
          runProcess: (executable, arguments, {workingDirectory}) async {
            throw ProcessException(executable, arguments, 'not found');
          },
          readVersion: () => '0.1.0',
        ));
      });

      expect(code, 1);
      expect(output.join('\n'), contains('Some checks failed.'));
    });
  });
}
