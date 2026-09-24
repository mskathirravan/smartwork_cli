import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

ProjectConfig _configFor({
  required Architecture architecture,
  required StateManagement stateManagement,
  required Network network,
  Storage storage = Storage.sharedPreferences,
  Set<String>? services,
  FontConfig? fonts,
  LocalizationConfig? localization,
}) {
  return ProjectConfig(
    projectName: 'demo_app',
    architecture: architecture,
    stateManagement: stateManagement,
    network: network,
    storage: storage,
    services: services,
    fonts: fonts,
    localization: localization,
    initialFeatures: ['home'],
  );
}

void main() {
  group('PubspecGenerator.resolveDependencies', () {
    late PubspecGenerator generator;

    setUp(() {
      generator = PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      );
    });

    test('Clean + BLoC + http', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ));

      expect(deps.runtime,
          ['flutter', 'flutter_bloc', 'http', 'meta', 'shared_preferences']);
      expect(deps.dev, ['flutter_test']);
    });

    test('Clean + Riverpod + dio', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
      ));

      expect(deps.runtime,
          ['flutter', 'riverpod', 'dio', 'meta', 'shared_preferences']);
      expect(deps.dev, ['flutter_test']);
    });

    test('MVVM + GetX + http', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.getx,
        network: Network.http,
      ));

      expect(deps.runtime,
          ['flutter', 'get', 'http', 'meta', 'shared_preferences']);
    });

    test('MVP + Riverpod + dio', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.mvp,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
      ));

      expect(deps.runtime,
          ['flutter', 'riverpod', 'dio', 'meta', 'shared_preferences']);
    });

    test('Network.other adds no networking package at all', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.other,
      ));

      expect(deps.runtime, ['flutter', 'flutter_bloc', 'shared_preferences']);
      expect(deps.runtime, isNot(contains('http')));
      expect(deps.runtime, isNot(contains('dio')));
    });

    test('Storage.other adds no persistence package at all', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.other,
      ));

      expect(deps.runtime, ['flutter', 'flutter_bloc', 'http', 'meta']);
      expect(deps.runtime, isNot(contains('shared_preferences')));
      expect(deps.runtime, isNot(contains('hive_flutter')));
    });

    test('Network.other + Storage.other adds neither package', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.other,
        storage: Storage.other,
      ));

      expect(deps.runtime, ['flutter', 'flutter_bloc']);
    });

    test('Cubit maps to the same flutter_bloc package as BLoC', () {
      final deps = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.cubit,
        network: Network.http,
      ));

      expect(deps.runtime, contains('flutter_bloc'));
    });

    test(
        'architecture choice alone never adds a package beyond the '
        'universal flutter baseline', () {
      for (final architecture in Architecture.values) {
        final deps = generator.resolveDependencies(_configFor(
          architecture: architecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ));
        // Same state management + network + storage across all three
        // architectures must yield the exact same dependency set.
        expect(deps.runtime,
            ['flutter', 'flutter_bloc', 'http', 'meta', 'shared_preferences']);
      }
    });

    test('each storage option resolves to its own real pub.dev package', () {
      expect(
        generator
            .resolveDependencies(_configFor(
              architecture: Architecture.cleanArchitecture,
              stateManagement: StateManagement.bloc,
              network: Network.http,
              storage: Storage.sharedPreferences,
            ))
            .runtime,
        contains('shared_preferences'),
      );
      expect(
        generator
            .resolveDependencies(_configFor(
              architecture: Architecture.cleanArchitecture,
              stateManagement: StateManagement.bloc,
              network: Network.http,
              storage: Storage.hive,
            ))
            .runtime,
        contains('hive_flutter'),
      );
    });

    test(
        'storage choice never adds the other storage mechanism\'s '
        'package', () {
      for (final storage in Storage.values) {
        final deps = generator.resolveDependencies(_configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: storage,
        ));
        final otherPackage = switch (storage) {
          Storage.sharedPreferences => 'hive_flutter',
          Storage.hive => 'shared_preferences',
          Storage.other => 'shared_preferences',
        };
        expect(deps.runtime, isNot(contains(otherPackage)),
            reason: '$storage must not also pull in $otherPackage');
        if (storage == Storage.other) {
          expect(deps.runtime, isNot(contains('hive_flutter')));
        }
      }
    });

    test('the dependency set contains no duplicates for any combination', () {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          for (final network in Network.values) {
            for (final storage in Storage.values) {
              final deps = generator.resolveDependencies(_configFor(
                architecture: architecture,
                stateManagement: stateManagement,
                network: network,
                storage: storage,
              ));
              expect(deps.runtime.toSet().length, deps.runtime.length,
                  reason: '$architecture + $stateManagement + $network + '
                      '$storage produced a duplicate runtime dependency');
              expect(deps.dev.toSet().length, deps.dev.length);
            }
          }
        }
      }
    });

    test('resolution is deterministic across repeated calls', () {
      final config = _configFor(
        architecture: Architecture.mvp,
        stateManagement: StateManagement.getx,
        network: Network.dio,
      );

      final first = generator.resolveDependencies(config);
      final second = generator.resolveDependencies(config);

      expect(second.runtime, first.runtime);
      expect(second.dev, first.dev);
    });

    test(
        'selecting Event Bus adds no dependency (V1.1-4 — a pure, '
        'dependency-free in-memory service, same as the original eight '
        'provider-neutral services)', () {
      final without = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ));
      final withEventBus = generator.resolveDependencies(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        services: {Service.eventBus.id},
      ));

      expect(withEventBus.runtime, without.runtime);
      expect(withEventBus.dev, without.dev);
    });
  });

  group('PubspecGenerator.generate', () {
    late PubspecGenerator generator;

    setUp(() {
      generator = PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      );
    });

    test('produces valid, parseable YAML', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ));

      expect(() => loadYaml(content), returnsNormally);
    });

    test('uses SmartWork\'s default description when none is given', () async {
      final parsed = loadYaml(await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ))) as YamlMap;

      expect(
          parsed['description'], 'A Flutter project generated by SmartWork.');
    });

    test('uses projectDescription when one is given', () async {
      final parsed = loadYaml(await generator.generate(
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
        projectDescription: 'A personal productivity application.',
      )) as YamlMap;

      expect(parsed['description'], 'A personal productivity application.');
    });

    test('declares the project name from ProjectConfig', () async {
      final config = ProjectConfig(
        projectName: 'my_cool_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      final parsed = loadYaml(await generator.generate(config)) as YamlMap;
      expect(parsed['name'], 'my_cool_app');
    });

    test(
        'declares the correct SDK constraint, matching smartwork_core\'s '
        'own pubspec.yaml (not invented)', () async {
      final parsed = loadYaml(await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ))) as YamlMap;

      expect(parsed['environment']['sdk'], '^3.0.0');
    });

    test(
        'dependencies and dev_dependencies sections match '
        'resolveDependencies exactly', () async {
      final config = _configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
      );

      final parsed = loadYaml(await generator.generate(config)) as YamlMap;
      final deps = generator.resolveDependencies(config);

      final dependencies = parsed['dependencies'] as YamlMap;
      final devDependencies = parsed['dev_dependencies'] as YamlMap;

      for (final package in deps.runtime) {
        expect(dependencies.containsKey(package), isTrue,
            reason: '$package missing from dependencies');
      }
      expect(dependencies.length, deps.runtime.length);

      for (final package in deps.dev) {
        expect(devDependencies.containsKey(package), isTrue,
            reason: '$package missing from dev_dependencies');
      }
      expect(devDependencies.length, deps.dev.length);
    });

    test(
        'flutter and flutter_test use the sdk: flutter form, not a '
        'version string', () async {
      final parsed = loadYaml(await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ))) as YamlMap;

      expect(
        (parsed['dependencies'] as YamlMap)['flutter']['sdk'],
        'flutter',
      );
      expect(
        (parsed['dev_dependencies'] as YamlMap)['flutter_test']['sdk'],
        'flutter',
      );
    });

    test(
        'no managed third-party dependency ever uses the "any" '
        'constraint', () async {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          for (final network in Network.values) {
            for (final storage in Storage.values) {
              final content = await generator.generate(_configFor(
                architecture: architecture,
                stateManagement: stateManagement,
                network: network,
                storage: storage,
              ));
              expect(content, isNot(contains(': any')),
                  reason: '$architecture + $stateManagement + $network + '
                      '$storage still declares an unpinned dependency');
            }
          }
        }
      }
    });

    test('BLoC declares flutter_bloc at the centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ));

      expect(
          content, contains('flutter_bloc: ${DependencyVersions.flutterBloc}'));
    });

    test('Cubit declares flutter_bloc at the centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.cubit,
        network: Network.http,
      ));

      expect(
          content, contains('flutter_bloc: ${DependencyVersions.flutterBloc}'));
    });

    test('GetX declares get at the centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.getx,
        network: Network.http,
      ));

      expect(content, contains('get: ${DependencyVersions.get}'));
    });

    test(
        'Riverpod declares riverpod (not flutter_riverpod) at the '
        'centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.riverpod,
        network: Network.http,
      ));

      expect(content, contains('riverpod: ${DependencyVersions.riverpod}'));
      expect(content, isNot(contains('flutter_riverpod')));
    });

    test('Http declares http at the centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ));

      expect(content, contains('http: ${DependencyVersions.http}'));
    });

    test('Dio declares dio at the centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
      ));

      expect(content, contains('dio: ${DependencyVersions.dio}'));
    });

    test(
        'SharedPreferences declares shared_preferences at the '
        'centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
      ));

      expect(
          content,
          contains(
              'shared_preferences: ${DependencyVersions.sharedPreferences}'));
    });

    test('Hive declares hive_flutter at the centralized version', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.hive,
      ));

      expect(
          content, contains('hive_flutter: ${DependencyVersions.hiveFlutter}'));
    });

    test(
        'unused dependencies are never generated: BLoC config declares '
        'neither get nor riverpod', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
      ));

      expect(content, isNot(contains('get:')));
      expect(content, isNot(contains('riverpod:')));
    });

    test(
        'unused dependencies are never generated: Http config never '
        'declares dio, SharedPreferences config never declares hive', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
      ));

      expect(content, isNot(contains('dio:')));
      expect(content, isNot(contains('hive:')));
    });

    test(
        'no smartwork_core-internal dependency leaks into the generated '
        'pubspec (yaml, path, lints, args, test are SmartWork\'s own, not '
        'a generated Flutter project\'s)', () async {
      final content = await generator.generate(_configFor(
        architecture: Architecture.mvp,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
      ));

      for (final smartworkOwnPackage in ['yaml', 'path', 'lints', 'args']) {
        expect(content, isNot(contains('$smartworkOwnPackage:')),
            reason: '$smartworkOwnPackage is a SmartWork-internal '
                'dependency and must not leak into generated projects');
      }
    });

    test(
        'rendering the same config twice produces identical output '
        '(deterministic)', () async {
      final config = _configFor(
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.getx,
        network: Network.http,
      );

      expect(
          await generator.generate(config), await generator.generate(config));
    });
  });

  group('PubspecGenerator.mergeInto', () {
    late PubspecGenerator generator;

    setUp(() {
      generator = PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      );
    });

    /// A representative `flutter create`-generated pubspec.yaml — the
    /// real shape [mergeInto] must work against, not a SmartWork-owned
    /// fixture. Deliberately includes the pieces SmartWork must never
    /// remove or duplicate: the `flutter`/`flutter_test` SDK deps, a
    /// non-`^3.0.0` SDK constraint, Flutter's own default dependency
    /// (`cupertino_icons`), and the top-level `flutter:` config block.
    String flutterGeneratedPubspec({String name = 'demo_app'}) {
      return '''name: $name
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

  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''';
    }

    test(
        'a null or blank projectDescription leaves Flutter\'s own '
        'description line untouched', () async {
      final unchanged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );
      expect(unchanged, contains('description: "A new Flutter project."'));

      final blank = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
        projectDescription: '   ',
      );
      expect(blank, contains('description: "A new Flutter project."'));
    });

    test(
        'a non-blank projectDescription replaces Flutter\'s own '
        'description line — this is the smartwork init path', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
        projectDescription:
            'A mobile shopping app for discovering products and placing '
            'orders.',
      );

      expect(
        merged,
        contains('description: "A mobile shopping app for discovering '
            'products and placing orders."'),
      );
      expect(merged, isNot(contains('A new Flutter project.')));
    });

    test(
        'a projectDescription containing double quotes is escaped so the '
        'result is still valid YAML', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
        projectDescription: 'The "best" shopping app',
      );

      expect(() => loadYaml(merged), returnsNormally);
      final parsed = loadYaml(merged) as YamlMap;
      expect(parsed['description'], 'The "best" shopping app');
    });

    test(
        'adds SmartWork\'s runtime and dev dependencies with the '
        'centrally-managed versions', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.dio,
          storage: Storage.hive,
        ),
      );

      expect(merged, contains('riverpod: ${DependencyVersions.riverpod}'));
      expect(merged, contains('dio: ${DependencyVersions.dio}'));
      expect(
          merged, contains('hive_flutter: ${DependencyVersions.hiveFlutter}'));
    });

    test(
        'preserves everything Flutter generated: SDK constraint, the '
        'flutter: config block, and the default dependency', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );

      expect(merged, contains('sdk: ^3.9.2'),
          reason: 'the Flutter-generated SDK constraint must not be '
              'replaced with SmartWork\'s own ^3.0.0');
      expect(merged, contains('cupertino_icons: ^1.0.8'));
      expect(merged, contains('flutter_lints: ^5.0.0'));
      expect(merged, contains('flutter:'));
      expect(merged, contains('uses-material-design: true'),
          reason: 'the assets: block this milestone inserts sits between '
              'flutter: and uses-material-design: true, so they are no '
              'longer necessarily adjacent — both must still be present');
      expect(merged, contains('description: "A new Flutter project."'));
    });

    test('never duplicates the flutter/flutter_test SDK dependencies',
        () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.mvp,
          stateManagement: StateManagement.getx,
          network: Network.http,
        ),
      );

      expect(
        RegExp(r'^  flutter:\s*$', multiLine: true).allMatches(merged),
        hasLength(1),
        reason: 'the flutter: SDK dependency must appear exactly once '
            '(the top-level flutter: config block is a separate key and '
            'is intentionally not counted here)',
      );
      expect(
        RegExp(r'^  flutter_test:\s*$', multiLine: true).allMatches(merged),
        hasLength(1),
        reason: 'the flutter_test: SDK dependency must appear exactly once',
      );
    });

    test('never adds a dependency that is already present', () async {
      final withSharedPreferences = '''${flutterGeneratedPubspec()}
  shared_preferences: ^2.5.5
''';

      final merged = await generator.mergeInto(
        withSharedPreferences,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
        ),
      );

      expect(
        RegExp(r'shared_preferences:').allMatches(merged),
        hasLength(1),
      );
    });

    test('produces valid, parseable YAML with the project name intact',
        () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(name: 'zephyr_app'),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.cubit,
          network: Network.http,
        ),
      );

      final parsed = loadYaml(merged) as Map;
      expect(parsed['name'], 'zephyr_app');
      expect((parsed['dependencies'] as Map)['flutter_bloc'],
          DependencyVersions.flutterBloc);
      expect((parsed['dependencies'] as Map)['flutter'], isA<Map>());
      expect(parsed['flutter'], isA<Map>());
    });

    test(
        'declares the standard asset folders under the existing '
        'flutter: section, not a duplicate one', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );

      final parsed = loadYaml(merged) as Map;
      final assets = (parsed['flutter'] as Map)['assets'] as List;
      expect(assets, [
        'assets/images/',
        'assets/fonts/',
        'assets/icons/',
        'assets/animations/',
      ]);
    });

    test('never duplicates the assets: list if one is already present',
        () async {
      final withAssets = flutterGeneratedPubspec().replaceFirst(
        'flutter:\n  uses-material-design: true',
        'flutter:\n  uses-material-design: true\n  assets:\n'
            '    - assets/images/\n'
            '    - assets/fonts/\n'
            '    - assets/icons/\n'
            '    - assets/animations/',
      );

      final merged = await generator.mergeInto(
        withAssets,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );

      expect(RegExp(r'^\s*assets:\s*$', multiLine: true).allMatches(merged),
          hasLength(1));
    });
  });

  group('PubspecGenerator dependency synchronization (V1.1-M3)', () {
    late PubspecGenerator generator;

    setUp(() {
      generator = PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      );
    });

    String flutterGeneratedPubspec({String name = 'demo_app'}) {
      return '''name: $name
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

  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''';
    }

    test(
        'a fresh configuration merged into a bare Flutter pubspec '
        'produces exactly the dependencies that configuration needs', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );

      expect(merged, contains('http: ${DependencyVersions.http}'));
      expect(
          merged, contains('flutter_bloc: ${DependencyVersions.flutterBloc}'));
      expect(
        merged,
        contains('shared_preferences: ${DependencyVersions.sharedPreferences}'),
      );
    });

    test(
        'regenerating with a different Network provider removes the '
        'stale SmartWork-owned dependency', () async {
      final withHttp = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );

      final withDio = await generator.mergeInto(
        withHttp,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.dio,
        ),
      );

      expect(withDio, isNot(contains('  http:')));
      expect(withDio, contains('dio: ${DependencyVersions.dio}'));
      // meta is needed by both Http and Dio (NetworkService's
      // @visibleForTesting setters) — it must survive the switch, not
      // be treated as Http-specific and removed alongside it.
      expect(withDio, contains('meta: ${DependencyVersions.meta}'));
    });

    test(
        'regenerating with a different Storage provider removes the '
        'stale SmartWork-owned dependency', () async {
      final withSharedPreferences = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
        ),
      );

      final withHive = await generator.mergeInto(
        withSharedPreferences,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.hive,
        ),
      );

      expect(withHive, isNot(contains('  shared_preferences:')));
      expect(withHive,
          contains('hive_flutter: ${DependencyVersions.hiveFlutter}'));
      expect(
        withHive,
        contains(
          'path_provider_platform_interface: '
          '${DependencyVersions.pathProviderPlatformInterface}',
        ),
      );
    });

    test(
        'regenerating with a different StateManagement removes the '
        'stale SmartWork-owned dependency too — the same ownership '
        'mechanism applies uniformly, not just to Network/Storage', () async {
      final withBloc = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );

      final withRiverpod = await generator.mergeInto(
        withBloc,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
        ),
      );

      expect(withRiverpod, isNot(contains('  flutter_bloc:')));
      expect(
          withRiverpod, contains('riverpod: ${DependencyVersions.riverpod}'));
    });

    test(
        'regenerating as Network.other removes the previously-selected '
        'provider dependency and adds none in its place', () async {
      final withDio = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.dio,
        ),
      );

      final withOther = await generator.mergeInto(
        withDio,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.other,
        ),
      );

      expect(withOther, isNot(contains('  dio:')));
      expect(withOther, isNot(contains('  http:')));
      expect(withOther, isNot(contains('  meta:')),
          reason: 'meta is only needed by NetworkService\'s Http/Dio '
              'variants; Network.other\'s stub never imports it');
    });

    test(
        'regenerating as Storage.other removes both Hive dependencies '
        'and adds none in their place', () async {
      final withHive = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.hive,
        ),
      );

      final withOther = await generator.mergeInto(
        withHive,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.other,
        ),
      );

      expect(withOther, isNot(contains('  hive_flutter:')));
      expect(withOther, isNot(contains('  path_provider_platform_interface:')));
      expect(withOther, isNot(contains('  plugin_platform_interface:')));
    });

    test(
        'a developer-owned dependency survives a Network + Storage '
        'provider switch untouched', () async {
      final initial = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
        ),
      );
      // Simulate a developer hand-adding their own dependency after the
      // first generation — exactly what mergeInto must never remove.
      final withDeveloperDep = initial.replaceFirst(
        'dependencies:\n',
        'dependencies:\n  custom_package: ^1.2.3\n',
      );

      final regenerated = await generator.mergeInto(
        withDeveloperDep,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.dio,
          storage: Storage.hive,
        ),
      );

      expect(regenerated, contains('custom_package: ^1.2.3'));
      expect(regenerated, isNot(contains('  http:')));
      expect(regenerated, isNot(contains('  shared_preferences:')));
      expect(regenerated, contains('dio: ${DependencyVersions.dio}'));
      expect(regenerated,
          contains('hive_flutter: ${DependencyVersions.hiveFlutter}'));
    });

    test(
        'a developer dependency that happens to share a name pattern '
        'with a managed one is still left alone unless it is an exact '
        'match SmartWork itself would generate', () async {
      final withDeveloperDep = flutterGeneratedPubspec().replaceFirst(
        'dependencies:\n',
        'dependencies:\n  http_parser: ^4.0.0\n',
      );

      final merged = await generator.mergeInto(
        withDeveloperDep,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.dio,
        ),
      );

      expect(merged, contains('http_parser: ^4.0.0'),
          reason: 'http_parser is not a name SmartWork ever generates — '
              'it must never be confused with the managed "http" package');
    });

    test(
        'flutter/flutter_test and Flutter\'s own default dependencies '
        'survive every provider switch', () async {
      final initial = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
        ),
      );

      final regenerated = await generator.mergeInto(
        initial,
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.other,
          storage: Storage.other,
        ),
      );

      expect(regenerated, contains('cupertino_icons: ^1.0.8'));
      expect(regenerated, contains('flutter_lints: ^5.0.0'));
      expect(
        RegExp(r'^  flutter:\s*$', multiLine: true).allMatches(regenerated),
        hasLength(1),
      );
      expect(
        RegExp(r'^  flutter_test:\s*$', multiLine: true)
            .allMatches(regenerated),
        hasLength(1),
      );
    });

    test(
        'assets/fonts configuration under the flutter: section survives '
        'a full Network + Storage + StateManagement switch', () async {
      final initial = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
        ),
      );

      final regenerated = await generator.mergeInto(
        initial,
        _configFor(
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.dio,
          storage: Storage.hive,
        ),
      );

      expect(regenerated, contains('uses-material-design: true'));
      expect(
          RegExp(r'^\s*assets:\s*$', multiLine: true).allMatches(regenerated),
          hasLength(1));
      expect(regenerated, contains('- assets/images/'));
    });

    test(
        'applying the same configuration a second time is a no-op — '
        'dependency synchronization is idempotent', () async {
      final config = _configFor(
        architecture: Architecture.mvp,
        stateManagement: StateManagement.getx,
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      final first =
          await generator.mergeInto(flutterGeneratedPubspec(), config);
      final second = await generator.mergeInto(first, config);

      expect(second, first);
    });

    test(
        'applying the same configuration twice after a provider switch '
        'is also a no-op', () async {
      final withHttp = await generator.mergeInto(
        flutterGeneratedPubspec(),
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
        ),
      );
      final dioConfig = _configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
      );

      final firstSwitch = await generator.mergeInto(withHttp, dioConfig);
      final secondSwitch = await generator.mergeInto(firstSwitch, dioConfig);

      expect(secondSwitch, firstSwitch);
    });

    test(
        'a full round trip back to the original configuration removes '
        'every intermediate dependency and restores the original set',
        () async {
      final httpSharedPrefsConfig = _configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
      );
      final dioHiveConfig = _configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
      );
      final otherOtherConfig = _configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.other,
        storage: Storage.other,
      );

      var content = await generator.mergeInto(
        flutterGeneratedPubspec(),
        httpSharedPrefsConfig,
      );
      content = await generator.mergeInto(content, dioHiveConfig);
      content = await generator.mergeInto(content, otherOtherConfig);
      content = await generator.mergeInto(content, httpSharedPrefsConfig);

      expect(content, contains('http: ${DependencyVersions.http}'));
      expect(
        content,
        contains(
          'shared_preferences: ${DependencyVersions.sharedPreferences}',
        ),
      );
      expect(content, isNot(contains('  dio:')));
      expect(content, isNot(contains('  hive_flutter:')));
      expect(content, isNot(contains('  path_provider_platform_interface:')));
      expect(content, isNot(contains('  plugin_platform_interface:')));
    });
  });

  group('PubspecGenerator fonts (V1.1-5)', () {
    late PubspecGenerator generator;
    late String tempFontPath;

    setUp(() {
      generator = PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      );
      final dir = Directory.systemTemp.createTempSync('smartwork_font_pg_');
      tempFontPath = '${dir.path}/Schyler-Regular.ttf';
      File(tempFontPath).writeAsBytesSync([0, 1, 2, 3]);
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    String flutterGeneratedPubspec() {
      return '''name: demo_app
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

  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''';
    }

    ProjectConfig configWithFonts(FontConfig fonts) => _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          fonts: fonts,
        );

    test('no font selected adds no dependency and no fonts: block', () async {
      final deps = generator.resolveDependencies(configWithFonts(
        FontConfig.none(),
      ));
      expect(deps.runtime, isNot(contains('google_fonts')));

      final generated =
          await generator.generate(configWithFonts(FontConfig.none()));
      expect(generated, isNot(contains('google_fonts')));
      expect(generated, isNot(contains('  fonts:')));
    });

    test(
        'Google Font selected adds the google_fonts dependency, and no '
        'fonts: block (needs no static asset registration)', () async {
      final config = configWithFonts(
        FontConfig.google(GoogleFontConfig(family: 'Poppins')),
      );

      final deps = generator.resolveDependencies(config);
      expect(deps.runtime, contains('google_fonts'));

      final generated = await generator.generate(config);
      expect(
        generated,
        contains('google_fonts: ${DependencyVersions.googleFonts}'),
      );
      expect(generated, isNot(contains('  fonts:')));
    });

    test(
        'Custom Font selected generates the exact fonts: block, and no '
        'google_fonts dependency', () async {
      final config = configWithFonts(
        FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: tempFontPath)],
        )),
      );

      final deps = generator.resolveDependencies(config);
      expect(deps.runtime, isNot(contains('google_fonts')));

      final generated = await generator.generate(config);
      expect(generated, isNot(contains('google_fonts')));
      expect(
        generated,
        contains('  fonts:\n'
            '    - family: Schyler\n'
            '      fonts:\n'
            '        - asset: assets/fonts/Schyler-Regular.ttf\n'),
      );
    });

    test('a custom font file\'s weight/style are rendered when given',
        () async {
      final config = configWithFonts(
        FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [
            CustomFontFile(sourcePath: tempFontPath, weight: 700, italic: true),
          ],
        )),
      );

      final generated = await generator.generate(config);
      expect(
        generated,
        contains('        - asset: assets/fonts/Schyler-Regular.ttf\n'
            '          weight: 700\n'
            '          style: italic\n'),
      );
    });

    test(
        'mergeInto: fresh custom font configuration inserts both the '
        'fonts: block and no google_fonts dependency', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithFonts(FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: tempFontPath)],
        ))),
      );

      expect(merged, contains('  fonts:'));
      expect(merged, contains('- family: Schyler'));
      expect(merged, isNot(contains('google_fonts')));
    });

    test(
        'mergeInto: fresh Google Font configuration adds the dependency '
        'and never inserts a fonts: block', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithFonts(FontConfig.google(GoogleFontConfig(family: 'Lato'))),
      );

      expect(
          merged, contains('google_fonts: ${DependencyVersions.googleFonts}'));
      expect(merged, isNot(contains('  fonts:')));
    });

    test(
        'Google -> Custom: the stale google_fonts dependency is removed '
        'and the fonts: block is inserted', () async {
      final withGoogle = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithFonts(FontConfig.google(GoogleFontConfig(family: 'Lato'))),
      );

      final withCustom = await generator.mergeInto(
        withGoogle,
        configWithFonts(FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: tempFontPath)],
        ))),
      );

      expect(withCustom, isNot(contains('google_fonts')));
      expect(withCustom, contains('  fonts:'));
      expect(withCustom, contains('- family: Schyler'));
    });

    test(
        'Custom -> Google: the fonts: block is removed and google_fonts '
        'is added', () async {
      final withCustom = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithFonts(FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: tempFontPath)],
        ))),
      );

      final withGoogle = await generator.mergeInto(
        withCustom,
        configWithFonts(FontConfig.google(GoogleFontConfig(family: 'Lato'))),
      );

      expect(withGoogle, isNot(contains('  fonts:')));
      expect(withGoogle, isNot(contains('- family: Schyler')));
      expect(
        withGoogle,
        contains('google_fonts: ${DependencyVersions.googleFonts}'),
      );
    });

    test(
        'switching custom font family replaces the fonts: block '
        'wholesale — no stale family left behind', () async {
      final secondFontPath =
          tempFontPath.replaceFirst('Schyler-Regular.ttf', 'Lobster.ttf');
      File(secondFontPath).writeAsBytesSync([0, 1, 2, 3]);

      final withFirst = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithFonts(FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: tempFontPath)],
        ))),
      );

      final withSecond = await generator.mergeInto(
        withFirst,
        configWithFonts(FontConfig.custom(CustomFontConfig(
          family: 'Lobster',
          files: [CustomFontFile(sourcePath: secondFontPath)],
        ))),
      );

      expect(withSecond, isNot(contains('Schyler')));
      expect(withSecond, contains('- family: Lobster'));
      expect(withSecond, contains('assets/fonts/Lobster.ttf'));
      // Exactly one top-level fonts: block — never a duplicate second
      // one (see the idempotency test above for why this must be an
      // exact-line match, not a substring search).
      expect(
        withSecond.split('\n').where((line) => line == '  fonts:').length,
        1,
      );
    });

    test(
        'removing the font entirely (custom -> none) removes the fonts: '
        'block and leaves everything else untouched', () async {
      final withCustom = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithFonts(FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: tempFontPath)],
        ))),
      );

      final withNone = await generator.mergeInto(
        withCustom,
        configWithFonts(FontConfig.none()),
      );

      expect(withNone, isNot(contains('fonts:')));
      expect(withNone, contains('cupertino_icons: ^1.0.8'));
      expect(withNone, contains('flutter_lints: ^5.0.0'));
      expect(withNone, contains('  assets:'));
    });

    test(
        'idempotency: applying the same custom font configuration twice '
        'produces no duplicate block and identical content', () async {
      final config = configWithFonts(FontConfig.custom(CustomFontConfig(
        family: 'Schyler',
        files: [CustomFontFile(sourcePath: tempFontPath)],
      )));

      final once = await generator.mergeInto(flutterGeneratedPubspec(), config);
      final twice = await generator.mergeInto(once, config);

      expect(twice, once);
      // Exact-line count, not a substring search: `_fontLines` also
      // emits a nested `      fonts:` key (Flutter's own required
      // per-family key, indented under `- family:`), whose text
      // trivially contains the substring `'  fonts:'` too — only an
      // exact-line match reflects "how many top-level fonts: blocks
      // exist", which is what this test actually means to assert.
      expect(
        twice.split('\n').where((line) => line == '  fonts:').length,
        1,
      );
    });

    test(
        'an unrelated developer dependency survives every font '
        'transition untouched', () async {
      final base = flutterGeneratedPubspec().replaceFirst(
        '  cupertino_icons: ^1.0.8',
        '  cupertino_icons: ^1.0.8\n  freezed_annotation: ^2.4.1',
      );

      var content = await generator.mergeInto(
        base,
        configWithFonts(FontConfig.google(GoogleFontConfig(family: 'Lato'))),
      );
      content = await generator.mergeInto(
        content,
        configWithFonts(FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: tempFontPath)],
        ))),
      );
      content = await generator.mergeInto(
        content,
        configWithFonts(FontConfig.none()),
      );

      expect(content, contains('freezed_annotation: ^2.4.1'));
    });
  });

  group('PubspecGenerator localization (V1.1-6)', () {
    late PubspecGenerator generator;

    setUp(() => generator = PubspecGenerator());

    String flutterGeneratedPubspec() {
      return '''name: demo_app
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

  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''';
    }

    ProjectConfig configWithLocalization(LocalizationConfig localization) =>
        _configFor(
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          localization: localization,
        );

    test('disabled adds no dependency and no generate: true flag', () async {
      final config = configWithLocalization(LocalizationConfig.disabled());

      final deps = generator.resolveDependencies(config);
      expect(deps.runtime, isNot(contains('flutter_localizations')));
      expect(deps.runtime, isNot(contains('intl')));

      final generated = await generator.generate(config);
      expect(generated, isNot(contains('flutter_localizations')));
      expect(generated, isNot(contains('generate: true')));
    });

    test(
        'enabled adds flutter_localizations (SDK form) and intl, and '
        'the generate: true flag', () async {
      final config = configWithLocalization(LocalizationConfig.enabled(
        supportedLocales: ['en', 'fr'],
        defaultLocale: 'en',
      ));

      final deps = generator.resolveDependencies(config);
      expect(deps.runtime, contains('flutter_localizations'));
      expect(deps.runtime, contains('intl'));

      final generated = await generator.generate(config);
      expect(
        generated,
        contains('  flutter_localizations:\n    sdk: flutter\n'),
      );
      expect(generated, contains('intl: ${DependencyVersions.intl}'));
      expect(generated, contains('  generate: true'));
    });

    test(
        'mergeInto: fresh enabled configuration adds the dependency '
        'and the generate: true flag', () async {
      final merged = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithLocalization(LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        )),
      );

      expect(merged, contains('flutter_localizations:'));
      expect(merged, contains('intl: ${DependencyVersions.intl}'));
      expect(merged, contains('  generate: true'));
    });

    test(
        'enabled -> disabled removes the dependency and the generate: '
        'true flag', () async {
      final withLocalization = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithLocalization(LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        )),
      );

      final withoutLocalization = await generator.mergeInto(
        withLocalization,
        configWithLocalization(LocalizationConfig.disabled()),
      );

      expect(withoutLocalization, isNot(contains('flutter_localizations')));
      expect(withoutLocalization, isNot(contains('  intl:')));
      expect(withoutLocalization, isNot(contains('generate: true')));
    });

    test('disabled -> enabled adds the dependency and the flag', () async {
      final withoutLocalization = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithLocalization(LocalizationConfig.disabled()),
      );

      final withLocalization = await generator.mergeInto(
        withoutLocalization,
        configWithLocalization(LocalizationConfig.enabled(
          supportedLocales: ['en', 'de'],
          defaultLocale: 'de',
        )),
      );

      expect(withLocalization, contains('flutter_localizations:'));
      expect(withLocalization, contains('generate: true'));
    });

    test(
        'idempotency: applying the same enabled configuration twice '
        'produces identical content with no duplicate flag/dependency',
        () async {
      final config = configWithLocalization(LocalizationConfig.enabled(
        supportedLocales: ['en', 'fr'],
        defaultLocale: 'en',
      ));

      final once = await generator.mergeInto(flutterGeneratedPubspec(), config);
      final twice = await generator.mergeInto(once, config);

      expect(twice, once);
      expect(
        twice.split('\n').where((line) => line == '  generate: true').length,
        1,
      );
      expect(
        twice
            .split('\n')
            .where((line) => line == '  flutter_localizations:')
            .length,
        1,
      );
    });

    test(
        'locale set A -> locale set B leaves dependencies/flag '
        'unchanged (only lib/l10n/ resources vary — see '
        'ProjectGenerator)', () async {
      final withSetA = await generator.mergeInto(
        flutterGeneratedPubspec(),
        configWithLocalization(LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr', 'de'],
          defaultLocale: 'en',
        )),
      );

      final withSetB = await generator.mergeInto(
        withSetA,
        configWithLocalization(LocalizationConfig.enabled(
          supportedLocales: ['en', 'es'],
          defaultLocale: 'en',
        )),
      );

      expect(withSetB, contains('flutter_localizations:'));
      expect(withSetB, contains('generate: true'));
      expect(
        withSetB.split('\n').where((line) => line == '  generate: true').length,
        1,
      );
    });

    test(
        'an unrelated developer dependency and Flutter\'s own defaults '
        'survive every localization transition untouched', () async {
      final base = flutterGeneratedPubspec().replaceFirst(
        '  cupertino_icons: ^1.0.8',
        '  cupertino_icons: ^1.0.8\n  freezed_annotation: ^2.4.1',
      );

      var content = await generator.mergeInto(
        base,
        configWithLocalization(LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        )),
      );
      content = await generator.mergeInto(
        content,
        configWithLocalization(LocalizationConfig.disabled()),
      );

      expect(content, contains('freezed_annotation: ^2.4.1'));
      expect(content, contains('cupertino_icons: ^1.0.8'));
      expect(content, contains('  assets:'));
    });

    test(
        'coexists correctly with a Google Font — both dependencies '
        'present, neither disturbs the other', () async {
      final config = _configFor(
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        ),
      );

      final generated = await generator.generate(config);

      expect(generated,
          contains('google_fonts: ${DependencyVersions.googleFonts}'));
      expect(generated, contains('flutter_localizations:'));
      expect(generated, contains('intl: ${DependencyVersions.intl}'));
      expect(generated, contains('generate: true'));
    });
  });
}
