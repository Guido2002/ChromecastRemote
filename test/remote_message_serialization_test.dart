import 'package:chromecast_remote/core/protocol/android_tv/android_key_codes.dart';
import 'package:chromecast_remote/core/protocol/android_tv/framing.dart';
import 'package:chromecast_remote/core/protocol/android_tv/proto/polo.pb.dart';
import 'package:chromecast_remote/core/protocol/android_tv/proto/remotemessage.pb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteMessage key inject serialization', () {
    test('encodes D-pad up short press to the exact wire format', () {
      final message = RemoteMessage()
        ..remoteKeyInject = (RemoteKeyInject()
          ..keyCode = AndroidKeyCodes.dpadUp
          ..direction = RemoteDirection.SHORT);

      // field 10 (remote_key_inject), length-delimited: tag 0x52
      // inner: field 1 varint 19 (0x08 0x13), field 2 varint 3 (0x10 0x03)
      expect(
        message.writeToBuffer(),
        [0x52, 0x04, 0x08, 0x13, 0x10, 0x03],
      );
    });

    test('round-trips all required remote key codes', () {
      for (final keyCode in [
        AndroidKeyCodes.dpadUp, // 19
        AndroidKeyCodes.dpadDown, // 20
        AndroidKeyCodes.dpadLeft, // 21
        AndroidKeyCodes.dpadRight, // 22
        AndroidKeyCodes.dpadCenter, // 23
        AndroidKeyCodes.back, // 4
        AndroidKeyCodes.home, // 3
        AndroidKeyCodes.power, // 26
        AndroidKeyCodes.volumeUp, // 24
        AndroidKeyCodes.volumeDown, // 25
        AndroidKeyCodes.mute, // 164
        AndroidKeyCodes.mediaPlayPause, // 85
      ]) {
        final message = RemoteMessage()
          ..remoteKeyInject = (RemoteKeyInject()
            ..keyCode = keyCode
            ..direction = RemoteDirection.SHORT);
        final parsed = RemoteMessage.fromBuffer(message.writeToBuffer());
        expect(parsed.remoteKeyInject.keyCode, keyCode);
        expect(parsed.remoteKeyInject.direction, RemoteDirection.SHORT);
      }
    });

    test('encodes long-press start/end directions', () {
      for (final (direction, value) in [
        (RemoteDirection.START_LONG, 0x01),
        (RemoteDirection.END_LONG, 0x02),
      ]) {
        final message = RemoteMessage()
          ..remoteKeyInject = (RemoteKeyInject()
            ..keyCode = AndroidKeyCodes.volumeUp
            ..direction = direction);
        final bytes = message.writeToBuffer();
        // direction is the last field: tag 0x10 then the enum value.
        expect(bytes.last, value);
      }
    });

    test('parses a ping request and builds the matching response', () {
      // RemoteMessage { remote_ping_request { val1: 42 } }
      // field 8 tag = 0x42, inner: field 1 varint 42 = 0x08 0x2A
      final parsed = RemoteMessage.fromBuffer([0x42, 0x02, 0x08, 0x2A]);
      expect(parsed.hasRemotePingRequest(), isTrue);
      expect(parsed.remotePingRequest.val1, 42);

      final response = RemoteMessage()
        ..remotePingResponse =
            (RemotePingResponse()..val1 = parsed.remotePingRequest.val1);
      // field 9 tag = 0x4A
      expect(response.writeToBuffer(), [0x4A, 0x02, 0x08, 0x2A]);
    });

    test('parses a volume level update', () {
      final message = RemoteMessage()
        ..remoteSetVolumeLevel = (RemoteSetVolumeLevel()
          ..volumeMax = 25
          ..volumeLevel = 12
          ..volumeMuted = false);
      final parsed = RemoteMessage.fromBuffer(message.writeToBuffer());
      expect(parsed.hasRemoteSetVolumeLevel(), isTrue);
      expect(parsed.remoteSetVolumeLevel.volumeMax, 25);
      expect(parsed.remoteSetVolumeLevel.volumeLevel, 12);
      expect(parsed.remoteSetVolumeLevel.volumeMuted, isFalse);
    });
  });

  group('Framed protobuf round-trip', () {
    test('framed key inject survives encode/decode intact', () {
      final framing = MessageFraming();
      final message = RemoteMessage()
        ..remoteKeyInject = (RemoteKeyInject()
          ..keyCode = AndroidKeyCodes.dpadCenter
          ..direction = RemoteDirection.SHORT);
      final decoded =
          framing.addData(MessageFraming.encode(message.writeToBuffer()));
      expect(decoded, hasLength(1));
      expect(
        RemoteMessage.fromBuffer(decoded.single).remoteKeyInject.keyCode,
        AndroidKeyCodes.dpadCenter,
      );
    });
  });

  group('Pairing protocol (polo) serialization', () {
    test('builds the protocol-version-2 pairing request', () {
      final message = OuterMessage()
        ..protocolVersion = 2
        ..status = OuterMessage_Status.STATUS_OK
        ..pairingRequest = (PairingRequest()
          ..serviceName = 'atvremote'
          ..clientName = 'Chromecast Remote');

      final parsed = OuterMessage.fromBuffer(message.writeToBuffer());
      expect(parsed.protocolVersion, 2);
      expect(parsed.status, OuterMessage_Status.STATUS_OK);
      expect(parsed.hasPairingRequest(), isTrue);
      expect(parsed.pairingRequest.serviceName, 'atvremote');
      expect(parsed.pairingRequest.clientName, 'Chromecast Remote');
    });

    test('round-trips options, configuration and secret messages', () {
      final options = OuterMessage()
        ..protocolVersion = 2
        ..status = OuterMessage_Status.STATUS_OK
        ..options = (Options()
          ..preferredRole = Options_RoleType.ROLE_TYPE_INPUT
          ..inputEncodings.add(Options_Encoding()
            ..type = Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL
            ..symbolLength = 6));
      final parsedOptions = OuterMessage.fromBuffer(options.writeToBuffer());
      expect(parsedOptions.options.preferredRole,
          Options_RoleType.ROLE_TYPE_INPUT);
      expect(parsedOptions.options.inputEncodings.single.symbolLength, 6);

      final secret = OuterMessage()
        ..protocolVersion = 2
        ..status = OuterMessage_Status.STATUS_OK
        ..secret = (Secret()..secret = List.filled(32, 0xAB));
      final parsedSecret = OuterMessage.fromBuffer(secret.writeToBuffer());
      expect(parsedSecret.hasSecret(), isTrue);
      expect(parsedSecret.secret.secret, List.filled(32, 0xAB));
    });
  });
}
