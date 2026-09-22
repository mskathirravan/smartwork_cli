import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkDiscoverTool = Tool(
  name: 'smartwork_discover',
  description: 'Builds a machine-readable understanding of an existing '
      'project — framework, platforms, dependencies, architecture, '
      'state management, dependency injection, features, and test '
      'structure — each field reported with its own confidence '
      '(declared/detected/inferred/unknown) and supporting evidence. '
      'Read-only: never writes a file or modifies anything.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'Directory to analyze. Defaults to the current '
            'directory.',
      ),
    },
  ),
);

class DiscoverTool {
  final DiscoverLifecycle _lifecycle;

  DiscoverTool({DiscoverLifecycle? lifecycle})
      : _lifecycle = lifecycle ?? DiscoverLifecycle();

  Future<CallToolResult> call(CallToolRequest request) async {
    final projectPath = request.arguments?['projectPath'] as String? ?? '.';

    try {
      final knowledge = await _lifecycle.discover(projectPath);

      return CallToolResult(
        content: [TextContent(text: 'Success: discover')],
        structuredContent: {
          'success': true,
          'operation': 'discover',
          'projectPath': projectPath,
          'result': knowledge.toJson(),
        },
      );
    } on NotAFlutterProjectException catch (e) {
      return _error(
        projectPath: projectPath,
        code: 'not_a_flutter_project',
        message: e.toString(),
      );
    } catch (_) {
      return _error(
        projectPath: projectPath,
        code: 'unexpected_error',
        message: 'An unexpected error occurred while running discover.',
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
          'operation': 'discover',
          'projectPath': projectPath,
          'error': {'code': code, 'message': message},
        },
      );
}
