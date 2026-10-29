import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/protocol/android_tv/android_key_codes.dart';
import '../../../core/protocol/android_tv/android_tv_remote_client.dart';
import '../../../shared/presentation/adaptive_layout.dart';
import '../../../shared/presentation/app_theme.dart';
import '../../apps/app_launcher.dart';
import '../../apps/app_shortcut_store.dart';
import '../../apps/presentation/app_shortcuts_section.dart';
import '../../apps/tv_app.dart';
import '../../pairing/paired_device_store.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../android_tv_remote_controller.dart';
import '../remote_controller.dart';
import 'widgets/directional_pad.dart';
import 'tv_keyboard_sheet.dart';
import '../../household/tv_preferences.dart';
import '../../household/presentation/control_setup_sheet.dart';

class AndroidTvRemoteScreen extends StatefulWidget {
  const AndroidTvRemoteScreen({
    required this.controller,
    this.embedded = false,
    this.active = true,
    this.onChooseDevice,
    this.onRetry,
    this.onForget,
    this.shortcutStore,
    this.onManageApps,
    this.preferenceStore,
    this.onRoutines,
    super.key,
  });

  final AndroidTvRemoteController controller;
  final bool embedded;
  final bool active;
  final VoidCallback? onChooseDevice;
  final VoidCallback? onRetry;
  final VoidCallback? onForget;
  final AppShortcutStore? shortcutStore;
  final VoidCallback? onManageApps;
  final TvPreferenceStore? preferenceStore;
  final VoidCallback? onRoutines;

  @override
  State<AndroidTvRemoteScreen> createState() => _AndroidTvRemoteScreenState();
}

class _AndroidTvRemoteScreenState extends State<AndroidTvRemoteScreen>
    with WidgetsBindingObserver {
  AndroidTvRemoteController get _controller => widget.controller;
  StreamSubscription<RemoteConnectionState>? _stateSubscription;
  StreamSubscription<String>? _appSubscription;
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  String? _activePackage;
  TvPreferences _preferences = const TvPreferences();
  TvPreferenceStore get _preferenceStore =>
      widget.preferenceStore ?? AppServices.instance.tvPreferences;
  StreamSubscription<AndroidTvVolumeInfo>? _volumeSubscription;
  StreamSubscription<bool>? _powerSubscription;
  Timer? _reportTicker;
  Future<void> _loadPreferences() async {
    try {
      final value = await _preferenceStore.load(
        _controller.pairedDevice.serviceName,
      );
      if (mounted) setState(() => _preferences = value);
    } catch (_) {
      /* Defaults retain control if storage is temporarily unavailable. */
    }
  }

  bool get _connected => _state == RemoteConnectionState.connected;
  bool _supports(RemoteCommand command) =>
      widget.active &&
      _controller.supports(command) &&
      (command != RemoteCommand.power || _preferences.power) &&
      (![
            RemoteCommand.volumeUp,
            RemoteCommand.volumeDown,
            RemoteCommand.mute,
          ].contains(command) ||
          _preferences.volume);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preferenceStore.addListener(_loadPreferences);
    unawaited(_loadPreferences());
    _volumeSubscription = _controller.client.volumeInfoUpdates.listen((_) {
      if (mounted) setState(() {});
    });
    _powerSubscription = _controller.client.powerStateUpdates.listen((_) {
      if (mounted) setState(() {});
    });
    _reportTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && widget.active) setState(() {});
    });
    _state = _controller.connectionState;
    _activePackage = _controller.currentApp;
    _stateSubscription = _controller.connectionStates.listen((state) {
      if (!mounted) return;
      if (state != RemoteConnectionState.connected) {
        _controller.cancelHeldCommands();
      }
      setState(() {
        _state = state;
        if (!_connected) _activePackage = null;
      });
    });
    _appSubscription = _controller.currentAppUpdates.listen((package) {
      if (mounted) setState(() => _activePackage = package);
    });
    // The shell owns connection attempts, address refresh, and replacement.
    if (!widget.embedded) unawaited(_controller.connect());
  }

  @override
  void didUpdateWidget(AndroidTvRemoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _controller.cancelHeldCommands();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.cancelHeldCommands();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preferenceStore.removeListener(_loadPreferences);
    _volumeSubscription?.cancel();
    _powerSubscription?.cancel();
    _reportTicker?.cancel();
    _controller.cancelHeldCommands();
    _stateSubscription?.cancel();
    _appSubscription?.cancel();
    super.dispose();
  }

  void _send(RemoteCommand command) {
    if (_connected && widget.active) {
      unawaited(_controller.sendCommand(command));
    }
  }

  RemoteCommand _commandFor(String direction) => switch (direction) {
    'up' => RemoteCommand.up,
    'down' => RemoteCommand.down,
    'left' => RemoteCommand.left,
    _ => RemoteCommand.right,
  };

  Future<void> _launchApp(TvApp app) async {
    final result = await launchTvApp(
      _controller,
      app,
      isCurrentTarget: () => mounted && _connected && widget.active,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message(app.name, _controller.deviceName))),
    );
  }

  Future<void> _pairAgain() async {
    _controller.cancelHeldCommands();
    await _controller.disconnect();
    if (!mounted) return;
    final paired = await Navigator.of(context).push<PairedAndroidTv>(
      MaterialPageRoute(
        builder: (_) => PairingScreen(
          serviceName: _controller.pairedDevice.serviceName,
          displayName: _controller.pairedDevice.displayName,
          host: _controller.pairedDevice.lastHost,
        ),
      ),
    );
    if (paired == null || !mounted) return;
    _controller.updatePairedDevice(paired);
    _retry();
  }

  void _retry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
    } else {
      unawaited(_controller.connect());
    }
  }

  void _keyboard() {
    _controller.cancelHeldCommands();
    showTvKeyboard(
      context,
      target: _controller,
      isCurrentTarget: () => mounted && widget.active && _connected,
    );
  }

  void _moreControls() {
    _controller.cancelHeldCommands();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _MediaControlsSection(
            enabled: _supports(RemoteCommand.playPause),
            onCommand: _send,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = switch (_state) {
      RemoteConnectionState.connected =>
        widget.active ? 'Connected' : 'Controls paused',
      RemoteConnectionState.connecting => 'Connecting…',
      RemoteConnectionState.reconnecting => 'Reconnecting…',
      RemoteConnectionState.pairing => 'Pairing…',
      RemoteConnectionState.error => 'Connection needs attention',
      RemoteConnectionState.disconnected => 'Disconnected',
    };
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: widget.onChooseDevice != null,
                  child: InkWell(
                    onTap: widget.onChooseDevice,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _controller.deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _connected
                                    ? colors.secondary
                                    : colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Phone keyboard',
                onPressed: widget.active && _controller.textInputSupported
                    ? _keyboard
                    : null,
                icon: const Icon(Icons.keyboard_outlined),
              ),
              IconButton(
                tooltip: 'Power',
                onPressed: _supports(RemoteCommand.power)
                    ? () => _send(RemoteCommand.power)
                    : null,
                icon: const Icon(Icons.power_settings_new_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: 'Remote options',
                onSelected: (value) {
                  _controller.cancelHeldCommands();
                  switch (value) {
                    case 'routines':
                      widget.onRoutines?.call();
                    case 'setup':
                      unawaited(
                        showControlSetup(
                          context,
                          _controller,
                          _preferenceStore,
                        ),
                      );
                    case 'media':
                      _moreControls();
                    case 'search':
                      _controller.sendRawKey(AndroidKeyCodes.search);
                    case 'pair':
                      unawaited(_pairAgain());
                    case 'forget':
                      widget.onForget?.call();
                  }
                },
                itemBuilder: (_) => [
                  if (widget.onRoutines != null)
                    const PopupMenuItem(
                      value: 'routines',
                      child: Text('TV and audio routines'),
                    ),
                  const PopupMenuItem(
                    value: 'setup',
                    child: Text('Controls and room setup'),
                  ),
                  const PopupMenuItem(
                    value: 'media',
                    child: Text('More playback controls'),
                  ),
                  PopupMenuItem(
                    value: 'search',
                    enabled: _connected && widget.active,
                    child: const Text('Search on TV'),
                  ),
                  PopupMenuItem(
                    value: 'pair',
                    enabled:
                        widget.active &&
                        _state != RemoteConnectionState.connecting,
                    child: const Text('Pair again'),
                  ),
                  if (widget.onForget != null)
                    const PopupMenuItem(
                      value: 'forget',
                      child: Text('Forget this TV'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_state == RemoteConnectionState.connecting ||
            _state == RemoteConnectionState.reconnecting)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tablet =
                  constraints.maxWidth >= 700 && constraints.maxHeight >= 550;
              final padSize = (constraints.maxHeight - 246).clamp(
                160.0,
                tablet || _preferences.eyesUp ? 340.0 : 270.0,
              );
              return SingleChildScrollView(
                key: PageStorageKey(
                  'remote-${_controller.pairedDevice.serviceName}',
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: AdaptiveContent(
                  child: Column(
                    children: [
                      if (_state == RemoteConnectionState.error ||
                          _state == RemoteConnectionState.disconnected)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              Text(
                                _controller.requiresPairing
                                    ? 'This TV needs to be paired again.'
                                    : 'Could not reach this TV. Check its power and Wi-Fi, then retry. It may have a new network address.',
                                textAlign: TextAlign.center,
                              ),
                              Wrap(
                                spacing: 12,
                                children: [
                                  FilledButton(
                                    onPressed: _controller.requiresPairing
                                        ? _pairAgain
                                        : _retry,
                                    child: Text(
                                      _controller.requiresPairing
                                          ? 'Pair again'
                                          : 'Find and reconnect',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onChooseDevice,
                                    child: const Text('Choose TV'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (_preferences.eyesUp)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Eyes-up mode · larger navigation',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      if (tablet)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _essentialControls(padSize)),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                children: [
                                  _foregroundApp(),
                                  if (!_preferences.eyesUp) _shortcuts(),
                                  const SizedBox(height: 24),
                                  _MediaControlsSection(
                                    enabled: _supports(RemoteCommand.playPause),
                                    onCommand: _send,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _essentialControls(padSize),
                        const SizedBox(height: 12),
                        _foregroundApp(),
                        if (!_preferences.eyesUp) _shortcuts(),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
    return widget.embedded ? body : Scaffold(body: SafeArea(child: body));
  }

  Widget _essentialControls(double padSize) => Column(
    children: [
      DirectionalPad(
        enabled: _supports(RemoteCommand.select),
        maxDiameter: padSize,
        onDirection: (direction) => _send(_commandFor(direction)),
        onSelect: () => _send(RemoteCommand.select),
        onDirectionLongPressStart: (direction) =>
            _controller.startLongPress(_commandFor(direction)),
        onDirectionLongPressEnd: (direction) =>
            _controller.endLongPress(_commandFor(direction)),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundRemoteButton(
            tooltip: 'Back on TV',
            icon: Icons.arrow_back_rounded,
            size: 56,
            enabled: _supports(RemoteCommand.back),
            onPressed: () => _send(RemoteCommand.back),
          ),
          _RoundRemoteButton(
            tooltip: 'TV Home',
            icon: Icons.home_outlined,
            size: 56,
            enabled: _supports(RemoteCommand.home),
            onPressed: () => _send(RemoteCommand.home),
          ),
          _RoundRemoteButton(
            tooltip: 'Play / pause',
            icon: Icons.play_arrow_rounded,
            size: 56,
            iconWidget: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 20),
                Icon(Icons.pause_rounded, size: 18),
              ],
            ),
            enabled: _supports(RemoteCommand.playPause),
            onPressed: () => _send(RemoteCommand.playPause),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          StreamBuilder<AndroidTvVolumeInfo>(
            stream: _controller.client.volumeInfoUpdates,
            initialData: _controller.client.volumeInfo,
            builder: (context, snapshot) => _RoundRemoteButton(
              tooltip: _connected && snapshot.data?.muted == true
                  ? 'Unmute'
                  : 'Mute',
              icon: _connected && snapshot.data?.muted == true
                  ? Icons.volume_off
                  : Icons.volume_off_outlined,
              size: 56,
              enabled: _supports(RemoteCommand.mute),
              onPressed: () => _send(RemoteCommand.mute),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _VolumePill(
              enabled: _supports(RemoteCommand.volumeUp),
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
      ),
      if (_connected &&
          (!_preferences.volume ||
              !_controller.capabilities.contains(RemoteCapability.volume)))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_preferences.volume ? 'Volume is not available through this TV connection.' : 'Volume is disabled in this TV’s control setup.'),
        ),
    ],
  );

  Widget _foregroundApp() {
    final app = matchByPackage(catalogApps, _activePackage);
    final name =
        app?.name ??
        (_activePackage == null
            ? null
            : _activePackage!.contains('launcher')
            ? 'TV Home'
            : 'TV app');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '${_connected && name != null ? 'On TV: $name' : 'TV activity unavailable'}\n${_controller.reportedState.describe(DateTime.now().toUtc())}',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _shortcuts() => AppShortcutsSection(
    store:
        widget.shortcutStore ??
        AppServices.instance.appShortcuts.forDevice(
          _controller.pairedDevice.serviceName,
        ),
    enabled:
        widget.active &&
        _controller.capabilities.contains(RemoteCapability.appLaunch),
    activePackage: _activePackage,
    onLaunch: _launchApp,
    onManage: widget.onManageApps,
  );
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
                    ? AppColors.actionFill
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
    this.iconWidget,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final double size;
  final Widget? iconWidget;

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
      icon: iconWidget ?? Icon(icon),
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
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
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
      ),
    );
  }
}
