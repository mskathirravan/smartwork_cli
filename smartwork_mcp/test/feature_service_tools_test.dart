import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Real in-process MCP protocol tests for the MCP-1 feature/service
/// lifecycle tools — every request goes through `initialize`/
/// `tools/list`/`tools/call`, never a direct Dart method call. The
/// fixture project uses the same lightweight `.smartwork/project.yaml`
/// setup `smartwork_cli`'s own `FeatureLifecycle`/`ServiceLifecycle`
/// tests already establish (see `feature_command_lifecycle_test.dart`)
/// — `FeatureLifecycle`/`ServiceLifecycle` only ever need that file,
/// never a real `flutter create`-bootstrapped project.
void main() {
  group('MCP-1 feature/service lifecycle tools', () {
    late Directory tempDir;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;

    Future<void> writeProjectConfig({
      Set<String> services = const {},
      List<String> initialFeatures = const ['home'],
    }) async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          services: services,
          initialFeatures: initialFeatures,
        ),
      );
    }

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_lifecycle_');
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

    group('tool registration', () {
      test('tools/list contains at least the MCP-1 feature/service tools',
          () async {
        final result = await connection.listTools();

        expect(
          result.tools.map((t) => t.name),
          containsAll([
            'smartwork_feature_add',
            'smartwork_feature_remove',
            'smartwork_service_add',
            'smartwork_service_remove',
          ]),
        );
      });
    });

    group('feature add', () {
      test('adds a feature to a real project via the real MCP protocol',
          () async {
        await writeProjectConfig();

        final result = await call('smartwork_feature_add', {
          'projectPath': tempDir.path,
          'featureName': 'profile',
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        expect(structured['success'], isTrue);
        expect(structured['operation'], 'feature_add');
        expect(structured['featureName'], 'profile');
        expect(
          Directory('${tempDir.path}/lib/features/profile').existsSync(),
          isTrue,
        );
        final router =
            File('${tempDir.path}/lib/services/routing/app_router.dart')
                .readAsStringSync();
        expect(router, contains("case '/profile':"));
      });

      test(
          'duplicate feature add matches Core semantics '
          '(FeatureAlreadyExistsException)', () async {
        await writeProjectConfig();
        await call('smartwork_feature_add',
            {'projectPath': tempDir.path, 'featureName': 'profile'});

        final result = await call('smartwork_feature_add',
            {'projectPath': tempDir.path, 'featureName': 'profile'});

        expect(result.isError, isTrue);
        final structured = result.structuredContent!;
        expect(structured['success'], isFalse);
        expect(
          (structured['error'] as Map)['code'],
          'feature_already_exists',
        );
      });

      test('an invalid feature name is rejected with Core\'s own error',
          () async {
        await writeProjectConfig();

        final result = await call('smartwork_feature_add',
            {'projectPath': tempDir.path, 'featureName': 'Not Valid!'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_feature_name',
        );
      });

      test('missing required featureName is rejected by the tool schema',
          () async {
        final result = await call('smartwork_feature_add', {
          'projectPath': tempDir.path,
        });

        expect(result.isError, isTrue);
      });

      test('a directory with no SmartWork project fails safely', () async {
        final result = await call('smartwork_feature_add',
            {'projectPath': tempDir.path, 'featureName': 'profile'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'no_project',
        );
      });
    });

    group('feature remove', () {
      test('removes a feature and its route via the real MCP protocol',
          () async {
        await writeProjectConfig();
        await call('smartwork_feature_add',
            {'projectPath': tempDir.path, 'featureName': 'profile'});
        await call('smartwork_feature_add',
            {'projectPath': tempDir.path, 'featureName': 'settings'});

        final result = await call('smartwork_feature_remove',
            {'projectPath': tempDir.path, 'featureName': 'profile'});

        expect(result.isError, isNot(true));
        expect(result.structuredContent!['success'], isTrue);
        expect(
          Directory('${tempDir.path}/lib/features/profile').existsSync(),
          isFalse,
        );
        expect(
          Directory('${tempDir.path}/lib/features/settings').existsSync(),
          isTrue,
          reason: 'other features must remain intact',
        );
        final router =
            File('${tempDir.path}/lib/services/routing/app_router.dart')
                .readAsStringSync();
        expect(router, isNot(contains("case '/profile':")));
        expect(router, contains("case '/settings':"));
      });

      test(
          'removing "home" is rejected — protection is Core\'s rule, '
          'not reimplemented here', () async {
        await writeProjectConfig();

        final result = await call('smartwork_feature_remove',
            {'projectPath': tempDir.path, 'featureName': 'home'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'home_feature_not_removable',
        );
        expect(Directory('${tempDir.path}/lib/features/home').existsSync(),
            isFalse,
            reason: 'home was never generated by this lightweight '
                'fixture — the point is the request never even tries');
      });

      test('removing "debug" is rejected', () async {
        await writeProjectConfig();

        final result = await call('smartwork_feature_remove',
            {'projectPath': tempDir.path, 'featureName': 'debug'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'debug_feature_not_removable',
        );
      });

      test(
          'removing a nonexistent feature matches Core semantics '
          '(FeatureNotFoundException)', () async {
        await writeProjectConfig();

        final result = await call('smartwork_feature_remove',
            {'projectPath': tempDir.path, 'featureName': 'nope'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'feature_not_found',
        );
      });
    });

    group('service add', () {
      for (final serviceId in ['logger', 'analytics', 'crashReporting']) {
        test('adds the $serviceId service via the real MCP protocol', () async {
          await writeProjectConfig();

          final result = await call('smartwork_service_add',
              {'projectPath': tempDir.path, 'service': serviceId});

          expect(result.isError, isNot(true));
          expect(result.structuredContent!['success'], isTrue);
          final service = Service.values.firstWhere((s) => s.id == serviceId);
          expect(
            File('${tempDir.path}/lib/services/${service.folderName}/'
                    '${service.fileName}')
                .existsSync(),
            isTrue,
          );
          expect(
            File('${tempDir.path}/lib/services/services.dart')
                .readAsStringSync(),
            contains(service.fileName),
          );
        });
      }

      test(
          'reports dependenciesChanged with a "flutter pub get" next step '
          'only when the service adds a package', () async {
        await writeProjectConfig();
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync(
          'name: demo_app\n\ndependencies:\n  flutter:\n    sdk: flutter\n'
          '\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n'
          '\nflutter:\n  uses-material-design: true\n',
        );

        // The first add also brings this bare pubspec in line with the
        // project config (as a real SmartWork pubspec already is).
        await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'analytics'});

        final logger = await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'logger'});
        final loggerResult =
            logger.structuredContent!['result'] as Map<String, Object?>;
        expect(loggerResult, isNot(contains('dependenciesChanged')));

        final forceUpdate = await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'forceUpdate'});
        final result =
            forceUpdate.structuredContent!['result'] as Map<String, Object?>;
        expect(result['dependenciesChanged'], isTrue);
        expect(result['nextStep'], contains('flutter pub get'));
        expect(result['nextStep'], contains('flutter upgrade'));
      });

      test('does not touch routing or feature files', () async {
        await writeProjectConfig();
        await call('smartwork_feature_add',
            {'projectPath': tempDir.path, 'featureName': 'profile'});
        final routerBefore =
            File('${tempDir.path}/lib/services/routing/app_router.dart')
                .readAsStringSync();

        await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'analytics'});

        final routerAfter =
            File('${tempDir.path}/lib/services/routing/app_router.dart')
                .readAsStringSync();
        expect(routerAfter, routerBefore);
        expect(
          Directory('${tempDir.path}/lib/features/settings').existsSync(),
          isFalse,
          reason: 'service_add must never touch lib/features/',
        );
      });

      test(
          'duplicate service add matches Core semantics '
          '(ServiceAlreadySelectedException)', () async {
        await writeProjectConfig(services: {'analytics'});

        final result = await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'analytics'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'service_already_selected',
        );
      });

      test('an unknown service is rejected safely, no files modified',
          () async {
        await writeProjectConfig();

        final result = await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'not_a_real_service'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'unknown_service',
        );
        expect(Directory('${tempDir.path}/lib/services').existsSync(), isFalse);
      });

      for (final infra in [
        'bootstrap',
        'routing',
        'network',
        'storage',
        'theme',
      ]) {
        test(
            '"$infra" cannot be added as a service — it has no Service '
            'enum value', () async {
          await writeProjectConfig();

          final result = await call('smartwork_service_add',
              {'projectPath': tempDir.path, 'service': infra});

          expect(result.isError, isTrue);
          expect(
            (result.structuredContent!['error'] as Map)['code'],
            'unknown_service',
          );
        });
      }
    });

    group('service remove', () {
      test('removes a service via the real MCP protocol', () async {
        await writeProjectConfig();
        await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'analytics'});
        await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'logger'});

        final result = await call('smartwork_service_remove',
            {'projectPath': tempDir.path, 'service': 'analytics'});

        expect(result.isError, isNot(true));
        expect(result.structuredContent!['success'], isTrue);
        expect(
          Directory('${tempDir.path}/lib/services/analytics').existsSync(),
          isFalse,
        );
        expect(
          Directory('${tempDir.path}/lib/services/logging').existsSync(),
          isTrue,
          reason: 'other services must remain intact',
        );
        final barrel = File('${tempDir.path}/lib/services/services.dart')
            .readAsStringSync();
        expect(barrel, isNot(contains('analytics_service.dart')));
        expect(barrel, contains('debug_logger.dart'));
      });

      test(
          'removing a not-selected service matches Core semantics '
          '(ServiceNotSelectedException)', () async {
        await writeProjectConfig();

        final result = await call('smartwork_service_remove',
            {'projectPath': tempDir.path, 'service': 'analytics'});

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'service_not_selected',
        );
      });

      for (final infra in [
        'bootstrap',
        'routing',
        'network',
        'storage',
        'theme'
      ]) {
        test(
            '"$infra" cannot be removed as a service — Core\'s '
            'architectural protection, not an MCP blocklist', () async {
          await writeProjectConfig();

          final result = await call('smartwork_service_remove',
              {'projectPath': tempDir.path, 'service': infra});

          expect(result.isError, isTrue);
          expect(
            (result.structuredContent!['error'] as Map)['code'],
            'unknown_service',
          );
          expect(
            Directory('${tempDir.path}/lib/services/$infra').existsSync(),
            isFalse,
          );
        });
      }

      test(
          'does not change network/storage/state-management dependency '
          'choices', () async {
        await writeProjectConfig();
        await call('smartwork_service_add',
            {'projectPath': tempDir.path, 'service': 'analytics'});
        final configBefore =
            await ProjectConfigFile(projectPath: tempDir.path).read();

        await call('smartwork_service_remove',
            {'projectPath': tempDir.path, 'service': 'analytics'});

        final configAfter =
            await ProjectConfigFile(projectPath: tempDir.path).read();
        expect(configAfter.network, configBefore.network);
        expect(configAfter.storage, configBefore.storage);
        expect(configAfter.stateManagement, configBefore.stateManagement);
      });
    });
  });
}
