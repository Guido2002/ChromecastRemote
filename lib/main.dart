import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'features/discovery/presentation/devices_screen.dart';
import 'shared/presentation/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
