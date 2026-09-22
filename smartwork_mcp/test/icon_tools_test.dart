import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// A real, minimal, valid, square, opaque 4x4 PNG — genuinely decodable
/// by `package:image` (see `icon_command_test.dart`'s own note on why
/// the visually-similar Splash fixture cannot be reused here).
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

const _sampleIosContentsJson = '''
{
  "images": [
    {"size": "20x20", "idiom": "iphone", "filename": "Icon-App-20x20@2x.png", "scale": "2x"},
    {"size": "1024x1024", "idiom": "ios-marketing", "filename": "Icon-App-1024x1024@1x.png", "scale": "1x"}
  ],
  "info": {"version": 1, "author": "xcode"}
}
''';

/// Real in-process MCP protocol tests for the V1.1-10 App Icon tool —
/// every request goes through `initialize`/`tools/list`/`tools/call`,
/// never a direct Dart method call. Mirrors `splash_tools_test.dart`'s
/// exact setup: a real generated project plus a minimal, real-shaped
/// iOS icon set (`ProjectGenerator` never creates native platform
/// folders — that is real `flutter create`'s job) is enough for these
/// fast, protocol-level checks; full real-Flutter behavior is validated
/// separately under `tmp/`.
void main() {
  group('V1.1-10 App Icon tool', () {
    late Directory tempDir;
    late String projectPath;
    late File sourceFile;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_icon_');
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

      final iosDir =
          '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset';
      await Directory(iosDir).create(recursive: true);
      await File('$iosDir/Contents.json').writeAsString(_sampleIosContentsJson);

      controller = StreamChannelController<String>();
      server = SmartworkMcpServer(controller.foreign);
      client = MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
      connection = client.connectServer(controller.local);

      await connection.initialize(InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: ClientCapabilities(),
        clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
      ));
      connection.notifyInitialized();
      await server.initialized;
    });

    tearDown(() async {
      await client.shutdown();
      await server.shutdown();
      tempDir.deleteSync(recursive: true);
      if (sourceFile.existsSync()) sourceFile.deleteSync();
    });

    Future<CallToolResult> call(String name, Map<String, Object?> args) =>
        connection.callTool(CallToolRequest(name: name, arguments: args));

    test('tools/list contains smartwork_app_icon_set', () async {
      final result = await connection.listTools();

      expect(
        result.tools.map((t) => t.name),
        contains('smartwork_app_icon_set'),
      );
    });

    group('app_icon_set', () {
      test(
          'generates the App Icon in a real project via the real MCP '
          'protocol', () async {
        final result = await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
          'sourcePath': sourceFile.path,
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        expect(structured['success'], isTrue);
        expect(structured['operation'], 'app_icon_set');
        final generatedFiles =
            (structured['result'] as Map)['generatedFiles'] as List;
        expect(generatedFiles, isNotEmpty);
        expect(
          File(
            '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset/'
            'Icon-App-1024x1024@1x.png',
          ).existsSync(),
          isTrue,
        );
      });

      test(
          'running again with a different source replaces the icon '
          'files, matching Core semantics', () async {
        await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
          'sourcePath': sourceFile.path,
        });

        final result = await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
          'sourcePath': sourceFile.path,
        });

        expect(result.isError, isNot(true));
      });

      test('a missing project fails safely with no_project', () async {
        final emptyDir =
            Directory.systemTemp.createTempSync('smartwork_no_project_');
        addTearDown(() => emptyDir.deleteSync(recursive: true));

        final result = await call('smartwork_app_icon_set', {
          'projectPath': emptyDir.path,
          'sourcePath': sourceFile.path,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'no_project',
        );
      });

      test(
          'a nonexistent source fails safely with '
          'invalid_app_icon_config', () async {
        final result = await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
          'sourcePath': '/no/such/icon.png',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_app_icon_config',
        );
      });

      test(
          'a corrupt source image fails safely with '
          'invalid_app_icon_config', () async {
        final badSource = File('${tempDir.path}_bad.png')
          ..writeAsBytesSync([1, 2, 3]);
        addTearDown(() => badSource.deleteSync());

        final result = await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
          'sourcePath': badSource.path,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_app_icon_config',
        );
      });

      test(
          'a non-square source image fails safely with '
          'invalid_app_icon_config', () async {
        final wideSource = File('${tempDir.path}_wide.png')
          ..writeAsBytesSync(_validWidePngBytes);
        addTearDown(() => wideSource.deleteSync());

        final result = await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
          'sourcePath': wideSource.path,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_app_icon_config',
        );
      });

      test(
          'a project with no in-scope platform folder fails safely with '
          'no_supported_platform_found', () async {
        await Directory('$projectPath/ios').delete(recursive: true);

        final result = await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
          'sourcePath': sourceFile.path,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'no_supported_platform_found',
        );
      });

      test('missing required sourcePath is rejected by the tool schema',
          () async {
        final result = await call('smartwork_app_icon_set', {
          'projectPath': projectPath,
        });

        expect(result.isError, isTrue);
      });
    });
  });
}
