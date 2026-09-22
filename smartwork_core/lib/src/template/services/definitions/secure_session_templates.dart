import '../../../models/project_config.dart';
import '../../testing/storage_test_setup.dart';

String secureSessionManagerSource() {
  return '''import '../../core/constants/constants.dart';
import '../storage/storage_service.dart';

/// Application-level boundary for secure session/token storage.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real secure-storage provider to. SmartWork
/// itself never adds a concrete provider SDK here.
class SecureSessionManager {
  SecureSessionManager._();

  static final SecureSessionManager instance = SecureSessionManager._();

  String? _accessToken;
  String? _refreshToken;

  /// Whether a session is currently held, in memory or restored by
  /// [initialize].
  bool get hasSession => _accessToken != null;

  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  /// Restores a previously persisted session, if any. Called once from
  /// `Bootstrap.initialize()`, before `runApp()`.
  Future<void> initialize() async {
    _accessToken = await StorageService.instance.getString(
      StorageConstants.secureAccessTokenKey,
    );
    _refreshToken = await StorageService.instance.getString(
      StorageConstants.secureRefreshTokenKey,
    );
  }

  /// Stores the current session and persists it through
  /// `StorageService`.
  Future<void> setSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await StorageService.instance.setString(
      StorageConstants.secureAccessTokenKey,
      accessToken,
    );
    if (refreshToken == null) {
      await StorageService.instance.remove(
        StorageConstants.secureRefreshTokenKey,
      );
    } else {
      await StorageService.instance.setString(
        StorageConstants.secureRefreshTokenKey,
        refreshToken,
      );
    }
  }

  /// Clears the current session, in memory and from persistence (e.g.
  /// on sign-out).
  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    await StorageService.instance.remove(StorageConstants.secureAccessTokenKey);
    await StorageService.instance.remove(
      StorageConstants.secureRefreshTokenKey,
    );
  }
}
''';
}

String secureSessionManagerTestSource(
  String projectName,
  Storage storage,
) {
  return '''import 'package:flutter_test/flutter_test.dart';
${StorageTestSetup.imports(storage)}

import 'package:$projectName/core/constants/constants.dart';
import 'package:$projectName/services/secure_session/secure_session_manager.dart';
import 'package:$projectName/services/storage/storage_service.dart';

${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

${StorageTestSetup.setUpAndTearDown(storage)}

  tearDown(() async {
    await SecureSessionManager.instance.clearSession();
  });

  test('instance is a singleton', () {
    final a = SecureSessionManager.instance;
    final b = SecureSessionManager.instance;
    expect(a, same(b));
  });

  test('has no session until setSession() is called', () {
    expect(SecureSessionManager.instance.hasSession, isFalse);
  });

  test('setSession() stores and persists both tokens through '
      'StorageService', () async {
    await SecureSessionManager.instance.setSession(
      accessToken: 'access-123',
      refreshToken: 'refresh-456',
    );

    expect(SecureSessionManager.instance.hasSession, isTrue);
    expect(SecureSessionManager.instance.accessToken, 'access-123');
    expect(SecureSessionManager.instance.refreshToken, 'refresh-456');
    expect(
      await StorageService.instance.getString(
        StorageConstants.secureAccessTokenKey,
      ),
      'access-123',
    );
    expect(
      await StorageService.instance.getString(
        StorageConstants.secureRefreshTokenKey,
      ),
      'refresh-456',
    );
  });

  test('clearSession() clears both tokens, in memory and persisted', () async {
    await SecureSessionManager.instance.setSession(
      accessToken: 'access-123',
      refreshToken: 'refresh-456',
    );

    await SecureSessionManager.instance.clearSession();

    expect(SecureSessionManager.instance.hasSession, isFalse);
    expect(
      await StorageService.instance.getString(
        StorageConstants.secureAccessTokenKey,
      ),
      isNull,
    );
    expect(
      await StorageService.instance.getString(
        StorageConstants.secureRefreshTokenKey,
      ),
      isNull,
    );
  });

  test('initialize() restores a previously persisted session', () async {
    await SecureSessionManager.instance.setSession(
      accessToken: 'access-123',
      refreshToken: 'refresh-456',
    );

    await SecureSessionManager.instance.initialize();

    expect(SecureSessionManager.instance.accessToken, 'access-123');
    expect(SecureSessionManager.instance.refreshToken, 'refresh-456');
  });
}
''';
}
