import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/model_command.dart';
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

Future<int> _runFromJson(String projectPath, List<String> args) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(ModelCommand(projectPath: projectPath));
  final previousExitCode = exitCode;
  exitCode = 0;
  await runner.run(['model', 'from-json', ...args]);
  final result = exitCode;
  exitCode = previousExitCode;
  return result;
}

/// Tests `smartwork model from-json <json-file-path> --feature
/// <feature-name>` (V1.1-9) — the CLI surface for
/// [ModelLifecycle.generateFromJson].
void main() {
  group('FromJsonCommand', () {
    late Directory tempDir;
    late String projectPath;
    late File jsonFile;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_model_test_');
      projectPath = tempDir.path;
      jsonFile = File('${tempDir.path}_user.json');

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      if (jsonFile.existsSync()) jsonFile.deleteSync();
    });

    test('a successful invocation generates the model and reports it',
        () async {
      await jsonFile.writeAsString(jsonEncode({'id': 1, 'name': 'John'}));

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(
          projectPath,
          [jsonFile.path, '--feature', 'profile'],
        );
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Model generated'));
      expect(text, contains('_model.dart'));
      expect(
        Directory('$projectPath/lib/features/profile/data/models')
            .listSync()
            .any((f) =>
                f.path.endsWith('_model.dart') &&
                !f.path.endsWith('profile_model.dart')),
        isTrue,
      );
    });

    test(
        'missing JSON file path argument is rejected with a clear usage '
        'message', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(projectPath, ['--feature', 'profile']);
      });

      expect(code, 1);
      expect(output.join('\n'), contains('JSON file path is required'));
    });

    test('missing --feature is rejected with a clear usage message', () async {
      await jsonFile.writeAsString(jsonEncode({'id': 1}));

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(projectPath, [jsonFile.path]);
      });

      expect(code, 1);
      expect(output.join('\n'), contains('--feature is required'));
    });

    test('a nonexistent JSON file is reported clearly', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(
          projectPath,
          ['/no/such/file.json', '--feature', 'profile'],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('JSON file not found'));
    });

    test('invalid JSON content is reported clearly', () async {
      await jsonFile.writeAsString('{not valid');

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(
          projectPath,
          [jsonFile.path, '--feature', 'profile'],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('Invalid JSON'));
    });

    test('a nonexistent feature is reported clearly', () async {
      await jsonFile.writeAsString(jsonEncode({'id': 1}));

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(
          projectPath,
          [jsonFile.path, '--feature', 'does_not_exist'],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('Feature not found'));
    });

    test('running in an uninitialized project is reported clearly', () async {
      final emptyDir =
          Directory.systemTemp.createTempSync('smartwork_no_project_');
      addTearDown(() => emptyDir.deleteSync(recursive: true));
      await jsonFile.writeAsString(jsonEncode({'id': 1}));

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(
          emptyDir.path,
          [jsonFile.path, '--feature', 'profile'],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('No Smartwork project found'));
    });

    test(
        'an existing model file collision is reported clearly, with no '
        'uncaught exception', () async {
      await jsonFile.writeAsString(jsonEncode({'id': 1}));
      await _runFromJson(projectPath, [jsonFile.path, '--feature', 'profile']);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(
          projectPath,
          [jsonFile.path, '--feature', 'profile'],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('Refusing to overwrite'));
    });

    test('a root JSON array is rejected clearly', () async {
      await jsonFile.writeAsString('[1, 2, 3]');

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFromJson(
          projectPath,
          [jsonFile.path, '--feature', 'profile'],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('Unsupported JSON root'));
    });
  });
}
