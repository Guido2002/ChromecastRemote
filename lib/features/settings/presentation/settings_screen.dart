import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../shared/presentation/adaptive_layout.dart';
import '../../update/presentation/update_actions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: const SafeArea(child: SettingsView()),
  );
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AdaptiveLayout.pagePadding(context),
      child: AdaptiveContent(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(label: 'GENERAL'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (Platform.isAndroid) ...[
                    ListTile(
                      leading: const Icon(Icons.bolt_outlined),
                      title: const Text('Quick access'),
                      subtitle: const Text(
                        'Add TV remote to Quick Settings or long-press the launcher icon.',
                      ),
                      onTap: () async {
                        try {
                          await const MethodChannel(
                            'chromecast_remote/navigation',
                          ).invokeMethod<int>('addQuickSettingsTile');
                        } on PlatformException {
                          /* Instructions below cover unsupported launchers. */
                        } on MissingPluginException {
                          /* Other builds can follow the manual instructions. */
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'You can also edit Quick Settings and add TV remote, or long-press the app icon for its remote shortcut.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                  ],
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Connection help'),
                    subtitle: const Text(
                      'Find a missing TV or recover a connection.',
                    ),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) => const SafeArea(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Find and reconnect your TV',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '1. Check that your TV is powered on and connected to the same Wi-Fi as your phone.',
                              ),
                              SizedBox(height: 12),
                              Text(
                                '2. Allow local network access if your phone asks. Guest Wi-Fi and network isolation can prevent discovery.',
                              ),
                              SizedBox(height: 12),
                              Text(
                                '3. Refresh Devices, then select the saved TV again. This checks its current network address.',
                              ),
                              SizedBox(height: 12),
                              Text(
                                '4. If the TV no longer trusts the connection, use Pair again in Remote options and enter its new code.',
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Choose TV remote for navigation and apps. Cast playback only controls compatible media sessions. Power and volume depend on your TV and audio setup.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.system_update_alt_rounded),
                    title: const Text('Check for updates'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        checkForAppUpdate(context, userInitiated: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel(label: 'ABOUT'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) => ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/branding/app_icon.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                      title: const Text('Chromecast Remote'),
                      subtitle: Text(
                        snapshot.hasData
                            ? 'Version ${snapshot.data!.version}'
                            : 'Version…',
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.code_rounded),
                    title: const Text('Open-source licenses'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Chromecast Remote',
                      applicationIcon: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/branding/app_icon.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}
