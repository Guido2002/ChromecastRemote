import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'features/discovery/presentation/devices_screen.dart';
import 'shared/presentation/app_motion.dart';
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: -110,
            bottom: -130,
            child: _GlowOrb(size: 290, color: colors.primary),
          ),
          Positioned(
            right: -85,
            top: -100,
            child: _GlowOrb(size: 220, color: colors.primary),
          ),
          Center(
            child: MotionEntrance(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/branding/app_icon.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chromecast Remote',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Control Google TV and Chromecast devices',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.34), Colors.transparent],
        ),
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

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
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/branding/app_icon.png',
                  width: 72,
                  height: 72,
                ),
              ),
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
