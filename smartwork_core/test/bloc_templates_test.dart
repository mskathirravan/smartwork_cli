import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('BlocTemplates', () {
    late TemplateEngine engine;

    setUp(() {
      engine = TemplateEngine();
    });

    Map<String, String> varsFor(String featureName, String pascalName) => {
          'featureName': featureName,
          'pascalName': pascalName,
        };

    test('event template renders a meaningful event skeleton', () {
      final template = BlocTemplates.eventTemplate('home', 'Home');
      final rendered = engine.render(template, varsFor('home', 'Home'));

      expect(rendered, contains('abstract class HomeEvent'));
      expect(rendered, contains('class HomeRequested extends HomeEvent'));
    });

    test('state template renders a meaningful state skeleton', () {
      final template = BlocTemplates.stateTemplate('home', 'Home');
      final rendered = engine.render(template, varsFor('home', 'Home'));

      expect(rendered, contains('abstract class HomeState'));
      expect(rendered, contains('class HomeInitial extends HomeState'));
      expect(rendered, contains('class HomeLoading extends HomeState'));
      expect(rendered, contains('class HomeLoaded extends HomeState'));
      expect(rendered, contains('class HomeError extends HomeState'));
    });

    test('bloc template renders a meaningful BLoC skeleton', () {
      final template = BlocTemplates.blocTemplate('home', 'Home');
      final rendered = engine.render(template, varsFor('home', 'Home'));

      expect(rendered,
          contains("import 'package:flutter_bloc/flutter_bloc.dart';"));
      expect(rendered,
          contains('class HomeBloc extends Bloc<HomeEvent, HomeState>'));
      expect(rendered, contains('HomeBloc() : super(const HomeInitial())'));
      expect(rendered, contains('on<HomeRequested>(_onHomeRequested);'));
      expect(rendered, contains('emit(const HomeLoading());'));
      expect(rendered, contains('emit(const HomeLoaded());'));
    });

    test(
        'a long feature name wraps the class declaration onto two lines, '
        'matching dart format\'s own 80-column output — regression for a '
        'real "smartwork init" Format validation failure with feature '
        'names like "authentication"/"product_catalog"', () {
      final template =
          BlocTemplates.blocTemplate('authentication', 'Authentication');
      final rendered =
          engine.render(template, varsFor('authentication', 'Authentication'));

      expect(
        rendered,
        contains('class AuthenticationBloc\n'
            '    extends Bloc<AuthenticationEvent, AuthenticationState> {'),
      );
      for (final line in rendered.split('\n')) {
        expect(line.length, lessThanOrEqualTo(80),
            reason: 'line exceeds dart format\'s 80-column limit: "$line"');
      }
    });

    test('a short feature name keeps the class declaration on one line', () {
      final template = BlocTemplates.blocTemplate('home', 'Home');
      final rendered = engine.render(template, varsFor('home', 'Home'));

      expect(rendered,
          contains('class HomeBloc extends Bloc<HomeEvent, HomeState> {'));
      expect(rendered, isNot(contains('class HomeBloc\n')));
    });

    test('templates render without unresolved placeholders', () {
      final eventTemplate = BlocTemplates.eventTemplate('home', 'Home');
      final stateTemplate = BlocTemplates.stateTemplate('home', 'Home');
      final blocTemplate = BlocTemplates.blocTemplate('home', 'Home');
      final vars = varsFor('home', 'Home');

      expect(engine.render(eventTemplate, vars), isNot(contains('{{')));
      expect(engine.render(stateTemplate, vars), isNot(contains('{{')));
      expect(engine.render(blocTemplate, vars), isNot(contains('{{')));
    });

    test('feature-name substitution renders correctly for a different name',
        () {
      final template = BlocTemplates.blocTemplate('product', 'Product');
      final rendered = engine.render(template, varsFor('product', 'Product'));

      expect(
          rendered,
          contains(
              'class ProductBloc extends Bloc<ProductEvent, ProductState>'));
      expect(rendered, contains('on<ProductRequested>(_onProductRequested);'));
    });
  });
}
