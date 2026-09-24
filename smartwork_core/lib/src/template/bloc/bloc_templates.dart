import '../template.dart';

class BlocTemplates {
  static Template eventTemplate(String featureName, String pascalName) {
    return Template(content: '''abstract class {{pascalName}}Event {
  const {{pascalName}}Event();
}

class {{pascalName}}Requested extends {{pascalName}}Event {
  const {{pascalName}}Requested();
}
''');
  }

  static Template stateTemplate(String featureName, String pascalName) {
    return Template(content: '''abstract class {{pascalName}}State {
  const {{pascalName}}State();
}

class {{pascalName}}Initial extends {{pascalName}}State {
  const {{pascalName}}Initial();
}

class {{pascalName}}Loading extends {{pascalName}}State {
  const {{pascalName}}Loading();
}

class {{pascalName}}Loaded extends {{pascalName}}State {
  const {{pascalName}}Loaded();
}

class {{pascalName}}Error extends {{pascalName}}State {
  const {{pascalName}}Error();
}
''');
  }

  static Template blocTemplate(String featureName, String pascalName) {
    // A long feature name (e.g. "product_catalog" -> ProductCatalog) can
    // push this declaration past dart format's 80-column limit, in which
    // case it wraps the extends clause onto its own line — computed here,
    // from the real resolved name, because {{pascalName}} substitution
    // happens later and can't make that formatting decision itself.
    final oneLineDeclaration =
        'class ${pascalName}Bloc extends Bloc<${pascalName}Event, ${pascalName}State> {';
    final classDeclaration = oneLineDeclaration.length <= 80
        ? oneLineDeclaration
        : 'class ${pascalName}Bloc\n'
            '    extends Bloc<${pascalName}Event, ${pascalName}State> {';

    return Template(content: '''import 'package:flutter_bloc/flutter_bloc.dart';

import '{{featureName}}_event.dart';
import '{{featureName}}_state.dart';

$classDeclaration
  {{pascalName}}Bloc() : super(const {{pascalName}}Initial()) {
    on<{{pascalName}}Requested>(_on{{pascalName}}Requested);
  }

  Future<void> _on{{pascalName}}Requested(
    {{pascalName}}Requested event,
    Emitter<{{pascalName}}State> emit,
  ) async {
    emit(const {{pascalName}}Loading());
    // TODO: implement {{featureName}} logic
    emit(const {{pascalName}}Loaded());
  }
}
''');
  }
}
