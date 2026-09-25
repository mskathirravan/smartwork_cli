import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

import 'choice_reader.dart';

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
    final choice = readChoice(
      'Select (1, 2, or 3): ',
      FontType.values,
    );
    return switch (choice) {
      FontType.none => FontConfig.none(),
      FontType.custom => FontConfig.custom(_promptCustomFont()),
      FontType.google => FontConfig.google(_promptGoogleFont()),
    };
  }

  CustomFontConfig _promptCustomFont() {
    String family;
    while (true) {
      stdout.write('Font family name: ');
      family = readLineOrThrow().trim();
      if (family.isNotEmpty) break;
      print('❌ Font family name cannot be empty');
    }

    String path;
    while (true) {
      stdout.write('Path to font file (.ttf or .otf): ');
      path = readLineOrThrow().trim();
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
      final family = readLineOrThrow().trim();
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
