import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/adaptive_layout.dart';
import '../../../shared/presentation/app_motion.dart';
import '../app_shortcut_store.dart';
import '../tv_app.dart';
import 'tv_app_icon.dart';

/// Horizontally scrolling app shortcuts that launch apps on the TV.
///
/// The shortcut matching the foreground app reported by the TV is
/// highlighted. An edit affordance opens the manage sheet (catalog toggles
/// and custom entries).
class AppShortcutsSection extends StatefulWidget {
  const AppShortcutsSection({
    required this.store,
    required this.enabled,
    required this.onLaunch,
    required this.activePackage,
    super.key,
  });

  final AppShortcutStore store;
  final bool enabled;
  final ValueChanged<TvApp> onLaunch;

  /// Package name of the app currently in the foreground on the TV.
  final String? activePackage;

  @override
  State<AppShortcutsSection> createState() => _AppShortcutsSectionState();
}

class _AppShortcutsSectionState extends State<AppShortcutsSection> {
  List<TvApp> _shortcuts = const [];
  String? _launchingId;
  Timer? _launchFeedbackTimer;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final shortcuts = await widget.store.loadShortcuts();
    if (mounted) setState(() => _shortcuts = shortcuts);
  }

  void _launch(TvApp app) {
    HapticFeedback.lightImpact();
    setState(() => _launchingId = app.id);
    widget.onLaunch(app);
    _launchFeedbackTimer?.cancel();
    _launchFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _launchingId = null);
    });
  }

  @override
  void dispose() {
    _launchFeedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _manage() async {
    final tablet = AdaptiveLayout.isTablet(context);
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: tablet,
      constraints: tablet ? const BoxConstraints(maxWidth: 680) : null,
      builder: (_) => _ManageShortcutsSheet(store: widget.store),
    );
    if (changed == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tablet = AdaptiveLayout.isTablet(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'APPS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Manage app shortcuts',
              onPressed: _manage,
              icon: const Icon(Icons.edit_outlined, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        SizedBox(
          height: tablet ? 100 : 84,
          child: _shortcuts.isEmpty
              ? Center(
                  child: Text(
                    'No app shortcuts yet — tap the pencil to add some.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _shortcuts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final app = _shortcuts[index];
                    final isActive =
                        app.packageName != null &&
                        app.packageName == widget.activePackage;
                    return _AppShortcutButton(
                      app: app,
                      enabled: widget.enabled,
                      active: isActive,
                      tablet: tablet,
                      launchPending: _launchingId == app.id,
                      onTap: () => _launch(app),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AppShortcutButton extends StatelessWidget {
  const _AppShortcutButton({
    required this.app,
    required this.enabled,
    required this.active,
    required this.tablet,
    required this.launchPending,
    required this.onTap,
  });

  final TvApp app;
  final bool enabled;
  final bool active;
  final bool tablet;
  final bool launchPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: launchPending
          ? 'Opening ${app.name}…'
          : active
          ? '${app.name} (active on TV)'
          : app.name,
      child: AnimatedScale(
        scale: launchPending ? 0.96 : 1,
        duration: AppMotion.quick,
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          overlayColor: WidgetStatePropertyAll(
            colors.primary.withValues(alpha: 0.1),
          ),
          child: AnimatedContainer(
            width: tablet ? 88 : 72,
            duration: AppMotion.standard,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: active
                  ? colors.primaryContainer
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? colors.primary : colors.outlineVariant,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.standard,
                  child: launchPending
                      ? Icon(
                          Icons.check_rounded,
                          key: const ValueKey('sent'),
                          color: colors.secondary,
                          size: tablet ? 30 : 26,
                        )
                      : Opacity(
                          key: ValueKey('app-icon-${app.id}'),
                          opacity: enabled ? 1 : 0.42,
                          child: TvAppIcon(
                            app: app,
                            size: tablet ? 40 : 34,
                            borderRadius: tablet ? 12 : 10,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: enabled
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to toggle catalog apps and manage custom entries.
class _ManageShortcutsSheet extends StatefulWidget {
  const _ManageShortcutsSheet({required this.store});

  final AppShortcutStore store;

  @override
  State<_ManageShortcutsSheet> createState() => _ManageShortcutsSheetState();
}

class _ManageShortcutsSheetState extends State<_ManageShortcutsSheet> {
  Set<String> _selected = {};
  List<TvApp> _custom = const [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selected = await widget.store.loadSelectedIds();
    final custom = await widget.store.loadCustomApps();
    if (mounted) {
      setState(() {
        _selected = selected;
        _custom = custom;
      });
    }
  }

  Future<void> _toggle(String id, bool value) async {
    setState(() {
      if (value) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
      _changed = true;
    });
    await widget.store.saveSelectedIds(_selected);
  }

  Future<void> _addCustom() async {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final app = await showDialog<TvApp>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add custom app'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'App name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Package name or link',
                hintText: 'com.example.tv or https://…',
                helperText:
                    'Use an app link to open directly. Unknown package '
                    'names may open the Play Store.',
                helperMaxLines: 3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final target = targetController.text.trim();
              if (name.isEmpty || target.isEmpty) return;
              Navigator.of(
                context,
              ).pop(TvApp.customEntry(name: name, target: target));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    targetController.dispose();
    if (app == null) return;
    await widget.store.addCustomApp(app);
    _changed = true;
    await _load();
  }

  Future<void> _removeCustom(TvApp app) async {
    await widget.store.removeCustomApp(app.id);
    _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'App shortcuts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addCustom,
                  icon: const Icon(Icons.add),
                  label: const Text('Custom'),
                ),
                IconButton(
                  tooltip: 'Done',
                  onPressed: () => Navigator.of(context).pop(_changed),
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              children: [
                for (final app in catalogApps)
                  SwitchListTile(
                    secondary: TvAppIcon(app: app, size: 42, borderRadius: 12),
                    title: Text(app.name),
                    subtitle: Text(
                      app.launchUrl.startsWith('market://')
                          ? 'Opens automatically via the Play Store'
                          : app.packageName ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    value: _selected.contains(app.id),
                    onChanged: (value) => _toggle(app.id, value),
                  ),
                if (_custom.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'CUSTOM',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final app in _custom)
                    ListTile(
                      leading: TvAppIcon(app: app, size: 42, borderRadius: 12),
                      title: Text(app.name),
                      subtitle: Text(
                        app.launchUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove ${app.name}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeCustom(app),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
