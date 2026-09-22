import '../models/font_config.dart';
import '../models/project_config.dart';
import '../models/service_definition.dart';
import '../template/naming_conventions.dart';
import 'routing_generator.dart';

class ProjectDocumentationGenerator {
  Map<String, String> generateAll(ProjectConfig config) {
    return {
      'README.md': _writeReadme(config),
      'docs/architecture.md': _writeArchitectureDoc(config),
      'docs/services.md': _writeServicesDoc(config),
      'docs/development.md': _writeDevelopmentDoc(config),
      'docs/testing.md': _writeTestingDoc(config),
    };
  }

  String _writeReadme(ProjectConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('# ${_titleCase(config.projectName)}');
    buffer.writeln();
    buffer.writeln('## Overview');
    buffer.writeln();
    buffer.writeln('| | |');
    buffer.writeln('|---|---|');
    buffer.writeln('| Project name | `${config.projectName}` |');
    buffer.writeln(
        '| Architecture | ${_architectureLabel(config.architecture)} |');
    buffer.writeln(
        '| State management | ${_stateManagementLabel(config.stateManagement)} |');
    buffer.writeln('| Network | ${_networkLabel(config.network)} |');
    buffer.writeln('| Storage | ${_storageLabel(config.storage)} |');
    buffer.writeln('| App Targets | ${_appTargetsLabel(config)} |');
    buffer.writeln('| Home feature | `${config.homeFeatureName}` |');
    buffer.writeln('| Initial features | ${_initialFeaturesLabel(config)} |');
    buffer.writeln();
    buffer.writeln(
        'This document describes the actual structure and conventions of '
        '`${config.projectName}`, reflecting this project\'s own current '
        'configuration.');
    buffer.writeln();
    buffer.writeln('## Documentation');
    buffer.writeln();
    buffer.writeln('- [Architecture](docs/architecture.md) — architecture, '
        'state management, application targets, folder/feature '
        'structure, and models.');
    buffer.writeln('- [Services](docs/services.md) — network, storage, '
        'routing, application startup, environment configuration, and '
        'optional services.');
    buffer.writeln('- [Development](docs/development.md) — constants, '
        'assets, debug tools, code conventions, and guidelines.');
    buffer.writeln('- [Testing](docs/testing.md) — test layout, '
        'API-dependent tests, and coverage.');
    buffer.writeln();
    return buffer.toString();
  }

  String _appTargetsLabel(ProjectConfig config) {
    return config.orderedAppTargets.map((t) => t.displayName).join(', ');
  }

  String _titleCase(String projectName) {
    return projectName
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _initialFeaturesLabel(ProjectConfig config) {
    if (config.initialFeatures.isEmpty) return '(none beyond Home)';
    return config.initialFeatures.map((f) => '`$f`').join(', ');
  }

  String _writeArchitectureDoc(ProjectConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('# Architecture');
    buffer.writeln();
    buffer.writeln('[← Back to README](../README.md)');
    buffer.writeln();
    _writeArchitecture(buffer, config);
    _writeStateManagement(buffer, config);
    _writeAppTarget(buffer, config);
    _writeFolderStructure(buffer, config);
    _writeFeatureStructure(buffer, config);
    _writeModelAndEntity(buffer, config);
    _writeUtilities(buffer);
    return buffer.toString();
  }

  void _writeArchitecture(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Architecture');
    buffer.writeln();
    switch (config.architecture) {
      case Architecture.cleanArchitecture:
        buffer.writeln(
            'This project uses **Clean Architecture**. Each feature is '
            'split into three layers:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('lib/features/<feature>/');
        buffer.writeln(
            '├── domain/        # Entities, repository contracts, use cases');
        buffer.writeln(
            '├── data/          # Models, data sources, repository implementations');
        buffer.writeln('└── presentation/  # Pages, widgets, state management');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln('Dependencies flow in one direction:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('Presentation');
        buffer.writeln('    ↓');
        buffer.writeln('Domain');
        buffer.writeln('    ↓');
        buffer.writeln('Data');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln('`presentation/` depends on `domain/` (a repository '
            '*contract*, never a concrete data source). `data/` '
            'implements that contract and is the only layer that knows '
            'about `domain/`\'s entities and about network/storage '
            'details. `domain/` depends on nothing else in the feature.');
      case Architecture.mvvm:
        buffer.writeln(
            'This project uses **MVVM** (Model-View-ViewModel). There is '
            'no separate domain layer — a feature is a flat set of '
            'folders:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('lib/features/<feature>/');
        buffer.writeln('├── models/      # Concrete data models');
        buffer.writeln('├── services/    # Network/storage access');
        buffer.writeln('├── viewmodels/  # Presentation state and logic');
        buffer.writeln('└── views/       # Pages and widgets');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln('The relationship between them:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('View');
        buffer.writeln('  ↓');
        buffer.writeln('ViewModel');
        buffer.writeln('  ↓');
        buffer.writeln('Repository / Service');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln('A View reads from and calls into its ViewModel; the '
            'ViewModel calls the feature\'s Service to fetch or persist '
            'data. There is no separate domain-versus-data split — MVVM '
            'collapses that distinction into `services/`.');
      case Architecture.mvp:
        buffer.writeln('This project uses **MVP** (Model-View-Presenter). Like '
            'MVVM, there is no separate domain layer:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('lib/features/<feature>/');
        buffer.writeln('├── models/      # Concrete data models');
        buffer.writeln('├── services/    # Network/storage access');
        buffer.writeln('├── presenters/  # Presentation state and logic');
        buffer.writeln('└── views/       # Pages and widgets');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln('The relationship between them:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('View');
        buffer.writeln('  ↓');
        buffer.writeln('Presenter');
        buffer.writeln('  ↓');
        buffer.writeln('Repository / Service');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln(
            'A View delegates to its Presenter; the Presenter calls the '
            "feature's Service to fetch or persist data. There is no "
            'separate domain-versus-data split — MVP collapses that '
            'distinction into `services/`.');
    }
    buffer.writeln();
  }

  void _writeStateManagement(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## State Management');
    buffer.writeln();
    switch (config.stateManagement) {
      case StateManagement.bloc:
        buffer.writeln(
            'This project uses **BLoC**. Every feature gets a `state/` '
            'folder containing:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('state/');
        buffer.writeln('├── <feature>_event.dart');
        buffer.writeln('├── <feature>_state.dart');
        buffer.writeln('└── <feature>_bloc.dart');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln('The Bloc receives events and emits states; the '
            'presentation layer (page/view) dispatches events and '
            'rebuilds from emitted states.');
      case StateManagement.cubit:
        buffer.writeln('This project uses **Cubit** (the simplified BLoC '
            'variant — same `flutter_bloc` package). Every feature gets '
            'a `state/` folder containing:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln('state/');
        buffer.writeln('├── <feature>_state.dart');
        buffer.writeln('└── <feature>_cubit.dart');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln(
            'The Cubit exposes methods that emit new states directly — '
            'no separate event type, unlike BLoC.');
      case StateManagement.getx:
        buffer.writeln('This project uses **GetX**.');
        buffer.writeln();
        switch (config.architecture) {
          case Architecture.cleanArchitecture:
            buffer.writeln('Each feature gets a GetX controller under '
                '`presentation/getx/<feature>_controller.dart`, holding '
                'the feature\'s reactive state.');
          case Architecture.mvvm:
            buffer.writeln("GetX's reactivity lives directly in each feature's "
                'existing ViewModel (`viewmodels/<feature>_view_model.dart`) '
                '— MVVM does not generate a separate GetX controller '
                'file, since the ViewModel already owns presentation '
                'state.');
          case Architecture.mvp:
            buffer.writeln("GetX's reactivity lives directly in each feature's "
                'existing Presenter (`presenters/<feature>_presenter.dart`) '
                '— MVP does not generate a separate GetX controller '
                'file, since the Presenter already owns presentation '
                'state.');
        }
      case StateManagement.riverpod:
        buffer.writeln('This project uses **Riverpod**.');
        buffer.writeln();
        final providersPath = switch (config.architecture) {
          Architecture.cleanArchitecture => 'presentation/providers/',
          Architecture.mvvm || Architecture.mvp => 'providers/',
        };
        buffer
            .writeln('Each feature gets a `$providersPath` folder containing:');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln(providersPath);
        buffer.writeln('├── <feature>_state.dart');
        buffer.writeln('└── <feature>_provider.dart');
        buffer.writeln('```');
        buffer.writeln();
        buffer
            .writeln('The provider exposes the feature\'s state to the widget '
                'tree; the presentation layer watches it with `ref.watch`.');
    }
    buffer.writeln();
  }

  void _writeAppTarget(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Application Targets');
    buffer.writeln();
    buffer.writeln('This project targets:');
    buffer.writeln();
    for (final target in config.orderedAppTargets) {
      buffer.writeln('- ${target.displayName}');
    }
    buffer.writeln();
    buffer.writeln(
        'Each target above has a real Flutter platform folder (`android/`, '
        '`ios/`, `web/`, `windows/`, `macos/`, `linux/`) for exactly the '
        'targets this project supports — never a platform that was not '
        'selected. See [Responsive UI Guidelines](../docs/development.md) '
        'for what supporting more than one target implies about layout and '
        'responsiveness.');
    buffer.writeln();
  }

  void _writeFolderStructure(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Folder Structure');
    buffer.writeln();
    buffer.writeln('```text');
    buffer.writeln('lib/');
    buffer.writeln('├── core/');
    buffer.writeln('│   ├── constants/     # Centralized project constants');
    buffer.writeln(
        '│   ├── environment/   # Environment selection (Production/Staging/Development)');
    buffer.writeln(
        '│   └── utilities/     # General-purpose helpers (see Utilities below)');
    buffer.writeln('├── services/');
    buffer.writeln('│   ├── bootstrap/     # Application startup boundary');
    buffer.writeln('│   ├── network/       # NetworkService');
    buffer
        .writeln('│   ├── routing/       # AppRouter (native Flutter routing)');
    buffer.writeln('│   ├── storage/       # StorageService');
    final hasOptionalServices = config.orderedServices.isNotEmpty;
    buffer.writeln(
        '│   ${hasOptionalServices ? '├──' : '└──'} theme/         # ThemeService (theme mode selection)');
    for (var i = 0; i < config.orderedServices.length; i++) {
      final service = config.orderedServices[i];
      final branch = i == config.orderedServices.length - 1 ? '└──' : '├──';
      final label = '│   $branch ${service.folderName}/';
      buffer.writeln('${label.padRight(24)}# ${service.displayName}');
    }
    buffer.writeln('├── features/');
    buffer.writeln(
        '│   ├── debug/         # Framework-level Debug feature (see Development)');
    final allFeatures =
        {config.homeFeatureName, ...config.initialFeatures}.toList();
    for (var i = 0; i < allFeatures.length; i++) {
      final branch = i == allFeatures.length - 1 ? '└──' : '├──';
      buffer.writeln('│   $branch ${allFeatures[i]}/');
    }
    buffer.writeln('└── main.dart');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('`lib/core/` holds only project-wide constants, '
        'Environment, and general-purpose utilities (see Utilities '
        'below) — nothing feature-specific belongs there. '
        '`lib/services/` holds every project-level service — '
        '`Bootstrap`/`AppRouter`/`NetworkService`/`StorageService`/'
        '`ThemeService` always, plus one folder per selected optional '
        'service (see [Services](../docs/services.md)) — never a `core/` '
        'foundation piece and never a feature. `lib/features/` holds every '
        'generated feature (including the framework Debug feature — see '
        '[Development](../docs/development.md)), each self-contained '
        'under its own directory.');
    buffer.writeln();
  }

  void _writeFeatureStructure(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Feature Structure');
    buffer.writeln();
    buffer.writeln('A feature with the full set of layers looks like this:');
    buffer.writeln();
    buffer.writeln('```text');
    switch (config.architecture) {
      case Architecture.cleanArchitecture:
        buffer.writeln('features/<feature>/');
        buffer.writeln('├── domain/');
        buffer.writeln('│   ├── entities/<feature>.dart');
        buffer.writeln('│   ├── repositories/<feature>_repository.dart');
        buffer.writeln('│   └── usecases/<feature>_usecase.dart');
        buffer.writeln('├── data/');
        buffer.writeln('│   ├── models/<feature>_model.dart');
        buffer.writeln('│   ├── datasources/<feature>_data_source.dart');
        buffer.writeln('│   └── repositories/<feature>_repository_impl.dart');
        buffer.writeln('├── presentation/');
        buffer.writeln('│   └── pages/<feature>_page.dart');
        buffer.writeln('└── <feature>.dart   # public export barrel');
      case Architecture.mvvm:
        buffer.writeln('features/<feature>/');
        buffer.writeln('├── models/<feature>_model.dart');
        buffer.writeln('├── services/<feature>_service.dart');
        buffer.writeln('├── viewmodels/<feature>_view_model.dart');
        buffer.writeln('├── views/<feature>_page.dart');
        buffer.writeln('└── <feature>.dart   # public export barrel');
      case Architecture.mvp:
        buffer.writeln('features/<feature>/');
        buffer.writeln('├── models/<feature>_model.dart');
        buffer.writeln('├── services/<feature>_service.dart');
        buffer.writeln('├── presenters/<feature>_presenter.dart');
        buffer.writeln('├── views/<feature>_page.dart');
        buffer.writeln('└── <feature>.dart   # public export barrel');
    }
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln(
        '`<feature>.dart` is the feature\'s public export — it exports '
        'only the model/entity and the page, never internal wiring '
        '(data sources, repository implementations, use cases). Other '
        'features and `main.dart`/`AppRouter` should import a feature '
        'through this file, not its internals directly. See [Development]'
        '(../docs/development.md) for the complete export/import '
        'convention.');
    buffer.writeln();
  }

  void _writeModelAndEntity(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Model and Entity');
    buffer.writeln();
    buffer.writeln('Models in this project are intentionally minimal: a '
        'concrete class with a single `const` constructor, no fields '
        'unless you add them, and no JSON serialization unless a feature '
        'needs it.');
    buffer.writeln();
    switch (config.architecture) {
      case Architecture.cleanArchitecture:
        buffer.writeln('```dart');
        buffer.writeln('// domain/entities/<feature>.dart');
        buffer.writeln('class <Feature> {');
        buffer.writeln('  const <Feature>();');
        buffer.writeln('}');
        buffer.writeln();
        buffer.writeln('// data/models/<feature>_model.dart');
        buffer.writeln('class <Feature>Model extends <Feature> {');
        buffer.writeln('  const <Feature>Model();');
        buffer.writeln('}');
        buffer.writeln('```');
        buffer.writeln();
        buffer
            .writeln('The Entity is the domain-level representation; the Model '
                'extends it and is what data sources actually return.');
      case Architecture.mvvm:
      case Architecture.mvp:
        buffer.writeln('```dart');
        buffer.writeln('// models/<feature>_model.dart');
        buffer.writeln('class <Feature>Model {');
        buffer.writeln('  const <Feature>Model();');
        buffer.writeln('}');
        buffer.writeln('```');
        buffer.writeln();
        buffer.writeln(
            'This architecture has no separate domain layer, so there is '
            'only one Model — no Entity.');
    }
    buffer.writeln();
    buffer.writeln('When a feature needs fields and JSON parsing, models in '
        'this project follow one consistent shape: typed fields, a '
        '`const` constructor, `factory fromJson(Map<String, dynamic> '
        'json)`, and `Map<String, dynamic> toJson()`. A nested object or '
        'a list of objects gets its own model class in its own file (for '
        'example, `address` → `AddressModel`, `users` → '
        '`UsersItemModel`). Serialization stays plain, hand-written Dart '
        '— this project does not use a `json_serializable`/`freezed`/'
        '`build_runner` dependency. For anything beyond that (equality, '
        '`copyWith`, a serialization package, ...) add it only when a '
        'feature actually needs it.');
    buffer.writeln();
  }

  void _writeUtilities(StringBuffer buffer) {
    buffer.writeln('## Utilities');
    buffer.writeln();
    buffer.writeln('`lib/core/utilities/` holds small, general-purpose '
        'helpers with no business logic of their own, exported through '
        'one barrel (`lib/core/utilities/utilities.dart`):');
    buffer.writeln();
    buffer.writeln('- **`AppPlatform`** — `isWeb`/`isAndroid`/`isIOS`/'
        '`isWindows`/`isMacOS`/`isLinux`/`isMobile`/`isDesktop`, '
        'resolved from Flutter\'s own `kIsWeb`/`defaultTargetPlatform`.');
    buffer.writeln('- **`DateTimeExtensions`** (on `DateTime`) — '
        '`isToday`/`isYesterday`/`isTomorrow`/`startOfDay`/`endOfDay`. '
        'Pure calendar-day comparisons — no formatting, no locale.');
    buffer.writeln('- **`NullableStringExtensions`**/**`StringExtensions`** '
        '(on `String?`/`String`) — `isNullOrEmpty`/`isBlank`/'
        '`capitalize()`/`capitalizeWords()`.');
    buffer.writeln('- **`HexColor`**/**`ColorHex`** (on `String`/`Color`) '
        '— `toColor()`/`tryToColor()` and `toHex()`, for a color that '
        'arrives as data (an API response, a JSON sample, a '
        'remote-config value) rather than a compile-time constant.');
    buffer.writeln('- **`FileSizeFormat`** (on `int`) — '
        '`toFileSizeString()` renders a byte count as `\'1.2 MB\'`-style '
        'text.');
    buffer.writeln();
    buffer.writeln('Import the barrel (`core/utilities/utilities.dart`) '
        'rather than an individual file — the same convention '
        '`core/constants/constants.dart` already establishes.');
    buffer.writeln();
  }

  String _writeServicesDoc(ProjectConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('# Services');
    buffer.writeln();
    buffer.writeln('[← Back to README](../README.md)');
    buffer.writeln();
    _writeNetworkLayer(buffer, config);
    _writeStorageLayer(buffer, config);
    _writeRouting(buffer, config);
    _writeBootstrap(buffer, config);
    _writeEnvironment(buffer);
    _writeServices(buffer, config);
    return buffer.toString();
  }

  void _writeNetworkLayer(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Network Layer');
    buffer.writeln();
    buffer.writeln(
        'Network is a project-level service: `NetworkService` (`lib/services/'
        'network/network_service.dart`) is the single boundary every '
        'feature\'s data source/service calls — never `package:http`/'
        '`package:dio` directly. Each of GET/POST/PUT/PATCH/DELETE takes '
        'a path plus `queryParameters` (a plain `Map<String, String>` — '
        'the service builds and percent-encodes the final request URI '
        'itself, so callers never hand-build `?a=b&c=d`), a request '
        '`body`, `headers` (merged on top of the service\'s own default '
        'headers, with a request header winning on a name collision), '
        'and an optional per-request `timeout` overriding the service\'s '
        'own default for that one call. An `Authorization` token '
        '(`setAuthToken`) is one of those default headers. Errors are a '
        'provider-neutral model (`NetworkException` and its subtypes — '
        '`NetworkTimeoutException` for a timed-out request, '
        '`NetworkConnectionException` for a connection that could not be '
        'made at all, `UnauthorizedException`/`ForbiddenException`/'
        '`NotFoundException`/`ServerErrorException` for real HTTP status '
        'codes, `InvalidResponseException` for a response that could not '
        'be treated as one, and `UnknownNetworkException` as the final '
        'fallback — see `network_exception.dart`) — a feature never '
        'needs to know which provider actually threw. It resolves its '
        'base URL from `EnvironmentManager.instance.currentBaseUrl` (see '
        'Environment Configuration below) at request time — never a '
        'hardcoded host — so switching the active environment (via the '
        'Debug screen, see [Development](../docs/development.md)) '
        'changes what the *next* request resolves to, with no code '
        'regeneration or app restart required.');
    buffer.writeln();
    if (config.network == Network.other) {
      buffer.writeln('This project has `Network.other` configured: '
          '`NetworkService` adds no networking dependency, and every '
          'request method throws `UnimplementedError` until you add your '
          'own networking package (e.g. `http`, `dio`, or another of '
          'your choice) and implement it inside `network_service.dart`. '
          'Every feature already calls this one class, so nothing else '
          'needs to change once you do.');
    } else {
      buffer.writeln('This project uses **${_networkLabel(config.network)}** '
          'as `NetworkService`\'s provider.');
    }
    buffer.writeln();
    final fileLabel = switch (config.architecture) {
      Architecture.cleanArchitecture =>
        'data/datasources/<feature>_network_data_source.dart',
      Architecture.mvvm ||
      Architecture.mvp =>
        'services/<feature>_service.dart',
    };
    buffer.writeln('A feature with a data source gets a `$fileLabel` that '
        'calls `NetworkService.instance.get(...)` and returns the '
        'feature\'s Model (see [Architecture](architecture.md)) — '
        'identical regardless of the provider configured above.');
    buffer.writeln();
  }

  void _writeStorageLayer(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Storage Layer');
    buffer.writeln();
    final alsoThroughStorageService = [
      'EnvironmentManager',
      'ThemeService',
      if (config.services.contains(Service.secureSession.id))
        'SecureSessionManager',
    ].map((name) => '`$name`').join('/');
    buffer.writeln('Storage is a project-level service: `StorageService` (`lib/'
        'services/storage/storage_service.dart`) is the single boundary '
        'every feature\'s local data source/service, plus '
        '$alsoThroughStorageService, persist through — never '
        '`package:shared_preferences`/`package:hive_flutter` directly. It '
        'is deliberately simple, provider-neutral *value* storage — '
        '`get`/`set` for `String`/`bool`/`int`/`double`/`List<String>` '
        'values (the same typed surface SharedPreferences itself already '
        'exposes), plus `containsKey`/`remove`/`clear` — never a '
        'database abstraction.');
    buffer.writeln();
    if (config.storage == Storage.other) {
      buffer.writeln('This project has `Storage.other` configured: '
          '`StorageService` adds no persistence dependency and keeps '
          'values in memory only — a genuinely working implementation, '
          'not a placeholder, but one that does not survive an app '
          'restart. Add your own package (e.g. `shared_preferences`, '
          '`hive_flutter`, or another of your choice) and replace its '
          'method bodies if you need real persistence. Because '
          '`EnvironmentManager`/`ThemeService` also persist through '
          '`StorageService`, the Debug screen\'s Environment/Theme '
          'selection (see [Development](../docs/development.md)) still '
          'works for the running session, but does not survive a restart '
          'either.');
    } else {
      buffer.writeln('This project uses **${_storageLabel(config.storage)}** '
          'as `StorageService`\'s provider.');
    }
    buffer.writeln();
    final fileLabel = switch (config.architecture) {
      Architecture.cleanArchitecture =>
        'data/datasources/<feature>_local_data_source.dart',
      Architecture.mvvm ||
      Architecture.mvp =>
        'services/<feature>_local_service.dart',
    };
    buffer.writeln(
        'A feature with a data source also gets a `$fileLabel` that calls '
        '`StorageService.instance.getString(...)` — generated alongside '
        '(never in place of) the network implementation — identical '
        'regardless of the provider configured above. '
        '`EnvironmentManager`/`ThemeService` use the same service '
        'directly — see [Development](../docs/development.md)\'s '
        'Constants section for the keys they persist under.');
    buffer.writeln();
  }

  void _writeRouting(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Routing');
    buffer.writeln();
    buffer
        .writeln('Routing uses native Flutter navigation — `MaterialPageRoute` '
            'and `onGenerateRoute` — no routing package. `AppRouter` — a '
            'project-level service like every other piece under '
            '`lib/services/` (`lib/services/routing/app_router.dart`) — '
            'is the single owner of route identifiers:');
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln("static const String home = '/';");
    buffer.writeln("static const String debug = '/debug';");
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln(
        '`home` resolves to `${_pascal(config.homeFeatureName)}Page` (the '
        'configured Home feature, `${config.homeFeatureName}`) and is the '
        "app's initial route. `debug` resolves to the architecture-"
        'specific Debug screen (see [Development](../docs/development.md)) '
        "— reached only through the Home screen's version-tap unlock, "
        'never a visible navigation entry. An unrecognized route name '
        'falls back to `home`.');
    buffer.writeln();
    buffer.writeln(
        '`AppRouter` is architecture-independent: it is the same mechanism '
        'no matter which architecture is selected. Debug is a real '
        'feature (`lib/features/debug/`) with its own public export '
        'barrel, imported exactly like Home — `AppRouter` never needs to '
        'know which architecture-specific file the Debug screen actually '
        'lives at.');
    buffer.writeln();
    final routableFeatures = RoutingGenerator.resolveRoutableFeatureNames(
      config.initialFeatures,
      homeFeatureName: config.homeFeatureName,
    );
    buffer.writeln(
        'Every other feature listed in this project\'s configuration also '
        'gets a route, at `/<feature>` resolving to `<Feature>Page` — '
        'imported through the feature\'s own public export barrel '
        '(`features/<feature>/<feature>.dart`, see [Architecture]'
        '(architecture.md)), never an architecture-specific internal '
        'path. Currently: ${_routableFeaturesLabel(routableFeatures)}.');
    buffer.writeln();
    buffer.writeln('`AppRouter` is the single owner of the *complete* routing '
        'state — it is regenerated from scratch (never incrementally '
        'patched) whenever a feature is added or removed (see '
        '[Development](../docs/development.md)\'s Adding a Feature '
        'section), so a feature\'s route always matches the project\'s '
        'actual current feature set. A feature with no page has nothing '
        'to navigate to and is never given a route.');
    buffer.writeln();
  }

  String _routableFeaturesLabel(List<String> routableFeatures) {
    if (routableFeatures.isEmpty) return '(none beyond Home)';
    return routableFeatures.map((f) => '`/$f`').join(', ');
  }

  void _writeBootstrap(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Bootstrap');
    buffer.writeln();
    buffer
        .writeln('`Bootstrap` — a project-level service like every other piece '
            'under `lib/services/` (`lib/services/bootstrap/bootstrap.dart`) '
            "— is the single application initialization boundary. "
            "`main.dart`'s flow is:");
    buffer.writeln();
    buffer.writeln('```text');
    buffer.writeln('main()');
    buffer.writeln('  ↓');
    buffer.writeln('Bootstrap.initialize()');
    buffer.writeln('  ↓');
    buffer.writeln('runApp()');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('`Bootstrap.initialize()` runs, in this deterministic, '
        'dependency-safe order:');
    buffer.writeln();
    buffer.writeln('- `StorageService.instance.initialize()` — the '
        'project-level persistence mechanism everything below reads '
        'through;');
    buffer.writeln(
        '- loads the persisted Environment (see Environment Configuration '
        'below);');
    buffer
        .write('- loads the persisted Theme mode (`ThemeService`, see Storage '
            'Layer above)');
    final initializedServices =
        config.orderedServices.where((s) => s.hasInitialize).toList();
    if (initializedServices.isEmpty) {
      buffer.writeln('.');
      buffer.writeln();
      buffer.writeln(
          'That is the complete set of initialization logic today — no '
          'selected optional service (see Production Services below) has '
          'a real `initialize()` to call (`NetworkService` never needs '
          'one either). If a new service with real initialization is '
          'added to this project later, its call belongs here too, not '
          'scattered elsewhere.');
    } else {
      buffer.writeln(';');
      buffer.writeln(
          "- then initializes this project's selected optional services "
          'that have real initialization logic (see Production Services '
          'below), in this fixed, deterministic order:');
      buffer.writeln();
      for (final service in initializedServices) {
        buffer.writeln('  - `${service.className}` (`${service.displayName}`)');
      }
      buffer.writeln();
      final skipped = config.orderedServices
          .where((s) => !s.hasInitialize)
          .map((s) => '`${s.className}`')
          .join(', ');
      buffer.writeln('A service not selected here has no generated file and is '
          'never initialized.${skipped.isEmpty ? '' : ' Selected services '
              'with no real initialization logic ($skipped) are present '
              'but never mentioned in Bootstrap — there is no meaningless '
              '`await service.initialize();` on a method that does '
              'nothing.'}');
    }
    buffer.writeln();
  }

  void _writeEnvironment(StringBuffer buffer) {
    buffer.writeln('## Environment Configuration');
    buffer.writeln();
    buffer
        .writeln('The project supports three environments — `Environment.prod` '
            '(Production), `Environment.stage` (Staging), and '
            '`Environment.dev` (Development), defined in '
            '`lib/core/environment/environment.dart`. This is runtime/'
            'debug-oriented functionality: it lets a developer switch '
            'environments from the Debug screen (see [Development]'
            '(../docs/development.md)) without rebuilding the app.');
    buffer.writeln();
    buffer.writeln('- `EnvironmentUrls` (`environment_urls.dart`) maps each '
        '`Environment` to its base URL, sourced from `ApiConstants` (see '
        '[Development](../docs/development.md)\'s Constants section) — '
        'the single place those URLs are declared.');
    buffer.writeln('- `EnvironmentManager` (`environment_manager.dart`) is a '
        'singleton (`EnvironmentManager.instance`) exposing '
        '`currentEnvironment` and `currentBaseUrl`, and `load()`/'
        '`setEnvironment()` to read/persist the active choice.');
    buffer.writeln('- The default environment is **Production**.');
    buffer.writeln('- Only the environment *identifier* (e.g. `prod`) is '
        'persisted — never a URL. The base URL is always resolved '
        'fresh from `ApiConstants` through `EnvironmentUrls`.');
    buffer.writeln('- `NetworkService` (see Network Layer above) reads '
        '`EnvironmentManager.instance.currentBaseUrl` on every '
        'request, so a switched environment takes effect immediately.');
    buffer.writeln();
  }

  void _writeServices(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Production Services');
    buffer.writeln();

    if (config.orderedServices.isEmpty) {
      buffer.writeln('This project has no Production Services selected. To '
          'add one, create a new folder under `lib/services/<name>/` '
          'following the same shape as the always-present services '
          '(`network/`, `storage/`, `theme/`, ...), export it from '
          '`lib/services/services.dart`, and initialize it from '
          '`Bootstrap.initialize()` (see Bootstrap above) if it needs '
          'startup logic.');
      buffer.writeln();
      return;
    }

    buffer.writeln('This project includes:');
    buffer.writeln();
    for (final service in config.orderedServices) {
      buffer.writeln('- **${service.displayName}** '
          '(`${service.className}`, '
          '`lib/services/${service.folderName}/${service.fileName}`) — '
          '${service.purpose}');
    }
    buffer.writeln();
    buffer.writeln('**Location.** Services live outside `core/` and '
        '`features/`, each in its own subfolder under the top-level '
        '`lib/services/` folder (`lib/services/${config.orderedServices.first.folderName}/`, ...) '
        '— a project-level capability boundary, not a `core/` foundation '
        'piece and not a feature component. Only the services actually '
        'selected are present; an unselected service has no folder here '
        'at all. `lib/services/` also always holds `bootstrap/`, '
        '`network/`, `routing/`, `storage/`, and `theme/` — the core '
        'project-level services every project gets regardless of which '
        'optional services are selected (see the sections above).');
    buffer.writeln();
    buffer.writeln('**Export.** `lib/services/services.dart` exports '
        '`bootstrap/bootstrap.dart`, `network/network_service.dart`, '
        '`routing/app_router.dart`, `storage/storage_service.dart`, and '
        '`theme/theme_service.dart` unconditionally, then only the '
        'selected optional services, in the same deterministic order '
        'shown above:');
    buffer.writeln();
    buffer.writeln('```dart');
    for (final service in config.orderedServices) {
      buffer.writeln("export '${service.folderName}/${service.fileName}';");
    }
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('**Bootstrap ownership.** Every selected service that has '
        'a meaningful `initialize()` (`ServiceDefinition.hasInitialize` — '
        'Debug Logger and Device Info are purely synchronous/stateless '
        'and have none) is initialized exactly once, from `Bootstrap.'
        'initialize()`, after Storage and Theme — never from `main.dart`, '
        'a feature, a page, a router, a repository, or a data source '
        'directly. This keeps initialization in one place and in one '
        'deterministic order, regardless of the order services were '
        'selected in.');
    buffer.writeln();
    buffer.writeln('**Provider-neutral.** Each service has real, genuinely '
        'useful baseline behavior for its own responsibility with no real '
        'third-party SDK wired in — no concrete provider (Firebase, '
        'Sentry, OneSignal, ...) is connected out of the box. Connect a '
        'real provider by editing the service\'s own implementation; '
        'nothing elsewhere needs to change, since every caller already '
        'depends only on `lib/services/services.dart` and `Bootstrap.'
        'initialize()`.');
    buffer.writeln();
    buffer.writeln('**Adding or removing a service.** Follow the same '
        'folder/export/Bootstrap-initialization convention described '
        'above — add a new folder under `lib/services/` the same way an '
        'existing one is structured, or delete an existing folder along '
        'with its export line and (if present) its `Bootstrap.'
        'initialize()` call.');
    buffer.writeln();
  }

  String _writeDevelopmentDoc(ProjectConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('# Development');
    buffer.writeln();
    buffer.writeln('[← Back to README](../README.md)');
    buffer.writeln();
    _writeConstants(buffer);
    _writeAssets(buffer, config);
    _writeDebugTools(buffer, config);
    _writeExportImportConventions(buffer, config);
    _writeResponsiveUiGuidelines(buffer, config);
    _writeAddingAFeature(buffer, config);
    _writeDevelopmentGuidelines(buffer);
    _writeAccessibility(buffer);
    return buffer.toString();
  }

  void _writeConstants(StringBuffer buffer) {
    buffer.writeln('## Constants');
    buffer.writeln();
    buffer.writeln('`lib/core/constants/` centralizes project-wide constants, '
        're-exported through one barrel file:');
    buffer.writeln();
    buffer.writeln('```text');
    buffer.writeln('lib/core/constants/');
    buffer.writeln(
        '├── app_constants.dart      # App name, Debug tap-unlock threshold');
    buffer.writeln('├── api_constants.dart      # Per-environment base URLs');
    buffer.writeln(
        '├── asset_constants.dart    # Standard asset folder paths (see Assets below)');
    buffer.writeln(
        '├── storage_constants.dart  # Storage keys (environment, theme)');
    buffer.writeln('├── app_colors.dart         # Theme seed colors');
    buffer.writeln('├── app_dimensions.dart     # Shared layout dimensions');
    buffer.writeln(
        '└── constants.dart          # Barrel re-exporting all of the above');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln(
        'When you need a reusable constant — a new API path, a spacing '
        'value, a storage key — add it to the namespace it belongs to '
        'above (or a new one, following the same pattern) instead of '
        'hardcoding a literal in feature code.');
    buffer.writeln();
  }

  void _writeAssets(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Assets');
    buffer.writeln();
    buffer.writeln('Every generated project has a fixed set of asset folders, '
        'declared in `pubspec.yaml` and exposed through `AssetConstants` '
        '(see Constants above):');
    buffer.writeln();
    buffer.writeln('```text');
    buffer.writeln('assets/images/');
    buffer.writeln('assets/fonts/');
    buffer.writeln('assets/icons/');
    buffer.writeln('assets/animations/');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln(
        'These folders start empty — that is a real project convention, '
        'not unfinished scaffolding. `pubspec.yaml` declares each folder '
        '(not individual files), so dropping a file directly into the '
        'matching folder makes it available immediately, with no further '
        '`pubspec.yaml` edit required.');
    buffer.writeln();
    buffer
        .writeln('`AssetConstants` (`lib/core/constants/asset_constants.dart`) '
            'exposes each folder\'s path as a constant — `imagesPath`, '
            '`fontsPath`, `iconsPath`, `animationsPath` — reference these '
            'instead of hardcoding the path string in feature code.');
    buffer.writeln();
    _writeFontConfiguration(buffer, config.fonts);
  }

  void _writeFontConfiguration(StringBuffer buffer, FontConfig fonts) {
    switch (fonts.type) {
      case FontType.none:
        return;
      case FontType.custom:
        final custom = fonts.custom!;
        buffer.writeln('**Font**: this project uses the custom font family '
            '`${custom.family}`, applied via `AppTheme` (`lib/services/'
            'theme/app_theme.dart`). Its font file(s) are declared under '
            '`assets/fonts/` in `pubspec.yaml`:');
        buffer.writeln();
        for (final file in custom.files) {
          buffer.writeln('- `assets/fonts/${file.assetFileName}`');
        }
        buffer.writeln();
      case FontType.google:
        final google = fonts.google!;
        buffer.writeln('**Font**: this project uses the Google Font '
            '`${google.family}`, applied via `AppTheme` (`lib/services/'
            'theme/app_theme.dart`) using the `google_fonts` package — no '
            'static asset registration is needed for it.');
        buffer.writeln();
    }
  }

  void _writeDebugTools(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Debug Tools');
    buffer.writeln();
    buffer.writeln('Debug (`lib/features/debug/`) is a real feature — an '
        'architecture-specific View plus a public export barrel, exactly '
        'like any other feature — but it is a framework-level capability, '
        'never an ordinary feature: it cannot be removed. Its draft '
        'Environment/Theme selection carries no globally-shared instance '
        'of its own — it is built per this project\'s configured '
        '${_stateManagementLabel(config.stateManagement)} state '
        'management, the same construct shape and folder placement a '
        'regular feature\'s own state would use.');
    buffer.writeln();
    buffer
        .writeln('Access is unlocked by tapping the version label on the Home '
            'screen `AppConstants.debugTapCount` times — trivial, page-local '
            'UI state living directly on Home\'s own `State`, gated on '
            'Flutter\'s own `kDebugMode` so a release build can never unlock '
            'it; reaching the threshold navigates to the Debug screen.');
    buffer.writeln();
    final debugPagePath = switch (config.architecture) {
      Architecture.cleanArchitecture =>
        'features/debug/presentation/pages/debug_page.dart',
      Architecture.mvvm =>
        'features/debug/views/debug_page.dart (+ viewmodels/debug_view_model.dart)',
      Architecture.mvp =>
        'features/debug/views/debug_page.dart (+ presenters/debug_presenter.dart)',
    };
    buffer.writeln('The Debug screen is architecture-aware — for this project '
        '(${_architectureLabel(config.architecture)}) it lives at '
        '`lib/$debugPagePath`, following the same conventions as any '
        'other screen. Its content is centered and capped at '
        '`AppDimensions.maxContentWidth` (see Constants above and '
        'Responsive UI Guidelines below) — responsive-safe on a wide '
        'window with no effect on a narrow one.');
    buffer.writeln();
    buffer.writeln('The Debug screen currently provides:');
    buffer.writeln();
    buffer.writeln(
        '- **Environment** selection (see [Services](../docs/services.md)) '
        '— a draft choice, applied or discarded explicitly;');
    buffer
        .writeln('- **Theme** selection (system/light/dark) — a draft choice, '
            'applied or discarded explicitly;');
    buffer.writeln('- **Send Test Notification** — a local scaffold '
        '(`PushTestService`) that simulates a delayed action; it is '
        'independent of the Environment/Theme draft and does not '
        'require Apply. No real push provider is integrated.');
    buffer.writeln();
    buffer
        .writeln('Environment/Theme changes are drafted, then either **Apply** '
            '(persists both and switches them live) or **Cancel** '
            '(discards the draft, nothing persisted). Do not treat this as '
            'a place for feature-specific settings — it is a framework-'
            'level tool.');
    buffer.writeln();
  }

  void _writeExportImportConventions(
      StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Export and Import Conventions');
    buffer.writeln();
    buffer.writeln('Every feature exposes exactly one public entry point — '
        '`<feature>.dart` (see [Architecture](../docs/architecture.md)) — '
        'exporting only its Model/Entity and Page, never internal '
        'wiring. Other features, `main.dart`, and `AppRouter` import a '
        'feature through this file, never its internal files directly.');
    buffer.writeln();
    buffer.writeln('- Import a feature as '
        '`package:${config.projectName}/features/<feature>/<feature>.dart` '
        '— never reach into its internal folders from outside the '
        'feature itself.');
    buffer.writeln('- `lib/core/` (constants, environment) and `lib/services/` '
        '(bootstrap, routing, network, storage, theme, and every '
        'selected optional service) have no single barrel of their own '
        'beyond `services/services.dart` (see [Services]'
        '(../docs/services.md)) — this project-wide infrastructure is '
        'imported directly by its own file path.');
    buffer
        .writeln('- Keep this boundary inside a feature too, where practical: '
            'prefer depending on the feature\'s own public surface over '
            'reaching past it out of convenience.');
    buffer.writeln();
  }

  void _writeResponsiveUiGuidelines(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Responsive UI Guidelines');
    buffer.writeln();
    buffer
        .writeln('This is guidance, not a generated framework — no responsive '
            'layout package or breakpoint system is included.');
    buffer.writeln();
    final touchTargets =
        config.appTargets.intersection({AppTarget.android, AppTarget.ios});
    final pointerTargets = config.appTargets.intersection({
      AppTarget.web,
      AppTarget.windows,
      AppTarget.macos,
      AppTarget.linux,
    });

    if (touchTargets.isNotEmpty && pointerTargets.isNotEmpty) {
      buffer.writeln('This project targets more than one form factor (see '
          '[Architecture](../docs/architecture.md)) — build each page to '
          'adapt at runtime rather than assuming one:');
      buffer.writeln();
      buffer.writeln('- Use `LayoutBuilder`/`MediaQuery` at the page level to '
          'choose between a mobile-style (single-column, touch) and '
          'desktop-style (wider, resizable, pointer) layout.');
      buffer.writeln(
          '- Avoid hardcoding either a phone-narrow or a fixed desktop '
          'width — the same page must work across every configured '
          'target.');
    } else if (touchTargets.isNotEmpty) {
      buffer.writeln(
          'This project targets only touch/mobile-style platforms (see '
          '[Architecture](../docs/architecture.md)): design for a '
          'single-column, portrait-first layout, a narrow width, and '
          "touch input. A desktop-style multi-pane layout is not this "
          "project's target.");
    } else {
      buffer
          .writeln('This project targets only pointer/desktop-style platforms '
              '(see [Architecture](../docs/architecture.md)): design for a '
              'wider, resizable window and pointer input. Avoid assuming a '
              'fixed width, and avoid a phone-style single-column layout — '
              "it is not this project's target.");
    }
    buffer.writeln();
    buffer.writeln(
        'The Debug screen (see Debug Tools above) already follows this '
        'pattern: its content is wrapped in `Center`/`ConstrainedBox` '
        'capped at `AppDimensions.maxContentWidth` (see Constants above), '
        "so it stays a comfortable reading width on a wide window instead "
        'of stretching edge-to-edge, with no effect on a narrow one. '
        'Reuse `AppDimensions.maxContentWidth` the same way in your own '
        'pages rather than inventing a new width constant per feature.');
    buffer.writeln();
    buffer.writeln(
        'Add a real responsive layout package or breakpoint system only '
        "when a feature's actual UI needs it — none is included today.");
    buffer.writeln();
  }

  void _writeAddingAFeature(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Adding a Feature');
    buffer.writeln();
    buffer.writeln('A new feature under `lib/features/<name>/` should follow '
        'the same shape as this project\'s existing features (see '
        '[Feature Structure](../docs/architecture.md)):');
    buffer.writeln();
    buffer.writeln('- **Feature naming**: must start with a letter and '
        'contain only lowercase letters, numbers, and underscores.');
    buffer.writeln('- **Public export barrel**: every feature exposes a '
        'public `<feature>.dart` (see Export and Import Conventions '
        'above) exporting only its entity/model and page.');
    buffer.writeln('- **Architecture-specific structure**: lay out the '
        'feature\'s internal files following this project\'s architecture '
        '(${_architectureLabel(config.architecture)}, see [Architecture]'
        '(../docs/architecture.md)) — the same shape every other feature '
        'already uses.');
    buffer
        .writeln('- **Routing**: a feature with a page should be registered in '
            '`AppRouter` at `/<feature>` (see [Services](../docs/services.md)) '
            '— a feature with nothing to navigate to needs no route.');
    buffer.writeln('- **Tests**: add a widget test for the page under '
        '`test/features/<feature>/`, following [Testing]'
        '(../docs/testing.md)\'s existing layout.');
    buffer.writeln();
    buffer.writeln('Removing a feature means deleting its files under '
        '`lib/features/<name>/` and `test/features/<name>/`, and '
        'removing its route from `AppRouter`, keeping routing '
        'synchronized with the actual feature set. The configured Home '
        'feature (`${config.homeFeatureName}`) and the Debug feature are '
        'framework-level concepts, not ordinary features — do not remove '
        'or restructure them the same way.');
    buffer.writeln();
  }

  void _writeDevelopmentGuidelines(StringBuffer buffer) {
    buffer.writeln('## Development Guidelines');
    buffer.writeln();
    buffer.writeln('- Follow the project\'s architecture (see [Architecture]'
        '(../docs/architecture.md)) — keep its layers\' boundaries clean '
        'rather than reaching across them.');
    buffer.writeln('- Put reusable constants in the appropriate '
        '`lib/core/constants/` namespace (see Constants above) instead '
        'of scattering literals.');
    buffer.writeln('- Never hardcode an environment URL in network code — '
        'always resolve it through `EnvironmentManager` (see [Services]'
        '(../docs/services.md)).');
    buffer.writeln('- Use `Bootstrap.initialize()` (see [Services]'
        '(../docs/services.md)) for application-level startup logic, not '
        '`main()` directly.');
    buffer.writeln('- Use `AppRouter` (see [Services](../docs/services.md)) '
        'for navigation — do not construct routes ad hoc.');
    buffer.writeln('- Keep a feature\'s internals behind its export '
        'barrel (see Export and Import Conventions above) where '
        'practical — depend on `<feature>.dart`, not internal files.');
    buffer.writeln('- Add tests (see [Testing](../docs/testing.md)) '
        'alongside new functionality.');
    buffer.writeln('- Avoid adding dependencies unless they are '
        'genuinely needed.');
    buffer.writeln("- Don't casually change the project's architecture "
        'conventions (folder layout, naming) — consistency across '
        'features matters more than a local preference.');
    buffer.writeln('- Initialize a new service only from `Bootstrap.'
        'initialize()` (see Bootstrap and Production Services in '
        '[Services](../docs/services.md)), never directly from a '
        'feature, page, router, repository, or data source.');
    buffer.writeln();
  }

  void _writeAccessibility(StringBuffer buffer) {
    buffer.writeln('## Accessibility');
    buffer.writeln();
    buffer.writeln('This project provides a reusable semantics wrapper '
        'primitive and preserves the system\'s own accessibility '
        'behavior — it does not audit, enforce, or certify the '
        'accessibility of any feature you build.');
    buffer.writeln();
    buffer.writeln('**What this project provides.** `AccessibleWidget` '
        '(`lib/shared/ui/accessible.dart`) wraps Flutter\'s own '
        '`Semantics` widget with the minimum useful surface — a '
        'screen-reader `label`, an optional `hint`, and whether the '
        'child should be announced as a `button`:');
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln('AccessibleWidget(');
    buffer.writeln("  label: 'Submit form',");
    buffer.writeln('  button: true,');
    buffer.writeln('  child: IconButton(icon: const Icon(Icons.check), '
        'onPressed: onSubmit),');
    buffer.writeln(')');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('It is present unconditionally, alongside every other '
        'Shared UI primitive (`AppAlert`, `LoadingIndicator`, '
        '`MaintenanceView`, `EmptyStateView`, `ErrorStateView`) and '
        'exported from `lib/shared/ui/shared_ui.dart` — the same way for '
        'every architecture and state management choice.');
    buffer.writeln();
    buffer.writeln('**Text scaling and system settings.** The generated '
        '`MaterialApp` (see [Architecture](../docs/architecture.md) and '
        '[Services](../docs/services.md)) never overrides `MediaQuery` '
        'text scaling, contrast, bold text, or reduced-motion settings — '
        'the device\'s own accessibility settings apply exactly as '
        'Flutter\'s defaults already provide. This project does not, and '
        'cannot, control a user\'s screen reader, system font scale, or '
        'other OS-level accessibility settings from application code, '
        'and does not attempt to.');
    buffer.writeln();
    buffer.writeln('**What remains your responsibility.** Wrapping a '
        'widget in `AccessibleWidget` — or using `Semantics` directly — '
        'is something you do deliberately, per widget, where it adds '
        'real value (an icon-only button, a custom control with no '
        'visible text). Adding a feature (see Adding a Feature above) '
        'does not automatically make its UI accessible, infer labels '
        'from context, or apply semantics on your behalf.');
    buffer.writeln();
    buffer.writeln('**Testing.** Verify real semantics behavior with '
        'Flutter\'s own testing APIs — the same pattern the generated '
        '`test/shared/ui/shared_ui_test.dart` already uses for '
        '`AccessibleWidget` itself:');
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln("testWidgets('Submit button has a semantics label', "
        '(tester) async {');
    buffer.writeln('  final handle = tester.ensureSemantics();');
    buffer.writeln('  await tester.pumpWidget(const MaterialApp(home: '
        'MyWidget()));');
    buffer.writeln();
    buffer.writeln(
        "  expect(find.bySemanticsLabel('Submit form'), findsOneWidget);");
    buffer.writeln('  handle.dispose();');
    buffer.writeln('});');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('Apply the same pattern to your own widgets\' tests '
        'under `test/features/<feature>/` (see [Testing]'
        '(../docs/testing.md)) as you add semantics to them.');
    buffer.writeln();
  }

  String _writeTestingDoc(ProjectConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('# Testing');
    buffer.writeln();
    buffer.writeln('[← Back to README](../README.md)');
    buffer.writeln();
    _writeTesting(buffer, config);
    _writeApiDependentTests(buffer);
    _writeCoverage(buffer);
    return buffer.toString();
  }

  void _writeTesting(StringBuffer buffer, ProjectConfig config) {
    buffer.writeln('## Test Layout');
    buffer.writeln();
    buffer.writeln('```text');
    buffer.writeln('test/');
    buffer.writeln('├── core/       # Constants + Environment unit tests');
    buffer.writeln(
        '├── services/   # Bootstrap, routing, network, storage, theme,');
    buffer.writeln('│               # and every selected optional service');
    buffer
        .writeln('└── features/   # Per-feature tests, including Debug\'s own');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('`test/core/` covers only `AppConstants`/`ApiConstants`/'
        '`AssetConstants`/`StorageConstants`/`AppColors`/`AppDimensions` '
        'and `EnvironmentManager` — the two pieces that remain genuinely '
        '`core/` concerns.');
    buffer.writeln();
    buffer.writeln('`test/services/` covers every project-level service '
        'described in [Services](../docs/services.md): `Bootstrap`, '
        '`AppRouter`, `NetworkService`, `StorageService`, `ThemeService`, '
        'and one `<name>_test.dart` per selected optional service.');
    buffer.writeln();
    buffer.writeln('`test/features/<feature>/` holds each feature\'s tests, '
        'including the Debug feature\'s own (`test/features/debug/`). A '
        'feature with a page gets a widget test asserting it builds '
        'without error — `<feature>_page_test.dart`. '
        '`${config.homeFeatureName}` (Home) always gets one.');
    buffer.writeln();
    buffer
        .writeln('When you add real logic to a feature, add tests alongside it '
            'under `test/features/<feature>/`, following the same '
            'structure. This project generates unit and widget tests only '
            '— add an integration-test setup yourself if a feature needs '
            'one.');
    buffer.writeln();
  }

  void _writeApiDependentTests(StringBuffer buffer) {
    buffer.writeln('## API-Dependent Tests');
    buffer.writeln();
    buffer.writeln('A test that exercises a feature\'s network data source '
        'should not depend on a real backend being reachable. This '
        'project\'s API-dependent tests use a local WireMock instance to '
        'give the request a deterministic, mocked HTTP response instead '
        '— the request still goes through `NetworkService` exactly as it '
        'would in production, only the far end is a local mock.');
    buffer.writeln();
    buffer.writeln(
        'WireMock\'s lifecycle (starting and stopping the local instance) '
        'is handled by this project\'s own test tooling and scripts — you '
        'do not start or stop it by hand. Once this project has '
        'API-dependent tests that use it, see `scripts/wiremock/'
        'README.md` (created alongside the scripts themselves) for setup '
        '— it covers obtaining a WireMock standalone JAR and the '
        '`WIREMOCK_PORT`/`WIREMOCK_JAR` environment variables the scripts '
        'read. No WireMock dependency is added to this project itself; '
        'the JAR is a devtime/test-time tool only, supplied by you or CI, '
        'never bundled.');
    buffer.writeln();
  }

  void _writeCoverage(StringBuffer buffer) {
    buffer.writeln('## Coverage');
    buffer.writeln();
    buffer.writeln('Run `flutter test --coverage` to produce a real, '
        'per-file line coverage report at `coverage/lcov.info`, using '
        'Flutter\'s own coverage tooling — no separate coverage package '
        'is added. Render it as a browsable HTML report with a tool such '
        'as `genhtml` (from the `lcov` package) if you want to browse it '
        'visually:');
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln('flutter test --coverage');
    buffer.writeln('genhtml coverage/lcov.info -o coverage/html');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('`coverage/` is working output, not source — it should '
        'not be committed.');
    buffer.writeln();
  }

  String _architectureLabel(Architecture architecture) {
    return switch (architecture) {
      Architecture.cleanArchitecture => 'Clean Architecture',
      Architecture.mvvm => 'MVVM',
      Architecture.mvp => 'MVP',
    };
  }

  String _stateManagementLabel(StateManagement stateManagement) {
    return switch (stateManagement) {
      StateManagement.bloc => 'BLoC',
      StateManagement.cubit => 'Cubit',
      StateManagement.getx => 'GetX',
      StateManagement.riverpod => 'Riverpod',
    };
  }

  String _networkLabel(Network network) {
    return switch (network) {
      Network.http => 'Http (package:http)',
      Network.dio => 'Dio (package:dio)',
      Network.other => 'a custom/other implementation',
    };
  }

  String _storageLabel(Storage storage) {
    return switch (storage) {
      Storage.sharedPreferences => 'SharedPreferences',
      Storage.hive => 'Hive',
      Storage.other => 'a custom/other implementation',
    };
  }

  String _pascal(String name) => NamingConventions.toPascalCase(name);
}
