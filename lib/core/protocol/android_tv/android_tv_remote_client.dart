import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'android_key_codes.dart';
import 'certificate_manager.dart';
import 'framing.dart';
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

/// Android TV Remote Protocol v2 client for the remote port (6466).
///
/// Mirrors https://github.com/tronikos/androidtvremote2 remote.py:
///  * answers RemoteConfigure with our own device info + negotiated features,
///  * answers RemoteSetActive,
///  * echoes RemotePingRequest (the TV pings every ~5 s when idle),
///  * exposes volume / current-app / power-state updates,
///  * closes the connection when no message arrives for 16 s (the TV closes
///    after 3 unanswered pings, so silence means the link is dead).
class AndroidTvRemoteClient {
  AndroidTvRemoteClient({required this.certificates});

  static const defaultPort = 6466;

  /// The TV goes silent ~16 s only when the connection is dead.
  static const _idleTimeout = Duration(seconds: 16);

  final CertificateManager certificates;
  final MessageFraming _framing = MessageFraming();

  SecureSocket? _socket;
  StreamSubscription<List<int>>? _subscription;
  Timer? _idleTimer;
  Completer<void>? _readyCompleter;
  bool _closedByUs = false;

  int _activeFeatures = AndroidTvFeatures.requested;

  final _volumeController =
      StreamController<AndroidTvVolumeInfo>.broadcast();
  final _currentAppController = StreamController<String>.broadcast();
  final _powerStateController = StreamController<bool>.broadcast();

  /// Called when the connection drops (any reason) after being established.
  void Function(String reason)? onDisconnected;

  AndroidTvDeviceInfo? deviceInfo;
  AndroidTvVolumeInfo? volumeInfo;
  String? currentApp;
  bool isOn = false;

  bool get isConnected => _socket != null;

  /// Features actually negotiated with the TV.
  int get activeFeatures => _activeFeatures;

  /// Completes once the TV sent RemoteStart, i.e. it is ready for commands.
  Future<void> get ready =>
      _readyCompleter?.future ?? Future.error('Not connected');

  Stream<AndroidTvVolumeInfo> get volumeInfoUpdates =>
      _volumeController.stream;
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
    _readyCompleter = Completer<void>();

    final context = await certificates.buildSecurityContext();
    try {
      _socket = await SecureSocket.connect(
        host,
        port,
        context: context,
        onBadCertificate: (certificate) {
          if (pinnedServerCertificateSha256 == null) return true;
          final fingerprint =
              sha256.convert(certificate.der).toString();
          return fingerprint == pinnedServerCertificateSha256;
        },
        timeout: timeout,
      );
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

  void sendKey(int keyCode, {RemoteDirection direction = RemoteDirection.SHORT}) {
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

  /// Sends the key down phase of a long press (repeat while held).
  void startLongPress(int keyCode) =>
      sendKey(keyCode, direction: RemoteDirection.START_LONG);

  /// Sends the key up phase of a long press.
  void endLongPress(int keyCode) =>
      sendKey(keyCode, direction: RemoteDirection.END_LONG);

  /// Launches an app via a `https://...` / `app://...` link where the TV
  /// supports APP_LINK.
  void launchAppLink(String link) {
    final socket = _socket;
    if (socket == null) return;
    socket.add(
      MessageFraming.encode(
        (RemoteMessage()
              ..remoteAppLinkLaunchRequest =
                  (RemoteAppLinkLaunchRequest()..appLink = link))
            .writeToBuffer(),
      ),
    );
  }

  Future<void> close() async {
    _closedByUs = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    socket?.destroy();
    if (_readyCompleter?.isCompleted == false) {
      _readyCompleter!.completeError(
        const RemoteConnectionException('Disconnected before the TV was ready.'),
      );
    }
  }

  Future<void> dispose() async {
    await close();
    await _volumeController.close();
    await _currentAppController.close();
    await _powerStateController.close();
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
      _send(RemoteMessage()
        ..remoteConfigure = (RemoteConfigure()
          ..code1 = _activeFeatures
          ..deviceInfo = (RemoteDeviceInfo()
            ..unknown1 = 1
            ..unknown2 = '1'
            ..packageName = 'atvremote'
            ..appVersion = '1.0.0')));
    } else if (message.hasRemoteSetActive()) {
      _send(RemoteMessage()
        ..remoteSetActive = (RemoteSetActive()..active = _activeFeatures));
    } else if (message.hasRemotePingRequest()) {
      _send(RemoteMessage()
        ..remotePingResponse =
            (RemotePingResponse()..val1 = message.remotePingRequest.val1));
    } else if (message.hasRemoteStart()) {
      isOn = message.remoteStart.started;
      _powerStateController.add(isOn);
      if (_readyCompleter?.isCompleted == false) _readyCompleter!.complete();
    } else if (message.hasRemoteSetVolumeLevel()) {
      final volume = message.remoteSetVolumeLevel;
      volumeInfo = AndroidTvVolumeInfo(
        level: volume.volumeLevel,
        max: volume.volumeMax,
        muted: volume.volumeMuted,
      );
      _volumeController.add(volumeInfo!);
    } else if (message.hasRemoteImeKeyInject()) {
      final app = message.remoteImeKeyInject.appInfo.appPackage;
      if (app.isNotEmpty) {
        currentApp = app;
        _currentAppController.add(app);
      }
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
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _onIdleTimeout);
  }

  void _onIdleTimeout() {
    _dropConnection('The TV stopped responding (connection timed out).');
  }

  void _dropConnection(String reason) {
    if (_socket == null) return;
    unawaited(close());
    if (!_closedByUs) onDisconnected?.call(reason);
  }
}
