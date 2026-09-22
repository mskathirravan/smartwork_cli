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

/// A [FlutterBootstrap] whose `create()` simulates real `flutter
/// create`'s idempotent behavior: it writes the baseline pubspec.yaml
/// only the first time (an already-bootstrapped Flutter project is
/// never clobbered by running `flutter create` again).
FlutterBootstrap _idempotentBootstrap(Directory tempDir) {
  return FlutterBootstrap(
    runProcess: (executable, arguments, {workingDirectory}) async {
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      if (!pubspec.existsSync()) {
        pubspec.writeAsStringSync('''
name: my_app
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
      }
      // Matches _mvpConfig()/_cleanConfig()'s default AppTargets
      // (android + ios) so the Platforms validation phase finds what
      // it expects, on both the first and any subsequent run.
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      return ProcessResult(0, 0, '', '');
    },
  );
}

ProjectValidator _passingValidator() {
  return ProjectValidator(
    runProcess: (executable, arguments, {workingDirectory}) async {
      return ProcessResult(0, 0, '', '');
    },
  );
}

ProjectValidator _failingValidator() {
  return ProjectValidator(
    runProcess: (executable, arguments, {workingDirectory}) async {
      final isAnalyze = arguments.contains('analyze');
      return ProcessResult(0, isAnalyze ? 1 : 0, '', '');
    },
  );
}

ProjectConfig _mvpConfig() {
  return ProjectConfig(
    projectName: 'my_app',
    architecture: Architecture.mvp,
    stateManagement: StateManagement.getx,
    network: Network.http,
    storage: Storage.sharedPreferences,
    initialFeatures: ['auth'],
  );
}

ProjectConfig _cleanConfig() {
  return ProjectConfig(
    projectName: 'my_app',
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.http,
    storage: Storage.sharedPreferences,
    initialFeatures: ['auth'],
  );
}

/// Recursively snapshots every file's relative path -> content under
/// [root], for a byte-exact "nothing changed" comparison — stronger
/// than checking a single file exists.
Map<String, String> _snapshot(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return {};
  final snapshot = <String, String>{};
  for (final entry in dir.listSync(recursive: true)) {
    if (entry is File) {
      final relative = entry.path.substring(root.length);
      snapshot[relative] = entry.readAsStringSync();
    }
  }
  return snapshot;
}

/// Project Safety & Regeneration V1: end-to-end tests for
/// [InitCommand.checkSafetyAndGenerate] — the full detect → warn →
/// confirm → (clear +) generate → validate → document sequence,
/// against a real, previously generated SmartWork project on disk.
void main() {
  group('InitCommand regeneration', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_regen_cmd_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'declining regeneration of an existing SmartWork project '
        'leaves every file byte-for-byte unchanged', () async {
      final firstRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) => true,
      );
      await _captureOutput(() => firstRun.checkSafetyAndGenerate(_mvpConfig()));

      final before = _snapshot(tempDir.path);
      expect(before, isNotEmpty);

      final secondRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) => false,
      );

      late List<String> output;
      output = await _captureOutput(
        () => secondRun.checkSafetyAndGenerate(_cleanConfig()),
      );

      final after = _snapshot(tempDir.path);
      expect(after, equals(before),
          reason: 'declining must leave every generated file untouched');

      final text = output.join('\n');
      expect(text, contains('SmartWork project detected'));
      expect(text, contains('Operation cancelled.'));
      expect(text, contains('No files were changed.'));
    });

    test(
        'confirming regeneration switches architecture and updates '
        '.smartwork/project.yaml to the new configuration', () async {
      final firstRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) => true,
      );
      await _captureOutput(() => firstRun.checkSafetyAndGenerate(_mvpConfig()));

      expect(
        Directory('${tempDir.path}/lib/features/auth/presenters').existsSync(),
        isTrue,
      );

      final secondRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) => true,
      );
      final output = await _captureOutput(
        () => secondRun.checkSafetyAndGenerate(_cleanConfig()),
      );

      expect(
        Directory('${tempDir.path}/lib/features/auth/presenters').existsSync(),
        isFalse,
        reason: 'stale MVP presenters/ must not survive regeneration',
      );
      expect(
        Directory('${tempDir.path}/lib/features/auth/domain').existsSync(),
        isTrue,
      );

      final config = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(config.architecture, Architecture.cleanArchitecture);
      expect(config.stateManagement, StateManagement.bloc);

      final text = output.join('\n');
      expect(text, contains('SmartWork project detected'));
      expect(text, contains('Validation successful.'));
      expect(text, contains('README.md'));
    });

    test(
        'regenerating with a different App Targets selection shows the '
        'existing-vs-new diff, adds only the missing platform, and asks '
        'exactly one confirmation for the whole operation', () async {
      final firstRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) => true,
      );
      await _captureOutput(
        () => firstRun.checkSafetyAndGenerate(
          ProjectConfig(
            projectName: 'my_app',
            appTargets: {AppTarget.android, AppTarget.ios},
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          ),
        ),
      );
      expect(Directory('${tempDir.path}/web').existsSync(), isFalse);

      final platformCalls = <Set<String>>[];
      var confirmationCalls = 0;
      final secondRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: FlutterBootstrap(
          runProcess: (executable, arguments, {workingDirectory}) async {
            final platformsArg = arguments.firstWhere(
              (a) => a.startsWith('--platforms='),
              orElse: () => '',
            );
            final requested = platformsArg.isEmpty
                ? <String>{}
                : platformsArg
                    .substring('--platforms='.length)
                    .split(',')
                    .toSet();
            platformCalls.add(requested);
            for (final platform in requested) {
              Directory('${tempDir.path}/$platform')
                  .createSync(recursive: true);
            }
            return ProcessResult(0, 0, '', '');
          },
        ),
        projectValidator: _passingValidator(),
        confirmationReader: (_) {
          confirmationCalls++;
          return true;
        },
      );

      final output = await _captureOutput(
        () => secondRun.checkSafetyAndGenerate(
          ProjectConfig(
            projectName: 'my_app',
            appTargets: {AppTarget.android, AppTarget.ios, AppTarget.web},
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          ),
        ),
      );

      expect(confirmationCalls, 1);
      expect(Directory('${tempDir.path}/web').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/android').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/ios').existsSync(), isTrue);
      expect(platformCalls, [
        {'android', 'ios', 'web'}
      ]);

      final text = output.join('\n');
      expect(text, contains('Existing App Targets:'));
      expect(text, contains('New App Targets:'));
      expect(text, contains('Validation successful.'));
    });

    test(
        'regenerating with a different Production Services selection '
        'shows Added/Removed/Kept, generates only the new files, and '
        'removes stale ones — the exact secureSession+connectivity+'
        'analytics -> connectivity+logger+crashReporting scenario', () async {
      final firstRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) => true,
      );
      await _captureOutput(
        () => firstRun.checkSafetyAndGenerate(
          ProjectConfig(
            projectName: 'my_app',
            services: {
              Service.secureSession.id,
              Service.connectivity.id,
              Service.analytics.id,
            },
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          ),
        ),
      );

      final servicesDir = Directory('${tempDir.path}/lib/services');
      expect(
        servicesDir.listSync().map((e) => e.path.split('/').last).toSet(),
        {
          'bootstrap',
          'network',
          'routing',
          'storage',
          'theme',
          Service.secureSession.folderName,
          Service.connectivity.folderName,
          Service.analytics.folderName,
          'services.dart',
        },
      );

      var confirmationCalls = 0;
      final secondRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) {
          confirmationCalls++;
          return true;
        },
      );

      final output = await _captureOutput(
        () => secondRun.checkSafetyAndGenerate(
          ProjectConfig(
            projectName: 'my_app',
            services: {
              Service.connectivity.id,
              Service.logger.id,
              Service.crashReporting.id,
            },
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          ),
        ),
      );

      expect(confirmationCalls, 1,
          reason: 'exactly one confirmation for the whole operation, '
              'covering App Targets and Services alike');

      final remaining = Directory('${tempDir.path}/lib/services')
          .listSync()
          .map((e) => e.path.split('/').last)
          .toSet();
      expect(
        remaining,
        {
          'bootstrap',
          'network',
          'routing',
          'storage',
          'theme',
          Service.connectivity.folderName,
          Service.logger.folderName,
          Service.crashReporting.folderName,
          'services.dart',
        },
        reason: 'secureSession and analytics were deselected and must '
            'not survive regeneration; connectivity is kept, logger and '
            'crashReporting are newly added',
      );

      final config = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(
        config.services,
        unorderedEquals({'connectivity', 'logger', 'crashReporting'}),
      );

      final text = output.join('\n');
      expect(text, contains('Service changes:'));
      expect(text, contains('+ Debug Logger'));
      expect(text, contains('+ Crash Reporting'));
      expect(text, contains('- Secure Session'));
      expect(text, contains('- Analytics'));
      expect(text, contains('✓ Connectivity Monitor'));
      expect(text, contains('Validation successful.'));
    });

    test(
        'regeneration still runs full validation, and documentation is '
        'generated only after it passes — a failing regeneration '
        'leaves README.md exactly as it was', () async {
      final firstRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) => true,
      );
      await _captureOutput(() => firstRun.checkSafetyAndGenerate(_mvpConfig()));

      final docsBefore = File('${tempDir.path}/README.md').readAsStringSync();

      final secondRun = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _failingValidator(),
        confirmationReader: (_) => true,
      );

      final output = <String>[];
      Object? caughtError;
      await runZoned(
        () async {
          try {
            await secondRun.checkSafetyAndGenerate(_cleanConfig());
          } catch (e) {
            caughtError = e;
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );
      expect(caughtError, isA<ProjectValidationFailedException>());

      final text = output.join('\n');
      expect(text, contains('✓ Format'));
      expect(text, contains('✗ Analyze'));
      expect(
          text,
          contains('Project documentation was not generated '
              'because validation failed.'));

      final docsAfter = File('${tempDir.path}/README.md').readAsStringSync();
      expect(docsAfter, docsBefore,
          reason: 'a failed regeneration must never touch existing docs');

      // The architecture switch itself still happened on disk (the new
      // Clean structure is there) even though validation subsequently
      // failed — documentation is the thing gated on validation, not
      // generation itself.
      final config = await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(config.architecture, Architecture.cleanArchitecture);
    });

    test(
        'an empty target directory shows no existing-project warning, '
        'but the single confirmation is still asked and honored', () async {
      var confirmationCalls = 0;
      final command = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: _idempotentBootstrap(tempDir),
        projectValidator: _passingValidator(),
        confirmationReader: (_) {
          confirmationCalls++;
          return true;
        },
      );

      final output = await _captureOutput(
        () => command.checkSafetyAndGenerate(_cleanConfig()),
      );

      expect(confirmationCalls, 1,
          reason: 'exactly one confirmation for the entire operation, '
              'even for a fresh, empty directory');
      final text = output.join('\n');
      expect(text, isNot(contains('SmartWork project detected')));
      expect(text, isNot(contains('Existing Flutter project detected')));
      expect(text, contains('Validation successful.'));
      expect(
        Directory('${tempDir.path}/lib/features/auth').existsSync(),
        isTrue,
      );
    });
  });
}
