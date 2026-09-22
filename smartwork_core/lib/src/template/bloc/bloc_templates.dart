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
    return Template(content: '''import 'package:flutter_bloc/flutter_bloc.dart';

import '{{featureName}}_event.dart';
import '{{featureName}}_state.dart';

class {{pascalName}}Bloc extends Bloc<{{pascalName}}Event, {{pascalName}}State> {
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
