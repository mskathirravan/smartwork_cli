import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'e2e_fixture_support.dart';

/// Runs a realistic sequence of MCP-1 lifecycle operations against one
/// real, `flutter create`-bootstrapped generated project (see the
/// MCP-1 report for how it was produced) and confirms the final state
/// is exactly correct — no duplicate routes, no duplicate service
/// registrations, no stale files, no duplicate dependencies — using
/// Core (`ProjectConfigFile`, the generated `app_router.dart`/
/// `services.dart`/`pubspec.yaml` themselves) as the source of truth,
/// then validates with real `flutter analyze`/`flutter test`.
void main() {
  test(
      'add profile, add settings, add analytics, add logger, remove '
      'profile, remove analytics, re-add profile, re-add analytics — '
      'final state is exactly correct', () async {
    // A dedicated project, separate from real_process_roundtrip_test's
    // tmp/mcp_roundtrip — two test files must never mutate the same
    // real project directory concurrently (the exact class of
    // cross-file interference this repository's CLI audit already
    // found and documented for shared process-global state).
    final projectPath = e2eFixturePath('mcp_idempotency');
    await generateSmartworkFixture(
      projectPath,
      config: ProjectConfig(
        projectName: 'mcp_idempotency',
        appTargets: {AppTarget.android},
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      ),
    );
    await addFixtureService(projectPath, 'secureSession');
    addTearDown(() => deleteE2EFixture(projectPath));

    final controller = StreamChannelController<String>();
    final server = SmartworkMcpServer(controller.foreign);
    final client =
        MCPClient(Implementation(name: 'seq-client', version: '1.0.0'));
    final connection = client.connectServer(controller.local);
    await connection.initialize(InitializeRequest(
      protocolVersion: ProtocolVersion.latestSupported,
      capabilities: ClientCapabilities(),
      clientInfo: Implementation(name: 'seq-client', version: '1.0.0'),
    ));
    connection.notifyInitialized();
    await server.initialized;

    Future<CallToolResult> call(String name, Map<String, Object?> args) =>
        connection.callTool(CallToolRequest(
          name: name,
          arguments: {'projectPath': projectPath, ...args},
        ));

    Future<void> expectSuccess(CallToolResult result, String label) async {
      expect(result.isError, isNot(true), reason: '$label: ${result.content}');
      expect(result.structuredContent!['success'], isTrue, reason: label);
    }

    addTearDown(() async {
      await client.shutdown();
      await server.shutdown();
    });

    await expectSuccess(
      await call('smartwork_feature_add', {'featureName': 'profile'}),
      'add feature profile',
    );
    await expectSuccess(
      await call('smartwork_feature_add', {'featureName': 'settings'}),
      'add feature settings',
    );
    await expectSuccess(
      await call('smartwork_service_add', {'service': 'analytics'}),
      'add service analytics',
    );
    await expectSuccess(
      await call('smartwork_service_add', {'service': 'logger'}),
      'add service logger',
    );
    await expectSuccess(
      await call('smartwork_feature_remove', {'featureName': 'profile'}),
      'remove feature profile',
    );
    await expectSuccess(
      await call('smartwork_service_remove', {'service': 'analytics'}),
      'remove service analytics',
    );
    await expectSuccess(
      await call('smartwork_feature_add', {'featureName': 'profile'}),
      're-add feature profile',
    );
    await expectSuccess(
      await call('smartwork_service_add', {'service': 'analytics'}),
      're-add service analytics',
    );

    // Final filesystem state, using Core as the source of truth.
    final config = await ProjectConfigFile(projectPath: projectPath).read();
    expect(config.initialFeatures.toSet(), {'home', 'profile', 'settings'});
    expect(config.services, {'secureSession', 'analytics', 'logger'});

    expect(Directory('$projectPath/lib/features/profile').existsSync(), isTrue);
    expect(
        Directory('$projectPath/lib/features/settings').existsSync(), isTrue);
    expect(
        Directory('$projectPath/lib/services/analytics').existsSync(), isTrue);
    expect(Directory('$projectPath/lib/services/logging').existsSync(), isTrue);

    final router = File('$projectPath/lib/services/routing/app_router.dart')
        .readAsStringSync();
    // No duplicate routes: each route case appears exactly once.
    // Ordinary features use a literal string case; home/debug are
    // reserved route-name constants referenced by bare identifier
    // (`static const String home = '/'`) rather than a literal string
    // — see the generated AppRouter itself.
    for (final route in ["'/profile':", "'/settings':"]) {
      expect(
        'case $route'.allMatches(router).length,
        1,
        reason: 'route $route must appear exactly once: $router',
      );
    }
    for (final route in ['home:', 'debug:']) {
      expect(
        'case $route'.allMatches(router).length,
        1,
        reason: 'route $route must appear exactly once: $router',
      );
    }

    final barrel =
        File('$projectPath/lib/services/services.dart').readAsStringSync();
    // No duplicate service registrations.
    for (final export in ['analytics_service.dart', 'debug_logger.dart']) {
      expect(
        export.allMatches(barrel).length,
        1,
        reason: 'service export $export must appear exactly once: $barrel',
      );
    }

    // No duplicate/stale dependencies in pubspec.yaml.
    final pubspecLines = File('$projectPath/pubspec.yaml').readAsLinesSync();
    final packageLineCounts = <String, int>{};
    for (final line in pubspecLines) {
      final match = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        packageLineCounts[name] = (packageLineCounts[name] ?? 0) + 1;
      }
    }
    for (final entry in packageLineCounts.entries) {
      expect(entry.value, 1,
          reason: 'dependency ${entry.key} must appear exactly once in '
              'pubspec.yaml');
    }

    // The project still genuinely analyzes and tests successfully.
    final analyze = await Process.run('flutter', ['analyze'],
        workingDirectory: projectPath);
    expect(analyze.exitCode, 0, reason: analyze.stdout.toString());

    final flutterTest =
        await Process.run('flutter', ['test'], workingDirectory: projectPath);
    expect(flutterTest.exitCode, 0, reason: flutterTest.stdout.toString());
  }, timeout: const Timeout(Duration(seconds: 90)));
}
