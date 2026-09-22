import 'package:dart_mcp/client.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// In-process MCP client/server round trip — connects a real
/// [MCPClient] to a real [SmartworkMcpServer] over an in-memory
/// [StreamChannelController], exercising the actual MCP request/
/// response protocol rather than calling Dart methods directly.
void main() {
  group('SmartworkMcpServer', () {
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    setUp(() async {
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
    });

    test('server initializes and reports its identity', () async {
      expect(server.ready, isTrue);
      expect(server.implementation.name, 'smartwork_mcp');
    });

    test('server registers a tool', () async {
      final result = await connection.listTools();

      expect(result.tools, isNotEmpty);
      // The exact, exhaustive tool set (kept current per milestone) is
      // asserted once, authoritatively, in init_tools_test.dart —
      // duplicating that exact-set list here would just be one more
      // place to remember to update at the next milestone.
      expect(result.tools.map((t) => t.name), contains('smartwork_doctor'));
    });

    test('server can shut down cleanly', () async {
      await server.shutdown();
      expect(server.isActive, isFalse);
    });
  });
}
