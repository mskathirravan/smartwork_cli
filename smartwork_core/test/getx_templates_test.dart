import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('GetxTemplates', () {
    late TemplateEngine engine;

    setUp(() {
      engine = TemplateEngine();
    });

    Map<String, String> varsFor(String featureName, String pascalName) => {
          'featureName': featureName,
          'pascalName': pascalName,
        };

    test('controller template renders a meaningful controller skeleton', () {
      final template = GetxTemplates.controllerTemplate('home', 'Home');
      final rendered = engine.render(template, varsFor('home', 'Home'));

      expect(rendered, contains("import 'package:get/get.dart';"));
      expect(rendered, contains('class HomeController extends GetxController'));
      expect(rendered, contains('loadHome()'));
    });

    test('feature-name substitution renders correctly for a different name',
        () {
      final template = GetxTemplates.controllerTemplate('product', 'Product');
      final rendered = engine.render(template, varsFor('product', 'Product'));

      expect(
          rendered, contains('class ProductController extends GetxController'));
      expect(rendered, contains('loadProduct()'));
    });

    test('renders without unresolved placeholders', () {
      final template =
          GetxTemplates.controllerTemplate('userProfile', 'UserProfile');
      final rendered =
          engine.render(template, varsFor('userProfile', 'UserProfile'));

      expect(rendered, isNot(contains('{{')));
    });
  });
}
