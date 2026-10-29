import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'cast_capabilities.dart';

class CastPlaybackSnapshot {
  const CastPlaybackSnapshot({this.session, this.media, this.capabilities});
  final GoogleCastSession? session;
  final GoggleCastMediaStatus? media;
  final CastCapabilities? capabilities;
  bool get available =>
      session?.connectionState == GoogleCastConnectState.connected &&
      session?.device != null &&
      media?.mediaInformation != null &&
      media!.mediaSessionID >= 0 &&
      const [
        CastMediaPlayerState.playing,
        CastMediaPlayerState.paused,
        CastMediaPlayerState.buffering,
        CastMediaPlayerState.loading,
      ].contains(media!.playerState) &&
      capabilities?.matches(session!.device!.deviceID, media!.mediaSessionID) ==
          true;
  String? get identity => available
      ? '${session!.device!.deviceID}:${session!.sessionID}:${media!.mediaSessionID}'
      : null;
}

/// Capabilities provide receiver/media identity missing from the Flutter status
/// event. Never attach old media to a newly selected receiver by display name.
class CastPlaybackMonitor extends ValueNotifier<CastPlaybackSnapshot> {
  CastPlaybackMonitor({
    required this.sessions,
    required this.mediaUpdates,
    required this.currentSession,
    required this.currentMedia,
    Future<CastCapabilities?> Function()? readCapabilities,
  }) : readCapabilities = readCapabilities ?? CastCapabilities.read,
       super(const CastPlaybackSnapshot());
  final Stream<GoogleCastSession?> sessions;
  final Stream<GoggleCastMediaStatus?> mediaUpdates;
  final GoogleCastSession? Function() currentSession;
  final GoggleCastMediaStatus? Function() currentMedia;
  final Future<CastCapabilities?> Function() readCapabilities;
  StreamSubscription<GoogleCastSession?>? _sessions;
  StreamSubscription<GoggleCastMediaStatus?>? _media;
  Timer? _poll;
  int _generation = 0;
  bool _reading = false, _active = false;

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    _generation++;
    _poll?.cancel();
    _sessions?.cancel();
    _media?.cancel();
    value = const CastPlaybackSnapshot();
    if (!active) return;
    _sessions = sessions.listen((_) => _invalidate());
    _media = mediaUpdates.listen((_) => _invalidate());
    unawaited(_refresh());
    _poll = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refresh()),
    );
  }

  void _invalidate() {
    _generation++;
    // A state change must remove stale controls before any asynchronous bridge read.
    final session = currentSession();
    final media = currentMedia();
    final previous = value;
    value = CastPlaybackSnapshot(
      session: session,
      media: media,
      capabilities:
          session?.sessionID == previous.session?.sessionID &&
              session?.device?.deviceID == previous.session?.device?.deviceID &&
              media?.mediaSessionID == previous.media?.mediaSessionID
          ? previous.capabilities
          : null,
    );
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!_active || _reading) return;
    _reading = true;
    final generation = _generation;
    final session = currentSession();
    final media = currentMedia();
    try {
      final caps =
          session?.connectionState == GoogleCastConnectState.connected &&
              media?.mediaInformation != null
          ? await readCapabilities()
          : null;
      if (!_active || generation != _generation) return;
      value = CastPlaybackSnapshot(
        session: session,
        media: media,
        capabilities: caps,
      );
    } catch (_) {
      if (_active && generation == _generation) {
        value = const CastPlaybackSnapshot();
      }
    } finally {
      _reading = false;
      if (_active && generation != _generation) unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _active = false;
    _generation++;
    _poll?.cancel();
    _sessions?.cancel();
    _media?.cancel();
    super.dispose();
  }
}
