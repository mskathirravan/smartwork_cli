import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';

class GetxGenerator implements StateManagementGenerator {
  late final TemplateEngine _templateEngine;

  GetxGenerator() {
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
    final fileName = '${featureNames.snake}_controller.dart';

    switch (architecture) {
      case Architecture.cleanArchitecture:
        final getxPath = path.join(featurePath, 'presentation', 'getx');
        final content = _templateEngine.render(
          GetxTemplates.controllerTemplate(featureName, featureNames.pascal),
          {
            'featureName': featureNames.snake,
            'pascalName': featureNames.pascal,
          },
        );
        await fileWriter.write(path.join(getxPath, fileName), content);
      case Architecture.mvvm:
      case Architecture.mvp:
        break;
    }
  }
}
