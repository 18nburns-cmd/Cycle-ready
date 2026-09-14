import 'dart:convert';

import 'package:cycle_ready/src/features/updates/domain/app_release.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class GithubAppReleaseRepository implements AppReleaseRepository {
  GithubAppReleaseRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static final _endpoint = Uri.https(
    'api.github.com',
    '/repos/18nburns-cmd/Cycle-ready/releases/latest',
  );

  @override
  Future<AppRelease> check() async {
    final response = await _client.get(_endpoint, headers: const {
      'accept': 'application/vnd.github+json'
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Update check failed with HTTP ${response.statusCode}.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final assets = (json['assets'] as List? ?? const [])
        .whereType<Map>()
        .map((asset) => Map<String, dynamic>.from(asset))
        .toList();
    final apk = assets.cast<Map<String, dynamic>?>().firstWhere(
          (asset) => '${asset?['name']}'.toLowerCase().endsWith('.apk'),
          orElse: () => null,
        );
    final url = Uri.tryParse('${apk?['browser_download_url'] ?? ''}');
    if (url == null || url.scheme != 'https') {
      throw const FormatException('Latest release has no secure APK asset.');
    }
    final package = await PackageInfo.fromPlatform();
    return AppRelease(
      currentVersion: package.version,
      latestVersion: '${json['tag_name']}',
      downloadUrl: url,
    );
  }
}
