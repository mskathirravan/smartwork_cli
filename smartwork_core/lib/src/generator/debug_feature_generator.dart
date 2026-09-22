import '../filesystem/file_writer.dart';
import '../models/project_config.dart';
import '../paths/project_paths.dart';
import '../template/debug/debug_templates.dart';
import '../template/mvp/mvp_templates.dart';
import '../template/mvvm/mvvm_templates.dart';
import '../template/template.dart';
import '../template/template_engine.dart';

class DebugFeatureGenerator {
  Future<void> generate(
    Architecture architecture,
    StateManagement stateManagement,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    final engine = TemplateEngine();

    await fileWriter.write(
      paths.featuresDebugPushTestServiceFile,
      engine.render(DebugTemplates.pushTestServiceTemplate(), {}),
    );
    await fileWriter.write(
      paths.featuresDebugFile,
      engine.render(DebugTemplates.debugBarrelTemplate(architecture), {}),
    );

    await _generateStateManagement(
        architecture, stateManagement, paths, fileWriter, engine);

    switch (architecture) {
      case Architecture.cleanArchitecture:
        await fileWriter.write(
          paths.featuresDebugPageFileClean,
          engine.render(
              DebugTemplates.debugPageTemplateClean(stateManagement), {}),
        );
      case Architecture.mvvm:
        await fileWriter.write(
          paths.featuresDebugPageFileMvvm,
          engine.render(
              DebugTemplates.debugViewTemplateMvvm(stateManagement), {}),
        );
        await fileWriter.write(
          paths.featuresDebugViewModelFileMvvm,
          engine.render(
            stateManagement == StateManagement.riverpod
                ? MvvmTemplates.viewModelTemplate()
                : DebugTemplates.debugViewModelTemplateMvvm(stateManagement),
            {'featureName': 'debug', 'pascalName': 'Debug'},
          ),
        );
      case Architecture.mvp:
        await fileWriter.write(
          paths.featuresDebugPageFileMvp,
          engine
              .render(DebugTemplates.debugViewTemplateMvp(stateManagement), {}),
        );
        await fileWriter.write(
          paths.featuresDebugPresenterFileMvp,
          engine.render(
            stateManagement == StateManagement.riverpod
                ? MvpTemplates.presenterTemplate()
                : DebugTemplates.debugPresenterTemplateMvp(stateManagement),
            {'featureName': 'debug', 'pascalName': 'Debug'},
          ),
        );
    }
  }

  Future<void> _generateStateManagement(
    Architecture architecture,
    StateManagement stateManagement,
    ProjectPaths paths,
    FileWriter fileWriter,
    TemplateEngine engine,
  ) async {
    switch (stateManagement) {
      case StateManagement.bloc:
        await fileWriter.write(
          paths.featuresDebugFileAt(['state', 'debug_state.dart']),
          engine.render(
            DebugTemplates.debugStateTemplate(toCoreDir: '../../../core'),
            {},
          ),
        );
        await fileWriter.write(
          paths.featuresDebugFileAt(['state', 'debug_event.dart']),
          engine.render(DebugTemplates.debugEventTemplate(), {}),
        );
        await fileWriter.write(
          paths.featuresDebugFileAt(['state', 'debug_bloc.dart']),
          engine.render(DebugTemplates.debugBlocTemplate(), {}),
        );
      case StateManagement.cubit:
        await fileWriter.write(
          paths.featuresDebugFileAt(['state', 'debug_state.dart']),
          engine.render(
            DebugTemplates.debugStateTemplate(toCoreDir: '../../../core'),
            {},
          ),
        );
        await fileWriter.write(
          paths.featuresDebugFileAt(['state', 'debug_cubit.dart']),
          engine.render(DebugTemplates.debugCubitTemplate(), {}),
        );
      case StateManagement.getx:
        if (architecture == Architecture.cleanArchitecture) {
          await fileWriter.write(
            paths.featuresDebugFileAt(
              ['presentation', 'getx', 'debug_controller.dart'],
            ),
            engine.render(DebugTemplates.debugGetxControllerTemplate(), {}),
          );
        }
      case StateManagement.riverpod:
        final providersDir = architecture == Architecture.cleanArchitecture
            ? ['presentation', 'providers']
            : ['providers'];
        final toCoreDir = architecture == Architecture.cleanArchitecture
            ? '../../../../core'
            : '../../../core';
        await fileWriter.write(
          paths.featuresDebugFileAt([...providersDir, 'debug_state.dart']),
          engine.render(
            DebugTemplates.debugStateTemplate(toCoreDir: toCoreDir),
            {},
          ),
        );
        final providerTemplate = switch (architecture) {
          Architecture.cleanArchitecture =>
            DebugTemplates.debugRiverpodProviderTemplateClean(),
          Architecture.mvvm =>
            DebugTemplates.debugRiverpodProviderTemplateMvvm(),
          Architecture.mvp => DebugTemplates.debugRiverpodProviderTemplateMvp(),
        };
        await fileWriter.write(
          paths.featuresDebugFileAt([...providersDir, 'debug_provider.dart']),
          engine.render(providerTemplate, {}),
        );
    }
  }

  Future<void> generateTests({
    required Architecture architecture,
    required StateManagement stateManagement,
    required Storage storage,
    required ProjectPaths paths,
    required FileWriter fileWriter,
    required String projectName,
  }) async {
    final engine = TemplateEngine();
    final vars = {'projectName': projectName};

    await fileWriter.write(
      paths.testFeaturesDebugPushTestServiceFile,
      engine.render(DebugTemplates.pushTestServiceTestTemplate(), vars),
    );

    switch (stateManagement) {
      case StateManagement.bloc:
        await fileWriter.write(
          paths.testFeaturesDebugFileAt(['state', 'debug_bloc_test.dart']),
          engine.render(DebugTemplates.debugBlocTestTemplate(storage), vars),
        );
      case StateManagement.cubit:
        await fileWriter.write(
          paths.testFeaturesDebugFileAt(['state', 'debug_cubit_test.dart']),
          engine.render(DebugTemplates.debugCubitTestTemplate(storage), vars),
        );
      case StateManagement.getx:
        if (architecture == Architecture.cleanArchitecture) {
          await fileWriter.write(
            paths.testFeaturesDebugFileAt(
              ['presentation', 'getx', 'debug_controller_test.dart'],
            ),
            engine.render(
                DebugTemplates.debugGetxControllerTestTemplate(storage), vars),
          );
        }
      case StateManagement.riverpod:
        final providersDir = architecture == Architecture.cleanArchitecture
            ? ['presentation', 'providers']
            : ['providers'];
        await fileWriter.write(
          paths.testFeaturesDebugFileAt(
            [...providersDir, 'debug_provider_test.dart'],
          ),
          engine.render(
            DebugTemplates.debugRiverpodNotifierTestTemplate(
              storage,
              architecture,
            ),
            vars,
          ),
        );
    }

    final (String debugPagePath, Template debugPageTemplate) =
        switch (architecture) {
      Architecture.cleanArchitecture => (
          paths.testFeaturesDebugPageFileClean,
          DebugTemplates.debugPageTestTemplateClean(storage),
        ),
      Architecture.mvvm => (
          paths.testFeaturesDebugPageFileMvvm,
          DebugTemplates.debugPageTestTemplateMvvm(storage),
        ),
      Architecture.mvp => (
          paths.testFeaturesDebugPageFileMvp,
          DebugTemplates.debugPageTestTemplateMvp(storage),
        ),
    };
    await fileWriter.write(
        debugPagePath, engine.render(debugPageTemplate, vars));
  }
}
