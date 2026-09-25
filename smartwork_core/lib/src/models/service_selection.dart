import 'service_definition.dart';

/// Thrown for Production Services input that can't be parsed.
class InvalidServiceSelectionException implements Exception {
  /// What was wrong with the input.
  final String message;

  /// An error described by [message].
  InvalidServiceSelectionException(this.message);

  @override
  String toString() => message;
}

/// Parses the Production Services answer of `smartwork init`.
class ServiceSelection {
  const ServiceSelection._();

  /// Parses comma-separated menu numbers (e.g. `1,3,5`), `all`, or an
  /// empty answer (no services). Throws [InvalidServiceSelectionException]
  /// for anything else.
  static Set<Service> parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return {};
    }
    if (trimmed.toLowerCase() == 'all') {
      return Service.values.toSet();
    }

    final tokens = trimmed.split(',').map((t) => t.trim()).toList();
    final services = <Service>{};

    for (final token in tokens) {
      final number = int.tryParse(token);
      if (number == null || number < 1 || number > Service.values.length) {
        throw InvalidServiceSelectionException(
          'Invalid selection: "$token". Choose numbers between 1 and '
          '${Service.values.length}.',
        );
      }
      services.add(Service.values[number - 1]);
    }

    return services;
  }
}
