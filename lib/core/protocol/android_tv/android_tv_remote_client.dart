import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'android_key_codes.dart';
import 'certificate_manager.dart';
import 'framing.dart';
import 'text_input.dart';
import 'proto/remotemessage.pb.dart';

/// Device information reported by the TV in the RemoteConfigure handshake.
class AndroidTvDeviceInfo {
  const AndroidTvDeviceInfo({
    required this.vendor,
    required this.model,
    required this.appVersion,
  });

  final String vendor;
  final String model;
  final String appVersion;
}

/// Volume state reported by the TV.
class AndroidTvVolumeInfo {
  const AndroidTvVolumeInfo({
    required this.level,
    required this.max,
    required this.muted,
  });

  final int level;
  final int max;
  final bool muted;
}

/// Thrown when connecting to the remote port fails.
class RemoteConnectionException implements Exception {
  const RemoteConnectionException(this.message, {this.requiresPairing = false});

  final String message;

  /// True when the failure indicates the TV no longer trusts us and the user
  /// must pair again (TLS rejection of our client certificate).
  final bool requiresPairing;

  @override
  String toString() => message;
}

/// Opaque routing token. Even a repeated numeric TV session ID cannot reuse
/// a token from an earlier request or connection.
class AndroidTvVoiceSession {
  AndroidTvVoiceSession._(this.id);
  final int id;
}

/// Android TV Remote Protocol v2 client for the remote port (6466).
///
/// Mirrors https://github.com/tronikos/androidtvremote2 remote.py:
///  * answers RemoteConfigure with our own device info + negotiated features,
///  * answers RemoteSetActive,
///  * echoes RemotePingRequest (the TV pings every ~5 s when idle),
///  * exposes volume / current-app / power-state updates,
///  * closes an idle connection after 16 seconds without traffic. TVs may
///    stop sending idle pings while receiving commands.
class AndroidTvRemoteClient {
  AndroidTvRemoteClient({
    required this.certificates,
    this.idleTimeout = const Duration(seconds: 16),
  });

  static const defaultPort = 6466;

  final Duration idleTimeout;

  final CertificateManager certificates;
  final MessageFraming _framing = MessageFraming();

  SecureSocket? _socket;
  StreamSubscription<List<int>>? _subscription;
  Timer? _idleTimer;
  Completer<void>? _readyCompleter;
  bool _closedByUs = false;
  int _connectionEpoch = 0;

  int _activeFeatures = AndroidTvFeatures.requested;
  final textInput = AndroidTvTextInput();
  Completer<AndroidTvVoiceSession>? _voiceReady;
  AndroidTvVoiceSession? _voiceSession;

  bool get voiceSupported =>
      isConnected &&
      _activeFeatures & AndroidTvFeatures.voice != 0 &&
      _activeFeatures & AndroidTvFeatures.key != 0;

  Future<AndroidTvVoiceSession> startVoice({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!voiceSupported) throw StateError('Voice input is unavailable.');
    if (_voiceReady != null || _voiceSession != null) {
      throw StateError('A voice request is already active.');
    }
    final ready = Completer<AndroidTvVoiceSession>();
    _voiceReady = ready;
    try {
      sendKey(AndroidKeyCodes.search);
      final session = await ready.future.timeout(timeout);
      if (!identical(_voiceReady, ready) || !voiceSupported) {
        throw StateError('Voice request cancelled.');
      }
      _send(
        RemoteMessage()
          ..remoteVoiceBegin = RemoteVoiceBegin(sessionId: session.id),
      );
      return session;
    } catch (_) {
      if (identical(_voiceReady, ready)) cancelVoice();
      rethrow;
    } finally {
      if (identical(_voiceReady, ready)) _voiceReady = null;
    }
  }

  /// PCM is accumulated by the recorder before this call. Only the final
  /// short frame is padded; padding every microphone callback distorts audio.
  bool sendVoiceChunk(AndroidTvVoiceSession session, List<int> samples) {
    if (!voiceSupported ||
        !identical(_voiceSession, session) ||
        samples.isEmpty ||
        samples.length > 20 * 1024 ||
        samples.length.isOdd) {
      return false;
    }
    final payload = samples.length < 8 * 1024
        ? (Uint8List(8 * 1024)..setRange(0, samples.length, samples))
        : samples;
    try {
      _send(
        RemoteMessage()
          ..remoteVoicePayload = RemoteVoicePayload(
            sessionId: session.id,
            samples: payload,
          ),
      );
      return true;
    } catch (_) {
      _dropConnection('Could not send voice audio to the TV.');
      return false;
    }
  }

  void endVoice(AndroidTvVoiceSession session) {
    if (!identical(_voiceSession, session)) return;
    cancelVoice();
  }

  void cancelVoice() {
    final session = _voiceSession;
    _voiceSession = null;
    final pending = _voiceReady;
    _voiceReady = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Voice request cancelled.'));
    }
    if (session != null && isConnected) {
      try {
        _send(
          RemoteMessage()
            ..remoteVoiceEnd = RemoteVoiceEnd(sessionId: session.id),
        );
      } catch (_) {
        /* Connection teardown also ends the remote request. */
      }
    }
  }

  final _volumeController = StreamController<AndroidTvVolumeInfo>.broadcast();
  final _currentAppController = StreamController<String>.broadcast();
  final _powerStateController = StreamController<bool>.broadcast();

  /// Called when the connection drops (any reason) after being established.
  void Function(String reason)? onDisconnected;

  AndroidTvDeviceInfo? deviceInfo;
  AndroidTvVolumeInfo? volumeInfo;
  String? currentApp;
  bool isOn = false;
  DateTime? powerReportedAt;
  DateTime? volumeReportedAt;

  bool get isConnected => _socket != null;

  /// Features actually negotiated with the TV.
  int get activeFeatures => _activeFeatures;

  /// Completes once the TV sent RemoteStart, i.e. it is ready for commands.
  Future<void> get ready =>
      _readyCompleter?.future ?? Future.error('Not connected');

  Stream<AndroidTvVolumeInfo> get volumeInfoUpdates => _volumeController.stream;
  Stream<String> get currentAppUpdates => _currentAppController.stream;
  Stream<bool> get powerStateUpdates => _powerStateController.stream;

  /// Connects to the remote port.
  ///
  /// [pinnedServerCertificateSha256], when provided, is verified against the
  /// certificate the TV presents; a mismatch aborts the connection so a stale
  /// or spoofed endpoint is never treated as our paired TV.
  Future<void> connect(
    String host, {
    int port = defaultPort,
    String? pinnedServerCertificateSha256,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await close();
    _closedByUs = false;
    final epoch = _connectionEpoch;
    _readyCompleter = Completer<void>();
    // A cancelled connection may finish before the controller awaits ready.
    unawaited(
      _readyCompleter!.future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      ),
    );

    final context = await certificates.buildSecurityContext();
    if (epoch != _connectionEpoch) {
      throw const RemoteConnectionException('Connection cancelled.');
    }
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        context: context,
        onBadCertificate: (certificate) {
          if (pinnedServerCertificateSha256 == null) return true;
          final fingerprint = sha256.convert(certificate.der).toString();
          return fingerprint == pinnedServerCertificateSha256;
        },
        timeout: timeout,
      );
      if (epoch != _connectionEpoch) {
        socket.destroy();
        throw const RemoteConnectionException('Connection cancelled.');
      }
      _socket = socket;
    } on SocketException catch (error) {
      throw RemoteConnectionException(
        'Could not reach the TV: ${error.message}',
      );
    } on HandshakeException catch (error) {
      throw RemoteConnectionException(
        'The TV refused the secure connection ($error). Pair again.',
        requiresPairing: true,
      );
    }

    _framing.clear();
    _subscription = _socket!.listen(
      _onData,
      onError: (Object error) => _dropConnection('Connection error: $error'),
      onDone: () => _dropConnection('The TV closed the connection.'),
    );
    _resetIdleTimer();
  }

  void sendKey(
    int keyCode, {
    RemoteDirection direction = RemoteDirection.SHORT,
  }) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(
        MessageFraming.encode(
          (RemoteMessage()
                ..remoteKeyInject = (RemoteKeyInject()
                  ..keyCode = keyCode
                  ..direction = direction))
              .writeToBuffer(),
        ),
      );
      _resetIdleTimer();
    } catch (_) {
      _dropConnection('Failed to send a command to the TV.');
    }
  }

  final Set<int> _heldKeys = {};

  /// Tracks held keys so leaving a surface cannot leave a TV key pressed.
  void startLongPress(int keyCode) {
    if (_socket == null) return;
    if (_heldKeys.add(keyCode)) {
      sendKey(keyCode, direction: RemoteDirection.START_LONG);
    }
  }

  void endLongPress(int keyCode) {
    if (_heldKeys.remove(keyCode)) {
      sendKey(keyCode, direction: RemoteDirection.END_LONG);
    }
  }

  void cancelLongPress() {
    for (final key in _heldKeys.toList()) {
      endLongPress(key);
    }
  }

  /// Launches an app via a `https://...` / `app://...` link where the TV
  /// supports APP_LINK.
  void launchAppLink(String link) {
    final socket = _socket;
    if (socket == null) return;
    socket.add(
      MessageFraming.encode(
        (RemoteMessage()
              ..remoteAppLinkLaunchRequest = (RemoteAppLinkLaunchRequest()
                ..appLink = link))
            .writeToBuffer(),
      ),
    );
    _resetIdleTimer();
  }

  bool sendText(String text, AndroidTvTextSession session) {
    if (_socket == null || _activeFeatures & AndroidTvFeatures.ime == 0) {
      return false;
    }
    final request = textInput.createRequest(text, session);
    if (request == null) return false;
    try {
      _send(request);
      return true;
    } catch (_) {
      _dropConnection('Could not send text to the TV.');
      return false;
    }
  }

  bool sendTextEnter(AndroidTvTextSession session) {
    if (_socket == null ||
        !textInput.accepts(session) ||
        _activeFeatures & AndroidTvFeatures.ime == 0 ||
        _activeFeatures & AndroidTvFeatures.key == 0) {
      return false;
    }
    sendKey(AndroidKeyCodes.enter);
    return isConnected;
  }

  Future<void> close() async {
    cancelVoice();
    _connectionEpoch++;
    cancelLongPress();
    currentApp = null;
    volumeInfo = null;
    textInput.reset();
    powerReportedAt = null;
    volumeReportedAt = null;
    isOn = false;
    _closedByUs = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    final subscription = _subscription;
    _subscription = null;
    final socket = _socket;
    _socket = null;
    socket?.destroy();
    if (_readyCompleter?.isCompleted == false) {
      _readyCompleter!.completeError(
        const RemoteConnectionException(
          'Disconnected before the TV was ready.',
        ),
      );
    }
    await subscription?.cancel();
  }

  Future<void> dispose() async {
    await close();
    await _volumeController.close();
    await _currentAppController.close();
    await _powerStateController.close();
    await textInput.dispose();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _onData(List<int> data) {
    final List<Uint8List> rawMessages;
    try {
      rawMessages = _framing.addData(data);
    } on FramingException catch (error) {
      _dropConnection(error.message);
      return;
    }
    _resetIdleTimer();
    for (final raw in rawMessages) {
      _handleMessage(raw);
    }
  }

  void _handleMessage(Uint8List raw) {
    final RemoteMessage message;
    try {
      message = RemoteMessage.fromBuffer(raw);
    } catch (_) {
      return; // Ignore unparseable messages rather than killing the session.
    }

    if (message.hasRemoteConfigure()) {
      final configure = message.remoteConfigure;
      deviceInfo = AndroidTvDeviceInfo(
        vendor: configure.deviceInfo.vendor,
        model: configure.deviceInfo.model,
        appVersion: configure.deviceInfo.appVersion,
      );
      _activeFeatures = AndroidTvFeatures.requested & configure.code1;
      _send(
        RemoteMessage()
          ..remoteConfigure = (RemoteConfigure()
            ..code1 = _activeFeatures
            ..deviceInfo = (RemoteDeviceInfo()
              ..unknown1 = 1
              ..unknown2 = '1'
              ..packageName = 'atvremote'
              ..appVersion = '1.0.0')),
      );
    } else if (message.hasRemoteSetActive()) {
      _send(
        RemoteMessage()
          ..remoteSetActive = (RemoteSetActive()..active = _activeFeatures),
      );
    } else if (message.hasRemotePingRequest()) {
      _send(
        RemoteMessage()
          ..remotePingResponse = (RemotePingResponse()
            ..val1 = message.remotePingRequest.val1),
      );
    } else if (message.hasRemoteStart()) {
      isOn = message.remoteStart.started;
      powerReportedAt = DateTime.now().toUtc();
      _powerStateController.add(isOn);
      if (_readyCompleter?.isCompleted == false) _readyCompleter!.complete();
    } else if (message.hasRemoteSetVolumeLevel()) {
      final volume = message.remoteSetVolumeLevel;
      volumeReportedAt = DateTime.now().toUtc();
      volumeInfo = AndroidTvVolumeInfo(
        level: volume.volumeLevel,
        max: volume.volumeMax,
        muted: volume.volumeMuted,
      );
      _volumeController.add(volumeInfo!);
    } else if (message.hasRemoteImeKeyInject()) {
      final app = message.remoteImeKeyInject.appInfo.appPackage;
      textInput.updateApp(app.isEmpty ? null : app);
      currentApp = app.isEmpty ? null : app;
      _currentAppController.add(app);
    } else if (message.hasRemoteImeBatchEdit()) {
      if (_activeFeatures & AndroidTvFeatures.ime != 0) {
        final batch = message.remoteImeBatchEdit;
        textInput.updateCounters(batch.imeCounter, batch.fieldCounter);
      }
    } else if (message.hasRemoteVoiceBegin()) {
      final pending = _voiceReady;
      if (voiceSupported && pending != null && !pending.isCompleted) {
        final session = AndroidTvVoiceSession._(
          message.remoteVoiceBegin.sessionId,
        );
        _voiceSession = session;
        pending.complete(session);
      }
    } else if (message.hasRemoteVoiceEnd()) {
      if (_voiceSession?.id == message.remoteVoiceEnd.sessionId) cancelVoice();
    } else if (message.hasRemoteError()) {
      // The TV rejected a command; surface via log only, never crash.
      assert(() {
        // ignore: avoid_print
        print('Android TV remote error: ${message.remoteError.value}');
        return true;
      }());
    }
  }

  void _send(RemoteMessage message) {
    final socket = _socket;
    if (socket == null) return;
    socket.add(MessageFraming.encode(message.writeToBuffer()));
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _onIdleTimeout);
  }

  void _onIdleTimeout() {
    _dropConnection('The TV stopped responding (connection timed out).');
  }

  void _dropConnection(String reason) {
    if (_socket == null) return;
    final notify = !_closedByUs;
    unawaited(close());
    if (notify) onDisconnected?.call(reason);
  }
}
