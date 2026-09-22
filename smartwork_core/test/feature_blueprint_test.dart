import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureConfig blueprint', () {
    test('default components form a coherent standard skeleton', () {
      final feature = FeatureConfig(name: 'auth');

      expect(feature.components, FeatureConfig.standardComponents);
      expect(feature.components, contains(FeatureComponent.entity));
      expect(feature.components, contains(FeatureComponent.repository));
      expect(feature.components, contains(FeatureComponent.useCase));
      expect(feature.components, contains(FeatureComponent.dataSource));
      expect(feature.components, contains(FeatureComponent.page));
    });

    test('widgets and tests are not included by default', () {
      final feature = FeatureConfig(name: 'auth');

      expect(feature.components, isNot(contains(FeatureComponent.widgets)));
      expect(feature.components, isNot(contains(FeatureComponent.tests)));
    });

    test('accepts an explicit custom component set', () {
      final feature = FeatureConfig(
        name: 'auth',
        components: {FeatureComponent.entity, FeatureComponent.page},
      );

      expect(feature.components, {
        FeatureComponent.entity,
        FeatureComponent.page,
      });
    });

    test('accepts an empty component set (name-only feature)', () {
      final feature = FeatureConfig(name: 'auth', components: {});

      expect(feature.components, isEmpty);
    });

    test('component selection is deterministic across constructions', () {
      final first = FeatureConfig(name: 'auth');
      final second = FeatureConfig(name: 'auth');

      expect(first.components, second.components);
    });

    test('still validates the feature name (no second naming rule)', () {
      expect(
        () => FeatureConfig(name: 'Invalid-Name'),
        throwsA(isA<InvalidFeatureNameException>()),
      );
    });
  });

  group('FeatureConfig.resolveDependencies()', () {
    Set<FeatureComponent> resolve(Set<FeatureComponent> requested) =>
        FeatureConfig(name: 'auth', components: requested)
            .resolveDependencies()
            .components;

    test('a component with no dependencies resolves to itself', () {
      expect(resolve({FeatureComponent.entity}), {FeatureComponent.entity});
      expect(resolve({FeatureComponent.page}), {FeatureComponent.page});
    });

    test('a single dependency is added: dataSource requires entity', () {
      expect(resolve({FeatureComponent.dataSource}), {
        FeatureComponent.dataSource,
        FeatureComponent.entity,
      });
    });

    test(
        'a transitive dependency is added: useCase requires repository, '
        'which requires entity and dataSource', () {
      expect(resolve({FeatureComponent.useCase}), {
        FeatureComponent.useCase,
        FeatureComponent.repository,
        FeatureComponent.entity,
        FeatureComponent.dataSource,
      });
    });

    test('repository alone pulls in entity and dataSource', () {
      expect(resolve({FeatureComponent.repository}), {
        FeatureComponent.repository,
        FeatureComponent.entity,
        FeatureComponent.dataSource,
      });
    });

    test(
        'a dependency required by multiple requested components is not '
        'duplicated or double-processed', () {
      // Both repository and useCase separately require entity; resolving
      // them together must not error or loop.
      final result = resolve({
        FeatureComponent.repository,
        FeatureComponent.useCase,
      });

      expect(result, {
        FeatureComponent.repository,
        FeatureComponent.useCase,
        FeatureComponent.entity,
        FeatureComponent.dataSource,
      });
    });

    test('widgets has no dependencies and gains no unrelated additions', () {
      expect(resolve({FeatureComponent.widgets}), {FeatureComponent.widgets});
    });

    test('an empty request stays empty', () {
      expect(resolve({}), isEmpty);
    });

    test('tests requires page: a widget test needs a page to test', () {
      expect(resolve({FeatureComponent.tests}), {
        FeatureComponent.tests,
        FeatureComponent.page,
      });
    });

    test('resolution is idempotent', () {
      final once = FeatureConfig(
        name: 'auth',
        components: {FeatureComponent.useCase},
      ).resolveDependencies();
      final twice = once.resolveDependencies();

      expect(twice.components, once.components);
    });

    test('resolving the default/standard set adds nothing (regression)', () {
      final resolved = FeatureConfig(name: 'auth').resolveDependencies();

      expect(resolved.components, FeatureConfig.standardComponents);
    });

    test('resolveDependencies preserves the feature name', () {
      final resolved = FeatureConfig(
        name: 'user_profile',
        components: {FeatureComponent.repository},
      ).resolveDependencies();

      expect(resolved.name, 'user_profile');
    });

    test(
        'resolveDependencies never removes an explicitly requested '
        'component', () {
      final requested = {FeatureComponent.page, FeatureComponent.useCase};
      final resolved = resolve(requested);

      expect(resolved.containsAll(requested), isTrue);
    });
  });
}
