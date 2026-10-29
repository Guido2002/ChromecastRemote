import 'dart:async';

import '../remote/remote_controller.dart';
import 'tv_app.dart';

abstract interface class AppLaunchTarget implements RemoteController {
  String? get currentApp;
  Stream<String> get currentAppUpdates;
  void launchAppLink(String link);
}

enum AppLaunchOutcome {
  confirmed,
  unconfirmed,
  failed,
  cancelled;

  String message(String app, String device) => switch (this) {
    confirmed => '$app is active on $device.',
    unconfirmed =>
      'Launch requested for $app on $device. The TV has not confirmed it. If a store page appears, choose Open on the TV.',
    failed => 'Could not request $app. Reconnect to $device and try again.',
    cancelled => 'Launch cancelled because the TV connection changed.',
  };
}

/// A transmitted link is a request. Only a matching foreground package
/// confirms an active app; it never confirms playback of specific content.
Future<AppLaunchOutcome> launchTvApp(
  AppLaunchTarget target,
  TvApp app, {
  required bool Function() isCurrentTarget,
  Duration confirmationTimeout = const Duration(seconds: 4),
}) async {
  bool available() =>
      isCurrentTarget() &&
      target.connectionState == RemoteConnectionState.connected &&
      target.capabilities.contains(RemoteCapability.appLaunch);
  if (!available()) return AppLaunchOutcome.failed;
  final result = Completer<AppLaunchOutcome>();
  void finish(AppLaunchOutcome outcome) {
    if (!result.isCompleted) result.complete(outcome);
  }

  final apps = target.currentAppUpdates.listen((package) {
    if (!available()) {
      finish(AppLaunchOutcome.cancelled);
    } else if (app.packageName != null && package == app.packageName) {
      finish(AppLaunchOutcome.confirmed);
    }
  });
  final connection = target.connectionStates.listen((state) {
    if (state != RemoteConnectionState.connected || !isCurrentTarget()) {
      finish(AppLaunchOutcome.cancelled);
    }
  });
  final timer = Timer(
    confirmationTimeout,
    () => finish(
      available() ? AppLaunchOutcome.unconfirmed : AppLaunchOutcome.cancelled,
    ),
  );
  try {
    target.launchAppLink(app.launchUrl);
    if (app.packageName != null && target.currentApp == app.packageName) {
      finish(AppLaunchOutcome.confirmed);
    }
    return await result.future;
  } catch (_) {
    return AppLaunchOutcome.failed;
  } finally {
    timer.cancel();
    await apps.cancel();
    await connection.cancel();
  }
}
