import 'package:smartwork_core/smartwork_core.dart';

class ConfigurationDisplay {
  void displaySummary(ProjectConfig config) {
    _displaySummary(config);
    _validateAndDisplayErrors(config);
  }

  void displayAppTargetsDiff(ProjectConfig existing, ProjectConfig config) {
    print('Existing App Targets:');
    for (final target in existing.orderedAppTargets) {
      print('  ${target.displayName}');
    }
    print('');
    print('New App Targets:');
    for (final target in config.orderedAppTargets) {
      print('  ${target.displayName}');
    }
    print('');
  }

  void displayServiceChanges(ServiceChanges changes) {
    if (!changes.hasChanges) {
      print('Services unchanged.\n');
      print('Final Services:');
      if (changes.orderedDesired.isEmpty) {
        print('  None');
      } else {
        for (final service in changes.orderedDesired) {
          print('  ✓ ${service.displayName}');
        }
      }
      print('');
      return;
    }

    print('Service changes:\n');
    print('  Added:');
    if (changes.orderedAdded.isEmpty) {
      print('    None');
    } else {
      for (final service in changes.orderedAdded) {
        print('    + ${service.displayName}');
      }
    }
    print('');
    print('  Removed:');
    if (changes.orderedRemoved.isEmpty) {
      print('    None');
    } else {
      for (final service in changes.orderedRemoved) {
        print('    - ${service.displayName}');
      }
    }
    if (changes.orderedUnchanged.isNotEmpty) {
      print('');
      print('  Kept:');
      for (final service in changes.orderedUnchanged) {
        print('    ✓ ${service.displayName}');
      }
    }
    print('');
    if (changes.orderedDesired.isEmpty) {
      print('All optional production services will be removed.\n');
    }
    print('Final Services:');
    if (changes.orderedDesired.isEmpty) {
      print('  None');
    } else {
      for (final service in changes.orderedDesired) {
        print('  ✓ ${service.displayName}');
      }
    }
    print('');
  }

  void _displaySummary(ProjectConfig config) {
    final separator = '=' * 60;
    print('\n$separator');
    print('📋 Configuration Summary');
    print(separator);
    print('Project Name:           ${config.projectName}');
    print('App Targets:            '
        '${config.orderedAppTargets.map((t) => t.displayName).join(', ')}');
    print('Architecture:           ${configLabel(config.architecture)}');
    print('State Management:       ${configLabel(config.stateManagement)}');
    print('Network:                ${configLabel(config.network)}');
    print('Storage:                ${configLabel(config.storage)}');
    print('Fonts:                  ${_formatFonts(config.fonts)}');
    print(
        'Localization:           ${_formatLocalization(config.localization)}');
    print('Services:               '
        '${config.orderedServices.isEmpty ? '(none)' : config.orderedServices.map((s) => s.displayName).join(', ')}');
    print('Initial Features:       ${config.initialFeatures.join(', ')}');
    print('$separator\n');
  }

  void _validateAndDisplayErrors(ProjectConfig config) {
    final errors = ConfigValidator.validate(config);
    if (errors.isNotEmpty) {
      print('❌ Configuration validation failed:');
      for (final error in errors) {
        print('  - $error');
      }
      throw Exception('Invalid configuration');
    }
  }

  String _formatFonts(FontConfig fonts) {
    return switch (fonts.type) {
      FontType.none => 'None',
      FontType.custom => 'Custom (${fonts.custom!.family})',
      FontType.google => 'Google Font (${fonts.google!.family})',
    };
  }

  String _formatLocalization(LocalizationConfig localization) {
    if (!localization.enabled) return 'Disabled';
    return 'Enabled (${localization.supportedLocales.join(', ')}; '
        'default: ${localization.defaultLocale})';
  }
}

/// The label a configuration choice has in SmartWork's prompts (e.g.
/// "MVVM", "BLoC", "GetX"), so summaries read the same as the menus.
String configLabel(Enum choice) => switch (choice) {
      Architecture.cleanArchitecture => 'Clean Architecture',
      Architecture.mvvm => 'MVVM',
      Architecture.mvp => 'MVP',
      StateManagement.bloc => 'BLoC',
      StateManagement.cubit => 'Cubit',
      StateManagement.getx => 'GetX',
      StateManagement.riverpod => 'Riverpod',
      Network.http => 'HTTP',
      Network.dio => 'Dio',
      Network.other => 'Other',
      Storage.sharedPreferences => 'SharedPreferences',
      Storage.hive => 'Hive',
      Storage.other => 'Other',
      _ => choice.name,
    };
