import '../template.dart';

class RiverpodTemplates {
  static String _providerDeclaration({
    required String variableName,
    required String expression,
    required String bodyExpression,
  }) {
    final singleLine = 'final $variableName = $expression((ref) {';
    if (singleLine.length <= 80) {
      return '''$singleLine
  return $bodyExpression;
});''';
    }
    return '''final $variableName =
    $expression((ref) {
      return $bodyExpression;
    });''';
  }

  static Template stateTemplate(String featureName, String pascalName) {
    return Template(
      content: '''abstract class ${pascalName}State {
  const ${pascalName}State();
}

class ${pascalName}Initial extends ${pascalName}State {
  const ${pascalName}Initial();
}
''',
    );
  }

  static Template providerTemplateClean(
    String featureName,
    String snakeName,
    String pascalName,
  ) {
    return Template(
      content: '''import 'package:riverpod/legacy.dart';

import '${snakeName}_state.dart';

class ${pascalName}Notifier extends StateNotifier<${pascalName}State> {
  ${pascalName}Notifier() : super(const ${pascalName}Initial());
}

${_providerDeclaration(
        variableName: '${snakeName}Provider',
        expression:
            'StateNotifierProvider<${pascalName}Notifier, ${pascalName}State>',
        bodyExpression: '${pascalName}Notifier()',
      )}
''',
    );
  }

  static Template providerTemplateMvvm(
    String featureName,
    String snakeName,
    String pascalName,
  ) {
    return Template(
      content: '''import 'package:riverpod/riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../viewmodels/${snakeName}_view_model.dart';
import '${snakeName}_state.dart';

${_providerDeclaration(
        variableName: '${snakeName}ViewModelProvider',
        expression: 'Provider<${pascalName}ViewModel>',
        bodyExpression: '${pascalName}ViewModel()',
      )}

class ${pascalName}Notifier extends StateNotifier<${pascalName}State> {
  ${pascalName}Notifier() : super(const ${pascalName}Initial());
}

${_providerDeclaration(
        variableName: '${snakeName}StateProvider',
        expression:
            'StateNotifierProvider<${pascalName}Notifier, ${pascalName}State>',
        bodyExpression: '${pascalName}Notifier()',
      )}
''',
    );
  }

  static Template providerTemplateMvp(
    String featureName,
    String snakeName,
    String pascalName,
  ) {
    return Template(
      content: '''import 'package:riverpod/riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../presenters/${snakeName}_presenter.dart';
import '${snakeName}_state.dart';

${_providerDeclaration(
        variableName: '${snakeName}PresenterProvider',
        expression: 'Provider<${pascalName}Presenter>',
        bodyExpression: '${pascalName}Presenter()',
      )}

class ${pascalName}Notifier extends StateNotifier<${pascalName}State> {
  ${pascalName}Notifier() : super(const ${pascalName}Initial());
}

${_providerDeclaration(
        variableName: '${snakeName}StateProvider',
        expression:
            'StateNotifierProvider<${pascalName}Notifier, ${pascalName}State>',
        bodyExpression: '${pascalName}Notifier()',
      )}
''',
    );
  }
}
