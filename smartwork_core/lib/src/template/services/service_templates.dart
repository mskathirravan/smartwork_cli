import '../../models/project_config.dart';
import '../../models/service_definition.dart';
import '../template.dart';
import '../template_engine.dart';
import 'definitions/accessibility_templates.dart';
import 'definitions/analytics_templates.dart';
import 'definitions/app_review_templates.dart';
import 'definitions/connectivity_templates.dart';
import 'definitions/crash_reporting_templates.dart';
import 'definitions/deeplink_templates.dart';
import 'definitions/device_info_templates.dart';
import 'definitions/event_bus_templates.dart';
import 'definitions/force_update_templates.dart';
import 'definitions/logger_templates.dart';
import 'definitions/notification_templates.dart';
import 'definitions/remote_config_templates.dart';
import 'definitions/secure_session_templates.dart';

class ServiceTemplates {
  static String serviceSource(Service service) {
    return switch (service) {
      Service.secureSession => secureSessionManagerSource(),
      Service.connectivity => connectivityMonitorSource(),
      Service.deviceInfo => deviceInfoServiceSource(),
      Service.accessibility => accessibilityServiceSource(),
      Service.logger => debugLoggerSource(),
      Service.crashReporting => crashReportingServiceSource(),
      Service.notification => notificationServiceSource(),
      Service.deeplink => deeplinkServiceSource(),
      Service.analytics => analyticsServiceSource(),
      Service.forceUpdate => forceUpdateServiceSource(),
      Service.appReview => appReviewServiceSource(),
      Service.eventBus => eventBusServiceSource(),
      Service.remoteConfig => remoteConfigServiceSource(),
    };
  }

  static String serviceTestSource(
    Service service,
    String projectName, {
    required Storage storage,
  }) {
    final source = switch (service) {
      Service.secureSession =>
        secureSessionManagerTestSource(projectName, storage),
      Service.connectivity => connectivityMonitorTestSource(projectName),
      Service.deviceInfo => deviceInfoServiceTestSource(projectName),
      Service.accessibility => accessibilityServiceTestSource(projectName),
      Service.logger => debugLoggerTestSource(projectName),
      Service.crashReporting => crashReportingServiceTestSource(projectName),
      Service.notification => notificationServiceTestSource(projectName),
      Service.deeplink => deeplinkServiceTestSource(projectName),
      Service.analytics => analyticsServiceTestSource(projectName),
      Service.forceUpdate => forceUpdateServiceTestSource(projectName),
      Service.appReview => appReviewServiceTestSource(projectName),
      Service.eventBus => eventBusServiceTestSource(projectName),
      Service.remoteConfig => remoteConfigServiceTestSource(projectName),
    };
    return TemplateEngine().render(Template(content: source), const {});
  }

  static String barrel(List<Service> orderedServices) {
    final buffer = StringBuffer()
      ..writeln("export 'bootstrap/bootstrap.dart';")
      ..writeln("export 'network/network_service.dart';")
      ..writeln("export 'routing/app_router.dart';")
      ..writeln("export 'storage/storage_service.dart';")
      ..writeln("export 'theme/theme_service.dart';");
    for (final service in orderedServices) {
      buffer.writeln("export '${service.folderName}/${service.fileName}';");
    }
    return buffer.toString();
  }
}
