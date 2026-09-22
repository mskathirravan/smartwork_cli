import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkModelFromJsonTool = Tool(
  name: 'smartwork_model_from_json',
  description: 'Generates a Dart model (fields, const constructor, '
      'fromJson, toJson — no copyWith/equality/hashCode/toString, no '
      'serialization dependency) from a single JSON sample document, '
      'into an already-existing feature\'s architecture-specific model '
      'folder. A nested object or object list generates its own model '
      'class in a separate file. The target feature must already '
      'exist. Refuses to overwrite an existing generated model file.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'jsonFilePath': Schema.string(
        description: 'Path (on the machine running this server) to a '
            'JSON sample document whose root value must be an object.',
      ),
      'feature': Schema.string(
        description: 'The existing feature to generate the model(s) '
            'into.',
      ),
    },
    required: ['jsonFilePath', 'feature'],
  ),
);

class ModelTools {
  final ModelLifecycle _lifecycle;

  ModelTools({ModelLifecycle? lifecycle})
      : _lifecycle = lifecycle ?? ModelLifecycle();

  Future<CallToolResult> fromJson(CallToolRequest request) async {
    final projectPath = request.arguments?['projectPath'] as String? ?? '.';
    final jsonFilePath = request.arguments!['jsonFilePath'] as String;
    final feature = request.arguments!['feature'] as String;

    try {
      final result = await _lifecycle.generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFilePath,
        featureName: feature,
      );

      return CallToolResult(
        content: [TextContent(text: 'Success: model_from_json')],
        structuredContent: {
          'success': true,
          'operation': 'model_from_json',
          'projectPath': projectPath,
          'feature': feature,
          'result': {
            'generatedFiles': result.generatedFiles,
            'classNames': result.classNames,
          },
        },
      );
    } on FileSystemException {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'no_project',
        message: 'No SmartWork project found at "$projectPath". Run '
            'smartwork init first.',
      );
    } on FeatureNotFoundException catch (e) {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'feature_not_found',
        message: e.toString(),
      );
    } on JsonFileNotFoundException catch (e) {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'json_file_not_found',
        message: e.toString(),
      );
    } on InvalidJsonException catch (e) {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'invalid_json',
        message: e.toString(),
      );
    } on UnsupportedJsonRootException catch (e) {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'unsupported_json_root',
        message: e.toString(),
      );
    } on DuplicateModelClassNameException catch (e) {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'duplicate_model_class_name',
        message: e.toString(),
      );
    } on ModelFileCollisionException catch (e) {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'model_file_collision',
        message: e.toString(),
      );
    } catch (_) {
      return _error(
        feature: feature,
        projectPath: projectPath,
        code: 'unexpected_error',
        message: 'An unexpected error occurred while running '
            'model_from_json.',
      );
    }
  }

  CallToolResult _error({
    required String feature,
    required String projectPath,
    required String code,
    required String message,
  }) =>
      CallToolResult(
        isError: true,
        content: [TextContent(text: message)],
        structuredContent: {
          'success': false,
          'operation': 'model_from_json',
          'projectPath': projectPath,
          'feature': feature,
          'error': {'code': code, 'message': message},
        },
      );
}
