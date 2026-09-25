import 'project_config.dart';

/// Thrown for App Targets input that can't be parsed.
class InvalidAppTargetSelectionException implements Exception {
  /// What was wrong with the input.
  final String message;

  /// An error described by [message].
  InvalidAppTargetSelectionException(this.message);

  @override
  String toString() => message;
}

/// Parses the App Targets answer of `smartwork init` and
/// `smartwork target`.
class AppTargetSelection {
  const AppTargetSelection._();

  /// Parses comma-separated menu numbers, e.g. `1,2`. Throws
  /// [InvalidAppTargetSelectionException] if empty or invalid.
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
