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

/// Feature View Lifecycle Cross-check: proves `smartwork feature
/// <name>` / `smartwork feature remove <name>` — the actual CLI
/// surface, not just `FeatureLifecycle` directly — work correctly for
/// MVVM and MVP too, not only the Clean Architecture default every
/// prior `FeatureCommand` test exclusively used.
void main() {
  group('FeatureCommand — architecture matrix', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_cli_arch_matrix_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    for (final architecture in Architecture.values) {
      test(
          '$architecture: smartwork feature profile generates the '
          'correct View structure and routes it, then smartwork '
          'feature remove profile removes it completely', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: architecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: [],
        );
        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        late int addCode;
        final addOutput = await _captureOutput(() async {
          addCode = await _runFeatureCommand(tempDir.path, ['profile']);
        });
        expect(addCode, 0);
        expect(addOutput.join('\n'), contains('Routing updated'));

        final viewFolders = switch (architecture) {
          Architecture.cleanArchitecture => ['presentation'],
          Architecture.mvvm => ['views', 'viewmodels'],
          Architecture.mvp => ['views', 'presenters'],
        };
        for (final folder in viewFolders) {
          expect(
            Directory('${tempDir.path}/lib/features/profile/$folder')
                .existsSync(),
            isTrue,
            reason: '$architecture: missing $folder/',
          );
        }

        final router =
            File('${tempDir.path}/lib/services/routing/app_router.dart')
                .readAsStringSync();
        expect(router, contains("case '/profile':"));

        late int removeCode;
        final removeOutput = await _captureOutput(() async {
          removeCode =
              await _runFeatureCommand(tempDir.path, ['remove', 'profile']);
        });
        expect(removeCode, 0);
        expect(removeOutput.join('\n'), contains('Routing updated'));
        expect(
          Directory('${tempDir.path}/lib/features/profile').existsSync(),
          isFalse,
        );

        final routerAfter =
            File('${tempDir.path}/lib/services/routing/app_router.dart')
                .readAsStringSync();
        expect(routerAfter, isNot(contains('profile')));
      });
    }
  });
}
