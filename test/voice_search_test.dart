import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chromecast_remote/features/remote/remote_controller.dart';
import 'package:chromecast_remote/features/remote/voice/voice_search.dart';
import 'support/fake_voice.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'release while permission is pending never records or contacts TV',
    () async {
      final mic = FakeMicrophone()..permission = Completer<bool>();
      final tv = FakeVoiceTv();
      final voice = VoiceSearchController(target: tv, microphone: mic);
      final start = voice.start();
      final stop = voice.stop();
      mic.permission!.complete(true);
      await start;
      await stop;
      expect(mic.starts, 0);
      expect(tv.starts, 0);
      expect(voice.busy, isFalse);
      voice.dispose();
      await tv.states.close();
    },
  );
  test('denied permission reports recovery and never starts capture', () async {
    final mic = FakeMicrophone()..allowed = false;
    final tv = FakeVoiceTv();
    final voice = VoiceSearchController(target: tv, microphone: mic);
    await voice.start();
    expect(voice.message, contains('permission'));
    expect(tv.starts, 0);
    expect(mic.starts, 0);
    voice.dispose();
    await tv.states.close();
  });
  test(
    'aggregates microphone callbacks, flushes final audio and ends exactly once',
    () async {
      final mic = FakeMicrophone();
      final tv = FakeVoiceTv();
      final voice = VoiceSearchController(target: tv, microphone: mic);
      await voice.start();
      expect(voice.recording, isTrue);
      mic.audio.add(Uint8List.fromList(List.filled(4000, 1)));
      expect(tv.sent, isEmpty);
      mic.audio.add(Uint8List.fromList(List.filled(5000, 2)));
      expect(tv.sent.single.length, 8192);
      expect(tv.sent.single.take(4000).every((n) => n == 1), isTrue);
      await voice.stop();
      expect(tv.sent.map((c) => c.length), [8192, 808]);
      expect(tv.ends, 1);
      expect(voice.message, contains('Check the result'));
      expect(voice.busy, isFalse);
      await voice.stop();
      expect(tv.ends, 1);
      voice.dispose();
      await tv.states.close();
    },
  );
  test(
    'cancel drops buffered audio and no request is redirected after target change',
    () async {
      final mic = FakeMicrophone();
      final tv = FakeVoiceTv();
      var current = true;
      final voice = VoiceSearchController(
        target: tv,
        microphone: mic,
        isCurrentTarget: () => current,
      );
      await voice.start();
      mic.audio.add(Uint8List(500));
      current = false;
      mic.audio.add(Uint8List(9000));
      await flush();
      await voice.stop(cancel: true);
      expect(tv.sent, isEmpty);
      expect(voice.recording, isFalse);
      voice.dispose();
      await tv.states.close();
    },
  );
  test(
    'disconnect cancels a pending TV handshake without opening the microphone',
    () async {
      final mic = FakeMicrophone();
      final tv = FakeVoiceTv()..pending = Completer<Object>();
      final voice = VoiceSearchController(target: tv, microphone: mic);
      final start = voice.start();
      await flush();
      tv.voiceSupported = false;
      tv.states.add(RemoteConnectionState.disconnected);
      await start;
      await voice.stop(cancel: true);
      expect(mic.starts, 0);
      expect(voice.busy, isFalse);
      expect(tv.sent, isEmpty);
      voice.dispose();
      await tv.states.close();
    },
  );
  test(
    'recording stops at duration limit and bounds accepted PCM bytes',
    () async {
      final mic = FakeMicrophone();
      final tv = FakeVoiceTv();
      final voice = VoiceSearchController(
        target: tv,
        microphone: mic,
        maxDuration: const Duration(milliseconds: 10),
      );
      await voice.start();
      mic.audio.add(Uint8List(16000));
      await flush();
      await voice.stop();
      expect(tv.sent.fold<int>(0, (n, chunk) => n + chunk.length), 160);
      expect(voice.busy, isFalse);
      voice.dispose();
      await tv.states.close();
    },
  );
}
