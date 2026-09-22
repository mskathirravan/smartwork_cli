import 'dart:io';

import 'package:image/image.dart' as img;

import '../models/app_icon_config.dart';
import '../models/font_config.dart';
import '../models/localization_config.dart';
import '../models/project_config.dart';
import '../models/service_definition.dart';
import '../models/splash_config.dart';

class ValidationError {
  final String message;

  ValidationError(this.message);

  @override
  String toString() => message;
}

class ConfigValidator {
  static List<ValidationError> validate(ProjectConfig config) {
    final errors = <ValidationError>[];

    if (config.projectName.isEmpty) {
      errors.add(ValidationError('Project name cannot be empty'));
    }

    if (!_isValidProjectName(config.projectName)) {
      errors.add(ValidationError(
        'Project name must start with a letter and contain only lowercase letters, numbers, and underscores',
      ));
    }

    if (config.appTargets.isEmpty) {
      errors.add(ValidationError('At least one App Target is required'));
    }

    if (config.initialFeatures.isEmpty) {
      errors.add(ValidationError('At least one initial feature is required'));
    }

    for (final feature in config.initialFeatures) {
      if (!isValidFeatureName(feature)) {
        errors.add(ValidationError(
          'Feature name "$feature" is invalid. Must start with a letter and contain only lowercase letters, numbers, and underscores',
        ));
      }
    }

    final knownServiceIds = Service.values.map((s) => s.id).toSet();
    for (final service in config.services) {
      if (!knownServiceIds.contains(service)) {
        errors.add(ValidationError(
          'Unknown service "$service". Valid services: '
          '${knownServiceIds.join(', ')}',
        ));
      }
    }

    errors.addAll(_validateFonts(config.fonts));
    errors.addAll(_validateLocalization(config.localization));
    if (config.splash != null) {
      errors.addAll(validateSplash(config.splash!));
    }
    if (config.appIcon != null) {
      errors.addAll(validateAppIcon(config.appIcon!));
    }

    return errors;
  }

  static final _localePattern = RegExp(r'^[a-z]{2,3}(_[A-Z]{2})?$');
  static final _hexColorPattern = RegExp(r'^#?[0-9A-Fa-f]{6}$');
  static const _supportedSplashIconExtensions = {'.png', '.jpg', '.jpeg'};

  static List<ValidationError> validateSplash(SplashConfig splash) {
    final errors = <ValidationError>[];

    if (!_hexColorPattern.hasMatch(splash.backgroundColor)) {
      errors.add(ValidationError(
        'Invalid Splash background color "${splash.backgroundColor}" — '
        'must be a 6-digit hex value, e.g. "#FFFFFF" or "FFFFFF"',
      ));
    }

    if (splash.iconPath.trim().isEmpty) {
      errors.add(ValidationError('Splash icon path cannot be empty'));
    } else {
      final extension = _lowercaseExtension(splash.iconPath);
      if (!_supportedSplashIconExtensions.contains(extension)) {
        errors.add(ValidationError(
          'Splash icon "${splash.iconPath}" must be a '
          '${_supportedSplashIconExtensions.join(' or ')} file',
        ));
      }
      if (!File(splash.iconPath).existsSync()) {
        errors.add(ValidationError(
          'Splash icon not found: "${splash.iconPath}"',
        ));
      }
    }

    return errors;
  }

  static const _supportedAppIconExtensions = {'.png', '.jpg', '.jpeg'};

  static List<ValidationError> validateAppIcon(AppIconConfig appIcon) {
    final errors = <ValidationError>[];

    if (appIcon.sourcePath.trim().isEmpty) {
      errors.add(ValidationError('App Icon source path cannot be empty'));
      return errors;
    }

    final extension = _lowercaseExtension(appIcon.sourcePath);
    if (!_supportedAppIconExtensions.contains(extension)) {
      errors.add(ValidationError(
        'App Icon source "${appIcon.sourcePath}" must be a '
        '${_supportedAppIconExtensions.join(' or ')} file',
      ));
    }

    final file = File(appIcon.sourcePath);
    if (!file.existsSync()) {
      errors.add(ValidationError(
        'App Icon source not found: "${appIcon.sourcePath}"',
      ));
      return errors;
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(file.readAsBytesSync());
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      errors.add(ValidationError(
        'App Icon source "${appIcon.sourcePath}" could not be decoded as '
        'an image — it may be corrupt or in an unsupported format',
      ));
      return errors;
    }

    if (decoded.width != decoded.height) {
      errors.add(ValidationError(
        'App Icon source "${appIcon.sourcePath}" must be square (found '
        '${decoded.width}x${decoded.height})',
      ));
    }

    return errors;
  }

  static List<ValidationError> _validateLocalization(
    LocalizationConfig localization,
  ) {
    final errors = <ValidationError>[];
    if (!localization.enabled) return errors;

    if (localization.supportedLocales.isEmpty) {
      errors.add(ValidationError(
        'Localization is enabled but no supported locales were given',
      ));
    }

    final seen = <String>{};
    for (final locale in localization.supportedLocales) {
      if (!seen.add(locale)) {
        errors.add(ValidationError('Duplicate supported locale: "$locale"'));
      }
      if (!_localePattern.hasMatch(locale)) {
        errors.add(ValidationError(
          'Invalid locale "$locale" — must look like "en", "en_US", or '
          '"pt_BR"',
        ));
      }
    }

    for (final locale in localization.supportedLocales) {
      if (!locale.contains('_')) continue;
      final baseLanguage = locale.split('_').first;
      if (!localization.supportedLocales.contains(baseLanguage)) {
        errors.add(ValidationError(
          'Locale "$locale" requires its base language "$baseLanguage" to '
          'also be a supported locale (a Flutter gen-l10n requirement)',
        ));
      }
    }

    final defaultLocale = localization.defaultLocale;
    if (defaultLocale == null || defaultLocale.trim().isEmpty) {
      errors.add(ValidationError(
        'Localization is enabled but no default locale was given',
      ));
    } else if (!localization.supportedLocales.contains(defaultLocale)) {
      errors.add(ValidationError(
        'Default locale "$defaultLocale" must be one of the supported '
        'locales: ${localization.supportedLocales.join(', ')}',
      ));
    }

    return errors;
  }

  static const _supportedCustomFontExtensions = {'.ttf', '.otf'};
  static const _validFontWeights = {
    100,
    200,
    300,
    400,
    500,
    600,
    700,
    800,
    900
  };

  static List<ValidationError> _validateFonts(FontConfig fonts) {
    final errors = <ValidationError>[];

    switch (fonts.type) {
      case FontType.none:
        break;

      case FontType.custom:
        final custom = fonts.custom;
        if (custom == null) {
          errors.add(ValidationError(
            'Font type is "custom" but no custom font configuration was '
            'given',
          ));
          break;
        }
        if (custom.family.trim().isEmpty) {
          errors.add(ValidationError('Custom font family cannot be empty'));
        }
        if (custom.files.isEmpty) {
          errors.add(ValidationError(
            'Custom font "${custom.family}" requires at least one font '
            'file',
          ));
        }
        for (final file in custom.files) {
          final extension = _lowercaseExtension(file.sourcePath);
          if (!_supportedCustomFontExtensions.contains(extension)) {
            errors.add(ValidationError(
              'Custom font file "${file.sourcePath}" must be a '
              '${_supportedCustomFontExtensions.join(' or ')} file',
            ));
          }
          if (!File(file.sourcePath).existsSync()) {
            errors.add(ValidationError(
              'Custom font file not found: "${file.sourcePath}"',
            ));
          }
          if (file.weight != null && !_validFontWeights.contains(file.weight)) {
            errors.add(ValidationError(
              'Custom font file "${file.sourcePath}" has an invalid '
              'weight (${file.weight}) — must be one of '
              '${_validFontWeights.join(', ')}',
            ));
          }
        }

      case FontType.google:
        final google = fonts.google;
        if (google == null) {
          errors.add(ValidationError(
            'Font type is "google" but no Google Font configuration was '
            'given',
          ));
          break;
        }
        if (google.family.trim().isEmpty) {
          errors.add(ValidationError('Google Font family cannot be empty'));
        }
    }

    return errors;
  }

  static String _lowercaseExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return path.substring(dotIndex).toLowerCase();
  }

  static bool _isValidProjectName(String name) {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }

  static bool isValidFeatureName(String name) {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }
}
