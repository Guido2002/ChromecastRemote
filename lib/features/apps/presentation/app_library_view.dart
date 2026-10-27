import 'package:flutter/material.dart';

import '../../../shared/presentation/adaptive_layout.dart';
import '../app_shortcut_store.dart';
import '../tv_app.dart';
import 'tv_app_icon.dart';

class AppLibraryView extends StatefulWidget {
  const AppLibraryView({
    required this.store,
    required this.onChooseDevice,
    super.key,
  });

  final AppShortcutStore store;
  final VoidCallback onChooseDevice;

  @override
  State<AppLibraryView> createState() => _AppLibraryViewState();
}

class _AppLibraryViewState extends State<AppLibraryView> {
  final _searchController = TextEditingController();
  Set<String> _selected = const {};
  TvAppCategory? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selected = await widget.store.loadSelectedIds();
    if (mounted) setState(() => _selected = selected);
  }

  Future<void> _toggle(TvApp app) async {
    final next = {..._selected};
    next.contains(app.id) ? next.remove(app.id) : next.add(app.id);
    setState(() => _selected = next);
    await widget.store.saveSelectedIds(next);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _searchController.text.trim().toLowerCase();
    final apps = catalogApps.where((app) {
      final matchesQuery =
          query.isEmpty || app.name.toLowerCase().contains(query);
      return matchesQuery && (_category == null || app.category == _category);
    }).toList();
    final tablet = AdaptiveLayout.isTablet(context);

    return AdaptiveContent(
      maxWidth: 1040,
      child: Padding(
        padding: EdgeInsets.fromLTRB(tablet ? 24 : 16, 8, tablet ? 24 : 16, 0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search apps',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'All apps',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  _FilterChip(
                    label: 'Movies',
                    selected: _category == TvAppCategory.movies,
                    onTap: () =>
                        setState(() => _category = TvAppCategory.movies),
                  ),
                  _FilterChip(
                    label: 'Music',
                    selected: _category == TvAppCategory.music,
                    onTap: () =>
                        setState(() => _category = TvAppCategory.music),
                  ),
                  _FilterChip(
                    label: 'Gaming',
                    selected: _category == TvAppCategory.gaming,
                    onTap: () =>
                        setState(() => _category = TvAppCategory.gaming),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.tv_rounded, color: colors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose a TV to launch apps. Stars control which shortcuts appear on the remote.',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onChooseDevice,
                    child: const Text('Choose TV'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: apps.isEmpty
                  ? Center(
                      child: Text(
                        'No apps match your search.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : tablet
                  ? GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 78,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: apps.length,
                      itemBuilder: (_, index) => _AppTile(
                        app: apps[index],
                        selected: _selected.contains(apps[index].id),
                        onToggle: () => _toggle(apps[index]),
                        onOpen: widget.onChooseDevice,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: apps.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => _AppTile(
                        app: apps[index],
                        selected: _selected.contains(apps[index].id),
                        onToggle: () => _toggle(apps[index]),
                        onOpen: widget.onChooseDevice,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
  });

  final TvApp app;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onOpen,
        leading: TvAppIcon(app: app, size: 44),
        title: Text(app.name),
        subtitle: Text(switch (app.category) {
          TvAppCategory.movies => 'Movies & TV',
          TvAppCategory.music => 'Music',
          TvAppCategory.gaming => 'Gaming',
          TvAppCategory.kids => 'Kids',
          TvAppCategory.other => 'Other',
        }, style: TextStyle(color: colors.onSurfaceVariant)),
        trailing: IconButton(
          tooltip: selected ? 'Remove from remote' : 'Add to remote',
          onPressed: onToggle,
          icon: Icon(selected ? Icons.star_rounded : Icons.star_border_rounded),
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
