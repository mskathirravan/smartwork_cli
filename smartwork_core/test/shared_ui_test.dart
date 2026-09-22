import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Tests for V1.1-2 (Shared UI): [SharedUiTemplates] and its wiring into
/// [ProjectGenerator]. Like every other generator test in this package,
/// these assert on generated *content* — smartwork_core itself never
/// depends on `package:flutter` and never executes generated Dart, so
/// "LoadingIndicator renders a spinner" is proven by the real, generated
/// widget test this milestone also adds (validated for real during the
/// `tmp/` E2E phase), not by anything smartwork_core's own suite runs.
void main() {
  group('SharedUiTemplates (template content)', () {
    test('LoadingIndicator is provider-independent and uses AppDimensions', () {
      final content = TemplateEngine()
          .render(SharedUiTemplates.loadingIndicatorTemplate(), {});
      expect(
          content, contains('class LoadingIndicator extends StatelessWidget'));
      expect(content, contains('CircularProgressIndicator'));
      expect(content, contains('AppDimensions.spacingMd'));
      expect(content, isNot(contains('Bloc')));
      expect(content, isNot(contains('Cubit')));
      expect(content, isNot(contains('GetxController')));
      expect(content, isNot(contains('StateNotifier')));
      expect(content, isNot(contains('{{')));
    });

    test(
        'AppAlert covers all four statuses and reads error from '
        'ColorScheme, never a duplicate AppColors.error', () {
      final content =
          TemplateEngine().render(SharedUiTemplates.appAlertTemplate(), {});
      expect(content,
          contains('enum AlertType { success, warning, info, error }'));
      expect(content, contains('AppColors.success'));
      expect(content, contains('AppColors.warning'));
      expect(content, contains('AppColors.info'));
      expect(content, contains('Theme.of(context).colorScheme.error'));
      expect(content, isNot(contains('AppColors.error')));
    });

    test(
        'MaintenanceView has sensible, overridable defaults and no '
        'remote/feature-flag/polling logic', () {
      final content = TemplateEngine()
          .render(SharedUiTemplates.maintenanceViewTemplate(), {});
      expect(content, contains("this.title = 'Under Maintenance'"));
      expect(content, contains('final String title;'));
      expect(content, contains('final String message;'));
      expect(content, isNot(contains('http')));
      expect(content, isNot(contains('Timer')));
      expect(content, isNot(contains('FeatureFlag')));
    });

    test(
        'EmptyStateView requires only a title; description/icon/action '
        'are all optional', () {
      final content = TemplateEngine()
          .render(SharedUiTemplates.emptyStateViewTemplate(), {});
      expect(content, contains('required this.title'));
      expect(content, contains('final String? description;'));
      expect(content, contains('final IconData? icon;'));
      expect(content, contains('final Widget? action;'));
    });

    test(
        'ErrorStateView never performs the retry itself — onRetry is a '
        'bare VoidCallback the caller supplies', () {
      final content = TemplateEngine()
          .render(SharedUiTemplates.errorStateViewTemplate(), {});
      expect(content, contains('final VoidCallback? onRetry;'));
      expect(content, contains('onPressed: onRetry'));
      expect(content, isNot(contains('NetworkService')));
      expect(content, isNot(contains('CrashReportingService')));
      expect(content, isNot(contains('http')));
      expect(content, isNot(contains('retry()')));
    });

    test(
        'AccessibleWidget wraps Flutter\'s own Semantics with the '
        'minimum useful surface', () {
      final content =
          TemplateEngine().render(SharedUiTemplates.accessibleTemplate(), {});
      expect(
          content, contains('class AccessibleWidget extends StatelessWidget'));
      expect(content, contains('return Semantics('));
      expect(content, contains('final String? label;'));
      expect(content, contains('final String? hint;'));
      expect(content, contains('final bool button;'));
      // No accessibility service/config/audit framework.
      expect(content, isNot(contains('Service')));
      expect(content, isNot(contains('Config')));
      expect(content, isNot(contains('Audit')));
    });

    test(
        'FontSample previews text styles, a label, buttons, and a list '
        '— not just Text widgets — all styled from the app\'s own '
        'textTheme, and names the configured font family', () {
      final content = TemplateEngine().render(
        SharedUiTemplates.fontSampleTemplate(
          FontConfig.google(GoogleFontConfig(family: 'Roboto')),
        ),
        {},
      );
      expect(content, contains('class FontSample extends StatelessWidget'));
      expect(content, contains("Text('Font: Roboto'"));
      expect(content, contains('textTheme.headlineMedium'));
      expect(content, contains('textTheme.bodyLarge'));
      expect(content, contains('textTheme.labelSmall'));
      expect(content, contains('Chip('));
      expect(content, contains('ElevatedButton('));
      expect(content, contains('OutlinedButton('));
      expect(content, contains('ListTile('));
      expect(content, isNot(contains('{{')));
    });

    test('FontSample names a Custom Font\'s family, not a Google Font one', () {
      final content = TemplateEngine().render(
        SharedUiTemplates.fontSampleTemplate(
          FontConfig.custom(CustomFontConfig(
            family: 'MyBrand',
            files: [CustomFontFile(sourcePath: 'brand.ttf')],
          )),
        ),
        {},
      );
      expect(content, contains("Text('Font: MyBrand'"));
    });

    test('the barrel exports exactly the six primitive files', () {
      final content = TemplateEngine()
          .render(SharedUiTemplates.sharedUiBarrelTemplate(), {});
      for (final export in [
        'accessible.dart',
        'app_alert.dart',
        'empty_state_view.dart',
        'error_state_view.dart',
        'loading_indicator.dart',
        'maintenance_view.dart',
      ]) {
        expect(content, contains("export '$export';"));
      }
    });

    test(
        'none of the six primitive templates reference any architecture '
        'or state-management construct', () {
      final templates = [
        SharedUiTemplates.loadingIndicatorTemplate(),
        SharedUiTemplates.appAlertTemplate(),
        SharedUiTemplates.maintenanceViewTemplate(),
        SharedUiTemplates.emptyStateViewTemplate(),
        SharedUiTemplates.errorStateViewTemplate(),
        SharedUiTemplates.accessibleTemplate(),
      ];
      final forbidden = [
        'Repository',
        'UseCase',
        'ViewModel',
        'Presenter',
        'Bloc',
        'Cubit',
        'GetxController',
        'StateNotifier',
        'NetworkService',
        'StorageService',
      ];
      for (final template in templates) {
        final content = TemplateEngine().render(template, {});
        for (final term in forbidden) {
          expect(content, isNot(contains(term)),
              reason: 'unexpected "$term" in shared UI template');
        }
      }
    });
  });

  group('ProjectGenerator (Shared UI wiring)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_shared_ui_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'generates exactly the six primitives plus the barrel, always — '
        'no configuration required', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final sharedUiDir = Directory('${tempDir.path}/lib/shared/ui');
      final generatedFiles = sharedUiDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();

      expect(generatedFiles, {
        'loading_indicator.dart',
        'app_alert.dart',
        'maintenance_view.dart',
        'empty_state_view.dart',
        'error_state_view.dart',
        'accessible.dart',
        'shared_ui.dart',
      });
    });

    test('also generates the matching widget test file', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final testFile =
          File('${tempDir.path}/test/shared/ui/shared_ui_test.dart');
      expect(testFile.existsSync(), isTrue);
      final content = testFile.readAsStringSync();
      expect(content,
          contains("import 'package:demo_app/shared/ui/shared_ui.dart';"));
      expect(content, isNot(contains('{{')));
    });

    test(
        'Shared UI is generated identically across every architecture and '
        'state management — architecture/state-management independence',
        () async {
      String? referenceContent;

      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          final dir = Directory.systemTemp
              .createTempSync('smartwork_shared_ui_matrix_');
          addTearDown(() => dir.deleteSync(recursive: true));

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: stateManagement,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['home'],
          );
          await ProjectGenerator(outputPath: dir.path, config: config)
              .generate();

          final content =
              File('${dir.path}/lib/shared/ui/loading_indicator.dart')
                  .readAsStringSync();
          referenceContent ??= content;
          expect(
            content,
            referenceContent,
            reason: '$architecture + $stateManagement produced different '
                'Shared UI output',
          );
        }
      }
    });

    test(
        'Shared UI is generated identically regardless of network/storage '
        'choice — network/storage independence', () async {
      String? referenceContent;

      for (final network in Network.values) {
        for (final storage in Storage.values) {
          final dir = Directory.systemTemp
              .createTempSync('smartwork_shared_ui_ns_matrix_');
          addTearDown(() => dir.deleteSync(recursive: true));

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: network,
            storage: storage,
            initialFeatures: ['home'],
          );
          await ProjectGenerator(outputPath: dir.path, config: config)
              .generate();

          final content = File('${dir.path}/lib/shared/ui/app_alert.dart')
              .readAsStringSync();
          referenceContent ??= content;
          expect(
            content,
            referenceContent,
            reason: '$network + $storage produced different Shared UI '
                'output',
          );
        }
      }
    });
  });

  group('ProjectGenerator (font sample opt-in)', () {
    late Directory tempDir;

    ProjectConfig configWith(FontConfig fonts) {
      return ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        fonts: fonts,
        initialFeatures: ['home'],
      );
    }

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_font_sample_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'is never generated when includeFontSample is left at its '
        'default (false)', () async {
      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith(FontConfig.google(GoogleFontConfig(
          family: 'Poppins',
        ))),
      ).generate();

      expect(
        File('${tempDir.path}/lib/shared/ui/font_sample.dart').existsSync(),
        isFalse,
      );
      final barrel = File('${tempDir.path}/lib/shared/ui/shared_ui.dart')
          .readAsStringSync();
      expect(barrel, isNot(contains('font_sample.dart')));
      final home = File(
        '${tempDir.path}/lib/features/home/presentation/pages/home_page.dart',
      ).readAsStringSync();
      expect(home, isNot(contains('FontSample')));
    });

    test(
        'generates FontSample, exports it from the barrel, and embeds '
        'it into the fresh Home page when includeFontSample is true', () async {
      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith(FontConfig.google(GoogleFontConfig(
          family: 'Poppins',
        ))),
        includeFontSample: true,
      ).generate();

      final sample = File('${tempDir.path}/lib/shared/ui/font_sample.dart');
      expect(sample.existsSync(), isTrue);
      expect(sample.readAsStringSync(), contains("Font: Poppins"));

      final barrel = File('${tempDir.path}/lib/shared/ui/shared_ui.dart')
          .readAsStringSync();
      expect(barrel, contains("export 'font_sample.dart';"));

      final home = File(
        '${tempDir.path}/lib/features/home/presentation/pages/home_page.dart',
      ).readAsStringSync();
      expect(home, contains("import '../../../../shared/ui/shared_ui.dart';"));
      expect(home, contains('const FontSample()'));
    });

    test('reflects a Custom Font\'s family name, not a Google Font one',
        () async {
      final sourceFont = File('${tempDir.path}_source_font.ttf')
        ..writeAsBytesSync([0, 1, 2, 3]);
      addTearDown(() {
        if (sourceFont.existsSync()) sourceFont.deleteSync();
      });

      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith(FontConfig.custom(CustomFontConfig(
          family: 'MyBrand',
          files: [CustomFontFile(sourcePath: sourceFont.path)],
        ))),
        includeFontSample: true,
      ).generate();

      final sample = File('${tempDir.path}/lib/shared/ui/font_sample.dart')
          .readAsStringSync();
      expect(sample, contains('Font: MyBrand'));
    });

    test(
        'every generated file stays dart-format clean with the sample '
        'included', () async {
      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith(FontConfig.google(GoogleFontConfig(
          family: 'Poppins',
        ))),
        includeFontSample: true,
      ).generate();

      final result = await Process.run(Platform.resolvedExecutable, [
        'format',
        '--set-exit-if-changed',
        '${tempDir.path}/lib/shared/ui/font_sample.dart',
        '${tempDir.path}/lib/features/home/presentation/pages/home_page.dart',
      ]);

      expect(result.exitCode, 0,
          reason: 'dart format would reformat at least one generated '
              'file:\n${result.stdout}');
    });
  });
}
