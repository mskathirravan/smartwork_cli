import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('Template', () {
    test('stores template content', () {
      final content = 'class {{className}} {}';
      final template = Template(content: content);

      expect(template.content, equals(content));
      expect(template.raw, equals(content));
    });

    test('supports templates with no placeholders', () {
      final template = Template(content: 'class Home {}');

      expect(template.content, equals('class Home {}'));
    });

    test('supports templates with single placeholder', () {
      final template = Template(content: 'class {{className}} {}');

      expect(template.content, contains('{{className}}'));
    });

    test('supports templates with multiple placeholders', () {
      final template = Template(
        content: 'class {{className}} extends {{baseClass}} {}',
      );

      expect(template.content, contains('{{className}}'));
      expect(template.content, contains('{{baseClass}}'));
    });

    test('supports templates with repeated placeholders', () {
      final template = Template(
        content: '''
class {{className}} {
  final {{className}} instance;
  {{className}}.empty();
}
''',
      );

      expect(template.content, contains('{{className}}'));
    });
  });

  group('TemplateEngine', () {
    late TemplateEngine engine;

    setUp(() {
      engine = TemplateEngine();
    });

    test('renders template with single variable', () {
      final template = Template(content: 'class {{className}} {}');

      final result = engine.render(template, {
        'className': 'HomeBloc',
      });

      expect(result, equals('class HomeBloc {}'));
    });

    test('renders template with multiple variables', () {
      final template = Template(
        content: 'class {{className}} extends {{baseClass}} {}',
      );

      final result = engine.render(template, {
        'className': 'HomeBloc',
        'baseClass': 'Bloc',
      });

      expect(result, equals('class HomeBloc extends Bloc {}'));
    });

    test('replaces multiple occurrences of same variable', () {
      final template = Template(
        content: '''
class {{name}} {
  final {{name}} instance;
  const {{name}}.empty();
}
''',
      );

      final result = engine.render(template, {
        'name': 'HomeBloc',
      });

      expect(result, contains('class HomeBloc {'));
      expect(result, contains('final HomeBloc instance;'));
      expect(result, contains('const HomeBloc.empty();'));
    });

    test('renders template with no placeholders unchanged', () {
      final template = Template(content: 'class Home {}');

      final result = engine.render(template, {});

      expect(result, equals('class Home {}'));
    });

    test('ignores unused supplied variables', () {
      final template = Template(content: 'class {{className}} {}');

      final result = engine.render(template, {
        'className': 'HomeBloc',
        'unusedVar': 'unused',
        'anotherUnused': 'also unused',
      });

      expect(result, equals('class HomeBloc {}'));
    });

    test('throws exception for missing variable', () {
      final template = Template(content: 'class {{className}} {}');

      expect(
        () => engine.render(template, {}),
        throwsA(isA<MissingTemplateVariableException>()),
      );
    });

    test('exception contains helpful information about missing variable', () {
      final template = Template(content: 'class {{className}} {}');

      try {
        engine.render(template, {});
        fail('Expected MissingTemplateVariableException');
      } catch (e) {
        expect(e, isA<MissingTemplateVariableException>());
        final exception = e as MissingTemplateVariableException;
        expect(exception.variableName, equals('className'));
        expect(exception.toString(), contains('className'));
        expect(exception.toString(), contains('Missing template variable'));
      }
    });

    test('exception lists available variables', () {
      final template = Template(content: 'class {{className}} {}');

      try {
        engine.render(template, {
          'available1': 'value1',
          'available2': 'value2',
        });
        fail('Expected MissingTemplateVariableException');
      } catch (e) {
        final exception = e as MissingTemplateVariableException;
        expect(
          exception.toString(),
          contains('available1'),
        );
        expect(
          exception.toString(),
          contains('available2'),
        );
      }
    });

    test('handles placeholder with whitespace', () {
      final template = Template(content: 'class {{ className }} {}');

      // Note: Current implementation only matches {{word}}, not {{  word  }}
      // This test documents the current behavior
      final result = engine.render(template, {
        'className': 'HomeBloc',
      });

      // The template has spaces inside placeholders, which won't match
      expect(result, equals('class {{ className }} {}'));
    });

    test('renders multiline templates correctly', () {
      final template = Template(
        content: '''
class {{className}} {
  const {{className}}();

  void method() {
    print('{{className}}');
  }
}
''',
      );

      final result = engine.render(template, {
        'className': 'HomeBloc',
      });

      expect(result, contains('class HomeBloc {'));
      expect(result, contains('const HomeBloc();'));
      expect(result, contains("print('HomeBloc');"));
    });

    test('handles special characters in variable values', () {
      final template = Template(content: 'final message = "{{message}}";');

      final result = engine.render(template, {
        'message': r'Hello "world"',
      });

      expect(result, equals(r'final message = "Hello "world"";'));
    });

    test('variable names must be word characters only', () {
      final template = Template(content: '{{valid_name}} {{another_name}}');

      final result = engine.render(template, {
        'valid_name': 'value1',
        'another_name': 'value2',
      });

      expect(result, equals('value1 value2'));
    });

    test('does not replace non-placeholder braces', () {
      final template = Template(content: 'Map<String, String> {key: value}');

      final result = engine.render(template, {});

      expect(result, equals('Map<String, String> {key: value}'));
    });
  });
}
