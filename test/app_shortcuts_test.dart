import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/app_shortcut_store.dart';
import 'package:chromecast_remote/features/apps/tv_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog integrity', () {
    test('catalog apps have unique ids and verified package launch links', () {
      final ids = catalogApps.map((a) => a.id).toSet();
      expect(ids.length, catalogApps.length, reason: 'duplicate catalog ids');

      for (final app in catalogApps) {
        expect(app.name, isNotEmpty, reason: app.id);
        expect(app.packageName, isNotNull, reason: app.id);
        expect(
          app.launchUrl,
          'market://launch?id=${app.packageName}',
          reason: app.id,
        );
      }
    });

    test('catalog contains the requested streaming apps', () {
      final names = catalogApps.map((a) => a.name).toSet();
      for (final expected in [
        'Netflix',
        'YouTube',
        'Spotify',
        'Videoland',
        'NPO Start',
      ]) {
        expect(names, contains(expected));
      }
    });
  });

  group('TvApp.customEntry', () {
    test('turns a package name into a launch link', () {
      final app = TvApp.customEntry(name: 'Kodi', target: 'org.xbmc.kodi');
      expect(app.launchUrl, 'market://launch?id=org.xbmc.kodi');
      expect(app.packageName, 'org.xbmc.kodi');
      expect(app.custom, isTrue);
    });

    test('keeps deep links as-is', () {
      final app = TvApp.customEntry(name: 'Radio', target: 'https://example.fm');
      expect(app.launchUrl, 'https://example.fm');
      expect(app.packageName, isNull);
    });
  });

  group('matchByPackage', () {
    test('matches the active foreground package', () {
      expect(
        matchByPackage(catalogApps, 'com.netflix.ninja')?.id,
        'netflix',
      );
      expect(matchByPackage(catalogApps, 'com.unknown.app'), isNull);
      expect(matchByPackage(catalogApps, null), isNull);
      expect(matchByPackage(catalogApps, ''), isNull);
    });
  });

  group('AppShortcutStore', () {
    late InMemorySecureStore secureStore;
    late AppShortcutStore store;

    setUp(() {
      secureStore = InMemorySecureStore();
      store = AppShortcutStore(store: secureStore);
    });

    test('returns default shortcuts on first launch', () async {
      final shortcuts = await store.loadShortcuts();
      expect(
        shortcuts.map((a) => a.id),
        containsAll(AppShortcutStore.defaultIds),
      );
      expect(shortcuts.every((a) => !a.custom), isTrue);
    });

    test('persists the selected catalog apps', () async {
      await store.saveSelectedIds({'plex', 'twitch'});
      final shortcuts = await store.loadShortcuts();
      expect(shortcuts.map((a) => a.id), containsAll(['plex', 'twitch']));
      expect(shortcuts.map((a) => a.id), isNot(contains('netflix')));
    });

    test('adds, persists, and removes custom apps', () async {
      final kodi = TvApp.customEntry(name: 'Kodi', target: 'org.xbmc.kodi');
      await store.addCustomApp(kodi);

      var shortcuts = await store.loadShortcuts();
      expect(shortcuts.map((a) => a.id), contains('custom:kodi'));

      await store.removeCustomApp('custom:kodi');
      shortcuts = await store.loadShortcuts();
      expect(shortcuts.map((a) => a.id), isNot(contains('custom:kodi')));
    });

    test('corrupted storage falls back to defaults', () async {
      await secureStore.write('app_shortcuts_selected_v1', '{broken');
      final ids = await store.loadSelectedIds();
      expect(ids, AppShortcutStore.defaultIds);
    });
  });
}
