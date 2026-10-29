import 'package:flutter/material.dart';

import '../../../shared/presentation/adaptive_layout.dart';
import '../app_shortcut_store.dart';
import '../tv_app.dart';
import '../destination_templates.dart';
import 'app_detail_screen.dart';
import 'tv_app_icon.dart';

class AppLibraryView extends StatefulWidget {
  const AppLibraryView({
    required this.store,
    required this.onChooseDevice,
    this.connectedDeviceName,
    this.onLaunchApp,
    this.onRoutines,
    super.key,
  });

  final AppShortcutStore store;
  final VoidCallback onChooseDevice;
  final String? connectedDeviceName;
  final VoidCallback? onRoutines;
  final Future<bool> Function(TvApp app)? onLaunchApp;

  @override
  State<AppLibraryView> createState() => _AppLibraryViewState();
}

class _AppLibraryViewState extends State<AppLibraryView> {
  final _searchController = TextEditingController();
  Set<String> _selected = {};
  List<TvApp> _custom = [];
  String? _launchingId;
  bool _saving = false;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(AppLibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_load);
      widget.store.addListener(_load);
      _load();
    }
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    final selected = await widget.store.loadSelectedIds();
    final custom = await widget.store.loadCustomApps();
    if (mounted && version == _loadVersion) {
      setState(() {
        _selected = selected;
        _custom = custom;
      });
    }
  }

  Future<void> _toggle(TvApp app) async {
    if (_saving) return;
    final store = widget.store;
    final next = {..._selected};
    next.contains(app.id) ? next.remove(app.id) : next.add(app.id);
    setState(() {
      _selected = next;
      _saving = true;
    });
    try {
      await store.saveSelectedIds(next);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _launch(TvApp app) async {
    if (_launchingId != null) return;
    final launch = widget.onLaunchApp;
    if (launch == null) {
      widget.onChooseDevice();
      return;
    }
    setState(() => _launchingId = app.id);
    try {
      await launch(app);
    } finally {
      if (mounted) setState(() => _launchingId = null);
    }
  }

  Future<void> _details(TvApp app) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppDetailScreen(
          app: app,
          store: widget.store,
          connectedDeviceName: widget.connectedDeviceName,
          onLaunchApp: widget.onLaunchApp,
          onChooseDevice: widget.onChooseDevice,
        ),
      ),
    );
    await _load();
  }

  Future<void> _addDestination() async {
    final store = widget.store;
    final app = await showDialog<TvApp>(
      context: context,
      builder: (_) => const _DestinationDialog(),
    );
    if (app != null) await store.addCustomApp(app);
  }

  Future<void> _reorder() async {
    final store = widget.store;
    final favorites = await store.loadShortcuts();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Order favorites',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: favorites.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setSheetState(() {
                      favorites.insert(newIndex, favorites.removeAt(oldIndex));
                    });
                  },
                  itemBuilder: (_, index) => ListTile(
                    key: ValueKey(favorites[index].id),
                    leading: TvAppIcon(app: favorites[index], size: 36),
                    title: Text(favorites[index].name),
                    trailing: const Icon(Icons.drag_handle),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () async {
                    await store.saveSelectedIds(
                      favorites.map((app) => app.id).toSet(),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.store.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final all = [...catalogApps, ..._custom];
    final positions = _selected.toList();
    final query = _searchController.text.trim().toLowerCase();
    final apps =
        all.where((app) => app.name.toLowerCase().contains(query)).toList()
          ..sort((a, b) {
            final ai = positions.indexOf(a.id), bi = positions.indexOf(b.id);
            if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
            if (ai >= 0) return -1;
            if (bi >= 0) return 1;
            return a.name.compareTo(b.name);
          });
    return AdaptiveContent(
      maxWidth: 800,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tv_outlined),
              title: Text(
                widget.connectedDeviceName ?? 'Choose a TV to launch',
              ),
              subtitle: const Text(
                'Available shortcuts · installation is not checked',
              ),
              trailing: TextButton(
                onPressed: widget.onChooseDevice,
                child: Text(
                  widget.connectedDeviceName == null ? 'Choose TV' : 'Switch',
                ),
              ),
            ),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search shortcuts',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Favorites first',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (widget.onRoutines != null)
                  IconButton(
                    tooltip: 'TV and audio routines',
                    onPressed: widget.onRoutines,
                    icon: const Icon(Icons.auto_awesome_motion_outlined),
                  ),
                IconButton(
                  tooltip: 'Order favorites',
                  onPressed: _selected.length < 2 ? null : _reorder,
                  icon: const Icon(Icons.reorder),
                ),
                IconButton(
                  tooltip: 'Add personal destination',
                  onPressed: _addDestination,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Expanded(
              child: apps.isEmpty
                  ? const Center(child: Text('No shortcuts match your search.'))
                  : ListView.builder(
                      key: const PageStorageKey('app-library'),
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final selected = _selected.contains(app.id);
                        return ListTile(
                          leading: TvAppIcon(app: app, size: 40),
                          title: Text(app.name),
                          subtitle: _launchingId == app.id
                              ? const Text('Requesting launch…')
                              : app.custom
                              ? const Text('Personal destination')
                              : null,
                          onTap: _launchingId == null
                              ? () => _launch(app)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: selected
                                    ? 'Remove ${app.name} from remote'
                                    : 'Add ${app.name} to remote',
                                onPressed: _saving ? null : () => _toggle(app),
                                icon: Icon(
                                  selected
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                ),
                                color: selected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                              PopupMenuButton<String>(
                                tooltip: '${app.name} options',
                                onSelected: (value) async {
                                  if (value == 'details') await _details(app);
                                  if (value == 'remove') {
                                    await widget.store.removeCustomApp(app.id);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: Text('Shortcut details'),
                                  ),
                                  if (app.custom)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Delete destination'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationDialog extends StatefulWidget {
  const _DestinationDialog();
  @override
  State<_DestinationDialog> createState() => _DestinationDialogState();
}

class _DestinationDialogState extends State<_DestinationDialog> {
  final form = GlobalKey<FormState>();
  DestinationProvider provider = DestinationProvider.custom;
  final name = TextEditingController();
  final target = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add personal destination'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DestinationProvider>(
              initialValue: provider,
              decoration: const InputDecoration(labelText: 'Destination type'),
              items: const [
                DropdownMenuItem(
                  value: DestinationProvider.custom,
                  child: Text('Custom app or link'),
                ),
                DropdownMenuItem(
                  value: DestinationProvider.youtube,
                  child: Text('YouTube video'),
                ),
                DropdownMenuItem(
                  value: DestinationProvider.spotify,
                  child: Text('Spotify music'),
                ),
              ],
              onChanged: (value) => setState(() {
                provider = value ?? DestinationProvider.custom;
                target.clear();
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: name,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Evening playlist',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: target,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'App link or package name',
                hintText: 'https://… or com.example.tv',
                helperText:
                    'Provider links are formatted here; test them on your TV. Opening an app does not confirm that content played.',
                helperMaxLines: 3,
              ),
              validator: (value) {
                try {
                  DestinationTemplates.create(
                    provider,
                    name.text.trim().isEmpty ? 'Destination' : name.text,
                    value ?? '',
                  );
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              DestinationTemplates.create(provider, name.text, target.text),
            );
          }
        },
        child: const Text('Add favorite'),
      ),
    ],
  );
}
