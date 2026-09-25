import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

final smartworkInitPlanTool = Tool(
  name: 'smartwork_init_plan',
  description:
      'Builds and validates a canonical SmartWork project configuration '
      '(read-only — creates nothing) and reports the target directory\'s '
      'safety state. Pass the returned "plan" unchanged to '
      'smartwork_init_apply to perform the real initialization.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'Target directory. Defaults to the current '
            'directory.',
      ),
      'projectName': Schema.string(
        description: 'Project name (lowercase letters, numbers, '
            'underscores; must start with a letter).',
      ),
      'architecture': Schema.string(
        description: 'One of: cleanArchitecture, mvvm, mvp. Defaults '
            'to cleanArchitecture.',
      ),
      'stateManagement': Schema.string(
        description: 'One of: bloc, cubit, getx, riverpod. Defaults '
            'to bloc.',
      ),
      'network': Schema.string(
        description: 'One of: http, dio, other. Defaults to http.',
      ),
      'storage': Schema.string(
        description: 'One of: sharedPreferences, hive, other. '
            'Defaults to sharedPreferences.',
      ),
      'appTargets': Schema.list(
        description: 'Platforms: android, ios, web, windows, macos, '
            'linux. Defaults to [android, ios].',
        items: Schema.string(),
      ),
      'initialFeatures': Schema.list(
        description: 'Feature names to generate alongside the '
            'always-generated Home/Debug. Defaults to [home].',
        items: Schema.string(),
      ),
      'services': Schema.list(
        description: 'Production Service ids: secureSession, '
            'connectivity, deviceInfo, logger, crashReporting, '
            'notification, deeplink, analytics. Defaults to none.',
        items: Schema.string(),
      ),
      'fontType': Schema.string(
        description: 'One of: none, custom, google. Defaults to none.',
      ),
      'customFontFamily': Schema.string(
        description: 'Required when fontType is "custom": the font '
            'family name.',
      ),
      'customFontSourcePath': Schema.string(
        description: 'Required when fontType is "custom": a real path '
            '(on the machine running this server) to a .ttf or .otf '
            'file, copied into the generated project\'s assets/fonts/ '
            'by smartwork_init_apply.',
      ),
      'googleFontFamily': Schema.string(
        description: 'Required when fontType is "google": the Google '
            'Fonts family name (e.g. Roboto, Poppins, Lato).',
      ),
      'localizationEnabled': Schema.bool(
        description: 'Whether to generate localization (ARB resources, '
            'l10n.yaml, flutter_localizations/intl, and MaterialApp '
            'wiring). Defaults to false.',
      ),
      'supportedLocales': Schema.list(
        description: 'Required when localizationEnabled is true: locale '
            'codes like "en", "en_US", "pt_BR". A country/script-'
            'qualified locale also requires its bare base language in '
            'this list (a real flutter gen-l10n requirement).',
        items: Schema.string(),
      ),
      'defaultLocale': Schema.string(
        description: 'Required when localizationEnabled is true: must '
            'be one of supportedLocales.',
      ),
    },
    required: ['projectName'],
  ),
);

final smartworkInitApplyTool = Tool(
  name: 'smartwork_init_apply',
  description: 'Performs real SmartWork initialization: flutter create, then '
      'the full SmartWork generation/validation/documentation '
      'pipeline. Requires the exact canonical "plan" from '
      'smartwork_init_plan and confirm: true — never uses stdin, '
      'never uses a server-cached plan.',
  inputSchema: Schema.object(
    properties: {
      'projectPath': Schema.string(
        description: 'Target directory. Defaults to the current '
            'directory. Should match the projectPath used for '
            'smartwork_init_plan.',
      ),
      'plan': Schema.object(
        description: 'The exact canonical plan object returned by '
            'smartwork_init_plan\'s "plan" field.',
        properties: {},
      ),
      'confirm': Schema.bool(
        description: 'Must be true to perform initialization. A '
            'missing or false value performs no action.',
      ),
    },
    required: ['plan', 'confirm'],
  ),
);

class InitTools {
  final TargetStateDetector _detector;
  final ProjectInitializer _initializer;

  InitTools({
    TargetStateDetector? detector,
    ProjectInitializer? initializer,
  })  : _detector = detector ?? TargetStateDetector(),
        _initializer = initializer ?? ProjectInitializer();

  Future<CallToolResult> plan(CallToolRequest request) async {
    final args = request.arguments!;
    final projectPath = args['projectPath'] as String? ?? '.';

    ProjectConfig config;
    try {
      config = _configFromArgs(args);
    } on _InvalidConfigException catch (e) {
      return _error(
        operation: 'init_plan',
        projectPath: projectPath,
        code: 'invalid_configuration',
        message: e.message,
      );
    }

    final validationErrors = ConfigValidator.validate(config);
    if (validationErrors.isNotEmpty) {
      return _error(
        operation: 'init_plan',
        projectPath: projectPath,
        code: 'invalid_configuration',
        message: validationErrors.map((e) => e.toString()).join('; '),
      );
    }

    try {
      final detected = await _detector.detect(projectPath);
      final safety = <String, Object?>{
        'state': detected.state.name,
        'isRegeneration': detected.state != TargetProjectState.empty,
        'existingPlatforms':
            detected.existingPlatforms.map((t) => t.name).toList(),
      };
      if (detected.state == TargetProjectState.malformedSmartworkProject) {
        safety['detectionError'] = detected.detectionError;
      }
      if (detected.existingConfig != null) {
        final existing = detected.existingConfig!;
        final targetPlan = TargetChangePlan.compute(
          current: existing.appTargets,
          requested: config.appTargets,
        );
        final serviceChanges = ServiceChanges.compute(
          current: existing.services,
          desired: config.services,
        );
        safety['appTargetsDiff'] = {
          'added': targetPlan.added.map((t) => t.name).toList(),
          'removedFromConfig':
              targetPlan.removedFromConfig.map((t) => t.name).toList(),
        };
        safety['serviceChanges'] = {
          'added': serviceChanges.added.toList(),
          'removed': serviceChanges.removed.toList(),
          'unchanged': serviceChanges.unchanged.toList(),
        };
      }

      return CallToolResult(
        content: [TextContent(text: 'Plan ready for $projectPath.')],
        structuredContent: {
          'success': true,
          'operation': 'init_plan',
          'plan': config.toYaml(),
          'safety': safety,
        },
      );
    } catch (_) {
      return _unexpectedError('init_plan', projectPath);
    }
  }

  Future<CallToolResult> apply(CallToolRequest request) async {
    final args = request.arguments!;
    final projectPath = args['projectPath'] as String? ?? '.';
    final confirm = args['confirm'] as bool? ?? false;

    if (!confirm) {
      return _error(
        operation: 'init_apply',
        projectPath: projectPath,
        code: 'confirmation_required',
        message: 'confirm must be true to perform initialization. '
            'No files were changed.',
      );
    }

    final planMap = args['plan'];
    if (planMap is! Map) {
      return _error(
        operation: 'init_apply',
        projectPath: projectPath,
        code: 'invalid_configuration',
        message: 'plan must be the canonical object returned by '
            'smartwork_init_plan.',
      );
    }

    ProjectConfig config;
    try {
      config = ProjectConfig.fromYaml(Map<String, dynamic>.from(planMap));
    } catch (e) {
      return _error(
        operation: 'init_apply',
        projectPath: projectPath,
        code: 'invalid_configuration',
        message: 'plan is not a valid SmartWork configuration: $e',
      );
    }

    final validationErrors = ConfigValidator.validate(config);
    if (validationErrors.isNotEmpty) {
      return _error(
        operation: 'init_apply',
        projectPath: projectPath,
        code: 'invalid_configuration',
        message: validationErrors.map((e) => e.toString()).join('; '),
      );
    }

    try {
      final detected = await _detector.detect(projectPath);
      final result = await _initializer.initialize(
        projectPath: projectPath,
        config: config,
        clearExisting: detected.state != TargetProjectState.empty,
      );

      return CallToolResult(
        content: [
          TextContent(
            text: 'Initialized ${config.projectName} at $projectPath.',
          ),
        ],
        structuredContent: {
          'success': true,
          'operation': 'init_apply',
          'projectPath': projectPath,
          'plan': config.toYaml(),
          'result': {
            'fileCount': result.generation.fileCount,
            'directoryCount': result.generation.directoryCount,
            'featureCount': result.generation.featureCount,
            'validationPhases': [
              for (final phase in result.validation.phases)
                {'phase': phase.phase.name, 'passed': phase.passed},
            ],
          },
        },
      );
    } on FlutterBootstrapException catch (e) {
      return _error(
        operation: 'init_apply',
        projectPath: projectPath,
        code: 'flutter_bootstrap_failed',
        message: e.toString(),
      );
    } on FeatureAlreadyExistsException catch (e) {
      return _error(
        operation: 'init_apply',
        projectPath: projectPath,
        code: 'feature_already_exists',
        message: e.toString(),
      );
    } on ProjectValidationFailedException catch (e) {
      return _error(
        operation: 'init_apply',
        projectPath: projectPath,
        code: 'validation_failed',
        message: e.details,
      );
    } catch (_) {
      return _unexpectedError('init_apply', projectPath);
    }
  }

  ProjectConfig _configFromArgs(Map<String, Object?> args) {
    try {
      return ProjectConfig(
        projectName: args['projectName'] as String,
        appTargets: _stringList(args['appTargets'])
            ?.map((v) => AppTarget.values.byName(v))
            .toSet(),
        architecture: Architecture.values
            .byName(args['architecture'] as String? ?? 'cleanArchitecture'),
        stateManagement: StateManagement.values
            .byName(args['stateManagement'] as String? ?? 'bloc'),
        network: Network.values.byName(args['network'] as String? ?? 'http'),
        storage: Storage.values
            .byName(args['storage'] as String? ?? 'sharedPreferences'),
        services: _stringList(args['services'])?.toSet(),
        fonts: _fontConfigFromArgs(args),
        localization: _localizationConfigFromArgs(args),
        initialFeatures: _stringList(args['initialFeatures']) ?? const ['home'],
      );
    } catch (e) {
      throw _InvalidConfigException('$e');
    }
  }

  FontConfig _fontConfigFromArgs(Map<String, Object?> args) {
    final type = FontType.values.byName(args['fontType'] as String? ?? 'none');
    return switch (type) {
      FontType.none => FontConfig.none(),
      FontType.custom => FontConfig.custom(CustomFontConfig(
          family: args['customFontFamily'] as String? ?? '',
          files: [
            CustomFontFile(
              sourcePath: args['customFontSourcePath'] as String? ?? '',
            ),
          ],
        )),
      FontType.google => FontConfig.google(GoogleFontConfig(
          family: args['googleFontFamily'] as String? ?? '',
        )),
    };
  }

  LocalizationConfig _localizationConfigFromArgs(Map<String, Object?> args) {
    if (args['localizationEnabled'] != true) {
      return LocalizationConfig.disabled();
    }
    return LocalizationConfig.enabled(
      supportedLocales: _stringList(args['supportedLocales']) ?? const [],
      defaultLocale: args['defaultLocale'] as String? ?? '',
    );
  }

  List<String>? _stringList(Object? value) =>
      (value as List?)?.map((v) => v as String).toList();

  CallToolResult _error({
    required String operation,
    required String projectPath,
    required String code,
    required String message,
  }) =>
      CallToolResult(
        isError: true,
        content: [TextContent(text: message)],
        structuredContent: {
          'success': false,
          'operation': operation,
          'projectPath': projectPath,
          'error': {'code': code, 'message': message},
        },
      );

  CallToolResult _unexpectedError(String operation, String projectPath) =>
      _error(
        operation: operation,
        projectPath: projectPath,
        code: 'unexpected_error',
        message: 'An unexpected error occurred while running $operation.',
      );
}

class _InvalidConfigException {
  final String message;
  _InvalidConfigException(this.message);
}
