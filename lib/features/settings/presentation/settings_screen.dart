import 'package:flutter/material.dart';
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
    final colors = Theme.of(context).colorScheme;
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
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Appearance'),
                    subtitle: const Text('Dark, optimized for remotes'),
                    trailing: Text(
                      'System',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
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
