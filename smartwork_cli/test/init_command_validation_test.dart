import 'dart:async';
import 'dart:io';

import 'package:smartwork_cli/src/commands/init_command.dart';
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

ProjectConfig _config() {
  return ProjectConfig(
    projectName: 'demo_app',
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.http,
    storage: Storage.sharedPreferences,
    initialFeatures: ['home'],
  );
}

FlutterBootstrap _passingBootstrap(Directory tempDir) {
  return FlutterBootstrap(
    runProcess: (executable, arguments, {workingDirectory}) async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: demo_app
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''');
      Directory('${tempDir.path}/lib').createSync();
      // Matches _config()'s default AppTargets (android + ios) so the
      // Platforms validation phase finds what it expects.
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      return ProcessResult(0, 0, '', '');
    },
  );
}

/// Tests the generation -> validation -> documentation ordering
/// [InitCommand.generateProject] enforces via an injected
/// [ProjectValidator], mirroring the same injection pattern
/// [FlutterBootstrap] already uses for testability.
void main() {
  group('InitCommand.generateProject validation wiring', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_cli_validate_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'when validation passes, README.md is generated and '
        'the exact success report is printed', () async {
      final command = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _passingBootstrap(tempDir),
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async {
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final lines = await _captureOutput(
        () => command.generateProject(_config()),
      );

      expect(File('${tempDir.path}/README.md').existsSync(), isTrue);
      expect(lines, contains('✓ Format'));
      expect(lines, contains('✓ Dependencies'));
      expect(lines, contains('✓ Analyze'));
      expect(lines, contains('✓ Tests'));
      expect(lines, contains('Validation successful.'));
      expect(lines, contains('✓ README.md'));
    });

    test(
        'when validation fails, README.md is never generated, '
        'the report stops at the failing phase, and generateProject '
        'throws ProjectValidationFailedException', () async {
      final command = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _passingBootstrap(tempDir),
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async {
            final isAnalyze = arguments.contains('analyze');
            return ProcessResult(0, isAnalyze ? 1 : 0, '', '');
          },
        ),
      );

      final lines = <String>[];
      await runZoned(
        () async {
          await expectLater(
            command.generateProject(_config()),
            throwsA(isA<ProjectValidationFailedException>()),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => lines.add(line),
        ),
      );

      expect(File('${tempDir.path}/README.md').existsSync(), isFalse,
          reason: 'a failed validation must never be followed by '
              'documentation generation');
      expect(Directory('${tempDir.path}/docs').existsSync(), isFalse);

      expect(lines, contains('✓ Format'));
      expect(lines, contains('✓ Dependencies'));
      expect(lines, contains('✗ Analyze'));
      expect(lines, isNot(contains('✓ Tests')),
          reason: 'flutter test must never run once analyze has failed');
      expect(lines, isNot(contains('✗ Tests')));
      expect(
        lines,
        contains(
          'Project documentation was not generated because validation '
          'failed.',
        ),
      );
      expect(lines, isNot(contains('Validation successful.')));
    });

    test(
        'a failing Format phase alone stops the whole pipeline before '
        'Dependencies/Analyze/Tests ever run', () async {
      final command = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _passingBootstrap(tempDir),
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async {
            final isFormat = executable == 'dart';
            return ProcessResult(0, isFormat ? 1 : 0, '', '');
          },
        ),
      );

      final lines = <String>[];
      await runZoned(
        () async {
          await expectLater(
            command.generateProject(_config()),
            throwsA(isA<ProjectValidationFailedException>()),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => lines.add(line),
        ),
      );

      expect(lines, contains('✗ Format'));
      expect(lines, isNot(contains('✓ Dependencies')));
      expect(lines, isNot(contains('✓ Analyze')));
      expect(lines, isNot(contains('✓ Tests')));
      expect(File('${tempDir.path}/README.md').existsSync(), isFalse);
    });
  });
}
