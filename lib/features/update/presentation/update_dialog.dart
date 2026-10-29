import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../apk_installer.dart';
import '../update_checker.dart';

/// Dialog shown when a newer GitHub release exists.
///
/// On Android with an APK attached to the release, the app downloads it with
/// a progress indicator and hands it to the system package installer. The OS
/// still asks the user to confirm the install and, once, to allow installs
/// from this app — that cannot be bypassed. On other platforms or releases
/// without an APK, the release page opens in the browser instead.
class UpdateAvailableDialog extends StatefulWidget {
  const UpdateAvailableDialog({
    required this.release,
    required this.currentVersion,
    super.key,
  });

  final AppRelease release;
  final String currentVersion;

  @override
  State<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<UpdateAvailableDialog> {
  final _installer = ApkInstaller();

  bool _downloading = false;
  bool _installerLaunched = false;
  double? _progress;
  String? _error;

  bool get _canInstallInApp =>
      Platform.isAndroid && widget.release.apkAsset != null;

  Future<void> _downloadAndInstall() async {
    final asset = widget.release.apkAsset;
    if (asset == null) return;
    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });
    try {
      final file = await _installer.download(
        asset,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      final launch = await _installer.launchInstall(file);
      if (!mounted) return;
      if (launch.launched) {
        setState(() {
          _downloading = false;
          _installerLaunched = true;
        });
      } else {
        setState(() {
          _downloading = false;
          _error =
              'Android could not open the installer (${launch.detail}). '
              'Allow installs from this app in Settings, or use '
              '"View on GitHub".';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download failed: $error';
        });
      }
    }
  }

  void _openInBrowser() {
    unawaited(
      launchUrl(widget.release.url, mode: LaunchMode.externalApplication),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final release = widget.release;

    return AlertDialog(
      icon: const Icon(Icons.system_update_alt),
      title: Text('Update available: ${release.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _canInstallInApp
                ? 'You are running ${widget.currentVersion}. The update is '
                      'downloaded in the app. Android will ask you to confirm '
                      'installation and may require permission to install updates.'
                : 'You are running ${widget.currentVersion}. Download the '
                      'latest APK from GitHub Releases and install it over the '
                      'current app.',
          ),
          if (_canInstallInApp && release.apkAsset!.sizeBytes > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Download size: ${_formatBytes(release.apkAsset!.sizeBytes)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              _progress == null
                  ? 'Downloading update…'
                  : 'Downloading update… ${(_progress! * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_installerLaunched) ...[
            const SizedBox(height: 20),
            Text(
              'Confirm the installation in the Android installer. If Android '
              'says "App not installed", the update was signed with a '
              'different key than the installed app. Keep your installed '
              'app and use a release signed with the matching key to preserve '
              'your saved TVs.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        TextButton(
          onPressed: _downloading ? null : _openInBrowser,
          child: const Text('View on GitHub'),
        ),
        if (_canInstallInApp)
          FilledButton.icon(
            onPressed: _downloading ? null : _downloadAndInstall,
            icon: const Icon(Icons.download),
            label: Text(_downloading ? 'Downloading…' : 'Download & install'),
          ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
