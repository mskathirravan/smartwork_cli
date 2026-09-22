import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkFeatureAddTool = Tool(
  name: 'smartwork_feature_add',
  description: 'Adds a new feature to an existing SmartWork project '
      '(the standard component blueprint — entity, repository, use '
      'case, data source, page). Regenerates routing automatically.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'featureName': Schema.string(
        description: 'Name of the feature to add (lowercase letters, '
            'numbers, underscores; must start with a letter).',
      ),
    },
    required: ['featureName'],
  ),
);

final smartworkFeatureRemoveTool = Tool(
  name: 'smartwork_feature_remove',
  description: 'Removes a feature from an existing SmartWork project '
      'and regenerates routing. The configured Home feature and the '
      'framework Debug feature cannot be removed.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'featureName': Schema.string(
        description: 'Name of the feature to remove.',
      ),
    },
    required: ['featureName'],
  ),
);

class FeatureTools {
  final FeatureLifecycle _lifecycle;

  FeatureTools({FeatureLifecycle? lifecycle})
      : _lifecycle = lifecycle ?? FeatureLifecycle();

  Future<CallToolResult> add(CallToolRequest request) async {
    final projectPath = _projectPath(request);
    final featureName = request.arguments!['featureName'] as String;

    try {
      final feature = FeatureConfig(name: featureName);
      final result = await _lifecycle.addFeature(
        projectPath: projectPath,
        feature: feature,
      );

      return _success(
        operation: 'feature_add',
        projectPath: projectPath,
        subject: {'featureName': featureName},
        result: {
          'fileCount': result.generation.fileCount,
          'directoryCount': result.generation.directoryCount,
          'addedToRouting': result.addedToRouting,
        },
      );
    } on FileSystemException {
      return _noProjectError('feature_add', projectPath, featureName);
    } on InvalidFeatureNameException catch (e) {
      return _error(
        operation: 'feature_add',
        projectPath: projectPath,
        subject: {'featureName': featureName},
        code: 'invalid_feature_name',
        message: e.toString(),
      );
    } on FeatureAlreadyExistsException catch (e) {
      return _error(
        operation: 'feature_add',
        projectPath: projectPath,
        subject: {'featureName': featureName},
        code: 'feature_already_exists',
        message: e.toString(),
      );
    } catch (_) {
      return _unexpectedError('feature_add', projectPath, {
        'featureName': featureName,
      });
    }
  }

  Future<CallToolResult> remove(CallToolRequest request) async {
    final projectPath = _projectPath(request);
    final featureName = request.arguments!['featureName'] as String;

    try {
      final result = await _lifecycle.removeFeature(
        projectPath: projectPath,
        featureName: featureName,
      );

      return _success(
        operation: 'feature_remove',
        projectPath: projectPath,
        subject: {'featureName': featureName},
        result: {'wasRouted': result.wasRouted},
      );
    } on FileSystemException {
      return _noProjectError('feature_remove', projectPath, featureName);
    } on HomeFeatureNotRemovableException catch (e) {
      return _error(
        operation: 'feature_remove',
        projectPath: projectPath,
        subject: {'featureName': featureName},
        code: 'home_feature_not_removable',
        message: e.toString(),
      );
    } on DebugFeatureNotRemovableException catch (e) {
      return _error(
        operation: 'feature_remove',
        projectPath: projectPath,
        subject: {'featureName': featureName},
        code: 'debug_feature_not_removable',
        message: e.toString(),
      );
    } on FeatureNotFoundException catch (e) {
      return _error(
        operation: 'feature_remove',
        projectPath: projectPath,
        subject: {'featureName': featureName},
        code: 'feature_not_found',
        message: '${e.featureName} was not found — nothing was removed.',
      );
    } catch (_) {
      return _unexpectedError('feature_remove', projectPath, {
        'featureName': featureName,
      });
    }
  }

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

  CallToolResult _noProjectError(
    String operation,
    String projectPath,
    String featureName,
  ) =>
      _error(
        operation: operation,
        projectPath: projectPath,
        subject: {'featureName': featureName},
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
