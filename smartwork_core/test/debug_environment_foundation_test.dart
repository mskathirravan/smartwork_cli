import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Tests for the Debug V1 + Routing Foundation + Environment/Theme
/// milestone: [DebugTemplates], [EnvironmentTemplates],
/// [ThemeServiceTemplates], [RoutingGenerator], [DebugFeatureGenerator],
/// and the constants they depend on ([ConstantsTemplates]'s
/// `AppConstants`/`ApiConstants`/`StorageConstants`/`AppColors`).
///
/// Like every other generator test in this package, these assert on the
/// generated *content* of a real project written to a temp directory —
/// smartwork_core itself never depends on `package:flutter` and never
/// executes generated Dart, so "the Debug singleton counts taps
/// correctly" is verified by asserting the generated source implements
/// that logic, not by running it. Genuine end-to-end behavioral proof
/// (compiles, analyzes, `flutter test` passes) happens separately in the
/// `tmp/` generated-project validation this milestone also requires.
void main() {
  group('Constants (AppConstants/ApiConstants/StorageConstants)', () {
    test('AppConstants.debugTapCount is exactly 10', () {
      final content = TemplateEngine().render(
        ConstantsTemplates.appConstantsTemplate(),
        {'projectName': 'demo_app'},
      );
      expect(content, contains('static const int debugTapCount = 10;'));
    });

    test('ApiConstants declares real prod/stage/dev scaffold URLs', () {
      final content = TemplateEngine()
          .render(ConstantsTemplates.apiConstantsTemplate(), {});
      expect(content,
          contains("static const String prodUrl = 'https://api.example.com';"));
      expect(
        content,
        contains(
            "static const String stageUrl = 'https://staging-api.example.com';"),
      );
      expect(
          content,
          contains(
              "static const String devUrl = 'https://dev-api.example.com';"));
    });

    test('StorageConstants declares the real environment and theme keys', () {
      final content = TemplateEngine()
          .render(ConstantsTemplates.storageConstantsTemplate(), {});
      expect(
          content,
          contains(
              "static const String environmentKey = 'debug_environment';"));
      expect(content,
          contains("static const String themeModeKey = 'debug_theme_mode';"));
    });

    test('AppColors declares concrete Light/Dark seed color defaults', () {
      final content =
          TemplateEngine().render(ConstantsTemplates.appColorsTemplate(), {});
      expect(content, contains("import 'package:flutter/material.dart';"));
      expect(content, contains("import '../utilities/color_hex.dart';"));
      expect(content, contains('static final Color lightSeedColor'));
      expect(content, contains('static final Color darkSeedColor'));
    });

    test(
        'AppColors declares one semantic color per status, with no '
        'Material ColorScheme duplication', () {
      final content =
          TemplateEngine().render(ConstantsTemplates.appColorsTemplate(), {});
      expect(content, contains('static final Color success'));
      expect(content, contains('static final Color warning'));
      expect(content, contains('static final Color info'));
      // Deliberately not duplicated: Material's own ColorScheme already
      // owns these roles — see the template's own doc comment.
      expect(content, isNot(contains('static final Color primary')));
      expect(content, isNot(contains('static final Color secondary')));
      expect(content, isNot(contains('static final Color error')));
      expect(content, isNot(contains('static final Color textPrimary')));
      expect(content, isNot(contains('static final Color textSecondary')));
      expect(content, isNot(contains('static final Color border')));
      expect(content, isNot(contains('static final Color divider')));
    });

    test('AppColors declares an overlay scrim and two distinct shadow colors',
        () {
      final content =
          TemplateEngine().render(ConstantsTemplates.appColorsTemplate(), {});
      expect(content, contains('static final Color overlay'));
      expect(content, contains('static final Color shadow ='));
      expect(content, contains('static final Color shadowDark ='));
    });

    test('AppColors declares no duplicate color constant names', () {
      final content =
          TemplateEngine().render(ConstantsTemplates.appColorsTemplate(), {});
      final names = RegExp(r'static final Color (\w+)')
          .allMatches(content)
          .map((m) => m.group(1))
          .toList();
      expect(names.toSet(), hasLength(names.length),
          reason: 'every color constant name must be declared exactly once');
    });

    test(
        'AppDimensions declares the content width, screen padding, an '
        'ascending spacing scale, and an ascending radius scale', () {
      final content = TemplateEngine()
          .render(ConstantsTemplates.appDimensionsTemplate(), {});
      expect(content, contains('static const double maxContentWidth = 640;'));
      expect(content, contains('static const double screenPadding = 16;'));
      for (final name in [
        'spacingXs',
        'spacingSm',
        'spacingMd',
        'spacingLg',
        'spacingXl',
        'radiusSmall',
        'radiusMedium',
        'radiusLarge',
      ]) {
        expect(content, contains('static const double $name ='),
            reason: '$name missing');
      }
    });

    test('AppDimensions declares no duplicate dimension constant names', () {
      final content = TemplateEngine()
          .render(ConstantsTemplates.appDimensionsTemplate(), {});
      final names = RegExp(r'static const double (\w+)')
          .allMatches(content)
          .map((m) => m.group(1))
          .toList();
      expect(names.toSet(), hasLength(names.length),
          reason: 'every dimension constant name must be declared exactly '
              'once');
    });

    test(
        'ScreenDimensions is a BuildContext extension reading '
        'MediaQuery.sizeOf, never a static constant', () {
      final content = TemplateEngine()
          .render(ConstantsTemplates.screenDimensionsTemplate(), {});
      expect(content, contains('extension ScreenDimensions on BuildContext'));
      expect(content, contains('MediaQuery.sizeOf(this).width'));
      expect(content, contains('MediaQuery.sizeOf(this).height'));
      expect(content, isNot(contains('static double')));
    });
  });

  group('Environment', () {
    test('Environment enum has exactly prod/stage/dev with UI labels', () {
      final content = TemplateEngine()
          .render(EnvironmentTemplates.environmentTemplate(), {});
      expect(content, contains('enum Environment { prod, stage, dev }'));
      expect(content, contains("return 'PROD';"));
      expect(content, contains("return 'STAGE';"));
      expect(content, contains("return 'DEV';"));
    });

    test('EnvironmentUrls maps every Environment to its ApiConstants URL', () {
      final content = TemplateEngine()
          .render(EnvironmentTemplates.environmentUrlsTemplate(), {});
      expect(content, contains('case Environment.prod:'));
      expect(content, contains('return ApiConstants.prodUrl;'));
      expect(content, contains('case Environment.stage:'));
      expect(content, contains('return ApiConstants.stageUrl;'));
      expect(content, contains('case Environment.dev:'));
      expect(content, contains('return ApiConstants.devUrl;'));
    });

    group('EnvironmentManager (storage-independent, via StorageService)', () {
      late String content;

      setUpAll(() {
        content = TemplateEngine()
            .render(EnvironmentTemplates.environmentManagerTemplate(), {});
      });

      test('is a singleton defaulting to Environment.prod', () {
        expect(content, contains('EnvironmentManager._();'));
        expect(
          content,
          contains(
              'static final EnvironmentManager instance = EnvironmentManager._();'),
        );
        expect(content, contains('Environment _current = Environment.prod;'));
      });

      test('currentBaseUrl resolves through EnvironmentUrls', () {
        expect(
          content,
          contains(
              'String get currentBaseUrl => EnvironmentUrls.forEnvironment(_current);'),
        );
      });

      test(
          'load() reads the persisted identifier through StorageService, '
          'defaulting to prod when nothing is stored — never a direct '
          'shared_preferences/hive dependency', () {
        expect(content,
            contains("import '../../services/storage/storage_service.dart';"));
        expect(
            content,
            contains(
                'StorageService.instance.getString(\n      StorageConstants.environmentKey,\n    );'));
        expect(content, contains('orElse: () => Environment.prod,'));
        expect(
            content,
            isNot(contains(
                "import 'package:shared_preferences/shared_preferences.dart';")));
        expect(content, isNot(contains("import 'package:hive")));
      });

      test(
          'setEnvironment() switches current and persists only the '
          'identifier, through StorageService, never a URL', () {
        expect(
          content,
          contains(
              'Future<void> setEnvironment(Environment environment) async {'),
        );
        expect(content, contains('_current = environment;'));
        expect(
          content,
          contains(
              'StorageService.instance.setString(\n      StorageConstants.environmentKey,\n      environment.name,\n    );'),
        );
        expect(
            content,
            isNot(contains(
                'setString(StorageConstants.environmentKey, environment.toString()')));
      });

      test('no unresolved placeholders', () {
        expect(content, isNot(contains('{{')));
      });
    });
  });

  group('Theme', () {
    group('ThemeService (storage-independent, via StorageService)', () {
      late String content;

      setUpAll(() {
        content = TemplateEngine()
            .render(ThemeServiceTemplates.themeServiceTemplate(), {});
      });

      test('is a ChangeNotifier singleton defaulting to ThemeMode.system', () {
        expect(content, contains('class ThemeService extends ChangeNotifier'));
        expect(content, contains('ThemeService._();'));
        expect(
          content,
          contains('static final ThemeService instance = ThemeService._();'),
        );
        expect(content, contains('ThemeMode _current = ThemeMode.system;'));
      });

      test(
          'load() reads the persisted mode through StorageService, '
          'defaulting to system', () {
        expect(content, contains("import '../storage/storage_service.dart';"));
        expect(
            content,
            contains(
                'StorageService.instance.getString(\n      StorageConstants.themeModeKey,\n    );'));
        expect(content, contains('orElse: () => ThemeMode.system,'));
      });

      test(
          'setTheme() switches current, persists the identifier through '
          'StorageService, and notifies listeners so the app rebuilds '
          'without a restart', () {
        expect(
            content, contains('Future<void> setTheme(ThemeMode mode) async {'));
        expect(content, contains('_current = mode;'));
        expect(
          content,
          contains(
              'StorageService.instance.setString(\n      StorageConstants.themeModeKey,\n      mode.name,\n    );'),
        );
        expect(content, contains('notifyListeners();'));
      });

      test('no unresolved placeholders', () {
        expect(content, isNot(contains('{{')));
      });
    });

    group('AppTheme (ThemeData construction, separate from ThemeService)', () {
      late String content;

      setUpAll(() {
        content = TemplateEngine().render(
          ThemeServiceTemplates.appThemeTemplate(FontConfig.none()),
          {},
        );
      });

      test('is a plain, non-instantiable ThemeData provider', () {
        expect(content, contains('class AppTheme {'));
        expect(content, contains('const AppTheme._();'));
      });

      test('light/dark are computed from AppColors, never a literal Color', () {
        expect(
          content,
          contains('seedColor: AppColors.lightSeedColor'),
        );
        expect(
          content,
          contains('seedColor: AppColors.darkSeedColor,'),
        );
        expect(content, contains('brightness: Brightness.dark,'));
        expect(content, isNot(contains('Colors.blue')));
      });

      test('imports the constants barrel, never ThemeService itself', () {
        expect(
            content, contains("import '../../core/constants/constants.dart';"));
        expect(content, isNot(contains('theme_service.dart')));
      });

      test('no unresolved placeholders', () {
        expect(content, isNot(contains('{{')));
      });
    });
  });

  group('Debug draft/apply/cancel state, per StateManagement', () {
    group('BLoC (state/debug_bloc.dart)', () {
      late String stateContent;
      late String blocContent;

      setUpAll(() {
        stateContent = TemplateEngine().render(
          DebugTemplates.debugStateTemplate(toCoreDir: '../../../core'),
          {},
        );
        blocContent =
            TemplateEngine().render(DebugTemplates.debugBlocTemplate(), {});
      });

      test('DebugState is a plain, immutable draft value', () {
        expect(stateContent, contains('class DebugState {'));
        expect(stateContent, contains('final Environment draftEnvironment;'));
        expect(stateContent, contains('final ThemeMode draftThemeMode;'));
        expect(stateContent, isNot(contains('{{')));
      });

      test(
          'DebugBloc seeds its initial state from the currently active '
          'Environment/Theme', () {
        expect(blocContent,
            contains('class DebugBloc extends Bloc<DebugEvent, DebugState>'));
        expect(
          blocContent,
          contains('draftEnvironment: EnvironmentManager.instance.'
              'currentEnvironment,'),
        );
        expect(
          blocContent,
          contains('draftThemeMode: ThemeService.instance.currentThemeMode,'),
        );
      });

      test('DebugEnvironmentChanged/DebugThemeChanged mutate only the draft',
          () {
        expect(blocContent, contains('on<DebugEnvironmentChanged>('));
        expect(blocContent, contains('on<DebugThemeChanged>('));
        expect(
            blocContent,
            contains('emit(state.copyWith(draftEnvironment: event.'
                'environment))'));
        expect(blocContent,
            contains('emit(state.copyWith(draftThemeMode: event.mode))'));
      });

      test(
          'cancel() reverts the draft to the active values without '
          'persisting anything', () {
        final cancelBody = blocContent.substring(
          blocContent.indexOf('void cancel()'),
          blocContent.indexOf('Future<void> apply()'),
        );
        expect(
            cancelBody,
            contains('draftEnvironment: EnvironmentManager.instance.'
                'currentEnvironment,'));
        expect(
            cancelBody,
            contains(
                'draftThemeMode: ThemeService.instance.currentThemeMode,'));
        expect(cancelBody, isNot(contains('setEnvironment')));
        expect(cancelBody, isNot(contains('setTheme')));
      });

      test('apply() persists both the environment and theme', () {
        final applyBody =
            blocContent.substring(blocContent.indexOf('Future<void> apply()'));
        expect(
            applyBody,
            contains('await EnvironmentManager.instance.setEnvironment('
                'state.draftEnvironment);'));
        expect(
            applyBody,
            contains('await ThemeService.instance.setTheme(state.'
                'draftThemeMode);'));
      });

      test('no unresolved placeholders', () {
        expect(blocContent, isNot(contains('{{')));
      });
    });

    group('Cubit (state/debug_cubit.dart)', () {
      late String content;

      setUpAll(() {
        content =
            TemplateEngine().render(DebugTemplates.debugCubitTemplate(), {});
      });

      test(
          'DebugCubit seeds its initial state from the currently active '
          'Environment/Theme', () {
        expect(content, contains('class DebugCubit extends Cubit<DebugState>'));
        expect(
          content,
          contains('draftEnvironment: EnvironmentManager.instance.'
              'currentEnvironment,'),
        );
        expect(
          content,
          contains('draftThemeMode: ThemeService.instance.currentThemeMode,'),
        );
      });

      test('changeEnvironment/changeTheme mutate only the draft', () {
        expect(
          content,
          contains('void changeEnvironment(Environment environment) {\n'
              '    emit(state.copyWith(draftEnvironment: environment));\n'
              '  }'),
        );
        expect(
          content,
          contains('void changeTheme(ThemeMode mode) {\n'
              '    emit(state.copyWith(draftThemeMode: mode));\n'
              '  }'),
        );
      });

      test(
          'cancel() reverts the draft to the active values without '
          'persisting anything', () {
        final cancelBody = content.substring(
          content.indexOf('void cancel()'),
          content.indexOf('Future<void> apply()'),
        );
        expect(
            cancelBody,
            contains('draftEnvironment: EnvironmentManager.instance.'
                'currentEnvironment,'));
        expect(
            cancelBody,
            contains(
                'draftThemeMode: ThemeService.instance.currentThemeMode,'));
        expect(cancelBody, isNot(contains('setEnvironment')));
        expect(cancelBody, isNot(contains('setTheme')));
      });

      test('apply() persists both the environment and theme', () {
        final applyBody =
            content.substring(content.indexOf('Future<void> apply()'));
        expect(
            applyBody,
            contains('await EnvironmentManager.instance.setEnvironment('
                'state.draftEnvironment);'));
        expect(
            applyBody,
            contains('await ThemeService.instance.setTheme(state.'
                'draftThemeMode);'));
      });

      test('no unresolved placeholders', () {
        expect(content, isNot(contains('{{')));
      });
    });

    group('GetX (presentation/getx/debug_controller.dart, Clean only)', () {
      late String content;

      setUpAll(() {
        content = TemplateEngine()
            .render(DebugTemplates.debugGetxControllerTemplate(), {});
      });

      test(
          'DebugController seeds its .obs fields from the currently '
          'active Environment/Theme', () {
        expect(
            content, contains('class DebugController extends GetxController'));
        expect(
          content,
          contains('final draftEnvironment = EnvironmentManager.instance.'
              'currentEnvironment.obs;'),
        );
        expect(
          content,
          contains('final draftThemeMode = ThemeService.instance.'
              'currentThemeMode.obs;'),
        );
      });

      test('changeEnvironment/changeTheme mutate only the draft', () {
        expect(
          content,
          contains('void changeEnvironment(Environment environment) {\n'
              '    draftEnvironment.value = environment;\n'
              '  }'),
        );
        expect(
          content,
          contains('void changeTheme(ThemeMode mode) {\n'
              '    draftThemeMode.value = mode;\n'
              '  }'),
        );
      });

      test(
          'cancel() reverts the draft to the active values without '
          'persisting anything', () {
        final cancelBody = content.substring(
          content.indexOf('void cancel()'),
          content.indexOf('Future<void> apply()'),
        );
        expect(
            cancelBody,
            contains('draftEnvironment.value = EnvironmentManager.instance.'
                'currentEnvironment;'));
        expect(
            cancelBody,
            contains('draftThemeMode.value = ThemeService.instance.'
                'currentThemeMode;'));
        expect(cancelBody, isNot(contains('setEnvironment')));
        expect(cancelBody, isNot(contains('setTheme')));
      });

      test('apply() persists both the environment and theme', () {
        final applyBody =
            content.substring(content.indexOf('Future<void> apply()'));
        expect(
            applyBody,
            contains('await EnvironmentManager.instance.setEnvironment('
                'draftEnvironment.value);'));
        expect(
            applyBody,
            contains('await ThemeService.instance.setTheme(draftThemeMode.'
                'value);'));
      });

      test('no unresolved placeholders', () {
        expect(content, isNot(contains('{{')));
      });
    });

    group('Riverpod (presentation/providers/debug_provider.dart, Clean)', () {
      late String content;

      setUpAll(() {
        content = TemplateEngine()
            .render(DebugTemplates.debugRiverpodProviderTemplateClean(), {});
      });

      test(
          'DebugNotifier seeds its initial state from the currently '
          'active Environment/Theme', () {
        expect(content,
            contains('class DebugNotifier extends StateNotifier<DebugState>'));
        expect(
          content,
          contains('draftEnvironment: EnvironmentManager.instance.'
              'currentEnvironment,'),
        );
        expect(
          content,
          contains('draftThemeMode: ThemeService.instance.currentThemeMode,'),
        );
        expect(
            content,
            contains('final debugProvider = '
                'StateNotifierProvider<DebugNotifier, DebugState>((ref) {'));
      });

      test('changeEnvironment/changeTheme mutate only the draft', () {
        expect(
          content,
          contains('void changeEnvironment(Environment environment) {\n'
              '    state = state.copyWith(draftEnvironment: environment);\n'
              '  }'),
        );
        expect(
          content,
          contains('void changeTheme(ThemeMode mode) {\n'
              '    state = state.copyWith(draftThemeMode: mode);\n'
              '  }'),
        );
      });

      test(
          'cancel() reverts the draft to the active values without '
          'persisting anything', () {
        final cancelBody = content.substring(
          content.indexOf('void cancel()'),
          content.indexOf('Future<void> apply()'),
        );
        expect(
            cancelBody,
            contains('draftEnvironment: EnvironmentManager.instance.'
                'currentEnvironment,'));
        expect(
            cancelBody,
            contains(
                'draftThemeMode: ThemeService.instance.currentThemeMode,'));
        expect(cancelBody, isNot(contains('setEnvironment')));
        expect(cancelBody, isNot(contains('setTheme')));
      });

      test('apply() persists both the environment and theme', () {
        final applyBody =
            content.substring(content.indexOf('Future<void> apply()'));
        expect(
            applyBody,
            contains('await EnvironmentManager.instance.setEnvironment('
                'state.draftEnvironment);'));
        expect(
            applyBody,
            contains('await ThemeService.instance.setTheme(state.'
                'draftThemeMode);'));
      });

      test('no unresolved placeholders', () {
        expect(content, isNot(contains('{{')));
      });
    });
  });

  group('PushTestService (independent of Apply/Cancel)', () {
    test('is a concrete scaffold with no real push provider dependency', () {
      final content =
          TemplateEngine().render(DebugTemplates.pushTestServiceTemplate(), {});
      expect(content, contains('class PushTestService {'));
      expect(content,
          contains('Future<void> sendTest({required Duration delay}) async {'));
      expect(content, contains('await Future<void>.delayed(delay);'));
      expect(content, isNot(contains('firebase')));
      expect(content, isNot(contains('Firebase')));
      expect(content, isNot(contains('apns')));
      expect(content, isNot(contains('APNs')));
      expect(content, isNot(contains('fcm')));
      expect(content, isNot(contains('FCM')));
    });
  });

  group('Routing (RoutingGenerator)', () {
    test(
        'Home is "/" and Debug is "/debug", resolved by a native '
        'onGenerateRoute switch', () {
      final content = RoutingGenerator().generate(homeFeatureName: 'home');
      expect(content, contains("static const String home = '/';"));
      expect(content, contains("static const String debug = '/debug';"));
      expect(
          content,
          contains(
              'static Route<dynamic> onGenerateRoute(RouteSettings settings) {'));
      expect(content, contains('case debug:'));
      expect(
          content,
          contains(
              'return MaterialPageRoute(builder: (_) => const DebugPage());'));
      expect(content, contains('case home:'));
      expect(content, isNot(contains('{{')));
    });

    test('honors a configurable homeFeatureName end-to-end', () {
      final content = RoutingGenerator()
          .generate(homeFeatureName: 'dashboard', otherFeatures: []);
      expect(content,
          contains("import '../../features/dashboard/dashboard.dart';"));
      expect(
        content,
        contains(
            'return MaterialPageRoute(builder: (_) => const DashboardPage());'),
      );
      expect(content, isNot(contains('HomePage')));
    });

    test(
        'imports Debug through its public barrel, architecture-'
        'independent — never an architecture-specific internal path', () {
      final content = RoutingGenerator().generate(homeFeatureName: 'home');
      expect(content, contains("import '../../features/debug/debug.dart';"));
      expect(content, isNot(contains('presentation/pages/debug_page')));
      expect(content, isNot(contains('views/debug_page')));
    });
  });

  group(
      'DebugFeatureGenerator (architecture + state-management-specific '
      'Debug screen)', () {
    late Directory tempDir;
    late ProjectPaths paths;
    late FileWriter fileWriter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_debug_gen_');
      paths = ProjectPaths(projectRoot: tempDir.path);
      fileWriter = FileWriter();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'always writes the architecture/state-management-independent '
        'push test service file', () async {
      await DebugFeatureGenerator().generate(
        Architecture.cleanArchitecture,
        StateManagement.bloc,
        paths,
        fileWriter,
      );

      expect(File(paths.featuresDebugPushTestServiceFile).existsSync(), isTrue);
    });

    test(
        'the Debug screen is responsive-safe: content is centered and '
        'width-capped via AppDimensions.maxContentWidth, for every '
        'architecture and every state management', () async {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          final dir = Directory.systemTemp
              .createTempSync('smartwork_debug_responsive_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final scopedPaths = ProjectPaths(projectRoot: dir.path);

          await DebugFeatureGenerator().generate(
            architecture,
            stateManagement,
            scopedPaths,
            FileWriter(),
          );

          final pageFile = switch (architecture) {
            Architecture.cleanArchitecture =>
              scopedPaths.featuresDebugPageFileClean,
            Architecture.mvvm => scopedPaths.featuresDebugPageFileMvvm,
            Architecture.mvp => scopedPaths.featuresDebugPageFileMvp,
          };
          final content = File(pageFile).readAsStringSync();

          expect(content, contains("constants/constants.dart';"),
              reason: '$architecture + $stateManagement');
          expect(content, contains('Center('),
              reason: '$architecture + $stateManagement');
          expect(content, contains('ConstrainedBox('),
              reason: '$architecture + $stateManagement');
          expect(content, contains('AppDimensions.maxContentWidth'),
              reason: '$architecture + $stateManagement');
          expect(content, isNot(contains('{{')),
              reason: '$architecture + $stateManagement');
          for (final line in content.split('\n')) {
            expect(line.length, lessThanOrEqualTo(80),
                reason: '$architecture + $stateManagement has a line dart '
                    'format would rewrap, which fails the "smartwork '
                    'init" Format validation phase: "$line"');
          }
        }
      }
    });

    test(
        'the Apply button\'s confirmation SnackBar is present and dart '
        'format-canonical for every architecture and every state '
        'management — regression for a real "smartwork init" Format '
        'validation failure caused by the SnackBar wrapping differently '
        'at each state management\'s indentation depth', () async {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          final dir =
              Directory.systemTemp.createTempSync('smartwork_debug_snackbar_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final scopedPaths = ProjectPaths(projectRoot: dir.path);

          await DebugFeatureGenerator().generate(
            architecture,
            stateManagement,
            scopedPaths,
            FileWriter(),
          );

          final pageFile = switch (architecture) {
            Architecture.cleanArchitecture =>
              scopedPaths.featuresDebugPageFileClean,
            Architecture.mvvm => scopedPaths.featuresDebugPageFileMvvm,
            Architecture.mvp => scopedPaths.featuresDebugPageFileMvp,
          };
          final content = File(pageFile).readAsStringSync();

          expect(
            content,
            contains("ScaffoldMessenger.of(context).showSnackBar("),
            reason: '$architecture + $stateManagement',
          );
          expect(
            content,
            contains("Text('Changes applied.')"),
            reason: '$architecture + $stateManagement',
          );
        }
      }
    });

    test('Clean + BLoC writes DebugPage wired to state/debug_bloc.dart',
        () async {
      await DebugFeatureGenerator().generate(
        Architecture.cleanArchitecture,
        StateManagement.bloc,
        paths,
        fileWriter,
      );

      expect(File(paths.featuresDebugPageFileClean).existsSync(), isTrue);
      expect(
        File(paths.featuresDebugFileAt(['state', 'debug_bloc.dart']))
            .existsSync(),
        isTrue,
      );
      final content = File(paths.featuresDebugPageFileClean).readAsStringSync();
      expect(content, contains('class DebugPage extends StatefulWidget'));
      expect(content, contains("import '../../state/debug_bloc.dart';"));
      expect(content, contains('final DebugBloc _bloc = DebugBloc();'));
      expect(content, isNot(contains('{{')));
    });

    test('Clean + Cubit writes DebugPage wired to state/debug_cubit.dart',
        () async {
      await DebugFeatureGenerator().generate(
        Architecture.cleanArchitecture,
        StateManagement.cubit,
        paths,
        fileWriter,
      );

      final content = File(paths.featuresDebugPageFileClean).readAsStringSync();
      expect(content, contains("import '../../state/debug_cubit.dart';"));
      expect(content, contains('final DebugCubit _cubit = DebugCubit();'));
    });

    test(
        'Clean + GetX writes DebugPage wired to '
        'presentation/getx/debug_controller.dart', () async {
      await DebugFeatureGenerator().generate(
        Architecture.cleanArchitecture,
        StateManagement.getx,
        paths,
        fileWriter,
      );

      expect(
        File(paths.featuresDebugFileAt(
            ['presentation', 'getx', 'debug_controller.dart'])).existsSync(),
        isTrue,
      );
      final content = File(paths.featuresDebugPageFileClean).readAsStringSync();
      expect(content, contains("import '../getx/debug_controller.dart';"));
      expect(content,
          contains('final DebugController _controller = DebugController();'));
    });

    test(
        'Clean + Riverpod writes DebugPage wired to '
        'presentation/providers/debug_provider.dart', () async {
      await DebugFeatureGenerator().generate(
        Architecture.cleanArchitecture,
        StateManagement.riverpod,
        paths,
        fileWriter,
      );

      expect(
        File(paths.featuresDebugFileAt(
            ['presentation', 'providers', 'debug_provider.dart'])).existsSync(),
        isTrue,
      );
      expect(
        File(paths.featuresDebugFileAt(
            ['presentation', 'providers', 'debug_state.dart'])).existsSync(),
        isTrue,
      );
      final content = File(paths.featuresDebugPageFileClean).readAsStringSync();
      expect(content, contains("import '../providers/debug_provider.dart';"));
      expect(content, contains('final DebugNotifier _notifier = '));
    });

    test(
        'Send Test Notification calls PushTestService directly, '
        'independent of the Apply/Cancel draft lifecycle', () async {
      await DebugFeatureGenerator().generate(
        Architecture.cleanArchitecture,
        StateManagement.bloc,
        paths,
        fileWriter,
      );

      final content = File(paths.featuresDebugPageFileClean).readAsStringSync();
      final pushCallSite =
          content.substring(content.indexOf('ElevatedButton('));
      expect(pushCallSite, contains('_pushTestService.sendTest('));
      expect(
        pushCallSite.substring(
            0, pushCallSite.indexOf('Send Test Notification')),
        isNot(contains('.apply()')),
        reason: 'sending a test notification must not go through apply()',
      );
      expect(
        pushCallSite.substring(
            0, pushCallSite.indexOf('Send Test Notification')),
        isNot(contains('.cancel()')),
        reason: 'sending a test notification must not go through cancel()',
      );
    });

    for (final stateManagement in StateManagement.values) {
      test(
          'MVVM + $stateManagement writes a View + ViewModel pair, never '
          'a one-off Debug architecture', () async {
        await DebugFeatureGenerator().generate(
          Architecture.mvvm,
          stateManagement,
          paths,
          fileWriter,
        );

        expect(File(paths.featuresDebugPageFileMvvm).existsSync(), isTrue);
        expect(File(paths.featuresDebugViewModelFileMvvm).existsSync(), isTrue);

        final pageContent =
            File(paths.featuresDebugPageFileMvvm).readAsStringSync();
        expect(pageContent, contains('class DebugPage extends StatefulWidget'));

        final viewModelContent =
            File(paths.featuresDebugViewModelFileMvvm).readAsStringSync();
        expect(viewModelContent, contains('class DebugViewModel'));

        switch (stateManagement) {
          case StateManagement.bloc:
            expect(pageContent,
                contains("import '../viewmodels/debug_view_model.dart';"));
            expect(pageContent, contains('_viewModel.bloc'));
            expect(viewModelContent,
                contains('final DebugBloc bloc = DebugBloc();'));
          case StateManagement.cubit:
            expect(pageContent,
                contains("import '../viewmodels/debug_view_model.dart';"));
            expect(pageContent, contains('_viewModel.cubit'));
            expect(viewModelContent,
                contains('final DebugCubit cubit = DebugCubit();'));
          case StateManagement.getx:
            expect(pageContent,
                contains("import '../viewmodels/debug_view_model.dart';"));
            expect(viewModelContent,
                contains('class DebugViewModel extends GetxController'));
            expect(pageContent, isNot(contains('_viewModel.bloc')));
            expect(pageContent, isNot(contains('_viewModel.cubit')));
          case StateManagement.riverpod:
            // Riverpod's real logic lives entirely in
            // providers/debug_provider.dart, and the page reaches it
            // directly — the ViewModel stays the same plain, state-
            // management-agnostic placeholder a regular MVVM+Riverpod
            // feature's ViewModel already is, and the page never
            // imports it at all.
            expect(pageContent, contains('final DebugNotifier _notifier = '));
            expect(
              File(paths.featuresDebugFileAt(
                  ['providers', 'debug_provider.dart'])).existsSync(),
              isTrue,
            );
        }
      });

      test(
          'MVP + $stateManagement writes a View + Presenter pair, never '
          'a one-off Debug architecture', () async {
        await DebugFeatureGenerator().generate(
          Architecture.mvp,
          stateManagement,
          paths,
          fileWriter,
        );

        expect(File(paths.featuresDebugPageFileMvp).existsSync(), isTrue);
        expect(File(paths.featuresDebugPresenterFileMvp).existsSync(), isTrue);

        final pageContent =
            File(paths.featuresDebugPageFileMvp).readAsStringSync();
        expect(pageContent, contains('class DebugPage extends StatefulWidget'));

        final presenterContent =
            File(paths.featuresDebugPresenterFileMvp).readAsStringSync();
        expect(presenterContent, contains('class DebugPresenter'));

        switch (stateManagement) {
          case StateManagement.bloc:
            expect(pageContent,
                contains("import '../presenters/debug_presenter.dart';"));
            expect(pageContent, contains('_presenter.bloc'));
            expect(presenterContent,
                contains('final DebugBloc bloc = DebugBloc();'));
          case StateManagement.cubit:
            expect(pageContent,
                contains("import '../presenters/debug_presenter.dart';"));
            expect(pageContent, contains('_presenter.cubit'));
            expect(presenterContent,
                contains('final DebugCubit cubit = DebugCubit();'));
          case StateManagement.getx:
            expect(pageContent,
                contains("import '../presenters/debug_presenter.dart';"));
            expect(presenterContent,
                contains('class DebugPresenter extends GetxController'));
          case StateManagement.riverpod:
            expect(pageContent, contains('final DebugNotifier _notifier = '));
            expect(
              File(paths.featuresDebugFileAt(
                  ['providers', 'debug_provider.dart'])).existsSync(),
              isTrue,
            );
        }
      });
    }

    test(
        'every relative import the generated Debug files declare '
        'resolves to a file that actually exists, for every architecture '
        'and every state management', () async {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          final dir =
              Directory.systemTemp.createTempSync('smartwork_debug_resolve_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final archPaths = ProjectPaths(projectRoot: dir.path);

          // Debug's files reference core/environment/, core/constants/,
          // and services/theme/, exactly like a real project already
          // has by the time ProjectGenerator reaches
          // DebugFeatureGenerator.
          File(archPaths.coreEnvironmentManagerFile)
            ..parent.createSync(recursive: true)
            ..writeAsStringSync('class EnvironmentManager {}\n');
          File(archPaths.coreEnvironmentFile)
              .writeAsStringSync('enum Environment { prod, stage, dev }\n');
          File(archPaths.coreConstantsBarrelFile)
            ..parent.createSync(recursive: true)
            ..writeAsStringSync('class AppConstants {}\n');
          File(archPaths.servicesThemeServiceFile)
            ..parent.createSync(recursive: true)
            ..writeAsStringSync('class ThemeService {}\n');

          await DebugFeatureGenerator().generate(
            architecture,
            stateManagement,
            archPaths,
            FileWriter(),
          );

          for (final file in Directory(archPaths.featuresDebug)
              .listSync(recursive: true)
              .whereType<File>()) {
            final content = file.readAsStringSync();
            for (final match
                in RegExp(r"import '(\.\./[^']+)';").allMatches(content)) {
              final resolved = path.normalize(
                path.join(file.parent.path, match.group(1)!),
              );
              expect(
                File(resolved).existsSync(),
                isTrue,
                reason: '$architecture + $stateManagement: ${file.path} '
                    'imports ${match.group(1)} which does not exist',
              );
            }
          }
        }
      }
    });
  });

  group('End-to-end: Home is the initial route, Debug resolves through it', () {
    for (final architecture in Architecture.values) {
      test(
          '$architecture: a fully generated project wires Home as '
          'initialRoute and Debug as a resolvable named route', () async {
        final dir =
            Directory.systemTemp.createTempSync('smartwork_routing_e2e_');
        addTearDown(() => dir.deleteSync(recursive: true));

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: architecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: [],
        );

        await ProjectGenerator(outputPath: dir.path, config: config).generate();

        final paths = ProjectPaths(projectRoot: dir.path);
        final mainContent = File(paths.mainDartFile).readAsStringSync();
        expect(mainContent, contains('initialRoute: AppRouter.home'));
        expect(mainContent,
            contains('onGenerateRoute: AppRouter.onGenerateRoute'));

        final routerContent =
            File(paths.servicesRoutingFile).readAsStringSync();
        expect(routerContent, contains("static const String home = '/';"));
        expect(
            routerContent, contains("static const String debug = '/debug';"));
        expect(routerContent, contains('case debug:'));
        expect(
            routerContent,
            contains(
                'return MaterialPageRoute(builder: (_) => const DebugPage());'));
        expect(
            routerContent,
            contains(
                'return MaterialPageRoute(builder: (_) => const HomePage());'));

        // The Debug screen this router resolves must actually exist on
        // disk, at the path this architecture uses.
        final debugPageFile = switch (architecture) {
          Architecture.cleanArchitecture => paths.featuresDebugPageFileClean,
          Architecture.mvvm => paths.featuresDebugPageFileMvvm,
          Architecture.mvp => paths.featuresDebugPageFileMvp,
        };
        expect(File(debugPageFile).existsSync(), isTrue);
      });
    }

    test(
        'a custom ProjectConfig.homeFeatureName is honored end-to-end, '
        'through Home generation, routing, and main.dart', () async {
      final dir = Directory.systemTemp.createTempSync('smartwork_routing_e2e_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
        homeFeatureName: 'dashboard',
      );

      await ProjectGenerator(outputPath: dir.path, config: config).generate();

      final paths = ProjectPaths(projectRoot: dir.path);
      expect(
        Directory(paths.featurePath('dashboard')).existsSync(),
        isTrue,
      );
      expect(
        Directory(paths.featurePath('home')).existsSync(),
        isFalse,
        reason: 'the configured name replaces the default "home", it '
            'does not generate both',
      );

      final routerContent = File(paths.servicesRoutingFile).readAsStringSync();
      expect(
        routerContent,
        contains("import '../../features/dashboard/dashboard.dart';"),
      );
      expect(
        routerContent,
        contains(
            'return MaterialPageRoute(builder: (_) => const DashboardPage());'),
      );
      expect(routerContent, isNot(contains('HomePage')));
    });
  });
}
