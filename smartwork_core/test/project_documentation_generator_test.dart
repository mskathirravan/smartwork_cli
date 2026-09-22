import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Tests for [ProjectDocumentationGenerator] and its wiring into
/// [ProjectGenerator] — documentation for the developer building *this*
/// generated application, never documentation about SmartWork itself.
void main() {
  group('ProjectDocumentationGenerator', () {
    late ProjectConfig defaultConfig;

    setUp(() {
      defaultConfig = ProjectConfig(
        projectName: 'my_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    });

    test(
        'generates the parent README plus every focused docs/ file, '
        'keyed by their path relative to the project root', () {
      final files = ProjectDocumentationGenerator().generateAll(defaultConfig);

      expect(
          files.keys,
          unorderedEquals(<String>[
            'README.md',
            'docs/architecture.md',
            'docs/services.md',
            'docs/development.md',
            'docs/testing.md',
          ]));
    });

    test(
        'the README mentions the project name, architecture, state '
        'management, network, storage, home feature, initial features, '
        'and app targets, and links to every docs/ file', () {
      final readme = ProjectDocumentationGenerator()
          .generateAll(defaultConfig)['README.md']!;

      expect(readme, contains('my_app'));
      expect(readme, contains('Clean Architecture'));
      expect(readme, contains('BLoC'));
      expect(readme, contains('Http'));
      expect(readme, contains('SharedPreferences'));
      expect(readme, contains('`home`'));
      expect(readme, contains('`auth`'));
      expect(readme, contains('docs/architecture.md'));
      expect(readme, contains('docs/services.md'));
      expect(readme, contains('docs/development.md'));
      expect(readme, contains('docs/testing.md'));
    });

    test('unsupported configuration details are never documented anywhere', () {
      final files = ProjectDocumentationGenerator().generateAll(defaultConfig);
      final allContent = files.values.join('\n');

      expect(allContent, isNot(contains('Riverpod')));
      expect(allContent, isNot(contains('Cubit')));
      expect(allContent, isNot(contains('GetX')));
      expect(allContent, isNot(contains('Dio')));
      expect(allContent, isNot(contains('Hive')));
      expect(allContent, isNot(contains('MVVM')));
      expect(allContent, isNot(contains('MVP')));
    });

    test(
        'no SmartWork-specific documentation is generated — this is for '
        "the generated app's developer, not about SmartWork itself — and "
        'no SmartWork/AI/tool references appear anywhere', () {
      final files = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'my_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.dio,
          storage: Storage.hive,
          initialFeatures: ['auth'],
        ),
      );
      final allContent = files.values.join('\n');

      for (final forbidden in [
        'ProjectGenerator',
        'ProjectConfig',
        'FeatureContentGenerator',
        'TemplateEngine',
        'FlutterBootstrap',
        'smartwork_core',
        'smartwork_cli',
        'SmartWork',
        'smartwork ',
        'smartwork feature',
        'smartwork init',
        'smartwork target',
        'smartwork model',
        'smartwork service',
        'smartwork test',
        'Claude',
        'Anthropic',
        ' AI ',
        'artificial intelligence',
      ]) {
        expect(allContent, isNot(contains(forbidden)),
            reason: '"$forbidden" must not appear in the generated app\'s '
                'own docs');
      }
    });

    test(
        'is independent of the target directory name / package name — '
        'a pure function of ProjectConfig alone', () {
      final config = ProjectConfig(
        projectName: 'zephyr_quokka_ledger',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final first = ProjectDocumentationGenerator().generateAll(config);
      final second = ProjectDocumentationGenerator().generateAll(config);

      expect(first, second);
      expect(first['README.md'], contains('zephyr_quokka_ledger'));
    });

    group('architecture-specific folder structure (docs/architecture.md)', () {
      test('Clean Architecture documents domain/data/presentation', () {
        final content = ProjectDocumentationGenerator().generateAll(
          ProjectConfig(
            projectName: 'demo_app',
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          ),
        )['docs/architecture.md']!;

        expect(content, contains('domain/'));
        expect(content, contains('data/'));
        expect(content, contains('presentation/'));
        expect(content, contains('Presentation'));
        expect(content, contains('Domain'));
        expect(content, contains('Data'));
      });

      test(
          'MVVM documents View -> ViewModel -> Repository/Service, '
          'never Clean\'s domain/data layers', () {
        final content = ProjectDocumentationGenerator().generateAll(
          ProjectConfig(
            projectName: 'demo_app',
            architecture: Architecture.mvvm,
            stateManagement: StateManagement.riverpod,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          ),
        )['docs/architecture.md']!;

        expect(content, contains('viewmodels/'));
        expect(content, contains('ViewModel'));
        expect(content, contains('Repository / Service'));
        expect(content, isNot(contains('domain/')));
        expect(content, isNot(contains('usecases/')));
      });

      test(
          'MVP documents View -> Presenter -> Repository/Service, never '
          "Clean's domain/data layers", () {
        final content = ProjectDocumentationGenerator().generateAll(
          ProjectConfig(
            projectName: 'demo_app',
            architecture: Architecture.mvp,
            stateManagement: StateManagement.getx,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          ),
        )['docs/architecture.md']!;

        expect(content, contains('presenters/'));
        expect(content, contains('Presenter'));
        expect(content, contains('Repository / Service'));
        expect(content, isNot(contains('domain/')));
        expect(content, isNot(contains('usecases/')));
      });
    });

    test(
        'docs/services.md documents the configured network\'s '
        'environment-aware base URL behavior, without ever duplicating '
        'an actual URL value', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.dio,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      )['docs/services.md']!;

      expect(content, contains('EnvironmentManager'));
      expect(content, contains('currentBaseUrl'));
      expect(content, isNot(contains('https://')),
          reason: 'the source of truth for URLs is ApiConstants, not '
              'this document — it must never invent or duplicate one');
    });

    test(
        'docs/development.md documents Debug as a framework-level '
        'capability, never a FeatureComponent, with the configured '
        'tap-count constant referenced symbolically', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      )['docs/development.md']!;

      expect(content, contains('AppConstants.debugTapCount'));
      expect(content, contains('BLoC'));
      expect(content, isNot(contains('smartwork feature debug')));

      final debugSection = content.substring(
        content.indexOf('## Debug Tools'),
        content.indexOf('## Export and Import Conventions'),
      );
      expect(
        debugSection,
        isNot(contains('singleton')),
        reason: 'Debug has no singleton anywhere; EnvironmentManager '
            'legitimately documents itself as one elsewhere',
      );
    });

    test(
        'docs/services.md never claims a Production Service is active '
        'when none is selected', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      )['docs/services.md']!;

      expect(content,
          contains('This project has no Production Services selected.'));
      for (final service in Service.values) {
        expect(content, isNot(contains(service.className)));
      }
    });

    test(
        'docs/services.md documents selected Production Services without '
        'ever claiming a real third-party provider SDK is wired in', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          services: {Service.analytics.id, Service.crashReporting.id},
          initialFeatures: ['auth'],
        ),
      )['docs/services.md']!;

      expect(content, contains('AnalyticsService'));
      expect(content, contains('CrashReportingService'));
      // Naming providers as an explicit "never wired in" disclaimer is
      // fine — the doc must never claim one actually *is* connected.
      expect(content, contains('Provider-neutral'));
      expect(content, contains('no real third-party SDK wired in'));
      expect(content, isNot(contains('integration test')));
    });

    test(
        'docs/development.md documents the standard assets/ folders and '
        'AssetConstants', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      )['docs/development.md']!;

      expect(content, contains('Assets'));
      expect(content, contains('assets/images/'));
      expect(content, contains('assets/fonts/'));
      expect(content, contains('assets/icons/'));
      expect(content, contains('assets/animations/'));
      expect(content, contains('AssetConstants'));
    });

    test(
        'docs/development.md documents the feature export barrel '
        'convention, using the actual configured project name', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'zephyr_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      )['docs/development.md']!;

      expect(content, contains('Export and Import Conventions'));
      expect(content,
          contains('package:zephyr_app/features/<feature>/<feature>.dart'));
    });

    test('docs/development.md documents Responsive UI Guidelines', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      )['docs/development.md']!;

      expect(content, contains('Responsive UI Guidelines'));
    });

    test(
        'docs/development.md documents Accessibility unconditionally — '
        'the existing AccessibleWidget, preserved system text scaling, '
        'developer responsibility, and a real semantics testing pattern, '
        'with no compliance claim', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      )['docs/development.md']!;

      expect(content, contains('## Accessibility'));
      expect(content, contains('AccessibleWidget'));
      expect(content, contains('lib/shared/ui/accessible.dart'));
      expect(content, contains('tester.ensureSemantics()'));
      expect(content, contains('find.bySemanticsLabel'));
      expect(content, contains('your responsibility'));
      for (final claim in ['WCAG', 'ADA compliant', 'fully accessible']) {
        expect(content, isNot(contains(claim)));
      }
    });

    test(
        'docs/services.md lists the actual configured routable features, '
        'and docs/development.md documents feature add/remove keeping '
        'routing synchronized', () {
      final files = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth', 'profile'],
        ),
      );

      expect(files['docs/services.md'], contains('`/auth`'));
      expect(files['docs/services.md'], contains('`/profile`'));
      expect(files['docs/development.md'], contains('synchronized'));
      expect(files['docs/development.md'],
          isNot(contains('smartwork feature remove')));
    });

    test(
        'docs/services.md never lists Home or a reserved "debug" name '
        'as an ordinary feature route', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          homeFeatureName: 'dashboard',
          initialFeatures: ['dashboard', 'debug', 'auth'],
        ),
      )['docs/services.md']!;

      expect(content, isNot(contains('`/dashboard`')));
      expect(content, isNot(contains('`/debug`')));
      expect(content, contains('`/auth`'));
    });

    test('the README overview table reflects the configured app targets', () {
      final content = ProjectDocumentationGenerator().generateAll(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          appTargets: {AppTarget.android, AppTarget.ios},
          initialFeatures: ['auth'],
        ),
      )['README.md']!;

      expect(content, contains('App Targets'));
      expect(content, contains(AppTarget.android.displayName));
      expect(content, contains(AppTarget.ios.displayName));
    });

    test(
        'docs/testing.md documents API-dependent tests and coverage '
        'without mentioning WireMock implementation internals or any '
        'SmartWork command', () {
      final content = ProjectDocumentationGenerator()
          .generateAll(defaultConfig)['docs/testing.md']!;

      expect(content, contains('API-Dependent Tests'));
      expect(content, contains('WireMock'));
      expect(content, contains('scripts/wiremock/README.md'));
      expect(content, contains('Coverage'));
      expect(content, contains('flutter test --coverage'));
      expect(content, isNot(contains('smartwork test')));
      expect(content, isNot(contains('SmartWork')));
    });
  });

  group('ProjectGenerator documentation wiring', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_docs_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'generate() alone never writes README.md — documentation is '
        'only ever written by the separate generateDocumentation() '
        'call, gated on validation passing (see the Generation '
        'Pipeline milestone)', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      expect(File(paths.readmeFile).existsSync(), isFalse);
      expect(Directory(paths.docs).existsSync(), isFalse);
    });

    test(
        'generateDocumentation() writes README.md plus every docs/ '
        "file, matching ProjectDocumentationGenerator's own output", () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.getx,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      await generator.generate();
      await generator.generateDocumentation();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      final expected = ProjectDocumentationGenerator().generateAll(config);

      for (final entry in expected.entries) {
        final writtenFile = File(path.join(tempDir.path, entry.key));
        expect(writtenFile.existsSync(), isTrue,
            reason: '${entry.key} should have been written');
        expect(writtenFile.readAsStringSync(), entry.value);
      }
      expect(File(paths.readmeFile).existsSync(), isTrue);
      expect(Directory(paths.docs).existsSync(), isTrue);
    });
  });
}
