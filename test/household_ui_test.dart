import 'dart:io';
import 'dart:ui' as ui;
import 'package:chromecast_remote/core/protocol/android_tv/android_tv_remote_client.dart';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/app_shortcut_store.dart';
import 'package:chromecast_remote/features/household/tv_preferences.dart';
import 'package:chromecast_remote/features/remote/presentation/android_tv_remote_screen.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_tv_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const directory = String.fromEnvironment('UPGRADE_FONT_DIR');
    if (directory.isEmpty) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          File('$directory/$file').readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });
  for (final eyesUp in [false, true]) {
    testWidgets(
      'household preferences preserve reachable controls with eyes-up $eyesUp',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final preferences = TvPreferenceStore(InMemorySecureStore());
        final tv = FakeTvController(testTv());
        final now = DateTime.now().toUtc();
        tv.client.powerReportedAt = now;
        tv.client.volumeReportedAt = now;
        tv.client.isOn = true;
        tv.client.volumeInfo = const AndroidTvVolumeInfo(
          level: 12,
          max: 25,
          muted: false,
        );
        await preferences.save(
          tv.pairedDevice.serviceName,
          TvPreferences(eyesUp: eyesUp, room: 'Living room'),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: Scaffold(
                appBar: AppBar(title: const Text('Remote')),
                bottomNavigationBar: NavigationBar(
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.settings_remote),
                      label: 'Remote',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.apps),
                      label: 'Apps',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tv),
                      label: 'Devices',
                    ),
                  ],
                ),
                body: AndroidTvRemoteScreen(
                  controller: tv,
                  embedded: true,
                  preferenceStore: preferences,
                  shortcutStore: AppShortcutStore(store: InMemorySecureStore()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('TV on · Volume 12/25'), findsOneWidget);
        expect(
          tester.getBottomRight(find.byIcon(Icons.volume_down_rounded)).dy,
          lessThan(700),
        );
        if (eyesUp) expect(find.text('Favorite apps'), findsNothing);
        const directory = String.fromEnvironment('UPGRADE_SCREENSHOTS');
        if (directory.isNotEmpty) {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('capture')),
                )
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(directory).create(recursive: true);
            await File(
              '$directory/remote-${eyesUp ? 'eyes-up' : 'standard'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await preferences.save(
          tv.pairedDevice.serviceName,
          TvPreferences(eyesUp: eyesUp, volume: false),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.volume_down_rounded));
        expect(tv.commands, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tv.dispose();
      },
    );
  }
}
