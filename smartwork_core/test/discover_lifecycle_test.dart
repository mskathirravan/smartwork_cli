import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('DiscoverLifecycle.discover', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_discover_lc_test_');
      projectPath = tempDir.path;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'a SmartWork-generated project reports architecture/'
        'stateManagement/platforms as declared, straight from '
        'ProjectConfig — never re-inferred', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home'],
        appTargets: {AppTarget.android, AppTarget.web},
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();

      final knowledge = await DiscoverLifecycle().discover(projectPath);

      expect(knowledge.project.value.isSmartworkProject, isTrue);
      expect(knowledge.project.confidence, DiscoveryConfidence.declared);

      expect(knowledge.architecture.value, Architecture.mvvm);
      expect(knowledge.architecture.confidence, DiscoveryConfidence.declared);

      expect(knowledge.stateManagement.value, StateManagement.riverpod);
      expect(
        knowledge.stateManagement.confidence,
        DiscoveryConfidence.declared,
      );

      expect(
        knowledge.platforms.value,
        {AppTarget.android, AppTarget.web},
      );
      expect(knowledge.platforms.confidence, DiscoveryConfidence.declared);

      // Never declared — SmartWork has no config field for these; they
      // always run their real analyzers.
      expect(
        knowledge.dependencyInjection.confidence,
        isNot(DiscoveryConfidence.declared),
      );
      expect(knowledge.features.value, isNotEmpty);
    });

    test(
        'a foreign Flutter project (no .smartwork/project.yaml) is '
        'analyzed for real — architecture/stateManagement come from '
        'analyzers, never fabricated as declared', () async {
      await File('$projectPath/pubspec.yaml').create(recursive: true);
      await File('$projectPath/pubspec.yaml').writeAsString('''
name: foreign_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter_bloc: ^9.1.1
''');
      await Directory('$projectPath/lib').create(recursive: true);
      await Directory('$projectPath/android').create(recursive: true);

      final blocFile = File(
        '$projectPath/lib/features/profile/state/profile_bloc.dart',
      );
      await blocFile.create(recursive: true);
      await blocFile.writeAsString(
        'class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {}',
      );

      final knowledge = await DiscoverLifecycle().discover(projectPath);

      expect(knowledge.project.value.isSmartworkProject, isFalse);
      expect(knowledge.project.value.isFlutterProject, isTrue);
      expect(knowledge.project.confidence, DiscoveryConfidence.detected);

      expect(knowledge.stateManagement.value, StateManagement.bloc);
      expect(
        knowledge.stateManagement.confidence,
        DiscoveryConfidence.detected,
      );

      expect(knowledge.platforms.value, contains(AppTarget.android));
      expect(knowledge.platforms.confidence, DiscoveryConfidence.detected);

      expect(knowledge.features.value.single.name, 'profile');
    });

    test('an empty directory throws NotAFlutterProjectException', () async {
      expect(
        () => DiscoverLifecycle().discover(projectPath),
        throwsA(isA<NotAFlutterProjectException>()),
      );
    });

    test(
        'a directory with unrelated files (not a Flutter project) '
        'throws NotAFlutterProjectException', () async {
      await File('$projectPath/README.md').create(recursive: true);
      await File('$projectPath/README.md').writeAsString('hello');

      expect(
        () => DiscoverLifecycle().discover(projectPath),
        throwsA(isA<NotAFlutterProjectException>()),
      );
    });

    test(
        'a malformed SmartWork project (unreadable .smartwork/'
        'project.yaml) still analyzes what it can, rather than failing '
        'outright', () async {
      await Directory('$projectPath/.smartwork').create(recursive: true);
      await File('$projectPath/.smartwork/project.yaml')
          .writeAsString('not: valid: [[[');
      await File('$projectPath/pubspec.yaml').writeAsString('''
name: broken_config_app
environment:
  sdk: ^3.0.0
''');
      await Directory('$projectPath/lib').create(recursive: true);

      final knowledge = await DiscoverLifecycle().discover(projectPath);

      expect(knowledge.project.value.isSmartworkProject, isFalse);
      expect(
        knowledge.project.evidence.single,
        contains('could not be read'),
      );
    });

    test('discover never writes to the project directory', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();

      final beforeConfig =
          await File('$projectPath/.smartwork/project.yaml').readAsString();
      final beforePubspec =
          await File('$projectPath/pubspec.yaml').readAsString();

      await DiscoverLifecycle().discover(projectPath);
      await DiscoverLifecycle().discover(projectPath);

      expect(
        await File('$projectPath/.smartwork/project.yaml').readAsString(),
        beforeConfig,
      );
      expect(
        await File('$projectPath/pubspec.yaml').readAsString(),
        beforePubspec,
      );
    });
  });
}
