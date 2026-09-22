import 'dart:convert';
import 'dart:io';

typedef VersionFetcher = Future<String?> Function(String package);

class VersionResolver {
  static VersionResolver shared = VersionResolver();

  final VersionFetcher _fetch;
  final Map<String, String> _cache = {};

  VersionResolver({VersionFetcher? fetch}) : _fetch = fetch ?? fetchFromPubDev;

  Future<String> resolve(String package, String fallback) async {
    final cached = _cache[package];
    if (cached != null) return cached;

    var resolved = fallback;
    try {
      final latest = await _fetch(package);
      if (latest != null) resolved = '^$latest';
    } catch (_) {
      resolved = fallback;
    }

    _cache[package] = resolved;
    return resolved;
  }

  static Future<String?> fetchFromPubDev(String package) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.https('pub.dev', '/api/packages/$package'))
          .timeout(const Duration(seconds: 2));
      final response =
          await request.close().timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 2));
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final latest = json['latest'];
      if (latest is! Map<String, dynamic>) return null;
      final version = latest['version'];
      return version is String ? version : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
