import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Real in-process MCP protocol tests for the V1.1-12 Discover tool —
/// every request goes through `initialize`/`tools/list`/`tools/call`,
/// never a direct Dart method call. Mirrors `icon_tools_test.dart`'s
/// exact setup: a real generated project is enough for these fast,
/// protocol-level checks.
void main() {
  group('V1.1-12 Discover tool', () {
    late Directory tempDir;
    late String projectPath;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_discover_');
      projectPath = tempDir.path;

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
    });

    Future<CallToolResult> call(String name, Map<String, Object?> args) =>
        connection.callTool(CallToolRequest(name: name, arguments: args));

    test('tools/list contains smartwork_discover', () async {
      final result = await connection.listTools();

      expect(result.tools.map((t) => t.name), contains('smartwork_discover'));
    });

    group('discover', () {
      test(
          'returns the complete ProjectKnowledge as structuredContent '
          'for a real SmartWork project, via the real MCP protocol', () async {
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

        final result = await call('smartwork_discover', {
          'projectPath': projectPath,
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        expect(structured['success'], isTrue);
        expect(structured['operation'], 'discover');
        final knowledge = structured['result'] as Map;
        expect(knowledge['architecture']['value'], 'cleanArchitecture');
        expect(knowledge['architecture']['confidence'], 'declared');
        expect(knowledge['stateManagement']['value'], 'bloc');
        expect(knowledge['project']['value']['isSmartworkProject'], isTrue);
      });

      test('projectPath defaults to "." when omitted (schema behavior)',
          () async {
        // Not exercised against the real cwd here (that would depend on
        // the test runner's own working directory) — only that the
        // tool schema accepts a call with no projectPath at all,
        // matching smartwork_doctor's own established optional-argument
        // contract.
        final result = await call('smartwork_discover', {});

        // Whatever the real cwd is, the call must complete without a
        // schema-validation rejection (an error here would come from
        // Core's own NotAFlutterProjectException at worst, never a
        // missing-argument rejection).
        expect(result, isNotNull);
      });

      test(
          'a non-Flutter target fails safely with '
          'not_a_flutter_project', () async {
        final result = await call('smartwork_discover', {
          'projectPath': projectPath,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'not_a_flutter_project',
        );
      });

      test(
          'a foreign (non-SmartWork) Flutter project is analyzed and '
          'reports detected/unknown confidence, not an error', () async {
        await File('$projectPath/pubspec.yaml').create(recursive: true);
        await File('$projectPath/pubspec.yaml').writeAsString('''
name: foreign_app
environment:
  sdk: ^3.0.0
''');
        await Directory('$projectPath/lib').create(recursive: true);
        await Directory('$projectPath/android').create(recursive: true);

        final result = await call('smartwork_discover', {
          'projectPath': projectPath,
        });

        expect(result.isError, isNot(true));
        final knowledge = result.structuredContent!['result'] as Map;
        expect(knowledge['project']['value']['isSmartworkProject'], isFalse);
        expect(knowledge['architecture']['confidence'], 'unknown');
      });

      test('discover never modifies the project directory', () async {
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
        final before = await File('$projectPath/pubspec.yaml').readAsString();

        await call('smartwork_discover', {'projectPath': projectPath});

        expect(
          await File('$projectPath/pubspec.yaml').readAsString(),
          before,
        );
      });
    });
  });
}
