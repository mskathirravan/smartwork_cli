import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// SmartWork package boundary: `smartwork_core` is a
/// pure library — no executable of its own — and `smartwork_cli` is the
/// sole SmartWork executable. These tests guard against either package
/// drifting back toward the old, obsolete `smartwork_core/bin/` scratch
/// scripts this milestone removed (they referenced a nonexistent
/// `_validation/` directory and predated the current `ProjectGenerator`
/// shape entirely — confirmed to have zero references anywhere in the
/// repository before deletion).
void main() {
  group('smartwork_core package boundary', () {
    test('has no bin/ directory — it is a pure library package', () {
      expect(Directory('bin').existsSync(), isFalse);
    });

    test('pubspec.yaml declares no executables', () {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      expect(pubspec.containsKey('executables'), isFalse);
    });

    test(
        'lib/ and test/ are the only top-level Dart-relevant '
        'directories', () {
      final topLevelDirs = Directory.current
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(Platform.pathSeparator).last)
          .toSet();

      expect(topLevelDirs.contains('bin'), isFalse);
      expect(topLevelDirs.contains('lib'), isTrue);
      expect(topLevelDirs.contains('test'), isTrue);
    });
  });

  group(
      'smartwork_cli package boundary (sibling package in this '
      'monorepo)', () {
    late Directory cliRoot;

    setUp(() {
      cliRoot = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}smartwork_cli',
      );
    });

    test('exists as a sibling package', () {
      expect(cliRoot.existsSync(), isTrue);
    });

    test('remains the sole executable — bin/smartwork.dart exists', () {
      final entrypoint = File(
        '${cliRoot.path}${Platform.pathSeparator}bin${Platform.pathSeparator}smartwork.dart',
      );
      expect(entrypoint.existsSync(), isTrue);
    });

    test('pubspec.yaml depends on smartwork_core, never the reverse', () {
      final cliPubspec = loadYaml(
        File('${cliRoot.path}${Platform.pathSeparator}pubspec.yaml')
            .readAsStringSync(),
      ) as YamlMap;
      final dependencies = cliPubspec['dependencies'] as YamlMap;
      expect(dependencies.containsKey('smartwork_core'), isTrue);

      final corePubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final coreDependencies =
          (corePubspec['dependencies'] as YamlMap?) ?? YamlMap();
      expect(coreDependencies.containsKey('smartwork_cli'), isFalse);
    });
  });
}
