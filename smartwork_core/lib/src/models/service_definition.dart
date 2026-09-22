enum Service {
  secureSession,
  connectivity,
  deviceInfo,
  accessibility,
  logger,
  crashReporting,
  notification,
  deeplink,
  analytics,
  forceUpdate,
  appReview,
  eventBus,
  remoteConfig,
}

enum ServiceCategory {
  security,
  deviceRuntime,
  diagnostics,
  applicationIntegration,
}

extension ServiceCategoryLabel on ServiceCategory {
  String get displayName => switch (this) {
        ServiceCategory.security => 'Security',
        ServiceCategory.deviceRuntime => 'Device / Runtime',
        ServiceCategory.diagnostics => 'Diagnostics',
        ServiceCategory.applicationIntegration => 'Application Integration',
      };
}

extension ServiceDefinition on Service {
  String get id => name;

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

  bool get hasInitialize =>
      this != Service.logger &&
      this != Service.deviceInfo &&
      this != Service.appReview &&
      this != Service.eventBus;
}
