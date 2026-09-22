import '../filesystem/file_writer.dart';
import '../models/project_config.dart';
import '../paths/project_paths.dart';
import '../template/constants/constants_templates.dart';
import '../template/environment/environment_templates.dart';
import '../template/template_engine.dart';
import '../template/utilities/utilities_templates.dart';

class CoreTestGenerator {
  Future<void> generate({
    required ProjectConfig config,
    required ProjectPaths paths,
    required FileWriter fileWriter,
  }) async {
    final engine = TemplateEngine();
    final vars = {'projectName': config.projectName};

    await fileWriter.write(
      paths.testCoreConstantsFile,
      engine.render(ConstantsTemplates.constantsTestTemplate(), vars),
    );
    await fileWriter.write(
      paths.testCoreScreenDimensionsFile,
      engine.render(ConstantsTemplates.screenDimensionsTestTemplate(), vars),
    );
    await fileWriter.write(
      paths.testCoreUtilitiesAppPlatformFile,
      engine.render(UtilitiesTemplates.appPlatformTestTemplate(), vars),
    );
    await fileWriter.write(
      paths.testCoreUtilitiesDateTimeExtensionsFile,
      engine.render(UtilitiesTemplates.dateTimeExtensionsTestTemplate(), vars),
    );
    await fileWriter.write(
      paths.testCoreUtilitiesStringExtensionsFile,
      engine.render(UtilitiesTemplates.stringExtensionsTestTemplate(), vars),
    );
    await fileWriter.write(
      paths.testCoreUtilitiesColorHexFile,
      engine.render(UtilitiesTemplates.colorHexTestTemplate(), vars),
    );
    await fileWriter.write(
      paths.testCoreUtilitiesFileSizeFile,
      engine.render(UtilitiesTemplates.fileSizeTestTemplate(), vars),
    );
    await fileWriter.write(
      paths.testCoreEnvironmentFile,
      engine.render(
          EnvironmentTemplates.environmentTestTemplate(config.storage), vars),
    );
  }
}
