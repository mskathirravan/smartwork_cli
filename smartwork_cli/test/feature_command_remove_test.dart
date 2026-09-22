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
  List<String> initialFeatures = const [],
}) async {
  await ProjectConfigFile(projectPath: projectPath).write(
    ProjectConfig(
      projectName: 'demo_app',
      architecture: Architecture.cleanArchitecture,
      stateManagement: StateManagement.bloc,
      network: Network.http,
      storage: Storage.sharedPreferences,
      initialFeatures: initialFeatures,
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

/// Tests `smartwork feature remove <name>` — the CLI surface for
/// [FeatureLifecycle.removeFeature] — mirroring the existing add-path
/// tests in `feature_command_lifecycle_test.dart`.
void main() {
  group('FeatureCommand remove', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_remove_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('removes a previously added feature and updates routing', () async {
      await _writeProjectConfig(tempDir.path);
      await _captureOutput(
        () => _runFeatureCommand(tempDir.path, ['profile']),
      );

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['remove', 'profile']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Feature removed: profile'));
      expect(text, contains('Routing updated'));
      expect(
        Directory('${tempDir.path}/lib/features/profile').existsSync(),
        isFalse,
      );

      final router =
          File('${tempDir.path}/lib/services/routing/app_router.dart')
              .readAsStringSync();
      expect(router, isNot(contains('profile')));

      final config = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(config.initialFeatures, isNot(contains('profile')));
    });

    test('removing a feature name is required', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['remove']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Feature name is required'));
    });

    test(
        'removing a feature that was never generated is reported '
        'clearly, without touching anything', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['remove', 'ghost']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('ghost'));
      expect(text, contains('not found'));
    });

    test('removing the configured Home feature is refused', () async {
      // A minimal project state is enough here — the Home guard fires
      // before any filesystem check, purely from `ProjectConfig.
      // homeFeatureName`. The full "Home survives on disk" guarantee is
      // covered end-to-end, against a fully generated project, by
      // smartwork_core's routing_synchronization_test.dart.
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['remove', 'home']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Home'));
    });

    test('removing the protected Debug feature is refused', () async {
      // Same reasoning as the Home guard above: a minimal project state
      // is enough since the guard fires purely on the name `debug`,
      // before any filesystem check. The full "Debug survives on disk,
      // /debug still resolves, configuration unchanged" guarantee is
      // covered end-to-end, against a fully generated project, by
      // smartwork_core's routing_synchronization_test.dart.
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['remove', 'debug']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('debug'));
      expect(text, contains('Cannot remove'));
    });

    test('removing in an uninitialized project is reported clearly', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['remove', 'profile']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('No Smartwork project found'));
    });

    test(
        'a feature added without a page component reports routing as '
        'unchanged, and removing it also reports routing as unchanged',
        () async {
      await _writeProjectConfig(tempDir.path);

      late int addCode;
      final addOutput = await _captureOutput(() async {
        addCode = await _runFeatureCommand(
          tempDir.path,
          ['shared_utils', '--components', 'entity'],
        );
      });
      expect(addCode, 0);
      expect(addOutput.join('\n'), contains('Routing unchanged'));

      late int removeCode;
      final removeOutput = await _captureOutput(() async {
        removeCode =
            await _runFeatureCommand(tempDir.path, ['remove', 'shared_utils']);
      });
      expect(removeCode, 0);
      expect(removeOutput.join('\n'), contains('Routing unchanged'));
    });

    test(
        'a feature literally named "debug" reports routing as unchanged '
        'even though it has a page — the name is reserved, not the '
        'blueprint', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['debug']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Feature created: debug'));
      expect(text, contains('Routing unchanged'));
      expect(text, contains('reserved'));

      final config = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(config.initialFeatures, isNot(contains('debug')));
    });

    test(
        'synchronization: auth, profile, and settings are added, then '
        'profile is removed — the router keeps auth/settings and drops '
        'profile', () async {
      await _writeProjectConfig(tempDir.path);
      for (final name in ['auth', 'profile', 'settings']) {
        await _captureOutput(() => _runFeatureCommand(tempDir.path, [name]));
      }

      await _captureOutput(
        () => _runFeatureCommand(tempDir.path, ['remove', 'profile']),
      );

      final router =
          File('${tempDir.path}/lib/services/routing/app_router.dart')
              .readAsStringSync();
      expect(router, contains("case '/auth':"));
      expect(router, contains("case '/settings':"));
      expect(router, isNot(contains('profile')));
    });
  });
}
