import 'dart:convert';

import '../../core/storage/secure_store.dart';
import 'tv_app.dart';

/// Persists which catalog apps are shown as shortcuts plus any custom
/// user-defined apps.
class AppShortcutStore {
  AppShortcutStore({required this.store});

  static const _selectedKey = 'app_shortcuts_selected_v1';
  static const _customKey = 'app_shortcuts_custom_v1';

  /// Shortcuts shown on first launch.
  static const defaultIds = {'netflix', 'youtube', 'spotify', 'videoland'};

  final SecureStore store;

  Future<Set<String>> loadSelectedIds() async {
    final raw = await store.read(_selectedKey);
    if (raw == null || raw.isEmpty) return Set.of(defaultIds);
    try {
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toSet();
    } on FormatException {
      return Set.of(defaultIds);
    }
  }

  Future<void> saveSelectedIds(Set<String> ids) =>
      store.write(_selectedKey, jsonEncode(ids.toList()));

  Future<List<TvApp>> loadCustomApps() async {
    final raw = await store.read(_customKey);
    if (raw == null || raw.isEmpty) return <TvApp>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(TvApp.fromJson)
          .toList();
    } on FormatException {
      return <TvApp>[];
    }
  }

  Future<void> addCustomApp(TvApp app) async {
    final apps = await loadCustomApps();
    apps.removeWhere((a) => a.id == app.id);
    apps.add(app);
    await store.write(
      _customKey,
      jsonEncode(apps.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> removeCustomApp(String id) async {
    final apps = await loadCustomApps();
    apps.removeWhere((a) => a.id == id);
    await store.write(
      _customKey,
      jsonEncode(apps.map((a) => a.toJson()).toList()),
    );
  }

  /// The shortcuts to show on the remote: selected catalog apps plus all
  /// custom apps, catalog order preserved.
  Future<List<TvApp>> loadShortcuts() async {
    final selected = await loadSelectedIds();
    final custom = await loadCustomApps();
    return [
      ...catalogApps.where((app) => selected.contains(app.id)),
      ...custom,
    ];
  }
}
