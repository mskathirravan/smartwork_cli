import '../template/naming_conventions.dart';

class RoutingGenerator {
  static const _reservedFeatureNames = {'debug'};

  String generate({
    required String homeFeatureName,
    List<String> otherFeatures = const [],
  }) {
    final homeNames = FeatureNames(homeFeatureName);

    final routableNames = _resolveRoutableFeatures(
      otherFeatures,
      homeFeatureName: homeFeatureName,
    );

    final featureImports = routableNames
        .map((name) =>
            "import '../../features/${name.snake}/${name.snake}.dart';")
        .join('\n');

    final featureCases =
        routableNames.map((name) => '''      case '/${name.snake}':
        return MaterialPageRoute(builder: (_) => const ${name.pascal}Page());
''').join();

    return '''import 'package:flutter/material.dart';

import '../../features/debug/debug.dart';
import '../../features/${homeNames.snake}/${homeNames.snake}.dart';
${featureImports.isEmpty ? '' : '$featureImports\n'}
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String debug = '/debug';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case debug:
        return MaterialPageRoute(builder: (_) => const DebugPage());
$featureCases      case home:
      default:
        return MaterialPageRoute(builder: (_) => const ${homeNames.pascal}Page());
    }
  }
}
''';
  }

  static List<String> resolveRoutableFeatureNames(
    List<String> rawFeatureNames, {
    required String homeFeatureName,
  }) {
    return rawFeatureNames
        .where((name) =>
            name != homeFeatureName && !_reservedFeatureNames.contains(name))
        .toSet()
        .toList()
      ..sort();
  }

  List<FeatureNames> _resolveRoutableFeatures(
    List<String> rawFeatureNames, {
    required String homeFeatureName,
  }) {
    return resolveRoutableFeatureNames(
      rawFeatureNames,
      homeFeatureName: homeFeatureName,
    ).map(FeatureNames.new).toList();
  }

  String generateTest({
    required String homeFeatureName,
    required String projectName,
    List<String> otherFeatures = const [],
  }) {
    final homeNames = FeatureNames(homeFeatureName);

    final routableNames = _resolveRoutableFeatures(
      otherFeatures,
      homeFeatureName: homeFeatureName,
    );

    final featureImports = routableNames
        .map((name) =>
            "import 'package:$projectName/features/${name.snake}/${name.snake}.dart';")
        .join('\n');

    final featureTests = routableNames.map((name) {
      final description = 'the ${name.snake} route resolves to '
          '${name.pascal}Page';
      final singleLine = "  testWidgets('$description', (tester) async {";
      final wrappedParam = "  testWidgets('$description', (";
      return switch (true) {
        _ when singleLine.length <= 80 => '''
  testWidgets('$description', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: '/${name.snake}',
      ),
    );

    expect(find.byType(${name.pascal}Page), findsOneWidget);
  });
''',
        _ when wrappedParam.length <= 80 => '''
  testWidgets('$description', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: '/${name.snake}',
      ),
    );

    expect(find.byType(${name.pascal}Page), findsOneWidget);
  });
''',
        _ => '''
  testWidgets(
    '$description',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: '/${name.snake}',
        ),
      );

      expect(find.byType(${name.pascal}Page), findsOneWidget);
    },
  );
''',
      };
    }).join();

    return '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:$projectName/services/routing/app_router.dart';
import 'package:$projectName/features/debug/debug.dart';
import 'package:$projectName/features/${homeNames.snake}/${homeNames.snake}.dart';
${featureImports.isEmpty ? '' : '$featureImports\n'}
void main() {
  testWidgets('the initial route resolves to Home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRouter.home,
      ),
    );

    expect(find.byType(${homeNames.pascal}Page), findsOneWidget);
  });

  testWidgets('the debug route resolves to DebugPage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRouter.debug,
      ),
    );

    expect(find.byType(DebugPage), findsOneWidget);
  });
$featureTests
  testWidgets('an unknown route name falls back safely to Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: '/this-route-does-not-exist',
      ),
    );

    expect(find.byType(${homeNames.pascal}Page), findsOneWidget);
  });

  test('route identifiers are owned by AppRouter, not scattered literals', () {
    expect(AppRouter.home, '/');
    expect(AppRouter.debug, '/debug');
  });
}
''';
  }
}
