/// A Production Service SmartWork can generate into a project.
enum Service {
  /// Secure session and token storage.
  secureSession,

  /// Network connectivity monitoring.
  connectivity,

  /// Device and platform information.
  deviceInfo,

  /// Accessibility settings (screen reader, text scale, reduced motion).
  accessibility,

  /// Structured debug logging.
  logger,

  /// Crash and error reporting.
  crashReporting,

  /// Push notifications.
  notification,

  /// Deep link handling.
  deeplink,

  /// Product analytics.
  analytics,

  /// Minimum-version enforcement (force update).
  forceUpdate,

  /// In-app review requests.
  appReview,

  /// In-memory, typed publish/subscribe for app events.
  eventBus,

  /// Remote configuration (feature flags, dynamic values).
  remoteConfig,
}

/// The group a [Service] is listed under.
enum ServiceCategory {
  /// Security services.
  security,

  /// Device and runtime services.
  deviceRuntime,

  /// Diagnostics services.
  diagnostics,

  /// Application integration services.
  applicationIntegration,
}

/// Display names for a [ServiceCategory].
extension ServiceCategoryLabel on ServiceCategory {
  /// Its human-readable name, e.g. `Device / Runtime`.
  String get displayName => switch (this) {
        ServiceCategory.security => 'Security',
        ServiceCategory.deviceRuntime => 'Device / Runtime',
        ServiceCategory.diagnostics => 'Diagnostics',
        ServiceCategory.applicationIntegration => 'Application Integration',
      };
}

/// What SmartWork generates for each [Service].
extension ServiceDefinition on Service {
  /// Its identifier, as used on the command line and in
  /// `.smartwork/project.yaml`, e.g. `forceUpdate`.
  String get id => name;

  /// Its human-readable name, e.g. `Force Update`.
  String get displayName => switch (this) {
        Service.secureSession => 'Secure Session',
        Service.connectivity => 'Connectivity Monitor',
        Service.deviceInfo => 'Device Info',
        Service.accessibility => 'Accessibility',
        Service.logger => 'Debug Logger',
        Service.crashReporting => 'Crash Reporting',
        Service.notification => 'Notifications',
        Service.deeplink => 'Deep Linking',
        Service.analytics => 'Analytics',
        Service.forceUpdate => 'Force Update',
        Service.appReview => 'App Review',
        Service.eventBus => 'Event Bus',
        Service.remoteConfig => 'Remote Config',
      };

  /// The group it is listed under.
  ServiceCategory get category => switch (this) {
        Service.secureSession => ServiceCategory.security,
        Service.connectivity => ServiceCategory.deviceRuntime,
        Service.deviceInfo => ServiceCategory.deviceRuntime,
        Service.accessibility => ServiceCategory.deviceRuntime,
        Service.logger => ServiceCategory.diagnostics,
        Service.crashReporting => ServiceCategory.diagnostics,
        Service.notification => ServiceCategory.applicationIntegration,
        Service.deeplink => ServiceCategory.applicationIntegration,
        Service.analytics => ServiceCategory.applicationIntegration,
        Service.forceUpdate => ServiceCategory.applicationIntegration,
        Service.appReview => ServiceCategory.applicationIntegration,
        Service.eventBus => ServiceCategory.applicationIntegration,
        Service.remoteConfig => ServiceCategory.applicationIntegration,
      };

  /// The generated Dart file's name, e.g. `force_update_service.dart`.
  String get fileName => switch (this) {
        Service.secureSession => 'secure_session_manager.dart',
        Service.connectivity => 'connectivity_monitor.dart',
        Service.deviceInfo => 'device_info_service.dart',
        Service.accessibility => 'accessibility_service.dart',
        Service.logger => 'debug_logger.dart',
        Service.crashReporting => 'crash_reporting_service.dart',
        Service.notification => 'notification_service.dart',
        Service.deeplink => 'deeplink_service.dart',
        Service.analytics => 'analytics_service.dart',
        Service.forceUpdate => 'force_update_service.dart',
        Service.appReview => 'app_review_service.dart',
        Service.eventBus => 'event_bus_service.dart',
        Service.remoteConfig => 'remote_config_service.dart',
      };

  /// Its folder under `lib/services/`, e.g. `force_update`.
  String get folderName => switch (this) {
        Service.secureSession => 'secure_session',
        Service.connectivity => 'connectivity',
        Service.deviceInfo => 'device',
        Service.accessibility => 'accessibility',
        Service.logger => 'logging',
        Service.crashReporting => 'crash_reporting',
        Service.notification => 'notification',
        Service.deeplink => 'deeplink',
        Service.analytics => 'analytics',
        Service.forceUpdate => 'force_update',
        Service.appReview => 'app_review',
        Service.eventBus => 'event_bus',
        Service.remoteConfig => 'remote_config',
      };

  /// The generated class's name, e.g. `ForceUpdateService`.
  String get className => switch (this) {
        Service.secureSession => 'SecureSessionManager',
        Service.connectivity => 'ConnectivityMonitor',
        Service.deviceInfo => 'DeviceInfoService',
        Service.accessibility => 'AccessibilityService',
        Service.logger => 'DebugLogger',
        Service.crashReporting => 'CrashReportingService',
        Service.notification => 'NotificationService',
        Service.deeplink => 'DeeplinkService',
        Service.analytics => 'AnalyticsService',
        Service.forceUpdate => 'ForceUpdateService',
        Service.appReview => 'AppReviewService',
        Service.eventBus => 'EventBusService',
        Service.remoteConfig => 'RemoteConfigService',
      };

  /// One sentence describing what the service is for.
  String get purpose => switch (this) {
        Service.secureSession =>
          'Application-level boundary for secure session/token storage.',
        Service.connectivity =>
          'Application-level boundary for network connectivity awareness.',
        Service.deviceInfo =>
          'Application-level boundary for device/platform information.',
        Service.accessibility =>
          'Application-level boundary for accessibility (screen reader, '
              'text scale, reduced motion) awareness.',
        Service.logger =>
          'Application-level boundary for structured debug logging.',
        Service.crashReporting =>
          'Application-level boundary for crash/error reporting.',
        Service.notification =>
          'Application-level boundary for push notifications.',
        Service.deeplink =>
          'Application-level boundary for deep link handling.',
        Service.analytics =>
          'Application-level boundary for product analytics.',
        Service.forceUpdate =>
          'Application-level boundary for minimum-version enforcement.',
        Service.appReview =>
          'Application-level boundary for requesting an in-app review.',
        Service.eventBus =>
          'In-memory, typed publish/subscribe for application events.',
        Service.remoteConfig =>
          'Application-level boundary for remote configuration (feature '
              'flags, dynamic values) with local defaults.',
      };

  /// Whether the generated service has an `initialize()` the app's
  /// bootstrap calls at startup.
  bool get hasInitialize =>
      this != Service.logger &&
      this != Service.deviceInfo &&
      this != Service.appReview &&
      this != Service.eventBus;
}
