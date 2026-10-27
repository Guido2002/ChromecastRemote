import 'dart:async';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

/// Whether the system package installer could be opened, with the platform's
/// detail message for failures.
class InstallLaunchResult {
  const InstallLaunchResult({required this.launched, required this.detail});

  final bool launched;
  final String detail;
}

/// Downloads the release APK to local storage and hands it to Android's
/// package installer.
///
/// Android still requires the user to confirm the install and to grant this
/// app the "install unknown apps" permission once; both prompts are part of
/// the OS and cannot be bypassed. The update APK must be signed with the same
/// key as the installed app, otherwise Android refuses the install.
class ApkInstaller {
  ApkInstaller({HttpClient Function()? httpClientFactory})
      : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const _apkMimeType = 'application/vnd.android.package-archive';

  final HttpClient Function() _httpClientFactory;

  /// Downloads [asset] to a temporary file, reporting progress as a value
  /// between 0 and 1 (null when the server does not send a content length).
  Future<File> download(
    ApkAsset asset, {
    void Function(double? progress)? onProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/update-${asset.name}');

    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(asset.downloadUrl).timeout(timeout);
      request.headers
          .set(HttpHeaders.userAgentHeader, 'ChromecastRemote-updater');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed with status ${response.statusCode}.',
          uri: asset.downloadUrl,
        );
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : (asset.sizeBytes > 0 ? asset.sizeBytes : null);
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(timeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress
              ?.call(total == null || total == 0 ? null : received / total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // Guard against truncated downloads when the length is known.
      if (total != null && received != total) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup of the partial file.
        }
        throw HttpException(
          'Incomplete download ($received of $total bytes).',
          uri: asset.downloadUrl,
        );
      }
      return file;
    } finally {
      client.close();
    }
  }

  /// Opens Android's package installer for [file]. The user must confirm the
  /// installation. Note the platform only reports whether the installer was
  /// *launched* — it cannot report whether the user actually installed.
  Future<InstallLaunchResult> launchInstall(File file) async {
    final result = await OpenFilex.open(file.path, type: _apkMimeType);
    return InstallLaunchResult(
      launched: result.type == ResultType.done,
      detail: result.message,
    );
  }

  /// Removes a previously downloaded update file.
  Future<void> discard(File file) async {
    if (await file.exists()) await file.delete();
  }
}
