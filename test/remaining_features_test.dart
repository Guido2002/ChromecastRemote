import 'package:chromecast_remote/core/protocol/android_tv/android_tv_remote_client.dart';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/destination_templates.dart';
import 'package:chromecast_remote/features/diagnostics/local_diagnostics.dart';
import 'package:chromecast_remote/features/household/room_suggestions.dart';
import 'package:chromecast_remote/features/household/tv_preferences.dart';
import 'package:chromecast_remote/features/remote/cast_capabilities.dart';
import 'package:chromecast_remote/features/remote/models/tv_reported_state.dart';
import 'package:chromecast_remote/features/remote/presentation/widgets/directional_pad.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_tv_controller.dart';

void main() {
  test('TV preferences persist independently and reset safely', () async {
    final store = TvPreferenceStore(InMemorySecureStore());
    await store.save(
      'living',
      const TvPreferences(room: 'Living room', eyesUp: true, volume: false),
    );
    expect((await store.load('living')).eyesUp, isTrue);
    expect((await store.load('living')).volume, isFalse);
    expect((await store.load('bedroom')).volume, isTrue);
    await store.save('living', const TvPreferences());
    expect((await store.load('living')).room, isEmpty);
    expect((await store.load('living')).volume, isTrue);
  });
  test(
    'room suggestions require explicit room metadata and rank nearby TVs first',
    () {
      final living = testTv(id: 'living'), bedroom = testTv(id: 'bedroom');
      TvPreferences preferences(String id) =>
          TvPreferences(room: id == 'living' ? 'Living room' : 'Bedroom');
      expect(
        suggestRoomTvs(
          devices: [living, bedroom],
          nearbyServices: {'bedroom'},
          preferences: preferences,
        ).first,
        bedroom,
      );
      expect(
        suggestRoomTvs(
          devices: [living, bedroom],
          nearbyServices: {'bedroom'},
          preferences: preferences,
          room: 'Living room',
        ),
        [living],
      );
    },
  );
  test('Cast capabilities require matching receiver and media identities', () {
    final cap = CastCapabilities.parse({
      'deviceId': 'receiver',
      'mediaSessionId': 42,
      'seek': true,
      'pause': false,
    })!;
    expect(cap.matches('receiver', 42), isTrue);
    expect(cap.matches('other-room', 42), isFalse);
    expect(cap.matches('receiver', 43), isFalse);
    expect(CastCapabilities.parse({'seek': true}), isNull);
  });
  test(
    'seek windows need explicit support and correctly bound live positions',
    () {
      expect(
        CastSeekWindow.resolve(
          seekSupported: false,
          live: false,
          duration: const Duration(minutes: 5),
        ),
        isNull,
      );
      expect(
        CastSeekWindow.resolve(
          seekSupported: true,
          live: true,
          duration: const Duration(minutes: 5),
        ),
        isNull,
      );
      final live = CastSeekWindow.resolve(
        seekSupported: true,
        live: true,
        liveStart: const Duration(seconds: 20),
        liveEnd: const Duration(seconds: 60),
      )!;
      expect(live.clamp(Duration.zero), const Duration(seconds: 20));
      expect(
        live.clamp(const Duration(seconds: 90)),
        const Duration(seconds: 60),
      );
      expect(
        CastSeekWindow.resolve(
          seekSupported: true,
          live: false,
          duration: Duration.zero,
        ),
        isNull,
      );
    },
  );
  test(
    'TV reporting separates unknown, fresh, and old reports without fabricated percentages',
    () {
      final now = DateTime.utc(2026, 10, 29, 12);
      expect(
        const TvReportedState().describe(now),
        'TV power and volume not reported',
      );
      final state = TvReportedState(
        power: true,
        powerAt: now,
        volumeAt: now,
        volume: const AndroidTvVolumeInfo(level: 12, max: 25, muted: false),
      );
      expect(state.describe(now), 'TV on · Volume 12/25');
      expect(
        state.describe(now.add(const Duration(minutes: 2))),
        contains('Last report:'),
      );
      expect(
        TvReportedState(
          volumeAt: now,
          volume: const AndroidTvVolumeInfo(level: 99, max: 0, muted: false),
        ).describe(now),
        'TV power and volume not reported',
      );
    },
  );
  test(
    'provider templates accept canonical links without claiming playback',
    () {
      final youtube = DestinationTemplates.create(
        DestinationProvider.youtube,
        'Video',
        'https://youtu.be/dQw4w9WgXcQ?si=tracking',
      );
      expect(youtube.launchUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(youtube.packageName, 'com.google.android.youtube.tv');
      final spotify = DestinationTemplates.create(
        DestinationProvider.spotify,
        'Playlist',
        'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=tracking',
      );
      expect(spotify.launchUrl, 'spotify:playlist:37i9dQZF1DXcBWIGoYBM5M');
      expect(
        () => DestinationTemplates.create(
          DestinationProvider.youtube,
          'Video',
          'https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ',
        ),
        throwsFormatException,
      );
      expect(
        () => DestinationTemplates.create(
          DestinationProvider.custom,
          'Unsafe',
          'javascript:alert(1)',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'local measurements are bounded, clearable and contain no device data',
    () {
      final metrics = LocalDiagnostics();
      for (var i = 0; i < 120; i++) {
        metrics.record(
          RemoteMetric.connection,
          Duration(milliseconds: i),
          success: i.isEven,
        );
      }
      expect(metrics.value.length, 100);
      expect(metrics.report(), contains('p95='));
      expect(metrics.report(), contains('not TV execution latency'));
      metrics.clear();
      expect(metrics.report(), contains('no samples'));
    },
  );
  testWidgets(
    'D-pad has distinct accessible direction bounds and labeled 48px targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: DirectionalPad(
                enabled: true,
                onDirection: sent.add,
                onSelect: () => sent.add('select'),
                maxDiameter: 160,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final up = tester.getRect(find.bySemanticsLabel('Up'));
      final right = tester.getRect(find.bySemanticsLabel('Right'));
      final select = tester.getRect(find.bySemanticsLabel('OK, select'));
      expect(up.height, greaterThanOrEqualTo(48));
      expect(up.overlaps(select), isFalse);
      expect(right.overlaps(select), isFalse);
      expect(up.overlaps(right), isFalse);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );
}
