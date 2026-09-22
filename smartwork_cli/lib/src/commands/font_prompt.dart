import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

class FontSelection {
  final FontConfig fonts;
  final bool includeHomeSample;

  FontSelection({required this.fonts, required this.includeHomeSample});
}

class FontPrompt {
  FontSelection prompt() {
    final fonts = _promptFontConfig();
    final includeHomeSample =
        fonts.type == FontType.none ? false : _promptSampleChoice(fonts);
    return FontSelection(fonts: fonts, includeHomeSample: includeHomeSample);
  }

  FontConfig _promptFontConfig() {
    print('\nFonts:');
    print('  1. None');
    print('  2. Custom Font (from a local .ttf/.otf file)');
    print('  3. Google Font');
    stdout.write('Select (1, 2, or 3): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    switch (input) {
      case '1':
        return FontConfig.none();
      case '2':
        return FontConfig.custom(_promptCustomFont());
      case '3':
        return FontConfig.google(_promptGoogleFont());
      default:
        print('❌ Invalid selection. Using no font by default.');
        return FontConfig.none();
    }
  }

  CustomFontConfig _promptCustomFont() {
    String family;
    while (true) {
      stdout.write('Font family name: ');
      family = stdin.readLineSync()?.trim() ?? '';
      if (family.isNotEmpty) break;
      print('❌ Font family name cannot be empty');
    }

    String path;
    while (true) {
      stdout.write('Path to font file (.ttf or .otf): ');
      path = stdin.readLineSync()?.trim() ?? '';
      if (path.isNotEmpty) break;
      print('❌ Font file path cannot be empty');
    }

    return CustomFontConfig(
      family: family,
      files: [CustomFontFile(sourcePath: path)],
    );
  }

  GoogleFontConfig _promptGoogleFont() {
    while (true) {
      stdout.write('Google Font family name (e.g., Roboto, Poppins, Lato): ');
      final family = stdin.readLineSync()?.trim() ?? '';
      if (family.isNotEmpty) return GoogleFontConfig(family: family);
      print('❌ Font family name cannot be empty');
    }
  }

  bool _promptSampleChoice(FontConfig fonts) {
    final family = fonts.type == FontType.custom
        ? fonts.custom!.family
        : fonts.google!.family;
    stdout.write("Add a '$family' sample preview to the Home page? "
        '[y/N]: ');
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    return input == 'y' || input == 'yes';
  }
}
