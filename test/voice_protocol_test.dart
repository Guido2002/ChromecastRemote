import 'dart:async';
import 'dart:io';

import 'package:chromecast_remote/core/protocol/android_tv/android_key_codes.dart';
import 'package:chromecast_remote/core/protocol/android_tv/android_tv_remote_client.dart';
import 'package:chromecast_remote/core/protocol/android_tv/certificate_manager.dart';
import 'package:chromecast_remote/core/protocol/android_tv/framing.dart';
import 'package:chromecast_remote/core/protocol/android_tv/proto/remotemessage.pb.dart';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final certificates = CertificateManager(store: InMemorySecureStore());
  Future<
    ({
      AndroidTvRemoteClient client,
      SecureSocket tv,
      Stream<RemoteMessage> outgoing,
      Future<void> Function() dispose,
    })
  >
  connect({
    int features = AndroidTvFeatures.requested,
    Duration idleTimeout = const Duration(seconds: 16),
  }) async {
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      await certificates.buildSecurityContext(),
    );
    final accepted = Completer<SecureSocket>();
    final connections = server.listen(
      accepted.complete,
      onError: (Object error) {},
    );
    final client = AndroidTvRemoteClient(
      certificates: certificates,
      idleTimeout: idleTimeout,
    );
    await client.connect(
      '127.0.0.1',
      port: server.port,
      pinnedServerCertificateSha256: sha256
          .convert(await certificates.certificateDer())
          .toString(),
    );
    final tv = await accepted.future;
    final framing = MessageFraming();
    final messages = StreamController<RemoteMessage>.broadcast(sync: true);
    final receiver = tv.listen((bytes) {
      for (final frame in framing.addData(bytes)) {
        messages.add(RemoteMessage.fromBuffer(frame));
      }
    }, onError: (Object error) {});
    void send(RemoteMessage message) =>
        tv.add(MessageFraming.encode(message.writeToBuffer()));
    send(
      RemoteMessage()..remoteConfigure = (RemoteConfigure()..code1 = features),
    );
    send(RemoteMessage()..remoteStart = (RemoteStart()..started = true));
    await client.ready;
    return (
      client: client,
      tv: tv,
      outgoing: messages.stream,
      dispose: () async {
        await client.dispose();
        tv.destroy();
        await receiver.cancel();
        await messages.close();
        await connections.cancel();
        await server.close();
      },
    );
  }

  void offer(SecureSocket tv, int id) => tv.add(
    MessageFraming.encode(
      RemoteMessage(
        remoteVoiceBegin: RemoteVoiceBegin(sessionId: id),
      ).writeToBuffer(),
    ),
  );
  test(
    'voice waits for TV routing, acknowledges, pads PCM and rejects stale tokens',
    () async {
      final link = await connect();
      addTearDown(link.dispose);
      final search = link.outgoing.firstWhere((m) => m.hasRemoteKeyInject());
      final starting = link.client.startVoice();
      expect((await search).remoteKeyInject.keyCode, 84);
      final begin = link.outgoing.firstWhere((m) => m.hasRemoteVoiceBegin());
      offer(link.tv, 47);
      final session = await starting;
      expect((await begin).remoteVoiceBegin.sessionId, 47);
      final received = link.outgoing.firstWhere(
        (m) => m.hasRemoteVoicePayload(),
      );
      expect(link.client.sendVoiceChunk(session, [1, 2, 3, 4]), isTrue);
      final payload = (await received).remoteVoicePayload;
      expect(payload.sessionId, 47);
      expect(payload.samples.length, 8192);
      expect(payload.samples.take(4), [1, 2, 3, 4]);
      expect(payload.samples.skip(4).every((n) => n == 0), isTrue);
      expect(link.client.sendVoiceChunk(session, [1]), isFalse);
      expect(
        link.client.sendVoiceChunk(session, List.filled(20482, 0)),
        isFalse,
      );
      final ended = link.outgoing.firstWhere((m) => m.hasRemoteVoiceEnd());
      link.client.endVoice(session);
      expect((await ended).remoteVoiceEnd.sessionId, 47);
      expect(link.client.sendVoiceChunk(session, [1, 2]), isFalse);
      final nextSearch = link.outgoing.firstWhere(
        (m) => m.hasRemoteKeyInject(),
      );
      final next = link.client.startVoice();
      await nextSearch;
      offer(link.tv, 47);
      final token = await next;
      expect(identical(session, token), isFalse);
      expect(link.client.sendVoiceChunk(session, [1, 2]), isFalse);
      await link.client.close();
      expect(link.client.sendVoiceChunk(token, [1, 2]), isFalse);
    },
  );
  test(
    'voice capability, timeout and cancellation never create an audio route',
    () async {
      final unsupported = await connect(features: AndroidTvFeatures.key);
      addTearDown(unsupported.dispose);
      expect(unsupported.client.voiceSupported, isFalse);
      await expectLater(unsupported.client.startVoice(), throwsStateError);
      final link = await connect();
      addTearDown(link.dispose);
      await expectLater(
        link.client.startVoice(timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      final search = link.outgoing.firstWhere((m) => m.hasRemoteKeyInject());
      final pending = link.client.startVoice();
      final cancelled = expectLater(pending, throwsStateError);
      await search;
      link.client.cancelVoice();
      await cancelled;
      final messages = <RemoteMessage>[];
      final subscription = link.outgoing.listen(messages.add);
      offer(link.tv, 88);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        messages.where(
          (m) => m.hasRemoteVoiceBegin() || m.hasRemoteVoicePayload(),
        ),
        isEmpty,
      );
      await subscription.cancel();
    },
  );
}
