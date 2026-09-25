import '../validator/config_validator.dart';

/// Thrown for a feature name that isn't a lowercase snake_case identifier.
class InvalidFeatureNameException implements Exception {
  /// The rejected name.
  final String name;

  /// An error for the rejected [name].
  InvalidFeatureNameException(this.name);

  @override
  String toString() =>
      'Invalid feature name "$name". Must start with a letter and contain '
      'only lowercase letters, numbers, and underscores.';
}

/// A piece of a feature that `smartwork feature --components` can generate.
enum FeatureComponent {
  /// The domain entity.
  entity,

  /// The repository (interface and implementation).
  repository,

  /// The use case.
  useCase,

  /// The data source.
  dataSource,

  /// The page (screen).
  page,

  /// The feature's widgets folder.
  widgets,

  /// The feature's tests.
  tests,
}

/// A feature to generate: its name and which components to include.
class FeatureConfig {
  /// The feature's snake_case name, e.g. `order_history`.
  final String name;

  /// The components to generate.
  final Set<FeatureComponent> components;

  /// What a feature includes when no components are given.
  static const Set<FeatureComponent> standardComponents = {
    FeatureComponent.entity,
    FeatureComponent.repository,
    FeatureComponent.useCase,
    FeatureComponent.dataSource,
    FeatureComponent.page,
  };

  static const Map<FeatureComponent, Set<FeatureComponent>> _dependencies = {
    FeatureComponent.repository: {
      FeatureComponent.entity,
      FeatureComponent.dataSource,
    },
    FeatureComponent.useCase: {
      FeatureComponent.entity,
      FeatureComponent.repository,
    },
    FeatureComponent.dataSource: {
      FeatureComponent.entity,
    },
    FeatureComponent.tests: {
      FeatureComponent.page,
    },
  };

  /// A feature [name] with [components] (default [standardComponents]).
  /// Throws [InvalidFeatureNameException] for an invalid name.
  FeatureConfig({
    required this.name,
    Set<FeatureComponent>? components,
  }) : components = components ?? standardComponents {
    if (!ConfigValidator.isValidFeatureName(name)) {
      throw InvalidFeatureNameException(name);
    }
  }

  /// A copy that also includes every component the chosen ones need
  /// (e.g. a repository needs an entity and a data source).
  FeatureConfig resolveDependencies() {
    final resolved = <FeatureComponent>{...components};
    var changed = true;
    while (changed) {
      changed = false;
      for (final component in [...resolved]) {
        final required = _dependencies[component] ?? const {};
        for (final dependency in required) {
          if (resolved.add(dependency)) {
            changed = true;
          }
        }
      }
    }
    return FeatureConfig(name: name, components: resolved);
  }
}
