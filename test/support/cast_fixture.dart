import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:chromecast_remote/features/remote/cast_capabilities.dart';
import 'package:chromecast_remote/features/remote/smart_now_playing.dart';

class FixtureCastSession extends GoogleCastSession {
  FixtureCastSession({
    String id = 'living-room',
    String session = 'cast-1',
    bool connected = true,
  }) : super(
         device: GoogleCastDevice(
           deviceID: id,
           friendlyName: 'Living room TV',
           modelName: 'Chromecast',
           statusText: null,
           deviceVersion: '1',
           isOnLocalNetwork: true,
           category: 'cast',
           uniqueID: id,
         ),
         sessionID: session,
         connectionState: connected
             ? GoogleCastConnectState.connected
             : GoogleCastConnectState.disconnected,
         currentDeviceMuted: false,
         currentDeviceVolume: .4,
         deviceStatusText: '',
       );
}

GoggleCastMediaStatus fixtureMedia({
  int id = 7,
  CastMediaPlayerState state = CastMediaPlayerState.playing,
}) => GoggleCastMediaStatus(
  mediaSessionID: id,
  playerState: state,
  playbackRate: 1,
  volume: .4,
  isMuted: false,
  repeatMode: GoogleCastMediaRepeatMode.off,
  mediaInformation: GoogleCastMediaInformation(
    contentId: 'https://example.com/movie.mp4',
    streamType: CastMediaStreamType.buffered,
    contentType: 'video/mp4',
    duration: const Duration(minutes: 5),
    metadata: GoogleCastGenericMediaMetadata(title: 'Reported movie title'),
  ),
);
CastPlaybackSnapshot fixturePlayback({
  int mediaId = 7,
  String receiver = 'living-room',
  CastMediaPlayerState state = CastMediaPlayerState.playing,
}) => CastPlaybackSnapshot(
  session: FixtureCastSession(id: receiver),
  media: fixtureMedia(id: mediaId, state: state),
  capabilities: CastCapabilities(
    deviceId: receiver,
    mediaSessionId: mediaId,
    seek: true,
    pause: true,
  ),
);
