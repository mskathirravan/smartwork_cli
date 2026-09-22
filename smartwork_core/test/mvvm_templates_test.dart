import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('MvvmTemplates', () {
    test('top level directories are correct', () {
      final dirs = MvvmTemplates.topLevelDirectories();
      expect(dirs, equals(['models', 'viewmodels', 'services', 'views']));
    });

    test('views subdirectories contain widgets', () {
      final subdirs = MvvmTemplates.viewsSubdirectories();
      expect(subdirs, equals(['widgets']));
    });

    test('allSubdirectories maps correctly', () {
      final all = MvvmTemplates.allSubdirectories();
      expect(all.keys, contains('views'));
      expect(all['views'], equals(['widgets']));
    });

    test('allSubdirectories has no entries for layers without subdirs', () {
      final all = MvvmTemplates.allSubdirectories();
      expect(all.containsKey('models'), isFalse);
      expect(all.containsKey('viewmodels'), isFalse);
      expect(all.containsKey('services'), isFalse);
    });
  });

  group('MvvmTemplates with TemplateEngine', () {
    late TemplateEngine engine;

    setUp(() {
      engine = TemplateEngine();
    });

    test('viewModel template renders a meaningful, named ViewModel class', () {
      final template = MvvmTemplates.viewModelTemplate();
      final rendered = engine.render(
        template,
        {'featureName': 'auth', 'pascalName': 'Auth'},
      );

      expect(rendered, contains('class AuthViewModel'));
      expect(rendered, contains('loadAuth()'));
      expect(rendered, isNot(contains('{{')));
    });

    test('viewModel template has no required-arg constructor', () {
      // RiverpodTemplates.providerTemplateMvvm already calls
      // {{pascalName}}ViewModel() with zero arguments — the ViewModel must
      // stay constructible that way.
      final template = MvvmTemplates.viewModelTemplate();
      final rendered = engine.render(
        template,
        {'featureName': 'auth', 'pascalName': 'Auth'},
      );

      expect(rendered, isNot(contains('AuthViewModel(')));
    });

    test('viewModel naming follows PascalCase feature name', () {
      final template = MvvmTemplates.viewModelTemplate();
      final rendered = engine.render(
        template,
        {'featureName': 'user_profile', 'pascalName': 'UserProfile'},
      );

      expect(rendered, contains('class UserProfileViewModel'));
      expect(rendered, contains('loadUserProfile()'));
    });
  });
}
