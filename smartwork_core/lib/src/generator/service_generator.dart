import '../filesystem/file_writer.dart';
import '../models/font_config.dart';
import '../models/project_config.dart';
import '../models/service_definition.dart';
import '../paths/project_paths.dart';
import '../template/bootstrap/bootstrap_templates.dart';
import '../template/network/network_service_templates.dart';
import '../template/services/service_templates.dart';
import '../template/storage/storage_service_templates.dart';
import '../template/template_engine.dart';
import '../template/theme/theme_service_templates.dart';

class ServiceGenerator {
  Future<void> generate({
    required Set<String> services,
    required String projectName,
    required ProjectPaths paths,
    required FileWriter fileWriter,
    required Network network,
    required Storage storage,
    FontConfig? fonts,
  }) async {
    fonts ??= FontConfig.none();
    final ordered =
        Service.values.where((s) => services.contains(s.id)).toList();
    final engine = TemplateEngine();

    await fileWriter.write(
      paths.servicesBootstrapFile,
      engine.render(BootstrapTemplates.bootstrapTemplate(ordered), {}),
    );
    await fileWriter.write(
      paths.servicesNetworkServiceFile,
      NetworkServiceTemplates.serviceSource(network),
    );
    await fileWriter.write(
      paths.servicesNetworkExceptionFile,
      NetworkServiceTemplates.exceptionSource(),
    );
    await fileWriter.write(
      paths.servicesNetworkResponseFile,
      NetworkServiceTemplates.responseSource(),
    );
    await fileWriter.write(
      paths.servicesStorageServiceFile,
      StorageServiceTemplates.serviceSource(storage),
    );
    await fileWriter.write(
      paths.servicesThemeServiceFile,
      engine
          .render(ThemeServiceTemplates.themeServiceTemplate(), {}).toString(),
    );
    await fileWriter.write(
      paths.servicesAppThemeFile,
      engine.render(ThemeServiceTemplates.appThemeTemplate(fonts), {}),
    );

    for (final service in ordered) {
      await fileWriter.write(
        paths.serviceFolderFile(service.folderName, service.fileName),
        ServiceTemplates.serviceSource(service),
      );
    }

    await fileWriter.write(
      paths.servicesBarrelFile,
      ServiceTemplates.barrel(ordered),
    );
  }

  Future<void> generateTests({
    required Set<String> services,
    required String projectName,
    required ProjectPaths paths,
    required FileWriter fileWriter,
    required Network network,
    required Storage storage,
    FontConfig? fonts,
  }) async {
    fonts ??= FontConfig.none();
    final ordered =
        Service.values.where((s) => services.contains(s.id)).toList();
    final engine = TemplateEngine();
    final vars = {'projectName': projectName};

    await fileWriter.write(
      paths.testServicesBootstrapFile,
      engine.render(
        BootstrapTemplates.bootstrapTestTemplate(storage, ordered),
        vars,
      ),
    );
    await fileWriter.write(
      paths.testServicesNetworkServiceFile,
      engine.render(
          NetworkServiceTemplates.testTemplate(network, storage), vars),
    );
    await fileWriter.write(
      paths.testServicesStorageServiceFile,
      engine.render(StorageServiceTemplates.testTemplate(storage), vars),
    );
    await fileWriter.write(
      paths.testServicesThemeServiceFile,
      engine.render(
        ThemeServiceTemplates.themeServiceTestTemplate(storage),
        vars,
      ),
    );
    await fileWriter.write(
      paths.testServicesAppThemeFile,
      engine.render(ThemeServiceTemplates.appThemeTestTemplate(fonts), vars),
    );

    for (final service in ordered) {
      final testFileName =
          '${service.fileName.replaceAll('.dart', '')}_test.dart';
      await fileWriter.write(
        paths.testServiceFolderFile(service.folderName, testFileName),
        ServiceTemplates.serviceTestSource(
          service,
          projectName,
          storage: storage,
        ),
      );
    }
  }
}
