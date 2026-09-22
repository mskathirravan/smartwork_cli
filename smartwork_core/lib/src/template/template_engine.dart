import 'template.dart';

class TemplateEngine {
  String render(
    Template template,
    Map<String, String> variables,
  ) {
    var result = template.content;

    final placeholderRegex = RegExp(r'\{\{(\w+)\}\}');

    final usedVariables = <String>{};

    result = result.replaceAllMapped(placeholderRegex, (match) {
      final variableName = match.group(1)!;

      if (!variables.containsKey(variableName)) {
        throw MissingTemplateVariableException(
          variableName: variableName,
          availableVariables: variables.keys.toList(),
        );
      }

      usedVariables.add(variableName);
      return variables[variableName]!;
    });

    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    result = result.replaceAll(RegExp(r'\{\n\n+'), '{\n');

    return result;
  }
}

class MissingTemplateVariableException implements Exception {
  final String variableName;

  final List<String> availableVariables;

  MissingTemplateVariableException({
    required this.variableName,
    required this.availableVariables,
  });

  @override
  String toString() {
    final available =
        availableVariables.isEmpty ? 'none' : availableVariables.join(', ');
    return 'Missing template variable: {{$variableName}}. '
        'Available variables: $available';
  }
}
