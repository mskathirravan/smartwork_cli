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

/// This file owns CLI-level concerns for `--components`: parsing,
/// validation, communication, and orchestration into the existing
/// FeatureConfig/FeatureGenerator. It does not re-verify core generation
/// semantics (file shapes, import correctness, architecture translation)
/// — those belong to smartwork_core's own test suite. The existing
/// default-command behavior (no `--components`) is covered by
/// feature_command_lifecycle_test.dart and is not duplicated here.
void main() {
  group('FeatureCommand --components', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_components_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'explicit single component generates only that component (plus '
        'its resolved dependencies) and reports it', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'entity']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Components: entity'));
      // entity has no dependencies, so no expansion line.
      expect(text, isNot(contains('Resolved:')));
      expect(
        File('${tempDir.path}/lib/features/auth/domain/entities/auth.dart')
            .existsSync(),
        isTrue,
      );
      expect(
        File('${tempDir.path}/lib/features/auth/domain/repositories/auth_repository.dart')
            .existsSync(),
        isFalse,
        reason: 'repository was not requested and has no reason to exist',
      );
    });

    test('multiple explicit components are all generated', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'entity,repository,page']);
      });

      expect(code, 0);
      final featurePath = '${tempDir.path}/lib/features/auth';
      expect(
          File('$featurePath/domain/entities/auth.dart').existsSync(), isTrue);
      expect(
        File('$featurePath/domain/repositories/auth_repository.dart')
            .existsSync(),
        isTrue,
      );
      expect(
        File('$featurePath/presentation/pages/auth_page.dart').existsSync(),
        isTrue,
      );
    });

    test(
        'dependency expansion is reported and the resolved config drives '
        'generation: repository pulls in entity and dataSource', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'repository']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Components: repository'));
      expect(text, contains('Resolved:'));
      expect(text, contains('entity'));
      expect(text, contains('dataSource'));
      // The "Generated:" breakdown must reflect the resolved set, not
      // just the raw request — entity/data source really were written.
      expect(text, contains('Entity'));
      expect(text, contains('Data source'));

      final featurePath = '${tempDir.path}/lib/features/auth';
      expect(
          File('$featurePath/domain/entities/auth.dart').existsSync(), isTrue);
      expect(
        File('$featurePath/data/datasources/auth_data_source.dart')
            .existsSync(),
        isTrue,
      );
    });

    test(
        'dependency expansion: useCase transitively pulls in repository, '
        'entity, and dataSource', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'useCase']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Components: useCase'));
      expect(text, contains('Resolved:'));

      final featurePath = '${tempDir.path}/lib/features/auth';
      for (final expected in [
        'domain/entities/auth.dart',
        'domain/repositories/auth_repository.dart',
        'domain/usecases/auth_usecase.dart',
        'data/datasources/auth_data_source.dart',
      ]) {
        expect(File('$featurePath/$expected').existsSync(), isTrue,
            reason: '$expected should exist');
      }
    });

    test('widgets component generates the widget file', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'widgets']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Components: widgets'));
      expect(text, isNot(contains('Resolved:')),
          reason: 'widgets has no dependencies');
      expect(
        File('${tempDir.path}/lib/features/auth/presentation/widgets/auth_widget.dart')
            .existsSync(),
        isTrue,
      );
    });

    test(
        'tests component causes page to be resolved in and generates a '
        'test file under the top-level test/ directory', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'tests']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Components: tests'));
      expect(text, contains('Resolved:'));
      expect(text, contains('page'));

      expect(
        File('${tempDir.path}/lib/features/auth/presentation/pages/auth_page.dart')
            .existsSync(),
        isTrue,
        reason: 'tests requires page; it must be resolved in',
      );
      expect(
        File('${tempDir.path}/test/features/auth/auth_page_test.dart')
            .existsSync(),
        isTrue,
      );
    });

    test('unknown component is rejected before any generation occurs',
        () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'entity,notarealthing']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Unknown component'));
      expect(text, contains('notarealthing'));
      expect(text, contains('Valid components:'));
      expect(
        Directory('${tempDir.path}/lib/features/auth').existsSync(),
        isFalse,
        reason: 'no partial generation should happen on validation failure',
      );
    });

    test('duplicate component names collapse without error', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'entity,entity,entity']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Components: entity'));
      expect(
        File('${tempDir.path}/lib/features/auth/domain/entities/auth.dart')
            .existsSync(),
        isTrue,
      );
    });

    test('whitespace and mixed casing around component names are accepted',
        () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', ' Entity , PAGE ']);
      });

      expect(code, 0);
      final featurePath = '${tempDir.path}/lib/features/auth';
      expect(
          File('$featurePath/domain/entities/auth.dart').existsSync(), isTrue);
      expect(
        File('$featurePath/presentation/pages/auth_page.dart').existsSync(),
        isTrue,
      );
    });

    test(
        'an explicitly empty --components value generates a name-only '
        'feature with no blueprint content', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', '']);
      });

      expect(code, 0);
      final featurePath = Directory('${tempDir.path}/lib/features/auth');
      expect(featurePath.existsSync(), isTrue);
      // Only the architecture skeleton (.placeholder) and the always-on
      // state-management files exist; no blueprint-driven .dart files.
      expect(
        File('${featurePath.path}/domain/entities/auth.dart').existsSync(),
        isFalse,
      );
      expect(
        File('${featurePath.path}/presentation/pages/auth_page.dart')
            .existsSync(),
        isFalse,
      );
    });

    test(
        'lifecycle protection still refuses a duplicate feature when '
        '--components was used to create it', () async {
      await _writeProjectConfig(tempDir.path);
      await _captureOutput(() async {
        await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'entity']);
      });

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(
            tempDir.path, ['auth', '--components', 'page']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Feature already exists: auth'));
      expect(
        File('${tempDir.path}/lib/features/auth/presentation/pages/auth_page.dart')
            .existsSync(),
        isFalse,
        reason: 'the second, conflicting request must not have run at all',
      );
    });

    test(
        'omitting --components entirely preserves the exact default '
        'output and behavior', () async {
      await _writeProjectConfig(tempDir.path);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFeatureCommand(tempDir.path, ['auth']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, isNot(contains('Components:')),
          reason: 'the Components/Resolved lines only appear when '
              '--components was explicitly provided');
      expect(text, isNot(contains('Resolved:')));
    });
  });
}
