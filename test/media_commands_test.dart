import 'package:chromecast_remote/core/protocol/android_tv/android_key_codes.dart';
import 'package:chromecast_remote/core/protocol/android_tv/proto/remotemessage.pb.dart';
import 'package:chromecast_remote/features/remote/android_tv_remote_controller.dart';
import 'package:chromecast_remote/features/remote/remote_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keyCodeForCommand', () {
    test('maps media commands to the Android media key codes', () {
      expect(keyCodeForCommand(RemoteCommand.playPause), 85);
      expect(keyCodeForCommand(RemoteCommand.stop), 86);
      expect(keyCodeForCommand(RemoteCommand.next), 87);
      expect(keyCodeForCommand(RemoteCommand.previous), 88);
      expect(keyCodeForCommand(RemoteCommand.rewind), 89);
      expect(keyCodeForCommand(RemoteCommand.fastForward), 90);
      expect(keyCodeForCommand(RemoteCommand.play), 126);
      expect(keyCodeForCommand(RemoteCommand.pause), 127);
    });

    test('existing navigation and volume mappings are unchanged', () {
      expect(keyCodeForCommand(RemoteCommand.up), AndroidKeyCodes.dpadUp);
      expect(keyCodeForCommand(RemoteCommand.down), AndroidKeyCodes.dpadDown);
      expect(keyCodeForCommand(RemoteCommand.left), AndroidKeyCodes.dpadLeft);
      expect(keyCodeForCommand(RemoteCommand.right), AndroidKeyCodes.dpadRight);
      expect(keyCodeForCommand(RemoteCommand.select),
          AndroidKeyCodes.dpadCenter);
      expect(keyCodeForCommand(RemoteCommand.back), AndroidKeyCodes.back);
      expect(keyCodeForCommand(RemoteCommand.home), AndroidKeyCodes.home);
      expect(keyCodeForCommand(RemoteCommand.power), AndroidKeyCodes.power);
      expect(
          keyCodeForCommand(RemoteCommand.volumeUp), AndroidKeyCodes.volumeUp);
      expect(keyCodeForCommand(RemoteCommand.volumeDown),
          AndroidKeyCodes.volumeDown);
      expect(keyCodeForCommand(RemoteCommand.mute), AndroidKeyCodes.mute);
    });
  });

  group('media key serialization', () {
    test('all media commands serialize to valid key-inject messages', () {
      for (final command in [
        RemoteCommand.playPause,
        RemoteCommand.play,
        RemoteCommand.pause,
        RemoteCommand.stop,
        RemoteCommand.next,
        RemoteCommand.previous,
        RemoteCommand.rewind,
        RemoteCommand.fastForward,
      ]) {
        final message = RemoteMessage()
          ..remoteKeyInject = (RemoteKeyInject()
            ..keyCode = keyCodeForCommand(command)
            ..direction = RemoteDirection.SHORT);
        final parsed = RemoteMessage.fromBuffer(message.writeToBuffer());
        expect(parsed.hasRemoteKeyInject(), isTrue, reason: '$command');
        expect(parsed.remoteKeyInject.keyCode, keyCodeForCommand(command),
            reason: '$command');
        expect(parsed.remoteKeyInject.direction, RemoteDirection.SHORT,
            reason: '$command');
      }
    });

    test('key-down and key-up directions serialize distinctly', () {
      RemoteMessage build(RemoteDirection direction) => RemoteMessage()
        ..remoteKeyInject = (RemoteKeyInject()
          ..keyCode = AndroidKeyCodes.mediaPlayPause
          ..direction = direction);

      final down = build(RemoteDirection.START_LONG).writeToBuffer();
      final up = build(RemoteDirection.END_LONG).writeToBuffer();
      final tap = build(RemoteDirection.SHORT).writeToBuffer();

      expect(down.last, 1);
      expect(up.last, 2);
      expect(tap.last, 3);
      // Only the direction byte differs.
      expect(down.length, up.length);
      expect(down.sublist(0, down.length - 1),
          up.sublist(0, up.length - 1));
    });

    test('rapid identical presses each produce an independent message', () {
      // Rapid presses are framed individually; no deduplication or merging
      // happens at the serialization layer.
      RemoteMessage playPause() => RemoteMessage()
        ..remoteKeyInject = (RemoteKeyInject()
          ..keyCode = AndroidKeyCodes.mediaPlayPause
          ..direction = RemoteDirection.SHORT);

      final first = playPause().writeToBuffer();
      final second = playPause().writeToBuffer();
      expect(first, second);
      expect(first, [0x52, 0x04, 0x08, 0x55, 0x10, 0x03]); // 85 = 0x55
    });
  });
}
