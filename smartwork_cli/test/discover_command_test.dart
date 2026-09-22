@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/discover_command.dart';
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

Future<int> _runDiscoverCommand(
  String projectPath,
  List<String> args,
) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(DiscoverCommand(projectPath: projectPath));
  final previousExitCode = exitCode;
  exitCode = 0;
  await runner.run(['discover', ...args]);
  final result = exitCode;
  exitCode = previousExitCode;
  return result;
}

/// Tests `smartwork discover [--json]` (V1.1-12) — the CLI surface for
/// [DiscoverLifecycle.discover].
void main() {
  group('DiscoverCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_discover_test_');
      projectPath = tempDir.path;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'a successful invocation against a real SmartWork project prints '
        'a human-readable summary with confidence levels', () async {
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

      late int code;
      final output = await _captureOutput(() async {
        code = await _runDiscoverCommand(projectPath, []);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Project: demo_app'));
      expect(text, contains('Architecture: cleanArchitecture (declared)'));
      expect(text, contains('State Management: bloc (declared)'));
      expect(text, contains('Dependency Injection:'));
    });

    test('low confidence never causes a command failure', () async {
      // A real, but non-SmartWork, Flutter-shaped project — architecture
      // and state management will both be unknown/low-confidence, but
      // that must never be a non-zero exit.
      await File('$projectPath/pubspec.yaml').create(recursive: true);
      await File('$projectPath/pubspec.yaml').writeAsString('''
name: foreign_app
environment:
  sdk: ^3.0.0
''');
      await Directory('$projectPath/lib').create(recursive: true);
      await Directory('$projectPath/android').create(recursive: true);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runDiscoverCommand(projectPath, []);
      });

      expect(code, 0);
      expect(output.join('\n'), contains('Architecture: unknown'));
    });

    test(
        'a non-project target is reported clearly with a non-zero exit '
        'code', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runDiscoverCommand(projectPath, []);
      });

      expect(code, 1);
      expect(output.join('\n'), contains('Not a Flutter project'));
    });

    test('--json prints the complete ProjectKnowledge as valid JSON', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.getx,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();

      late int code;
      final output = await _captureOutput(() async {
        code = await _runDiscoverCommand(projectPath, ['--json']);
      });

      expect(code, 0);
      final decoded = jsonDecode(output.join('\n')) as Map<String, dynamic>;
      expect(decoded['architecture']['value'], 'mvp');
      expect(decoded['architecture']['confidence'], 'declared');
      expect(decoded['stateManagement']['value'], 'getx');
    });
  });
}
