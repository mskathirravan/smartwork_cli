import '../models/project_config.dart';

class MainDartGenerator {
  static const _appClassName = 'MyApp';

  String generate(ProjectConfig config) {
    final localization = config.localization;
    final localizationImport =
        localization.enabled ? "import 'l10n/app_localizations.dart';\n" : '';
    final onGenerateTitle = localization.enabled
        ? '\n          onGenerateTitle: (context) => '
            'AppLocalizations.of(context)!.appTitle,'
        : '';
    final localizationParams = localization.enabled
        ? '\n          localizationsDelegates: '
            'AppLocalizations.localizationsDelegates,'
            '\n${_supportedLocalesLine(localization.orderedLocales)}'
        : '';

    return '''import 'package:flutter/material.dart';

import 'core/constants/constants.dart';
import 'core/environment/environment.dart';
import 'core/environment/environment_manager.dart';
${localizationImport}import 'services/bootstrap/bootstrap.dart';
import 'services/routing/app_router.dart';
import 'services/theme/app_theme.dart';
import 'services/theme/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Bootstrap.initialize();

  runApp(const $_appClassName());
}

class $_appClassName extends StatelessWidget {
  const $_appClassName({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.instance,
        EnvironmentManager.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,$onGenerateTitle
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeService.instance.currentThemeMode,$localizationParams
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: AppRouter.home,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            final environment = EnvironmentManager.instance.currentEnvironment;
            if (environment == Environment.prod) return child;
            return Banner(
              message: environment.label,
              location: BannerLocation.topEnd,
              color: Colors.red,
              child: child,
            );
          },
        );
      },
    );
  }
}
''';
  }

  String _localeExpr(String locale) {
    final parts = locale.split('_');
    if (parts.length == 1) return "Locale('${parts[0]}')";
    return "Locale('${parts[0]}', '${parts[1]}')";
  }

  String _supportedLocalesLine(List<String> orderedLocales) {
    final exprs = orderedLocales.map(_localeExpr).toList();
    final oneLine = '          supportedLocales: const [${exprs.join(', ')}],';
    if (oneLine.length <= 80) return oneLine;
    final items = exprs.map((e) => '            $e,').join('\n');
    return '          supportedLocales: const [\n$items\n          ],';
  }
}
