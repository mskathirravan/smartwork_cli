import '../../models/font_config.dart';
import '../../models/project_config.dart';
import '../template.dart';
import '../testing/storage_test_setup.dart';

class ThemeServiceTemplates {
  static Template themeServiceTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';
import '../storage/storage_service.dart';

/// A `ChangeNotifier` — not just a plain singleton like
/// `EnvironmentManager` — because `main.dart`'s root widget must
/// visually rebuild the instant the Debug screen applies a new theme,
/// with no app restart. `EnvironmentManager` has no such requirement:
/// Network reads `currentBaseUrl` fresh on every request, so nothing
/// needs to be notified when it changes.
class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  ThemeMode _current = ThemeMode.system;

  ThemeMode get currentThemeMode => _current;

  /// Loads the persisted theme mode, if any. Called once from
  /// `Bootstrap.initialize()`, before `runApp()`.
  Future<void> load() async {
    final stored = await StorageService.instance.getString(
      StorageConstants.themeModeKey,
    );
    if (stored != null) {
      _current = ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
  }

  /// Switches the active theme mode and persists only its identifier
  /// (e.g. `'dark'`).
  Future<void> setTheme(ThemeMode mode) async {
    _current = mode;
    await StorageService.instance.setString(
      StorageConstants.themeModeKey,
      mode.name,
    );
    notifyListeners();
  }
}
''');
  }

  static Template themeServiceTestTemplate(Storage storage) {
    return Template(content: '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
${StorageTestSetup.imports(storage)}

import 'package:{{projectName}}/core/constants/constants.dart';
import 'package:{{projectName}}/services/storage/storage_service.dart';
import 'package:{{projectName}}/services/theme/theme_service.dart';

${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

${StorageTestSetup.setUpAndTearDown(storage)}

  tearDown(() async {
    await ThemeService.instance.setTheme(ThemeMode.system);
  });

  test('defaults to ThemeMode.system', () {
    expect(ThemeService.instance.currentThemeMode, ThemeMode.system);
  });

  test('setTheme switches the current theme mode', () async {
    await ThemeService.instance.setTheme(ThemeMode.light);

    expect(ThemeService.instance.currentThemeMode, ThemeMode.light);
  });

  test('setTheme persists the identifier, never the enum toString(), '
      'through StorageService', () async {
    await ThemeService.instance.setTheme(ThemeMode.dark);

    expect(
      await StorageService.instance.getString(StorageConstants.themeModeKey),
      'dark',
    );
  });

  test('setTheme notifies listeners so the app can rebuild live', () async {
    var notifications = 0;
    ThemeService.instance.addListener(() => notifications++);

    await ThemeService.instance.setTheme(ThemeMode.light);

    expect(notifications, greaterThan(0));
  });

  test('load() reads a persisted theme mode', () async {
    await StorageService.instance.setString(
      StorageConstants.themeModeKey,
      'dark',
    );

    await ThemeService.instance.load();

    expect(ThemeService.instance.currentThemeMode, ThemeMode.dark);
  });

  test(
    'load() falls back to ThemeMode.system when nothing is persisted',
    () async {
      await ThemeService.instance.load();

      expect(ThemeService.instance.currentThemeMode, ThemeMode.system);
    },
  );
}
''');
  }

  static Template appThemeTemplate(FontConfig fonts) {
    return Template(content: _appThemeSource(fonts));
  }

  static String _appThemeSource(FontConfig fonts) {
    final googleFontsImport = fonts.type == FontType.google
        ? "import 'package:google_fonts/google_fonts.dart';\n"
        : '';
    final lightBody = _themeDataBody(
      fonts,
      seedColorExpr: 'AppColors.lightSeedColor',
      shadowColorExpr: 'AppColors.shadow',
      isDark: false,
    );
    final darkBody = _themeDataBody(
      fonts,
      seedColorExpr: 'AppColors.darkSeedColor',
      shadowColorExpr: 'AppColors.shadowDark',
      isDark: true,
    );

    return '''import 'package:flutter/material.dart';
$googleFontsImport
import '../../core/constants/constants.dart';

/// `ThemeData` configuration for the app's light/dark themes. Reads
/// its seed and shadow colors from `AppColors` — never a literal
/// `Color` here — so changing the app's color foundation only ever
/// means editing `AppColors`. `AppColors`' other semantic colors
/// (`success`/`warning`/`info`/`overlay`) have no `ThemeData` field to
/// feed — they are used directly where needed, not through `Theme.of
/// (context)`.
class AppTheme {
  const AppTheme._();

$lightBody
$darkBody}
''';
  }

  static String _themeDataBody(
    FontConfig fonts, {
    required String seedColorExpr,
    required String shadowColorExpr,
    required bool isDark,
  }) {
    final getterName = isDark ? 'dark' : 'light';

    switch (fonts.type) {
      case FontType.none:
        final colorScheme = isDark
            ? '''ColorScheme.fromSeed(
      seedColor: $seedColorExpr,
      brightness: Brightness.dark,
    )'''
            : 'ColorScheme.fromSeed(seedColor: $seedColorExpr)';
        return '''  static ThemeData get $getterName => ThemeData(
    colorScheme: $colorScheme,
    shadowColor: $shadowColorExpr,
  );
''';
      case FontType.custom:
        final family = fonts.custom!.family;
        final colorScheme = isDark
            ? '''ColorScheme.fromSeed(
      seedColor: $seedColorExpr,
      brightness: Brightness.dark,
    )'''
            : 'ColorScheme.fromSeed(seedColor: $seedColorExpr)';
        return '''  static ThemeData get $getterName => ThemeData(
    colorScheme: $colorScheme,
    shadowColor: $shadowColorExpr,
    fontFamily: '$family',
  );
''';
      case FontType.google:
        final family = fonts.google!.family;
        final colorScheme = isDark
            ? '''ColorScheme.fromSeed(
        seedColor: $seedColorExpr,
        brightness: Brightness.dark,
      )'''
            : 'ColorScheme.fromSeed(seedColor: $seedColorExpr)';
        return '''  static ThemeData get $getterName {
    final base = ThemeData(
      colorScheme: $colorScheme,
      shadowColor: $shadowColorExpr,
    );
    return base.copyWith(
      textTheme: GoogleFonts.getTextTheme('$family', base.textTheme),
    );
  }
''';
    }
  }

  static Template appThemeTestTemplate(FontConfig fonts) {
    final fontAssertions = switch (fonts.type) {
      FontType.none => '',
      FontType.custom => '''
  test('light/dark apply the configured custom font family', () {
    expect(AppTheme.light.textTheme.bodyLarge?.fontFamily, '${fonts.custom!.family}');
    expect(AppTheme.dark.textTheme.bodyLarge?.fontFamily, '${fonts.custom!.family}');
  });
''',
      FontType.google => '''
  test('light/dark apply the configured Google Font family', () {
    expect(AppTheme.light.textTheme.bodyLarge?.fontFamily, contains('${fonts.google!.family}'));
    expect(AppTheme.dark.textTheme.bodyLarge?.fontFamily, contains('${fonts.google!.family}'));
  });
''',
    };

    return Template(content: '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/constants/constants.dart';
import 'package:{{projectName}}/services/theme/app_theme.dart';

void main() {
  test('light is a light-brightness ThemeData seeded from AppColors', () {
    final theme = AppTheme.light;

    expect(theme.brightness, Brightness.light);
    expect(
      theme.colorScheme.brightness,
      ColorScheme.fromSeed(seedColor: AppColors.lightSeedColor).brightness,
    );
    expect(theme.shadowColor, AppColors.shadow);
  });

  test('dark is a dark-brightness ThemeData seeded from AppColors', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(
      theme.colorScheme.primary,
      ColorScheme.fromSeed(
        seedColor: AppColors.darkSeedColor,
        brightness: Brightness.dark,
      ).primary,
    );
    expect(theme.shadowColor, AppColors.shadowDark);
  });

  test('light and dark are deterministic across repeated access', () {
    expect(
      AppTheme.light.colorScheme.primary,
      AppTheme.light.colorScheme.primary,
    );
    expect(
      AppTheme.dark.colorScheme.primary,
      AppTheme.dark.colorScheme.primary,
    );
  });
$fontAssertions}
''');
  }
}
