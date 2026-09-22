import 'service_definition.dart';

class InvalidServiceSelectionException implements Exception {
  final String message;

  InvalidServiceSelectionException(this.message);

  @override
  String toString() => message;
}

class ServiceSelection {
  const ServiceSelection._();

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
