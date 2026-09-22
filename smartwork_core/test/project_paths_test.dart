import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectPaths', () {
    const projectRoot = '/path/to/project';
    late ProjectPaths paths;

    setUp(() {
      paths = ProjectPaths(projectRoot: projectRoot);
    });

    test('projectRoot returns the root path', () {
      expect(paths.projectRoot, equals(projectRoot));
    });

    test('lib returns lib directory path', () {
      final expected = path.join(projectRoot, 'lib');
      expect(paths.lib, equals(expected));
    });

    test('test returns test directory path', () {
      final expected = path.join(projectRoot, 'test');
      expect(paths.test, equals(expected));
    });

    test('readmeFile returns README.md path', () {
      final expected = path.join(projectRoot, 'README.md');
      expect(paths.readmeFile, equals(expected));
    });

    test('smartworkDir returns .smartwork directory path', () {
      final expected = path.join(projectRoot, '.smartwork');
      expect(paths.smartworkDir, equals(expected));
    });

    test('projectConfigFile returns .smartwork/project.yaml path', () {
      final expected = path.join(projectRoot, '.smartwork', 'project.yaml');
      expect(paths.projectConfigFile, equals(expected));
    });

    test('features returns lib/features path', () {
      final expected = path.join(projectRoot, 'lib', 'features');
      expect(paths.features, equals(expected));
    });

    test('featurePath returns lib/features/{featureName} path', () {
      final expected = path.join(projectRoot, 'lib', 'features', 'home');
      expect(paths.featurePath('home'), equals(expected));
    });

    test('featurePath supports multiple feature names', () {
      final home = paths.featurePath('home');
      final profile = paths.featurePath('profile');
      final settings = paths.featurePath('settings');

      expect(home, contains('home'));
      expect(profile, contains('profile'));
      expect(settings, contains('settings'));
      expect(home, isNot(equals(profile)));
      expect(profile, isNot(equals(settings)));
    });

    test('featureFile returns lib/features/{featureName}/{filePath}', () {
      final expected = path.join(
          projectRoot, 'lib', 'features', 'home', 'models', 'user.dart');
      expect(paths.featureFile('home', path.join('models', 'user.dart')),
          equals(expected));
    });

    test('featureFile constructs nested paths correctly', () {
      final deepPath = paths.featureFile(
          'home', path.join('lib', 'domain', 'entities', 'entity.dart'));
      expect(deepPath,
          contains('lib/features/home/lib/domain/entities/entity.dart'));
    });

    test('all paths are relative to projectRoot', () {
      expect(paths.lib, startsWith(projectRoot));
      expect(paths.test, startsWith(projectRoot));
      expect(paths.readmeFile, startsWith(projectRoot));
      expect(paths.smartworkDir, startsWith(projectRoot));
      expect(paths.projectConfigFile, startsWith(projectRoot));
      expect(paths.features, startsWith(projectRoot));
      expect(paths.featurePath('home'), startsWith(projectRoot));
    });

    test('projectRoot can be any path', () {
      final paths2 = ProjectPaths(projectRoot: '/another/location');
      expect(paths2.projectRoot, equals('/another/location'));
      expect(paths2.lib, startsWith('/another/location'));
    });
  });
}
