import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chromecast_remote/features/remote/cast_capabilities.dart';
import 'package:chromecast_remote/features/remote/smart_now_playing.dart';
import 'package:chromecast_remote/features/remote/presentation/smart_remote_view.dart';
import 'support/cast_fixture.dart';

void main() {
  test(
    'requires matching receiver and media identity, connected session and non-idle media',
    () {
      expect(fixturePlayback().available, isTrue);
      expect(
        fixturePlayback(state: CastMediaPlayerState.paused).available,
        isTrue,
      );
      expect(
        fixturePlayback(state: CastMediaPlayerState.idle).available,
        isFalse,
      );
      final active = fixturePlayback();
      expect(
        CastPlaybackSnapshot(
          session: active.session,
          media: active.media,
        ).available,
        isFalse,
      );
      expect(
        CastPlaybackSnapshot(
          session: active.session,
          media: active.media,
          capabilities: const CastCapabilities(
            deviceId: 'other-room',
            mediaSessionId: 7,
            seek: true,
            pause: true,
          ),
        ).available,
        isFalse,
      );
      expect(
        CastPlaybackSnapshot(
          session: active.session,
          media: active.media,
          capabilities: const CastCapabilities(
            deviceId: 'living-room',
            mediaSessionId: 8,
            seek: true,
            pause: true,
          ),
        ).available,
        isFalse,
      );
      expect(
        CastPlaybackSnapshot(
          session: FixtureCastSession(connected: false),
          media: active.media,
          capabilities: active.capabilities,
        ).available,
        isFalse,
      );
    },
  );
  test(
    'stale capability responses cannot promote another receiver; background clears state',
    () async {
      final sessions = StreamController<GoogleCastSession?>.broadcast(
        sync: true,
      );
      final mediaUpdates = StreamController<GoggleCastMediaStatus?>.broadcast(
        sync: true,
      );
      GoogleCastSession? session = FixtureCastSession();
      GoggleCastMediaStatus? media = fixtureMedia();
      final stale = Completer<CastCapabilities?>();
      var reads = 0;
      final monitor = CastPlaybackMonitor(
        sessions: sessions.stream,
        mediaUpdates: mediaUpdates.stream,
        currentSession: () => session,
        currentMedia: () => media,
        readCapabilities: () async {
          reads++;
          if (reads == 1) return stale.future;
          return CastCapabilities(
            deviceId: session!.device!.deviceID,
            mediaSessionId: media.mediaSessionID,
            seek: true,
            pause: true,
          );
        },
      );
      monitor.setActive(true);
      session = FixtureCastSession(id: 'bedroom', session: 'cast-2');
      sessions.add(session);
      expect(monitor.value.available, isFalse);
      stale.complete(
        const CastCapabilities(
          deviceId: 'living-room',
          mediaSessionId: 7,
          seek: true,
          pause: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.value.session!.device!.deviceID, 'bedroom');
      expect(monitor.value.available, isTrue);
      final seen = <bool>[];
      monitor.addListener(() => seen.add(monitor.value.available));
      mediaUpdates.add(media);
      expect(
        monitor.value.available,
        isTrue,
        reason: 'Position/status ticks must not flicker back to TV controls',
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.every((v) => v), isTrue);
      monitor.setActive(false);
      expect(monitor.value.available, isFalse);
      final count = reads;
      sessions.add(session);
      await Future<void>.delayed(Duration.zero);
      expect(reads, count);
      monitor.dispose();
      await sessions.close();
      await mediaUpdates.close();
    },
  );
  testWidgets(
    'automatically displays media, preserves manual override and returns on session end',
    (tester) async {
      final playback = ValueNotifier(const CastPlaybackSnapshot());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRemoteView(
              playback: playback,
              remoteBuilder: (_, active) =>
                  Text(active ? 'TV controls ready' : 'TV controls paused'),
              castBuilder: (_, snapshot) =>
                  const Text('Dedicated media controls'),
            ),
          ),
        ),
      );
      expect(find.text('TV controls ready'), findsOneWidget);
      playback.value = fixturePlayback();
      await tester.pump();
      expect(find.text('Dedicated media controls'), findsOneWidget);
      expect(find.text('TV controls ready'), findsNothing);
      await tester.tap(find.text('TV remote'));
      await tester.pump();
      expect(find.text('TV controls ready'), findsOneWidget);
      playback.value = fixturePlayback(state: CastMediaPlayerState.paused);
      await tester.pump();
      expect(find.text('TV controls ready'), findsOneWidget);
      playback.value = fixturePlayback(mediaId: 8);
      await tester.pump();
      expect(find.text('Dedicated media controls'), findsOneWidget);
      playback.value = const CastPlaybackSnapshot();
      await tester.pump();
      expect(find.text('TV controls ready'), findsOneWidget);
      expect(find.text('Dedicated media controls'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      playback.dispose();
    },
  );
}
