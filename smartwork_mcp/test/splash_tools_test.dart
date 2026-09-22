import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// A real, minimal, valid 4x4 PNG.
final List<int> _validPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, //
  0x08, 0x02, 0x00, 0x00, 0x00, 0x26, 0x93, 0x09, //
  0x29, 0x00, 0x00, 0x00, 0x15, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x62, 0x62, 0x60, 0x60, 0xF8, //
  0xCF, 0x40, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x03, //
  0x00, 0x02, 0x9C, 0x01, 0x9E, 0x97, 0xF6, 0x25, //
  0x0F, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82, //
];

/// Real in-process MCP protocol tests for the V1.1-8 Splash Screen tool
/// — every request goes through `initialize`/`tools/list`/`tools/call`,
/// never a direct Dart method call. Mirrors
/// `feature_service_tools_test.dart`'s exact setup: `SplashLifecycle`
/// only ever needs `.smartwork/project.yaml` to exist, never a real
/// `flutter create`-bootstrapped project, for these fast, protocol-level
/// checks — full real-Flutter behavior is validated separately under
/// `tmp/`.
void main() {
  group('V1.1-8 Splash Screen tool', () {
    late Directory tempDir;
    late File iconFile;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    Future<void> writeProjectConfig() async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        ),
      );
    }

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_splash_');
      iconFile = File('${tempDir.path}_icon.png')
        ..writeAsBytesSync(_validPngBytes);
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
      if (iconFile.existsSync()) iconFile.deleteSync();
    });

    Future<CallToolResult> call(String name, Map<String, Object?> args) =>
        connection.callTool(CallToolRequest(name: name, arguments: args));

    group('tool registration', () {
      test('tools/list contains smartwork_splash_add', () async {
        final result = await connection.listTools();

        expect(
          result.tools.map((t) => t.name),
          contains('smartwork_splash_add'),
        );
      });
    });

    group('splash_add', () {
      test(
          'adds Splash Screen to a real project via the real MCP '
          'protocol', () async {
        await writeProjectConfig();

        final result = await call('smartwork_splash_add', {
          'projectPath': tempDir.path,
          'backgroundColor': '#2E7D32',
          'iconPath': iconFile.path,
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        expect(structured['success'], isTrue);
        expect(structured['operation'], 'splash_add');
        expect(
          (structured['result'] as Map)['iconAssetPath'],
          'assets/icons/${iconFile.uri.pathSegments.last}',
        );
        expect(
          File('${tempDir.path}/lib/shared/ui/splash_screen.dart').existsSync(),
          isTrue,
        );
        final barrel = File('${tempDir.path}/lib/shared/ui/shared_ui.dart')
            .readAsStringSync();
        expect(barrel, contains("export 'splash_screen.dart';"));
      });

      test(
          'running again with different values updates Splash in '
          'place, matching Core semantics', () async {
        await writeProjectConfig();
        await call('smartwork_splash_add', {
          'projectPath': tempDir.path,
          'backgroundColor': '#2E7D32',
          'iconPath': iconFile.path,
        });

        final result = await call('smartwork_splash_add', {
          'projectPath': tempDir.path,
          'backgroundColor': 'FF0000',
          'iconPath': iconFile.path,
        });

        expect(result.isError, isNot(true));
        final content = File(
          '${tempDir.path}/lib/shared/ui/splash_screen.dart',
        ).readAsStringSync();
        expect(content, contains('Color(0xFFFF0000)'));
      });

      test(
          'an invalid background color matches Core semantics '
          '(InvalidSplashConfigException)', () async {
        await writeProjectConfig();

        final result = await call('smartwork_splash_add', {
          'projectPath': tempDir.path,
          'backgroundColor': 'not-a-color',
          'iconPath': iconFile.path,
        });

        expect(result.isError, isTrue);
        final structured = result.structuredContent!;
        expect(structured['success'], isFalse);
        expect(
          (structured['error'] as Map)['code'],
          'invalid_splash_config',
        );
      });

      test(
          'a missing icon file matches Core semantics '
          '(InvalidSplashConfigException)', () async {
        await writeProjectConfig();

        final result = await call('smartwork_splash_add', {
          'projectPath': tempDir.path,
          'backgroundColor': '#2E7D32',
          'iconPath': '/no/such/icon.png',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_splash_config',
        );
      });

      test('a directory with no SmartWork project fails safely', () async {
        final result = await call('smartwork_splash_add', {
          'projectPath': tempDir.path,
          'backgroundColor': '#2E7D32',
          'iconPath': iconFile.path,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'no_project',
        );
      });

      test(
          'missing required backgroundColor/iconPath is rejected by '
          'the tool schema', () async {
        await writeProjectConfig();

        final result = await call('smartwork_splash_add', {
          'projectPath': tempDir.path,
        });

        expect(result.isError, isTrue);
      });
    });
  });
}
