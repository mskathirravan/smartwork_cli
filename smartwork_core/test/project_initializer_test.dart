import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

ProjectConfig _config({String projectName = 'demo_app'}) {
  return ProjectConfig(
    projectName: projectName,
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
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      return ProcessResult(0, 0, '', '');
    },
  );
}

FlutterBootstrap _failingBootstrap() {
  return FlutterBootstrap(
    runProcess: (executable, arguments, {workingDirectory}) async {
      throw const ProcessException('flutter', ['create'], 'not found');
    },
  );
}

/// [ProjectInitializer] — the real `smartwork init` sequence (bootstrap
/// → clear-if-regenerating → generate → validate → document, only
/// generating documentation once validation passes), extracted (V1
/// MCP-2) from `smartwork_cli`'s `InitCommand.generateProject` so
/// `smartwork_mcp`'s `smartwork_init_apply` tool reuses the exact same
/// pipeline instead of independently reimplementing it. Mirrors the
/// exact fake-`FlutterBootstrap`/`ProjectValidator` injection pattern
/// `smartwork_cli`'s own `init_command_generation_test.dart`/
/// `init_command_validation_test.dart` already establish.
void main() {
  group('ProjectInitializer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_core_init_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('a failed Flutter bootstrap throws before any generation happens',
        () async {
      final initializer = ProjectInitializer(
        flutterBootstrap: _failingBootstrap(),
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async =>
              ProcessResult(0, 0, '', ''),
        ),
      );

      await expectLater(
        initializer.initialize(
          projectPath: tempDir.path,
          config: _config(),
        ),
        throwsA(isA<FlutterBootstrapException>()),
      );
      expect(Directory('${tempDir.path}/lib').existsSync(), isFalse,
          reason: 'no SmartWork generation should happen when bootstrap '
              'fails');
    });

    test(
        'a successful sequence bootstraps, generates, validates, and '
        'documents — in that order', () async {
      final initializer = ProjectInitializer(
        flutterBootstrap: _passingBootstrap(tempDir),
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async =>
              ProcessResult(0, 0, '', ''),
        ),
      );

      final result = await initializer.initialize(
        projectPath: tempDir.path,
        config: _config(),
      );

      expect(result.validation.passed, isTrue);
      expect(result.generation.featureCount, greaterThan(0));
      expect(File('${tempDir.path}/README.md').existsSync(), isTrue);
      expect(
          Directory('${tempDir.path}/lib/features/home').existsSync(), isTrue);
    });

    test(
        'a failing validation phase throws ProjectValidationFailedException '
        'and never generates documentation', () async {
      final initializer = ProjectInitializer(
        flutterBootstrap: _passingBootstrap(tempDir),
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async {
            final isAnalyze = arguments.contains('analyze');
            return ProcessResult(0, isAnalyze ? 1 : 0, '', '');
          },
        ),
      );

      await expectLater(
        initializer.initialize(
          projectPath: tempDir.path,
          config: _config(),
        ),
        throwsA(isA<ProjectValidationFailedException>()),
      );
      expect(File('${tempDir.path}/README.md').existsSync(), isFalse,
          reason: 'a failed validation must never be followed by '
              'documentation generation');
    });

    test(
        'clearExisting clears previously generated content before '
        'regenerating, so a second call never throws '
        'FeatureAlreadyExistsException on Home', () async {
      final passingValidator = ProjectValidator(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, '', ''),
      );

      await ProjectInitializer(
        flutterBootstrap: _passingBootstrap(tempDir),
        projectValidator: passingValidator,
      ).initialize(projectPath: tempDir.path, config: _config());

      await expectLater(
        ProjectInitializer(
          flutterBootstrap: _passingBootstrap(tempDir),
          projectValidator: passingValidator,
        ).initialize(
          projectPath: tempDir.path,
          config: _config(),
          clearExisting: true,
        ),
        completes,
      );
    });
  });
}
