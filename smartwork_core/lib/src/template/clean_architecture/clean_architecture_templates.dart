import '../template.dart';

class CleanArchitectureTemplates {
  static List<String> domainSubdirectories() {
    return ['entities', 'repositories', 'usecases'];
  }

  static List<String> dataSubdirectories() {
    return ['datasources', 'models', 'repositories'];
  }

  static List<String> presentationSubdirectories() {
    return ['pages', 'widgets'];
  }

  static List<String> topLevelDirectories() {
    return ['domain', 'data', 'presentation'];
  }

  static Map<String, List<String>> allSubdirectories() {
    return {
      'domain': domainSubdirectories(),
      'data': dataSubdirectories(),
      'presentation': presentationSubdirectories(),
    };
  }

  static Template entityTemplate() {
    return Template(content: '''class {{pascalName}} {
  const {{pascalName}}();
}
''');
  }

  static Template repositoryContractTemplate() {
    return Template(content: '''import '../entities/{{featureName}}.dart';

abstract class {{pascalName}}Repository {
  Future<{{pascalName}}> get{{pascalName}}();
}
''');
  }

  static Template useCaseTemplate() {
    return Template(content: '''import '../entities/{{featureName}}.dart';
import '../repositories/{{featureName}}_repository.dart';

class Get{{pascalName}}UseCase {
  final {{pascalName}}Repository repository;

  const Get{{pascalName}}UseCase(this.repository);

  Future<{{pascalName}}> call() {
    return repository.get{{pascalName}}();
  }
}
''');
  }

  static Template modelTemplate() {
    return Template(
        content: '''import '../../domain/entities/{{featureName}}.dart';

class {{pascalName}}Model extends {{pascalName}} {
  const {{pascalName}}Model();
}
''');
  }

  static Template dataSourceTemplate() {
    return Template(content: '''import '../models/{{featureName}}_model.dart';

abstract class {{pascalName}}DataSource {
  Future<{{pascalName}}Model> get{{pascalName}}();
}
''');
  }

  static Template repositoryImplTemplate() {
    return Template(
        content: '''import '../../domain/entities/{{featureName}}.dart';
import '../../domain/repositories/{{featureName}}_repository.dart';
import '../datasources/{{featureName}}_data_source.dart';

class {{pascalName}}RepositoryImpl implements {{pascalName}}Repository {
  final {{pascalName}}DataSource dataSource;

  const {{pascalName}}RepositoryImpl(this.dataSource);

  @override
  Future<{{pascalName}}> get{{pascalName}}() {
    return dataSource.get{{pascalName}}();
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

import 'package:{{projectName}}/features/{{featureName}}/presentation/pages/{{featureName}}_page.dart';

void main() {
  testWidgets('{{pascalName}}Page builds without error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: {{pascalName}}Page()));

    expect(find.byType({{pascalName}}Page), findsOneWidget);
  });
}
''');
  }

  static Template networkDataSourceTemplate() {
    return Template(
        content: '''import '../../../../services/network/network_service.dart';
import '../models/{{featureName}}_model.dart';
import '{{featureName}}_data_source.dart';

class {{pascalName}}NetworkDataSource implements {{pascalName}}DataSource {
  const {{pascalName}}NetworkDataSource();

  @override
  Future<{{pascalName}}Model> get{{pascalName}}() async {
    await NetworkService.instance.get('/{{featureName}}');
    return const {{pascalName}}Model();
  }
}
''');
  }

  static Template localDataSourceTemplate() {
    return Template(
        content: '''import '../../../../services/storage/storage_service.dart';
import '../models/{{featureName}}_model.dart';
import '{{featureName}}_data_source.dart';

class {{pascalName}}LocalDataSource implements {{pascalName}}DataSource {
  const {{pascalName}}LocalDataSource();

  @override
  Future<{{pascalName}}Model> get{{pascalName}}() async {
    await StorageService.instance.getString('{{featureName}}');
    return const {{pascalName}}Model();
  }
}
''');
  }
}
