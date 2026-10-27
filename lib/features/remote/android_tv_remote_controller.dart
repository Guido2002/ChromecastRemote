import 'dart:async';

import '../../core/protocol/android_tv/android_key_codes.dart';
import '../../core/protocol/android_tv/android_tv_remote_client.dart';
import '../../core/protocol/android_tv/certificate_manager.dart';
import '../pairing/paired_device_store.dart';
import 'remote_controller.dart';

/// Maps a [RemoteCommand] to its Android key code.
int keyCodeForCommand(RemoteCommand command) => switch (command) {
      RemoteCommand.up => AndroidKeyCodes.dpadUp,
      RemoteCommand.down => AndroidKeyCodes.dpadDown,
      RemoteCommand.left => AndroidKeyCodes.dpadLeft,
      RemoteCommand.right => AndroidKeyCodes.dpadRight,
      RemoteCommand.select => AndroidKeyCodes.dpadCenter,
      RemoteCommand.back => AndroidKeyCodes.back,
      RemoteCommand.home => AndroidKeyCodes.home,
      RemoteCommand.power => AndroidKeyCodes.power,
      RemoteCommand.volumeUp => AndroidKeyCodes.volumeUp,
      RemoteCommand.volumeDown => AndroidKeyCodes.volumeDown,
      RemoteCommand.mute => AndroidKeyCodes.mute,
      RemoteCommand.playPause => AndroidKeyCodes.mediaPlayPause,
      RemoteCommand.play => AndroidKeyCodes.mediaPlay,
      RemoteCommand.pause => AndroidKeyCodes.mediaPause,
      RemoteCommand.stop => AndroidKeyCodes.mediaStop,
      RemoteCommand.next => AndroidKeyCodes.mediaNext,
      RemoteCommand.previous => AndroidKeyCodes.mediaPrevious,
      RemoteCommand.rewind => AndroidKeyCodes.mediaRewind,
      RemoteCommand.fastForward => AndroidKeyCodes.mediaFastForward,
    };

/// Drives a paired Google TV / Android TV over Android TV Remote Protocol v2.
///
/// Pairing itself is handled by `AndroidTvPairingClient` (see the pairing
/// feature); this controller reconnects using the persisted certificate pin.
class AndroidTvRemoteController implements RemoteController {
  AndroidTvRemoteController({
    required this.pairedDevice,
    required CertificateManager certificates,
    required this.store,
  }) : _client = AndroidTvRemoteClient(certificates: certificates) {
    _client.onDisconnected = _onDropped;
  }

  PairedAndroidTv pairedDevice;
  final PairedDeviceStore store;
  final AndroidTvRemoteClient _client;

  final _stateController =
      StreamController<RemoteConnectionState>.broadcast();
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  String? _lastError;
  Timer? _reconnectTimer;
  bool _userDisconnected = false;

  AndroidTvRemoteClient get client => _client;

  void updatePairedDevice(PairedAndroidTv device) {
    if (device.serviceName == pairedDevice.serviceName) pairedDevice = device;
  }

  @override
  String get deviceName => pairedDevice.displayName;

  @override
  RemoteConnectionState get connectionState => _state;

  @override
  String? get lastError => _lastError;

  @override
  Stream<RemoteConnectionState> get connectionStates => _stateController.stream;

  @override
  Set<RemoteCapability> get capabilities {
    if (_state != RemoteConnectionState.connected) return const {};
    final features = _client.activeFeatures;
    return {
      if (features & AndroidTvFeatures.key != 0) ...{
        RemoteCapability.navigation,
        RemoteCapability.mediaControl,
      },
      if (features & AndroidTvFeatures.power != 0) RemoteCapability.power,
      if (features & AndroidTvFeatures.volume != 0) RemoteCapability.volume,
      if (features & AndroidTvFeatures.appLink != 0)
        RemoteCapability.appLaunch,
    };
  }

  @override
  bool supports(RemoteCommand command) {
    final caps = capabilities;
    return switch (command) {
      RemoteCommand.up ||
      RemoteCommand.down ||
      RemoteCommand.left ||
      RemoteCommand.right ||
      RemoteCommand.select ||
      RemoteCommand.back ||
      RemoteCommand.home =>
        caps.contains(RemoteCapability.navigation),
      RemoteCommand.power => caps.contains(RemoteCapability.power),
      RemoteCommand.volumeUp ||
      RemoteCommand.volumeDown ||
      RemoteCommand.mute =>
        caps.contains(RemoteCapability.volume),
      RemoteCommand.playPause ||
      RemoteCommand.play ||
      RemoteCommand.pause ||
      RemoteCommand.stop ||
      RemoteCommand.next ||
      RemoteCommand.previous ||
      RemoteCommand.rewind ||
      RemoteCommand.fastForward =>
        caps.contains(RemoteCapability.mediaControl),
    };
  }

  @override
  Future<void> connect() async {
    if (_state == RemoteConnectionState.connecting ||
        _state == RemoteConnectionState.connected) {
      return;
    }
    _userDisconnected = false;
    _setState(RemoteConnectionState.connecting);
    try {
      await _client.connect(
        pairedDevice.lastHost,
        pinnedServerCertificateSha256: pairedDevice.serverCertificateSha256,
      );
      await _client.ready.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw const RemoteConnectionException(
          'The TV connected but never became ready for commands.',
        ),
      );
      _setState(RemoteConnectionState.connected);
    } on RemoteConnectionException catch (error) {
      if (error.requiresPairing) {
        // Credentials are stale; drop them so the UI offers re-pairing.
        await store.remove(pairedDevice.serviceName);
      }
      _fail(error.message);
    } catch (error) {
      _fail('$error');
    }
  }

  @override
  Future<void> disconnect() async {
    _userDisconnected = true;
    _reconnectTimer?.cancel();
    await _client.close();
    _setState(RemoteConnectionState.disconnected);
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!supports(command)) return;
    _client.sendKey(keyCodeForCommand(command));
  }

  /// Sends a raw Android key code not covered by [RemoteCommand]
  /// (e.g. KEYCODE_SEARCH for the assistant). Requires key support.
  void sendRawKey(int keyCode) {
    if (!capabilities.contains(RemoteCapability.navigation)) return;
    _client.sendKey(keyCode);
  }

  /// Launches an app on the TV via its deep link (e.g. `netflix://`).
  /// Requires the APP_LINK feature.
  void launchAppLink(String link) {
    if (!capabilities.contains(RemoteCapability.appLaunch)) return;
    _client.launchAppLink(link);
  }

  /// Package name of the app currently in the foreground on the TV, when the
  /// device reports it (IME feature). Null when unknown.
  String? get currentApp => _client.currentApp;

  /// Updates when the foreground app on the TV changes.
  Stream<String> get currentAppUpdates => _client.currentAppUpdates;

  /// Starts key repetition for a held button (volume / D-pad).
  void startLongPress(RemoteCommand command) {
    if (_state != RemoteConnectionState.connected) return;
    final keyCode = _longPressableKeyCode(command);
    if (keyCode != null) _client.startLongPress(keyCode);
  }

  void endLongPress(RemoteCommand command) {
    final keyCode = _longPressableKeyCode(command);
    if (keyCode != null) _client.endLongPress(keyCode);
  }

  int? _longPressableKeyCode(RemoteCommand command) => switch (command) {
        RemoteCommand.up => AndroidKeyCodes.dpadUp,
        RemoteCommand.down => AndroidKeyCodes.dpadDown,
        RemoteCommand.left => AndroidKeyCodes.dpadLeft,
        RemoteCommand.right => AndroidKeyCodes.dpadRight,
        RemoteCommand.volumeUp => AndroidKeyCodes.volumeUp,
        RemoteCommand.volumeDown => AndroidKeyCodes.volumeDown,
        _ => null,
      };

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _client.dispose();
    await _stateController.close();
  }

  void _onDropped(String reason) {
    if (_userDisconnected) return;
    _lastError = reason;
    _setState(RemoteConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (!_userDisconnected) unawaited(connect());
    });
  }

  void _fail(String message) {
    _lastError = message;
    _setState(RemoteConnectionState.error);
  }

  void _setState(RemoteConnectionState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }
}
