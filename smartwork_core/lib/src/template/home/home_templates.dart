import '../template.dart';

class HomeTemplates {
  static Template pageTemplateClean({bool includeFontSample = false}) {
    return Template(
      content: _pageBody(
        toLibDir: '../../../../',
        includeFontSample: includeFontSample,
      ),
    );
  }

  static Template pageTemplateMvvm({bool includeFontSample = false}) {
    return Template(
      content: _pageBody(
        toLibDir: '../../../',
        includeFontSample: includeFontSample,
      ),
    );
  }

  static Template pageTemplateMvp({bool includeFontSample = false}) {
    return Template(
      content: _pageBody(
        toLibDir: '../../../',
        includeFontSample: includeFontSample,
      ),
    );
  }

  static String _pageBody({
    required String toLibDir,
    required bool includeFontSample,
  }) {
    final fontSampleImport = includeFontSample
        ? "\nimport '${toLibDir}shared/ui/shared_ui.dart';"
        : '';
    final fontSampleWidget = includeFontSample
        ? '\n            const SizedBox(height: 24),'
            '\n            const FontSample(),'
        : '';
    return '''import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '${toLibDir}core/constants/constants.dart';
import '${toLibDir}services/routing/app_router.dart';$fontSampleImport

class {{pascalName}}Page extends StatefulWidget {
  const {{pascalName}}Page({super.key});

  @override
  State<{{pascalName}}Page> createState() => _{{pascalName}}PageState();
}

class _{{pascalName}}PageState extends State<{{pascalName}}Page> {
  int _tapCount = 0;

  void _onVersionTap() {
    if (!kDebugMode) return;
    _tapCount++;
    if (_tapCount >= AppConstants.debugTapCount) {
      _tapCount = 0;
      Navigator.of(context).pushNamed(AppRouter.debug);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppConstants.appName),
            const SizedBox(height: 8),
            GestureDetector(
              // The pubspec's own fixed version — see PubspecGenerator.
              onTap: _onVersionTap,
              child: const Text('v1.0.0'),
            ),$fontSampleWidget
          ],
        ),
      ),
    );
  }
}
''';
  }
}
