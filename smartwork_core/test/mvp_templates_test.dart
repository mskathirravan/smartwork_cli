import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('MvpTemplates', () {
    test('top level directories are correct', () {
      final dirs = MvpTemplates.topLevelDirectories();
      expect(
        dirs,
        equals(['models', 'contracts', 'presenters', 'services', 'views']),
      );
    });

    test('views subdirectories contain widgets', () {
      final subdirs = MvpTemplates.viewsSubdirectories();
      expect(subdirs, equals(['widgets']));
    });

    test('allSubdirectories maps correctly', () {
      final all = MvpTemplates.allSubdirectories();
      expect(all.keys, contains('views'));
      expect(all['views'], equals(['widgets']));
    });

    test('allSubdirectories has no entries for layers without subdirs', () {
      final all = MvpTemplates.allSubdirectories();
      expect(all.containsKey('models'), isFalse);
      expect(all.containsKey('contracts'), isFalse);
      expect(all.containsKey('presenters'), isFalse);
      expect(all.containsKey('services'), isFalse);
    });

    test('MVP includes both Contracts and Presenters', () {
      final dirs = MvpTemplates.topLevelDirectories();
      expect(dirs, contains('contracts'));
      expect(dirs, contains('presenters'));
    });
  });

  group('MvpTemplates with TemplateEngine', () {
    late TemplateEngine engine;

    setUp(() {
      engine = TemplateEngine();
    });

    test('presenter template renders a meaningful, named Presenter class', () {
      final template = MvpTemplates.presenterTemplate();
      final rendered = engine.render(
        template,
        {'featureName': 'auth', 'pascalName': 'Auth'},
      );

      expect(rendered, contains('class AuthPresenter'));
      expect(rendered, contains('loadAuth()'));
      expect(rendered, isNot(contains('{{')));
    });

    test('presenter template has no required-arg constructor', () {
      // RiverpodTemplates.providerTemplateMvp already calls
      // {{pascalName}}Presenter() with zero arguments — the Presenter must
      // stay constructible that way.
      final template = MvpTemplates.presenterTemplate();
      final rendered = engine.render(
        template,
        {'featureName': 'auth', 'pascalName': 'Auth'},
      );

      expect(rendered, isNot(contains('AuthPresenter(')));
    });

    test('presenter naming follows PascalCase feature name', () {
      final template = MvpTemplates.presenterTemplate();
      final rendered = engine.render(
        template,
        {'featureName': 'user_profile', 'pascalName': 'UserProfile'},
      );

      expect(rendered, contains('class UserProfilePresenter'));
      expect(rendered, contains('loadUserProfile()'));
    });
  });
}
