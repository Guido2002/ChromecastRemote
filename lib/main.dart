import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'features/discovery/presentation/devices_screen.dart';

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
    // Palette follows the reference remote design: near-black background
    // (#202124), dark gray controls, restrained accent.
    const background = Color(0xFF202124);
    const surface = Color(0xFF2F3133);
    const accent = Color(0xFF8DAAFF);

    return MaterialApp(
      title: 'Chromecast Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: Color(0xFF101A35),
          secondary: Color(0xFF8CE4D0),
          surface: background,
          onSurface: Color(0xFFF0F3FA),
          onSurfaceVariant: Color(0xFFA8B0C0),
          error: Color(0xFFFF7B82),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF28292B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3C4043)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _castInitialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StartupError(
              error: snapshot.error,
              onRetry: _retryInitialization,
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StartupLoading();
          }
          return const DevicesScreen();
        },
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Starting Chromecast Remote…'),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cast_connected, size: 48),
              const SizedBox(height: 20),
              Text(
                'Could not start Chromecast Remote',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
