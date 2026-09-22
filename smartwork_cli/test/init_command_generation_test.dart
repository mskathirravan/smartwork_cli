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

ProjectConfig _config({String projectName = 'demo_app', FontConfig? fonts}) {
  return ProjectConfig(
    projectName: projectName,
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.http,
    storage: Storage.sharedPreferences,
    fonts: fonts,
    initialFeatures: ['home'],
  );
}

/// Tests [InitCommand.generateProject] — the Flutter-bootstrap-then-
/// SmartWork-generate pipeline — using an injected [FlutterBootstrap]
/// so nothing here depends on a real `flutter` invocation. `run()`
/// itself is interactive (reads stdin, calls `exit()`) and is
/// deliberately not exercised here; `generateProject` is the public,
/// directly-testable seam this milestone added for exactly that reason.
void main() {
  group('InitCommand.generateProject', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_cli_init_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'a failed Flutter bootstrap stops generation: no SmartWork files '
        'are written', () async {
      final command = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: FlutterBootstrap(
          runProcess: (executable, arguments, {workingDirectory}) async {
            return ProcessResult(0, 1, '', 'flutter create failed');
          },
        ),
      );

      await expectLater(
        command.generateProject(_config()),
        throwsA(isA<FlutterBootstrapException>()),
      );

      expect(tempDir.listSync(), isEmpty,
          reason: 'a failed Flutter bootstrap must never be followed by '
              'SmartWork generation');
    });

    test(
        'a failed Flutter bootstrap never invokes SmartWork generation, '
        'even when the target already has unrelated content', () async {
      File('${tempDir.path}/keep_me.txt').writeAsStringSync('do not touch');

      final command = InitCommand(
        projectPath: tempDir.path,
        flutterBootstrap: FlutterBootstrap(
          runProcess: (executable, arguments, {workingDirectory}) async {
            return ProcessResult(0, 1, '', 'boom');
          },
        ),
      );

      await expectLater(
        command.generateProject(_config()),
        throwsA(isA<FlutterBootstrapException>()),
      );

      expect(File('${tempDir.path}/keep_me.txt').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/lib').existsSync(), isFalse);
      expect(File('${tempDir.path}/pubspec.yaml').existsSync(), isFalse);
    });

    test(
        'a successful Flutter bootstrap is followed by real SmartWork '
        'generation on top of it', () async {
      final command = InitCommand(
        projectPath: tempDir.path,
        // Validation is exercised in its own dedicated tests (see
        // init_command_validation_test.dart) with a controllable
        // ProjectValidator; here an always-passing fake keeps this
        // test focused on the bootstrap-then-generate pipeline alone.
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async {
            return ProcessResult(0, 0, '', '');
          },
        ),
        flutterBootstrap: FlutterBootstrap(
          runProcess: (executable, arguments, {workingDirectory}) async {
            // Simulates flutter create's own pubspec.yaml, exactly what
            // PubspecGenerator.mergeInto is meant to build on top of.
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
            // Matches _config()'s default AppTargets (android + ios) so
            // the new Platforms validation phase finds what it expects.
            Directory('${tempDir.path}/android').createSync();
            Directory('${tempDir.path}/ios').createSync();
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final lines = await _captureOutput(
        () => command.generateProject(_config()),
      );

      expect(lines.any((l) => l.contains('Flutter project created')), isTrue);
      expect(Directory('${tempDir.path}/lib/core').existsSync(), isTrue);
      expect(
        Directory('${tempDir.path}/lib/features/home').existsSync(),
        isTrue,
      );

      final pubspec = File('${tempDir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('flutter_bloc:'));
      expect(pubspec, contains('cupertino_icons: ^1.0.8'),
          reason: 'Flutter\'s own pubspec content must be preserved, not '
              'overwritten');
    });

    test(
        'includeFontSample: true embeds FontSample into the freshly '
        'generated Home page and reports it', () async {
      final command = InitCommand(
        projectPath: tempDir.path,
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async {
            return ProcessResult(0, 0, '', '');
          },
        ),
        flutterBootstrap: FlutterBootstrap(
          runProcess: (executable, arguments, {workingDirectory}) async {
            File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: demo_app
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter

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
        ),
      );

      final lines = await _captureOutput(
        () => command.generateProject(
          _config(
            fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
          ),
          includeFontSample: true,
        ),
      );

      expect(lines.any((l) => l.contains('Font sample')), isTrue);
      final home = File(
        '${tempDir.path}/lib/features/home/presentation/pages/home_page.dart',
      ).readAsStringSync();
      expect(home, contains('const FontSample()'));
      expect(
        File('${tempDir.path}/lib/shared/ui/font_sample.dart').existsSync(),
        isTrue,
      );
    });
  });
}
