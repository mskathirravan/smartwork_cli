import '../template.dart';

class CubitTemplates {
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

  static Template cubitTemplate(String featureName, String pascalName) {
    return Template(content: '''import 'package:flutter_bloc/flutter_bloc.dart';

import '{{featureName}}_state.dart';

class {{pascalName}}Cubit extends Cubit<{{pascalName}}State> {
  {{pascalName}}Cubit() : super(const {{pascalName}}Initial());

  Future<void> load{{pascalName}}() async {
    emit(const {{pascalName}}Loading());
    // TODO: implement {{featureName}} logic
    emit(const {{pascalName}}Loaded());
  }
}
''');
  }
}
