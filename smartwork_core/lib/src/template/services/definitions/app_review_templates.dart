import '../../../models/service_definition.dart';

String appReviewServiceSource() {
  return '''import 'package:in_app_review/in_app_review.dart';

import '../../core/utilities/app_platform.dart';

/// Application-level boundary for requesting an in-app review.
///
/// Provider-neutral: no review-prompting policy of any kind (launch
/// counters, time-since-install, eligibility rules, ...) — the
/// developer decides when to call [requestReview]. Safe on every
/// SmartWork target: `in_app_review` only ships a real platform
/// implementation for Android/iOS/macOS, so both methods below resolve
/// to a safe default everywhere else rather than throwing.
class AppReviewService {
  AppReviewService._();

  static final AppReviewService instance = AppReviewService._();

  /// Delegates to the shared `AppPlatform`
  /// (`lib/core/utilities/app_platform.dart`) — this used to hand-roll
  /// its own `kIsWeb`/`defaultTargetPlatform` switch, duplicating
  /// `DeviceInfoService`'s own copy of the same check; both now share
  /// one implementation. Behavior-identical to the previous switch:
  /// web/windows/linux/fuchsia all still resolve to `false`, exactly as
  /// the old wildcard `_ => false` case already did.
  bool get _isSupportedPlatform =>
      AppPlatform.isAndroid || AppPlatform.isIOS || AppPlatform.isMacOS;

  /// Whether an in-app review request can currently be made. Always
  /// `false` on a platform `in_app_review` does not support.
  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    return InAppReview.instance.isAvailable();
  }

  /// Requests an in-app review. A safe no-op on a platform
  /// `in_app_review` does not support.
  Future<void> requestReview() async {
    if (!_isSupportedPlatform) return;
    await InAppReview.instance.requestReview();
  }
}
''';
}

String appReviewServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.appReview.folderName}/'
      'app_review_service.dart';
  return '''import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = null);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('instance is a singleton', () {
    final a = AppReviewService.instance;
    final b = AppReviewService.instance;
    expect(a, same(b));
  });

  test('isAvailable/requestReview are safe on every platform in_app_review '
      'does not support — never a MissingPluginException', () async {
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;

      expect(await AppReviewService.instance.isAvailable(), isFalse);
      await AppReviewService.instance.requestReview();
    }
  });
}
''';
}
