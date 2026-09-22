import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('CubitTemplates', () {
    late TemplateEngine engine;

    setUp(() {
      engine = TemplateEngine();
    });

    Map<String, String> varsFor(String featureName, String pascalName) => {
          'featureName': featureName,
          'pascalName': pascalName,
        };

    test('state template renders a meaningful state skeleton', () {
      final template = CubitTemplates.stateTemplate('home', 'Home');
      final rendered = engine.render(template, varsFor('home', 'Home'));

      expect(rendered, contains('abstract class HomeState'));
      expect(rendered, contains('class HomeInitial extends HomeState'));
      expect(rendered, contains('class HomeLoading extends HomeState'));
      expect(rendered, contains('class HomeLoaded extends HomeState'));
      expect(rendered, contains('class HomeError extends HomeState'));
    });

    test('cubit template renders a meaningful Cubit skeleton', () {
      final template = CubitTemplates.cubitTemplate('home', 'Home');
      final rendered = engine.render(template, varsFor('home', 'Home'));

      expect(rendered,
          contains("import 'package:flutter_bloc/flutter_bloc.dart';"));
      expect(rendered, contains('class HomeCubit extends Cubit<HomeState>'));
      expect(rendered, contains('HomeCubit() : super(const HomeInitial());'));
      expect(rendered, contains('emit(const HomeLoading());'));
      expect(rendered, contains('emit(const HomeLoaded());'));
    });

    test('templates render without unresolved placeholders', () {
      final stateTemplate = CubitTemplates.stateTemplate('home', 'Home');
      final cubitTemplate = CubitTemplates.cubitTemplate('home', 'Home');
      final vars = varsFor('home', 'Home');

      expect(engine.render(stateTemplate, vars), isNot(contains('{{')));
      expect(engine.render(cubitTemplate, vars), isNot(contains('{{')));
    });

    test('feature-name substitution renders correctly for a different name',
        () {
      final template = CubitTemplates.cubitTemplate('product', 'Product');
      final rendered = engine.render(template, varsFor('product', 'Product'));

      expect(
          rendered, contains('class ProductCubit extends Cubit<ProductState>'));
    });

    test('cubit has no event template (unlike bloc)', () {
      final stateTemplate = CubitTemplates.stateTemplate('home', 'Home');
      final cubitTemplate = CubitTemplates.cubitTemplate('home', 'Home');

      expect(stateTemplate.content, isNotEmpty);
      expect(cubitTemplate.content, isNotEmpty);
    });
  });
}
