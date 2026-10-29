import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromecast_remote/core/protocol/android_tv/certificate_manager.dart';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/app_launcher.dart';
import 'package:chromecast_remote/features/apps/app_shortcut_store.dart';
import 'package:chromecast_remote/features/apps/presentation/app_library_view.dart';
import 'package:chromecast_remote/features/apps/tv_app.dart';
import 'package:chromecast_remote/features/pairing/paired_device_store.dart';
import 'package:chromecast_remote/features/remote/android_tv_connection_manager.dart';
import 'package:chromecast_remote/features/remote/presentation/android_tv_remote_screen.dart';
import 'package:chromecast_remote/features/remote/presentation/widgets/directional_pad.dart';
import 'package:chromecast_remote/features/remote/remote_controller.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_tv_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fonts = String.fromEnvironment('UPGRADE_FONT_DIR');
    if (fonts.isEmpty) return;
    for (final (family, filename) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          File(
            '$fonts/$filename',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  test(
    'TV favorites migrate once and preserve independent explicit order',
    () async {
      final storage = InMemorySecureStore();
      final root = AppShortcutStore(store: storage);
      await root.saveSelectedIds({'youtube', 'netflix'});
      await root.addCustomApp(
        TvApp.customEntry(name: 'Radio', target: 'https://example.com/radio'),
      );
      final living = root.forDevice('Living room');
      final bedroom = root.forDevice('Bedroom');
      expect(await living.loadSelectedIds(), {
        'youtube',
        'netflix',
        'custom:radio',
      });
      await living.saveSelectedIds({'custom:radio', 'netflix'});
      expect((await living.loadShortcuts()).map((app) => app.id), [
        'custom:radio',
        'netflix',
      ]);
      expect(await bedroom.loadSelectedIds(), {
        'youtube',
        'netflix',
        'custom:radio',
      });
      await root.saveSelectedIds({'plex'});
      expect(await living.loadSelectedIds(), {'custom:radio', 'netflix'});
      await living.removeCustomApp('custom:radio');
      expect(
        (await bedroom.loadCustomApps()).map((app) => app.id),
        contains('custom:radio'),
      );
    },
  );

  test(
    'remembered Cast identities stay separate from trusted TV pairings',
    () async {
      final storage = InMemorySecureStore();
      final paired = PairedDeviceStore(store: storage);
      await paired.save(testTv());
      await paired.rememberCastReceiver(
        const SavedCastReceiver(id: 'cast:receiver', name: 'Living room'),
      );
      await paired.saveLastDevice(id: 'cast:receiver', protocol: 'googleCast');
      expect((await paired.loadCastReceivers()).single.id, 'cast:receiver');
      await paired.forgetCastReceiver('cast:receiver');
      expect(await paired.loadLastDevice(), isNull);
      expect(
        (await paired.loadPairedDevices()).single.serverCertificateSha256,
        'trusted',
      );
    },
  );

  test('launch confirms only a reported foreground match', () async {
    final target = FakeTvController(testTv());
    final result = launchTvApp(
      target,
      catalogApps.first,
      isCurrentTarget: () => true,
    );
    target.apps.add('com.unrelated.app');
    target.apps.add(catalogApps.first.packageName!);
    expect(await result, AppLaunchOutcome.confirmed);
    expect(target.links, [catalogApps.first.launchUrl]);
    expect(
      target.commands,
      isEmpty,
      reason: 'Never blindly confirm a Play Store action',
    );
    await target.dispose();
  });

  test(
    'unconfirmed launches and lost connections never report success',
    () async {
      final target = FakeTvController(testTv());
      expect(
        await launchTvApp(
          target,
          catalogApps.first,
          isCurrentTarget: () => true,
          confirmationTimeout: Duration.zero,
        ),
        AppLaunchOutcome.unconfirmed,
      );
      final pending = launchTvApp(
        target,
        catalogApps.first,
        isCurrentTarget: () => true,
      );
      await target.disconnect();
      expect(await pending, AppLaunchOutcome.cancelled);
      await target.dispose();
    },
  );

  test(
    'rediscovery refreshes the endpoint and preserves the trust pin',
    () async {
      final storage = InMemorySecureStore();
      final manager = AndroidTvConnectionManager(
        certificates: CertificateManager(store: storage),
        store: PairedDeviceStore(store: storage),
        resolveHost: (_) async => '192.0.2.99',
        createController: FakeTvController.new,
      );
      final controller = await manager.connect(testTv());
      expect(controller.pairedDevice.lastHost, '192.0.2.99');
      expect(controller.pairedDevice.serverCertificateSha256, 'trusted');
      await manager.forget(controller.pairedDevice);
    },
  );

  test('fresh pairing replaces a controller with an obsolete pin', () async {
    final storage = InMemorySecureStore();
    final manager = AndroidTvConnectionManager(
      certificates: CertificateManager(store: storage),
      store: PairedDeviceStore(store: storage),
      createController: FakeTvController.new,
    );
    final original = await manager.connect(testTv());
    final replacement = await manager.connect(testTv(pin: 'fresh-pairing'));
    expect(identical(original, replacement), isFalse);
    expect((original as FakeTvController).disposed, isTrue);
    expect(replacement.pairedDevice.serverCertificateSha256, 'fresh-pairing');
    await manager.forget(replacement.pairedDevice);
  });

  test(
    'forget serializes behind an in-flight connection and clears last device',
    () async {
      final storage = InMemorySecureStore();
      final gate = Completer<void>();
      final paired = PairedDeviceStore(store: storage);
      final manager = AndroidTvConnectionManager(
        certificates: CertificateManager(store: storage),
        store: paired,
        createController: (device) =>
            FakeTvController(device)..connectGate = gate,
      );
      final connecting = manager.connect(testTv());
      final forgetting = manager.forget(testTv());
      gate.complete();
      await connecting;
      await forgetting;
      expect(manager.controller, isNull);
      expect(await paired.loadLastDevice(), isNull);
      expect(await paired.loadPairedDevices(), isEmpty);
    },
  );

  testWidgets('direction quadrants respond outside the former icon buttons', (
    tester,
  ) async {
    final directions = <String>[];
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DirectionalPad(
              enabled: true,
              maxDiameter: 300,
              onDirection: directions.add,
              onSelect: () => selected++,
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(DirectionalPad));
    await tester.tapAt(center + const Offset(75, -75));
    await tester.tapAt(center + const Offset(-75, 75));
    await tester.tapAt(center);
    expect(directions.length, 2);
    expect(selected, 1);
  });

  for (final size in [
    const Size(360, 800),
    const Size(360, 640),
    const Size(700, 900),
    const Size(900, 500),
  ]) {
    testWidgets('essential controls stay visible at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = FakeTvController(testTv());
      final store = AppShortcutStore(store: InMemorySecureStore());
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
                  NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
                  NavigationDestination(icon: Icon(Icons.tv), label: 'Devices'),
                ],
              ),
              body: AndroidTvRemoteScreen(
                controller: controller,
                embedded: true,
                shortcutStore: store,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final volume = find.byIcon(Icons.volume_down_rounded);
      expect(volume, findsOneWidget);
      expect(tester.getBottomRight(volume).dy, lessThan(size.height - 70));
      await tester.tap(find.byTooltip('TV Home'));
      expect(controller.commands, [RemoteCommand.home]);
      const captures = String.fromEnvironment('UPGRADE_SCREENSHOTS');
      if (captures.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(captures).create(recursive: true);
          await File(
            '$captures/remote-${size.width.toInt()}-${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await controller.dispose();
    });
  }

  testWidgets('app rows request launch directly without a details detour', (
    tester,
  ) async {
    final store = AppShortcutStore(store: InMemorySecureStore());
    TvApp? requested;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AppLibraryView(
            store: store,
            connectedDeviceName: 'Living room',
            onChooseDevice: () {},
            onLaunchApp: (app) async {
              requested = app;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    expect(requested?.id, 'netflix');
    expect(find.text('App details'), findsNothing);
  });

  testWidgets('large text remote remains reachable without layout overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = FakeTvController(testTv());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: AndroidTvRemoteScreen(
              controller: controller,
              embedded: true,
              shortcutStore: AppShortcutStore(store: InMemorySecureStore()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final volume = find.byIcon(Icons.volume_down_rounded);
    await tester.ensureVisible(volume);
    await tester.tap(volume);
    expect(controller.commands, [RemoteCommand.volumeDown]);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });

  test('filled action colors meet normal text contrast', () {
    final contrast =
        (Colors.white.computeLuminance() + 0.05) /
        (AppColors.actionFill.computeLuminance() + 0.05);
    expect(contrast, greaterThanOrEqualTo(4.5));
  });
}
