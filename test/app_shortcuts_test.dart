import 'dart:convert';

import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/app_shortcut_store.dart';
import 'package:chromecast_remote/features/apps/presentation/app_shortcuts_section.dart';
import 'package:chromecast_remote/features/apps/tv_app.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog integrity', () {
    test('catalog apps have unique ids, packages, and launch links', () {
      final ids = catalogApps.map((a) => a.id).toSet();
      expect(ids.length, catalogApps.length, reason: 'duplicate catalog ids');

      for (final app in catalogApps) {
        expect(app.name, isNotEmpty, reason: app.id);
        expect(app.packageName, isNotNull, reason: app.id);
        expect(Uri.parse(app.launchUrl).hasScheme, isTrue, reason: app.id);
      }
    });

    test('apps with known deep links bypass the Play Store', () {
      const directLinks = {
        'netflix': 'netflix://',
        'youtube': 'vnd.youtube.launch://',
        'prime-video': 'https://app.primevideo.com',
        'disney-plus': 'https://www.disneyplus.com',
        'videoland': 'videoland-v2://',
        'nlziet': 'nlziet://',
        'ziggo-go': 'ziggogo://',
        'spotify': 'spotify://',
        'plex': 'plex://',
        'twitch': 'twitch://home',
      };
      for (final entry in directLinks.entries) {
        final app = catalogApps.singleWhere((app) => app.id == entry.key);
        expect(app.launchUrl, entry.value, reason: app.id);
        expect(
          Uri.parse(app.launchUrl).scheme,
          isNot('market'),
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
    test('uses a direct link for a known package name', () {
      final app = TvApp.customEntry(
        name: 'My Netflix',
        target: '  com.netflix.ninja  ',
      );
      expect(app.launchUrl, 'netflix://');
      expect(app.packageName, 'com.netflix.ninja');
      expect(app.custom, isTrue);
    });

    test('keeps the package fallback when no deep link is known', () {
      final app = TvApp.customEntry(name: 'Kodi', target: 'org.xbmc.kodi');
      expect(app.launchUrl, 'market://launch?id=org.xbmc.kodi');
      expect(app.packageName, 'org.xbmc.kodi');
      expect(app.custom, isTrue);
    });

    test('keeps deep links as-is', () {
      final app = TvApp.customEntry(
        name: 'Radio',
        target: 'https://example.fm',
      );
      expect(app.launchUrl, 'https://example.fm');
      expect(app.packageName, isNull);
    });

    test('keeps links to specific content as-is', () {
      final app = TvApp.customEntry(
        name: 'Netflix title',
        target: 'netflix://title/12345',
      );
      expect(app.launchUrl, 'netflix://title/12345');
    });
  });

  group('TvApp persistence', () {
    test('preserves an explicit content link for a known package', () {
      final app = TvApp.fromJson({
        'id': 'custom:netflix title',
        'name': 'Netflix title',
        'packageName': 'com.netflix.ninja',
        'launchUrl': 'netflix://title/12345',
      });
      expect(app.launchUrl, 'netflix://title/12345');
      expect(TvApp.fromJson(app.toJson()).launchUrl, app.launchUrl);
    });

    test('preserves an explicitly configured store details link', () {
      final app = TvApp.fromJson({
        'id': 'custom:netflix store',
        'name': 'Netflix store',
        'packageName': 'com.netflix.ninja',
        'launchUrl': 'market://details?id=com.netflix.ninja',
      });
      expect(app.launchUrl, 'market://details?id=com.netflix.ninja');
    });
  });

  group('matchByPackage', () {
    test('matches the active foreground package', () {
      expect(matchByPackage(catalogApps, 'com.netflix.ninja')?.id, 'netflix');
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

    test(
      'upgrades saved package shortcuts to direct links when available',
      () async {
        await secureStore.write(
          'app_shortcuts_custom_v1',
          jsonEncode([
            {
              'id': 'custom:my netflix',
              'name': 'My Netflix',
              'packageName': 'com.netflix.ninja',
              'launchUrl': 'market://launch?id=com.netflix.ninja',
            },
            {
              'id': 'custom:kodi',
              'name': 'Kodi',
              'packageName': 'org.xbmc.kodi',
              'launchUrl': 'market://launch?id=org.xbmc.kodi',
            },
            {
              'id': 'custom:radio',
              'name': 'Radio',
              'launchUrl': 'https://example.fm',
            },
          ]),
        );

        final shortcuts = await store.loadShortcuts();
        final netflix = shortcuts.singleWhere(
          (a) => a.id == 'custom:my netflix',
        );
        expect(netflix.name, 'My Netflix');
        expect(netflix.packageName, 'com.netflix.ninja');
        expect(netflix.launchUrl, 'netflix://');
        expect(netflix.custom, isTrue);
        expect(
          shortcuts.singleWhere((a) => a.id == 'custom:kodi').launchUrl,
          'market://launch?id=org.xbmc.kodi',
        );
        expect(
          shortcuts.singleWhere((a) => a.id == 'custom:radio').launchUrl,
          'https://example.fm',
        );
      },
    );

    test('corrupted storage falls back to defaults', () async {
      await secureStore.write('app_shortcuts_selected_v1', '{broken');
      final ids = await store.loadSelectedIds();
      expect(ids, AppShortcutStore.defaultIds);
    });
  });

  testWidgets('launching a shortcut gives immediate visual confirmation', (
    tester,
  ) async {
    final store = AppShortcutStore(store: InMemorySecureStore());
    TvApp? launchedApp;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AppShortcutsSection(
            store: store,
            enabled: true,
            activePackage: null,
            onLaunch: (app) => launchedApp = app,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Netflix'));
    await tester.pump();

    expect(launchedApp?.id, 'netflix');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
