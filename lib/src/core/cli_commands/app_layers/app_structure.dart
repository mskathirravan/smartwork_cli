import '../operations/operations.dart';

class AppStructure {
  static bool createStructure({required String directoryPath}) {
    String sharedPath = '$directoryPath/shared';
    List<bool> operations = [
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: 'main.dart',
          content: _mainContent()),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'features'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'routes'),
      Operations.createFile(
          directoryPath: '$directoryPath/routes',
          fileName: 'routes_manager.dart',
          content: _routesManager()),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'shared'),
      Operations.createFolder(directoryPath: sharedPath, folderName: 'widgets'),
      Operations.createFolder(directoryPath: sharedPath, folderName: 'theme'),
      Operations.createFile(
          directoryPath: '$sharedPath/theme',
          fileName: 'app_colors.dart',
          content: _appColorsContent()),
      Operations.createFile(
          directoryPath: '$sharedPath/theme',
          fileName: 'app_theme.dart',
          content: _appThemeContent()),
      Operations.createFile(
          directoryPath: '$sharedPath/theme',
          fileName: 'text_styles.dart',
          content: _textStylesContent()),
      Operations.createFile(
          directoryPath: '$sharedPath/theme',
          fileName: 'text_theme.dart',
          content: _textThemeContent()),
      Operations.createFolder(
          directoryPath: sharedPath, folderName: 'initializer'),
      Operations.createFile(
          directoryPath: '$sharedPath/initializer',
          fileName: 'initializer.dart',
          content: _initializerContent()),
      Operations.createFolder(
          directoryPath: '$sharedPath/initializer', folderName: 'widgets'),
      Operations.createFile(
          directoryPath: '$sharedPath/initializer/widgets',
          fileName: 'custom_error_widget.dart',
          content: _initializerWidgetContent()),
      Operations.createFolder(directoryPath: sharedPath, folderName: 'keys'),
      Operations.createFile(
          directoryPath: '$sharedPath/keys',
          fileName: 'storage_keys.dart',
          content: _storageKeysContent()),
      Operations.createFolder(
          directoryPath: sharedPath, folderName: 'data_storage'),
      Operations.createFile(
          directoryPath: '$sharedPath/data_storage',
          fileName: 'data_storage.dart',
          content: _dataStorageContent()),
      Operations.createFolder(directoryPath: sharedPath, folderName: 'mixins'),
      Operations.createFolder(
          directoryPath: sharedPath, folderName: 'exceptions'),
      Operations.createFolder(directoryPath: sharedPath, folderName: 'utils'),
    ];

    // check if all operations are true
    if (operations.every((element) => element == true)) {
      return true;
    } else {
      return false;
    }
  }

  static String _routesManager() {
    return '''
import 'package:flutter/material.dart';
import '../features/home/home.dart';

class Routes {
  static const String homeRoute = '/home';
  static const String landingRoute = '/landing';

  static Route<dynamic> getRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case Routes.landingRoute:
        return landingScreen();
      case Routes.homeRoute:
        return MaterialPageRoute(
            builder: (_) => const HomeScreen(
                  isLoading: true,
                  data: '',
                ));
      default:
        return undefinedRoute();
    }
  }

  static Route<dynamic> undefinedRoute() {
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(
          child: Text('Page not found!'),
        ),
      ),
    );
  }

  static Route<dynamic> landingScreen() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        // Use a FutureBuilder to handle the redirect after a delay
        return FutureBuilder(
          future: Future.delayed(const Duration(seconds: 0)),
          builder: (context, snapshot) {
            // Check if the future is completed
            if (snapshot.connectionState == ConnectionState.done) {
              // Replace the current page with HomeScreen
              WidgetsBinding.instance.addPostFrameCallback((_) {
               replaceWith(context, Routes.homeRoute);
              });
            }
            // Display a placeholder or loading indicator while waiting
            return const Scaffold(
              body: SizedBox(),
            );
          },
        );
      },
    );
  }

  static void navigateTo(BuildContext context, String route,
      {dynamic arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  static void replaceWith(BuildContext context, String route,
      {dynamic arguments}) {
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false,
        arguments: arguments);
  }

  static void navigateBack(BuildContext context) {
    Navigator.pop(context);
  }
}
    ''';
  }

  static String _mainContent() {
    return '''
import 'package:flutter/material.dart';
import 'routes/routes_manager.dart';
import 'shared/initializer/initializer.dart';
import 'shared/theme/app_theme.dart';

void main() {
  Initializer.singleton.init(() {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: Routes.getRoute,
      initialRoute: Routes.landingRoute,
      theme: AppTheme.lightTheme, // Set the light theme
      darkTheme: AppTheme.darkTheme, // Set the dark theme
      themeMode: ThemeMode.system, // Use system theme (light/dark)
    );
  }
}
    ''';
  }

  static String _appColorsContent() {
    return '''
import 'package:flutter/material.dart';

class AppColors {
  /// App primary color
  static const Color primary = Color(0xff1DA1F2);

  /// App secondary color
  static const Color error = Color(0xffFC698C);

  /// App black color
  static const Color black = Color(0xff14171A);

  /// App white color
  static const Color white = Color(0xffffffff);

  /// Light grey color
  static const Color lightGrey = Color(0xffAAB8C2);

  /// Extra Light grey color
  static const Color extraLightGrey = Color(0xffE1E8ED);
}
    ''';
  }

  static String _appThemeContent() {
    return '''
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'text_theme.dart';
import 'text_styles.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.fontFamily,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.lightGrey,
        error: AppColors.error,
      ),
      // backgroundColor: AppColors.black,
      scaffoldBackgroundColor: AppColors.black,
      textTheme: TextThemes.darkTextTheme,
      primaryTextTheme: TextThemes.primaryTextTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.black,
        titleTextStyle: AppTextStyles.h2,
      ),
    );
  }

  /// Light theme data of the app
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      textTheme: TextThemes.textTheme,
      primaryTextTheme: TextThemes.primaryTextTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.lightGrey,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
    ''';
  }

  static String _textStylesContent() {
    return '''
import 'package:flutter/material.dart';

class AppTextStyles {
  static const String fontFamily = 'Helvetica';

  /// Text style for body
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
  );

  static const TextStyle bodyXs = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w300,
  );

  /// Text style for heading

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
}
    ''';
  }

  static String _textThemeContent() {
    return '''
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'text_styles.dart';

class TextThemes {
  /// Main text theme

  static TextTheme get textTheme {
    return const TextTheme(
      bodyLarge: AppTextStyles.bodyLg,
      bodyMedium: AppTextStyles.body,
      titleMedium: AppTextStyles.bodySm,
      titleSmall: AppTextStyles.bodyXs,
      displayLarge: AppTextStyles.h1,
      displayMedium: AppTextStyles.h2,
      displaySmall: AppTextStyles.h3,
      headlineMedium: AppTextStyles.h4,
    );
  }

  /// Dark text theme

  static TextTheme get darkTextTheme {
    return TextTheme(
      bodyLarge: AppTextStyles.bodyLg.copyWith(color: AppColors.white),
      bodyMedium: AppTextStyles.body.copyWith(color: AppColors.white),
      titleMedium: AppTextStyles.bodySm.copyWith(color: AppColors.white),
      titleSmall: AppTextStyles.bodyXs.copyWith(color: AppColors.white),
      displayLarge: AppTextStyles.h1.copyWith(color: AppColors.white),
      displayMedium: AppTextStyles.h2.copyWith(color: AppColors.white),
      displaySmall: AppTextStyles.h3.copyWith(color: AppColors.white),
      headlineMedium: AppTextStyles.h4.copyWith(color: AppColors.white),
    );
  }

  /// Primary text theme

  static TextTheme get primaryTextTheme {
    return TextTheme(
      bodyLarge: AppTextStyles.bodyLg.copyWith(color: AppColors.primary),
      bodyMedium: AppTextStyles.body.copyWith(color: AppColors.primary),
      titleMedium: AppTextStyles.bodySm.copyWith(color: AppColors.primary),
      titleSmall: AppTextStyles.bodyXs.copyWith(color: AppColors.primary),
      displayLarge: AppTextStyles.h1.copyWith(color: AppColors.primary),
      displayMedium: AppTextStyles.h2.copyWith(color: AppColors.primary),
      displaySmall: AppTextStyles.h3.copyWith(color: AppColors.primary),
      headlineMedium: AppTextStyles.h4.copyWith(color: AppColors.primary),
    );
  }
}
    ''';
  }

  static String _initializerContent() {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/custom_error_widget.dart';
import 'dart:async';

class Initializer {
  static final Initializer singleton = Initializer._internal();

  factory Initializer() {
    return singleton;
  }

  Initializer._internal();

  void init(VoidCallback runApp) {
    ErrorWidget.builder = (errorDetails) {
      return CustomErrorWidget(
        message: errorDetails.exceptionAsString(),
      );
    };

    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        debugPrint(details.stack.toString());
      };

      await _initServices();
      runApp();
    }, (error, stack) {
       debugPrint('runZonedGuarded: \${error.toString()}');
    });
  }

  Future<void> _initServices() async {
    try {
      _initScreenPreference();
      await _initDataStorage();
      await _initAnalytics();
      await _initCrashlytics();
      await _initDeepLinking();
      await _initPushNotification();
      debugPrint('Initializer --> initServices');
    } catch (err) {
      rethrow;
    }
  }

  Future<void> _initDataStorage() async {}

  Future<void> _initAnalytics() async {}

  Future<void> _initCrashlytics() async {}

  Future<void> _initDeepLinking() async {}

  Future<void> _initPushNotification() async {}

  void _initScreenPreference() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}

    ''';
  }

  static String _initializerWidgetContent() {
    return '''
import 'package:flutter/material.dart';

class CustomErrorWidget extends StatelessWidget {
  const CustomErrorWidget({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(message),
      ),
    );
  }
}
    ''';
  }

  static String _dataStorageContent() {
    return '''
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DataStorage {
  static final DataStorage singleton = DataStorage._internal();

  factory DataStorage() {
    return singleton;
  }

  DataStorage._internal();

  late SharedPreferences _sharedPreferences;

  Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
    debugPrint("DataStorage --> init");
  }

  Future<bool> containsKey(String key) {
    return Future.value(_sharedPreferences.containsKey(key));
  }

  Future<bool> setString(String key, String value) {
    return _sharedPreferences.setString(key, value);
  }

  Future<bool> setBool(String key, bool value) {
    return _sharedPreferences.setBool(key, value);
  }

  Future<bool> setInt(String key, int value) {
    return _sharedPreferences.setInt(key, value);
  }

  Future<bool> setDouble(String key, double value) {
    return _sharedPreferences.setDouble(key, value);
  }

  Future<bool> remove(String key) {
    return _sharedPreferences.remove(key);
  }

  Future<bool> clear() {
    return _sharedPreferences.clear();
  }

  String getString(String key) {
    final value = _sharedPreferences.getString(key);
    return value ?? '';
  }

  bool getBool(String key) {
    final value = _sharedPreferences.getBool(key);
    return value ?? false;
  }

  int getInt(String key) {
    final value = _sharedPreferences.getInt(key);
    return value ?? 0;
  }

  double getDouble(String key) {
    final value = _sharedPreferences.getDouble(key);
    return value ?? 0;
  }
}
    ''';
  }

  static String _storageKeysContent() {
    return '''
class StorageKeys {
  final String currentMode = 'currentMode';
  final String baseUrl = 'baseUrl';
  final String accessToken = 'accessToken';
  final String refreshToken = 'refreshToken';
  final String isLoggedIn = 'isLoggedIn';
  final String userName = 'userName';
  final String userId = 'userId';
  final String pushNotificationTopic = 'pushNotificationTopic';

  final String customUrl = 'customUrl';
  final String customUrlAction = 'customUrlAction';
  final String environment = 'environment';
  final String loginService = 'loginService';
  final String visibleLevel = 'visibleLevel';
  final String disableAssignment = 'disableAssignment';
}
    ''';
  }

  //  static String _textStylesContent() {
  //   return '''
  //   ''';
  // }
}
