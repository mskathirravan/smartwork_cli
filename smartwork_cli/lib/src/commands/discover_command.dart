import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

class DiscoverCommand extends Command {
  final String projectPath;

  DiscoverCommand({this.projectPath = '.'}) {
    argParser.addFlag(
      'json',
      help: 'Print the complete ProjectKnowledge as JSON instead of a '
          'human-readable summary.',
      negatable: false,
    );
  }

  @override
  final name = 'discover';

  @override
  final description = 'Build a machine-readable understanding of an '
      'existing project (framework, platforms, architecture, state '
      'management, dependency injection, features, tests)';

  @override
  String get invocation => 'smartwork discover [--json]';

  @override
  Future<void> run() async {
    final asJson = argResults!['json'] as bool;

    try {
      final knowledge = await DiscoverLifecycle().discover(projectPath);
      if (asJson) {
        print(const JsonEncoder.withIndent('  ').convert(knowledge.toJson()));
      } else {
        _printSummary(knowledge);
      }
    } on NotAFlutterProjectException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _printSummary(ProjectKnowledge knowledge) {
    final project = knowledge.project.value;
    print('Project: ${project.name} '
        '(${project.isSmartworkProject ? 'SmartWork project' : 'Flutter project'})');

    final framework = knowledge.framework.value;
    print(_line(
      'Framework',
      'Dart ${framework.dartSdkConstraint ?? 'unknown'}, '
          'Flutter ${framework.flutterSdkConstraint ?? 'unknown'}',
      knowledge.framework.confidence,
    ));

    print(_line(
      'Platforms',
      knowledge.platforms.value.isEmpty
          ? 'none found'
          : knowledge.platforms.value.map((t) => t.displayName).join(', '),
      knowledge.platforms.confidence,
    ));

    print(_line(
      'Dependencies',
      '${knowledge.dependencies.value.length} declared',
      knowledge.dependencies.confidence,
    ));

    print(_line(
      'Architecture',
      knowledge.architecture.value?.name ?? 'unknown',
      knowledge.architecture.confidence,
    ));

    print(_line(
      'State Management',
      knowledge.stateManagement.value?.name ?? 'unknown',
      knowledge.stateManagement.confidence,
    ));

    print(_line(
      'Dependency Injection',
      knowledge.dependencyInjection.value.name,
      knowledge.dependencyInjection.confidence,
    ));

    final features = knowledge.features.value;
    print(_line(
      'Features',
      features.isEmpty
          ? 'none found'
          : '${features.length} (${features.map((f) => f.name).join(', ')})',
      knowledge.features.confidence,
    ));

    final tests = knowledge.tests.value;
    print(_line(
      'Tests',
      tests.hasTestDirectory
          ? '${tests.declaredTestingPackages.join(', ')}'
              '${tests.hasDetectedTestCalls ? ', real test calls found' : ''}'
          : 'no test/ directory found',
      knowledge.tests.confidence,
    ));
  }

  String _line(String label, String value, DiscoveryConfidence confidence) =>
      '$label: $value (${confidence.name})';
}
