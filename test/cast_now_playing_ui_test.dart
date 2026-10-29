import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chromecast_remote/features/remote/presentation/cast_remote_screen.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> native(String channel, String method, Object? arguments) {
    final done = Completer<void>();
    ui.channelBuffers.push(
      channel,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) => done.complete(),
    );
    return done.future;
  }

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
  testWidgets(
    'dedicated Cast view shows reported title, progress, volume and capability-gated controls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final commands = <String>[];
      var pauseSupported = true;
      const capabilities = MethodChannel('chromecast_remote/cast_capabilities');
      const mediaChannel = MethodChannel('google_cast.remote_media_client');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        capabilities,
        (_) async => {
          'deviceId': 'living-room',
          'mediaSessionId': 7,
          'seek': true,
          'pause': pauseSupported,
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        mediaChannel,
        (call) async {
          commands.add(call.method);
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_cast.session_manager'),
        (_) async => null,
      );
      // Initialize SDK listeners before delivering native reports.
      GoogleCastSessionManager.instance.currentSession;
      GoogleCastRemoteMediaClient.instance.mediaStatus;
      await native('google_cast.session_manager', 'onCurrentSessionChanged', {
        'device': {
          'deviceID': 'living-room',
          'friendlyName': 'Living room TV',
          'isOnLocalNetwork': true,
          'category': 'cast',
          'uniqueID': 'living-room',
        },
        'sessionID': 'cast-1',
        'connectionState': GoogleCastConnectState.connected.index,
        'currentDeviceMuted': false,
        'currentDeviceVolume': .4,
      });
      await native('google_cast.remote_media_client', 'onUpdateMediaStatus', {
        'mediaSessionID': 7,
        'playerState': CastMediaPlayerState.playing.index,
        'playbackRate': 1,
        'volume': .4,
        'isMuted': false,
        'repeatMode': GoogleCastMediaRepeatMode.off.index,
        'queueHasNextItem': false,
        'mediaInformation': {
          'contentID': 'https://example.com/movie.mp4',
          'streamType': CastMediaStreamType.buffered.index,
          'contentType': 'video/mp4',
          'duration': 300,
          'metadata': {'metadataType': 0, 'title': 'Reported movie title'},
        },
      });
      await native(
        'google_cast.remote_media_client',
        'onUpdatePlayerPosition',
        62,
      );
      final device = GoogleCastSessionManager.instance.currentSession!.device!;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: CastRemoteScreen(
              device: device,
              embedded: true,
              nowPlaying: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Now playing'), findsAtLeastNWidgets(1));
      expect(find.text('Reported movie title'), findsOneWidget);
      expect(find.text('1:02'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      final seek = tester.widgetList<Slider>(find.byType(Slider)).first;
      expect(seek.onChanged, isNotNull);
      final pause = find.widgetWithIcon(FilledButton, Icons.pause_rounded);
      await tester.tap(pause);
      await tester.pumpAndSettle();
      expect(commands, contains('pause'));
      pauseSupported = false;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.widget<FilledButton>(pause).onPressed, isNull);
      const output = String.fromEnvironment('FEATURE_QA_DIR');
      if (output.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/now-playing.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      for (final size in [
        const Size(320, 640),
        const Size(700, 900),
        const Size(900, 500),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Cast layout at $size');
      }
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Cast layout at 200% text',
      );
      await tester.pumpWidget(const SizedBox());
      await native(
        'google_cast.session_manager',
        'onCurrentSessionChanged',
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        capabilities,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        mediaChannel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_cast.session_manager'),
        null,
      );
    },
  );
}
