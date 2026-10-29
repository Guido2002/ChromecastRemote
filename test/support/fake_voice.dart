import 'dart:async';
import 'dart:typed_data';
import 'package:chromecast_remote/features/remote/remote_controller.dart';
import 'package:chromecast_remote/features/remote/voice/voice_search.dart';

class FakeMicrophone implements VoiceMicrophone {
  bool allowed = true;
  int starts = 0, stops = 0;
  Completer<bool>? permission;
  final audio = StreamController<Uint8List>.broadcast(sync: true);
  @override
  Future<bool> requestPermission() async =>
      permission == null ? allowed : permission!.future;
  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    return audio.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await audio.close();
  }
}

class FakeVoiceTv implements TvVoiceTarget {
  @override
  String deviceName = 'Living room';
  @override
  bool voiceSupported = true;
  final states = StreamController<RemoteConnectionState>.broadcast(sync: true);
  @override
  Stream<RemoteConnectionState> get connectionStates => states.stream;
  int starts = 0, ends = 0;
  final sent = <Uint8List>[];
  Object? session;
  Completer<Object>? pending;
  @override
  Future<Object> beginVoice() async {
    starts++;
    return session = pending == null ? Object() : await pending!.future;
  }

  @override
  bool sendVoice(Object token, Uint8List samples) {
    if (!voiceSupported || token != session) return false;
    sent.add(samples);
    return true;
  }

  @override
  void finishVoice(Object token) {
    if (session == token) {
      ends++;
      session = null;
    }
  }

  @override
  void cancelVoice() {
    session = null;
    if (pending != null && !pending!.isCompleted) {
      pending!.completeError(StateError('cancel'));
    }
  }
}
