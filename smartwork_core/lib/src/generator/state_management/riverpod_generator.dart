import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';

class RiverpodGenerator implements StateManagementGenerator {
  late final TemplateEngine _templateEngine;

  RiverpodGenerator() {
    _templateEngine = TemplateEngine();
  }

  @override
  Future<void> generate(
    ProjectConfig config,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    for (final feature in config.initialFeatures) {
      await _generateFeature(feature, config.architecture, paths, fileWriter);
    }
  }

  Future<void> _generateFeature(
    String featureName,
    Architecture architecture,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    final featurePath = paths.featurePath(featureName);
    final featureNames = FeatureNames(featureName);

    final providersPath = _getProvidersPath(featurePath, architecture);

    final stateContent = _templateEngine.render(
      RiverpodTemplates.stateTemplate(featureName, featureNames.pascal),
      {},
    );
    await fileWriter.write(
      path.join(providersPath, '${featureNames.snake}_state.dart'),
      stateContent,
    );

    final providerContent = _getProviderContent(
      featureName,
      featureNames,
      architecture,
    );
    await fileWriter.write(
      path.join(providersPath, '${featureNames.snake}_provider.dart'),
      providerContent,
    );
  }

  String _getProvidersPath(String featurePath, Architecture architecture) {
    switch (architecture) {
      case Architecture.cleanArchitecture:
        return path.join(featurePath, 'presentation', 'providers');
      case Architecture.mvvm:
      case Architecture.mvp:
        return path.join(featurePath, 'providers');
    }
  }

  String _getProviderContent(
    String featureName,
    FeatureNames featureNames,
    Architecture architecture,
  ) {
    switch (architecture) {
      case Architecture.cleanArchitecture:
        return _templateEngine.render(
          RiverpodTemplates.providerTemplateClean(
            featureName,
            featureNames.snake,
            featureNames.pascal,
          ),
          {},
        );
      case Architecture.mvvm:
        return _templateEngine.render(
          RiverpodTemplates.providerTemplateMvvm(
            featureName,
            featureNames.snake,
            featureNames.pascal,
          ),
          {},
        );
      case Architecture.mvp:
        return _templateEngine.render(
          RiverpodTemplates.providerTemplateMvp(
            featureName,
            featureNames.snake,
            featureNames.pascal,
          ),
          {},
        );
    }
  }
}
