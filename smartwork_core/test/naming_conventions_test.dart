import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('NamingConventions', () {
    group('toPascalCase', () {
      test('converts simple lowercase to PascalCase', () {
        expect(NamingConventions.toPascalCase('home'), equals('Home'));
      });

      test('converts snake_case to PascalCase', () {
        expect(
          NamingConventions.toPascalCase('home_page'),
          equals('HomePage'),
        );
      });

      test('converts hyphenated names to PascalCase', () {
        expect(
          NamingConventions.toPascalCase('product-detail'),
          equals('ProductDetail'),
        );
      });

      test('converts space-separated names to PascalCase', () {
        expect(
          NamingConventions.toPascalCase('user profile'),
          equals('UserProfile'),
        );
      });

      test('converts camelCase to PascalCase', () {
        expect(
          NamingConventions.toPascalCase('homePage'),
          equals('HomePage'),
        );
      });

      test('converts mixed formats to PascalCase', () {
        expect(
          NamingConventions.toPascalCase('home_page_detail'),
          equals('HomePageDetail'),
        );
      });

      test('handles already PascalCase input', () {
        expect(NamingConventions.toPascalCase('HomePage'), equals('HomePage'));
      });

      test('handles multiple consecutive separators', () {
        expect(
          NamingConventions.toPascalCase('home__page'),
          equals('HomePage'),
        );
      });

      test('handles mixed underscores and hyphens', () {
        expect(
          NamingConventions.toPascalCase('home_product-detail'),
          equals('HomeProductDetail'),
        );
      });
    });

    group('toSnakeCase', () {
      test('converts PascalCase to snake_case', () {
        expect(NamingConventions.toSnakeCase('Home'), equals('home'));
      });

      test('converts PascalCase multi-word to snake_case', () {
        expect(
          NamingConventions.toSnakeCase('HomePage'),
          equals('home_page'),
        );
      });

      test('converts hyphenated names to snake_case', () {
        expect(
          NamingConventions.toSnakeCase('product-detail'),
          equals('product_detail'),
        );
      });

      test('converts space-separated names to snake_case', () {
        expect(
          NamingConventions.toSnakeCase('user profile'),
          equals('user_profile'),
        );
      });

      test('handles already snake_case input', () {
        expect(
          NamingConventions.toSnakeCase('home_page'),
          equals('home_page'),
        );
      });

      test('converts camelCase to snake_case', () {
        expect(
          NamingConventions.toSnakeCase('homePage'),
          equals('home_page'),
        );
      });

      test('handles multiple consecutive separators', () {
        expect(
          NamingConventions.toSnakeCase('home__page'),
          equals('home_page'),
        );
      });

      test('handles mixed separators', () {
        expect(
          NamingConventions.toSnakeCase('home-page_detail'),
          equals('home_page_detail'),
        );
      });

      test('removes leading/trailing underscores', () {
        expect(
          NamingConventions.toSnakeCase('_homePage_'),
          equals('home_page'),
        );
      });
    });
  });

  group('FeatureNames', () {
    test('stores original feature name', () {
      final names = FeatureNames('home');
      expect(names.original, equals('home'));
    });

    test('computes snake case variant', () {
      final names = FeatureNames('homePage');
      expect(names.snake, equals('home_page'));
    });

    test('computes pascal case variant', () {
      final names = FeatureNames('home_page');
      expect(names.pascal, equals('HomePage'));
    });

    test('fromFeature factory works', () {
      final names = FeatureNames.fromFeature('user_profile');
      expect(names.original, equals('user_profile'));
      expect(names.snake, equals('user_profile'));
      expect(names.pascal, equals('UserProfile'));
    });

    test('toString provides useful output', () {
      final names = FeatureNames('home');
      expect(
        names.toString(),
        contains('original: home'),
      );
      expect(
        names.toString(),
        contains('pascal: Home'),
      );
    });

    test('handles complex feature names', () {
      final names = FeatureNames('user_profile_settings');
      expect(names.snake, equals('user_profile_settings'));
      expect(names.pascal, equals('UserProfileSettings'));
    });

    test('caches computed values', () {
      final names = FeatureNames('home_page');
      final snake1 = names.snake;
      final snake2 = names.snake;
      expect(identical(snake1, snake2), isTrue);
    });
  });
}
