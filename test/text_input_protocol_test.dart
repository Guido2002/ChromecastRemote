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

  test(
    'TLS input uses TV counters, rejects old fields, and keeps Enter separate',
    () async {
      final link = await connect();
      addTearDown(link.dispose);
      final ready = link.client.textInput.changes.firstWhere(
        (session) => session != null,
      );
      link.tv.add(
        MessageFraming.encode(
          (RemoteMessage()
                ..remoteImeBatchEdit = RemoteImeBatchEdit(
                  imeCounter: 71,
                  fieldCounter: 39,
                  editInfo: [
                    RemoteEditInfo(
                      textFieldStatus: RemoteImeObject(
                        value: 'TV private value',
                      ),
                    ),
                  ],
                ))
              .writeToBuffer(),
        ),
      );
      final token = (await ready)!;
      final requested = link.outgoing.firstWhere(
        (message) => message.hasRemoteImeBatchEdit(),
      );
      expect(link.client.sendText('é😀', token), isTrue);
      final batch = (await requested).remoteImeBatchEdit;
      expect(batch.imeCounter, 71);
      expect(batch.fieldCounter, 39);
      expect(batch.editInfo.single.textFieldStatus.value, 'é😀');
      expect(batch.editInfo.single.textFieldStatus.start, 1);
      final enter = link.outgoing.firstWhere(
        (message) => message.hasRemoteKeyInject(),
      );
      expect(link.client.sendTextEnter(token), isTrue);
      expect((await enter).remoteKeyInject.keyCode, 66);
      final changed = link.client.textInput.changes.firstWhere(
        (session) => session?.fieldCounter == 40,
      );
      link.tv.add(
        MessageFraming.encode(
          (RemoteMessage()
                ..remoteImeBatchEdit = RemoteImeBatchEdit(
                  imeCounter: 71,
                  fieldCounter: 40,
                ))
              .writeToBuffer(),
        ),
      );
      await changed;
      expect(link.client.sendText('stale draft', token), isFalse);
      expect(link.client.sendTextEnter(token), isFalse);
      await link.client.close();
      expect(link.client.textInput.session, isNull);
      expect(link.client.sendText('offline draft', token), isFalse);
    },
  );

  test(
    'a TV that declines IME never enables input from unsolicited counters',
    () async {
      final link = await connect(
        features: AndroidTvFeatures.key | AndroidTvFeatures.ping,
      );
      addTearDown(link.dispose);
      link.tv.add(
        MessageFraming.encode(
          (RemoteMessage()
                ..remoteImeBatchEdit = RemoteImeBatchEdit(
                  imeCounter: 71,
                  fieldCounter: 39,
                ))
              .writeToBuffer(),
        ),
      );
      final ping = link.outgoing.firstWhere(
        (message) => message.hasRemotePingResponse(),
      );
      link.tv.add(
        MessageFraming.encode(
          (RemoteMessage()..remotePingRequest = RemotePingRequest(val1: 99))
              .writeToBuffer(),
        ),
      );
      await ping; // Proves the counter packet ahead of it has been processed.
      expect(link.client.textInput.session, isNull);
    },
  );

  test(
    'outgoing activity keeps a healthy session alive when idle pings stop',
    () async {
      final link = await connect(
        idleTimeout: const Duration(milliseconds: 400),
      );
      addTearDown(link.dispose);
      final dropped = Completer<void>();
      link.client.onDisconnected = (_) {
        if (!dropped.isCompleted) dropped.complete();
      };
      final traffic = Timer.periodic(
        const Duration(milliseconds: 40),
        (_) => link.client.sendKey(AndroidKeyCodes.dpadUp),
      );
      try {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(link.client.isConnected, isTrue);
        expect(dropped.isCompleted, isFalse);
      } finally {
        traffic.cancel();
      }
      await dropped.future.timeout(const Duration(seconds: 2));
      expect(link.client.isConnected, isFalse);
    },
  );
}
