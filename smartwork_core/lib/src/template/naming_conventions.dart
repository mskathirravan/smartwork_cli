class NamingConventions {
  static String toPascalCase(String input) {
    final normalized = input.replaceAll(RegExp(r'[-\s_]+'), ' ');

    final words = normalized.split(' ').where((w) => w.isNotEmpty);

    return words.map((word) {
      final expanded = word.replaceAllMapped(
        RegExp(r'(?<!^)(?=[A-Z])'),
        (match) => ' ',
      );

      return expanded
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
          .join();
    }).join();
  }

  static String toSnakeCase(String input) {
    var result = input.replaceAllMapped(
      RegExp(r'(?<!^)(?=[A-Z])'),
      (match) => '_',
    );

    result = result.replaceAll(RegExp(r'[-\s]+'), '_');

    result = result.toLowerCase();

    result = result.replaceAll(RegExp(r'_+'), '_');

    result = result.trim().replaceAll(RegExp(r'^_|_$'), '');

    return result;
  }

  static String toCamelCase(String input) {
    final pascal = toPascalCase(input);
    if (pascal.isEmpty) return pascal;
    return pascal[0].toLowerCase() + pascal.substring(1);
  }

  static String asIs(String input) => input;
}

class FeatureNames {
  final String original;

  late final String snake = NamingConventions.toSnakeCase(original);

  late final String pascal = NamingConventions.toPascalCase(original);

  FeatureNames(this.original);

  factory FeatureNames.fromFeature(String featureName) {
    return FeatureNames(featureName);
  }

  @override
  String toString() => 'FeatureNames(original: $original, '
      'snake: $snake, pascal: $pascal)';
}
