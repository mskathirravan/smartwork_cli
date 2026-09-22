import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/doctor_command.dart';
import 'package:smartwork_cli/src/commands/feature_command.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Runs [body], discarding everything printed via `print()` during it.
Future<void> _silently(Future<void> Function() body) => runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {},
      ),
    );

/// A [ProcessRunner] that succeeds for both `dart --version` and
/// `flutter --version`, returning realistic output — mirrors
/// `doctor_command_test.dart`'s own private helper of the same shape.
ProcessRunner _bothToolsAvailable() {
  return (executable, arguments, {workingDirectory}) async {
    if (executable == 'dart') {
      return ProcessResult(0, 0, 'Dart SDK version: 3.9.0 (stable)', '');
    }
    if (executable == 'flutter') {
      return ProcessResult(0, 0, 'Flutter 3.35.0 • channel stable', '');
    }
    throw ProcessException(executable, arguments, 'unexpected executable');
  };
}

/// V1 Architecture Final Audit, item 21 (README Safety): documentation
/// generation belongs only to `smartwork init`'s (and `smartwork
/// target`'s) post-validation step — `smartwork feature <name>`/
/// `smartwork feature remove <name>` must never write, overwrite, or
/// otherwise touch an existing `README.md`, whether it's a developer's
/// own or SmartWork's previously generated one.
void main() {
  group('FeatureCommand — README safety', () {
    late Directory tempDir;
    late File readmeFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_readme_safety_');

      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: const [],
        ),
      );

      readmeFile = File('${tempDir.path}/README.md');
      await readmeFile.writeAsString(
        '# demo_app\n\nA developer wrote this by hand.\n',
      );
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('smartwork feature <name> never touches an existing README.md',
        () async {
      final before = readmeFile.readAsStringSync();
      final modifiedBefore = readmeFile.lastModifiedSync();

      final runner = CommandRunner('smartwork', 'test')
        ..addCommand(FeatureCommand(projectPath: tempDir.path));
      await _silently(() => runner.run(['feature', 'auth']));

      expect(readmeFile.readAsStringSync(), before);
      expect(readmeFile.lastModifiedSync(), modifiedBefore);
    });

    test(
        'smartwork feature remove <name> never touches an existing '
        'README.md', () async {
      final runner = CommandRunner('smartwork', 'test')
        ..addCommand(FeatureCommand(projectPath: tempDir.path));
      await _silently(() => runner.run(['feature', 'auth']));

      final before = readmeFile.readAsStringSync();
      final modifiedBefore = readmeFile.lastModifiedSync();

      await _silently(() => runner.run(['feature', 'remove', 'auth']));

      expect(readmeFile.readAsStringSync(), before);
      expect(readmeFile.lastModifiedSync(), modifiedBefore);
    });

    test(
        'attempting to remove the protected Debug feature never touches '
        'an existing README.md either', () async {
      final before = readmeFile.readAsStringSync();
      final modifiedBefore = readmeFile.lastModifiedSync();

      final runner = CommandRunner('smartwork', 'test')
        ..addCommand(FeatureCommand(projectPath: tempDir.path));
      await _silently(() => runner.run(['feature', 'remove', 'debug']));

      expect(readmeFile.readAsStringSync(), before);
      expect(readmeFile.lastModifiedSync(), modifiedBefore);
    });

    test(
        'smartwork doctor never touches an existing README.md either — '
        'it is strictly read-only', () async {
      final before = readmeFile.readAsStringSync();
      final modifiedBefore = readmeFile.lastModifiedSync();

      final runner = CommandRunner('smartwork', 'test')
        ..addCommand(DoctorCommand(
          projectPath: tempDir.path,
          runProcess: _bothToolsAvailable(),
        ));
      await _silently(() => runner.run(['doctor']));

      expect(readmeFile.readAsStringSync(), before);
      expect(readmeFile.lastModifiedSync(), modifiedBefore);
    });
  });
}
