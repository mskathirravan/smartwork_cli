import '../template.dart';

class ConstantsTemplates {
  static Template appConstantsTemplate() {
    return Template(content: '''class AppConstants {
  static const appName = '{{projectName}}';
  static const int debugTapCount = 10;
}
''');
  }

  static Template apiConstantsTemplate() {
    return Template(content: '''class ApiConstants {
  const ApiConstants._();

  static const String prodUrl = 'https://api.example.com';
  static const String stageUrl = 'https://staging-api.example.com';
  static const String devUrl = 'https://dev-api.example.com';
}
''');
  }

  static Template assetConstantsTemplate() {
    return Template(content: '''class AssetConstants {
  const AssetConstants._();

  static const String imagesPath = 'assets/images/';
  static const String fontsPath = 'assets/fonts/';
  static const String iconsPath = 'assets/icons/';
  static const String animationsPath = 'assets/animations/';
}
''');
  }

  static Template storageConstantsTemplate({
    bool includeSecureSessionKeys = false,
  }) {
    final secureSessionKeys = includeSecureSessionKeys
        ? '''
  static const String secureAccessTokenKey = 'secure_session_access_token';
  static const String secureRefreshTokenKey = 'secure_session_refresh_token';
'''
        : '';
    return Template(content: '''class StorageConstants {
  const StorageConstants._();

  static const String environmentKey = 'debug_environment';
  static const String themeModeKey = 'debug_theme_mode';
$secureSessionKeys}
''');
  }

  static Template appColorsTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../utilities/color_hex.dart';

class AppColors {
  const AppColors._();

  // Brand — feeds ColorScheme.fromSeed in AppTheme. Every other
  // Material role (primary, secondary, surface, error, onSurface,
  // outline, ...) is already available through
  // Theme.of(context).colorScheme — read those instead of adding a
  // duplicate constant here. 2196F3 is Material's own Colors.blue.
  static final Color lightSeedColor = '2196F3'.toColor();
  static final Color darkSeedColor = '2196F3'.toColor();

  // Semantic status colors with no Material ColorScheme role.
  static final Color success = '2E7D32'.toColor();
  static final Color warning = 'ED6C02'.toColor();
  static final Color info = '0288D1'.toColor();

  // A semi-transparent scrim for dimming content — distinct from
  // ColorScheme.scrim, which Material reserves for modal barriers.
  static final Color overlay = '1F000000'.toColor();

  // Shadow colors — feeds AppTheme's ThemeData.shadowColor, and
  // available directly for a custom-drawn BoxShadow.
  static final Color shadow = '33000000'.toColor();
  static final Color shadowDark = '66000000'.toColor();
}
''');
  }

  static Template appDimensionsTemplate() {
    return Template(content: '''class AppDimensions {
  const AppDimensions._();

  // Screen / content.
  static const double maxContentWidth = 640;
  static const double screenPadding = 16;

  // Spacing scale — covers padding, margin, and general layout gaps.
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // Border radius.
  static const double radiusSmall = 4;
  static const double radiusMedium = 8;
  static const double radiusLarge = 16;
}
''');
  }

  static Template screenDimensionsTemplate() {
    return Template(content: '''import 'package:flutter/widgets.dart';

/// Runtime screen dimensions — the counterpart to `AppDimensions`'
/// static design values. Read through a [BuildContext], never as a
/// static constant, since these vary by device and orientation.
extension ScreenDimensions on BuildContext {
  /// The current screen width, in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// The current screen height, in logical pixels.
  double get screenHeight => MediaQuery.sizeOf(this).height;
}
''');
  }

  static Template constantsBarrelTemplate() {
    return Template(content: '''export 'app_constants.dart';
export 'api_constants.dart';
export 'asset_constants.dart';
export 'storage_constants.dart';
export 'app_colors.dart';
export 'app_dimensions.dart';
export 'screen_dimensions.dart';
''');
  }

  static Template constantsTestTemplate() {
    return Template(content: '''import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/constants/constants.dart';

void main() {
  test('AppConstants declares the real app name and debug tap count', () {
    expect(AppConstants.appName, '{{projectName}}');
    expect(AppConstants.debugTapCount, 10);
  });

  test('ApiConstants declares three distinct, real environment URLs', () {
    expect(ApiConstants.prodUrl, 'https://api.example.com');
    expect(ApiConstants.stageUrl, 'https://staging-api.example.com');
    expect(ApiConstants.devUrl, 'https://dev-api.example.com');
    expect(
      {ApiConstants.prodUrl, ApiConstants.stageUrl, ApiConstants.devUrl},
      hasLength(3),
      reason: 'must never collapse to a duplicate',
    );
  });

  test('StorageConstants declares the real environment and theme keys', () {
    expect(StorageConstants.environmentKey, 'debug_environment');
    expect(StorageConstants.themeModeKey, 'debug_theme_mode');
  });

  test('AppColors declares the real, consumed theme seed colors', () {
    expect(AppColors.lightSeedColor, isNotNull);
    expect(AppColors.darkSeedColor, isNotNull);
  });

  test('AppColors declares a distinct semantic status color per status', () {
    expect(
      {AppColors.success, AppColors.warning, AppColors.info},
      hasLength(3),
      reason: 'must never collapse to a duplicate',
    );
  });

  test(
    'AppColors declares an overlay scrim and two distinct shadow colors',
    () {
      expect(AppColors.overlay, isNotNull);
      expect(
        AppColors.shadow,
        isNot(AppColors.shadowDark),
        reason: 'light and dark themes need different shadow opacity',
      );
    },
  );

  test('AppDimensions declares the shared max content width', () {
    expect(AppDimensions.maxContentWidth, 640);
  });

  test('AppDimensions.screenPadding matches the value the generated Debug '
      'screen already uses', () {
    expect(AppDimensions.screenPadding, 16);
  });

  test('AppDimensions declares an ascending spacing scale', () {
    expect(AppDimensions.spacingXs, lessThan(AppDimensions.spacingSm));
    expect(AppDimensions.spacingSm, lessThan(AppDimensions.spacingMd));
    expect(AppDimensions.spacingMd, lessThan(AppDimensions.spacingLg));
    expect(AppDimensions.spacingLg, lessThan(AppDimensions.spacingXl));
  });

  test('AppDimensions declares an ascending border-radius scale', () {
    expect(AppDimensions.radiusSmall, lessThan(AppDimensions.radiusMedium));
    expect(AppDimensions.radiusMedium, lessThan(AppDimensions.radiusLarge));
  });

  test('AssetConstants declares the standard asset folder paths', () {
    expect(AssetConstants.imagesPath, 'assets/images/');
    expect(AssetConstants.fontsPath, 'assets/fonts/');
    expect(AssetConstants.iconsPath, 'assets/icons/');
    expect(AssetConstants.animationsPath, 'assets/animations/');
  });
}
''');
  }

  static Template screenDimensionsTestTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/constants/constants.dart';

void main() {
  testWidgets('screenWidth/screenHeight report the real MediaQuery size', (
    tester,
  ) async {
    late double width;
    late double height;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Builder(
          builder: (context) {
            width = context.screenWidth;
            height = context.screenHeight;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(width, 400);
    expect(height, 800);
  });

  testWidgets(
    'screenWidth/screenHeight update when the reported size changes',
    (tester) async {
      late double width;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(300, 600)),
          child: Builder(
            builder: (context) {
              width = context.screenWidth;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(width, 300);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(500, 900)),
          child: Builder(
            builder: (context) {
              width = context.screenWidth;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(width, 500);
    },
  );
}
''');
  }
}
