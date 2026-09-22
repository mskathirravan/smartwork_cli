import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  group('smartwork_doctor tool', () {
    late Directory tempDir;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_doctor_');
      controller = StreamChannelController<String>();
      server = SmartworkMcpServer(
        controller.foreign,
        doctorTool: DoctorTool(
          environmentDoctor: EnvironmentDoctor(
            runProcess: (executable, arguments, {workingDirectory}) async =>
                ProcessResult(0, 0, '$executable ok', ''),
          ),
        ),
      );
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

    test('tool is discoverable via tools/list', () async {
      final result = await connection.listTools();

      expect(result.tools.map((t) => t.name), contains('smartwork_doctor'));
    });

    test(
        'a valid SmartWork project produces a successful structured '
        'result reflecting the real generated project', () async {
      Directory('${tempDir.path}/android').createSync();
      final config = ProjectConfig(
        projectName: 'demo_app',
        appTargets: {AppTarget.android},
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: {'secureSession'},
        initialFeatures: ['home'],
      );
      await ProjectConfigFile(projectPath: tempDir.path).write(config);

      final result = await connection.callTool(CallToolRequest(
        name: 'smartwork_doctor',
        arguments: {'projectPath': tempDir.path},
      ));

      expect(result.isError, isNot(true));
      final structured = result.structuredContent!;
      expect(structured['success'], isTrue);
      expect(structured['projectPath'], tempDir.path);
      final checks = (structured['checks'] as List).cast<Map>();
      expect(
        checks.any(
            (c) => c['label'] == 'SmartWork project' && c['status'] == 'pass'),
        isTrue,
      );
      expect(
        checks.any((c) =>
            (c['label'] as String).startsWith('App Targets') &&
            c['detail'] == 'Android'),
        isTrue,
      );
      expect(structured['errors'], isEmpty);
    });

    test(
        'a directory with no SmartWork project reports informational '
        'context, never a failure', () async {
      final result = await connection.callTool(CallToolRequest(
        name: 'smartwork_doctor',
        arguments: {'projectPath': tempDir.path},
      ));

      final structured = result.structuredContent!;
      expect(structured['success'], isTrue);
      final checks = (structured['checks'] as List).cast<Map>();
      expect(
        checks.any(
            (c) => c['label'] == 'Flutter project' && c['status'] == 'info'),
        isTrue,
      );
    });

    test(
        'a malformed SmartWork project (Core validation failure) is '
        'preserved as a failing check with the real detection error', () async {
      Directory('${tempDir.path}/.smartwork').createSync();
      File('${tempDir.path}/.smartwork/project.yaml')
          .writeAsStringSync('not: [valid, smartwork, config');

      final result = await connection.callTool(CallToolRequest(
        name: 'smartwork_doctor',
        arguments: {'projectPath': tempDir.path},
      ));

      final structured = result.structuredContent!;
      expect(structured['success'], isFalse);
      expect(structured['errors'], isNotEmpty);
      final checks = (structured['checks'] as List).cast<Map>();
      expect(
        checks.any((c) =>
            c['label'] == 'Configuration valid' && c['status'] == 'fail'),
        isTrue,
      );
    });

    test('defaults projectPath to the current directory when omitted',
        () async {
      final result = await connection.callTool(
        CallToolRequest(name: 'smartwork_doctor'),
      );

      expect(result.isError, isNot(true));
      expect(result.structuredContent!['projectPath'], '.');
    });

    test(
        'an invalid argument type is rejected by the tool schema, not '
        'the tool implementation', () async {
      final result = await connection.callTool(CallToolRequest(
        name: 'smartwork_doctor',
        arguments: {'projectPath': 123},
      ));

      expect(result.isError, isTrue);
    });

    test(
        'unexpected failures are handled safely, with no stack trace '
        'exposed', () async {
      controller = StreamChannelController<String>();
      final failingServer = SmartworkMcpServer(
        controller.foreign,
        doctorTool: DoctorTool(
          environmentDoctor: EnvironmentDoctor(
            runProcess: (executable, arguments, {workingDirectory}) async {
              throw StateError('boom: unexpected environment failure');
            },
          ),
        ),
      );
      final failingClient =
          MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
      final failingConnection = failingClient.connectServer(controller.local);
      await failingConnection.initialize(InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: ClientCapabilities(),
        clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
      ));
      failingConnection.notifyInitialized();
      await failingServer.initialized;

      final result = await failingConnection.callTool(CallToolRequest(
        name: 'smartwork_doctor',
        arguments: {'projectPath': tempDir.path},
      ));

      expect(result.isError, isTrue);
      final text = (result.content.single as TextContent).text;
      expect(text, isNot(contains('boom')));
      expect(text, isNot(contains('StateError')));
      expect(text, isNot(contains('.dart:')));

      await failingClient.shutdown();
      await failingServer.shutdown();
    });
  });
}
