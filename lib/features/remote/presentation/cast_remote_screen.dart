import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../../media_url.dart';
import '../../../shared/presentation/adaptive_layout.dart';
import '../../../shared/presentation/app_motion.dart';
import '../../../shared/presentation/app_theme.dart';
import '../cast_capabilities.dart';

/// Remote screen for classic Chromecast devices.
///
/// Classic Chromecasts expose a Cast media session only — there is no
/// system-wide navigation. This screen therefore shows media transport,
/// receiver volume and media casting, and nothing that cannot work.
class CastRemoteScreen extends StatefulWidget {
  const CastRemoteScreen({
    required this.device,
    this.embedded = false,
    this.active = true,
    this.onStopped,
    super.key,
  });

  final GoogleCastDevice device;
  final bool embedded;
  final bool active;
  final VoidCallback? onStopped;

  @override
  State<CastRemoteScreen> createState() => _CastRemoteScreenState();
}

class _CastRemoteScreenState extends State<CastRemoteScreen> {
  bool _isDisconnecting = false;

  Future<void> _disconnect() async {
    setState(() => _isDisconnecting = true);
    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
      if (mounted) {
        if (widget.embedded) {
          widget.onStopped?.call();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (error) {
      _showMessage(
        'Could not stop casting. Check the receiver connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isDisconnecting = false);
    }
  }

  void _showMessage(String message, {bool isWarning = false}) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isWarning
              ? colors.secondaryContainer
              : colors.errorContainer,
          content: Text(
            message,
            style: TextStyle(
              color: isWarning
                  ? colors.onSecondaryContainer
                  : colors.onErrorContainer,
            ),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GoogleCastSession?>(
      stream: GoogleCastSessionManager.instance.currentSessionStream,
      initialData: GoogleCastSessionManager.instance.currentSession,
      builder: (context, snapshot) {
        final session = snapshot.data;
        final sameReceiver =
            session?.device?.deviceID == widget.device.deviceID;
        final connected =
            sameReceiver &&
            session?.connectionState == GoogleCastConnectState.connected;
        final connecting =
            sameReceiver &&
            session?.connectionState == GoogleCastConnectState.connecting;
        final tablet =
            AdaptiveLayout.isTablet(context) &&
            MediaQuery.sizeOf(context).height >= 600;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.friendlyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                _CastStatus(connected: connected, connecting: connecting),
              ],
            ),
            actions: [
              if (!connected && !connecting)
                IconButton(
                  tooltip: 'Reconnect Cast receiver',
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    try {
                      final started = await GoogleCastSessionManager.instance
                          .startSessionWithDevice(widget.device);
                      if (!started) {
                        _showMessage('Could not reconnect to this receiver.');
                      }
                    } catch (_) {
                      _showMessage(
                        'Could not reconnect. Check receiver power and Wi-Fi.',
                      );
                    }
                  },
                ),
              IconButton(
                tooltip: 'Stop casting',
                onPressed: connected && !_isDisconnecting ? _disconnect : null,
                icon: const Icon(Icons.stop_screen_share_outlined),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: AdaptiveLayout.pagePadding(context),
            child: AdaptiveContent(
              maxWidth: 1080,
              child: MotionEntrance(
                child: tablet
                    ? Row(
                        key: const ValueKey('cast-tablet-layout'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _MediaControlsCard(
                                  connected: connected,
                                  active: widget.active,
                                  deviceId: widget.device.deviceID,
                                  onMessage: _showMessage,
                                ),
                                const SizedBox(height: 18),
                                _VolumeCard(
                                  session: session,
                                  connected: connected,
                                  onMessage: _showMessage,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: _buildPlaySection(connected),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MediaControlsCard(
                            connected: connected,
                            active: widget.active,
                            deviceId: widget.device.deviceID,
                            onMessage: _showMessage,
                          ),
                          const SizedBox(height: 14),
                          _VolumeCard(
                            session: session,
                            connected: connected,
                            onMessage: _showMessage,
                          ),
                          const SizedBox(height: 24),
                          _buildPlaySection(connected),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaySection(bool connected) => ExpansionTile(
    title: const Text('Cast a media link'),
    subtitle: const Text('Advanced · direct audio or video files'),
    children: [
      _CastUrlCard(connected: connected, onMessage: _showMessage),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Classic Chromecast supports media sessions, not TV navigation. Media started by another app may not expose controls here.',
        ),
      ),
    ],
  );
}

class _CastStatus extends StatelessWidget {
  const _CastStatus({required this.connected, required this.connecting});

  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = connected
        ? 'Connected · Cast media'
        : connecting
        ? 'Connecting…'
        : 'Disconnected';
    final color = connected
        ? colors.secondary
        : connecting
        ? colors.primary
        : colors.onSurfaceVariant;

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.standard,
      child: Row(
        key: ValueKey(label),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaControlsCard extends StatefulWidget {
  const _MediaControlsCard({
    required this.connected,
    required this.onMessage,
    required this.deviceId,
    required this.active,
  });

  final bool connected;
  final String deviceId;
  final bool active;
  final void Function(String message, {bool isWarning}) onMessage;

  @override
  State<_MediaControlsCard> createState() => _MediaControlsCardState();
}

class _MediaControlsCardState extends State<_MediaControlsCard>
    with WidgetsBindingObserver {
  CastCapabilities? _capabilities;
  Timer? _poll;
  bool _foreground = true;
  bool _reading = false;
  int _epoch = 0;
  int? _dragMediaId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCapabilities();
  }

  @override
  void didUpdateWidget(_MediaControlsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connected != widget.connected ||
        oldWidget.active != widget.active ||
        oldWidget.deviceId != widget.deviceId) {
      _startCapabilities();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _startCapabilities();
  }

  void _startCapabilities() {
    _epoch++;
    _poll?.cancel();
    _capabilities = null;
    if (!widget.active || !widget.connected || !_foreground) return;
    unawaited(_refreshCapabilities());
    _poll = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshCapabilities()),
    );
  }

  Future<void> _refreshCapabilities() async {
    if (_reading) return;
    final epoch = _epoch;
    _reading = true;
    try {
      final value = await CastCapabilities.read();
      if (mounted && epoch == _epoch) setState(() => _capabilities = value);
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _epoch++;
    super.dispose();
  }

  bool get _sessionMatches =>
      widget.active &&
      widget.connected &&
      GoogleCastSessionManager.instance.currentSession?.device?.deviceID ==
          widget.deviceId;
  CastSeekWindow? _window(GoggleCastMediaStatus? status) =>
      CastSeekWindow.resolve(
        seekSupported:
            _sessionMatches &&
            _capabilities?.matches(widget.deviceId, status?.mediaSessionID) ==
                true &&
            _capabilities!.seek,
        live: status?.mediaInformation?.streamType == CastMediaStreamType.live,
        duration: status?.mediaInformation?.duration,
        liveStart: status?.liveSeekableRange?.start,
        liveEnd: status?.liveSeekableRange?.end,
      );

  bool _busy = false;
  double? _dragPosition;

  Future<void> _perform(
    Future<void> Function() command, {
    int? expectedSession,
  }) async {
    if (!_sessionMatches ||
        _busy ||
        (expectedSession != null &&
            GoogleCastRemoteMediaClient.instance.mediaStatus?.mediaSessionID !=
                expectedSession)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await command();
    } catch (error) {
      widget.onMessage('Cast command failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip(Duration delta, int expectedSession) async {
    final client = GoogleCastRemoteMediaClient.instance;
    final window = _window(client.mediaStatus);
    if (window == null) return;
    await _perform(
      () => client.seek(
        GoogleCastMediaSeekOption(
          position: window.clamp(client.playerPosition + delta),
        ),
      ),
      expectedSession: expectedSession,
    );
  }

  Future<void> _seek(Duration position, int expectedSession) async {
    setState(() {
      _dragPosition = null;
      _dragMediaId = null;
    });
    final window = _window(GoogleCastRemoteMediaClient.instance.mediaStatus);
    if (window == null) return;
    await _perform(
      () => GoogleCastRemoteMediaClient.instance.seek(
        GoogleCastMediaSeekOption(position: window.clamp(position)),
      ),
      expectedSession: expectedSession,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final client = GoogleCastRemoteMediaClient.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: StreamBuilder<GoggleCastMediaStatus?>(
          stream: client.mediaStatusStream,
          initialData: client.mediaStatus,
          builder: (context, statusSnapshot) {
            final status = widget.connected ? statusSnapshot.data : null;
            final info = status?.mediaInformation;
            final duration = info?.duration;
            final live = info?.streamType == CastMediaStreamType.live;
            final window = _window(status);
            final mediaId = status?.mediaSessionID;
            final pauseSupported =
                _capabilities?.matches(widget.deviceId, mediaId) == true &&
                _capabilities!.pause;
            final mediaLoaded = info != null;
            final title = _titleFor(info);
            final state = status?.playerState;
            final playing = state == CastMediaPlayerState.playing;
            final loading =
                state == CastMediaPlayerState.loading ||
                state == CastMediaPlayerState.buffering;
            final canControl = _sessionMatches && mediaLoaded && !_busy;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MediaArtwork(info: info),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mediaLoaded ? title : 'Nothing playing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _playerLabel(state, widget.connected),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: loading
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (loading || _busy)
                      const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (statusSnapshot.hasError) ...[
                  const SizedBox(height: 14),
                  _InlineNotice(
                    message:
                        'Could not read playback status: '
                        '${statusSnapshot.error}',
                    isError: true,
                  ),
                ],
                const SizedBox(height: 18),
                StreamBuilder<Duration>(
                  stream: client.playerPositionStream,
                  initialData: client.playerPosition,
                  builder: (context, positionSnapshot) {
                    final actualPosition =
                        positionSnapshot.data ?? Duration.zero;
                    final minMs =
                        window?.start.inMilliseconds.toDouble() ?? 0.0;
                    final maxMs = window?.end.inMilliseconds.toDouble() ?? 1.0;
                    final currentMs =
                        (_dragMediaId == mediaId ? _dragPosition : null) ??
                        actualPosition.inMilliseconds.toDouble();
                    final sliderEnabled =
                        canControl && window != null && mediaId != null;

                    return Column(
                      children: [
                        Slider(
                          value: currentMs.clamp(minMs, maxMs),
                          min: minMs,
                          max: maxMs,
                          onChanged: sliderEnabled
                              ? (value) => setState(() {
                                  _dragPosition = value;
                                  _dragMediaId = mediaId;
                                })
                              : null,
                          onChangeEnd: sliderEnabled
                              ? (value) => _seek(
                                  Duration(milliseconds: value.round()),
                                  mediaId,
                                )
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(
                                  _dragPosition == null
                                      ? actualPosition
                                      : Duration(
                                          milliseconds: _dragPosition!.round(),
                                        ),
                                ),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                live
                                    ? 'LIVE'
                                    : duration == null
                                    ? '—:—'
                                    : _formatDuration(duration),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundControlButton(
                      tooltip: 'Back 10 seconds',
                      icon: Icons.replay_10,
                      onPressed: canControl && window != null && mediaId != null
                          ? () => _skip(const Duration(seconds: -10), mediaId)
                          : null,
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 66,
                      height: 66,
                      child: FilledButton(
                        onPressed: canControl && (!playing || pauseSupported)
                            ? () => _perform(
                                playing ? client.pause : client.play,
                                expectedSession: mediaId,
                              )
                            : null,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: AppColors.actionFill,
                        ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    _RoundControlButton(
                      tooltip: 'Forward 30 seconds',
                      icon: Icons.forward_30,
                      onPressed: canControl && window != null && mediaId != null
                          ? () => _skip(const Duration(seconds: 30), mediaId)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Stop playback',
                      onPressed: canControl
                          ? () =>
                                _perform(client.stop, expectedSession: mediaId)
                          : null,
                      icon: const Icon(Icons.stop_rounded),
                    ),
                  ],
                ),
                if (mediaLoaded &&
                    _capabilities?.matches(widget.deviceId, mediaId) != true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Some controls are unavailable until receiver capabilities are reported.',
                    ),
                  ),
                if (!mediaLoaded && widget.connected) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No controllable media session. Start compatible media on this receiver or cast a direct media link.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MediaArtwork extends StatelessWidget {
  const _MediaArtwork({required this.info});

  final GoogleCastMediaInformation? info;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final images = info?.metadata?.images;
    Widget fallback() => Container(
      color: colors.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        info == null ? Icons.ondemand_video : Icons.graphic_eq,
        color: colors.onPrimaryContainer,
        size: 25,
      ),
    );

    Widget child = fallback();
    if (images != null && images.isNotEmpty) {
      final sorted = List<GoogleCastImage>.from(images)
        ..sort((a, b) {
          final aSize = (a.width ?? 0) * (a.height ?? 0);
          final bSize = (b.width ?? 0) * (b.height ?? 0);
          return bSize.compareTo(aSize);
        });
      child = Image.network(
        sorted.first.url.toString(),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
        loadingBuilder: (context, image, progress) => progress == null
            ? image
            : Container(
                color: colors.primaryContainer,
                alignment: Alignment.center,
                child: const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    }

    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size(50, 50),
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurface,
      ),
    );
  }
}

class _VolumeCard extends StatefulWidget {
  const _VolumeCard({
    required this.session,
    required this.connected,
    required this.onMessage,
  });

  final GoogleCastSession? session;
  final bool connected;
  final void Function(String message, {bool isWarning}) onMessage;

  @override
  State<_VolumeCard> createState() => _VolumeCardState();
}

class _VolumeCardState extends State<_VolumeCard> {
  double? _volume;
  double _lastAudibleVolume = 0.5;
  String? _deviceId;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _VolumeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.session?.device?.deviceID;
    if (!_dragging || id != _deviceId) {
      _deviceId = id;
      _volume = null;
      final reported = widget.session?.currentDeviceVolume ?? 0;
      if (reported > 0) _lastAudibleVolume = reported;
    }
  }

  void _setVolume(double next) {
    if (!widget.connected) return;
    final value = next.clamp(0.0, 1.0);
    setState(() {
      _volume = null;
      _dragging = false;
      if (value > 0) _lastAudibleVolume = value;
    });
    try {
      GoogleCastSessionManager.instance.setDeviceVolume(value);
    } catch (error) {
      widget.onMessage('Could not change Cast volume: $error');
    }
  }

  void _toggleMute() {
    if (!widget.connected) return;
    HapticFeedback.lightImpact();
    final current = _volume ?? widget.session?.currentDeviceVolume ?? 0;
    _setVolume(current > 0 ? 0 : _lastAudibleVolume);
  }

  @override
  Widget build(BuildContext context) {
    final sessionVolume = widget.session?.currentDeviceVolume ?? 0;
    final value = (_volume ?? sessionVolume).clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          children: [
            IconButton(
              tooltip: value == 0 ? 'Unmute receiver' : 'Mute receiver',
              onPressed: widget.connected ? _toggleMute : null,
              icon: Icon(value == 0 ? Icons.volume_off : Icons.volume_mute),
            ),
            Expanded(
              child: Slider(
                value: value,
                onChanged: widget.connected
                    ? (next) => setState(() {
                        _volume = next;
                        _dragging = true;
                      })
                    : null,
                onChangeEnd: widget.connected ? _setVolume : null,
              ),
            ),
            SizedBox(
              width: 38,
              child: Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastUrlCard extends StatefulWidget {
  const _CastUrlCard({required this.connected, required this.onMessage});

  final bool connected;
  final void Function(String message, {bool isWarning}) onMessage;

  @override
  State<_CastUrlCard> createState() => _CastUrlCardState();
}

class _CastUrlCardState extends State<_CastUrlCard> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _showFormatWarning = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _castUrl() async {
    if (!widget.connected || _isLoading) return;
    late final CastMediaUrl mediaUrl;
    try {
      mediaUrl = CastMediaUrl.parse(_controller.text);
    } on MediaUrlException catch (error) {
      widget.onMessage(error.message, isWarning: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _showFormatWarning = !mediaUrl.hasKnownFormat;
    });
    try {
      final pathName = mediaUrl.uri.pathSegments.isEmpty
          ? mediaUrl.uri.host
          : Uri.decodeComponent(mediaUrl.uri.pathSegments.last);
      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformation(
          contentId: mediaUrl.uri.toString(),
          contentUrl: mediaUrl.uri,
          contentType: mediaUrl.contentType,
          streamType: CastMediaStreamType.buffered,
          metadata: GoogleCastGenericMediaMetadata(
            title: pathName.isEmpty ? 'Cast media' : pathName,
          ),
        ),
      );
    } catch (error) {
      widget.onMessage('Could not play this media link: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cast a media link',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Use a direct audio or video link, not a webpage. The receiver must support the format and be able to access the file.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              enabled: widget.connected && !_isLoading,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _castUrl(),
              decoration: const InputDecoration(
                hintText: 'https://example.com/video.mp4',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            if (_showFormatWarning) ...[
              const SizedBox(height: 10),
              const _InlineNotice(
                message:
                    'The file type is unknown. The receiver may not be '
                    'able to play this URL.',
                isError: false,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !widget.connected || _isLoading ? null : _castUrl,
                icon: _isLoading
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? 'Starting playback…' : 'Play on TV'),
              ),
            ),
            if (!widget.connected) ...[
              const SizedBox(height: 8),
              Text(
                'Connect a Chromecast before sending media.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

String _titleFor(GoogleCastMediaInformation? info) {
  if (info == null) return 'Nothing playing';
  final metadata = info.metadata;
  if (metadata is GoogleCastGenericMediaMetadata &&
      metadata.title?.isNotEmpty == true) {
    return metadata.title!;
  }
  final uri = Uri.tryParse(info.contentId);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return Uri.decodeComponent(uri.pathSegments.last);
  }
  return info.contentId.isEmpty ? 'Cast media' : info.contentId;
}

String _playerLabel(CastMediaPlayerState? state, bool connected) {
  if (!connected) return 'Connect to control playback';
  return switch (state) {
    CastMediaPlayerState.playing => 'Now playing',
    CastMediaPlayerState.paused => 'Paused',
    CastMediaPlayerState.loading ||
    CastMediaPlayerState.buffering => 'Loading media…',
    CastMediaPlayerState.idle => 'Ready for media',
    CastMediaPlayerState.unknown || null => 'Waiting for playback',
  };
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = remainder.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
}
