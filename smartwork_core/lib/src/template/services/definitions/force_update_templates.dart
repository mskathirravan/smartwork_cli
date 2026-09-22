import '../../../models/service_definition.dart';

String forceUpdateServiceSource() {
  return '''import 'package:package_info_plus/package_info_plus.dart';

/// Application-level boundary for minimum-version enforcement.
///
/// Provider-neutral: owns retrieving and caching this app's own
/// version, and comparing it against a caller-supplied minimum. Never
/// owns where that minimum comes from (a remote config, a backend, a
/// hardcoded value are all the developer's own decision), never makes
/// a network/store request itself, and has no update policy or UI of
/// its own.
class ForceUpdateService {
  ForceUpdateService._();

  static final ForceUpdateService instance = ForceUpdateService._();

  String _currentVersion = '';

  /// The running app's own version (e.g. `'1.2.3'`), populated by
  /// [initialize]. Empty until then.
  String get currentVersion => _currentVersion;

  /// Fetches and caches the running app's version. Called once from
  /// `Bootstrap.initialize()`, before `runApp()`.
  Future<void> initialize() async {
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version;
  }

  /// Whether [currentVersion] is lower than [minimumVersion]. Compares
  /// `major.minor.patch` components numerically. A missing component
  /// defaults to `0` (`'1.2'` is treated as `'1.2.0'`). A malformed
  /// [minimumVersion] (or an unset [currentVersion]) never throws —
  /// it returns `false`, since an update should never be forced on a
  /// version this class could not actually parse.
  bool isUpdateRequired(String minimumVersion) {
    final current = _parse(_currentVersion);
    final minimum = _parse(minimumVersion);
    if (current == null || minimum == null) return false;

    for (var i = 0; i < 3; i++) {
      if (current[i] != minimum[i]) return current[i] < minimum[i];
    }
    return false;
  }

  List<int>? _parse(String version) {
    final parts = version.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null || number < 0) return null;
      numbers.add(number);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers;
  }
}
''';
}

String forceUpdateServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.forceUpdate.folderName}/'
      'force_update_service.dart';
  return '''import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '$importPath';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '$projectName',
      packageName: 'com.example.$projectName',
      version: '1.2.3',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  test('instance is a singleton', () {
    final a = ForceUpdateService.instance;
    final b = ForceUpdateService.instance;
    expect(a, same(b));
  });

  test('initialize() populates currentVersion from the real package', () async {
    await ForceUpdateService.instance.initialize();

    expect(ForceUpdateService.instance.currentVersion, '1.2.3');
  });

  test('isUpdateRequired is false when current equals the minimum', () async {
    await ForceUpdateService.instance.initialize();

    expect(ForceUpdateService.instance.isUpdateRequired('1.2.3'), isFalse);
  });

  test(
    'isUpdateRequired is false when current is greater than the minimum',
    () async {
      await ForceUpdateService.instance.initialize();

      expect(ForceUpdateService.instance.isUpdateRequired('1.2.2'), isFalse);
      expect(ForceUpdateService.instance.isUpdateRequired('1.1.9'), isFalse);
      expect(ForceUpdateService.instance.isUpdateRequired('0.9.9'), isFalse);
    },
  );

  test('isUpdateRequired is true when current is lower than the minimum, '
      'comparing major/minor/patch numerically', () async {
    await ForceUpdateService.instance.initialize();

    expect(ForceUpdateService.instance.isUpdateRequired('1.2.4'), isTrue);
    expect(ForceUpdateService.instance.isUpdateRequired('1.3.0'), isTrue);
    expect(ForceUpdateService.instance.isUpdateRequired('2.0.0'), isTrue);
  });

  test('isUpdateRequired treats a missing patch component as zero', () async {
    await ForceUpdateService.instance.initialize();

    expect(ForceUpdateService.instance.isUpdateRequired('1.2'), isFalse);
    expect(ForceUpdateService.instance.isUpdateRequired('1.3'), isTrue);
  });

  test('isUpdateRequired is false for a malformed minimum version', () async {
    await ForceUpdateService.instance.initialize();

    expect(
      ForceUpdateService.instance.isUpdateRequired('not-a-version'),
      isFalse,
    );
    expect(ForceUpdateService.instance.isUpdateRequired(''), isFalse);
  });

  test('isUpdateRequired is deterministic across repeated calls', () async {
    await ForceUpdateService.instance.initialize();

    expect(
      ForceUpdateService.instance.isUpdateRequired('1.3.0'),
      ForceUpdateService.instance.isUpdateRequired('1.3.0'),
    );
  });
}
''';
}
