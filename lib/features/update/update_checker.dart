import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Information about the latest published GitHub release.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.name,
    required this.url,
  });

  /// Version parsed from the release tag (leading "v" stripped).
  final String version;

  /// Release title, e.g. "v0.2.0".
  final String name;

  /// Web page of the release, where the APK can be downloaded.
  final Uri url;
}

/// Outcome of an update check.
sealed class UpdateCheckResult {}

/// A newer release exists on GitHub.
class UpdateAvailable extends UpdateCheckResult {
  UpdateAvailable(this.release);

  final AppRelease release;
}

/// The installed version is the latest published release.
class UpToDate extends UpdateCheckResult {}

/// The repository has no published releases yet.
class NoReleasesPublished extends UpdateCheckResult {}

/// The check could not be completed (network, rate limit, bad response).
class UpdateCheckFailed extends UpdateCheckResult {
  UpdateCheckFailed(this.message);

  final String message;
}

/// Parses the GitHub `releases/latest` API response. Pure for testability.
AppRelease parseLatestRelease(Map<String, dynamic> json) {
  final tag = json['tag_name'];
  final htmlUrl = json['html_url'];
  if (tag is! String || tag.isEmpty || htmlUrl is! String || htmlUrl.isEmpty) {
    throw const FormatException('GitHub release response is missing fields.');
  }
  return AppRelease(
    version: tag.startsWith('v') ? tag.substring(1) : tag,
    name: (json['name'] as String?)?.isNotEmpty == true
        ? json['name'] as String
        : tag,
    url: Uri.parse(htmlUrl),
  );
}

/// Returns true when [latest] is a higher semantic version than [current].
///
/// Build metadata (`+1`) and pre-release suffixes are ignored; missing
/// segments count as zero ("0.2" equals "0.2.0").
bool isNewerVersion(String latest, String current) {
  List<int> parts(String version) => version
      .split('+')
      .first
      .split('-')
      .first
      .split('.')
      .map((segment) => int.tryParse(segment) ?? 0)
      .toList();

  final latestParts = parts(latest);
  final currentParts = parts(current);
  final length = latestParts.length > currentParts.length
      ? latestParts.length
      : currentParts.length;
  for (var i = 0; i < length; i++) {
    final l = i < latestParts.length ? latestParts[i] : 0;
    final c = i < currentParts.length ? currentParts[i] : 0;
    if (l != c) return l > c;
  }
  return false;
}

/// Checks GitHub Releases for a newer version of the app.
class UpdateChecker {
  UpdateChecker({
    this.owner = 'Guido2002',
    this.repository = 'ChromecastRemote',
    HttpClient Function()? httpClientFactory,
    this.timeout = const Duration(seconds: 10),
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final String owner;
  final String repository;
  final HttpClient Function() _httpClientFactory;
  final Duration timeout;

  /// Compares the latest GitHub release against [currentVersion].
  Future<UpdateCheckResult> checkForUpdate(String currentVersion) async {
    final client = _httpClientFactory();
    try {
      final request = await client
          .getUrl(Uri.parse(
              'https://api.github.com/repos/$owner/$repository/releases/latest'))
          .timeout(timeout);
      // GitHub requires a User-Agent header on API calls.
      request.headers.set(HttpHeaders.userAgentHeader, '$repository-android');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');

      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 404) return NoReleasesPublished();
      if (response.statusCode != 200) {
        return UpdateCheckFailed(
          'GitHub returned status ${response.statusCode}.',
        );
      }

      final release = parseLatestRelease(
        jsonDecode(body) as Map<String, dynamic>,
      );
      return isNewerVersion(release.version, currentVersion)
          ? UpdateAvailable(release)
          : UpToDate();
    } on TimeoutException {
      return UpdateCheckFailed('GitHub did not respond in time.');
    } on SocketException {
      return UpdateCheckFailed('No internet connection.');
    } on FormatException {
      return UpdateCheckFailed('Unexpected response from GitHub.');
    } catch (error) {
      return UpdateCheckFailed('$error');
    } finally {
      client.close();
    }
  }
}
