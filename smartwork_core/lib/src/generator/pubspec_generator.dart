import '../models/font_config.dart';
import '../models/project_config.dart';
import '../models/service_definition.dart';
import 'version_resolver.dart';

class DependencyVersions {
  static const flutterBloc = '^9.1.1';

  static const get = '^4.7.3';

  static const riverpod = '^3.4.3';

  static const http = '^1.6.0';
  static const dio = '^5.11.1';

  static const meta = '^1.19.0';
  static const sharedPreferences = '^2.5.5';

  static const hiveFlutter = '^1.1.0';

  static const pathProviderPlatformInterface = '^2.1.3';
  static const pluginPlatformInterface = '^2.1.8';

  static const packageInfoPlus = '^10.2.1';

  static const inAppReview = '^2.0.12';

  static const googleFonts = '^8.2.1';

  static const intl = '^0.20.3';
}

class PubspecDependencies {
  final List<String> runtime;
  final List<String> dev;

  PubspecDependencies({required this.runtime, required this.dev});
}

class PubspecGenerator {
  final VersionResolver _resolver;

  PubspecGenerator({VersionResolver? resolver})
      : _resolver = resolver ?? VersionResolver.shared;

  PubspecDependencies resolveDependencies(ProjectConfig config) {
    final runtime = <String>['flutter'];
    final dev = <String>['flutter_test'];

    switch (config.stateManagement) {
      case StateManagement.bloc:
      case StateManagement.cubit:
        runtime.add('flutter_bloc');
      case StateManagement.getx:
        runtime.add('get');
      case StateManagement.riverpod:
        runtime.add('riverpod');
    }

    switch (config.network) {
      case Network.http:
        runtime.add('http');
        runtime.add('meta');
      case Network.dio:
        runtime.add('dio');
        runtime.add('meta');
      case Network.other:
    }

    switch (config.storage) {
      case Storage.sharedPreferences:
        runtime.add('shared_preferences');
      case Storage.hive:
        runtime.add('hive_flutter');
        dev.add('path_provider_platform_interface');
        dev.add('plugin_platform_interface');
      case Storage.other:
    }

    if (config.services.contains(Service.forceUpdate.id)) {
      runtime.add('package_info_plus');
    }
    if (config.services.contains(Service.appReview.id)) {
      runtime.add('in_app_review');
    }

    if (config.fonts.type == FontType.google) {
      runtime.add('google_fonts');
    }

    if (config.localization.enabled) {
      runtime.add('flutter_localizations');
      runtime.add('intl');
    }

    return PubspecDependencies(runtime: runtime, dev: dev);
  }

  Future<String> generate(
    ProjectConfig config, {
    String? projectDescription,
  }) async {
    final deps = resolveDependencies(config);
    final buffer = StringBuffer()
      ..writeln('name: ${config.projectName}')
      ..writeln('description: ${_descriptionLine(projectDescription)}')
      ..writeln('version: 1.0.0+1')
      ..writeln("publish_to: 'none'")
      ..writeln()
      ..writeln('environment:')
      ..writeln('  sdk: ^3.0.0')
      ..writeln()
      ..writeln('dependencies:');
    for (final package in deps.runtime) {
      await _writeDependency(buffer, package);
    }
    buffer
      ..writeln()
      ..writeln('dev_dependencies:');
    for (final package in deps.dev) {
      await _writeDependency(buffer, package);
    }
    buffer
      ..writeln()
      ..writeln('flutter:')
      ..writeln('  uses-material-design: true');
    if (config.localization.enabled) {
      buffer.writeln('  generate: true');
    }
    for (final line in _assetLines) {
      buffer.writeln(line);
    }
    for (final line in _fontLines(config.fonts)) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  /// A throwaway pubspec depending on every package SmartWork can generate,
  /// at the versions it would write. `smartwork doctor` runs
  /// `flutter pub get` on it to check the local Flutter SDK can resolve
  /// them.
  Future<String> generateDependencyProbe() async {
    final buffer = StringBuffer()
      ..writeln('name: smartwork_dependency_probe')
      ..writeln("publish_to: 'none'")
      ..writeln()
      ..writeln('environment:')
      ..writeln('  sdk: ^3.0.0')
      ..writeln()
      ..writeln('dependencies:');
    for (final package in ['flutter', 'flutter_localizations']) {
      await _writeDependency(buffer, package);
    }
    for (final package in _managedPackages) {
      await _writeDependency(buffer, package);
    }
    buffer
      ..writeln()
      ..writeln('dev_dependencies:');
    await _writeDependency(buffer, 'flutter_test');
    return buffer.toString();
  }

  static const List<String> _assetLines = [
    '  assets:',
    '    - assets/images/',
    '    - assets/fonts/',
    '    - assets/icons/',
    '    - assets/animations/',
  ];

  static List<String> _fontLines(FontConfig fonts) {
    if (fonts.type != FontType.custom) return const [];
    final custom = fonts.custom!;

    final lines = <String>[
      '  fonts:',
      '    - family: ${custom.family}',
      '      fonts:',
    ];
    for (final file in custom.files) {
      lines.add('        - asset: assets/fonts/${file.assetFileName}');
      if (file.weight != null) {
        lines.add('          weight: ${file.weight}');
      }
      if (file.italic) {
        lines.add('          style: italic');
      }
    }
    return lines;
  }

  static const _defaultDescription =
      'A Flutter project generated by SmartWork.';

  String _descriptionLine(String? projectDescription) {
    final trimmed = projectDescription?.trim() ?? '';
    if (trimmed.isEmpty) return _defaultDescription;

    final escaped = trimmed.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '"$escaped"';
  }

  Future<String> mergeInto(
    String existingPubspecYaml,
    ProjectConfig config, {
    String? projectDescription,
  }) async {
    final deps = resolveDependencies(config);
    final runtimeToAdd = deps.runtime.where((p) => p != 'flutter').toList();
    final devToAdd = deps.dev.where((p) => p != 'flutter_test').toList();
    final desired = {...runtimeToAdd, ...devToAdd};

    var content = existingPubspecYaml;
    content = _removeStaleManagedDependencies(content, desired);
    content = await _insertAfterSection(content, 'dependencies:', runtimeToAdd);
    content = await _insertAfterSection(content, 'dev_dependencies:', devToAdd);
    content = _insertAssetsSection(content);
    content = _syncFontsSection(content, config.fonts);
    content = _syncGenerateFlag(content, config.localization.enabled);
    content = _syncDescription(content, projectDescription);
    return content;
  }

  /// Overwrites the existing `description:` line in place with
  /// [projectDescription] (SmartWork's `smartwork init` collects this from
  /// the developer). A null or blank value leaves Flutter's own generated
  /// line untouched — this is a no-op for every other lifecycle command
  /// (`feature`, `font`, `localization`, `service`, `splash`, `target`),
  /// none of which have a project description to offer.
  String _syncDescription(String content, String? projectDescription) {
    final trimmed = projectDescription?.trim() ?? '';
    if (trimmed.isEmpty) return content;

    final lines = content.split('\n');
    final index = lines.indexWhere((line) => line.startsWith('description:'));
    if (index == -1) return content;

    lines[index] = 'description: ${_descriptionLine(trimmed)}';
    return lines.join('\n');
  }

  String _removeStaleManagedDependencies(String content, Set<String> desired) {
    final packageLine = RegExp(r'^  ([A-Za-z0-9_]+):');
    final lines = content.split('\n');
    final kept = <String>[];
    var removingBlock = false;
    for (final line in lines) {
      // A removed entry's nested lines (e.g. `    sdk: flutter` under
      // `  flutter_localizations:`) go with it; leaving them behind would
      // attach them to the previous entry and corrupt the YAML.
      if (removingBlock && line.startsWith('    ') && line.trim().isNotEmpty) {
        continue;
      }
      removingBlock = _isStaleManagedDependencyLine(line, packageLine, desired);
      if (!removingBlock) kept.add(line);
    }
    return kept.join('\n');
  }

  bool _isStaleManagedDependencyLine(
    String line,
    RegExp packageLine,
    Set<String> desired,
  ) {
    final match = packageLine.firstMatch(line);
    if (match == null) return false;
    final name = match.group(1)!;
    return _isManagedPackage(name) && !desired.contains(name);
  }

  static const _managedPackages = {
    'flutter_bloc',
    'get',
    'riverpod',
    'http',
    'dio',
    'meta',
    'shared_preferences',
    'hive_flutter',
    'path_provider_platform_interface',
    'plugin_platform_interface',
    'package_info_plus',
    'in_app_review',
    'google_fonts',
    'intl',
  };

  bool _isManagedPackage(String package) {
    return package == 'flutter_localizations' ||
        _managedPackages.contains(package);
  }

  String _insertAssetsSection(String content) {
    if (content.contains('\n  assets:')) return content;

    final lines = content.split('\n');
    final headerIndex = lines.indexWhere((line) => line == 'flutter:');
    if (headerIndex == -1) return content;

    lines.insertAll(headerIndex + 1, _assetLines);
    return lines.join('\n');
  }

  String _syncFontsSection(String content, FontConfig fonts) {
    var result = _removeFontsSection(content);
    final fontLines = _fontLines(fonts);
    if (fontLines.isEmpty) return result;

    final lines = result.split('\n');
    final headerIndex = lines.indexWhere((line) => line == 'flutter:');
    if (headerIndex == -1) return result;

    lines.insertAll(headerIndex + 1, fontLines);
    return lines.join('\n');
  }

  String _removeFontsSection(String content) {
    final lines = content.split('\n');
    final headerIndex = lines.indexWhere((line) => line == '  fonts:');
    if (headerIndex == -1) return content;

    var end = headerIndex + 1;
    while (end < lines.length && _isDeeperIndent(lines[end], '  ')) {
      end++;
    }

    lines.removeRange(headerIndex, end);
    return lines.join('\n');
  }

  bool _isDeeperIndent(String line, String parentIndent) {
    if (line.trim().isEmpty) return true;
    final indent = line.substring(0, line.length - line.trimLeft().length);
    return indent.length > parentIndent.length;
  }

  String _syncGenerateFlag(String content, bool enabled) {
    final hasFlag = content.contains('\n  generate: true');
    if (enabled == hasFlag) return content;

    final lines = content.split('\n');
    if (!enabled) {
      lines.removeWhere((line) => line == '  generate: true');
      return lines.join('\n');
    }

    final headerIndex = lines.indexWhere((line) => line == 'flutter:');
    if (headerIndex == -1) return content;
    lines.insert(headerIndex + 1, '  generate: true');
    return lines.join('\n');
  }

  Future<String> _insertAfterSection(
    String content,
    String header,
    List<String> packages,
  ) async {
    final lines = content.split('\n');
    final headerIndex = lines.indexWhere((line) => line.trim() == header);
    if (headerIndex == -1) return content;

    final toInsert = <String>[];
    for (final package in packages) {
      if (content.contains('  $package:')) continue;
      final buffer = StringBuffer();
      await _writeDependency(buffer, package);
      toInsert.addAll(
        buffer.toString().split('\n').where((l) => l.isNotEmpty),
      );
    }

    lines.insertAll(headerIndex + 1, toInsert);
    return lines.join('\n');
  }

  static const _sdkSourcedPackages = {
    'flutter',
    'flutter_test',
    'flutter_localizations',
  };

  Future<void> _writeDependency(StringBuffer buffer, String package) async {
    if (_sdkSourcedPackages.contains(package)) {
      buffer
        ..writeln('  $package:')
        ..writeln('    sdk: flutter');
    } else {
      buffer.writeln('  $package: ${await _versionFor(package)}');
    }
  }

  Future<String> _versionFor(String package) {
    return _resolver.resolve(package, _fallbackVersionFor(package));
  }

  String _fallbackVersionFor(String package) {
    return switch (package) {
      'flutter_bloc' => DependencyVersions.flutterBloc,
      'get' => DependencyVersions.get,
      'riverpod' => DependencyVersions.riverpod,
      'http' => DependencyVersions.http,
      'dio' => DependencyVersions.dio,
      'meta' => DependencyVersions.meta,
      'shared_preferences' => DependencyVersions.sharedPreferences,
      'hive_flutter' => DependencyVersions.hiveFlutter,
      'path_provider_platform_interface' =>
        DependencyVersions.pathProviderPlatformInterface,
      'plugin_platform_interface' => DependencyVersions.pluginPlatformInterface,
      'package_info_plus' => DependencyVersions.packageInfoPlus,
      'in_app_review' => DependencyVersions.inAppReview,
      'google_fonts' => DependencyVersions.googleFonts,
      'intl' => DependencyVersions.intl,
      _ => throw StateError(
          'No centralized DependencyVersions entry for package "$package"'),
    };
  }
}
