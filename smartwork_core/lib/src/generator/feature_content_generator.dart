import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';

class FeatureContentGenerator {
  late final TemplateEngine _templateEngine = TemplateEngine();

  Future<void> generate(
    FeatureConfig feature,
    Architecture architecture,
    ProjectPaths paths,
    FileWriter fileWriter, {
    required String projectName,
  }) async {
    final resolvedFeature = feature.resolveDependencies();
    switch (architecture) {
      case Architecture.cleanArchitecture:
        await _generateClean(resolvedFeature, paths, fileWriter, projectName);
      case Architecture.mvvm:
        await _generateMvvm(resolvedFeature, paths, fileWriter, projectName);
      case Architecture.mvp:
        await _generateMvp(resolvedFeature, paths, fileWriter, projectName);
    }
  }

  Future<void> _generateClean(
    FeatureConfig feature,
    ProjectPaths paths,
    FileWriter fileWriter,
    String projectName,
  ) async {
    final components = feature.components;
    final vars = _variablesFor(feature, projectName);
    final featurePath = paths.featurePath(feature.name);
    final exports = <String>[];

    if (components.contains(FeatureComponent.entity)) {
      await _write(
          fileWriter,
          featurePath,
          'domain/entities/${vars['featureName']}.dart',
          CleanArchitectureTemplates.entityTemplate(),
          vars);
      await _write(
          fileWriter,
          featurePath,
          'data/models/${vars['featureName']}_model.dart',
          CleanArchitectureTemplates.modelTemplate(),
          vars);
      exports.add('domain/entities/${vars['featureName']}.dart');
      exports.add('data/models/${vars['featureName']}_model.dart');
    }
    if (components.contains(FeatureComponent.repository)) {
      await _write(
          fileWriter,
          featurePath,
          'domain/repositories/${vars['featureName']}_repository.dart',
          CleanArchitectureTemplates.repositoryContractTemplate(),
          vars);
      await _write(
          fileWriter,
          featurePath,
          'data/repositories/${vars['featureName']}_repository_impl.dart',
          CleanArchitectureTemplates.repositoryImplTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.useCase)) {
      await _write(
          fileWriter,
          featurePath,
          'domain/usecases/${vars['featureName']}_usecase.dart',
          CleanArchitectureTemplates.useCaseTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.dataSource)) {
      await _write(
          fileWriter,
          featurePath,
          'data/datasources/${vars['featureName']}_data_source.dart',
          CleanArchitectureTemplates.dataSourceTemplate(),
          vars);
      await _write(
          fileWriter,
          featurePath,
          'data/datasources/${vars['featureName']}_network_data_source.dart',
          CleanArchitectureTemplates.networkDataSourceTemplate(),
          vars);
      await _write(
          fileWriter,
          featurePath,
          'data/datasources/${vars['featureName']}_local_data_source.dart',
          CleanArchitectureTemplates.localDataSourceTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.page)) {
      await _write(
          fileWriter,
          featurePath,
          'presentation/pages/${vars['featureName']}_page.dart',
          CleanArchitectureTemplates.pageTemplate(),
          vars);
      exports.add('presentation/pages/${vars['featureName']}_page.dart');
    }
    if (components.contains(FeatureComponent.widgets)) {
      await _write(
          fileWriter,
          featurePath,
          'presentation/widgets/${vars['featureName']}_widget.dart',
          CleanArchitectureTemplates.widgetTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.tests)) {
      await _writeTest(
          fileWriter,
          paths,
          feature.name,
          '${vars['featureName']}_page_test.dart',
          CleanArchitectureTemplates.pageTestTemplate(),
          vars);
    }

    await _writeFeatureExport(fileWriter, featurePath, vars, exports);
  }

  Future<void> _generateMvvm(
    FeatureConfig feature,
    ProjectPaths paths,
    FileWriter fileWriter,
    String projectName,
  ) async {
    final components = feature.components;
    final vars = _variablesFor(feature, projectName);
    final featurePath = paths.featurePath(feature.name);
    final exports = <String>[];

    if (components.contains(FeatureComponent.entity)) {
      await _write(
          fileWriter,
          featurePath,
          'models/${vars['featureName']}_model.dart',
          MvvmTemplates.modelTemplate(),
          vars);
      exports.add('models/${vars['featureName']}_model.dart');
    }
    if (components.contains(FeatureComponent.repository) ||
        components.contains(FeatureComponent.dataSource) ||
        components.contains(FeatureComponent.useCase)) {
      await _write(
          fileWriter,
          featurePath,
          'services/${vars['featureName']}_service.dart',
          MvvmTemplates.serviceTemplate(),
          vars);
      await _write(
          fileWriter,
          featurePath,
          'services/${vars['featureName']}_local_service.dart',
          MvvmTemplates.localServiceTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.page)) {
      await _write(
          fileWriter,
          featurePath,
          'views/${vars['featureName']}_page.dart',
          MvvmTemplates.pageTemplate(),
          vars);
      exports.add('views/${vars['featureName']}_page.dart');
    }
    if (components.contains(FeatureComponent.widgets)) {
      await _write(
          fileWriter,
          featurePath,
          'views/widgets/${vars['featureName']}_widget.dart',
          MvvmTemplates.widgetTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.tests)) {
      await _writeTest(
          fileWriter,
          paths,
          feature.name,
          '${vars['featureName']}_page_test.dart',
          MvvmTemplates.pageTestTemplate(),
          vars);
    }
    await _write(
        fileWriter,
        featurePath,
        'viewmodels/${vars['featureName']}_view_model.dart',
        MvvmTemplates.viewModelTemplate(),
        vars);

    await _writeFeatureExport(fileWriter, featurePath, vars, exports);
  }

  Future<void> _generateMvp(
    FeatureConfig feature,
    ProjectPaths paths,
    FileWriter fileWriter,
    String projectName,
  ) async {
    final components = feature.components;
    final vars = _variablesFor(feature, projectName);
    final featurePath = paths.featurePath(feature.name);
    final exports = <String>[];

    if (components.contains(FeatureComponent.entity)) {
      await _write(
          fileWriter,
          featurePath,
          'models/${vars['featureName']}_model.dart',
          MvpTemplates.modelTemplate(),
          vars);
      exports.add('models/${vars['featureName']}_model.dart');
    }
    if (components.contains(FeatureComponent.repository) ||
        components.contains(FeatureComponent.dataSource) ||
        components.contains(FeatureComponent.useCase)) {
      await _write(
          fileWriter,
          featurePath,
          'services/${vars['featureName']}_service.dart',
          MvpTemplates.serviceTemplate(),
          vars);
      await _write(
          fileWriter,
          featurePath,
          'services/${vars['featureName']}_local_service.dart',
          MvpTemplates.localServiceTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.page)) {
      await _write(
          fileWriter,
          featurePath,
          'views/${vars['featureName']}_page.dart',
          MvpTemplates.pageTemplate(),
          vars);
      exports.add('views/${vars['featureName']}_page.dart');
    }
    if (components.contains(FeatureComponent.widgets)) {
      await _write(
          fileWriter,
          featurePath,
          'views/widgets/${vars['featureName']}_widget.dart',
          MvpTemplates.widgetTemplate(),
          vars);
    }
    if (components.contains(FeatureComponent.tests)) {
      await _writeTest(
          fileWriter,
          paths,
          feature.name,
          '${vars['featureName']}_page_test.dart',
          MvpTemplates.pageTestTemplate(),
          vars);
    }
    await _write(
        fileWriter,
        featurePath,
        'presenters/${vars['featureName']}_presenter.dart',
        MvpTemplates.presenterTemplate(),
        vars);

    await _writeFeatureExport(fileWriter, featurePath, vars, exports);
  }

  Map<String, String> _variablesFor(FeatureConfig feature, String projectName) {
    final names = FeatureNames(feature.name);
    return {
      'featureName': names.snake,
      'pascalName': names.pascal,
      'projectName': projectName,
    };
  }

  Future<void> _write(
    FileWriter fileWriter,
    String featurePath,
    String relativePath,
    Template template,
    Map<String, String> variables,
  ) async {
    final content = _templateEngine.render(template, variables);
    await fileWriter.write(path.join(featurePath, relativePath), content);
  }

  Future<void> _writeTest(
    FileWriter fileWriter,
    ProjectPaths paths,
    String featureName,
    String fileName,
    Template template,
    Map<String, String> variables,
  ) async {
    final content = _templateEngine.render(template, variables);
    final testPath = path.join(paths.test, 'features', featureName, fileName);
    await fileWriter.write(testPath, content);
  }

  Future<void> _writeFeatureExport(
    FileWriter fileWriter,
    String featurePath,
    Map<String, String> vars,
    List<String> exports,
  ) async {
    final content = exports.isEmpty
        ? ''
        : '${exports.map((e) => "export '$e';").join('\n')}\n';
    await fileWriter.write(
        path.join(featurePath, '${vars['featureName']}.dart'), content);
  }
}
