import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/storage/secure_store.dart';
import 'tv_app.dart';

/// Ordered favorites and personal destinations, isolated by paired TV.
/// Legacy global preferences are copied once when a TV scope is first used.
class AppShortcutStore extends ChangeNotifier {
  AppShortcutStore({required this.store, this.deviceId});

  static const defaultIds = {'netflix', 'youtube', 'spotify', 'videoland'};
  final SecureStore store;
  final String? deviceId;
  final Map<String, AppShortcutStore> _scopes = {};

  AppShortcutStore forDevice(String? id) => id == null
      ? this
      : _scopes.putIfAbsent(
          id,
          () => AppShortcutStore(store: store, deviceId: id),
        );

  String get _suffix =>
      deviceId == null ? '' : ':${Uri.encodeComponent(deviceId!)}';
  String get _selectedKey => 'app_shortcuts_selected_v2$_suffix';
  String get _customKey => 'app_shortcuts_custom_v1$_suffix';

  Future<Set<String>> loadSelectedIds() async {
    final raw = await store.read(_selectedKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.whereType<String>().toSet();
      } on FormatException {
        /* Recover below. */
      }
    }
    final Set<String> selected;
    if (deviceId != null) {
      selected = await AppShortcutStore(store: store).loadSelectedIds();
    } else {
      final legacy = await store.read('app_shortcuts_selected_v1');
      Set<String>? migrated;
      if (legacy != null) {
        try {
          final decoded = jsonDecode(legacy);
          if (decoded is List) migrated = decoded.whereType<String>().toSet();
        } on FormatException {
          /* Defaults preserve first-use behavior. */
        }
      }
      selected = migrated ?? Set.of(defaultIds);
      selected.addAll((await loadCustomApps()).map((app) => app.id));
    }
    await store.write(_selectedKey, jsonEncode(selected.toList()));
    return selected;
  }

  Future<void> saveSelectedIds(Set<String> ids) async {
    await store.write(_selectedKey, jsonEncode(ids.toList()));
    notifyListeners();
  }

  Future<List<TvApp>> loadCustomApps() async {
    var raw = await store.read(_customKey);
    if (raw == null && deviceId != null) {
      raw = await store.read('app_shortcuts_custom_v1') ?? '[]';
      await store.write(_customKey, raw);
    }
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final apps = <TvApp>[];
      for (final item in decoded.whereType<Map<String, dynamic>>()) {
        try {
          apps.add(TvApp.fromJson(item));
        } on TypeError {
          /* Skip invalid entry. */
        }
      }
      return apps;
    } on FormatException {
      return [];
    }
  }

  Future<void> addCustomApp(TvApp app) async {
    final selected = await loadSelectedIds();
    final apps = await loadCustomApps();
    apps.removeWhere((entry) => entry.id == app.id);
    apps.add(app);
    await store.write(
      _customKey,
      jsonEncode(apps.map((entry) => entry.toJson()).toList()),
    );
    await saveSelectedIds({...selected, app.id});
  }

  Future<void> removeCustomApp(String id) async {
    final selected = await loadSelectedIds();
    final apps = await loadCustomApps()
      ..removeWhere((app) => app.id == id);
    await store.write(
      _customKey,
      jsonEncode(apps.map((app) => app.toJson()).toList()),
    );
    await saveSelectedIds(selected..remove(id));
  }

  Future<List<TvApp>> loadShortcuts() async {
    final selected = await loadSelectedIds();
    final apps = {
      for (final app in [...catalogApps, ...await loadCustomApps()])
        app.id: app,
    };
    return [
      for (final id in selected)
        if (apps[id] != null) apps[id]!,
    ];
  }
}
