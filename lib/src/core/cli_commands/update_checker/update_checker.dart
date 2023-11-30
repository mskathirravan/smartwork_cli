import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../utils/log_utils.dart';

class UpdateChecker {
  static void checkForUpdates() async {
    final currentVersion = await getCurrentVersion();
    final latestVersion = await getLatestVersion();

    if (latestVersion != null && latestVersion.compareTo(currentVersion) > 0) {
      LogService.info('A newer version is available: $latestVersion');
      // Add your update logic here
    } else {
      LogService.success('You have the latest version: $currentVersion');
    }
  }

  static Future<String> getCurrentVersion() async {
    // Fetch the version from pubspec.yaml
    final pubspecContent = File('pubspec.yaml').readAsStringSync();
    final versionMatch = RegExp(r'version: (.+)').firstMatch(pubspecContent);
    return versionMatch?.group(1) ?? 'Unknown';
  }

  static Future<String?> getLatestVersion() async {
    try {
      final response = await http
          .get(Uri.parse('https://pub.dev/api/packages/smartwork_cli'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> packageInfo =
            Map<String, dynamic>.from(json.decode(response.body));
        return packageInfo['latest']['version'] as String;
      }
    } catch (e) {
      LogService.error('Error fetching the latest version: $e');
    }
    return null;
  }
}
