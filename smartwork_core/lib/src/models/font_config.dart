import 'package:path/path.dart' as p;

enum FontType { none, custom, google }

class CustomFontFile {
  final String sourcePath;
  final int? weight;
  final bool italic;

  CustomFontFile({
    required this.sourcePath,
    this.weight,
    this.italic = false,
  });

  String get assetFileName => p.basename(sourcePath);

  factory CustomFontFile.fromYaml(Map<String, dynamic> yaml) {
    return CustomFontFile(
      sourcePath: yaml['sourcePath'] as String,
      weight: yaml['weight'] as int?,
      italic: yaml['italic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toYaml() => {
        'sourcePath': sourcePath,
        if (weight != null) 'weight': weight,
        'italic': italic,
      };
}

class CustomFontConfig {
  final String family;
  final List<CustomFontFile> files;

  CustomFontConfig({required this.family, required this.files});

  factory CustomFontConfig.fromYaml(Map<String, dynamic> yaml) {
    return CustomFontConfig(
      family: yaml['family'] as String,
      files: (yaml['files'] as List? ?? [])
          .map((f) => CustomFontFile.fromYaml(Map<String, dynamic>.from(f)))
          .toList(),
    );
  }

  Map<String, dynamic> toYaml() => {
        'family': family,
        'files': files.map((f) => f.toYaml()).toList(),
      };
}

class GoogleFontConfig {
  final String family;

  GoogleFontConfig({required this.family});

  factory GoogleFontConfig.fromYaml(Map<String, dynamic> yaml) {
    return GoogleFontConfig(family: yaml['family'] as String);
  }

  Map<String, dynamic> toYaml() => {'family': family};
}

class FontConfig {
  final FontType type;
  final CustomFontConfig? custom;
  final GoogleFontConfig? google;

  FontConfig._({required this.type, this.custom, this.google});

  FontConfig.none() : this._(type: FontType.none);

  FontConfig.custom(CustomFontConfig config)
      : this._(type: FontType.custom, custom: config);

  FontConfig.google(GoogleFontConfig config)
      : this._(type: FontType.google, google: config);

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

  Map<String, dynamic> toYaml() => {
        'type': type.name,
        if (custom != null) 'custom': custom!.toYaml(),
        if (google != null) 'google': google!.toYaml(),
      };
}
