import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

FlutterBootstrap _passingBootstrap(Directory tempDir) {
  return FlutterBootstrap(
    runProcess: (executable, arguments, {workingDirectory}) async {
      final platformsArg = arguments.firstWhere(
        (a) => a.startsWith('--platforms='),
        orElse: () => '',
      );
      final platforms = platformsArg.isEmpty
          ? <String>{}
          : platformsArg.substring('--platforms='.length).split(',').toSet();
      for (final platform in platforms) {
        Directory('${tempDir.path}/$platform').createSync(recursive: true);
      }
      Directory('${tempDir.path}/test').createSync(recursive: true);
      File('${tempDir.path}/test/widget_test.dart')
          .writeAsStringSync('// stock counter-app smoke test\n');
      return ProcessResult(0, 0, '', '');
    },
  );
}

ProjectValidator _passingValidator() => ProjectValidator(
      runProcess: (executable, arguments, {workingDirectory}) async =>
          ProcessResult(0, 0, '', ''),
    );

void main() {
  group('MCP-3 target plan/apply tools', () {
    late Directory tempDir;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    Future<void> writeProjectConfig({Set<AppTarget>? appTargets}) async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'demo_app',
          appTargets: appTargets ?? {AppTarget.android},
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        ),
      );
    }

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_target_');
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

    test(
        'tools/list contains exactly the full MCP-0 through MCP-3 set, '
        'plus V1.1-8\'s Splash Screen tool, V1.1-9\'s JSON → Model '
        'tool, V1.1-10\'s App Icon tool, and V1.1-12\'s Discover tool',
        () async {
      final result = await connection.listTools();

      expect(
        result.tools.map((t) => t.name).toSet(),
        {
          'smartwork_doctor',
          'smartwork_feature_add',
          'smartwork_feature_remove',
          'smartwork_service_add',
          'smartwork_service_remove',
          'smartwork_init_plan',
          'smartwork_init_apply',
          'smartwork_target_plan',
          'smartwork_target_apply',
          'smartwork_splash_add',
          'smartwork_model_from_json',
          'smartwork_app_icon_set',
          'smartwork_discover',
        },
      );
    });

    group('target_plan', () {
      test('a valid selection returns normalized current/desired/changes',
          () async {
        await writeProjectConfig(appTargets: {AppTarget.android});

        final result = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android', 'web'],
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        expect(structured['plan'], {
          'appTargets': ['android', 'web'],
        });
        expect(structured['currentState'], {
          'appTargets': ['android'],
          // The lightweight fixture writes only .smartwork/project.yaml,
          // never a real android/ folder — existingPlatforms is a real
          // filesystem check (TargetStateDetector), not a config echo,
          // so it correctly reports none here.
          'existingPlatforms': <String>[],
        });
        expect(structured['changes'], {
          'add': ['web'],
          'removedFromConfig': <String>[],
        });
        expect((structured['safety'] as Map)['hasChanges'], isTrue);
      });

      test(
          'duplicate targets normalize to the same plan as no '
          'duplicates', () async {
        await writeProjectConfig(appTargets: {AppTarget.android});

        final withDupes = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android', 'android', 'ios', 'ios'],
        });
        final withoutDupes = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android', 'ios'],
        });

        expect(
          withDupes.structuredContent!['plan'],
          withoutDupes.structuredContent!['plan'],
        );
      });

      test('input order never affects the normalized plan', () async {
        await writeProjectConfig(appTargets: {AppTarget.android});

        final orderA = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['ios', 'android', 'web'],
        });
        final orderB = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['web', 'ios', 'android'],
        });

        expect(
          orderA.structuredContent!['plan'],
          orderB.structuredContent!['plan'],
        );
      });

      test('a no-op plan (identical to current) reports no changes', () async {
        await writeProjectConfig(
            appTargets: {AppTarget.android, AppTarget.ios});

        final result = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android', 'ios'],
        });

        final changes = result.structuredContent!['changes'] as Map;
        expect(changes['add'], isEmpty);
        expect(changes['removedFromConfig'], isEmpty);
        expect(
          (result.structuredContent!['safety'] as Map)['hasChanges'],
          isFalse,
        );
      });

      test('removing a target reports it under removedFromConfig', () async {
        await writeProjectConfig(
            appTargets: {AppTarget.android, AppTarget.ios});

        final result = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android'],
        });

        final changes = result.structuredContent!['changes'] as Map;
        expect(changes['removedFromConfig'], ['ios']);
        expect(changes['add'], isEmpty);
      });

      test('an unknown target name is rejected safely', () async {
        await writeProjectConfig();

        final result = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android', 'not_a_real_target'],
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_target',
        );
      });

      test('an empty target list is rejected safely', () async {
        await writeProjectConfig();

        final result = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': <String>[],
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_target',
        );
      });

      test(
          'a non-SmartWork project is rejected safely, causing zero '
          'mutation', () async {
        final before = Directory(tempDir.path).listSync();

        final result = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android'],
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'not_a_smartwork_project',
        );
        expect(Directory(tempDir.path).listSync().length, before.length);
      });

      test('missing required appTargets is rejected by the tool schema',
          () async {
        final result = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
        });

        expect(result.isError, isTrue);
      });
    });

    group('target_apply', () {
      test('without confirmation, nothing is created', () async {
        await writeProjectConfig(appTargets: {AppTarget.android});
        final planResult = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android', 'ios'],
        });

        final result = await call('smartwork_target_apply', {
          'projectPath': tempDir.path,
          'plan': planResult.structuredContent!['plan'],
          'confirm': false,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'confirmation_required',
        );
        expect(Directory('${tempDir.path}/ios').existsSync(), isFalse);
      });

      test('confirm omitted is rejected the same as confirm: false', () async {
        await writeProjectConfig(appTargets: {AppTarget.android});
        final planResult = await call('smartwork_target_plan', {
          'projectPath': tempDir.path,
          'appTargets': ['android', 'ios'],
        });

        final result = await connection.callTool(CallToolRequest(
          name: 'smartwork_target_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': planResult.structuredContent!['plan'],
          },
        ));

        expect(result.isError, isTrue);
        expect(Directory('${tempDir.path}/ios').existsSync(), isFalse);
      });

      test('plan then apply with confirm: true performs the real change',
          () async {
        Directory('${tempDir.path}/android').createSync();
        await writeProjectConfig(appTargets: {AppTarget.android});
        final localController = StreamChannelController<String>();
        final applyServer = SmartworkMcpServer(
          localController.foreign,
          targetTools: TargetTools(
            updater: ProjectTargetUpdater(
              flutterBootstrap: _passingBootstrap(tempDir),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final applyClient =
            MCPClient(Implementation(name: 'apply-client', version: '0.0.1'));
        final applyConnection =
            applyClient.connectServer(localController.local);
        await applyConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'apply-client', version: '0.0.1'),
        ));
        applyConnection.notifyInitialized();
        await applyServer.initialized;

        final planResult = await applyConnection.callTool(CallToolRequest(
          name: 'smartwork_target_plan',
          arguments: {
            'projectPath': tempDir.path,
            'appTargets': ['android', 'ios'],
          },
        ));
        final plan = planResult.structuredContent!['plan'];

        final applyResult = await applyConnection.callTool(CallToolRequest(
          name: 'smartwork_target_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': plan,
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isNot(true),
            reason: 'apply failed: ${applyResult.content}');
        expect(applyResult.structuredContent!['success'], isTrue);
        expect(Directory('${tempDir.path}/ios').existsSync(), isTrue);
        expect(Directory('${tempDir.path}/android').existsSync(), isTrue);
        final config =
            await ProjectConfigFile(projectPath: tempDir.path).read();
        expect(config.appTargets, {AppTarget.android, AppTarget.ios});

        await applyClient.shutdown();
        await applyServer.shutdown();
      });

      test('an altered plan before apply is applied exactly as supplied',
          () async {
        Directory('${tempDir.path}/android').createSync();
        await writeProjectConfig(appTargets: {AppTarget.android});
        final localController = StreamChannelController<String>();
        final applyServer = SmartworkMcpServer(
          localController.foreign,
          targetTools: TargetTools(
            updater: ProjectTargetUpdater(
              flutterBootstrap: _passingBootstrap(tempDir),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final applyClient =
            MCPClient(Implementation(name: 'apply-client', version: '0.0.1'));
        final applyConnection =
            applyClient.connectServer(localController.local);
        await applyConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'apply-client', version: '0.0.1'),
        ));
        applyConnection.notifyInitialized();
        await applyServer.initialized;

        final planResult = await applyConnection.callTool(CallToolRequest(
          name: 'smartwork_target_plan',
          arguments: {
            'projectPath': tempDir.path,
            'appTargets': ['android', 'ios'],
          },
        ));
        final plan = Map<String, Object?>.from(
            planResult.structuredContent!['plan'] as Map);
        // Altered before apply — the client's latest explicit request
        // is authoritative, not the earlier plan call.
        plan['appTargets'] = ['android', 'web'];

        final applyResult = await applyConnection.callTool(CallToolRequest(
          name: 'smartwork_target_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': plan,
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isNot(true));
        expect(Directory('${tempDir.path}/web').existsSync(), isTrue);
        expect(Directory('${tempDir.path}/ios').existsSync(), isFalse,
            reason: 'ios was never in the altered plan actually applied');

        await applyClient.shutdown();
        await applyServer.shutdown();
      });

      test('an unknown target in the plan is rejected safely', () async {
        await writeProjectConfig(appTargets: {AppTarget.android});

        final result = await call('smartwork_target_apply', {
          'projectPath': tempDir.path,
          'plan': {
            'appTargets': ['android', 'not_a_real_target'],
          },
          'confirm': true,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_target',
        );
      });

      test('a non-SmartWork project is rejected safely on apply too', () async {
        final result = await call('smartwork_target_apply', {
          'projectPath': tempDir.path,
          'plan': {
            'appTargets': ['android'],
          },
          'confirm': true,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'not_a_smartwork_project',
        );
      });
    });
  });
}
