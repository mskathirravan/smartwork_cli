import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Real in-process MCP protocol tests for the V1.1-9 JSON → Model tool
/// — every request goes through `initialize`/`tools/list`/`tools/call`,
/// never a direct Dart method call. Mirrors `splash_tools_test.dart`'s
/// exact setup: a real generated project (with a real added feature)
/// is enough for these fast, protocol-level checks — full real-Flutter
/// behavior is validated separately under `tmp/`.
void main() {
  group('V1.1-9 JSON → Model tool', () {
    late Directory tempDir;
    late String projectPath;
    late File jsonFile;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_model_');
      projectPath = tempDir.path;
      jsonFile = File('${tempDir.path}_user.json');

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
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );

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
      if (jsonFile.existsSync()) jsonFile.deleteSync();
    });

    Future<CallToolResult> call(String name, Map<String, Object?> args) =>
        connection.callTool(CallToolRequest(name: name, arguments: args));

    test('tools/list contains smartwork_model_from_json', () async {
      final result = await connection.listTools();

      expect(
        result.tools.map((t) => t.name),
        contains('smartwork_model_from_json'),
      );
    });

    group('model_from_json', () {
      test(
          'a successful generation writes the model and reports it via '
          'the real MCP protocol', () async {
        await jsonFile.writeAsString(jsonEncode({'id': 1, 'name': 'John'}));

        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': jsonFile.path,
          'feature': 'profile',
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        expect(structured['success'], isTrue);
        expect(structured['operation'], 'model_from_json');
        final data = structured['result'] as Map;
        expect((data['generatedFiles'] as List), hasLength(1));
        expect((data['classNames'] as List), contains(contains('Model')));
      });

      test('a successful nested-model generation reports every file', () async {
        await jsonFile.writeAsString(jsonEncode({
          'id': 1,
          'address': {'city': 'Metropolis', 'zip': '12345'},
          'tags': ['a', 'b'],
        }));

        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': jsonFile.path,
          'feature': 'profile',
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        final data = structured['result'] as Map;
        expect((data['generatedFiles'] as List), hasLength(2));
        expect(data['classNames'], containsAll(['AddressModel']));
      });

      test('a missing project fails safely with no_project', () async {
        final emptyDir =
            Directory.systemTemp.createTempSync('smartwork_no_project_');
        addTearDown(() => emptyDir.deleteSync(recursive: true));
        await jsonFile.writeAsString(jsonEncode({'id': 1}));

        final result = await call('smartwork_model_from_json', {
          'projectPath': emptyDir.path,
          'jsonFilePath': jsonFile.path,
          'feature': 'profile',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'no_project',
        );
      });

      test('a missing JSON file fails safely with json_file_not_found',
          () async {
        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': '/no/such/file.json',
          'feature': 'profile',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'json_file_not_found',
        );
      });

      test('invalid JSON content fails safely with invalid_json', () async {
        await jsonFile.writeAsString('{not valid');

        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': jsonFile.path,
          'feature': 'profile',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_json',
        );
      });

      test('a missing feature fails safely with feature_not_found', () async {
        await jsonFile.writeAsString(jsonEncode({'id': 1}));

        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': jsonFile.path,
          'feature': 'does_not_exist',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'feature_not_found',
        );
      });

      test(
          'an existing model file collision fails safely with '
          'model_file_collision', () async {
        await jsonFile.writeAsString(jsonEncode({'id': 1}));
        await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': jsonFile.path,
          'feature': 'profile',
        });

        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': jsonFile.path,
          'feature': 'profile',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'model_file_collision',
        );
      });

      test('a root JSON array fails safely with unsupported_json_root',
          () async {
        await jsonFile.writeAsString('[1, 2, 3]');

        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
          'jsonFilePath': jsonFile.path,
          'feature': 'profile',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'unsupported_json_root',
        );
      });

      test(
          'missing required jsonFilePath/feature is rejected by the '
          'tool schema', () async {
        final result = await call('smartwork_model_from_json', {
          'projectPath': projectPath,
        });

        expect(result.isError, isTrue);
      });
    });
  });
}
