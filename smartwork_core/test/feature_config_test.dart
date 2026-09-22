import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureConfig', () {
    test('accepts a valid snake_case name', () {
      final config = FeatureConfig(name: 'auth');
      expect(config.name, 'auth');
    });

    test('accepts a valid multi-word snake_case name', () {
      final config = FeatureConfig(name: 'user_profile');
      expect(config.name, 'user_profile');
    });

    test('rejects a name with uppercase letters', () {
      expect(
        () => FeatureConfig(name: 'Auth'),
        throwsA(isA<InvalidFeatureNameException>()),
      );
    });

    test('rejects a name with hyphens', () {
      expect(
        () => FeatureConfig(name: 'payment-history'),
        throwsA(isA<InvalidFeatureNameException>()),
      );
    });

    test('rejects a name starting with a digit', () {
      expect(
        () => FeatureConfig(name: '1auth'),
        throwsA(isA<InvalidFeatureNameException>()),
      );
    });

    test('rejects an empty name', () {
      expect(
        () => FeatureConfig(name: ''),
        throwsA(isA<InvalidFeatureNameException>()),
      );
    });

    test('uses the same validation rule as ConfigValidator.initialFeatures',
        () {
      // FeatureConfig must not diverge from the project-level feature
      // name rule already enforced for ProjectConfig.initialFeatures.
      const name = 'user_profile';
      expect(ConfigValidator.isValidFeatureName(name), isTrue);
      expect(() => FeatureConfig(name: name), returnsNormally);
    });

    test('naming transformation via FeatureNames matches feature name', () {
      final config = FeatureConfig(name: 'user_profile');
      final names = FeatureNames(config.name);

      expect(names.snake, 'user_profile');
      expect(names.pascal, 'UserProfile');
    });
  });
}
