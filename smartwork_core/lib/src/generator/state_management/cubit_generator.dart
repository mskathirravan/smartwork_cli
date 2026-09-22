import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';

class CubitGenerator implements StateManagementGenerator {
  late final TemplateEngine _templateEngine = TemplateEngine();

  @override
  Future<void> generate(
    ProjectConfig config,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    for (final feature in config.initialFeatures) {
      await _generateFeature(feature, paths, fileWriter);
    }
  }

  Future<void> _generateFeature(
    String featureName,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    final featurePath = paths.featurePath(featureName);
    final statePath = path.join(featurePath, 'state');
    final names = FeatureNames.fromFeature(featureName);

    final stateFileName = '${names.snake}_state.dart';
    final stateContent = _templateEngine.render(
      CubitTemplates.stateTemplate(featureName, names.pascal),
      {
        'featureName': names.snake,
        'pascalName': names.pascal,
      },
    );
    await fileWriter.write(path.join(statePath, stateFileName), stateContent);

    final cubitFileName = '${names.snake}_cubit.dart';
    final cubitContent = _templateEngine.render(
      CubitTemplates.cubitTemplate(featureName, names.pascal),
      {
        'featureName': names.snake,
        'pascalName': names.pascal,
      },
    );
    await fileWriter.write(path.join(statePath, cubitFileName), cubitContent);
  }
}
