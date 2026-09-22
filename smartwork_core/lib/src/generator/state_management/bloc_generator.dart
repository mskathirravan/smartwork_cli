import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';

class BlocGenerator implements StateManagementGenerator {
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

    final eventFileName = '${names.snake}_event.dart';
    final eventContent = _templateEngine.render(
      BlocTemplates.eventTemplate(featureName, names.pascal),
      {
        'featureName': names.snake,
        'pascalName': names.pascal,
      },
    );
    await fileWriter.write(path.join(statePath, eventFileName), eventContent);

    final stateFileName = '${names.snake}_state.dart';
    final stateContent = _templateEngine.render(
      BlocTemplates.stateTemplate(featureName, names.pascal),
      {
        'featureName': names.snake,
        'pascalName': names.pascal,
      },
    );
    await fileWriter.write(path.join(statePath, stateFileName), stateContent);

    final blocFileName = '${names.snake}_bloc.dart';
    final blocContent = _templateEngine.render(
      BlocTemplates.blocTemplate(featureName, names.pascal),
      {
        'featureName': names.snake,
        'pascalName': names.pascal,
      },
    );
    await fileWriter.write(path.join(statePath, blocFileName), blocContent);
  }
}
