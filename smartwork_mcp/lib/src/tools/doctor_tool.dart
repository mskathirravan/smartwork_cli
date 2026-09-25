import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

enum DoctorCheckStatus { pass, fail, info }

final smartworkDoctorTool = Tool(
  name: 'smartwork_doctor',
  description: 'Read-only diagnostic for whether the SmartWork and Flutter '
      'environment is ready, and whether the given directory is a '
      'valid SmartWork project. Never writes a file or modifies '
      'anything.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'Directory to check for a SmartWork project. '
            'Defaults to the current directory.',
      ),
    },
  ),
);

class DoctorTool {
  final EnvironmentDoctor _environmentDoctor;
  final TargetStateDetector _detector;

  DoctorTool({
    EnvironmentDoctor? environmentDoctor,
    TargetStateDetector? detector,
  })  : _environmentDoctor = environmentDoctor ?? EnvironmentDoctor(),
        _detector = detector ?? TargetStateDetector();

  Future<CallToolResult> call(CallToolRequest request) async {
    final projectPath = request.arguments?['projectPath'] as String? ?? '.';

    try {
      final checks = <Map<String, Object?>>[];

      for (final check in await _environmentDoctor.checkEnvironment()) {
        checks.add(_check(
          check.label,
          check.inconclusive
              ? DoctorCheckStatus.info
              : check.passed
                  ? DoctorCheckStatus.pass
                  : DoctorCheckStatus.fail,
          check.detail,
        ));
      }

      checks.addAll(await _projectChecks(projectPath));

      final errors = [
        for (final check in checks)
          if (check['status'] == 'fail' && check['detail'] != null)
            check['detail'] as String,
      ];
      final success = errors.isEmpty;

      return CallToolResult(
        content: [
          TextContent(
            text: success
                ? 'All checks passed.'
                : 'Some checks failed: ${errors.join('; ')}',
          ),
        ],
        structuredContent: {
          'success': success,
          'projectPath': projectPath,
          'checks': checks,
          'errors': errors,
          'warnings': const <String>[],
        },
      );
    } catch (_) {
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text: 'An unexpected error occurred while running '
                'smartwork_doctor.',
          ),
        ],
      );
    }
  }

  Future<List<Map<String, Object?>>> _projectChecks(
    String projectPath,
  ) async {
    final result = await _detector.detect(projectPath);

    switch (result.state) {
      case TargetProjectState.empty:
      case TargetProjectState.nonFlutterProject:
        return [
          _check(
            'Flutter project',
            DoctorCheckStatus.info,
            'not inside a Flutter project',
          ),
        ];

      case TargetProjectState.flutterProject:
        return [
          _check('Flutter project', DoctorCheckStatus.pass, null),
          _check(
            'SmartWork project',
            DoctorCheckStatus.info,
            'not a SmartWork project',
          ),
        ];

      case TargetProjectState.smartworkProject:
        final config = result.existingConfig!;
        final targetChecks = <Map<String, Object?>>[
          _check('Flutter project', DoctorCheckStatus.pass, null),
          _check('SmartWork project', DoctorCheckStatus.pass, null),
          _check('Configuration valid', DoctorCheckStatus.pass, null),
          _check(
            'App Targets',
            DoctorCheckStatus.pass,
            config.orderedAppTargets.map((t) => t.displayName).join(', '),
          ),
        ];
        for (final target in config.orderedAppTargets) {
          if (!result.existingPlatforms.contains(target)) {
            targetChecks.add(_check(
              'Missing platform: ${target.platformFolder}/',
              DoctorCheckStatus.fail,
              null,
            ));
          }
        }
        targetChecks.add(_check(
          'Services',
          DoctorCheckStatus.pass,
          config.orderedServices.isEmpty
              ? '(none)'
              : config.orderedServices.map((s) => s.displayName).join(', '),
        ));
        return targetChecks;

      case TargetProjectState.malformedSmartworkProject:
        return [
          _check(
            'SmartWork project',
            DoctorCheckStatus.fail,
            'SmartWork project metadata was found but could not be read.',
          ),
          _check(
            'Configuration valid',
            DoctorCheckStatus.fail,
            result.detectionError,
          ),
        ];
    }
  }

  Map<String, Object?> _check(
    String label,
    DoctorCheckStatus status,
    String? detail,
  ) =>
      {
        'label': label,
        'status': status.name,
        if (detail != null) 'detail': detail,
      };
}
