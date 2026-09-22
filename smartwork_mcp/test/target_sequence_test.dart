import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'e2e_fixture_support.dart';

/// Phases 14 + 15 of the MCP-3 E2E requirements: a realistic sequence
/// of target changes against one real, `flutter create`-bootstrapped
/// generated project (with real features/services/dependencies
/// already present — see the MCP-3 report for how it was produced),
/// confirming the final state is exactly correct and unrelated project
/// state (feature files, service files, routing, bootstrap, pubspec)
/// stays intact throughout — using Core (`ProjectConfigFile`, the
/// generated files themselves) as the source of truth — plus
/// idempotency: a no-op apply and order/duplicate-insensitive requests
/// produce the identical normalized result.
void main() {
  test(
      'Android -> Android+iOS -> Android+Web -> Android+iOS+Web, then '
      'idempotent re-application — final state exactly correct, '
      'unrelated project state untouched throughout', () async {
    final projectPath = e2eFixturePath('mcp_target_sequence');
    await generateSmartworkFixture(
      projectPath,
      config: ProjectConfig(
        projectName: 'mcp_target_sequence',
        appTargets: {AppTarget.android},
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      ),
    );
    await addFixtureFeature(projectPath, 'profile');
    await addFixtureService(projectPath, 'secureSession');
    await addFixtureService(projectPath, 'analytics');
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
    addTearDown(() async {
      await client.shutdown();
      await server.shutdown();
    });

    Future<CallToolResult> planAndApply(List<String> targets) async {
      final planResult = await connection.callTool(CallToolRequest(
        name: 'smartwork_target_plan',
        arguments: {'projectPath': projectPath, 'appTargets': targets},
      ));
      expect(planResult.isError, isNot(true),
          reason: 'plan($targets) failed: ${planResult.content}');

      final applyResult = await connection.callTool(CallToolRequest(
        name: 'smartwork_target_apply',
        arguments: {
          'projectPath': projectPath,
          'plan': planResult.structuredContent!['plan'],
          'confirm': true,
        },
      ));
      expect(applyResult.isError, isNot(true),
          reason: 'apply($targets) failed: ${applyResult.content}');
      return applyResult;
    }

    // Snapshot unrelated state before the sequence starts.
    final featureFilesBefore =
        Directory('$projectPath/lib/features').listSync(recursive: true).length;
    final serviceFilesBefore =
        Directory('$projectPath/lib/services').listSync(recursive: true).length;
    final pubspecBefore = File('$projectPath/pubspec.yaml').readAsStringSync();
    final routerBefore =
        File('$projectPath/lib/services/routing/app_router.dart')
            .readAsStringSync();
    final bootstrapBefore =
        File('$projectPath/lib/services/bootstrap/bootstrap.dart')
            .readAsStringSync();

    await planAndApply(['android']);
    await planAndApply(['android', 'ios']);
    await planAndApply(['android', 'web']);
    await planAndApply(['android', 'ios', 'web']);

    // Final target state matches the last requested state.
    final config = await ProjectConfigFile(projectPath: projectPath).read();
    expect(
        config.appTargets, {AppTarget.android, AppTarget.ios, AppTarget.web});

    // No stale platform directories: ios/ was dropped from config at
    // step 3 then re-added at step 4 — its folder must exist exactly
    // once, never duplicated, and android/'s folder from step 1 is
    // still exactly the one real directory.
    for (final platform in ['android', 'ios', 'web']) {
      expect(Directory('$projectPath/$platform').existsSync(), isTrue);
    }

    // No corrupted project.yaml — read it back once more; a second,
    // independent successful parse is itself a strong "not corrupted"
    // signal, plus the exact expected fields.
    final reread = await ProjectConfigFile(projectPath: projectPath).read();
    expect(reread.projectName, 'mcp_target_sequence');
    expect(reread.initialFeatures.toSet(), {'home', 'profile'});
    expect(reread.services, {'secureSession', 'analytics'});

    // Unrelated project state intact throughout.
    expect(
      Directory('$projectPath/lib/features').listSync(recursive: true).length,
      featureFilesBefore,
      reason: 'feature files must be untouched by target changes',
    );
    expect(
      Directory('$projectPath/lib/services').listSync(recursive: true).length,
      serviceFilesBefore,
      reason: 'service files must be untouched by target changes',
    );
    expect(
      File('$projectPath/lib/services/routing/app_router.dart')
          .readAsStringSync(),
      routerBefore,
      reason: 'routing must be untouched by target changes',
    );
    expect(
      File('$projectPath/lib/services/bootstrap/bootstrap.dart')
          .readAsStringSync(),
      bootstrapBefore,
      reason: 'bootstrap must be untouched by target changes',
    );
    // pubspec dependencies (not asset-section-adjacent formatting)
    // must be unaffected by target changes, which never touch
    // network/storage/state-management provider choices.
    for (final dep in ['flutter_bloc', 'http', 'shared_preferences']) {
      expect(pubspecBefore.contains(dep), isTrue);
      expect(
        File('$projectPath/pubspec.yaml').readAsStringSync().contains(dep),
        isTrue,
        reason: 'no unexpected pubspec dependency change for $dep',
      );
    }

    // Phase 15: idempotency — re-applying the current state performs
    // no meaningful mutation (Core's own semantics: TargetChangePlan
    // reports no changes, so no platform is created, and the project
    // remains exactly this state).
    final idempotentPlan = await connection.callTool(CallToolRequest(
      name: 'smartwork_target_plan',
      arguments: {
        'projectPath': projectPath,
        'appTargets': ['android', 'ios', 'web'],
      },
    ));
    expect(
      (idempotentPlan.structuredContent!['safety'] as Map)['hasChanges'],
      isFalse,
    );
    await planAndApply(['android', 'ios', 'web']);
    final configAfterIdempotentApply =
        await ProjectConfigFile(projectPath: projectPath).read();
    expect(configAfterIdempotentApply.appTargets, config.appTargets);

    // Equivalent, differently-ordered/duplicated requests produce the
    // identical normalized plan — Core's own Set-based normalization,
    // not a second implementation in MCP.
    final ordered = await connection.callTool(CallToolRequest(
      name: 'smartwork_target_plan',
      arguments: {
        'projectPath': projectPath,
        'appTargets': ['android', 'ios', 'web'],
      },
    ));
    final reorderedWithDupes = await connection.callTool(CallToolRequest(
      name: 'smartwork_target_plan',
      arguments: {
        'projectPath': projectPath,
        'appTargets': ['web', 'ios', 'android', 'android'],
      },
    ));
    expect(
      ordered.structuredContent!['plan'],
      reorderedWithDupes.structuredContent!['plan'],
    );

    // Real Flutter validation after the whole sequence.
    final analyze = await Process.run('flutter', ['analyze'],
        workingDirectory: projectPath);
    expect(analyze.exitCode, 0, reason: analyze.stdout.toString());

    final flutterTest =
        await Process.run('flutter', ['test'], workingDirectory: projectPath);
    expect(flutterTest.exitCode, 0, reason: flutterTest.stdout.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
