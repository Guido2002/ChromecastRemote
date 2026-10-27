/// Explicit connection lifecycle shared by every remote backend.
enum RemoteConnectionState {
  disconnected,
  connecting,
  pairing,
  connected,
  reconnecting,
  error,
}

/// High-level commands the UI can request.
enum RemoteCommand {
  up,
  down,
  left,
  right,
  select,
  back,
  home,
  power,
  volumeUp,
  volumeDown,
  mute,

  // Media playback controls (standard Android media key events).
  playPause,
  play,
  pause,
  stop,
  next,
  previous,
  rewind,
  fastForward,
}

/// What a connected device can actually do. The UI only enables controls
/// whose capability is present.
enum RemoteCapability {
  /// D-pad navigation, select, back, home.
  navigation,
  power,
  volume,
  mediaControl,
}

/// Abstraction over the per-protocol remote implementations.
abstract interface class RemoteController {
  Stream<RemoteConnectionState> get connectionStates;
  RemoteConnectionState get connectionState;

  /// Human-readable failure details when [connectionState] is
  /// [RemoteConnectionState.error].
  String? get lastError;

  Set<RemoteCapability> get capabilities;
  String get deviceName;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> sendCommand(RemoteCommand command);

  /// Whether [command] may be sent to this device.
  bool supports(RemoteCommand command);
}
