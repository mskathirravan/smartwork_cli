import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectScanner', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_scanner_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('parses a real pubspec.yaml into a plain map', () async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: demo_app
environment:
  sdk: ^3.0.0
  flutter: ">=3.0.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
dev_dependencies:
  flutter_test:
    sdk: flutter
''');

      final result = await ProjectScanner().scan(tempDir.path);

      expect(result.pubspecYaml, isNotNull);
      expect(result.pubspecYaml!['name'], 'demo_app');
      expect(
        (result.pubspecYaml!['dependencies'] as Map)['flutter_bloc'],
        '^9.1.1',
      );
      expect(
        (result.pubspecYaml!['environment'] as Map)['sdk'],
        '^3.0.0',
      );
    });

    test('returns a null pubspecYaml when the file is missing', () async {
      final result = await ProjectScanner().scan(tempDir.path);
      expect(result.pubspecYaml, isNull);
    });

    test('returns a null pubspecYaml for malformed YAML, never throws',
        () async {
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('not: valid: yaml: [[[');

      final result = await ProjectScanner().scan(tempDir.path);
      expect(result.pubspecYaml, isNull);
    });

    test(
        'collects every .dart file under lib/ and test/, keyed by a '
        'forward-slash relative path', () async {
      final libFile = File('${tempDir.path}/lib/features/profile/state/'
          'profile_bloc.dart');
      await libFile.create(recursive: true);
      await libFile.writeAsString('class ProfileBloc {}');

      final testFile = File('${tempDir.path}/test/features/profile/'
          'profile_test.dart');
      await testFile.create(recursive: true);
      await testFile.writeAsString("void main() {}");

      // A non-.dart file must never be collected.
      final readme = File('${tempDir.path}/lib/README.md');
      await readme.create(recursive: true);
      await readme.writeAsString('not dart');

      final result = await ProjectScanner().scan(tempDir.path);

      expect(
        result.dartFiles['lib/features/profile/state/profile_bloc.dart'],
        'class ProfileBloc {}',
      );
      expect(
        result.dartFiles['test/features/profile/profile_test.dart'],
        isNotNull,
      );
      expect(result.dartFiles.keys, isNot(contains('lib/README.md')));
    });

    test(
        'featureFolderNames derives feature names purely from scanned '
        'paths', () async {
      for (final featureFile in [
        'lib/features/profile/state/profile_bloc.dart',
        'lib/features/settings/views/settings_page.dart',
      ]) {
        final file = File('${tempDir.path}/$featureFile');
        await file.create(recursive: true);
        await file.writeAsString('// stub');
      }

      final result = await ProjectScanner().scan(tempDir.path);

      expect(result.featureFolderNames, {'profile', 'settings'});
    });

    test(
        'hasTestsForFeature is true only when a real test file exists '
        'under test/features/<name>/', () async {
      final testFile =
          File('${tempDir.path}/test/features/profile/profile_test.dart');
      await testFile.create(recursive: true);
      await testFile.writeAsString('// stub');

      final result = await ProjectScanner().scan(tempDir.path);

      expect(result.hasTestsForFeature('profile'), isTrue);
      expect(result.hasTestsForFeature('settings'), isFalse);
    });

    test(
        'an entirely empty project directory scans cleanly with no '
        'dart files and no pubspec', () async {
      final result = await ProjectScanner().scan(tempDir.path);

      expect(result.pubspecYaml, isNull);
      expect(result.dartFiles, isEmpty);
      expect(result.featureFolderNames, isEmpty);
    });
  });
}
