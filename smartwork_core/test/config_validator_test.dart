import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigValidator', () {
    test('validates valid configuration', () {
      final config = ProjectConfig(
        projectName: 'my_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home', 'profile'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isEmpty);
    });

    test('rejects empty project name', () {
      final config = ProjectConfig(
        projectName: '',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isNotEmpty);
      expect(errors[0].toString(), contains('empty'));
    });

    test('rejects invalid project name', () {
      final config = ProjectConfig(
        projectName: 'MyApp',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isNotEmpty);
      expect(errors[0].toString(), contains('lowercase'));
    });

    test('rejects no initial features', () {
      final config = ProjectConfig(
        projectName: 'my_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isNotEmpty);
      expect(errors[0].toString(), contains('feature'));
    });

    test('accepts MVP architecture', () {
      final config = ProjectConfig(
        projectName: 'mvp_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isEmpty);
    });

    test('accepts Riverpod state management', () {
      final config = ProjectConfig(
        projectName: 'riverpod_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.riverpod,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isEmpty);
    });

    test('accepts MVP + Riverpod combination', () {
      final config = ProjectConfig(
        projectName: 'mvp_riverpod_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['dashboard'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isEmpty);
    });

    test('accepts every known service, including all eight', () {
      final config = ProjectConfig(
        projectName: 'my_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        services: Service.values.map((s) => s.id).toSet(),
        initialFeatures: ['home'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isEmpty);
    });

    test('rejects an unknown service', () {
      final config = ProjectConfig(
        projectName: 'my_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        services: {'madeUpService'},
        initialFeatures: ['home'],
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isNotEmpty);
      expect(errors[0].toString(), contains('madeUpService'));
    });
  });
}
