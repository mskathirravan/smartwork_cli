import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// A fake [FlutterBootstrap] that behaves like a real `flutter create`
/// for testing purposes — writes a plausible `pubspec.yaml` and the
/// platform folders `_config()`'s default AppTargets (android + ios)
/// expect, exactly mirroring the pattern `smartwork_core`'s own
/// `project_initializer_test.dart` and `smartwork_cli`'s
/// `init_command_validation_test.dart` already establish.
FlutterBootstrap _passingBootstrap(Directory tempDir) {
  return FlutterBootstrap(
    runProcess: (executable, arguments, {workingDirectory}) async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: demo_app
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''');
      Directory('${tempDir.path}/lib').createSync();
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      return ProcessResult(0, 0, '', '');
    },
  );
}

ProjectValidator _passingValidator() => ProjectValidator(
      runProcess: (executable, arguments, {workingDirectory}) async =>
          ProcessResult(0, 0, '', ''),
    );

void main() {
  group('MCP-2 init plan/apply tools', () {
    late Directory tempDir;
    late StreamChannelController<String> controller;
    late SmartworkMcpServer server;
    late MCPClient client;
    late ServerConnection connection;
    InitTools? injectedInitTools;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_mcp_init_');
      controller = StreamChannelController<String>();
      server =
          SmartworkMcpServer(controller.foreign, initTools: injectedInitTools);
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
      injectedInitTools = null;
    });

    Future<CallToolResult> call(String name, Map<String, Object?> args) =>
        connection.callTool(CallToolRequest(name: name, arguments: args));

    test('tools/list contains at least the MCP-2 init tools', () async {
      final result = await connection.listTools();

      // The exact, exhaustive tool set (kept current per milestone) is
      // asserted once, authoritatively, in target_tools_test.dart.
      expect(
        result.tools.map((t) => t.name),
        containsAll(['smartwork_init_plan', 'smartwork_init_apply']),
      );
    });

    group('init_plan', () {
      test(
          'a valid configuration returns a structured, normalized plan '
          'with no filesystem mutation', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'architecture': 'mvvm',
          'stateManagement': 'riverpod',
          'network': 'dio',
          'storage': 'hive',
          'appTargets': ['android', 'web'],
          'initialFeatures': ['home', 'profile'],
          'services': ['analytics'],
        });

        expect(result.isError, isNot(true));
        final structured = result.structuredContent!;
        expect(structured['success'], isTrue);
        expect(structured['operation'], 'init_plan');
        final plan = structured['plan'] as Map;
        expect(plan['projectName'], 'demo_app');
        expect(plan['architecture'], 'mvvm');
        expect(plan['stateManagement'], 'riverpod');
        expect(plan['network'], 'dio');
        expect(plan['storage'], 'hive');
        expect((plan['appTargets'] as List).toSet(), {'android', 'web'});
        expect(
          (plan['initialFeatures'] as List).toSet(),
          {'home', 'profile'},
        );
        expect(plan['services'], ['analytics']);

        expect(Directory(tempDir.path).listSync(), isEmpty,
            reason: 'init_plan must never create files');
      });

      test('omitted optional values follow Core defaults', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
        });

        expect(result.isError, isNot(true));
        final plan = result.structuredContent!['plan'] as Map;
        expect(plan['architecture'], 'cleanArchitecture');
        expect(plan['stateManagement'], 'bloc');
        expect(plan['network'], 'http');
        expect(plan['storage'], 'sharedPreferences');
        expect((plan['appTargets'] as List).toSet(), {'android', 'ios'});
        expect(plan['initialFeatures'], ['home']);
        expect(plan['services'], isEmpty);
      });

      test('reports safety state for an empty directory', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
        });

        final safety = result.structuredContent!['safety'] as Map;
        expect(safety['state'], 'empty');
        expect(safety['isRegeneration'], isFalse);
      });

      test(
          'reports regeneration + config diff for an existing SmartWork '
          'project', () async {
        await ProjectConfigFile(projectPath: tempDir.path).write(
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

        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'appTargets': ['android', 'web'],
          'services': ['logger'],
        });

        final safety = result.structuredContent!['safety'] as Map;
        expect(safety['state'], 'smartworkProject');
        expect(safety['isRegeneration'], isTrue);
        final targetsDiff = safety['appTargetsDiff'] as Map;
        expect(targetsDiff['added'], ['web']);
        final serviceChanges = safety['serviceChanges'] as Map;
        expect(serviceChanges['added'], ['logger']);
        expect(serviceChanges['removed'], ['analytics']);
      });

      test('semantic errors (empty initialFeatures) come from Core safely',
          () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'initialFeatures': <String>[],
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_configuration',
        );
      });

      test('an unknown enum value is rejected safely', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'architecture': 'not_a_real_architecture',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_configuration',
        );
      });

      test('a missing required projectName is rejected by the tool schema',
          () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
        });

        expect(result.isError, isTrue);
      });
    });

    group('init_apply', () {
      test('without confirmation, nothing is created', () async {
        final planResult = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
        });
        final plan = planResult.structuredContent!['plan'];

        final result = await call('smartwork_init_apply', {
          'projectPath': tempDir.path,
          'plan': plan,
          'confirm': false,
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'confirmation_required',
        );
        expect(Directory(tempDir.path).listSync(), isEmpty);
      });

      test('confirm omitted is rejected the same as confirm: false', () async {
        final planResult = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
        });
        final plan = planResult.structuredContent!['plan'];

        final result = await connection.callTool(CallToolRequest(
          name: 'smartwork_init_apply',
          arguments: {'projectPath': tempDir.path, 'plan': plan},
        ));

        expect(result.isError, isTrue);
        expect(Directory(tempDir.path).listSync(), isEmpty);
      });
    });

    group('init_apply with a real generation (injected fakes)', () {
      setUp(() {
        // Re-create the server for this group with a real
        // ProjectInitializer backed by fake FlutterBootstrap/
        // ProjectValidator, so "apply" performs a real (fake-bootstrap)
        // generation without needing the actual Flutter toolchain for
        // these fast in-process tests — the real toolchain is exercised
        // separately by the mandatory spawned-process E2E.
      });

      test('plan then apply with confirm: true performs real generation',
          () async {
        final localController = StreamChannelController<String>();
        final localServer = SmartworkMcpServer(
          localController.foreign,
          initTools: InitTools(
            initializer: ProjectInitializer(
              flutterBootstrap: _passingBootstrap(tempDir),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final localClient =
            MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
        final localConnection =
            localClient.connectServer(localController.local);
        await localConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
        ));
        localConnection.notifyInitialized();
        await localServer.initialized;

        final planResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_plan',
          arguments: {
            'projectPath': tempDir.path,
            'projectName': 'demo_app',
            'appTargets': ['android', 'ios'],
          },
        ));
        final plan = planResult.structuredContent!['plan'];

        final applyResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': plan,
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isNot(true));
        expect(applyResult.structuredContent!['success'], isTrue);
        expect(applyResult.structuredContent!['operation'], 'init_apply');
        expect(
          Directory('${tempDir.path}/lib/features/home').existsSync(),
          isTrue,
        );
        expect(File('${tempDir.path}/README.md').existsSync(), isTrue);

        await localClient.shutdown();
        await localServer.shutdown();
      });

      test(
          'an altered plan before apply is applied exactly as supplied '
          '— the client\'s latest explicit request is authoritative, '
          'not a prior plan call', () async {
        final localController = StreamChannelController<String>();
        final localServer = SmartworkMcpServer(
          localController.foreign,
          initTools: InitTools(
            initializer: ProjectInitializer(
              flutterBootstrap: _passingBootstrap(tempDir),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final localClient =
            MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
        final localConnection =
            localClient.connectServer(localController.local);
        await localConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
        ));
        localConnection.notifyInitialized();
        await localServer.initialized;

        final planResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_plan',
          arguments: {
            'projectPath': tempDir.path,
            'projectName': 'demo_app',
            'appTargets': ['android', 'ios'],
            'initialFeatures': ['home'],
          },
        ));
        final plan = Map<String, Object?>.from(
            planResult.structuredContent!['plan'] as Map);
        // The client alters one field before apply — adds a second
        // feature that was never in the original plan.
        plan['initialFeatures'] = ['home', 'settings'];

        final applyResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': plan,
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isNot(true));
        expect(
          Directory('${tempDir.path}/lib/features/settings').existsSync(),
          isTrue,
          reason: 'apply must use exactly the plan it was explicitly '
              'given, not a stale one from an earlier plan call',
        );

        await localClient.shutdown();
        await localServer.shutdown();
      });

      test(
          'a safety failure (invalid configuration in the plan) fails '
          'safely with no partial project', () async {
        final localController = StreamChannelController<String>();
        final localServer = SmartworkMcpServer(
          localController.foreign,
          initTools: InitTools(
            initializer: ProjectInitializer(
              flutterBootstrap: _passingBootstrap(tempDir),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final localClient =
            MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
        final localConnection =
            localClient.connectServer(localController.local);
        await localConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
        ));
        localConnection.notifyInitialized();
        await localServer.initialized;

        final applyResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': {
              'projectName': 'demo_app',
              'appTargets': ['android'],
              'architecture': 'cleanArchitecture',
              'stateManagement': 'bloc',
              'network': 'http',
              'storage': 'sharedPreferences',
              'services': [],
              'initialFeatures': <String>[],
            },
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isTrue);
        expect(
          (applyResult.structuredContent!['error'] as Map)['code'],
          'invalid_configuration',
        );
        expect(Directory(tempDir.path).listSync(), isEmpty,
            reason: 'no partial project on a safety failure');

        await localClient.shutdown();
        await localServer.shutdown();
      });

      test(
          'an unexpected exception is handled safely, with no stack '
          'trace exposed', () async {
        final localController = StreamChannelController<String>();
        final localServer = SmartworkMcpServer(
          localController.foreign,
          initTools: InitTools(
            initializer: ProjectInitializer(
              flutterBootstrap: FlutterBootstrap(
                runProcess: (executable, arguments, {workingDirectory}) async {
                  throw StateError('boom: unexpected failure');
                },
              ),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final localClient =
            MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
        final localConnection =
            localClient.connectServer(localController.local);
        await localConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
        ));
        localConnection.notifyInitialized();
        await localServer.initialized;

        final planResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_plan',
          arguments: {
            'projectPath': tempDir.path,
            'projectName': 'demo_app',
          },
        ));
        final plan = planResult.structuredContent!['plan'];

        final applyResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': plan,
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isTrue);
        final text = (applyResult.content.single as TextContent).text;
        expect(text, isNot(contains('boom')));
        expect(text, isNot(contains('StateError')));
        expect(text, isNot(contains('.dart:')));

        await localClient.shutdown();
        await localServer.shutdown();
      });
    });

    group('fonts (V1.1-5)', () {
      test(
          'init_plan with fontType: google returns the canonical fonts '
          'shape', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'fontType': 'google',
          'googleFontFamily': 'Poppins',
        });

        expect(result.isError, isNot(true));
        final plan = result.structuredContent!['plan'] as Map;
        final fonts = plan['fonts'] as Map;
        expect(fonts['type'], 'google');
        expect((fonts['google'] as Map)['family'], 'Poppins');
      });

      test(
          'init_plan with fontType: custom returns the canonical fonts '
          'shape, including the source path', () async {
        final fontFile = '${tempDir.path}/Schyler-Regular.ttf';
        File(fontFile).writeAsBytesSync([0, 1, 2, 3]);

        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'fontType': 'custom',
          'customFontFamily': 'Schyler',
          'customFontSourcePath': fontFile,
        });

        expect(result.isError, isNot(true));
        final plan = result.structuredContent!['plan'] as Map;
        final fonts = plan['fonts'] as Map;
        expect(fonts['type'], 'custom');
        final custom = fonts['custom'] as Map;
        expect(custom['family'], 'Schyler');
        expect((custom['files'] as List).single['sourcePath'], fontFile);
      });

      test('init_plan omitting fontType defaults to no font', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
        });

        final plan = result.structuredContent!['plan'] as Map;
        expect((plan['fonts'] as Map)['type'], 'none');
      });

      test('init_plan rejects a custom font whose file does not exist',
          () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'fontType': 'custom',
          'customFontFamily': 'Schyler',
          'customFontSourcePath': '${tempDir.path}/nope.ttf',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_configuration',
        );
      });

      test(
          'init_apply with a custom font copies the real file into the '
          'generated project\'s assets/fonts/', () async {
        final sourceFile = '${tempDir.path}_source/Schyler-Regular.ttf';
        Directory('${tempDir.path}_source').createSync();
        File(sourceFile).writeAsBytesSync([0, 1, 2, 3]);
        addTearDown(() =>
            Directory('${tempDir.path}_source').deleteSync(recursive: true));

        final localController = StreamChannelController<String>();
        final localServer = SmartworkMcpServer(
          localController.foreign,
          initTools: InitTools(
            initializer: ProjectInitializer(
              flutterBootstrap: _passingBootstrap(tempDir),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final localClient =
            MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
        final localConnection =
            localClient.connectServer(localController.local);
        await localConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
        ));
        localConnection.notifyInitialized();
        await localServer.initialized;

        final planResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_plan',
          arguments: {
            'projectPath': tempDir.path,
            'projectName': 'demo_app',
            'appTargets': ['android', 'ios'],
            'fontType': 'custom',
            'customFontFamily': 'Schyler',
            'customFontSourcePath': sourceFile,
          },
        ));
        final plan = planResult.structuredContent!['plan'];

        final applyResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': plan,
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isNot(true));
        expect(
          File('${tempDir.path}/assets/fonts/Schyler-Regular.ttf').existsSync(),
          isTrue,
        );
        expect(
          File('${tempDir.path}/lib/services/theme/app_theme.dart')
              .readAsStringSync(),
          contains("fontFamily: 'Schyler'"),
        );

        await localClient.shutdown();
        await localServer.shutdown();
      });
    });

    group('localization (V1.1-6)', () {
      test('init_plan omitting localizationEnabled defaults to disabled',
          () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
        });

        final plan = result.structuredContent!['plan'] as Map;
        expect((plan['localization'] as Map)['enabled'], isFalse);
      });

      test(
          'init_plan with localizationEnabled: true returns the '
          'canonical localization shape', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'localizationEnabled': true,
          'supportedLocales': ['en', 'fr', 'de'],
          'defaultLocale': 'fr',
        });

        expect(result.isError, isNot(true));
        final plan = result.structuredContent!['plan'] as Map;
        final localization = plan['localization'] as Map;
        expect(localization['enabled'], isTrue);
        expect(localization['supportedLocales'], ['en', 'fr', 'de']);
        expect(localization['defaultLocale'], 'fr');
      });

      test(
          'init_plan rejects localization enabled with no supported '
          'locales', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'localizationEnabled': true,
          'defaultLocale': 'en',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_configuration',
        );
      });

      test(
          'init_plan rejects a default locale not among the supported '
          'locales', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'localizationEnabled': true,
          'supportedLocales': ['en', 'fr'],
          'defaultLocale': 'de',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_configuration',
        );
      });

      test(
          'init_plan rejects a country-qualified locale missing its '
          'base language', () async {
        final result = await call('smartwork_init_plan', {
          'projectPath': tempDir.path,
          'projectName': 'demo_app',
          'localizationEnabled': true,
          'supportedLocales': ['en', 'pt_BR'],
          'defaultLocale': 'en',
        });

        expect(result.isError, isTrue);
        expect(
          (result.structuredContent!['error'] as Map)['code'],
          'invalid_configuration',
        );
      });

      test(
          'init_apply with localization enabled generates l10n.yaml, '
          'ARB resources, and wires the generated project', () async {
        final localController = StreamChannelController<String>();
        final localServer = SmartworkMcpServer(
          localController.foreign,
          initTools: InitTools(
            initializer: ProjectInitializer(
              flutterBootstrap: _passingBootstrap(tempDir),
              projectValidator: _passingValidator(),
            ),
          ),
        );
        final localClient =
            MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
        final localConnection =
            localClient.connectServer(localController.local);
        await localConnection.initialize(InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test-client', version: '0.0.1'),
        ));
        localConnection.notifyInitialized();
        await localServer.initialized;

        final planResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_plan',
          arguments: {
            'projectPath': tempDir.path,
            'projectName': 'demo_app',
            'appTargets': ['android', 'ios'],
            'localizationEnabled': true,
            'supportedLocales': ['en', 'fr'],
            'defaultLocale': 'en',
          },
        ));
        final plan = planResult.structuredContent!['plan'];

        final applyResult = await localConnection.callTool(CallToolRequest(
          name: 'smartwork_init_apply',
          arguments: {
            'projectPath': tempDir.path,
            'plan': plan,
            'confirm': true,
          },
        ));

        expect(applyResult.isError, isNot(true));
        expect(File('${tempDir.path}/l10n.yaml').existsSync(), isTrue);
        expect(
          File('${tempDir.path}/lib/l10n/app_en.arb').existsSync(),
          isTrue,
        );
        expect(
          File('${tempDir.path}/lib/l10n/app_fr.arb').existsSync(),
          isTrue,
        );
        expect(
          File('${tempDir.path}/lib/main.dart').readAsStringSync(),
          contains('AppLocalizations'),
        );

        await localClient.shutdown();
        await localServer.shutdown();
      });
    });
  });
}
