import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectConfigFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('write creates .smartwork directory and config file', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final config = ProjectConfig(
        projectName: 'test_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home'],
      );

      await configFile.write(config);

      final yamlFile =
          File(path.join(tempDir.path, '.smartwork', 'project.yaml'));
      expect(await yamlFile.exists(), isTrue);
    });

    test('write creates valid YAML content', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final config = ProjectConfig(
        projectName: 'my_app',
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.cubit,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: {'analytics', 'logger'},
        initialFeatures: ['splash', 'home'],
      );

      await configFile.write(config);

      final yamlFile =
          File(path.join(tempDir.path, '.smartwork', 'project.yaml'));
      final content = await yamlFile.readAsString();

      expect(content, contains("projectName: 'my_app'"));
      expect(content, contains("architecture: 'mvvm'"));
      expect(content, contains("stateManagement: 'cubit'"));
      expect(content, contains("network: 'http'"));
      expect(content, contains("storage: 'sharedPreferences'"));
      expect(content, contains("initialFeatures:"));
    });

    test('read parses YAML file into ProjectConfig', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final originalConfig = ProjectConfig(
        projectName: 'read_test',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.getx,
        network: Network.dio,
        storage: Storage.hive,
        services: {'notification'},
        initialFeatures: ['auth', 'dashboard'],
      );

      await configFile.write(originalConfig);
      final readConfig = await configFile.read();

      expect(readConfig.projectName, equals(originalConfig.projectName));
      expect(readConfig.architecture, equals(originalConfig.architecture));
      expect(
          readConfig.stateManagement, equals(originalConfig.stateManagement));
      expect(readConfig.network, equals(originalConfig.network));
      expect(readConfig.storage, equals(originalConfig.storage));
      expect(readConfig.services, equals(originalConfig.services));
      expect(
          readConfig.initialFeatures, equals(originalConfig.initialFeatures));
    });

    test('read throws when config file does not exist', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);

      expect(
        () => configFile.read(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('roundtrip: write -> read preserves config', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final original = ProjectConfig(
        projectName: 'roundtrip_app',
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: {'deeplink', 'crashReporting', 'logger'},
        initialFeatures: ['login', 'home', 'profile'],
      );

      await configFile.write(original);
      final restored = await configFile.read();

      expect(restored.projectName, equals(original.projectName));
      expect(restored.architecture, equals(original.architecture));
      expect(restored.stateManagement, equals(original.stateManagement));
      expect(restored.network, equals(original.network));
      expect(restored.storage, equals(original.storage));
      expect(restored.services, equals(original.services));
      expect(restored.initialFeatures, equals(original.initialFeatures));
    });

    test('overwrite replaces existing config file', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final config1 = ProjectConfig(
        projectName: 'app_v1',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['feature1'],
      );
      final config2 = ProjectConfig(
        projectName: 'app_v2',
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.cubit,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['feature2', 'feature3'],
      );

      await configFile.write(config1);
      await configFile.write(config2);
      final readConfig = await configFile.read();

      expect(readConfig.projectName, equals('app_v2'));
      expect(readConfig.architecture, equals(Architecture.mvvm));
      expect(readConfig.initialFeatures, equals(['feature2', 'feature3']));
    });

    test('write and read MVP architecture', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final config = ProjectConfig(
        projectName: 'mvp_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home'],
      );

      await configFile.write(config);
      final readConfig = await configFile.read();

      expect(readConfig.architecture, equals(Architecture.mvp));
      expect(readConfig.projectName, equals('mvp_app'));
    });

    test('write and read Riverpod state management', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final config = ProjectConfig(
        projectName: 'riverpod_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.riverpod,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home', 'details'],
      );

      await configFile.write(config);
      final readConfig = await configFile.read();

      expect(readConfig.stateManagement, equals(StateManagement.riverpod));
      expect(readConfig.projectName, equals('riverpod_app'));
    });

    test('write and read MVP + Riverpod combination', () async {
      final configFile = ProjectConfigFile(projectPath: tempDir.path);
      final config = ProjectConfig(
        projectName: 'mvp_riverpod_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
        storage: Storage.hive,
        services: {'analytics'},
        initialFeatures: ['home', 'dashboard'],
      );

      await configFile.write(config);
      final readConfig = await configFile.read();

      expect(readConfig.architecture, equals(Architecture.mvp));
      expect(readConfig.stateManagement, equals(StateManagement.riverpod));
      expect(readConfig.services, contains('analytics'));
      expect(readConfig.initialFeatures, equals(['home', 'dashboard']));
    });
  });
}
