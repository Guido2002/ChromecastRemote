import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/protocol/android_tv/android_key_codes.dart';
import '../../../shared/presentation/adaptive_layout.dart';
import '../../../shared/presentation/app_motion.dart';
import '../../apps/presentation/app_shortcuts_section.dart';
import '../../apps/tv_app.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../android_tv_remote_controller.dart';
import '../remote_controller.dart';
import 'widgets/directional_pad.dart';

const _playStorePackage = 'com.android.vending';

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
  StreamSubscription<String>? _appSubscription;
  Timer? _storeOpenTimer;
  Timer? _storeLaunchExpiry;
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  String? _activePackage;
  String? _pendingStoreLaunchPackage;

  @override
  void initState() {
    super.initState();
    _state = _controller.connectionState;
    _activePackage = _controller.currentApp;
    _stateSubscription = _controller.connectionStates.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _appSubscription = _controller.currentAppUpdates.listen((package) {
      if (mounted) setState(() => _activePackage = package);
      _handleForegroundApp(package);
    });
    unawaited(_controller.connect());
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _appSubscription?.cancel();
    _storeOpenTimer?.cancel();
    _storeLaunchExpiry?.cancel();
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

  void _launchApp(TvApp app) {
    _clearPendingStoreLaunch();
    _controller.launchAppLink(app.launchUrl);
    if (!app.requiresStoreOpenConfirmation) return;

    _pendingStoreLaunchPackage = app.packageName;
    _storeLaunchExpiry = Timer(
      const Duration(seconds: 4),
      _clearPendingStoreLaunch,
    );

    // If the Play Store was already foregrounded, its package may not emit a
    // second update. Allow the NPO details page time to settle before Open.
    if (_activePackage == _playStorePackage) {
      _scheduleStoreOpenConfirmation(const Duration(milliseconds: 850));
    }
  }

  void _handleForegroundApp(String package) {
    final target = _pendingStoreLaunchPackage;
    if (target == null) return;
    if (package == target) {
      _clearPendingStoreLaunch();
    } else if (package == _playStorePackage) {
      _scheduleStoreOpenConfirmation(const Duration(milliseconds: 550));
    }
  }

  void _scheduleStoreOpenConfirmation(Duration delay) {
    _storeOpenTimer?.cancel();
    _storeOpenTimer = Timer(delay, () {
      if (!mounted ||
          !_connected ||
          _pendingStoreLaunchPackage == null ||
          _activePackage != _playStorePackage) {
        return;
      }
      _clearPendingStoreLaunch();
      unawaited(_controller.sendCommand(RemoteCommand.select));
    });
  }

  void _clearPendingStoreLaunch() {
    _storeOpenTimer?.cancel();
    _storeOpenTimer = null;
    _storeLaunchExpiry?.cancel();
    _storeLaunchExpiry = null;
    _pendingStoreLaunchPackage = null;
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
    final tablet = AdaptiveLayout.isTablet(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              tablet: tablet,
              deviceName: _controller.deviceName,
              state: _state,
              error: _controller.lastError,
              showPower:
                  capabilities.contains(RemoteCapability.power) || _connected,
              onClose: () => Navigator.of(context).pop(),
              onPower: () => _send(RemoteCommand.power),
              onForget: _forgetDevice,
              onRetry: () => unawaited(_controller.connect()),
              onPairAgain: _pairAgain,
            ),
            if (_state == RemoteConnectionState.reconnecting)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: AdaptiveLayout.pagePadding(context),
                child: AdaptiveContent(
                  child: MotionEntrance(
                    child: tablet
                        ? _buildTabletControls(capabilities)
                        : _buildPhoneControls(capabilities),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneControls(Set<RemoteCapability> capabilities) {
    return Column(
      children: [
        _directionalPad(maxDiameter: 300),
        const SizedBox(height: 20),
        _navigationButtons(),
        const SizedBox(height: 22),
        _appShortcuts(capabilities),
        const SizedBox(height: 28),
        _mediaControls(capabilities),
        const SizedBox(height: 28),
        _volumeControls(capabilities),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTabletControls(Set<RemoteCapability> capabilities) {
    return Row(
      key: const ValueKey('android-tv-tablet-layout'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: TabletPanel(
            child: Column(
              children: [
                _sectionHeading('NAVIGATION'),
                const SizedBox(height: 18),
                _directionalPad(maxDiameter: 370),
                const SizedBox(height: 22),
                _navigationButtons(),
                const SizedBox(height: 26),
                _sectionHeading('VOLUME'),
                const SizedBox(height: 12),
                _volumeControls(capabilities),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              TabletPanel(child: _appShortcuts(capabilities)),
              const SizedBox(height: 24),
              TabletPanel(child: _mediaControls(capabilities)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeading(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _directionalPad({double maxDiameter = 340}) => Center(
    child: DirectionalPad(
      enabled: _connected,
      maxDiameter: maxDiameter,
      onDirection: _onDirection,
      onSelect: () => _send(RemoteCommand.select),
      onDirectionLongPressStart: (direction) =>
          _controller.startLongPress(_commandFor(direction)),
      onDirectionLongPressEnd: (direction) =>
          _controller.endLongPress(_commandFor(direction)),
    ),
  );

  Widget _navigationButtons() => Row(
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
        onPressed: () => _controller.sendRawKey(AndroidKeyCodes.search),
      ),
    ],
  );

  Widget _appShortcuts(Set<RemoteCapability> capabilities) =>
      AppShortcutsSection(
        store: AppServices.instance.appShortcuts,
        enabled:
            _connected && capabilities.contains(RemoteCapability.appLaunch),
        activePackage: _activePackage,
        onLaunch: _launchApp,
      );

  Widget _mediaControls(Set<RemoteCapability> capabilities) =>
      _MediaControlsSection(
        enabled:
            _connected && capabilities.contains(RemoteCapability.mediaControl),
        onCommand: _send,
      );

  Widget _volumeControls(Set<RemoteCapability> capabilities) {
    final enabled =
        _connected && capabilities.contains(RemoteCapability.volume);
    return Row(
      children: [
        _RoundRemoteButton(
          tooltip: 'Mute',
          icon: Icons.volume_off_outlined,
          enabled: enabled,
          onPressed: () => _send(RemoteCommand.mute),
          size: 56,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _VolumePill(
            enabled: enabled,
            onVolumeDown: () => _send(RemoteCommand.volumeDown),
            onVolumeUp: () => _send(RemoteCommand.volumeUp),
            onVolumeDownLongStart: () =>
                _controller.startLongPress(RemoteCommand.volumeDown),
            onVolumeDownLongEnd: () =>
                _controller.endLongPress(RemoteCommand.volumeDown),
            onVolumeUpLongStart: () =>
                _controller.startLongPress(RemoteCommand.volumeUp),
            onVolumeUpLongEnd: () =>
                _controller.endLongPress(RemoteCommand.volumeUp),
          ),
        ),
      ],
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
    required this.tablet,
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
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: AdaptiveContent(
        child: Padding(
          padding: EdgeInsets.fromLTRB(tablet ? 20 : 4, 8, tablet ? 20 : 8, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to devices',
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.tv_rounded, color: colors.onPrimaryContainer),
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
                    const SizedBox(height: 3),
                    _ConnectionStatus(state: state, error: error),
                  ],
                ),
              ),
              if (state == RemoteConnectionState.error) ...[
                IconButton(
                  tooltip: 'Retry connection',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              IconButton(
                tooltip: 'Power',
                onPressed: state == RemoteConnectionState.connected && showPower
                    ? onPower
                    : null,
                icon: const Icon(Icons.power_settings_new_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHigh,
                  shape: const CircleBorder(),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'pair') onPairAgain?.call();
                  if (value == 'forget') onForget();
                },
                itemBuilder: (context) => [
                  if (onPairAgain != null)
                    const PopupMenuItem(
                      value: 'pair',
                      child: ListTile(
                        leading: Icon(Icons.link_rounded),
                        title: Text('Pair again'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'forget',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Forget this TV'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.state, required this.error});

  final RemoteConnectionState state;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (state) {
      RemoteConnectionState.connected => ('Connected', colors.secondary),
      RemoteConnectionState.pairing => ('Pairing…', colors.primary),
      RemoteConnectionState.connecting => ('Connecting…', colors.primary),
      RemoteConnectionState.reconnecting => ('Reconnecting…', colors.primary),
      RemoteConnectionState.error => (
        error ?? 'Connection error',
        colors.error,
      ),
      RemoteConnectionState.disconnected => (
        'Disconnected',
        colors.onSurfaceVariant,
      ),
    };

    return AnimatedSwitcher(
      duration: AppMotion.standard,
      child: Row(
        key: ValueKey(state),
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppMotion.standard,
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
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
                    ? colors.primary
                    : colors.surfaceContainerHigh.withValues(alpha: 0.5),
                foregroundColor: colors.onPrimary,
                disabledForegroundColor: colors.onSurface.withValues(
                  alpha: 0.3,
                ),
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
    final colors = Theme.of(context).colorScheme;
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
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurface,
        disabledBackgroundColor: colors.surfaceContainerHigh.withValues(
          alpha: 0.4,
        ),
        disabledForegroundColor: colors.onSurface.withValues(alpha: 0.3),
        overlayColor: colors.primary.withValues(alpha: 0.12),
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
    final colors = Theme.of(context).colorScheme;
    final background = enabled
        ? colors.surfaceContainerHigh
        : colors.surfaceContainerHigh.withValues(alpha: 0.4);
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
              color: colors.outlineVariant,
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
    final colors = Theme.of(context).colorScheme;
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
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.3),
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
