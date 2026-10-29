import 'dart:convert';
import 'dart:io';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/tv_app.dart';
import 'package:chromecast_remote/features/automation/routines.dart';
import 'package:chromecast_remote/features/remote/remote_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_tv_controller.dart';

void main() {
  final app = catalogApps.first;
  final routine = TvAudioRoutine(
    id: 'routine',
    name: 'Watch TV',
    tvId: 'living-room',
    appId: app.id,
    entity: 'media_player.audio',
    volume: .2,
  );
  test(
    'connections reject credential URLs, remote HTTP and invalid tokens',
    () {
      for (final url in [
        'https://name:password@example.com',
        'http://example.com',
        'file:///private',
        'https://example.com?token=secret',
      ]) {
        expect(() => HomeAssistantConfig(url, 'token'), throwsFormatException);
      }
      expect(
        () => HomeAssistantConfig('http://127.0.0.1:8123', 'token'),
        returnsNormally,
      );
      expect(
        () => HomeAssistantConfig('https://example.com', 'token\nleak'),
        throwsFormatException,
      );
    },
  );
  test(
    'routines and Home Assistant configuration persist separately from pairing',
    () async {
      final store = RoutineStore(InMemorySecureStore());
      await store.save(routine);
      await store.saveConfig(
        HomeAssistantConfig('https://example.com', 'secret-token'),
      );
      expect((await store.load()).single.tvId, routine.tvId);
      expect((await store.loadConfig())!.base.host, 'example.com');
      await store.clearConfig();
      expect(await store.loadConfig(), isNull);
      expect((await store.load()).length, 1);
    },
  );

  for (final scenario in [
    'success',
    'not-confirmed',
    'wrong-tv',
    'cancel',
    'redirect',
  ]) {
    test(
      'routine $scenario respects acknowledgements, target identity and cancellation',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final redirectReceiver = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        var redirected = 0;
        final redirectSubscription = redirectReceiver.listen((request) {
          redirected++;
          request.response.statusCode = 403;
          request.response.close();
        });
        final cancel = RoutineCancellation();
        var posts = 0;
        var audioRequested = false;
        final subscription = server.listen((request) async {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer fixture-token',
          );
          if (scenario == 'redirect') {
            request.response.statusCode = 302;
            request.response.headers.set(
              HttpHeaders.locationHeader,
              'http://127.0.0.1:${redirectReceiver.port}/',
            );
          } else if (request.method == 'POST') {
            final body = jsonDecode(await utf8.decoder.bind(request).join());
            expect(body, {
              'entity_id': 'media_player.audio',
              'volume_level': .2,
            });
            posts++;
            audioRequested = true;
            if (scenario == 'cancel') cancel.cancel();
            request.response.headers.contentType = ContentType.json;
            request.response.write('[]');
          } else {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'state': 'on',
                'attributes': {
                  'supported_features': 4,
                  'volume_level': audioRequested && scenario != 'not-confirmed'
                      ? .2
                      : .8,
                },
              }),
            );
          }
          try {
            await request.response.close();
          } catch (_) {
            /* Cancellation closes the client. */
          }
        });
        final target = FakeTvController(testTv())..foreground = app.packageName;
        try {
          final result = await runTvAudioRoutine(
            routine: routine,
            app: app,
            audio: HomeAssistantClient(
              HomeAssistantConfig(
                'http://127.0.0.1:${server.port}',
                'fixture-token',
              ),
            ),
            tv: target,
            tvId: scenario == 'wrong-tv' ? 'bedroom' : 'living-room',
            isCurrentTarget: () => true,
            cancellation: cancel,
            pollInterval: Duration.zero,
            launchTimeout: Duration.zero,
          );
          if (scenario == 'success') {
            expect(result.outcome, RoutineOutcome.completed);
            expect(target.links, [app.launchUrl]);
            expect(posts, 1);
          } else {
            expect(target.links, isEmpty);
            expect(
              result.outcome,
              scenario == 'cancel'
                  ? RoutineOutcome.cancelled
                  : scenario == 'not-confirmed'
                  ? RoutineOutcome.partial
                  : RoutineOutcome.failed,
            );
          }
          expect(
            target.commands,
            isEmpty,
            reason: 'Routines must never issue timed key macros.',
          );
          expect(
            redirected,
            0,
            reason:
                'Credentials must never follow a redirect to another origin.',
          );
        } finally {
          await target.dispose();
          await subscription.cancel();
          await server.close(force: true);
          await redirectSubscription.cancel();
          await redirectReceiver.close(force: true);
        }
      },
    );
  }
  test(
    'routine rejects a missing or changed TV connection before touching audio',
    () async {
      final tv = FakeTvController(testTv())
        ..state = RemoteConnectionState.disconnected;
      final result = await runTvAudioRoutine(
        routine: routine,
        app: app,
        audio: HomeAssistantClient(
          HomeAssistantConfig('http://127.0.0.1:1', 'token'),
        ),
        tv: tv,
        tvId: 'living-room',
        isCurrentTarget: () => true,
        cancellation: RoutineCancellation(),
      );
      expect(result.outcome, RoutineOutcome.failed);
      expect(tv.links, isEmpty);
      await tv.dispose();
    },
  );
}
