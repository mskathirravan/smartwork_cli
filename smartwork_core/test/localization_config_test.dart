import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Localization (V1.1-6): [LocalizationConfig] model behavior,
/// [ProjectConfig.localization] serialization, and [ConfigValidator]
/// localization rules. Real generated-source/pubspec/resource behavior
/// is covered in `project_generator_test.dart`/
/// `pubspec_generator_test.dart`/`main_dart_generator_test.dart`.
void main() {
  ProjectConfig baseConfig({LocalizationConfig? localization}) {
    return ProjectConfig(
      projectName: 'demo_app',
      architecture: Architecture.cleanArchitecture,
      stateManagement: StateManagement.bloc,
      network: Network.http,
      storage: Storage.sharedPreferences,
      localization: localization,
      initialFeatures: ['home'],
    );
  }

  group('LocalizationConfig defaults', () {
    test(
        'ProjectConfig defaults to LocalizationConfig.disabled when '
        'omitted', () {
      final config = baseConfig();
      expect(config.localization.enabled, isFalse);
      expect(config.localization.supportedLocales, isEmpty);
      expect(config.localization.defaultLocale, isNull);
    });

    test('LocalizationConfig.enabled sets supportedLocales/defaultLocale', () {
      final localization = LocalizationConfig.enabled(
        supportedLocales: ['en', 'fr'],
        defaultLocale: 'en',
      );
      expect(localization.enabled, isTrue);
      expect(localization.supportedLocales, ['en', 'fr']);
      expect(localization.defaultLocale, 'en');
    });
  });

  group('orderedLocales', () {
    test('places defaultLocale first, preserving the rest\'s order', () {
      final localization = LocalizationConfig.enabled(
        supportedLocales: ['en', 'fr', 'de'],
        defaultLocale: 'de',
      );
      expect(localization.orderedLocales, ['de', 'en', 'fr']);
    });

    test('is a no-op when defaultLocale is already first', () {
      final localization = LocalizationConfig.enabled(
        supportedLocales: ['en', 'fr'],
        defaultLocale: 'en',
      );
      expect(localization.orderedLocales, ['en', 'fr']);
    });

    test('returns supportedLocales unchanged when disabled', () {
      expect(LocalizationConfig.disabled().orderedLocales, isEmpty);
    });
  });

  group('Serialization (ProjectConfig.toYaml/fromYaml)', () {
    test('round-trips disabled', () {
      final restored = ProjectConfig.fromYaml(baseConfig().toYaml());
      expect(restored.localization.enabled, isFalse);
    });

    test('round-trips enabled with multiple locales', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr', 'de'],
          defaultLocale: 'fr',
        ),
      );

      final restored = ProjectConfig.fromYaml(config.toYaml());

      expect(restored.localization.enabled, isTrue);
      expect(restored.localization.supportedLocales, ['en', 'fr', 'de']);
      expect(restored.localization.defaultLocale, 'fr');
    });

    test('round-trips a country-qualified locale', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['pt', 'pt_BR'],
          defaultLocale: 'pt_BR',
        ),
      );

      final restored = ProjectConfig.fromYaml(config.toYaml());

      expect(restored.localization.supportedLocales, ['pt', 'pt_BR']);
      expect(restored.localization.defaultLocale, 'pt_BR');
    });

    test(
        'fromYaml defaults to LocalizationConfig.disabled when the '
        '"localization" key is absent — every .smartwork/project.yaml '
        'written before V1.1-6', () {
      final yaml = baseConfig().toYaml()..remove('localization');
      final restored = ProjectConfig.fromYaml(yaml);
      expect(restored.localization.enabled, isFalse);
    });

    test(
        'toYaml always includes a "localization" key, matching every '
        'other field\'s "always present" convention', () {
      expect(baseConfig().toYaml(), contains('localization'));
    });
  });

  group('ConfigValidator: localization', () {
    test('disabled is always valid', () {
      final errors = ConfigValidator.validate(baseConfig());
      expect(
          errors.map((e) => e.toString()), isNot(contains(contains('ocale'))));
    });

    test('a valid single-locale configuration produces no errors', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        ),
      );
      expect(ConfigValidator.validate(config), isEmpty);
    });

    test('a valid multi-locale configuration produces no errors', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr', 'de'],
          defaultLocale: 'en',
        ),
      );
      expect(ConfigValidator.validate(config), isEmpty);
    });

    test(
        'a valid country-qualified configuration (with its base '
        'language present) produces no errors', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'pt', 'pt_BR'],
          defaultLocale: 'en',
        ),
      );
      expect(ConfigValidator.validate(config), isEmpty);
    });

    test('enabled with no supported locales is rejected', () {
      final config = baseConfig(
        localization:
            LocalizationConfig.enabled(supportedLocales: [], defaultLocale: ''),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()),
          contains(contains('no supported locales')));
    });

    test('a default locale not among the supported locales is rejected', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr'],
          defaultLocale: 'de',
        ),
      );
      final errors = ConfigValidator.validate(config);
      expect(
        errors.map((e) => e.toString()),
        contains(contains('must be one of the supported locales')),
      );
    });

    test('a malformed locale value is rejected', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'not-a-locale'],
          defaultLocale: 'en',
        ),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()),
          contains(contains('Invalid locale')));
    });

    test('a duplicate supported locale is rejected', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr', 'en'],
          defaultLocale: 'en',
        ),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()),
          contains(contains('Duplicate supported locale')));
    });

    test(
        'a country-qualified locale without its base language is '
        'rejected (a real flutter gen-l10n requirement)', () {
      final config = baseConfig(
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'pt_BR'],
          defaultLocale: 'en',
        ),
      );
      final errors = ConfigValidator.validate(config);
      expect(
        errors.map((e) => e.toString()),
        contains(contains('requires its base language "pt"')),
      );
    });
  });

  group('LocalizationSelection.parseSupportedLocales', () {
    test('parses a single locale', () {
      expect(LocalizationSelection.parseSupportedLocales('en'), ['en']);
    });

    test('parses multiple comma-separated locales, preserving order', () {
      expect(
        LocalizationSelection.parseSupportedLocales('en,fr,de'),
        ['en', 'fr', 'de'],
      );
    });

    test('tolerates surrounding whitespace around tokens', () {
      expect(
        LocalizationSelection.parseSupportedLocales('en,  fr,   de'),
        ['en', 'fr', 'de'],
      );
    });

    test('accepts country-qualified locales', () {
      expect(
        LocalizationSelection.parseSupportedLocales('pt,pt_BR,zh_CN'),
        ['pt', 'pt_BR', 'zh_CN'],
      );
    });

    test('normalizes a duplicate locale rather than rejecting it', () {
      expect(
        LocalizationSelection.parseSupportedLocales('en,fr,en'),
        ['en', 'fr'],
      );
    });

    test('empty input is rejected', () {
      expect(
        () => LocalizationSelection.parseSupportedLocales(''),
        throwsA(isA<InvalidLocaleSelectionException>()),
      );
    });

    test('blank input (only commas/whitespace) is rejected', () {
      expect(
        () => LocalizationSelection.parseSupportedLocales(' , , '),
        throwsA(isA<InvalidLocaleSelectionException>()),
      );
    });

    test('a malformed token is rejected, naming the invalid one', () {
      try {
        LocalizationSelection.parseSupportedLocales('en,not-a-locale');
        fail('expected an exception');
      } on InvalidLocaleSelectionException catch (e) {
        expect(e.toString(), contains('not-a-locale'));
      }
    });

    test('exception messages are printable, non-empty strings', () {
      try {
        LocalizationSelection.parseSupportedLocales('');
        fail('expected an exception');
      } on InvalidLocaleSelectionException catch (e) {
        expect(e.toString(), isNotEmpty);
      }
    });
  });

  group('LocalizationSelection.validateDefaultLocale', () {
    test('returns the candidate unchanged when it is supported', () {
      expect(
        LocalizationSelection.validateDefaultLocale('fr', ['en', 'fr', 'de']),
        'fr',
      );
    });

    test('rejects a candidate not in the supported list', () {
      expect(
        () => LocalizationSelection.validateDefaultLocale(
          'es',
          ['en', 'fr'],
        ),
        throwsA(isA<InvalidLocaleSelectionException>()),
      );
    });

    test('rejects an empty candidate', () {
      expect(
        () => LocalizationSelection.validateDefaultLocale('', ['en']),
        throwsA(isA<InvalidLocaleSelectionException>()),
      );
    });

    test('the exception names the valid choices', () {
      try {
        LocalizationSelection.validateDefaultLocale('es', ['en', 'fr']);
        fail('expected an exception');
      } on InvalidLocaleSelectionException catch (e) {
        expect(e.toString(), contains('en'));
        expect(e.toString(), contains('fr'));
      }
    });
  });
}
