enum TestUpdateConfidence { high, medium, low }

enum TestUpdateKind {
  methodCallArguments,
  constructorArguments,
  staleIdentifier,
}

class TestUpdate {
  final String testFile;

  final String subject;

  final TestUpdateKind kind;
  final TestUpdateConfidence confidence;

  final String reason;

  final String oldSnippet;

  final String? newSnippet;

  final int? startOffset;
  final int? endOffset;

  TestUpdate({
    required this.testFile,
    required this.subject,
    required this.kind,
    required this.confidence,
    required this.reason,
    required this.oldSnippet,
    this.newSnippet,
    this.startOffset,
    this.endOffset,
  });

  String? get diff {
    final newText = newSnippet;
    if (newText == null) return null;
    final oldLines = oldSnippet.split('\n');
    final newLines = newText.split('\n');
    final buffer = StringBuffer();
    for (final line in oldLines) {
      buffer.writeln('- $line');
    }
    for (final line in newLines) {
      buffer.writeln('+ $line');
    }
    return buffer.toString().trimRight();
  }

  Map<String, dynamic> toJson() => {
        'testFile': testFile,
        'subject': subject,
        'kind': kind.name,
        'confidence': confidence.name,
        'reason': reason,
        'oldSnippet': oldSnippet,
        'newSnippet': newSnippet,
        'diff': diff,
      };
}

class TestMaintenancePlan {
  final String feature;
  final List<TestUpdate> updates;

  TestMaintenancePlan({required this.feature, required this.updates});

  List<TestUpdate> get highConfidence =>
      updates.where((u) => u.confidence == TestUpdateConfidence.high).toList();

  List<TestUpdate> get mediumConfidence => updates
      .where((u) => u.confidence == TestUpdateConfidence.medium)
      .toList();

  List<TestUpdate> get lowConfidence =>
      updates.where((u) => u.confidence == TestUpdateConfidence.low).toList();

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'updates': updates.map((u) => u.toJson()).toList(),
        'summary': {
          'highConfidenceCount': highConfidence.length,
          'mediumConfidenceCount': mediumConfidence.length,
          'lowConfidenceCount': lowConfidence.length,
        },
      };
}
