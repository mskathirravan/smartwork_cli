import '../../../models/service_definition.dart';

String debugLoggerSource() {
  return '''import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Application-level boundary for structured debug logging.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real logging provider to. SmartWork itself
/// never adds a concrete provider SDK here.
class DebugLogger {
  DebugLogger._();

  static final DebugLogger instance = DebugLogger._();

  void debug(String message) => _log('DEBUG', message);

  void info(String message) => _log('INFO', message);

  void warning(String message) => _log('WARNING', message);

  /// [error]/[stackTrace] are optional: not every error site has one or
  /// both.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    developer.log(
      '[ERROR] \$message',
      name: 'AppLogger',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(String level, String message) {
    if (!kDebugMode) return;
    developer.log('[\$level] \$message', name: 'AppLogger');
  }
}
''';
}

String debugLoggerTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.logger.folderName}/'
      'debug_logger.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = DebugLogger.instance;
    final b = DebugLogger.instance;
    expect(a, same(b));
  });

  test('debug/info/warning log without throwing', () {
    expect(() => DebugLogger.instance.debug('debug message'), returnsNormally);
    expect(() => DebugLogger.instance.info('info message'), returnsNormally);
    expect(
      () => DebugLogger.instance.warning('warning message'),
      returnsNormally,
    );
  });

  test('error() accepts an optional error and stack trace', () {
    expect(() => DebugLogger.instance.error('bare message'), returnsNormally);
    expect(
      () => DebugLogger.instance.error(
        'message with error',
        error: Exception('boom'),
        stackTrace: StackTrace.current,
      ),
      returnsNormally,
    );
  });
}
''';
}
