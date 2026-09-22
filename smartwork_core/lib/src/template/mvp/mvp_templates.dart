import '../template.dart';

class MvpTemplates {
  static List<String> topLevelDirectories() {
    return ['models', 'contracts', 'presenters', 'services', 'views'];
  }

  static List<String> viewsSubdirectories() {
    return ['widgets'];
  }

  static Map<String, List<String>> allSubdirectories() {
    return {
      'views': viewsSubdirectories(),
    };
  }

  static Template modelTemplate() {
    return Template(content: '''class {{pascalName}}Model {
  const {{pascalName}}Model();
}
''');
  }

  static Template serviceTemplate() {
    return Template(
        content: '''import '../../../services/network/network_service.dart';
import '../models/{{featureName}}_model.dart';

class {{pascalName}}Service {
  const {{pascalName}}Service();

  Future<{{pascalName}}Model> get{{pascalName}}() async {
    await NetworkService.instance.get('/{{featureName}}');
    return const {{pascalName}}Model();
  }
}
''');
  }

  static Template localServiceTemplate() {
    return Template(
        content: '''import '../../../services/storage/storage_service.dart';
import '../models/{{featureName}}_model.dart';

class {{pascalName}}LocalService {
  const {{pascalName}}LocalService();

  Future<{{pascalName}}Model> get{{pascalName}}() async {
    await StorageService.instance.getString('{{featureName}}');
    return const {{pascalName}}Model();
  }
}
''');
  }

  static Template pageTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

class {{pascalName}}Page extends StatelessWidget {
  const {{pascalName}}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('{{pascalName}}')));
  }
}
''');
  }

  static Template presenterTemplate() {
    return Template(content: '''class {{pascalName}}Presenter {
  bool isLoading = false;

  Future<void> load{{pascalName}}() async {
    isLoading = true;
    // TODO: implement {{featureName}} logic
    isLoading = false;
  }
}
''');
  }

  static Template widgetTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

class {{pascalName}}Widget extends StatelessWidget {
  const {{pascalName}}Widget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
''');
  }

  static Template pageTestTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/features/{{featureName}}/views/{{featureName}}_page.dart';

void main() {
  testWidgets('{{pascalName}}Page builds without error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: {{pascalName}}Page()));

    expect(find.byType({{pascalName}}Page), findsOneWidget);
  });
}
''');
  }
}
