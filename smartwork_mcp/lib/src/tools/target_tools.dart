import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkTargetPlanTool = Tool(
  name: 'smartwork_target_plan',
  description:
      'Computes the effect of changing an existing SmartWork project\'s '
      'App Targets (read-only — creates/deletes nothing). Pass the '
      'returned "plan" unchanged to smartwork_target_apply to perform '
      'the real change.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory.',
      ),
      'appTargets': Schema.list(
        description: 'The complete desired set of App Targets: '
            'android, ios, web, windows, macos, linux. Duplicates are '
            'normalized; order does not affect the result.',
        items: Schema.string(),
      ),
    },
    required: ['appTargets'],
  ),
);

final smartworkTargetApplyTool = Tool(
  name: 'smartwork_target_apply',
  description: 'Performs a real App Targets change: creates any genuinely '
      'missing platform folder, updates .smartwork/project.yaml, '
      'validates, and updates documentation. Requires the exact '
      'canonical "plan" from smartwork_target_plan and confirm: true '
      '— never uses stdin, never uses a server-cached plan. Removing '
      'a target only ever drops it from configuration; its platform '
      'folder is never deleted.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'SmartWork project directory. Defaults to the '
            'current directory. Should match the projectPath used for '
            'smartwork_target_plan.',
      ),
      'plan': Schema.object(
        description: 'The exact canonical plan object returned by '
            'smartwork_target_plan\'s "plan" field.',
        properties: {},
      ),
      'confirm': Schema.bool(
        description: 'Must be true to perform the change. A missing '
            'or false value performs no action.',
      ),
    },
    required: ['plan', 'confirm'],
  ),
);

class TargetTools {
  final TargetStateDetector _detector;
  final ProjectTargetUpdater _updater;

  TargetTools({
    TargetStateDetector? detector,
    ProjectTargetUpdater? updater,
  })  : _detector = detector ?? TargetStateDetector(),
        _updater = updater ?? ProjectTargetUpdater();

  Future<CallToolResult> plan(CallToolRequest request) async {
    final args = request.arguments!;
    final projectPath = args['projectPath'] as String? ?? '.';

    Set<AppTarget> requested;
    try {
      requested = _parseTargets(args['appTargets']);
    } on _InvalidTargetException catch (e) {
      return _error(
        operation: 'target_plan',
        projectPath: projectPath,
        code: 'invalid_target',
        message: e.message,
      );
    }

    try {
      final detected = await _detector.detect(projectPath);
      if (detected.state != TargetProjectState.smartworkProject) {
        return _notASmartworkProjectError('target_plan', projectPath);
      }

      final config = detected.existingConfig!;
      final targetPlan = TargetChangePlan.compute(
        current: config.appTargets,
        requested: requested,
      );

      return CallToolResult(
        content: [TextContent(text: 'Plan ready for $projectPath.')],
        structuredContent: {
          'success': true,
          'operation': 'target_plan',
          'plan': {
            'appTargets': _names(targetPlan.orderedRequested),
          },
          'currentState': {
            'appTargets': _names(targetPlan.orderedCurrent),
            'existingPlatforms': _names(
                AppTarget.values.where(detected.existingPlatforms.contains)),
          },
          'changes': {
            'add': _names(targetPlan.orderedAdded),
            'removedFromConfig': _names(targetPlan.orderedRemovedFromConfig),
          },
          'safety': {
            'state': detected.state.name,
            'hasChanges': targetPlan.hasChanges,
          },
        },
      );
    } catch (_) {
      return _unexpectedError('target_plan', projectPath);
    }
  }

  Future<CallToolResult> apply(CallToolRequest request) async {
    final args = request.arguments!;
    final projectPath = args['projectPath'] as String? ?? '.';
    final confirm = args['confirm'] as bool? ?? false;

    if (!confirm) {
      return _error(
        operation: 'target_apply',
        projectPath: projectPath,
        code: 'confirmation_required',
        message: 'confirm must be true to apply a target change. No '
            'files were changed.',
      );
    }

    final planMap = args['plan'];
    if (planMap is! Map) {
      return _error(
        operation: 'target_apply',
        projectPath: projectPath,
        code: 'invalid_target',
        message: 'plan must be the canonical object returned by '
            'smartwork_target_plan.',
      );
    }

    Set<AppTarget> requested;
    try {
      requested = _parseTargets(planMap['appTargets']);
    } on _InvalidTargetException catch (e) {
      return _error(
        operation: 'target_apply',
        projectPath: projectPath,
        code: 'invalid_target',
        message: e.message,
      );
    }

    try {
      final detected = await _detector.detect(projectPath);
      if (detected.state != TargetProjectState.smartworkProject) {
        return _notASmartworkProjectError('target_apply', projectPath);
      }

      final result = await _updater.apply(
        projectPath: projectPath,
        config: detected.existingConfig!,
        requestedTargets: requested,
      );

      return CallToolResult(
        content: [
          TextContent(text: 'App Targets updated for $projectPath.'),
        ],
        structuredContent: {
          'success': true,
          'operation': 'target_apply',
          'projectPath': projectPath,
          'plan': {
            'appTargets': _names(result.plan.orderedRequested),
          },
          'result': {
            'platformsCreated': _names(
              AppTarget.values.where(result.platformsCreated.contains),
            ),
            'removedFromConfig': _names(result.plan.orderedRemovedFromConfig),
            'validationPhases': [
              for (final phase in result.validation.phases)
                {'phase': phase.phase.name, 'passed': phase.passed},
            ],
          },
        },
      );
    } on FlutterBootstrapException catch (e) {
      return _error(
        operation: 'target_apply',
        projectPath: projectPath,
        code: 'flutter_bootstrap_failed',
        message: e.toString(),
      );
    } on ProjectValidationFailedException catch (e) {
      return _error(
        operation: 'target_apply',
        projectPath: projectPath,
        code: 'validation_failed',
        message: 'Project validation failed at the '
            '"${e.result.phases.last.phase.label}" phase.',
      );
    } catch (_) {
      return _unexpectedError('target_apply', projectPath);
    }
  }

  Set<AppTarget> _parseTargets(Object? value) {
    if (value is! List || value.isEmpty) {
      throw _InvalidTargetException(
        'appTargets must be a non-empty list of target names.',
      );
    }
    try {
      return value.map((v) => AppTarget.values.byName(v as String)).toSet();
    } catch (e) {
      throw _InvalidTargetException(
        'Unknown App Target in $value. Valid targets: '
        '${AppTarget.values.map((t) => t.name).join(', ')}.',
      );
    }
  }

  List<String> _names(Iterable<AppTarget> targets) =>
      targets.map((t) => t.name).toList();

  CallToolResult _notASmartworkProjectError(
    String operation,
    String projectPath,
  ) =>
      _error(
        operation: operation,
        projectPath: projectPath,
        code: 'not_a_smartwork_project',
        message: 'This is not a SmartWork-generated project. '
            'smartwork_target_plan/apply only operate on an existing '
            'SmartWork project.',
      );

  CallToolResult _error({
    required String operation,
    required String projectPath,
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
          'error': {'code': code, 'message': message},
        },
      );

  CallToolResult _unexpectedError(String operation, String projectPath) =>
      _error(
        operation: operation,
        projectPath: projectPath,
        code: 'unexpected_error',
        message: 'An unexpected error occurred while running $operation.',
      );
}

class _InvalidTargetException {
  final String message;
  _InvalidTargetException(this.message);
}
