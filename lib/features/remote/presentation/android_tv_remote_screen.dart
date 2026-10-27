import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/protocol/android_tv/android_key_codes.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../android_tv_remote_controller.dart';
import '../remote_controller.dart';
import 'widgets/directional_pad.dart';

/// The Google TV remote screen, modelled on the reference remote design:
/// dark background, circular D-pad, round Back/Home/Assistant buttons and a
/// joined volume pill with a separate mute button.
class AndroidTvRemoteScreen extends StatefulWidget {
  const AndroidTvRemoteScreen({required this.controller, super.key});

  final AndroidTvRemoteController controller;

  @override
  State<AndroidTvRemoteScreen> createState() => _AndroidTvRemoteScreenState();
}

class _AndroidTvRemoteScreenState extends State<AndroidTvRemoteScreen> {
  AndroidTvRemoteController get _controller => widget.controller;

  StreamSubscription<RemoteConnectionState>? _stateSubscription;
  RemoteConnectionState _state = RemoteConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _state = _controller.connectionState;
    _stateSubscription = _controller.connectionStates.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    unawaited(_controller.connect());
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  bool get _connected => _state == RemoteConnectionState.connected;

  void _send(RemoteCommand command) {
    if (!_connected) return;
    unawaited(_controller.sendCommand(command));
  }

  void _onDirection(String direction) {
    _send(switch (direction) {
      'up' => RemoteCommand.up,
      'down' => RemoteCommand.down,
      'left' => RemoteCommand.left,
      _ => RemoteCommand.right,
    });
  }

  Future<void> _forgetDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this TV?'),
        content: Text(
          'Removes the pairing with ${_controller.deviceName}. You will need '
          'to pair again next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.disconnect();
    if (mounted) Navigator.of(context).pop('forget');
  }

  Future<void> _pairAgain() async {
    await _controller.disconnect();
    if (!mounted) return;
    final paired = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PairingScreen(
          serviceName: _controller.pairedDevice.serviceName,
          displayName: _controller.pairedDevice.displayName,
          host: _controller.pairedDevice.lastHost,
        ),
      ),
    );
    if (paired == null || !mounted) return;
    unawaited(_controller.connect());
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = _controller.capabilities;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              deviceName: _controller.deviceName,
              state: _state,
              error: _controller.lastError,
              showPower: capabilities.contains(RemoteCapability.power) ||
                  _connected,
              onClose: () => Navigator.of(context).pop(),
              onPower: () => _send(RemoteCommand.power),
              onForget: _forgetDevice,
              onRetry: () => unawaited(_controller.connect()),
              onPairAgain:
                  _state == RemoteConnectionState.error ? _pairAgain : null,
            ),
            if (_state == RemoteConnectionState.reconnecting)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: DirectionalPad(
                        enabled: _connected,
                        onDirection: _onDirection,
                        onSelect: () => _send(RemoteCommand.select),
                        onDirectionLongPressStart: (direction) =>
                            _controller.startLongPress(_commandFor(direction)),
                        onDirectionLongPressEnd: (direction) =>
                            _controller.endLongPress(_commandFor(direction)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RoundRemoteButton(
                          tooltip: 'Back',
                          icon: Icons.arrow_back_rounded,
                          enabled: _connected,
                          onPressed: () => _send(RemoteCommand.back),
                        ),
                        _RoundRemoteButton(
                          tooltip: 'Home',
                          icon: Icons.home_outlined,
                          enabled: _connected,
                          onPressed: () => _send(RemoteCommand.home),
                        ),
                        _RoundRemoteButton(
                          tooltip: 'Assistant (where supported)',
                          icon: Icons.mic_none_rounded,
                          enabled: _connected,
                          onPressed: () => _controller
                              .sendRawKey(AndroidKeyCodes.search),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _MediaControlsSection(
                      enabled: _connected &&
                          capabilities.contains(RemoteCapability.mediaControl),
                      onCommand: _send,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        _RoundRemoteButton(
                          tooltip: 'Mute',
                          icon: Icons.volume_off_outlined,
                          enabled: _connected &&
                              capabilities.contains(RemoteCapability.volume),
                          onPressed: () => _send(RemoteCommand.mute),
                          size: 56,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VolumePill(
                            enabled: _connected &&
                                capabilities.contains(RemoteCapability.volume),
                            onVolumeDown: () =>
                                _send(RemoteCommand.volumeDown),
                            onVolumeUp: () => _send(RemoteCommand.volumeUp),
                            onVolumeDownLongStart: () => _controller
                                .startLongPress(RemoteCommand.volumeDown),
                            onVolumeDownLongEnd: () => _controller
                                .endLongPress(RemoteCommand.volumeDown),
                            onVolumeUpLongStart: () => _controller
                                .startLongPress(RemoteCommand.volumeUp),
                            onVolumeUpLongEnd: () => _controller
                                .endLongPress(RemoteCommand.volumeUp),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  RemoteCommand _commandFor(String direction) => switch (direction) {
        'up' => RemoteCommand.up,
        'down' => RemoteCommand.down,
        'left' => RemoteCommand.left,
        _ => RemoteCommand.right,
      };
}

class _Header extends StatelessWidget {
  const _Header({
    required this.deviceName,
    required this.state,
    required this.error,
    required this.showPower,
    required this.onClose,
    required this.onPower,
    required this.onForget,
    required this.onRetry,
    required this.onPairAgain,
  });

  final String deviceName;
  final RemoteConnectionState state;
  final String? error;
  final bool showPower;
  final VoidCallback onClose;
  final VoidCallback onPower;
  final VoidCallback onForget;
  final VoidCallback onRetry;
  final VoidCallback? onPairAgain;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close remote',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  switch (state) {
                    RemoteConnectionState.connected => 'Connected',
                    RemoteConnectionState.connecting => 'Connecting…',
                    RemoteConnectionState.reconnecting => 'Reconnecting…',
                    RemoteConnectionState.error => error ?? 'Connection error',
                    _ => 'Disconnected',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: state == RemoteConnectionState.connected
                            ? colors.secondary
                            : state == RemoteConnectionState.error
                                ? colors.error
                                : colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (state == RemoteConnectionState.error) ...[
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            if (onPairAgain != null)
              TextButton(onPressed: onPairAgain, child: const Text('Pair')),
          ],
          IconButton(
            tooltip: 'Power',
            onPressed:
                state == RemoteConnectionState.connected && showPower
                    ? onPower
                    : null,
            icon: const Icon(Icons.power_settings_new),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'forget') onForget();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'forget', child: Text('Forget this TV')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Media playback controls for whatever app is in the foreground on the TV.
///
/// Android TV Remote Protocol v2 does not report playback state, so this uses
/// a combined play/pause toggle and never claims to know whether media is
/// currently playing.
class _MediaControlsSection extends StatelessWidget {
  const _MediaControlsSection({required this.enabled, required this.onCommand});

  final bool enabled;
  final ValueChanged<RemoteCommand> onCommand;

  void _tap(RemoteCommand command) {
    HapticFeedback.lightImpact();
    onCommand(command);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEDIA',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundRemoteButton(
              tooltip: 'Previous',
              icon: Icons.skip_previous_rounded,
              enabled: enabled,
              onPressed: () => _tap(RemoteCommand.previous),
              size: 56,
            ),
            const SizedBox(width: 18),
            IconButton(
              tooltip: 'Play / Pause',
              onPressed: enabled ? () => _tap(RemoteCommand.playPause) : null,
              // Combined glyph: the protocol cannot report playback state.
              icon: const SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 13),
                      child: Icon(Icons.play_arrow_rounded, size: 30),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 17),
                      child: Icon(Icons.pause_rounded, size: 26),
                    ),
                  ],
                ),
              ),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(72),
                backgroundColor: enabled
                    ? const Color(0xFFE3E5E8)
                    : const Color(0xFF2F3133).withValues(alpha: 0.4),
                foregroundColor: const Color(0xFF202124),
                disabledForegroundColor:
                    const Color(0xFFE3E5E8).withValues(alpha: 0.3),
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: 18),
            _RoundRemoteButton(
              tooltip: 'Next',
              icon: Icons.skip_next_rounded,
              enabled: enabled,
              onPressed: () => _tap(RemoteCommand.next),
              size: 56,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundRemoteButton(
              tooltip: 'Rewind',
              icon: Icons.fast_rewind_rounded,
              enabled: enabled,
              onPressed: () => _tap(RemoteCommand.rewind),
              size: 52,
            ),
            const SizedBox(width: 14),
            _RoundRemoteButton(
              tooltip: 'Stop',
              icon: Icons.stop_rounded,
              enabled: enabled,
              onPressed: () => _tap(RemoteCommand.stop),
              size: 52,
            ),
            const SizedBox(width: 14),
            _RoundRemoteButton(
              tooltip: 'Fast forward',
              icon: Icons.fast_forward_rounded,
              enabled: enabled,
              onPressed: () => _tap(RemoteCommand.fastForward),
              size: 52,
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundRemoteButton extends StatelessWidget {
  const _RoundRemoteButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.size = 64,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled
          ? () {
              HapticFeedback.lightImpact();
              onPressed();
            }
          : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        backgroundColor: const Color(0xFF2F3133),
        foregroundColor: const Color(0xFFE3E5E8),
        disabledBackgroundColor: const Color(0xFF2F3133).withValues(alpha: 0.4),
        disabledForegroundColor:
            const Color(0xFFE3E5E8).withValues(alpha: 0.3),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// Joined pill-shaped volume down/up control from the reference design.
class _VolumePill extends StatelessWidget {
  const _VolumePill({
    required this.enabled,
    required this.onVolumeDown,
    required this.onVolumeUp,
    required this.onVolumeDownLongStart,
    required this.onVolumeDownLongEnd,
    required this.onVolumeUpLongStart,
    required this.onVolumeUpLongEnd,
  });

  final bool enabled;
  final VoidCallback onVolumeDown;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDownLongStart;
  final VoidCallback onVolumeDownLongEnd;
  final VoidCallback onVolumeUpLongStart;
  final VoidCallback onVolumeUpLongEnd;

  @override
  Widget build(BuildContext context) {
    final background = enabled
        ? const Color(0xFF2F3133)
        : const Color(0xFF2F3133).withValues(alpha: 0.4);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 56,
        color: background,
        child: Row(
          children: [
            Expanded(
              child: _VolumeHalf(
                icon: Icons.volume_down_rounded,
                tooltip: 'Volume down',
                enabled: enabled,
                onTap: onVolumeDown,
                onLongStart: onVolumeDownLongStart,
                onLongEnd: onVolumeDownLongEnd,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.35),
            ),
            Expanded(
              child: _VolumeHalf(
                icon: Icons.volume_up_rounded,
                tooltip: 'Volume up',
                enabled: enabled,
                onTap: onVolumeUp,
                onLongStart: onVolumeUpLongStart,
                onLongEnd: onVolumeUpLongEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeHalf extends StatelessWidget {
  const _VolumeHalf({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.onLongStart,
    required this.onLongEnd,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongStart;
  final VoidCallback onLongEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: enabled ? (_) => onLongStart() : null,
      onLongPressEnd: enabled ? (_) => onLongEnd() : null,
      onLongPressCancel: enabled ? onLongEnd : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              : null,
          child: Center(
            child: Icon(
              icon,
              color: enabled
                  ? const Color(0xFFE3E5E8)
                  : const Color(0xFFE3E5E8).withValues(alpha: 0.3),
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
