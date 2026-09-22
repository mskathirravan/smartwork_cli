import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkAppIconSetTool = Tool(
  name: 'smartwork_app_icon_set',
  description: 'Generates the App Icon for an existing SmartWork '
      'project — Android legacy launcher icons, iOS AppIcon, macOS '
      'AppIcon, and Web favicon/PWA icons — from a single square '
      'source image. Android adaptive icons, Windows, and Linux are '
      'out of scope. Running this again with a different source '
      'replaces every generated icon file.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'sourcePath': Schema.string(
        description: 'Path (on the machine running this server) to a '
            'square .png/.jpg/.jpeg image to use as the App Icon.',
      ),
    },
    required: ['sourcePath'],
  ),
);

class IconTools {
  final AppIconLifecycle _lifecycle;

  IconTools({AppIconLifecycle? lifecycle})
      : _lifecycle = lifecycle ?? AppIconLifecycle();

  Future<CallToolResult> set(CallToolRequest request) async {
    final projectPath = request.arguments?['projectPath'] as String? ?? '.';
    final sourcePath = request.arguments!['sourcePath'] as String;

    try {
      final result = await _lifecycle.setAppIcon(
        projectPath: projectPath,
        sourcePath: sourcePath,
      );

      return CallToolResult(
        content: [TextContent(text: 'Success: app_icon_set')],
        structuredContent: {
          'success': true,
          'operation': 'app_icon_set',
          'projectPath': projectPath,
          'result': {'generatedFiles': result.generatedFiles},
        },
      );
    } on FileSystemException {
      return _error(
        projectPath: projectPath,
        code: 'no_project',
        message: 'No SmartWork project found at "$projectPath". Run '
            'smartwork init first.',
      );
    } on InvalidAppIconConfigException catch (e) {
      return _error(
        projectPath: projectPath,
        code: 'invalid_app_icon_config',
        message: e.toString(),
      );
    } on AppIconTransparencyException catch (e) {
      return _error(
        projectPath: projectPath,
        code: 'app_icon_transparency',
        message: e.toString(),
      );
    } on NoSupportedPlatformFoundException catch (e) {
      return _error(
        projectPath: projectPath,
        code: 'no_supported_platform_found',
        message: e.toString(),
      );
    } catch (_) {
      return _error(
        projectPath: projectPath,
        code: 'unexpected_error',
        message: 'An unexpected error occurred while running '
            'app_icon_set.',
      );
    }
  }

  CallToolResult _error({
    required String projectPath,
    required String code,
    required String message,
  }) =>
      CallToolResult(
        isError: true,
        content: [TextContent(text: message)],
        structuredContent: {
          'success': false,
          'operation': 'app_icon_set',
          'projectPath': projectPath,
          'error': {'code': code, 'message': message},
        },
      );
}
