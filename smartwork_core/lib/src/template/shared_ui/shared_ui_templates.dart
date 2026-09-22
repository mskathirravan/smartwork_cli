import '../../models/font_config.dart';
import '../template.dart';

class SharedUiTemplates {
  static Template loadingIndicatorTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// A centered loading spinner, with an optional message beneath it.
/// Provider-independent — place it anywhere a loading condition needs
/// a loading widget to show, regardless of what tracks that condition.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message});

  /// Optional text shown beneath the spinner.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Text(message!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
''');
  }

  static Template appAlertTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// The four statuses an [AppAlert] can represent.
enum AlertType { success, warning, info, error }

/// A small inline alert banner for common application messaging.
/// Provider-independent — a plain [StatelessWidget] the caller places
/// directly in their own widget tree.
class AppAlert extends StatelessWidget {
  const AppAlert({super.key, required this.type, required this.message});

  final AlertType type;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      AlertType.success => AppColors.success,
      AlertType.warning => AppColors.warning,
      AlertType.info => AppColors.info,
      AlertType.error => Theme.of(context).colorScheme.error,
    };
    final icon = switch (type) {
      AlertType.success => Icons.check_circle_outline,
      AlertType.warning => Icons.warning_amber_outlined,
      AlertType.info => Icons.info_outline,
      AlertType.error => Icons.error_outline,
    };

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
''');
  }

  static Template maintenanceViewTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// A full-size "under maintenance" view. The caller decides when to
/// show it — this widget owns no remote configuration, feature flag,
/// or polling of its own.
class MaintenanceView extends StatelessWidget {
  const MaintenanceView({
    super.key,
    this.title = 'Under Maintenance',
    this.message =
        'This feature is temporarily unavailable. Please check back later.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.build_outlined, size: 48),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
''');
  }

  static Template emptyStateViewTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// A full-size empty-state view: a required [title], and an optional
/// [description], leading [icon], and trailing [action] widget (e.g. a
/// button the caller wires to their own "create the first item" flow).
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.action,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48),
              const SizedBox(height: AppDimensions.spacingMd),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(description!, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
''');
  }

  static Template errorStateViewTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// A full-size error view. [onRetry], when provided, is called
/// directly on tap — this widget never performs the retry itself.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
''');
  }

  static Template accessibleTemplate() {
    return Template(content: '''import 'package:flutter/widgets.dart';

/// Wraps [child] with Flutter's own [Semantics] — the minimum useful
/// surface for generated UI: a screen-reader [label], an optional
/// [hint], and whether [child] should be announced as a [button].
class AccessibleWidget extends StatelessWidget {
  const AccessibleWidget({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.button = false,
  });

  final Widget child;
  final String? label;
  final String? hint;
  final bool button;

  @override
  Widget build(BuildContext context) {
    return Semantics(label: label, hint: hint, button: button, child: child);
  }
}
''');
  }

  static Template sharedUiBarrelTemplate({
    bool splashPresent = false,
    bool fontSamplePresent = false,
  }) {
    return Template(content: '''export 'accessible.dart';
export 'app_alert.dart';
export 'empty_state_view.dart';
export 'error_state_view.dart';
${fontSamplePresent ? "export 'font_sample.dart';\n" : ''}export 'loading_indicator.dart';
export 'maintenance_view.dart';
${splashPresent ? "export 'splash_screen.dart';\n" : ''}''');
  }

  static Template fontSampleTemplate(FontConfig fonts) {
    final family = switch (fonts.type) {
      FontType.custom => fonts.custom!.family,
      FontType.google => fonts.google!.family,
      FontType.none => '',
    };
    return Template(content: '''import 'package:flutter/material.dart';

class FontSample extends StatelessWidget {
  const FontSample({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Font: $family', style: textTheme.labelMedium),
          const SizedBox(height: 16),
          Text('Heading sample', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Body sample text', style: textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Caption sample text', style: textTheme.labelSmall),
          const SizedBox(height: 16),
          Text('Label', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Sample label', style: textTheme.labelMedium)),
              ElevatedButton(
                onPressed: () {},
                child: Text('Sample button', style: textTheme.labelLarge),
              ),
              OutlinedButton(
                onPressed: () {},
                child: Text('Outlined button', style: textTheme.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('List', style: textTheme.labelLarge),
          for (final item in const [
            'First list item',
            'Second list item',
            'Third list item',
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle, size: 8),
              title: Text(item, style: textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}
''');
  }

  static Template sharedUiTestTemplate() {
    return Template(content: '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/shared/ui/shared_ui.dart';

void main() {
  testWidgets('LoadingIndicator shows a spinner and an optional message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoadingIndicator(message: 'Loading...')),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('AppAlert shows its message for every AlertType', (tester) async {
    for (final type in AlertType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppAlert(type: type, message: 'Alert message'),
        ),
      );
      expect(find.text('Alert message'), findsOneWidget);
    }
  });

  testWidgets('MaintenanceView shows its default title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MaintenanceView()));

    expect(find.text('Under Maintenance'), findsOneWidget);
  });

  testWidgets('MaintenanceView shows an overridden title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MaintenanceView(title: 'Back Soon')),
    );

    expect(find.text('Back Soon'), findsOneWidget);
  });

  testWidgets('EmptyStateView shows the title and, when given, the action', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EmptyStateView(
          title: 'Nothing here',
          description: 'Add your first item',
          action: ElevatedButton(
            onPressed: () => tapped = true,
            child: const Text('Add item'),
          ),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add your first item'), findsOneWidget);
    await tester.tap(find.text('Add item'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorStateView calls onRetry, never performing recovery '
      'itself', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorStateView(
          message: 'Something went wrong',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('ErrorStateView shows no retry button when onRetry is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ErrorStateView(message: 'Failed')),
    );

    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('AccessibleWidget attaches a semantics label', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: AccessibleWidget(
          label: 'Submit form',
          button: true,
          child: Icon(Icons.check),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Submit form'), findsOneWidget);
    handle.dispose();
  });
}
''');
  }
}
