import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:test/test.dart';

import 'e2e_fixture_support.dart';

/// The MCP-2 mandatory acceptance test: a real MCP client talking to a
/// real, separately-spawned `smartwork_mcp` server process over the
/// actual stdio transport, driving `smartwork_init_plan` then
/// `smartwork_init_apply` against a fresh, empty real directory — with
/// no injected fakes, so this exercises the real `flutter create` and
/// real `flutter analyze`/`flutter test` validation pipeline exactly
/// as a real MCP client would experience it.
void main() {
  test(
      'a real client plans then applies a real SmartWork init against a '
      'fresh directory, over real stdio, through a real spawned server '
      'process, and the resulting project is genuinely valid', () async {
    final packageRoot = Directory.current.path;
    final projectPath = e2eFixturePath('mcp_init_e2e_a');
    createEmptyE2EFixture(projectPath);
    addTearDown(() => deleteE2EFixture(projectPath));

    final process = await Process.start(
      'dart',
      ['run', 'bin/smartwork_mcp.dart'],
      workingDirectory: packageRoot,
    );
    addTearDown(() => process.kill());

    final stderrLines = <String>[];
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stderrLines.add);

    final client =
        MCPClient(Implementation(name: 'e2e-client', version: '1.0.0'));
    final connection = client.connectServer(
      stdioChannel(input: process.stdout, output: process.stdin),
    );

    await connection.initialize(InitializeRequest(
      protocolVersion: ProtocolVersion.latestSupported,
      capabilities: ClientCapabilities(),
      clientInfo: Implementation(name: 'e2e-client', version: '1.0.0'),
    ));
    connection.notifyInitialized();

    final tools = await connection.listTools();
    expect(
      tools.tools.map((t) => t.name),
      containsAll(['smartwork_init_plan', 'smartwork_init_apply']),
    );

    // Case A: Clean + BLoC + Http + SharedPreferences.
    final planResult = await connection.callTool(CallToolRequest(
      name: 'smartwork_init_plan',
      arguments: {
        'projectPath': projectPath,
        'projectName': 'mcp_init_e2e_a',
        'architecture': 'cleanArchitecture',
        'stateManagement': 'bloc',
        'network': 'http',
        'storage': 'sharedPreferences',
        'appTargets': ['android'],
        'initialFeatures': ['home', 'profile'],
      },
    ));
    expect(planResult.isError, isNot(true));
    final planStructured = planResult.structuredContent!;
    expect(planStructured['success'], isTrue);
    final safety = planStructured['safety'] as Map;
    expect(safety['state'], 'empty');
    expect(Directory(projectPath).listSync(), isEmpty,
        reason: 'init_plan must never create files');
    final plan = planStructured['plan'];

    final applyResult = await connection.callTool(CallToolRequest(
      name: 'smartwork_init_apply',
      arguments: {
        'projectPath': projectPath,
        'plan': plan,
        'confirm': true,
      },
    ));
    expect(applyResult.isError, isNot(true),
        reason: 'init_apply failed: ${applyResult.content}');
    final applyStructured = applyResult.structuredContent!;
    expect(applyStructured['success'], isTrue);
    expect(applyStructured['operation'], 'init_apply');
    final validationPhases =
        (applyStructured['result'] as Map)['validationPhases'] as List;
    expect(
      validationPhases.every((p) => (p as Map)['passed'] == true),
      isTrue,
      reason: 'validationPhases: $validationPhases',
    );

    await client.shutdown();
    process.kill();
    await process.exitCode;

    // Real filesystem verification.
    expect(Directory('$projectPath/android').existsSync(), isTrue);
    expect(Directory('$projectPath/ios').existsSync(), isFalse,
        reason: 'only the selected AppTargets (android) should exist');
    expect(Directory('$projectPath/lib').existsSync(), isTrue);
    expect(Directory('$projectPath/lib/features/profile').existsSync(), isTrue);
    expect(Directory('$projectPath/test').existsSync(), isTrue);
    expect(File('$projectPath/pubspec.yaml').existsSync(), isTrue);
    expect(File('$projectPath/README.md').existsSync(), isTrue);
    final pubspec = File('$projectPath/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('flutter_bloc'));
    expect(pubspec, contains('http'));
    expect(pubspec, contains('shared_preferences'));

    // Real Flutter validation — not source inspection.
    final analyze = await Process.run('flutter', ['analyze'],
        workingDirectory: projectPath);
    expect(analyze.exitCode, 0, reason: analyze.stdout.toString());

    final flutterTest =
        await Process.run('flutter', ['test'], workingDirectory: projectPath);
    expect(flutterTest.exitCode, 0, reason: flutterTest.stdout.toString());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
