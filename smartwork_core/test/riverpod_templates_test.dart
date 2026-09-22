import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('RiverpodTemplates', () {
    late TemplateEngine engine;

    setUp(() {
      engine = TemplateEngine();
    });

    group('state template', () {
      test('renders abstract state class with Initial subclass', () {
        final template = RiverpodTemplates.stateTemplate('home', 'Home');
        final rendered = engine.render(template, {});

        expect(rendered, contains('abstract class HomeState'));
        expect(rendered, contains('const HomeState();'));
        expect(rendered, contains('class HomeInitial extends HomeState'));
        expect(rendered, contains('const HomeInitial();'));
      });

      test('uses pascal case for class names', () {
        final template =
            RiverpodTemplates.stateTemplate('productDetail', 'ProductDetail');
        final rendered = engine.render(template, {});

        expect(rendered, contains('abstract class ProductDetailState'));
        expect(rendered,
            contains('class ProductDetailInitial extends ProductDetailState'));
      });
    });

    group('provider template - Clean Architecture', () {
      test('generates clean architecture provider', () {
        final template =
            RiverpodTemplates.providerTemplateClean('home', 'home', 'Home');
        final rendered = engine.render(template, {});

        expect(rendered, contains('import \'package:riverpod/legacy.dart\';'));
        expect(rendered, contains('import \'home_state.dart\';'));
        expect(rendered,
            contains('class HomeNotifier extends StateNotifier<HomeState>'));
        expect(
            rendered, contains('HomeNotifier() : super(const HomeInitial());'));
        expect(
            rendered, contains('final homeProvider = StateNotifierProvider'));
        expect(rendered, contains('return HomeNotifier();'));
      });

      test('renders without unresolved placeholders', () {
        final template = RiverpodTemplates.providerTemplateClean(
            'product', 'product', 'Product');
        final rendered = engine.render(template, {});

        expect(rendered, isNot(contains('{{')));
        expect(rendered, contains('class ProductNotifier'));
      });
    });

    group('provider template - MVVM', () {
      test('generates mvvm provider with ViewModel integration', () {
        final template =
            RiverpodTemplates.providerTemplateMvvm('home', 'home', 'Home');
        final rendered = engine.render(template, {});

        expect(
            rendered, contains('import \'package:riverpod/riverpod.dart\';'));
        expect(rendered, contains('import \'package:riverpod/legacy.dart\';'));
        expect(rendered,
            contains('import \'../viewmodels/home_view_model.dart\';'));
        expect(rendered, contains('import \'home_state.dart\';'));
        expect(rendered,
            contains('final homeViewModelProvider = Provider<HomeViewModel>'));
        expect(rendered, contains('return HomeViewModel();'));
        expect(rendered,
            contains('class HomeNotifier extends StateNotifier<HomeState>'));
        expect(rendered,
            contains('final homeStateProvider = StateNotifierProvider'));
        expect(rendered, contains('return HomeNotifier();'));
        // Must not instantiate the abstract StateNotifier directly —
        // that was a real compile error, independent of package version.
        expect(rendered, isNot(contains('StateNotifier(const HomeInitial())')));
      });

      test('references correct ViewModel path', () {
        final template = RiverpodTemplates.providerTemplateMvvm(
            'productDetail', 'product_detail', 'ProductDetail');
        final rendered = engine.render(template, {});

        expect(
            rendered,
            contains(
                'import \'../viewmodels/product_detail_view_model.dart\';'));
        expect(rendered, contains('ProductDetailViewModel'));
      });
    });

    group('provider template - MVP', () {
      test('generates mvp provider with Presenter integration', () {
        final template =
            RiverpodTemplates.providerTemplateMvp('home', 'home', 'Home');
        final rendered = engine.render(template, {});

        expect(
            rendered, contains('import \'package:riverpod/riverpod.dart\';'));
        expect(rendered, contains('import \'package:riverpod/legacy.dart\';'));
        expect(rendered,
            contains('import \'../presenters/home_presenter.dart\';'));
        expect(rendered, contains('import \'home_state.dart\';'));
        expect(rendered,
            contains('final homePresenterProvider = Provider<HomePresenter>'));
        expect(rendered, contains('return HomePresenter();'));
        expect(rendered,
            contains('class HomeNotifier extends StateNotifier<HomeState>'));
        expect(rendered,
            contains('final homeStateProvider = StateNotifierProvider'));
        expect(rendered, contains('return HomeNotifier();'));
        // Must not instantiate the abstract StateNotifier directly —
        // that was a real compile error, independent of package version.
        expect(rendered, isNot(contains('StateNotifier(const HomeInitial())')));
      });

      test('references correct Presenter path', () {
        final template = RiverpodTemplates.providerTemplateMvp(
            'userProfile', 'user_profile', 'UserProfile');
        final rendered = engine.render(template, {});

        expect(rendered,
            contains('import \'../presenters/user_profile_presenter.dart\';'));
        expect(rendered, contains('UserProfilePresenter'));
      });
    });

    group('provider declaration line-wrapping (V1.1 Core Final Audit)', () {
      // Regression: an entirely ordinary feature name ("profile", MVVM +
      // Riverpod) pushed the single-line `final ...StateProvider = ...`
      // declaration past 80 columns, and the template's fixed line
      // break didn't match dart_style's own wrap — a real,
      // reproducible `dart format --set-exit-if-changed` failure for
      // one of this repository's own canonical E2E combinations, not a
      // hypothetical edge case.
      test(
          'a feature name long enough to overflow 80 columns wraps '
          'exactly the way dart_style itself wraps a long assignment '
          '(break after =, indent the call, indent its body)', () {
        final template = RiverpodTemplates.providerTemplateMvvm(
            'profile', 'profile', 'Profile');
        final rendered = engine.render(template, {});

        expect(
          rendered,
          contains(
            'final profileStateProvider =\n'
            '    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {\n'
            '      return ProfileNotifier();\n'
            '    });',
          ),
        );
        // Never the naive single-line form once it would overflow.
        expect(
          rendered,
          isNot(contains(
            'final profileStateProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {',
          )),
        );
      });

      test(
          'a short feature name that already fits within 80 columns stays '
          'on a single line — the wrap only ever triggers on real '
          'overflow, never unconditionally', () {
        final template =
            RiverpodTemplates.providerTemplateMvvm('home', 'home', 'Home');
        final rendered = engine.render(template, {});

        expect(
          rendered,
          contains(
            'final homeStateProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {',
          ),
        );
      });

      test(
          'every line RiverpodTemplates generates for a realistic long '
          'feature name (Clean/MVVM/MVP alike) stays within the '
          '80-column limit dart format enforces', () {
        for (final featureName in ['profile', 'checkout', 'notifications']) {
          final pascal =
              featureName[0].toUpperCase() + featureName.substring(1);
          final templates = [
            RiverpodTemplates.providerTemplateClean(
                featureName, featureName, pascal),
            RiverpodTemplates.providerTemplateMvvm(
                featureName, featureName, pascal),
            RiverpodTemplates.providerTemplateMvp(
                featureName, featureName, pascal),
          ];

          for (final template in templates) {
            final rendered = engine.render(template, {});
            for (final line in rendered.split('\n')) {
              expect(line.length, lessThanOrEqualTo(80),
                  reason: 'feature "$featureName" produced an overlong '
                      'line: "$line"');
            }
          }
        }
      });
    });

    test('all templates render without unresolved placeholders', () {
      final stateTemplate = RiverpodTemplates.stateTemplate('home', 'Home');
      final cleanTemplate =
          RiverpodTemplates.providerTemplateClean('home', 'home', 'Home');
      final mvvmTemplate =
          RiverpodTemplates.providerTemplateMvvm('home', 'home', 'Home');
      final mvpTemplate =
          RiverpodTemplates.providerTemplateMvp('home', 'home', 'Home');

      final engine = TemplateEngine();
      final stateRendered = engine.render(stateTemplate, {});
      final cleanRendered = engine.render(cleanTemplate, {});
      final mvvmRendered = engine.render(mvvmTemplate, {});
      final mvpRendered = engine.render(mvpTemplate, {});

      expect(stateRendered, isNot(contains('{{')));
      expect(cleanRendered, isNot(contains('{{')));
      expect(mvvmRendered, isNot(contains('{{')));
      expect(mvpRendered, isNot(contains('{{')));
    });
  });
}
