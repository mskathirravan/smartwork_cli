import 'package:smartwork_cli/src/commands/feature_recommendations.dart';
import 'package:smartwork_cli/src/commands/project_type.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

const _predefinedTypes = [
  ProjectType.eCommerce,
  ProjectType.foodDelivery,
  ProjectType.booking,
  ProjectType.social,
  ProjectType.dashboard,
  ProjectType.eBook,
  ProjectType.finance,
];

void main() {
  group('FeatureRecommendations', () {
    for (final type in _predefinedTypes) {
      test('${type.name} has recommendations', () {
        expect(FeatureRecommendations.forType(type), isNotEmpty);
      });
    }

    test('custom returns an empty list', () {
      expect(FeatureRecommendations.forType(ProjectType.custom), isEmpty);
    });

    test(
        'every recommendation id satisfies the existing feature-name '
        'validation rules', () {
      for (final type in _predefinedTypes) {
        for (final feature in FeatureRecommendations.forType(type)) {
          expect(
            ConfigValidator.isValidFeatureName(feature.id),
            isTrue,
            reason: '"${feature.id}" for ${type.name} is not a valid '
                'feature name',
          );
        }
      }
    });

    test('every recommendation label is not empty', () {
      for (final type in _predefinedTypes) {
        for (final feature in FeatureRecommendations.forType(type)) {
          expect(feature.label, isNotEmpty);
        }
      }
    });

    test('recommendation ordering is deterministic', () {
      for (final type in _predefinedTypes) {
        final first = FeatureRecommendations.forType(type).map((f) => f.id);
        final second = FeatureRecommendations.forType(type).map((f) => f.id);
        expect(first, equals(second));
      }
    });

    test('E-Commerce matches the approved recommendation set', () {
      final ids = FeatureRecommendations.forType(ProjectType.eCommerce)
          .map((f) => f.id)
          .toList();
      expect(
        ids,
        equals([
          'authentication',
          'product_catalog',
          'product_details',
          'cart',
          'wishlist',
          'search',
          'payment',
          'orders',
          'profile',
        ]),
      );
    });
  });
}
