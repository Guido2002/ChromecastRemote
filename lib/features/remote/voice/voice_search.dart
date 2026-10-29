import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../remote_controller.dart';

abstract interface class TvVoiceTarget {
  String get deviceName;
  bool get voiceSupported;
  Stream<RemoteConnectionState> get connectionStates;
  Future<Object> beginVoice();
  bool sendVoice(Object session, Uint8List samples);
  void finishVoice(Object session);
  void cancelVoice();
}

abstract interface class VoiceMicrophone {
  Future<bool> requestPermission();
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

class RecordVoiceMicrophone implements VoiceMicrophone {
  final _recorder = AudioRecorder();
  @override
  Future<bool> requestPermission() => _recorder.hasPermission();
  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 8000,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    ),
  );
  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

enum VoiceSearchPhase { idle, permission, connecting, recording, stopping }

/// One explicit, bounded microphone request. Audio stays in memory and goes
/// only to the same TV's negotiated session. There is no transcript or file.
class VoiceSearchController extends ChangeNotifier {
  VoiceSearchController({
    required this.target,
    required this.microphone,
    this.maxDuration = const Duration(seconds: 10),
    bool Function()? isCurrentTarget,
  }) : _isCurrentTarget = isCurrentTarget ?? (() => true) {
    _connection = target.connectionStates.listen((state) {
      if (state != RemoteConnectionState.connected) {
        unawaited(stop(cancel: true));
      }
    });
  }
  final TvVoiceTarget target;
  final VoiceMicrophone microphone;
  final Duration maxDuration;
  final bool Function() _isCurrentTarget;
  VoiceSearchPhase phase = VoiceSearchPhase.idle;
  String? message;
  bool _requested = false, _disposed = false, _discard = false;
  Object? _session;
  Future<void>? _starting, _stopping;
  StreamSubscription<Uint8List>? _audio;
  StreamSubscription<RemoteConnectionState>? _connection;
  Timer? _limit;
  final _pending = <int>[];
  int _totalBytes = 0;
  bool get busy => phase != VoiceSearchPhase.idle;
  bool get recording => phase == VoiceSearchPhase.recording;
  bool get _valid =>
      _requested && !_disposed && _isCurrentTarget() && target.voiceSupported;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() {
    if (busy || _disposed || !_isCurrentTarget() || !target.voiceSupported) {
      return Future.value();
    }
    _requested = true;
    _discard = false;
    _totalBytes = 0;
    message = null;
    phase = VoiceSearchPhase.permission;
    _changed();
    return _starting = _start();
  }

  Future<void> _start() async {
    try {
      if (!await microphone.requestPermission()) {
        if (_requested) {
          message =
              'Microphone permission is off. Enable it in your phone settings to use voice search.';
        }
        return;
      }
      if (!_valid) return;
      phase = VoiceSearchPhase.connecting;
      _changed();
      final session = await target.beginVoice();
      _session = session;
      if (!_valid) return;
      final stream = await microphone.start();
      if (!_valid) return;
      phase = VoiceSearchPhase.recording;
      _changed();
      _audio = stream.listen(
        _onAudio,
        onError: (Object _) {
          message = 'Microphone recording failed. Try again.';
          unawaited(stop(cancel: true));
        },
        onDone: () {
          if (recording) unawaited(stop());
        },
      );
      _limit = Timer(maxDuration, () => unawaited(stop()));
    } catch (_) {
      if (_requested) {
        message =
            'Voice search could not start. Check the TV and microphone, then try again.';
      }
    } finally {
      if (phase != VoiceSearchPhase.recording) {
        try {
          await microphone.stop();
        } catch (_) {
          /* Nothing recorded. */
        }
        final session = _session;
        _session = null;
        if (session != null) target.finishVoice(session);
        _requested = false;
        if (_stopping == null) phase = VoiceSearchPhase.idle;
        _changed();
      }
    }
  }

  void _onAudio(Uint8List bytes) {
    if (_discard ||
        _session == null ||
        !_isCurrentTarget() ||
        !target.voiceSupported) {
      unawaited(stop(cancel: true));
      return;
    }
    // Also bound bytes if a recorder or clock misbehaves (8 kHz, PCM16 mono).
    final remaining = 16000 * maxDuration.inMilliseconds ~/ 1000 - _totalBytes;
    final accepted = bytes.length.clamp(0, remaining < 0 ? 0 : remaining);
    _totalBytes += accepted;
    _pending.addAll(bytes.take(accepted));
    while (_pending.length >= 8192) {
      final chunk = Uint8List.fromList(_pending.take(8192).toList());
      _pending.removeRange(0, 8192);
      if (!target.sendVoice(_session!, chunk)) {
        message =
            'The TV voice session ended. Hold the microphone to try again.';
        unawaited(stop(cancel: true));
        return;
      }
    }
    if (accepted < bytes.length || remaining <= bytes.length) unawaited(stop());
  }

  Future<void> stop({bool cancel = false}) {
    if (_stopping != null) {
      if (cancel) {
        _discard = true;
        target.cancelVoice();
      }
      return _stopping!;
    }
    if (!busy) return Future.value();
    _requested = false;
    _discard = cancel;
    _limit?.cancel();
    phase = VoiceSearchPhase.stopping;
    if (_session == null || cancel) target.cancelVoice();
    _changed();
    // Defer so _stopping exists before asynchronous cleanup can finish.
    return _stopping = Future<void>.microtask(() async {
      await _starting;
      try {
        await microphone.stop();
      } catch (_) {
        /* Cleanup is best effort. */
      }
      await _audio?.cancel();
      _audio = null;
      final session = _session;
      _session = null;
      if (session != null) {
        if (!_discard &&
            _isCurrentTarget() &&
            target.voiceSupported &&
            _pending.isNotEmpty) {
          // A truncated PCM sample must never alter sample alignment.
          if (_pending.length.isOdd) _pending.removeLast();
          if (_pending.isNotEmpty &&
              !target.sendVoice(session, Uint8List.fromList(_pending))) {
            _discard = true;
          }
        }
        target.finishVoice(session);
      }
      _pending.clear();
      if (message == null && _totalBytes > 0) {
        message = _discard
            ? 'Voice request cancelled. Audio already sent cannot be recalled.'
            : 'Voice request sent. Check the result on ${target.deviceName}.';
      }
      phase = VoiceSearchPhase.idle;
      _starting = null;
      _stopping = null;
      _changed();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _connection?.cancel();
    unawaited(stop(cancel: true).whenComplete(microphone.dispose));
    super.dispose();
  }
}
