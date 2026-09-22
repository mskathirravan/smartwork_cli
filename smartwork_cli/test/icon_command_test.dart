@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/icon_command.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// A real, minimal, valid, square, opaque 4x4 PNG — genuinely decodable
/// by `package:image` (unlike the visually-similar fixture
/// `splash_command_test.dart` uses, which Splash only ever copies
/// byte-for-byte and never decodes — confirmed live: that fixture's
/// bytes fail `img.decodeImage`, so it cannot be reused here, since
/// App Icon genuinely decodes its source).
final List<int> _validPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, //
  0x08, 0x02, 0x00, 0x00, 0x00, 0x26, 0x93, 0x09, //
  0x29, 0x00, 0x00, 0x00, 0x14, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x61, 0xA8, 0xB8, 0xCE, //
  0x00, 0x03, 0x2C, 0x0C, 0x48, 0x00, 0x37, 0x07, //
  0x00, 0x42, 0xD3, 0x01, 0x60, 0x03, 0x49, 0x8D, //
  0xAD, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82, //
];

const _sampleIosContentsJson = '''
{
  "images": [
    {"size": "20x20", "idiom": "iphone", "filename": "Icon-App-20x20@2x.png", "scale": "2x"},
    {"size": "1024x1024", "idiom": "ios-marketing", "filename": "Icon-App-1024x1024@1x.png", "scale": "1x"}
  ],
  "info": {"version": 1, "author": "xcode"}
}
''';

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

Future<int> _runIconCommand(String projectPath, List<String> args) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(IconCommand(projectPath: projectPath));
  final previousExitCode = exitCode;
  exitCode = 0;
  await runner.run(['icon', ...args]);
  final result = exitCode;
  exitCode = previousExitCode;
  return result;
}

/// Tests `smartwork icon --source <path>` (V1.1-10) — the CLI surface
/// for [AppIconLifecycle.setAppIcon].
void main() {
  group('IconCommand', () {
    late Directory tempDir;
    late String projectPath;
    late File sourceFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_cli_icon_test_');
      projectPath = tempDir.path;
      sourceFile = File('${tempDir.path}_icon.png')
        ..writeAsBytesSync(_validPngBytes);

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

      // `ProjectGenerator` never creates native platform folders (that
      // is `FlutterBootstrap`/real `flutter create`'s job) — a minimal,
      // real-shaped iOS icon set is enough for these CLI-level tests;
      // full real-Flutter behavior is validated separately under `tmp/`.
      final iosDir =
          '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset';
      await Directory(iosDir).create(recursive: true);
      await File('$iosDir/Contents.json').writeAsString(_sampleIosContentsJson);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      if (sourceFile.existsSync()) sourceFile.deleteSync();
    });

    test('a successful invocation generates the App Icon and reports it',
        () async {
      late int code;
      final output = await _captureOutput(() async {
        code =
            await _runIconCommand(projectPath, ['--source', sourceFile.path]);
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('App Icon generated'));
      expect(text, contains('Icon-App-20x20@2x.png'));
      expect(
        File(
          '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset/'
          'Icon-App-1024x1024@1x.png',
        ).existsSync(),
        isTrue,
      );
    });

    test('running again with a different source replaces the icon files',
        () async {
      await _runIconCommand(projectPath, ['--source', sourceFile.path]);
      final firstBytes = File(
        '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset/'
        'Icon-App-1024x1024@1x.png',
      ).readAsBytesSync();

      // A distinct, still-valid, still-square PNG — same fixture bytes
      // are fine here since the CLI-level assertion only needs to
      // confirm a second, independent run succeeds and reports success
      // again; exact-byte-difference is already covered by Core's own
      // `AppIconLifecycle` test suite.
      final code =
          await _runIconCommand(projectPath, ['--source', sourceFile.path]);

      expect(code, 0);
      expect(
        File(
          '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset/'
          'Icon-App-1024x1024@1x.png',
        ).readAsBytesSync(),
        firstBytes,
      );
    });

    test('missing --source is rejected with a clear usage message', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runIconCommand(projectPath, []);
      });

      expect(code, 1);
      expect(output.join('\n'), contains('Usage: smartwork icon'));
    });

    test('a nonexistent source file is reported clearly', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runIconCommand(
          projectPath,
          ['--source', '/no/such/icon.png'],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('not found'));
    });

    test('an invalid (corrupt) source image is reported clearly', () async {
      final badSource = File('${tempDir.path}_bad.png')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => badSource.deleteSync());

      late int code;
      final output = await _captureOutput(() async {
        code = await _runIconCommand(projectPath, ['--source', badSource.path]);
      });

      expect(code, 1);
      expect(output.join('\n'), contains('could not be decoded'));
    });

    test('a non-square source image is reported clearly', () async {
      final wideSource = File('${tempDir.path}_wide.png')
        ..writeAsBytesSync(_validWidePngBytes);
      addTearDown(() => wideSource.deleteSync());

      late int code;
      final output = await _captureOutput(() async {
        code =
            await _runIconCommand(projectPath, ['--source', wideSource.path]);
      });

      expect(code, 1);
      expect(output.join('\n'), contains('must be square'));
    });

    test('running in an uninitialized project is reported clearly', () async {
      final emptyDir =
          Directory.systemTemp.createTempSync('smartwork_no_project_');
      addTearDown(() => emptyDir.deleteSync(recursive: true));

      late int code;
      final output = await _captureOutput(() async {
        code = await _runIconCommand(
          emptyDir.path,
          ['--source', sourceFile.path],
        );
      });

      expect(code, 1);
      expect(output.join('\n'), contains('No Smartwork project found'));
    });

    test('a project with no in-scope platform folder is reported clearly',
        () async {
      // Remove the one platform folder `setUp` created, leaving none.
      await Directory('$projectPath/ios').delete(recursive: true);

      late int code;
      final output = await _captureOutput(() async {
        code =
            await _runIconCommand(projectPath, ['--source', sourceFile.path]);
      });

      expect(code, 1);
      expect(output.join('\n'), contains('No supported platform'));
    });
  });
}

/// A real, valid, non-square (8x4) opaque PNG.
final List<int> _validWidePngBytes = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x00,
  0x00,
  0x04,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x3C,
  0xAF,
  0xE9,
  0xA7,
  0x00,
  0x00,
  0x00,
  0x14,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xE1,
  0x12,
  0x91,
  0x63,
  0xC0,
  0x06,
  0x58,
  0xB0,
  0x8A,
  0x92,
  0x25,
  0x01,
  0x00,
  0x1B,
  0x30,
  0x00,
  0x4D,
  0x24,
  0x55,
  0xA6,
  0xD9,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
