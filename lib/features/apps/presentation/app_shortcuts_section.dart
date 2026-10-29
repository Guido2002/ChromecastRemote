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
/// highlighted. All apps opens the same library used by the Apps destination.
class AppShortcutsSection extends StatefulWidget {
  const AppShortcutsSection({
    required this.store,
    required this.enabled,
    required this.onLaunch,
    required this.activePackage,
    this.onManage,
    super.key,
  });

  final AppShortcutStore store;
  final bool enabled;
  final Future<void> Function(TvApp) onLaunch;
  final VoidCallback? onManage;

  /// Package name of the app currently in the foreground on the TV.
  final String? activePackage;

  @override
  State<AppShortcutsSection> createState() => _AppShortcutsSectionState();
}

class _AppShortcutsSectionState extends State<AppShortcutsSection> {
  List<TvApp> _shortcuts = const [];
  String? _launchingId;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_reload);
    _reload();
  }

  Future<void> _reload() async {
    final version = ++_loadVersion;
    final shortcuts = await widget.store.loadShortcuts();
    if (mounted && version == _loadVersion) {
      setState(() => _shortcuts = shortcuts);
    }
  }

  Future<void> _launch(TvApp app) async {
    if (_launchingId != null) return;
    HapticFeedback.lightImpact();
    setState(() => _launchingId = app.id);
    try {
      await widget.onLaunch(app);
    } finally {
      if (mounted) setState(() => _launchingId = null);
    }
  }

  @override
  void didUpdateWidget(AppShortcutsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_reload);
      widget.store.addListener(_reload);
      _reload();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_reload);
    super.dispose();
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
                'Favorite apps',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.onManage != null)
              TextButton(
                onPressed: widget.onManage,
                child: const Text('All apps'),
              ),
          ],
        ),
        SizedBox(
          height: tablet ? 100 : 84,
          child: _shortcuts.isEmpty
              ? Center(
                  child: Text(
                    'Choose favorites in Apps to keep them here.',
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
                      enabled: widget.enabled && _launchingId == null,
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
        scale: 1,
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
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.standard,
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
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppMotion.standard,
                  child: launchPending
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
