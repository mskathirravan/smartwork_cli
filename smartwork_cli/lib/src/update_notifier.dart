import 'dart:convert';
import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

/// Tells the developer when a newer smartwork_cli is on pub.dev.
///
/// pub.dev is asked at most once per [checkInterval]; the answer is cached
/// in [cacheFile], so most commands never touch the network and an offline
/// run still shows a notice already known about. Every failure (offline,
/// unreadable cache, unparsable version) means "no notice", never an error.
class UpdateNotifier {
  static const checkInterval = Duration(hours: 24);

  final String currentVersion;
  final File? cacheFile;
  final VersionFetcher _fetchLatest;
  final DateTime Function() _now;

  UpdateNotifier({
    required this.currentVersion,
    File? cacheFile,
    VersionFetcher? fetchLatest,
    DateTime Function()? now,
  })  : cacheFile = cacheFile ?? _defaultCacheFile(),
        _fetchLatest = fetchLatest ?? VersionResolver.fetchFromPubDev,
        _now = now ?? DateTime.now;

  /// The notice to print, or null when this CLI is up to date (or the
  /// latest version can't be determined).
  Future<String?> check() async {
    try {
      final latest = await _latestVersion();
      if (latest == null || !isNewer(latest, than: currentVersion)) {
        return null;
      }
      return 'A new version of SmartWork is available: $currentVersion → '
          '$latest\n'
          'Run "smartwork update" to update.';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _latestVersion() async {
    final cached = _readCache();
    if (cached != null && _now().difference(cached.checkedAt) < checkInterval) {
      return cached.latest;
    }

    final latest = await _fetchLatest('smartwork_cli');
    if (latest == null) return cached?.latest;
    _writeCache(latest);
    return latest;
  }

  ({DateTime checkedAt, String latest})? _readCache() {
    final file = cacheFile;
    if (file == null || !file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return (
        checkedAt: DateTime.parse(json['checkedAt'] as String),
        latest: json['latest'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  void _writeCache(String latest) {
    final file = cacheFile;
    if (file == null) return;
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode({
        'checkedAt': _now().toIso8601String(),
        'latest': latest,
      }));
    } catch (_) {
      // A read-only home directory just means checking again next time.
    }
  }

  /// Whether stable version [candidate] is newer than [current], comparing
  /// major.minor.patch. A pre-release [candidate] is never offered.
  static bool isNewer(String candidate, {required String than}) {
    if (candidate.contains('-')) return false;
    final a = _parts(candidate);
    final b = _parts(than);
    if (a == null || b == null) return false;
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    // Same major.minor.patch: a stable release is newer than a
    // pre-release of it (1.0.3 > 1.0.3-dev.1).
    return than.contains('-');
  }

  static List<int>? _parts(String version) {
    final core = version.split(RegExp(r'[-+]')).first.split('.');
    if (core.length != 3) return null;
    final parts = core.map(int.tryParse).toList();
    return parts.contains(null) ? null : parts.cast<int>();
  }

  static File? _defaultCacheFile() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return null;
    return File('$home/.smartwork/update_check.json');
  }
}
