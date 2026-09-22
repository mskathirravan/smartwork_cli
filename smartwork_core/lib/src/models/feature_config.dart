import '../validator/config_validator.dart';

class InvalidFeatureNameException implements Exception {
  final String name;

  InvalidFeatureNameException(this.name);

  @override
  String toString() =>
      'Invalid feature name "$name". Must start with a letter and contain '
      'only lowercase letters, numbers, and underscores.';
}

enum FeatureComponent {
  entity,

  repository,

  useCase,

  dataSource,

  page,

  widgets,

  tests,
}

class FeatureConfig {
  final String name;
  final Set<FeatureComponent> components;

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

  FeatureConfig({
    required this.name,
    Set<FeatureComponent>? components,
  }) : components = components ?? standardComponents {
    if (!ConfigValidator.isValidFeatureName(name)) {
      throw InvalidFeatureNameException(name);
    }
  }

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
