import 'dart:async';
import 'dart:io';

import 'package:chromecast_remote/core/protocol/android_tv/android_tv_remote_client.dart';
import 'package:chromecast_remote/core/protocol/android_tv/certificate_manager.dart';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unexpected TLS socket closure notifies reconnection listeners',
    () async {
      final certificates = CertificateManager(store: InMemorySecureStore());
      final context = await certificates.buildSecurityContext();
      final pin = sha256
          .convert(await certificates.certificateDer())
          .toString();
      final server = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      final accepted = Completer<SecureSocket>();
      final subscription = server.listen(
        accepted.complete,
        onError: (Object error) {},
      );
      final client = AndroidTvRemoteClient(certificates: certificates);
      final dropped = Completer<String>();
      client.onDisconnected = (reason) {
        if (!dropped.isCompleted) dropped.complete(reason);
      };
      try {
        await client.connect(
          '127.0.0.1',
          port: server.port,
          pinnedServerCertificateSha256: pin,
        );
        final socket = await accepted.future;
        socket.destroy();
        expect(
          await dropped.future.timeout(const Duration(seconds: 3)),
          isNotEmpty,
        );
        expect(client.isConnected, isFalse);
      } finally {
        await client.dispose();
        await subscription.cancel();
        await server.close();
      }
    },
  );

  test('explicit closure never requests reconnection', () async {
    final certificates = CertificateManager(store: InMemorySecureStore());
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      await certificates.buildSecurityContext(),
    );
    final accepted = Completer<SecureSocket>();
    final subscription = server.listen(
      accepted.complete,
      onError: (Object error) {},
    );
    final client = AndroidTvRemoteClient(certificates: certificates);
    var dropped = false;
    client.onDisconnected = (_) => dropped = true;
    try {
      await client.connect(
        '127.0.0.1',
        port: server.port,
        pinnedServerCertificateSha256: sha256
            .convert(await certificates.certificateDer())
            .toString(),
      );
      final socket = await accepted.future;
      await client.close();
      socket.destroy();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(dropped, isFalse);
    } finally {
      await client.dispose();
      await subscription.cancel();
      await server.close();
    }
  });
}
