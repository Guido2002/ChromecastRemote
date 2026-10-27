import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../update_checker.dart';
import 'update_dialog.dart';

/// Runs a GitHub release check and surfaces the result.
///
/// [userInitiated] checks always show the outcome (including "up to date"
/// and failures). Automatic checks stay silent unless an update is available.
Future<void> checkForAppUpdate(
  BuildContext context, {
  required bool userInitiated,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (userInitiated) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Checking GitHub for the latest version…'),
        duration: Duration(seconds: 2),
      ));
  }

  final String currentVersion;
  try {
    currentVersion = (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    if (userInitiated && context.mounted) {
      _showMessage(context, 'Could not read the installed app version.');
    }
    return;
  }

  final result = await UpdateChecker().checkForUpdate(currentVersion);
  if (!context.mounted) return;

  switch (result) {
    case UpdateAvailable(:final release):
      await showDialog<void>(
        context: context,
        builder: (context) => UpdateAvailableDialog(
          release: release,
          currentVersion: currentVersion,
        ),
      );
    case UpToDate():
      if (userInitiated) {
        _showMessage(context, 'You are on the latest version ($currentVersion).');
      }
    case NoReleasesPublished():
      if (userInitiated) {
        _showMessage(
          context,
          'No releases have been published on GitHub yet.',
        );
      }
    case UpdateCheckFailed(:final message):
      if (userInitiated) {
        _showMessage(context, 'Update check failed: $message');
      }
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
