@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/service_command.dart';
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

/// Stands in for `flutter pub get` so these tests never run real Flutter.
ProjectValidator _validator({ProcessResult? pubGet, List<String>? calls}) =>
    ProjectValidator(
      runProcess: (executable, arguments, {workingDirectory}) async {
        calls?.add('$executable ${arguments.join(' ')}');
        return pubGet ?? ProcessResult(0, 0, '', '');
      },
    );

Future<int> _runServiceCommand(
  String projectPath,
  List<String> args, {
  ProjectValidator? validator,
}) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(ServiceCommand(
      projectPath: projectPath,
      projectValidator: validator ?? _validator(),
    ));
  final previousExitCode = exitCode;
  exitCode = 0;
  await runner.run(['service', ...args]);
  final result = exitCode;
  exitCode = previousExitCode;
  return result;
}

/// Tests `smartwork service add <name>` / `smartwork service remove
/// <name>` — the CLI surface for [ServiceLifecycle].
void main() {
  group('ServiceCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_service_test_');
      projectPath = tempDir.path;

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: {Service.secureSession.id},
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'adding a service with a package (forceUpdate → package_info_plus) '
        'runs flutter pub get; one without a package does not', () async {
      final calls = <String>[];
      await _captureOutput(() async {
        await _runServiceCommand(
          projectPath,
          ['add', 'analytics'],
          validator: _validator(calls: calls),
        );
      });
      expect(calls, isEmpty);

      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(
          projectPath,
          ['add', 'forceUpdate'],
          validator: _validator(calls: calls),
        );
      });
      expect(code, 0);
      expect(calls, ['flutter pub get']);
      expect(output, contains('✔ Dependencies resolved (flutter pub get).'));
    });

    test('add generates the service and reports Bootstrap wiring', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['add', 'analytics']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Service added: Analytics'));
      expect(text, contains('Bootstrap updated'));
      expect(
        File('$projectPath/lib/services/analytics/analytics_service.dart')
            .existsSync(),
        isTrue,
      );

      final updatedConfig =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(updatedConfig.services, contains('analytics'));
    });

    test(
        'add reports "Bootstrap unchanged" for a service with no '
        'initialize()', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['add', 'deviceInfo']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Bootstrap unchanged'));
    });

    test(
        'add deeplink reports a routing example, forwarding query '
        'parameters as route arguments', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['add', 'deeplink']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('AppRouter stays the single routing authority'));
      expect(text, contains('DeeplinkService.instance.uriStream.listen'));
      expect(text, contains('navigatorKey.currentState?.pushNamed'));
      expect(text, contains('arguments: uri.queryParameters'));
    });

    test('add analytics never shows the deeplink routing example', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['add', 'analytics']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, isNot(contains('DeeplinkService.instance.uriStream')));
    });

    test('remove deletes the service and reports it', () async {
      late int code;
      final output = await _captureOutput(() async {
        code =
            await _runServiceCommand(projectPath, ['remove', 'secureSession']);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Service removed: Secure Session'));
      expect(
        Directory('$projectPath/lib/services/secure_session').existsSync(),
        isFalse,
      );

      final updatedConfig =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(updatedConfig.services, isNot(contains('secureSession')));
    });

    test('rejects an unknown service name, listing the valid ones', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['add', 'firebase']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Unknown service: firebase'));
      expect(text, contains('Valid services:'));
      expect(text, contains('analytics'));
    });

    test(
        'rejects bootstrap/routing/network/storage/theme as unknown '
        'services for both add and remove — infrastructure is never '
        'reachable through this command', () async {
      for (final infraName in [
        'bootstrap',
        'routing',
        'network',
        'storage',
        'theme',
      ]) {
        late int addCode;
        final addOutput = await _captureOutput(() async {
          addCode = await _runServiceCommand(projectPath, ['add', infraName]);
        });
        expect(addCode, 1, reason: '$infraName must be rejected by add');
        expect(addOutput.join('\n'), contains('Unknown service'));

        late int removeCode;
        final removeOutput = await _captureOutput(() async {
          removeCode =
              await _runServiceCommand(projectPath, ['remove', infraName]);
        });
        expect(removeCode, 1, reason: '$infraName must be rejected by remove');
        expect(removeOutput.join('\n'), contains('Unknown service'));

        expect(
          Directory('$projectPath/lib/services/$infraName').existsSync(),
          isTrue,
          reason: 'lib/services/$infraName must survive the attempt',
        );
      }
    });

    test(
        'remove of a not-currently-selected service is refused, '
        'nothing changed', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['remove', 'analytics']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Service not selected: analytics'));
    });

    test('add of an already-selected service is refused, nothing changed',
        () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['add', 'secureSession']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Service already selected: secureSession'));
    });

    test('requires an explicit add/remove action', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['analytics']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Unknown action'));
    });

    test('requires a service name after the action', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(projectPath, ['add']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Service name is required'));
    });

    test('running in an uninitialized project is reported clearly', () async {
      final emptyDir =
          Directory.systemTemp.createTempSync('smartwork_no_project_');
      addTearDown(() => emptyDir.deleteSync(recursive: true));

      late int code;
      final output = await _captureOutput(() async {
        code = await _runServiceCommand(emptyDir.path, ['add', 'analytics']);
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('No Smartwork project found'));
    });

    test('never touches routing or an existing README.md', () async {
      final readmeFile = File('$projectPath/README.md');
      await readmeFile.writeAsString('# demo_app\n\nHand-written.\n');
      final routerBefore =
          File('$projectPath/lib/services/routing/app_router.dart')
              .readAsStringSync();

      await _captureOutput(
        () => _runServiceCommand(projectPath, ['add', 'analytics']),
      );
      await _captureOutput(
        () => _runServiceCommand(projectPath, ['remove', 'secureSession']),
      );

      expect(readmeFile.readAsStringSync(), '# demo_app\n\nHand-written.\n');
      expect(
        File('$projectPath/lib/services/routing/app_router.dart')
            .readAsStringSync(),
        routerBefore,
      );
    });

    test(
        'never touches lib/features/ — service lifecycle is completely '
        'independent of FeatureLifecycle', () async {
      await _captureOutput(
        () => _runServiceCommand(projectPath, ['remove', 'secureSession']),
      );

      expect(Directory('$projectPath/lib/features/home').existsSync(), isTrue);
      expect(Directory('$projectPath/lib/features/debug').existsSync(), isTrue);
    });
  });
}
