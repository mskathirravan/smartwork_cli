import 'dart:io';

import '../filesystem/file_writer.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../models/service_definition.dart';
import '../paths/project_paths.dart';
import '../template/bootstrap/bootstrap_templates.dart';
import '../template/constants/constants_templates.dart';
import '../template/services/service_templates.dart';
import '../template/template_engine.dart';
import 'pubspec_generator.dart';

class UnknownServiceException implements Exception {
  final String serviceId;

  UnknownServiceException(this.serviceId);

  @override
  String toString() => 'Unknown service: $serviceId';
}

class ServiceAlreadySelectedException implements Exception {
  final String serviceId;

  ServiceAlreadySelectedException(this.serviceId);

  @override
  String toString() => 'Service already selected: $serviceId';
}

class ServiceNotSelectedException implements Exception {
  final String serviceId;

  ServiceNotSelectedException(this.serviceId);

  @override
  String toString() => 'Service not selected: $serviceId';
}

class ServiceLifecycle {
  Future<void> addService({
    required String projectPath,
    required String serviceId,
  }) async {
    final service = _resolve(serviceId);
    final config = await ProjectConfigFile(projectPath: projectPath).read();

    if (config.services.contains(serviceId)) {
      throw ServiceAlreadySelectedException(serviceId);
    }

    final paths = ProjectPaths(projectRoot: projectPath);
    final fileWriter = FileWriter();
    final updatedConfig = _withServices(
      config,
      {...config.services, serviceId},
    );

    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);

    await fileWriter.write(
      paths.serviceFolderFile(service.folderName, service.fileName),
      ServiceTemplates.serviceSource(service),
    );
    await fileWriter.write(
      paths.testServiceFolderFile(service.folderName, _testFileName(service)),
      ServiceTemplates.serviceTestSource(
        service,
        config.projectName,
        storage: config.storage,
      ),
    );

    await _regenerateBootstrapAndBarrel(updatedConfig, paths, fileWriter);
    await _syncPubspec(updatedConfig, paths, fileWriter);
  }

  Future<void> removeService({
    required String projectPath,
    required String serviceId,
  }) async {
    final service = _resolve(serviceId);
    final config = await ProjectConfigFile(projectPath: projectPath).read();

    if (!config.services.contains(serviceId)) {
      throw ServiceNotSelectedException(serviceId);
    }

    final paths = ProjectPaths(projectRoot: projectPath);
    final fileWriter = FileWriter();
    final updatedConfig = _withServices(
      config,
      config.services.where((id) => id != serviceId).toSet(),
    );

    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);

    await _deleteIfExists(
      File(paths.serviceFolderFile(service.folderName, service.fileName)),
    );
    await _deleteIfExists(
      File(paths.testServiceFolderFile(
        service.folderName,
        _testFileName(service),
      )),
    );

    await _regenerateBootstrapAndBarrel(updatedConfig, paths, fileWriter);
    await _syncPubspec(updatedConfig, paths, fileWriter);
  }

  String _testFileName(Service service) =>
      '${service.fileName.replaceAll('.dart', '')}_test.dart';

  Service _resolve(String serviceId) {
    for (final service in Service.values) {
      if (service.id == serviceId) return service;
    }
    throw UnknownServiceException(serviceId);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
    final dir = file.parent;
    if (await dir.exists() && await dir.list().isEmpty) {
      await dir.delete();
    }
  }

  Future<void> _regenerateBootstrapAndBarrel(
    ProjectConfig config,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    final engine = TemplateEngine();
    final ordered = config.orderedServices;

    await fileWriter.write(
      paths.servicesBootstrapFile,
      engine.render(BootstrapTemplates.bootstrapTemplate(ordered), {}),
    );
    await fileWriter.write(
      paths.testServicesBootstrapFile,
      engine.render(
        BootstrapTemplates.bootstrapTestTemplate(config.storage, ordered),
        {'projectName': config.projectName},
      ),
    );
    await fileWriter.write(
      paths.servicesBarrelFile,
      ServiceTemplates.barrel(ordered),
    );
    await fileWriter.write(
      paths.coreConstantsStorageFile,
      engine.render(
        ConstantsTemplates.storageConstantsTemplate(
          includeSecureSessionKeys:
              config.services.contains(Service.secureSession.id),
        ),
        {},
      ),
    );
  }

  Future<void> _syncPubspec(
    ProjectConfig config,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    final pubspecFile = File(paths.pubspecFile);
    if (!await pubspecFile.exists()) return;

    final existing = await pubspecFile.readAsString();
    final merged = await PubspecGenerator().mergeInto(existing, config);
    await fileWriter.write(paths.pubspecFile, merged);
  }

  ProjectConfig _withServices(ProjectConfig config, Set<String> services) {
    return config.copyWith(services: services);
  }
}
