@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/feature_command.dart';
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

Future<void> _writeProjectConfig(
  String projectPath, {
  Architecture architecture = Architecture.cleanArchitecture,
  StateManagement stateManagement = StateManagement.bloc,
}) async {
  await ProjectConfigFile(projectPath: projectPath).write(
    ProjectConfig(
      projectName: 'demo_app',
      architecture: architecture,
      stateManagement: stateManagement,
      network: Network.http,
      storage: Storage.sharedPreferences,
      initialFeatures: ['home'],
    ),
  );
}

Future<int> _runFeatureCommand(String projectPath, List<String> args) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(FeatureCommand(projectPath: projectPath));
  final previousExitCode = exitCode;
  exitCode = 0;
  await runner.run(['feature', ...args]);
  final result = exitCode;
  exitCode = previousExitCode;
  return result;
}

void main() {
  group('FeatureCommand lifecycle', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_lifecycle_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('successful feature generation reports counts and next step',
        () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['auth']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Feature created: auth'));
      expect(text, contains('Architecture'));
      expect(text, contains('State management'));
      expect(text, contains('Generated:'));
      expect(text, contains('files'));
      expect(text, contains('directories'));
      expect(text, contains('Start implementing auth'));
    });

    test('existing feature is refused with a clear conflict message', () async {
      await _writeProjectConfig(tempDir.path);
      await _captureOutput(() async {
        await _runFeatureCommand(tempDir.path, ['auth']);
      });

      final blocFile =
          File('${tempDir.path}/lib/features/auth/state/auth_bloc.dart');
      final contentBefore = blocFile.readAsStringSync();

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['auth']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Feature already exists: auth'));
      expect(text, contains('No files were modified'));
      expect(blocFile.readAsStringSync(), contentBefore);
    });

    test('invalid feature name is rejected with a clear message', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['Invalid-Name']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Invalid feature name'));
      expect(
        Directory('${tempDir.path}/lib/features').existsSync(),
        isFalse,
      );
    });

    test('uninitialized project is reported clearly', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['auth']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('No Smartwork project found'));
      expect(text, contains('smartwork init'));
    });

    test('a second, different feature still generates independently', () async {
      await _writeProjectConfig(tempDir.path);
      await _captureOutput(() async {
        await _runFeatureCommand(tempDir.path, ['auth']);
      });

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['profile']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Feature created: profile'));
      expect(
        Directory('${tempDir.path}/lib/features/auth').existsSync(),
        isTrue,
      );
      expect(
        Directory('${tempDir.path}/lib/features/profile').existsSync(),
        isTrue,
      );
    });
  });
}
