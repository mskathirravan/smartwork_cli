import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkSplashAddTool = Tool(
  name: 'smartwork_splash_add',
  description: 'Adds or reconfigures the Splash Screen in an existing '
      'SmartWork project — a full-screen background with a centered '
      'application icon at 60% of the available width, generated as a '
      'plain, stateless widget under lib/shared/ui/splash_screen.dart. '
      'No navigation, no timer, no persistence. Running this again '
      'with different values updates Splash in place.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'backgroundColor': Schema.string(
        description: 'A 6-digit hex color, e.g. "#2E7D32" or "2E7D32".',
      ),
      'iconPath': Schema.string(
        description: 'Path (on the machine running this server) to a '
            '.png/.jpg/.jpeg image to center on the Splash background.',
      ),
    },
    required: ['backgroundColor', 'iconPath'],
  ),
);

class SplashTools {
  final SplashLifecycle _lifecycle;

  SplashTools({SplashLifecycle? lifecycle})
      : _lifecycle = lifecycle ?? SplashLifecycle();

  Future<CallToolResult> add(CallToolRequest request) async {
    final projectPath = request.arguments?['projectPath'] as String? ?? '.';
    final backgroundColor = request.arguments!['backgroundColor'] as String;
    final iconPath = request.arguments!['iconPath'] as String;

    try {
      final result = await _lifecycle.addSplash(
        projectPath: projectPath,
        backgroundColor: backgroundColor,
        iconPath: iconPath,
      );

      return CallToolResult(
        content: [TextContent(text: 'Success: splash_add')],
        structuredContent: {
          'success': true,
          'operation': 'splash_add',
          'projectPath': projectPath,
          'result': {'iconAssetPath': result.iconAssetPath},
        },
      );
    } on FileSystemException {
      return _error(
        projectPath: projectPath,
        code: 'no_project',
        message: 'No SmartWork project found at "$projectPath". Run '
            'smartwork init first.',
      );
    } on InvalidSplashConfigException catch (e) {
      return _error(
        projectPath: projectPath,
        code: 'invalid_splash_config',
        message: e.toString(),
      );
    } catch (_) {
      return _error(
        projectPath: projectPath,
        code: 'unexpected_error',
        message: 'An unexpected error occurred while running splash_add.',
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
          'operation': 'splash_add',
          'projectPath': projectPath,
          'error': {'code': code, 'message': message},
        },
      );
}
