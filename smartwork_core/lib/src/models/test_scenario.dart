enum TestType { unit, widget, integration }

enum TestScenarioStatus { covered, missing, outdated, broken, partial }

class TestScenario {
  final String feature;
  final String subject;
  final TestType type;

  final String preconditions;

  final String action;

  final String expectedResult;

  final List<String> dependencies;

  final List<String> mockRequirements;

  final List<String> coverageTargets;

  final String? existingTest;

  final TestScenarioStatus status;

  final String reason;

  TestScenario({
    required this.feature,
    required this.subject,
    required this.type,
    required this.preconditions,
    required this.action,
    required this.expectedResult,
    this.dependencies = const [],
    this.mockRequirements = const [],
    this.coverageTargets = const [],
    this.existingTest,
    required this.status,
    required this.reason,
  });

  String get label => '$subject: $preconditions — $expectedResult';

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'subject': subject,
        'type': type.name,
        'preconditions': preconditions,
        'action': action,
        'expectedResult': expectedResult,
        'dependencies': dependencies,
        'mockRequirements': mockRequirements,
        'coverageTargets': coverageTargets,
        'existingTest': existingTest,
        'status': status.name,
        'reason': reason,
      };
}
