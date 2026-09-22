import 'project_config.dart';

class InvalidAppTargetSelectionException implements Exception {
  final String message;

  InvalidAppTargetSelectionException(this.message);

  @override
  String toString() => message;
}

class AppTargetSelection {
  const AppTargetSelection._();

  static Set<AppTarget> parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw InvalidAppTargetSelectionException(
        'At least one target is required. '
        'Select one or more (e.g. 1,3,5).',
      );
    }

    final tokens = trimmed.split(',').map((t) => t.trim()).toList();
    final targets = <AppTarget>{};

    for (final token in tokens) {
      final number = int.tryParse(token);
      if (number == null || number < 1 || number > AppTarget.values.length) {
        throw InvalidAppTargetSelectionException(
          'Invalid selection: "$token". Choose numbers between 1 and '
          '${AppTarget.values.length}.',
        );
      }
      targets.add(AppTarget.values[number - 1]);
    }

    return targets;
  }
}
