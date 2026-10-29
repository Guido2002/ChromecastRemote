import 'dart:io';
import 'dart:async';
import 'shared/presentation/remote_haptics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'features/discovery/presentation/devices_screen.dart';
import 'shared/presentation/app_theme.dart';
import 'features/diagnostics/local_diagnostics.dart';

void main() {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => LocalDiagnostics.instance.record(
      RemoteMetric.firstFrame,
      startup.elapsed,
      success: true,
    ),
  );
  unawaited(RemoteHaptics.instance.load());
  runApp(const ChromecastRemoteApp());
}

class ChromecastRemoteApp extends StatefulWidget {
  const ChromecastRemoteApp({super.key});

  @override
  State<ChromecastRemoteApp> createState() => _ChromecastRemoteAppState();
}

class _ChromecastRemoteAppState extends State<ChromecastRemoteApp> {
  late Future<void> _castInitialization;

  @override
  void initState() {
    super.initState();
    _castInitialization = _initializeCast();
  }

  Future<void> _initializeCast() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Chromecast Remote supports Android and iOS.');
    }

    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    final GoogleCastOptions options;
    if (Platform.isIOS) {
      options = IOSGoogleCastOptions(
        GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
      );
    } else {
      options = GoogleCastOptionsAndroid(appId: appId);
    }

    await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
  }

  void _retryInitialization() {
    setState(() => _castInitialization = _initializeCast());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chromecast Remote',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: FutureBuilder<void>(
        future: _castInitialization,
        builder: (context, snapshot) {
          return DevicesScreen(
            castAvailable:
                snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError,
            castInitializing: snapshot.connectionState != ConnectionState.done,
            onRetryCast: _retryInitialization,
          );
        },
      ),
    );
  }
}
