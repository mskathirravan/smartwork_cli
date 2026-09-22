import '../../models/project_config.dart';
import '../template.dart';
import '../testing/storage_test_setup.dart';

class DebugTemplates {
  static Template debugBarrelTemplate(Architecture architecture) {
    final pagePath = switch (architecture) {
      Architecture.cleanArchitecture => 'presentation/pages/debug_page.dart',
      Architecture.mvvm || Architecture.mvp => 'views/debug_page.dart',
    };
    return Template(content: '''export '$pagePath';
''');
  }

  static Template pushTestServiceTemplate() {
    return Template(content: '''class PushTestService {
  const PushTestService();

  /// Simulates sending a test push notification after [delay]. This is
  /// a local scaffold only — no real push provider is integrated yet.
  Future<void> sendTest({required Duration delay}) async {
    await Future<void>.delayed(delay);
    // TODO: integrate a real push provider here in a future milestone.
  }
}
''');
  }

  static Template debugStateTemplate({required String toCoreDir}) {
    return Template(content: '''import 'package:flutter/material.dart';

import '$toCoreDir/environment/environment.dart';

class DebugState {
  final Environment draftEnvironment;
  final ThemeMode draftThemeMode;

  const DebugState({
    required this.draftEnvironment,
    required this.draftThemeMode,
  });

  DebugState copyWith({
    Environment? draftEnvironment,
    ThemeMode? draftThemeMode,
  }) {
    return DebugState(
      draftEnvironment: draftEnvironment ?? this.draftEnvironment,
      draftThemeMode: draftThemeMode ?? this.draftThemeMode,
    );
  }
}
''');
  }

  static Template debugEventTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../../../core/environment/environment.dart';

abstract class DebugEvent {
  const DebugEvent();
}

class DebugEnvironmentChanged extends DebugEvent {
  final Environment environment;

  const DebugEnvironmentChanged(this.environment);
}

class DebugThemeChanged extends DebugEvent {
  final ThemeMode mode;

  const DebugThemeChanged(this.mode);
}
''');
  }

  static Template debugBlocTemplate() {
    return Template(content: '''import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/environment/environment_manager.dart';
import '../../../services/theme/theme_service.dart';
import 'debug_event.dart';
import 'debug_state.dart';

class DebugBloc extends Bloc<DebugEvent, DebugState> {
  DebugBloc()
    : super(
        DebugState(
          draftEnvironment: EnvironmentManager.instance.currentEnvironment,
          draftThemeMode: ThemeService.instance.currentThemeMode,
        ),
      ) {
    on<DebugEnvironmentChanged>(
      (event, emit) =>
          emit(state.copyWith(draftEnvironment: event.environment)),
    );
    on<DebugThemeChanged>(
      (event, emit) => emit(state.copyWith(draftThemeMode: event.mode)),
    );
  }

  /// Discards the draft, reverting it to the currently active
  /// (already-persisted) values. Nothing is persisted by cancelling.
  ///
  /// Bypasses the usual add()/on&lt;Event&gt;() event flow on purpose:
  /// Cancel must revert the draft synchronously, before the page pops,
  /// which add() (processed on a later microtask) cannot guarantee.
  void cancel() {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(
      DebugState(
        draftEnvironment: EnvironmentManager.instance.currentEnvironment,
        draftThemeMode: ThemeService.instance.currentThemeMode,
      ),
    );
  }

  /// Persists the draft and switches the active environment/theme to
  /// match. After this, the app uses the newly selected values
  /// immediately — no restart required.
  Future<void> apply() async {
    await EnvironmentManager.instance.setEnvironment(state.draftEnvironment);
    await ThemeService.instance.setTheme(state.draftThemeMode);
  }
}
''');
  }

  static Template debugCubitTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/environment/environment.dart';
import '../../../core/environment/environment_manager.dart';
import '../../../services/theme/theme_service.dart';
import 'debug_state.dart';

class DebugCubit extends Cubit<DebugState> {
  DebugCubit()
    : super(
        DebugState(
          draftEnvironment: EnvironmentManager.instance.currentEnvironment,
          draftThemeMode: ThemeService.instance.currentThemeMode,
        ),
      );

  void changeEnvironment(Environment environment) {
    emit(state.copyWith(draftEnvironment: environment));
  }

  void changeTheme(ThemeMode mode) {
    emit(state.copyWith(draftThemeMode: mode));
  }

  /// Discards the draft, reverting it to the currently active
  /// (already-persisted) values. Nothing is persisted by cancelling.
  void cancel() {
    emit(
      DebugState(
        draftEnvironment: EnvironmentManager.instance.currentEnvironment,
        draftThemeMode: ThemeService.instance.currentThemeMode,
      ),
    );
  }

  /// Persists the draft and switches the active environment/theme to
  /// match. After this, the app uses the newly selected values
  /// immediately — no restart required.
  Future<void> apply() async {
    await EnvironmentManager.instance.setEnvironment(state.draftEnvironment);
    await ThemeService.instance.setTheme(state.draftThemeMode);
  }
}
''');
  }

  static Template debugGetxControllerTemplate() {
    return Template(
        content: _getxControllerBody(
      toCoreDir: '../../../../core',
      toServicesDir: '../../../../services',
    ));
  }

  static String _getxControllerBody({
    required String toCoreDir,
    required String toServicesDir,
    String className = 'DebugController',
  }) {
    return '''import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '$toCoreDir/environment/environment.dart';
import '$toCoreDir/environment/environment_manager.dart';
import '$toServicesDir/theme/theme_service.dart';

class $className extends GetxController {
  final draftEnvironment = EnvironmentManager.instance.currentEnvironment.obs;
  final draftThemeMode = ThemeService.instance.currentThemeMode.obs;

  void changeEnvironment(Environment environment) {
    draftEnvironment.value = environment;
  }

  void changeTheme(ThemeMode mode) {
    draftThemeMode.value = mode;
  }

  /// Discards the draft, reverting it to the currently active
  /// (already-persisted) values. Nothing is persisted by cancelling.
  void cancel() {
    draftEnvironment.value = EnvironmentManager.instance.currentEnvironment;
    draftThemeMode.value = ThemeService.instance.currentThemeMode;
  }

  /// Persists the draft and switches the active environment/theme to
  /// match. After this, the app uses the newly selected values
  /// immediately — no restart required.
  Future<void> apply() async {
    await EnvironmentManager.instance.setEnvironment(draftEnvironment.value);
    await ThemeService.instance.setTheme(draftThemeMode.value);
  }
}
''';
  }

  static Template debugRiverpodProviderTemplateClean() {
    return Template(
      content: _riverpodProviderBody(
        toCoreDir: '../../../../core',
        toServicesDir: '../../../../services',
      ),
    );
  }

  static Template debugRiverpodProviderTemplateMvvm() {
    return Template(
      content: _riverpodProviderBody(
        toCoreDir: '../../../core',
        toServicesDir: '../../../services',
        viewModelImport: "import '../viewmodels/debug_view_model.dart';",
        viewModelClassName: 'DebugViewModel',
      ),
    );
  }

  static Template debugRiverpodProviderTemplateMvp() {
    return Template(
      content: _riverpodProviderBody(
        toCoreDir: '../../../core',
        toServicesDir: '../../../services',
        viewModelImport: "import '../presenters/debug_presenter.dart';",
        viewModelClassName: 'DebugPresenter',
      ),
    );
  }

  static String _riverpodProviderBody({
    required String toCoreDir,
    required String toServicesDir,
    String? viewModelImport,
    String? viewModelClassName,
  }) {
    final wrapperProvider = viewModelClassName == null
        ? ''
        : '''final debugViewModelProvider = Provider<$viewModelClassName>((ref) {
  return $viewModelClassName();
});

''';
    final riverpodMainImport = viewModelClassName == null
        ? "import 'package:riverpod/legacy.dart';"
        : '''import 'package:riverpod/riverpod.dart';
import 'package:riverpod/legacy.dart';''';
    return '''import 'package:flutter/material.dart';
$riverpodMainImport

import '$toCoreDir/environment/environment.dart';
import '$toCoreDir/environment/environment_manager.dart';
import '$toServicesDir/theme/theme_service.dart';
${viewModelImport == null ? '' : '$viewModelImport\n'}import 'debug_state.dart';

${wrapperProvider}class DebugNotifier extends StateNotifier<DebugState> {
  DebugNotifier()
    : super(
        DebugState(
          draftEnvironment: EnvironmentManager.instance.currentEnvironment,
          draftThemeMode: ThemeService.instance.currentThemeMode,
        ),
      );

  /// `state` itself is `@protected`/`@visibleForTesting` on
  /// `StateNotifier` — readable from within this subclass and from
  /// tests, but not from the page that consumes this notifier. This is
  /// that external read (`StateNotifier` has its own `debugState`, but
  /// it's `@Deprecated`, assert-gated, and stripped in release builds —
  /// not something production widget code can use).
  DebugState get currentState => state;

  void changeEnvironment(Environment environment) {
    state = state.copyWith(draftEnvironment: environment);
  }

  void changeTheme(ThemeMode mode) {
    state = state.copyWith(draftThemeMode: mode);
  }

  /// Discards the draft, reverting it to the currently active
  /// (already-persisted) values. Nothing is persisted by cancelling.
  void cancel() {
    state = DebugState(
      draftEnvironment: EnvironmentManager.instance.currentEnvironment,
      draftThemeMode: ThemeService.instance.currentThemeMode,
    );
  }

  /// Persists the draft and switches the active environment/theme to
  /// match. After this, the app uses the newly selected values
  /// immediately — no restart required.
  Future<void> apply() async {
    await EnvironmentManager.instance.setEnvironment(state.draftEnvironment);
    await ThemeService.instance.setTheme(state.draftThemeMode);
  }
}

final debugProvider = StateNotifierProvider<DebugNotifier, DebugState>((ref) {
  return DebugNotifier();
});
''';
  }

  static Template debugViewModelTemplateMvvm(StateManagement stateManagement) {
    return Template(
      content: _stateHolderClassBody(
        className: 'DebugViewModel',
        stateManagement: stateManagement,
        toCoreDir: '../../../core',
        toServicesDir: '../../../services',
      ),
    );
  }

  static Template debugPresenterTemplateMvp(StateManagement stateManagement) {
    return Template(
      content: _stateHolderClassBody(
        className: 'DebugPresenter',
        stateManagement: stateManagement,
        toCoreDir: '../../../core',
        toServicesDir: '../../../services',
      ),
    );
  }

  static String _stateHolderClassBody({
    required String className,
    required StateManagement stateManagement,
    required String toCoreDir,
    required String toServicesDir,
  }) {
    return switch (stateManagement) {
      StateManagement.bloc => '''import '../state/debug_bloc.dart';

class $className {
  final DebugBloc bloc = DebugBloc();
}
''',
      StateManagement.cubit => '''import '../state/debug_cubit.dart';

class $className {
  final DebugCubit cubit = DebugCubit();
}
''',
      StateManagement.getx => _getxControllerBody(
          toCoreDir: toCoreDir,
          toServicesDir: toServicesDir,
          className: className,
        ),
      StateManagement.riverpod => '''class $className {
  bool isLoading = false;
}
''',
    };
  }

  static Template debugPageTemplateClean(StateManagement stateManagement) {
    return Template(
      content: _debugScreenSource(
        stateManagement: stateManagement,
        toDebugDir: '../..',
        toCoreDir: '../../../../core',
        holderField: null,
      ),
    );
  }

  static Template debugViewTemplateMvvm(StateManagement stateManagement) {
    return Template(
      content: _debugScreenSource(
        stateManagement: stateManagement,
        toDebugDir: '..',
        toCoreDir: '../../../core',
        holderField: (
          type: 'DebugViewModel',
          field: '_viewModel',
          import: "import '../viewmodels/debug_view_model.dart';",
        ),
      ),
    );
  }

  static Template debugViewTemplateMvp(StateManagement stateManagement) {
    return Template(
      content: _debugScreenSource(
        stateManagement: stateManagement,
        toDebugDir: '..',
        toCoreDir: '../../../core',
        holderField: (
          type: 'DebugPresenter',
          field: '_presenter',
          import: "import '../presenters/debug_presenter.dart';",
        ),
      ),
    );
  }

  static String _debugScreenSource({
    required StateManagement stateManagement,
    required String toDebugDir,
    required String toCoreDir,
    required ({String type, String field, String import})? holderField,
  }) {
    String holder(String memberName) => holderField == null
        ? '_$memberName'
        : '${holderField.field}.$memberName';

    final extraFieldDeclaration = holderField == null
        ? _ownedFieldDeclaration(stateManagement)
        : '  final ${holderField.type} ${holderField.field} = '
            '${holderField.type}();\n';
    final extraImport = holderField?.import ?? '';

    return switch (stateManagement) {
      StateManagement.bloc => _debugScreenBlocOrCubit(
          isCubit: false,
          toDebugDir: toDebugDir,
          toCoreDir: toCoreDir,
          extraFieldDeclaration: extraFieldDeclaration,
          extraImport: extraImport,
          blocOrCubitExpr: holder('bloc'),
        ),
      StateManagement.cubit => _debugScreenBlocOrCubit(
          isCubit: true,
          toDebugDir: toDebugDir,
          toCoreDir: toCoreDir,
          extraFieldDeclaration: extraFieldDeclaration,
          extraImport: extraImport,
          blocOrCubitExpr: holder('cubit'),
        ),
      StateManagement.getx => _debugScreenGetx(
          toDebugDir: toDebugDir,
          toCoreDir: toCoreDir,
          extraFieldDeclaration: extraFieldDeclaration,
          extraImport: holderField == null
              ? "import '../getx/debug_controller.dart';"
              : extraImport,
          controllerExpr:
              holderField == null ? '_controller' : holderField.field,
        ),
      StateManagement.riverpod => _debugScreenRiverpod(
          toDebugDir: toDebugDir,
          toCoreDir: toCoreDir,
        ),
    };
  }

  static String _ownedFieldDeclaration(StateManagement stateManagement) {
    return switch (stateManagement) {
      StateManagement.bloc => '  final DebugBloc _bloc = DebugBloc();\n',
      StateManagement.cubit => '  final DebugCubit _cubit = DebugCubit();\n',
      StateManagement.getx =>
        '  final DebugController _controller = DebugController();\n',
      StateManagement.riverpod => '',
    };
  }

  static String _debugScreenBlocOrCubit({
    required bool isCubit,
    required String toDebugDir,
    required String toCoreDir,
    required String extraFieldDeclaration,
    required String extraImport,
    required String blocOrCubitExpr,
  }) {
    final typeName = isCubit ? 'DebugCubit' : 'DebugBloc';
    final stateImport = isCubit
        ? "import '$toDebugDir/state/debug_cubit.dart';"
        : '''import '$toDebugDir/state/debug_bloc.dart';
import '$toDebugDir/state/debug_event.dart';''';
    final closeCall = isCubit ? 'close' : 'close';
    final onEnvironmentChanged = isCubit
        ? '$blocOrCubitExpr.changeEnvironment(value);'
        : '$blocOrCubitExpr.add(DebugEnvironmentChanged(value));';
    final onThemeChanged = isCubit
        ? '$blocOrCubitExpr.changeTheme(value);'
        : '$blocOrCubitExpr.add(DebugThemeChanged(value));';

    return '''import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

$stateImport
import '$toDebugDir/state/debug_state.dart';
import '$toDebugDir/push_test_service.dart';
import '$toCoreDir/constants/constants.dart';
import '$toCoreDir/environment/environment.dart';
${extraImport.isEmpty ? '' : '$extraImport\n'}
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
$extraFieldDeclaration  final PushTestService _pushTestService = const PushTestService();
  final TextEditingController _delayController = TextEditingController(
    text: '5',
  );

  @override
  void dispose() {
    _delayController.dispose();
    $blocOrCubitExpr.$closeCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: BlocBuilder<$typeName, DebugState>(
        bloc: $blocOrCubitExpr,
        builder: (context, state) {
          return ${_settingsListContent(
      draftEnvironmentExpr: 'state.draftEnvironment',
      draftThemeModeExpr: 'state.draftThemeMode',
      onEnvironmentChanged: onEnvironmentChanged,
      onThemeChanged: onThemeChanged,
      onCancel: '$blocOrCubitExpr.cancel();\n'
          '                            Navigator.of(context).pop();',
      onApply: 'await $blocOrCubitExpr.apply();\n'
          '                            if (context.mounted) '
          'Navigator.of(context).pop();',
    )};
        },
      ),
    );
  }
}
''';
  }

  static String _debugScreenGetx({
    required String toDebugDir,
    required String toCoreDir,
    required String extraFieldDeclaration,
    required String extraImport,
    required String controllerExpr,
  }) {
    return '''import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '$toDebugDir/push_test_service.dart';
import '$toCoreDir/constants/constants.dart';
import '$toCoreDir/environment/environment.dart';
${extraImport.isEmpty ? '' : '$extraImport\n'}
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
$extraFieldDeclaration  final PushTestService _pushTestService = const PushTestService();
  final TextEditingController _delayController = TextEditingController(
    text: '5',
  );

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: Obx(() {
        return ${_settingsListContent(
      draftEnvironmentExpr: '$controllerExpr.draftEnvironment.value',
      draftThemeModeExpr: '$controllerExpr.draftThemeMode.value',
      onEnvironmentChanged: '$controllerExpr.changeEnvironment(value);',
      onThemeChanged: '$controllerExpr.changeTheme(value);',
      onCancel: '$controllerExpr.cancel();\n'
          '                            Navigator.of(context).pop();',
      onApply: 'await $controllerExpr.apply();\n'
          '                            if (context.mounted) '
          'Navigator.of(context).pop();',
      dedent: 2,
    )};
      }),
    );
  }
}
''';
  }

  static String _debugScreenRiverpod({
    required String toDebugDir,
    required String toCoreDir,
  }) {
    return '''import 'package:flutter/material.dart';

import '../providers/debug_provider.dart';
import '$toDebugDir/push_test_service.dart';
import '$toCoreDir/constants/constants.dart';
import '$toCoreDir/environment/environment.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final DebugNotifier _notifier = DebugNotifier();
  final PushTestService _pushTestService = const PushTestService();
  final TextEditingController _delayController = TextEditingController(
    text: '5',
  );
  late final void Function() _removeListener;

  @override
  void initState() {
    super.initState();
    _removeListener = _notifier.addListener(
      (_) => setState(() {}),
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _removeListener();
    _delayController.dispose();
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _notifier.currentState;

    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: ${_settingsListContent(
      draftEnvironmentExpr: 'state.draftEnvironment',
      draftThemeModeExpr: 'state.draftThemeMode',
      onEnvironmentChanged: '_notifier.changeEnvironment(value);',
      onThemeChanged: '_notifier.changeTheme(value);',
      onCancel: '_notifier.cancel();\n'
          '                            Navigator.of(context).pop();',
      onApply: 'await _notifier.apply();\n'
          '                            if (context.mounted) '
          'Navigator.of(context).pop();',
      dedent: 4,
    )},
    );
  }
}
''';
  }

  static String _settingsListContent({
    required String draftEnvironmentExpr,
    required String draftThemeModeExpr,
    required String onEnvironmentChanged,
    required String onThemeChanged,
    required String onCancel,
    required String onApply,
    int dedent = 0,
  }) {
    final raw = _settingsListContentRaw(
      draftEnvironmentExpr: draftEnvironmentExpr,
      draftThemeModeExpr: draftThemeModeExpr,
      onEnvironmentChanged: onEnvironmentChanged,
      onThemeChanged: onThemeChanged,
      onCancel: onCancel,
      onApply: onApply,
      dedent: dedent,
    );
    if (dedent == 0) return raw;
    final prefix = ' ' * dedent;
    return raw
        .split('\n')
        .map((line) => line.startsWith(prefix) ? line.substring(dedent) : line)
        .join('\n');
  }

  static String _settingsListContentRaw({
    required String draftEnvironmentExpr,
    required String draftThemeModeExpr,
    required String onEnvironmentChanged,
    required String onThemeChanged,
    required String onCancel,
    required String onApply,
    required int dedent,
  }) {
    final decorationBlock = 20 - dedent + 64 <= 80
        ? "decoration: const InputDecoration(labelText: 'Delay (seconds)'),"
        : '''decoration: const InputDecoration(
                      labelText: 'Delay (seconds)',
                    ),''';
    final sendTestBlock = 22 - dedent + 61 <= 80
        ? '_pushTestService.sendTest(delay: Duration(seconds: seconds));'
        : '''_pushTestService.sendTest(
                        delay: Duration(seconds: seconds),
                      );''';
    return '''Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                children: [
                  const Text(
                    'Environment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RadioGroup<Environment>(
                    groupValue: $draftEnvironmentExpr,
                    onChanged: (value) {
                      if (value != null) {
                        $onEnvironmentChanged
                      }
                    },
                    child: Column(
                      children: [
                        for (final environment in Environment.values)
                          RadioListTile<Environment>(
                            title: Text(environment.label),
                            value: environment,
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  const Text(
                    'Theme',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: $draftThemeModeExpr,
                    onChanged: (value) {
                      if (value != null) {
                        $onThemeChanged
                      }
                    },
                    child: Column(
                      children: [
                        for (final mode in ThemeMode.values)
                          RadioListTile<ThemeMode>(
                            title: Text(mode.name),
                            value: mode,
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  const Text(
                    'Push Notification Test',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: _delayController,
                    keyboardType: TextInputType.number,
                    $decorationBlock
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final seconds = int.tryParse(_delayController.text) ?? 5;
                      $sendTestBlock
                    },
                    child: const Text('Send Test Notification'),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            $onCancel
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            $onApply
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )''';
  }

  static Template pushTestServiceTestTemplate() {
    return Template(content: '''import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/features/debug/push_test_service.dart';

void main() {
  test(
    'sendTest completes on its own, independent of any Debug settings',
    () async {
      await const PushTestService().sendTest(delay: Duration.zero);
    },
  );
}
''');
  }

  static Template debugBlocTestTemplate(Storage storage) {
    return Template(
      content: _stateConstructTestBody(
        storage: storage,
        constructImport: "import 'package:{{projectName}}/features/debug/"
            "state/debug_bloc.dart';\nimport 'package:{{projectName}}/"
            "features/debug/state/debug_event.dart';",
        constructVar: 'bloc',
        constructExpr: 'DebugBloc()',
        changeEnvironment: (v) => 'bloc.add(DebugEnvironmentChanged($v))',
        changeTheme: (v) => 'bloc.add(DebugThemeChanged($v))',
        mutationIsAsync: true,
      ),
    );
  }

  static Template debugCubitTestTemplate(Storage storage) {
    return Template(
      content: _stateConstructTestBody(
        storage: storage,
        constructImport: "import 'package:{{projectName}}/features/debug/"
            "state/debug_cubit.dart';",
        constructVar: 'cubit',
        constructExpr: 'DebugCubit()',
        changeEnvironment: (v) => 'cubit.changeEnvironment($v)',
        changeTheme: (v) => 'cubit.changeTheme($v)',
      ),
    );
  }

  static Template debugGetxControllerTestTemplate(Storage storage) {
    return Template(
      content: _stateConstructTestBody(
        storage: storage,
        constructImport: "import 'package:{{projectName}}/features/debug/"
            "presentation/getx/debug_controller.dart';",
        constructVar: 'controller',
        constructExpr: 'DebugController()',
        changeEnvironment: (v) => 'controller.changeEnvironment($v)',
        changeTheme: (v) => 'controller.changeTheme($v)',
        readDraftEnvironment: 'controller.draftEnvironment.value',
        readDraftThemeMode: 'controller.draftThemeMode.value',
      ),
    );
  }

  static Template debugRiverpodNotifierTestTemplate(
    Storage storage,
    Architecture architecture,
  ) {
    final providersPath = architecture == Architecture.cleanArchitecture
        ? 'presentation/providers'
        : 'providers';
    return Template(
      content: _stateConstructTestBody(
        storage: storage,
        constructImport: "import 'package:{{projectName}}/features/debug/"
            "$providersPath/debug_provider.dart';",
        constructVar: 'notifier',
        constructExpr: 'DebugNotifier()',
        changeEnvironment: (v) => 'notifier.changeEnvironment($v)',
        changeTheme: (v) => 'notifier.changeTheme($v)',
        readDraftEnvironment: 'notifier.state.draftEnvironment',
        readDraftThemeMode: 'notifier.state.draftThemeMode',
      ),
    );
  }

  static String _expectStatement(String actual, String matcher) {
    final oneLine = 'expect($actual, $matcher);';
    if ('    $oneLine'.length <= 80) return oneLine;
    return 'expect(\n      $actual,\n      $matcher,\n    );';
  }

  static String _stateConstructTestBody({
    required Storage storage,
    required String constructImport,
    required String constructVar,
    required String constructExpr,
    required String Function(String value) changeEnvironment,
    required String Function(String value) changeTheme,
    String? readDraftEnvironment,
    String? readDraftThemeMode,
    bool mutationIsAsync = false,
  }) {
    final draftEnvironment =
        readDraftEnvironment ?? '$constructVar.state.draftEnvironment';
    final draftThemeMode =
        readDraftThemeMode ?? '$constructVar.state.draftThemeMode';
    final asyncKeyword = mutationIsAsync ? 'async ' : '';
    final awaitMutation =
        mutationIsAsync ? '\n    await pumpEventQueue();' : '';
    final seededEnvironmentExpect = _expectStatement(
      draftEnvironment,
      'EnvironmentManager.instance.currentEnvironment',
    );
    final seededThemeExpect = _expectStatement(
      draftThemeMode,
      'ThemeService.instance.currentThemeMode',
    );
    return '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
${StorageTestSetup.imports(storage)}

$constructImport
import 'package:{{projectName}}/core/environment/environment.dart';
import 'package:{{projectName}}/core/environment/environment_manager.dart';
import 'package:{{projectName}}/services/storage/storage_service.dart';
import 'package:{{projectName}}/services/theme/theme_service.dart';

${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

${StorageTestSetup.setUpAndTearDown(storage)}

  tearDown(() async {
    await EnvironmentManager.instance.setEnvironment(Environment.prod);
    await ThemeService.instance.setTheme(ThemeMode.system);
  });

  test('draft starts seeded from the currently active Environment/Theme', () {
    final $constructVar = $constructExpr;

    $seededEnvironmentExpect
    $seededThemeExpect
  });

  test('changing environment/theme mutates only the draft', () $asyncKeyword{
    final $constructVar = $constructExpr;

    ${changeEnvironment('Environment.stage')};
    ${changeTheme('ThemeMode.dark')};$awaitMutation

    expect($draftEnvironment, Environment.stage);
    expect($draftThemeMode, ThemeMode.dark);
    expect(
      EnvironmentManager.instance.currentEnvironment,
      isNot(Environment.stage),
    );
    expect(ThemeService.instance.currentThemeMode, isNot(ThemeMode.dark));
  });

  test('cancel() reverts the draft without persisting anything', () {
    final $constructVar = $constructExpr;
    ${changeEnvironment('Environment.dev')};
    ${changeTheme('ThemeMode.light')};

    $constructVar.cancel();

    expect($draftEnvironment, Environment.prod);
    expect($draftThemeMode, ThemeMode.system);
    expect(EnvironmentManager.instance.currentEnvironment, Environment.prod);
    expect(ThemeService.instance.currentThemeMode, ThemeMode.system);
  });

  test('apply() persists both the draft environment and theme', () async {
    final $constructVar = $constructExpr;
    ${changeEnvironment('Environment.stage')};
    ${changeTheme('ThemeMode.dark')};$awaitMutation

    await $constructVar.apply();

    expect(EnvironmentManager.instance.currentEnvironment, Environment.stage);
    expect(ThemeService.instance.currentThemeMode, ThemeMode.dark);
  });

  test('Environment and Theme apply independently of one another', () async {
    final $constructVar = $constructExpr;
    ${changeEnvironment('Environment.dev')};$awaitMutation

    await $constructVar.apply();

    expect(EnvironmentManager.instance.currentEnvironment, Environment.dev);
    expect(ThemeService.instance.currentThemeMode, ThemeMode.system);
  });
}
''';
  }

  static Template debugPageTestTemplateClean(Storage storage) {
    return Template(
      content: _debugScreenTestBody(
        importPath: 'features/debug/presentation/pages/debug_page.dart',
        storage: storage,
      ),
    );
  }

  static Template debugPageTestTemplateMvvm(Storage storage) {
    return Template(
      content: _debugScreenTestBody(
        importPath: 'features/debug/views/debug_page.dart',
        storage: storage,
      ),
    );
  }

  static Template debugPageTestTemplateMvp(Storage storage) {
    return Template(
      content: _debugScreenTestBody(
        importPath: 'features/debug/views/debug_page.dart',
        storage: storage,
      ),
    );
  }

  static String _debugScreenTestBody({
    required String importPath,
    required Storage storage,
  }) {
    return '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
${StorageTestSetup.imports(storage)}

import 'package:{{projectName}}/$importPath';
import 'package:{{projectName}}/core/environment/environment.dart';
import 'package:{{projectName}}/core/environment/environment_manager.dart';
import 'package:{{projectName}}/services/storage/storage_service.dart';
import 'package:{{projectName}}/services/theme/theme_service.dart';

${StorageTestSetup.helperClass(storage)}void main() {
${StorageTestSetup.setUpAndTearDown(storage)}

  tearDown(() async {
    await EnvironmentManager.instance.setEnvironment(Environment.prod);
    await ThemeService.instance.setTheme(ThemeMode.system);
  });

  testWidgets('shows the Environment and Theme options', (tester) async {
    await _pumpTallDebugPage(tester);

    expect(find.byType(DebugPage), findsOneWidget);
    expect(find.byType(RadioListTile<Environment>), findsNWidgets(3));
    expect(find.byType(RadioListTile<ThemeMode>), findsNWidgets(3));
  });

  testWidgets('Send Test Notification works without requiring Apply first', (
    tester,
  ) async {
    await _pumpTallDebugPage(tester);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Send Test Notification'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DebugPage), findsOneWidget);
    expect(EnvironmentManager.instance.currentEnvironment, Environment.prod);
  });

  testWidgets('Apply persists the selected Environment', (tester) async {
    await _pumpTallDebugPage(tester);

    await tester.tap(
      find.widgetWithText(RadioListTile<Environment>, 'Staging'),
    );
    await tester.pump();
    // Apply performs a real, storage-mechanism-dependent write (e.g.
    // real file I/O for Hive). testWidgets' fake-async test zone never
    // lets that complete on its own — WidgetTester.runAsync() is
    // Flutter's own documented escape hatch for exactly this.
    //
    // Critically, `tester.tap()` only delivers the pointer event — it
    // does not wait for the async `onPressed` body it triggers to
    // finish, and polling an observable side effect isn't reliable
    // either: `EnvironmentManager.setEnvironment()`/`ThemeService.
    // setTheme()` both update their in-memory value *synchronously*,
    // before `await`ing their real persistence write, so a poll would
    // see the "done" value while the underlying write — and therefore
    // Apply's own `await` chain — is still in flight. For Riverpod's
    // `StateNotifier`, letting the test (and so the widget) finish
    // while that write is still pending means the notifier gets
    // disposed before Apply's second, post-write `state` read runs,
    // throwing once the write finally resolves and that read fires. A
    // fixed, generous real delay — long enough for two local storage
    // writes to land under any realistic (including CI) load — is what
    // actually waits for completion here, not a proxy for it.
    await tester.runAsync(() async {
      await tester.tap(find.text('Apply'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(EnvironmentManager.instance.currentEnvironment, Environment.stage);
  });

  testWidgets('Cancel discards the draft without persisting anything', (
    tester,
  ) async {
    await _pumpTallDebugPage(tester);

    await tester.tap(
      find.widgetWithText(RadioListTile<Environment>, 'Staging'),
    );
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(EnvironmentManager.instance.currentEnvironment, Environment.prod);
  });
}

/// The Debug screen's content is taller than the default 800x600 test
/// surface, and `ListView` only builds children within its viewport
/// plus cache extent — so Apply/Cancel, near the bottom, would never
/// actually be built (and so never be findable/tappable) without this.
/// Enlarging the surface once, here, is simpler and more robust than
/// scrolling to each widget individually across every test below.
Future<void> _pumpTallDebugPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: DebugPage()));
}
''';
  }
}
