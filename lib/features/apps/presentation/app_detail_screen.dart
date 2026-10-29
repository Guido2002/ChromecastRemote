import 'package:flutter/material.dart';

import '../../../shared/presentation/adaptive_layout.dart';
import '../app_shortcut_store.dart';
import '../tv_app.dart';
import 'tv_app_icon.dart';

class AppDetailScreen extends StatefulWidget {
  const AppDetailScreen({
    required this.app,
    required this.store,
    required this.onChooseDevice,
    this.connectedDeviceName,
    this.onLaunchApp,
    super.key,
  });

  final TvApp app;
  final AppShortcutStore store;
  final VoidCallback onChooseDevice;
  final String? connectedDeviceName;
  final Future<bool> Function(TvApp app)? onLaunchApp;

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  bool? _favorite;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final selected = await widget.store.loadSelectedIds();
    if (mounted) setState(() => _favorite = selected.contains(widget.app.id));
  }

  Future<void> _toggleFavorite() async {
    final selected = await widget.store.loadSelectedIds();
    final favorite = !selected.contains(widget.app.id);
    favorite ? selected.add(widget.app.id) : selected.remove(widget.app.id);
    setState(() => _favorite = favorite);
    await widget.store.saveSelectedIds(selected);
  }

  Future<void> _openOnTv() async {
    final launch = widget.onLaunchApp;
    if (launch == null || widget.connectedDeviceName == null) {
      if (launch != null) {
        await launch(widget.app);
        if (mounted) Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop();
        widget.onChooseDevice();
      }
      return;
    }
    setState(() => _launching = true);
    var launched = false;
    try {
      launched = await launch(widget.app);
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    setState(() => _launching = false);
    if (launched) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open ${widget.app.name}. Reconnect to your TV and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('App details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AdaptiveLayout.pagePadding(context),
          child: AdaptiveContent(
            maxWidth: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(child: TvAppIcon(app: app, size: 104, borderRadius: 24)),
                const SizedBox(height: 18),
                Text(
                  app.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _categoryLabel(app.category),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _launching ? null : _openOnTv,
                  icon: _launching
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    widget.connectedDeviceName == null
                        ? 'Choose a TV'
                        : 'Open on ${widget.connectedDeviceName}',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _favorite == null ? null : _toggleFavorite,
                  icon: Icon(
                    _favorite == true
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                  label: Text(
                    _favorite == true
                        ? 'Remove from remote shortcuts'
                        : 'Add to remote shortcuts',
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'SHORTCUT DETAILS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: _categoryLabel(app.category),
                      ),
                      const Divider(height: 1, indent: 56),
                      _DetailRow(
                        icon: Icons.android_rounded,
                        label: 'TV package',
                        value: app.packageName ?? 'Link only',
                      ),
                      const Divider(height: 1, indent: 56),
                      _DetailRow(
                        icon: app.requiresStoreOpenConfirmation
                            ? Icons.storefront_outlined
                            : Icons.link_rounded,
                        label: 'Launch method',
                        value: app.requiresStoreOpenConfirmation
                            ? 'Play Store link · select Open on TV if needed'
                            : 'Direct app link',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Opening requires a connected Google TV or Android TV. '
                  'Available playback controls depend on the foreground app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

String _categoryLabel(TvAppCategory category) => switch (category) {
  TvAppCategory.movies => 'Movies & TV',
  TvAppCategory.music => 'Music',
  TvAppCategory.gaming => 'Gaming',
  TvAppCategory.kids => 'Kids',
  TvAppCategory.other => 'Other',
};
