import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

class FeatureCommand extends Command {
  final String projectPath;

  FeatureCommand({this.projectPath = '.'}) {
    argParser.addOption(
      'components',
      help: 'Comma-separated blueprint components to generate '
          '(${FeatureComponent.values.map((c) => c.name).join(', ')}). '
          'Defaults to the standard set if omitted.',
      valueHelp: 'entity,repository,page',
    );
  }

  @override
  final name = 'feature';

  @override
  final description = 'Generate a new feature in the current project, or '
      'remove one with "remove <name>"';

  @override
  String get invocation =>
      'smartwork feature <name> [--components ...] | remove <name>';

  @override
  Future<void> run() async {
    final args = argResults!.rest;

    if (args.isEmpty) {
      print('❌ Feature name is required. Usage: smartwork feature <name>');
      exitCode = 1;
      return;
    }

    if (args.first == 'remove') {
      await _runRemove(args.skip(1).toList());
      return;
    }

    await _runAdd(args);
  }

  Future<void> _runAdd(List<String> args) async {
    final featureName = args.first;

    final componentsInput = argResults!['components'] as String?;
    Set<FeatureComponent>? components;
    if (componentsInput != null) {
      final parsed = _parseComponents(componentsInput);
      if (parsed.unknown.isNotEmpty) {
        print('❌ Unknown component(s): ${parsed.unknown.join(', ')}');
        print('   Valid components: '
            '${FeatureComponent.values.map((c) => c.name).join(', ')}');
        exitCode = 1;
        return;
      }
      components = parsed.components;
    }

    try {
      final projectConfig =
          await ProjectConfigFile(projectPath: projectPath).read();
      final feature = components == null
          ? FeatureConfig(name: featureName)
          : FeatureConfig(name: featureName, components: components);

      final result = await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: feature,
      );

      _reportAddSuccess(result, feature, projectConfig,
          explicit: components != null);
    } on FileSystemException {
      print('❌ No Smartwork project found in the current directory.');
      print('   Run "smartwork init" first.');
      exitCode = 1;
    } on InvalidFeatureNameException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on FeatureAlreadyExistsException catch (e) {
      _reportConflict(e.featureName);
      exitCode = 1;
    }
  }

  Future<void> _runRemove(List<String> args) async {
    if (args.isEmpty) {
      print('❌ Feature name is required. '
          'Usage: smartwork feature remove <name>');
      exitCode = 1;
      return;
    }

    final featureName = args.first;

    try {
      final result = await FeatureLifecycle()
          .removeFeature(projectPath: projectPath, featureName: featureName);
      _reportRemoveSuccess(result);
    } on FileSystemException {
      print('❌ No Smartwork project found in the current directory.');
      print('   Run "smartwork init" first.');
      exitCode = 1;
    } on HomeFeatureNotRemovableException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on DebugFeatureNotRemovableException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on FeatureNotFoundException catch (e) {
      print('❌ ${e.featureName} was not found — nothing was removed.');
      exitCode = 1;
    }
  }

  _ParsedComponents _parseComponents(String input) {
    final components = <FeatureComponent>{};
    final unknown = <String>[];

    for (final rawToken in input.split(',')) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;

      final match = FeatureComponent.values
          .where((c) => c.name.toLowerCase() == token.toLowerCase())
          .firstOrNull;
      if (match == null) {
        unknown.add(token);
      } else {
        components.add(match);
      }
    }

    return _ParsedComponents(components, unknown);
  }

  void _reportAddSuccess(
    FeatureAddResult addResult,
    FeatureConfig feature,
    ProjectConfig config, {
    required bool explicit,
  }) {
    final result = addResult.generation;
    print('✔ Feature created: ${result.featureName}\n');

    final resolved = feature.resolveDependencies();

    if (explicit) {
      final added = resolved.components.difference(feature.components);
      print('Components: ${_namesOf(feature.components)}');
      if (added.isNotEmpty) {
        print('Resolved: ${_namesOf(resolved.components)}');
      }
      print('');
    }

    print('Architecture: ${_formatEnumName(config.architecture.name)}');
    print('State management: ${_formatEnumName(config.stateManagement.name)}');
    print('Network: ${_formatEnumName(config.network.name)}');
    print('Storage: ${_formatEnumName(config.storage.name)}\n');
    print('Generated:');
    for (final group in _componentBreakdown(resolved, config)) {
      print('  ${group.label}');
      for (final item in group.items) {
        print('    • $item');
      }
      print('');
    }
    print('Generated:');
    print('  • ${result.fileCount} files');
    print('  • ${result.directoryCount} directories');
    print('');
    if (addResult.addedToRouting) {
      print('✔ Routing updated: /${result.featureName} added to AppRouter');
    } else {
      print('ℹ Routing unchanged: ${result.featureName} has no route — '
          'either no page component was generated, or the name is '
          "reserved (this project's Home feature, or \"debug\").");
    }
    print('\nNext:');
    print('  Start implementing ${result.featureName}.');
  }

  void _reportRemoveSuccess(FeatureRemoveResult result) {
    print('✔ Feature removed: ${result.featureName}\n');
    print('Removed lib/features/${result.featureName}/ and its generated '
        'tests, if any.');
    if (result.wasRouted) {
      print('✔ Routing updated: /${result.featureName} removed from '
          'AppRouter');
    } else {
      print('ℹ Routing unchanged: ${result.featureName} had no route.');
    }
  }

  String _namesOf(Set<FeatureComponent> components) {
    final names = components.map((c) => c.name).toList()..sort();
    return names.isEmpty ? '(none)' : names.join(', ');
  }

  void _reportConflict(String featureName) {
    print('✖ Feature already exists: $featureName\n');
    print('No files were modified.\n');
    print('Use the appropriate overwrite option if regeneration is '
        'intentional.');
  }

  List<_ComponentGroup> _componentBreakdown(
    FeatureConfig feature,
    ProjectConfig config,
  ) {
    final components = feature.components;
    final stateManagementLabel = _formatEnumName(config.stateManagement.name);

    switch (config.architecture) {
      case Architecture.cleanArchitecture:
        return [
          _ComponentGroup('Domain', [
            if (components.contains(FeatureComponent.entity)) 'Entity',
            if (components.contains(FeatureComponent.repository)) 'Repository',
            if (components.contains(FeatureComponent.useCase)) 'Use case',
          ]),
          _ComponentGroup('Data', [
            if (components.contains(FeatureComponent.entity)) 'Model',
            if (components.contains(FeatureComponent.dataSource)) 'Data source',
            if (components.contains(FeatureComponent.repository)) 'Repository',
          ]),
          _ComponentGroup('Presentation', [
            stateManagementLabel,
            if (components.contains(FeatureComponent.page)) 'Page',
            if (components.contains(FeatureComponent.widgets)) 'Widget',
            if (components.contains(FeatureComponent.tests)) 'Test',
          ]),
        ].where((g) => g.items.isNotEmpty).toList();
      case Architecture.mvvm:
        return [
          _ComponentGroup('Models', [
            if (components.contains(FeatureComponent.entity)) 'Model',
          ]),
          _ComponentGroup('Services', [
            if (components.contains(FeatureComponent.repository) ||
                components.contains(FeatureComponent.dataSource) ||
                components.contains(FeatureComponent.useCase))
              'Service',
          ]),
          _ComponentGroup('Presentation', [
            stateManagementLabel,
            'ViewModel',
            if (components.contains(FeatureComponent.page)) 'Page',
            if (components.contains(FeatureComponent.widgets)) 'Widget',
            if (components.contains(FeatureComponent.tests)) 'Test',
          ]),
        ].where((g) => g.items.isNotEmpty).toList();
      case Architecture.mvp:
        return [
          _ComponentGroup('Models', [
            if (components.contains(FeatureComponent.entity)) 'Model',
          ]),
          _ComponentGroup('Services', [
            if (components.contains(FeatureComponent.repository) ||
                components.contains(FeatureComponent.dataSource) ||
                components.contains(FeatureComponent.useCase))
              'Service',
          ]),
          _ComponentGroup('Presentation', [
            stateManagementLabel,
            'Presenter',
            if (components.contains(FeatureComponent.page)) 'Page',
            if (components.contains(FeatureComponent.widgets)) 'Widget',
            if (components.contains(FeatureComponent.tests)) 'Test',
          ]),
        ].where((g) => g.items.isNotEmpty).toList();
    }
  }

  String _formatEnumName(String name) {
    return name
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _ComponentGroup {
  final String label;
  final List<String> items;

  _ComponentGroup(this.label, this.items);
}

class _ParsedComponents {
  final Set<FeatureComponent> components;
  final List<String> unknown;

  _ParsedComponents(this.components, this.unknown);
}
