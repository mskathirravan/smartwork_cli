import '../../../models/service_definition.dart';

String deviceInfoServiceSource() {
  return '''import 'package:flutter/foundation.dart';

import '../../core/utilities/app_platform.dart';

/// Application-level boundary for device/platform information.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real device-info provider to. SmartWork
/// itself never adds a concrete provider SDK here.
class DeviceInfoService {
  DeviceInfoService._();

  static final DeviceInfoService instance = DeviceInfoService._();

  /// The running platform (`android`, `ios`, `web`, `windows`, `macos`,
  /// `linux`, or `fuchsia`), resolved through the shared `AppPlatform`
  /// — real today, no extra package.
  String get platform {
    if (AppPlatform.isWeb) return 'web';
    if (AppPlatform.isAndroid) return 'android';
    if (AppPlatform.isIOS) return 'ios';
    if (AppPlatform.isMacOS) return 'macos';
    if (AppPlatform.isWindows) return 'windows';
    if (AppPlatform.isLinux) return 'linux';
    return defaultTargetPlatform.name;
  }

  /// Requires a platform-info package (e.g. `device_info_plus`) to
  /// resolve for real. SmartWork adds none, so this is a documented
  /// baseline until a future provider is wired in.
  String get osVersion => 'unknown';

  /// Requires a platform-info package (e.g. `device_info_plus`) to
  /// resolve for real. SmartWork adds none, so this is a documented
  /// baseline until a future provider is wired in.
  String get deviceModel => 'unknown';

  /// Requires a platform-info package (e.g. `package_info_plus`) to
  /// resolve for real. SmartWork adds none, so this is a documented
  /// baseline until a future provider is wired in.
  String get appVersion => 'unknown';

  /// Requires a platform-info package (e.g. `package_info_plus`) to
  /// resolve for real. SmartWork adds none, so this is a documented
  /// baseline until a future provider is wired in.
  String get buildNumber => 'unknown';
}
''';
}

String deviceInfoServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.deviceInfo.folderName}/'
      'device_info_service.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = DeviceInfoService.instance;
    final b = DeviceInfoService.instance;
    expect(a, same(b));
  });

  test('platform resolves to one of the real, known platform names', () {
    expect(
      DeviceInfoService.instance.platform,
      anyOf('android', 'ios', 'web', 'windows', 'macos', 'linux', 'fuchsia'),
    );
  });

  test('osVersion/deviceModel/appVersion/buildNumber are the documented '
      'baseline until a platform-info provider is added', () {
    expect(DeviceInfoService.instance.osVersion, 'unknown');
    expect(DeviceInfoService.instance.deviceModel, 'unknown');
    expect(DeviceInfoService.instance.appVersion, 'unknown');
    expect(DeviceInfoService.instance.buildNumber, 'unknown');
  });
}
''';
}
