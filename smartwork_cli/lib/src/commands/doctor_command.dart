import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

import '../version.dart';

enum DoctorCheckStatus {
  pass,

  fail,

  info,
}

class DoctorCheckResult {
  final String label;
  final DoctorCheckStatus status;

  final String? detail;

  DoctorCheckResult(this.label, this.status, {this.detail});

  String get symbol => switch (status) {
        DoctorCheckStatus.pass => '✓',
        DoctorCheckStatus.fail => '✗',
        DoctorCheckStatus.info => 'ℹ',
      };
}

class DoctorReport {
  final List<DoctorCheckResult> environment;
  final List<DoctorCheckResult> project;

  DoctorReport({required this.environment, required this.project});

  bool get allPassed => [...environment, ...project]
      .every((c) => c.status != DoctorCheckStatus.fail);
}

class DoctorCommand extends Command {
  final String projectPath;

  final EnvironmentDoctor _environmentDoctor;
  final TargetStateDetector _detector;
  final String? Function() _readVersion;

  DoctorCommand({
    this.projectPath = '.',
    ProcessRunner? runProcess,
    TargetStateDetector? detector,
    String? Function()? readVersion,
  })  : _environmentDoctor = EnvironmentDoctor(runProcess: runProcess),
        _detector = detector ?? TargetStateDetector(),
        _readVersion = readVersion ?? readSmartworkCliVersion;

  @override
  final name = 'doctor';

  @override
  final description = 'Check whether the SmartWork and Flutter '
      'environment is ready';

  @override
  Future<void> run() async {
    final report = await checkEnvironment();
    _printReport(report);
    if (!report.allPassed) exitCode = 1;
  }

  Future<DoctorReport> checkEnvironment() async {
    return DoctorReport(
      environment: await _checkEnvironment(),
      project: await _checkProject(),
    );
  }

  Future<List<DoctorCheckResult>> _checkEnvironment() async {
    final version = _readVersion();
    final results = <DoctorCheckResult>[
      DoctorCheckResult(
        'SmartWork',
        DoctorCheckStatus.pass,
        detail: version == null ? null : 'version $version',
      ),
    ];

    for (final check in await _environmentDoctor.checkEnvironment()) {
      results.add(DoctorCheckResult(
        check.label,
        check.inconclusive
            ? DoctorCheckStatus.info
            : check.passed
                ? DoctorCheckStatus.pass
                : DoctorCheckStatus.fail,
        detail: check.detail,
      ));
    }

    return results;
  }

  Future<List<DoctorCheckResult>> _checkProject() async {
    final result = await _detector.detect(projectPath);

    switch (result.state) {
      case TargetProjectState.empty:
      case TargetProjectState.nonFlutterProject:
        return [
          DoctorCheckResult(
            'Flutter project',
            DoctorCheckStatus.info,
            detail: 'not inside a Flutter project',
          ),
        ];

      case TargetProjectState.flutterProject:
        return [
          DoctorCheckResult('Flutter project', DoctorCheckStatus.pass),
          DoctorCheckResult(
            'SmartWork project',
            DoctorCheckStatus.info,
            detail: 'not a SmartWork project',
          ),
        ];

      case TargetProjectState.smartworkProject:
        return [
          DoctorCheckResult('Flutter project', DoctorCheckStatus.pass),
          DoctorCheckResult('SmartWork project', DoctorCheckStatus.pass),
          DoctorCheckResult('Configuration valid', DoctorCheckStatus.pass),
          ..._checkAppTargets(result.existingConfig!, result.existingPlatforms),
          _checkServices(result.existingConfig!),
        ];

      case TargetProjectState.malformedSmartworkProject:
        return [
          DoctorCheckResult(
            'SmartWork project',
            DoctorCheckStatus.fail,
            detail: 'SmartWork project metadata was found but could not '
                'be read.',
          ),
          DoctorCheckResult(
            'Configuration valid',
            DoctorCheckStatus.fail,
            detail: result.detectionError,
          ),
        ];
    }
  }

  List<DoctorCheckResult> _checkAppTargets(
    ProjectConfig config,
    Set<AppTarget> existingPlatforms,
  ) {
    final orderedTargets = config.orderedAppTargets;
    final results = <DoctorCheckResult>[
      DoctorCheckResult(
        'App Targets: ${orderedTargets.map((t) => t.displayName).join(', ')}',
        DoctorCheckStatus.pass,
      ),
    ];

    for (final target in orderedTargets) {
      if (!existingPlatforms.contains(target)) {
        results.add(DoctorCheckResult(
          'Missing platform: ${target.platformFolder}/',
          DoctorCheckStatus.fail,
        ));
      }
    }

    return results;
  }

  DoctorCheckResult _checkServices(ProjectConfig config) {
    final services = config.orderedServices;
    return DoctorCheckResult(
      'Services: '
      '${services.isEmpty ? '(none)' : services.map((s) => s.displayName).join(', ')}',
      DoctorCheckStatus.pass,
    );
  }

  void _printReport(DoctorReport report) {
    print('SmartWork Doctor\n');
    print('Environment');
    for (final check in report.environment) {
      _printCheck(check);
    }
    print('\nProject');
    for (final check in report.project) {
      _printCheck(check);
    }
    print('\nSummary');
    print(report.allPassed ? 'All checks passed.' : 'Some checks failed.');
  }

  void _printCheck(DoctorCheckResult check) {
    print('${check.symbol} ${check.label}');
    if (check.detail != null && check.detail!.isNotEmpty) {
      for (final line in check.detail!.split('\n')) {
        print('  $line');
      }
    }
  }
}
