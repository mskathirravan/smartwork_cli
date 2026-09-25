import 'package:path/path.dart' as p;

/// Which kind of font a project uses.
enum FontType {
  /// No font: Flutter's default.
  none,

  /// A font from local `.ttf`/`.otf` files, bundled as an asset.
  custom,

  /// A Google Font, loaded with the `google_fonts` package.
  google,
}

/// One file of a custom font family.
class CustomFontFile {
  /// Path of the `.ttf`/`.otf` file to copy into `assets/fonts/`.
  final String sourcePath;

  /// Its font weight (100–900), or null for the family's default.
  final int? weight;

  /// Whether it is the italic style.
  final bool italic;

  /// A font file at [sourcePath].
  CustomFontFile({
    required this.sourcePath,
    this.weight,
    this.italic = false,
  });

  /// The file's name once copied into `assets/fonts/`.
  String get assetFileName => p.basename(sourcePath);

  /// Reads a font file entry from `.smartwork/project.yaml`.
  factory CustomFontFile.fromYaml(Map<String, dynamic> yaml) {
    return CustomFontFile(
      sourcePath: yaml['sourcePath'] as String,
      weight: yaml['weight'] as int?,
      italic: yaml['italic'] as bool? ?? false,
    );
  }

  /// The entry as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() => {
        'sourcePath': sourcePath,
        if (weight != null) 'weight': weight,
        'italic': italic,
      };
}

/// A custom font family made of local font files.
class CustomFontConfig {
  /// The family name used in the theme, e.g. `MyBrand`.
  final String family;

  /// The family's font files.
  final List<CustomFontFile> files;

  /// A custom font [family] from [files].
  CustomFontConfig({required this.family, required this.files});

  /// Reads a custom font from `.smartwork/project.yaml`.
  factory CustomFontConfig.fromYaml(Map<String, dynamic> yaml) {
    return CustomFontConfig(
      family: yaml['family'] as String,
      files: (yaml['files'] as List? ?? [])
          .map((f) => CustomFontFile.fromYaml(Map<String, dynamic>.from(f)))
          .toList(),
    );
  }

  /// The font as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() => {
        'family': family,
        'files': files.map((f) => f.toYaml()).toList(),
      };
}

/// A Google Font, loaded at runtime by the `google_fonts` package.
class GoogleFontConfig {
  /// The Google Fonts family name, e.g. `Roboto`.
  final String family;

  /// The Google Font [family].
  GoogleFontConfig({required this.family});

  /// Reads a Google Font from `.smartwork/project.yaml`.
  factory GoogleFontConfig.fromYaml(Map<String, dynamic> yaml) {
    return GoogleFontConfig(family: yaml['family'] as String);
  }

  /// The font as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() => {'family': family};
}

/// A project's font: none, a custom font, or a Google Font.
class FontConfig {
  /// Which kind of font this is.
  final FontType type;

  /// The custom font, when [type] is [FontType.custom].
  final CustomFontConfig? custom;

  /// The Google Font, when [type] is [FontType.google].
  final GoogleFontConfig? google;

  FontConfig._({required this.type, this.custom, this.google});

  /// No font: the app uses Flutter's default.
  FontConfig.none() : this._(type: FontType.none);

  /// A custom font from local files.
  FontConfig.custom(CustomFontConfig config)
      : this._(type: FontType.custom, custom: config);

  /// A Google Font.
  FontConfig.google(GoogleFontConfig config)
      : this._(type: FontType.google, google: config);

  /// Reads the font from `.smartwork/project.yaml`; null means none.
  factory FontConfig.fromYaml(Map<String, dynamic>? yaml) {
    if (yaml == null) return FontConfig.none();

    final type = FontType.values.byName(yaml['type'] as String);
    return switch (type) {
      FontType.none => FontConfig.none(),
      FontType.custom => FontConfig.custom(
          CustomFontConfig.fromYaml(
            Map<String, dynamic>.from(yaml['custom'] as Map),
          ),
        ),
      FontType.google => FontConfig.google(
          GoogleFontConfig.fromYaml(
            Map<String, dynamic>.from(yaml['google'] as Map),
          ),
        ),
    };
  }

  /// The font as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() => {
        'type': type.name,
        if (custom != null) 'custom': custom!.toYaml(),
        if (google != null) 'google': google!.toYaml(),
      };
}
