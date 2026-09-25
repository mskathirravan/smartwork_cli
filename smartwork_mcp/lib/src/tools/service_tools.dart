import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkServiceAddTool = Tool(
  name: 'smartwork_service_add',
  description: 'Adds a Production Service (e.g. analytics, logger, '
      'crashReporting) to an existing SmartWork project. Regenerates '
      'Bootstrap and the services barrel.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'service': Schema.string(
        description: 'Service id: secureSession, connectivity, '
            'deviceInfo, logger, crashReporting, notification, '
            'deeplink, analytics, forceUpdate, appReview, or eventBus.',
      ),
    },
    required: ['service'],
  ),
);

final smartworkServiceRemoveTool = Tool(
  name: 'smartwork_service_remove',
  description: 'Removes a Production Service from an existing '
      'SmartWork project and regenerates Bootstrap and the services '
      'barrel. Infrastructure (bootstrap, routing, network, storage, '
      'theme) cannot be removed this way.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'service': Schema.string(
        description: 'Service id to remove.',
      ),
    },
    required: ['service'],
  ),
);

class ServiceTools {
  final ServiceLifecycle _lifecycle;

  ServiceTools({ServiceLifecycle? lifecycle})
      : _lifecycle = lifecycle ?? ServiceLifecycle();

  Future<CallToolResult> add(CallToolRequest request) async {
    final projectPath = _projectPath(request);
    final serviceId = request.arguments!['service'] as String;

    try {
      final pubspecBefore = _readPubspec(projectPath);
      await _lifecycle.addService(
        projectPath: projectPath,
        serviceId: serviceId,
      );
      final dependenciesChanged = _readPubspec(projectPath) != pubspecBefore;

      final service = Service.values.firstWhere((s) => s.id == serviceId);
      return _success(
        operation: 'service_add',
        projectPath: projectPath,
        subject: {'service': serviceId},
        result: {
          'displayName': service.displayName,
          'generatedFile':
              'lib/services/${service.folderName}/${service.fileName}',
          'bootstrapUpdated': service.hasInitialize,
          ..._dependencyChange(dependenciesChanged),
        },
      );
    } on FileSystemException {
      return _noProjectError('service_add', projectPath, serviceId);
    } on UnknownServiceException catch (e) {
      return _unknownServiceError('service_add', projectPath, serviceId, e);
    } on ServiceAlreadySelectedException catch (e) {
      return _error(
        operation: 'service_add',
        projectPath: projectPath,
        subject: {'service': serviceId},
        code: 'service_already_selected',
        message: '$e — nothing was changed.',
      );
    } catch (_) {
      return _unexpectedError('service_add', projectPath, {
        'service': serviceId,
      });
    }
  }

  Future<CallToolResult> remove(CallToolRequest request) async {
    final projectPath = _projectPath(request);
    final serviceId = request.arguments!['service'] as String;

    try {
      final pubspecBefore = _readPubspec(projectPath);
      await _lifecycle.removeService(
        projectPath: projectPath,
        serviceId: serviceId,
      );
      final dependenciesChanged = _readPubspec(projectPath) != pubspecBefore;

      final service = Service.values.firstWhere((s) => s.id == serviceId);
      return _success(
        operation: 'service_remove',
        projectPath: projectPath,
        subject: {'service': serviceId},
        result: {
          'displayName': service.displayName,
          'removedFolder': 'lib/services/${service.folderName}/',
          ..._dependencyChange(dependenciesChanged),
        },
      );
    } on FileSystemException {
      return _noProjectError('service_remove', projectPath, serviceId);
    } on UnknownServiceException catch (e) {
      return _unknownServiceError('service_remove', projectPath, serviceId, e);
    } on ServiceNotSelectedException catch (e) {
      return _error(
        operation: 'service_remove',
        projectPath: projectPath,
        subject: {'service': serviceId},
        code: 'service_not_selected',
        message: '$e — nothing was changed.',
      );
    } catch (_) {
      return _unexpectedError('service_remove', projectPath, {
        'service': serviceId,
      });
    }
  }

  String? _readPubspec(String projectPath) {
    final file = File(ProjectPaths(projectRoot: projectPath).pubspecFile);
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// pubspec.yaml dependencies changed, so the caller must run
  /// `flutter pub get` — which fails on an out-of-date Flutter SDK.
  Map<String, Object?> _dependencyChange(bool changed) => changed
      ? {
          'dependenciesChanged': true,
          'nextStep': 'Run "flutter pub get" in the project. If it fails '
              'because a package requires a newer SDK, the Flutter SDK is '
              'too old: update Flutter ("flutter upgrade") and run it again.',
        }
      : const {};

  String _projectPath(CallToolRequest request) =>
      request.arguments?['projectPath'] as String? ?? '.';

  CallToolResult _success({
    required String operation,
    required String projectPath,
    required Map<String, Object?> subject,
    required Map<String, Object?> result,
  }) =>
      CallToolResult(
        content: [TextContent(text: 'Success: $operation')],
        structuredContent: {
          'success': true,
          'operation': operation,
          'projectPath': projectPath,
          ...subject,
          'result': result,
        },
      );

  CallToolResult _error({
    required String operation,
    required String projectPath,
    required Map<String, Object?> subject,
    required String code,
    required String message,
  }) =>
      CallToolResult(
        isError: true,
        content: [TextContent(text: message)],
        structuredContent: {
          'success': false,
          'operation': operation,
          'projectPath': projectPath,
          ...subject,
          'error': {'code': code, 'message': message},
        },
      );

  CallToolResult _unknownServiceError(
    String operation,
    String projectPath,
    String serviceId,
    UnknownServiceException e,
  ) =>
      _error(
        operation: operation,
        projectPath: projectPath,
        subject: {'service': serviceId},
        code: 'unknown_service',
        message: '$e. Valid services: '
            '${Service.values.map((s) => s.id).join(', ')}.',
      );

  CallToolResult _noProjectError(
    String operation,
    String projectPath,
    String serviceId,
  ) =>
      _error(
        operation: operation,
        projectPath: projectPath,
        subject: {'service': serviceId},
        code: 'no_project',
        message: 'No SmartWork project found at "$projectPath". Run '
            'smartwork init first.',
      );

  CallToolResult _unexpectedError(
    String operation,
    String projectPath,
    Map<String, Object?> subject,
  ) =>
      _error(
        operation: operation,
        projectPath: projectPath,
        subject: subject,
        code: 'unexpected_error',
        message: 'An unexpected error occurred while running $operation.',
      );
}
