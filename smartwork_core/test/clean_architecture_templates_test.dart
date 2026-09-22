import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('CleanArchitectureTemplates', () {
    test('domain subdirectories are correct', () {
      final subdirs = CleanArchitectureTemplates.domainSubdirectories();
      expect(subdirs, equals(['entities', 'repositories', 'usecases']));
    });

    test('data subdirectories are correct', () {
      final subdirs = CleanArchitectureTemplates.dataSubdirectories();
      expect(subdirs, equals(['datasources', 'models', 'repositories']));
    });

    test('presentation subdirectories are correct', () {
      final subdirs = CleanArchitectureTemplates.presentationSubdirectories();
      expect(subdirs, equals(['pages', 'widgets']));
    });

    test('top level directories are correct', () {
      final dirs = CleanArchitectureTemplates.topLevelDirectories();
      expect(dirs, equals(['domain', 'data', 'presentation']));
    });

    test('allSubdirectories contains all layers', () {
      final all = CleanArchitectureTemplates.allSubdirectories();
      expect(all.keys, contains('domain'));
      expect(all.keys, contains('data'));
      expect(all.keys, contains('presentation'));
    });

    test('allSubdirectories maps correctly', () {
      final all = CleanArchitectureTemplates.allSubdirectories();
      expect(
        all['domain'],
        equals(['entities', 'repositories', 'usecases']),
      );
      expect(
        all['data'],
        equals(['datasources', 'models', 'repositories']),
      );
      expect(
        all['presentation'],
        equals(['pages', 'widgets']),
      );
    });
  });
}
