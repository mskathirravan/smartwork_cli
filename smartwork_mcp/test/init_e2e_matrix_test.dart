import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'e2e_fixture_support.dart';

/// Phase 13 of the MCP-2 E2E requirements — the remaining three
/// established configurations (Case A, Clean+BLoC+Http+
/// SharedPreferences, is already covered by the mandatory real
/// spawned-process test in real_init_e2e_test.dart). These three run
/// through the real, in-process MCP protocol with genuinely unfaked
/// Core classes (`InitTools()`'s own defaults: a real
/// `FlutterBootstrap`/`ProjectValidator`, so real `flutter create` and
/// real `flutter analyze`/`test` still run) — the expensive part of
/// this matrix is the real Flutter toolchain itself, not the MCP
/// transport, so validating the configuration matrix in-process
/// (rather than re-spawning a separate OS process three more times)
/// is a deliberate cost trade-off, not a shortcut on realism.
void main() {
  final cases = [
    (
      name: 'B',
      dirName: 'mcp_init_e2e_b',
      architecture: 'mvvm',
      stateManagement: 'riverpod',
      network: 'dio',
      storage: 'hive',
    ),
    (
      name: 'C',
      dirName: 'mcp_init_e2e_c',
      architecture: 'mvp',
      stateManagement: 'getx',
      network: 'http',
      storage: 'sharedPreferences',
    ),
    (
      name: 'D',
      dirName: 'mcp_init_e2e_d',
      architecture: 'cleanArchitecture',
      stateManagement: 'bloc',
      network: 'other',
      storage: 'other',
    ),
  ];

  for (final c in cases) {
    test(
        'Case ${c.name}: ${c.architecture}+${c.stateManagement}+'
        '${c.network}+${c.storage} — plan then apply produces a real, '
        'valid Flutter project', () async {
      final projectPath = e2eFixturePath(c.dirName);
      createEmptyE2EFixture(projectPath);
      addTearDown(() => deleteE2EFixture(projectPath));

      final controller = StreamChannelController<String>();
      final server = SmartworkMcpServer(controller.foreign);
      final client =
          MCPClient(Implementation(name: 'matrix-client', version: '1.0.0'));
      final connection = client.connectServer(controller.local);
      await connection.initialize(InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: ClientCapabilities(),
        clientInfo: Implementation(name: 'matrix-client', version: '1.0.0'),
      ));
      connection.notifyInitialized();
      await server.initialized;

      final planResult = await connection.callTool(CallToolRequest(
        name: 'smartwork_init_plan',
        arguments: {
          'projectPath': projectPath,
          'projectName': c.dirName,
          'architecture': c.architecture,
          'stateManagement': c.stateManagement,
          'network': c.network,
          'storage': c.storage,
          'appTargets': ['android'],
          'initialFeatures': ['home'],
        },
      ));
      expect(planResult.isError, isNot(true),
          reason: 'plan failed: ${planResult.content}');
      final plan = planResult.structuredContent!['plan'];

      final applyResult = await connection.callTool(CallToolRequest(
        name: 'smartwork_init_apply',
        arguments: {
          'projectPath': projectPath,
          'plan': plan,
          'confirm': true,
        },
      ));
      expect(applyResult.isError, isNot(true),
          reason: 'apply failed: ${applyResult.content}');
      final validationPhases = ((applyResult.structuredContent!['result']
          as Map)['validationPhases'] as List);
      expect(
        validationPhases.every((p) => (p as Map)['passed'] == true),
        isTrue,
        reason: 'Case ${c.name} validationPhases: $validationPhases',
      );

      await client.shutdown();
      await server.shutdown();

      // Independent real Flutter validation, not just trusting
      // init_apply's own internal report.
      final analyze = await Process.run('flutter', ['analyze'],
          workingDirectory: projectPath);
      expect(analyze.exitCode, 0, reason: analyze.stdout.toString());

      final flutterTest =
          await Process.run('flutter', ['test'], workingDirectory: projectPath);
      expect(flutterTest.exitCode, 0, reason: flutterTest.stdout.toString());
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
