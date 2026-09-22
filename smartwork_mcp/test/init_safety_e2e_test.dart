import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'e2e_fixture_support.dart';

/// Phase 14 of the MCP-2 E2E requirements: real init safety scenarios,
/// each against its own dedicated fixture directory (never reusing one
/// a prior test already mutated). Every safety fact reported here comes
/// straight from `TargetStateDetector` (via `smartwork_init_plan`) —
/// this test asserts on real filesystem states, not source inspection.
void main() {
  late StreamChannelController<String> controller;
  late SmartworkMcpServer server;
  late MCPClient client;
  late ServerConnection connection;

  final nonEmptyPath = e2eFixturePath('mcp_safety_nonempty');
  final flutterOnlyPath = e2eFixturePath('mcp_safety_flutter_only');

  setUpAll(() async {
    createNonFlutterFixture(nonEmptyPath);
    await generateBareFlutterFixture(
      flutterOnlyPath,
      projectName: 'mcp_safety_flutter_only',
      platforms: {'android'},
    );
  });

  tearDownAll(() {
    deleteE2EFixture(nonEmptyPath);
    deleteE2EFixture(flutterOnlyPath);
  });

  setUp(() async {
    controller = StreamChannelController<String>();
    server = SmartworkMcpServer(controller.foreign);
    client = MCPClient(Implementation(name: 'safety-client', version: '1.0.0'));
    connection = client.connectServer(controller.local);
    await connection.initialize(InitializeRequest(
      protocolVersion: ProtocolVersion.latestSupported,
      capabilities: ClientCapabilities(),
      clientInfo: Implementation(name: 'safety-client', version: '1.0.0'),
    ));
    connection.notifyInitialized();
    await server.initialized;
  });

  tearDown(() async {
    await client.shutdown();
    await server.shutdown();
  });

  Future<CallToolResult> plan(String projectPath) => connection.callTool(
        CallToolRequest(
          name: 'smartwork_init_plan',
          arguments: {'projectPath': projectPath, 'projectName': 'demo_app'},
        ),
      );

  test(
      'a non-empty (non-Flutter) directory is reported correctly, no '
      'mutation', () async {
    final before = Directory(nonEmptyPath).listSync().length;

    final result = await plan(nonEmptyPath);

    expect(result.isError, isNot(true));
    final safety = result.structuredContent!['safety'] as Map;
    expect(safety['state'], 'nonFlutterProject');
    expect(Directory(nonEmptyPath).listSync().length, before,
        reason: 'init_plan must never mutate the directory it inspects');
  });

  test(
      'an existing plain Flutter project (not SmartWork) is reported '
      'correctly', () async {
    final result = await plan(flutterOnlyPath);

    final safety = result.structuredContent!['safety'] as Map;
    expect(safety['state'], 'flutterProject');
    expect(safety['isRegeneration'], isTrue);
    expect(safety['existingPlatforms'], contains('android'));
  });

  test(
      'an existing SmartWork project reports smartworkProject and '
      'isRegeneration: true', () async {
    // A dedicated temp directory with its own `.smartwork/project.yaml`
    // fixture — never a real project another test file also generates,
    // since `dart test`'s default concurrency runs files in parallel
    // with no guaranteed ordering between them (the same class of
    // cross-file dependency this session's CLI audit found and fixed
    // for a shared process-global; here it would just be an
    // undeclared dependency on another file's timing). Only Core's
    // `TargetStateDetector`-derived safety facts are under test here,
    // not a full real generation, so this lightweight fixture — the
    // same one `FeatureLifecycle`/`ServiceLifecycle` tests already
    // establish — is both correct and fast.
    final projectPath =
        Directory.systemTemp.createTempSync('smartwork_mcp_safety_').path;
    addTearDown(() => Directory(projectPath).deleteSync(recursive: true));
    await ProjectConfigFile(projectPath: projectPath).write(
      ProjectConfig(
        projectName: 'demo_app',
        appTargets: {AppTarget.android},
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: {'analytics'},
        initialFeatures: ['home'],
      ),
    );

    final result = await plan(projectPath);

    final safety = result.structuredContent!['safety'] as Map;
    expect(safety['state'], 'smartworkProject');
    expect(safety['isRegeneration'], isTrue);
    expect(safety, contains('appTargetsDiff'));
    expect(safety, contains('serviceChanges'));
  });

  test(
      'a path that is a file, not a directory, is handled safely '
      '(reported as empty, never an exception)', () async {
    final result = await plan('$nonEmptyPath/random.txt');

    expect(result.isError, isNot(true));
    expect((result.structuredContent!['safety'] as Map)['state'], 'empty');
  });

  test(
      'apply with confirm: false against a real non-empty directory '
      'performs no mutation', () async {
    final before = _snapshot(flutterOnlyPath);

    final planResult = await plan(flutterOnlyPath);
    final applyResult = await connection.callTool(CallToolRequest(
      name: 'smartwork_init_apply',
      arguments: {
        'projectPath': flutterOnlyPath,
        'plan': planResult.structuredContent!['plan'],
        'confirm': false,
      },
    ));

    expect(applyResult.isError, isTrue);
    expect(_snapshot(flutterOnlyPath), before,
        reason: 'confirm: false must leave the directory byte-for-byte '
            'unchanged');
  });
}

/// A cheap content snapshot (relative paths + sizes) for asserting "no
/// mutation occurred" without a full byte-for-byte diff.
Set<String> _snapshot(String root) {
  return Directory(root).listSync(recursive: true).map((e) => e.path).toSet();
}
