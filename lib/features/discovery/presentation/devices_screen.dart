import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../../core/app_services.dart';
import '../../../shared/presentation/adaptive_layout.dart';
import '../../../shared/presentation/app_motion.dart';
import '../../../shared/models/discovered_device.dart';
import '../../apps/presentation/app_library_view.dart';
import '../../apps/tv_app.dart';
import '../../apps/app_launcher.dart';
import '../../household/room_suggestions.dart';
import '../../automation/presentation/routines_screen.dart';
import '../../pairing/paired_device_store.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../../remote/presentation/android_tv_remote_screen.dart';
import '../../remote/presentation/cast_remote_screen.dart';
import '../../remote/presentation/smart_remote_view.dart';
import '../../remote/smart_now_playing.dart';
import '../../remote/remote_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../update/presentation/update_actions.dart';

/// Home screen: live list of Google TV / Android TV and Chromecast devices
/// found on the local Wi-Fi network.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    this.castAvailable = true,
    this.castInitializing = false,
    this.onRetryCast,
    super.key,
  });

  final bool castAvailable;
  final bool castInitializing;
  final VoidCallback? onRetryCast;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with WidgetsBindingObserver {
  final _services = AppServices.instance;
  static const _navigation = MethodChannel('chromecast_remote/navigation');
  StreamSubscription<List<DiscoveredDevice>>? _subscription;
  StreamSubscription<RemoteConnectionState>? _connectionSubscription;
  List<DiscoveredDevice> _devices = const [];
  List<PairedAndroidTv> _pairedDevices = const [];
  bool _scanning = false;
  bool _foreground = true;
  int _scanRequests = 0;
  bool _autoReconnectAttempted = false;
  String? _openingDeviceId;
  String? _error;
  int _sectionIndex = 2;
  GoogleCastDevice? _castDevice;
  CastPlaybackMonitor? _castPlayback;
  final _noCast = ValueNotifier(const CastPlaybackSnapshot());
  List<SavedCastReceiver> _savedCast = [];
  String? _restoringCastId;
  TvApp? _pendingApp;
  bool _userSelected = false;
  String? _room;
  bool _roomTouched = false;
  RemoteConnectionState _connectionState = RemoteConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _services.tvPreferences.addListener(_preferencesChanged);
    _observeCast();
    unawaited(_restoreRoom());
    _navigation.setMethodCallHandler((call) async {
      if (call.method == 'openRemote') {
        await _navigation.invokeMethod<bool>('consumeOpenRemote');
        if (mounted) setState(() => _sectionIndex = 0);
      }
    });
    unawaited(_consumeQuickAccess());
    _subscription = _services.discovery.devices.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (_restoringCastId != null) {
          for (final device in devices) {
            if (device.id == _restoringCastId) _castDevice = device.castDevice;
          }
        }
      });
    });
    _connectionState = _services.androidTvConnection.state;
    _connectionSubscription = _services.androidTvConnection.changes.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() => _connectionState = state);
      if (state == RemoteConnectionState.connected) {
        unawaited(_loadPairedDevices());
      }
    });
    unawaited(_startScan());
    unawaited(_loadPairedDevices());
    unawaited(_reconnectToLastDevice());
    // Silent update check once per launch; only speaks up when a newer
    // release exists on GitHub.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(checkForAppUpdate(context, userInitiated: false));
    });
  }

  void _observeCast() {
    if (!widget.castAvailable || _castPlayback != null) return;
    _castPlayback = CastPlaybackMonitor(
      sessions: GoogleCastSessionManager.instance.currentSessionStream,
      mediaUpdates: GoogleCastRemoteMediaClient.instance.mediaStatusStream,
      currentSession: () => GoogleCastSessionManager.instance.currentSession,
      currentMedia: () => GoogleCastRemoteMediaClient.instance.mediaStatus,
    )..setActive(_foreground);
  }

  void _preferencesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreRoom() async {
    final room = await _services.secureStore.read('selected_room_v1');
    if (mounted && !_roomTouched) setState(() => _room = room);
  }

  Future<void> _consumeQuickAccess() async {
    try {
      final requested = await _navigation.invokeMethod<bool>(
        'consumeOpenRemote',
      );
      if (requested == true && mounted) setState(() => _sectionIndex = 0);
    } on MissingPluginException {
      // Other platforms can use the regular application entry point.
    }
  }

  /// Restore the last remote in place; discovery refreshes its endpoint.
  Future<void> _reconnectToLastDevice() async {
    if (_autoReconnectAttempted) return;
    _autoReconnectAttempted = true;
    try {
      final last = await _services.pairedDevices.loadLastDevice();
      if (last == null || !mounted || _userSelected) return;
      if (last.protocol == 'googleCast') {
        setState(() {
          _restoringCastId = last.id;
          _sectionIndex = 0;
        });
        for (final device in _devices) {
          if (device.id == last.id) {
            setState(() => _castDevice = device.castDevice);
          }
        }
        return;
      }
      if (last.protocol != 'androidTvRemote') return;
      final paired = await _services.pairedDevices.findByServiceName(last.id);
      if (paired == null || !mounted || _userSelected) return;
      if (mounted) {
        setState(() {
          _openingDeviceId = paired.serviceName;
          _sectionIndex = 0;
        });
      }
      await _services.androidTvConnection.connect(paired);
    } catch (_) {
      // Auto-reconnect is best-effort; discovery remains available.
    } finally {
      if (mounted) setState(() => _openingDeviceId = null);
    }
  }

  Future<void> _startScan() async {
    if (!mounted || !_foreground) return;
    _scanRequests++;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      await _services.discovery.start(castAvailable: widget.castAvailable);
      if (mounted && _services.discovery.errors.isNotEmpty) {
        setState(() => _error = _services.discovery.errors.join('\n'));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Discovery could not start. Check Wi-Fi and local network access, then try again.',
        );
      }
    } finally {
      _scanRequests--;
      if (mounted) setState(() => _scanning = _scanRequests > 0);
    }
  }

  Future<void> _rescan() async {
    if (_scanning) return;
    await _services.discovery.stop();
    await _startScan();
  }

  Future<void> _loadPairedDevices() async {
    final devices = await _services.pairedDevices.loadPairedDevices();
    final cast = await _services.pairedDevices.loadCastReceivers();
    await Future.wait(
      devices.map((device) => _services.tvPreferences.load(device.serviceName)),
    );
    devices.sort((a, b) => b.pairedAt.compareTo(a.pairedAt));
    if (mounted) {
      setState(() {
        _pairedDevices = devices;
        _savedCast = cast;
      });
    }
  }

  @override
  void didUpdateWidget(DevicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.castAvailable && !oldWidget.castAvailable) {
      _observeCast();
      unawaited(_startScan());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _castPlayback?.setActive(false);
      _services.androidTvConnection.controller?.cancelHeldCommands();
      unawaited(_services.discovery.stop());
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      _castPlayback?.setActive(true);
      unawaited(_startScan());
      final controller = _services.androidTvConnection.controller;
      if (_castDevice == null &&
          controller != null &&
          !controller.requiresPairing &&
          controller.connectionState != RemoteConnectionState.connected &&
          controller.connectionState != RemoteConnectionState.connecting) {
        unawaited(
          _services.androidTvConnection.connect(controller.pairedDevice),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _services.tvPreferences.removeListener(_preferencesChanged);
    _castPlayback?.dispose();
    _noCast.dispose();
    _navigation.setMethodCallHandler(null);
    _subscription?.cancel();
    _connectionSubscription?.cancel();
    unawaited(_services.discovery.stop());
    super.dispose();
  }

  Future<void> _openDevice(DiscoveredDevice device) async {
    if (_openingDeviceId != null) return;
    _userSelected = true;
    setState(() => _openingDeviceId = device.id);
    try {
      switch (device.protocol) {
        case DeviceProtocol.androidTvRemote:
          await _openAndroidTv(device);
        case DeviceProtocol.googleCast:
          await _openCastDevice(device);
      }
    } finally {
      if (mounted) setState(() => _openingDeviceId = null);
    }
  }

  Future<void> _openAndroidTv(DiscoveredDevice device) async {
    final host = device.host;
    if (host == null) return;

    final serviceName = device.id.substring('atv:'.length);
    final paired = await _services.pairedDevices.findByServiceName(serviceName);
    if (!mounted) return;

    if (paired == null) {
      // Not paired yet — run the pairing flow first.
      final pairedDevice = await Navigator.of(context).push<PairedAndroidTv>(
        MaterialPageRoute(
          builder: (_) => PairingScreen(
            serviceName: serviceName,
            displayName: device.name,
            host: host,
          ),
        ),
      );
      if (pairedDevice == null || !mounted) return;
      await _loadPairedDevices();
      await _openPairedAndroidTv(pairedDevice);
    } else {
      // Refresh the last known address with what discovery just resolved.
      var current = paired;
      if (paired.lastHost != host) {
        current = paired.copyWithHost(host);
        await _services.pairedDevices.save(current);
      }
      if (!mounted) return;
      await _openPairedAndroidTv(current);
    }
  }

  Future<void> _openPairedAndroidTv(PairedAndroidTv pairedDevice) async {
    final controller = await _services.androidTvConnection.connect(
      pairedDevice,
    );
    if (!mounted) return;
    setState(() {
      _castDevice = null;
      _restoringCastId = null;
      _sectionIndex = 0;
    });
    await _loadPairedDevices();
    if (controller.connectionState == RemoteConnectionState.connected) {
      if (_pendingApp != null && mounted) {
        setState(() => _openingDeviceId = null);
      }
      await _resumePendingApp();
    }
  }

  Future<bool> _launchApp(
    TvApp app, {
    String? expectedDeviceId,
    bool chooseBeforeLaunch = false,
  }) async {
    final controller = _services.androidTvConnection.controller;
    if (expectedDeviceId != null &&
        controller?.pairedDevice.serviceName != expectedDeviceId) {
      _showMessage(
        'TV selection changed. Choose the destination again before opening ${app.name}.',
      );
      return false;
    }
    if (chooseBeforeLaunch ||
        _castDevice != null ||
        controller == null ||
        controller.connectionState != RemoteConnectionState.connected) {
      setState(() {
        _pendingApp = app;
        _sectionIndex = 2;
      });
      _showMessage(
        'Choose a TV remote for ${app.name}. You will confirm the destination before opening.',
      );
      return false;
    }
    final result = await launchTvApp(
      controller,
      app,
      isCurrentTarget: () =>
          mounted &&
          _castDevice == null &&
          _openingDeviceId == null &&
          identical(controller, _services.androidTvConnection.controller),
    );
    if (!mounted) return false;
    _showMessage(result.message(app.name, controller.deviceName));
    return result != AppLaunchOutcome.failed &&
        result != AppLaunchOutcome.cancelled;
  }

  Future<void> _resumePendingApp() async {
    final app = _pendingApp;
    if (app == null || !mounted) return;
    _pendingApp = null;
    final controller = _services.androidTvConnection.controller;
    if (controller == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open ${app.name}?'),
        content: Text('Open on ${controller.deviceName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open on TV'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        identical(controller, _services.androidTvConnection.controller)) {
      await _launchApp(app);
    }
  }

  Future<void> _renameSavedDevice(PairedAndroidTv device) async {
    final nameController = TextEditingController(text: device.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename TV'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'TV name'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.isEmpty || name == device.displayName) return;
    await _services.androidTvConnection.rename(device, name);
    await _loadPairedDevices();
  }

  Future<void> _forgetSavedDevice(PairedAndroidTv device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this TV?'),
        content: Text(
          'Remove ${device.displayName} and its trusted pairing? You will need to pair again.',
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
    if (confirmed != true) return;
    await _services.androidTvConnection.forget(device);
    await _loadPairedDevices();
    _showMessage('${device.displayName} was forgotten');
  }

  Future<void> _openSavedDevice(PairedAndroidTv device) async {
    if (_openingDeviceId != null) return;
    _userSelected = true;
    setState(() => _openingDeviceId = device.serviceName);
    try {
      await _openPairedAndroidTv(device);
    } finally {
      if (mounted) setState(() => _openingDeviceId = null);
    }
  }

  Future<void> _openCastDevice(DiscoveredDevice device) async {
    final castDevice = device.castDevice;
    if (castDevice == null) return;
    try {
      final started = await GoogleCastSessionManager.instance
          .startSessionWithDevice(castDevice);
      if (!started) {
        _showMessage(
          'Could not start a Cast session. Another app may already be '
          'casting to this device.',
        );
        return;
      }
      await _services.pairedDevices.rememberCastReceiver(
        SavedCastReceiver(id: device.id, name: device.name),
      );
      await _loadPairedDevices();
      await _services.pairedDevices.saveLastDevice(
        id: device.id,
        protocol: 'googleCast',
      );
      if (!mounted) return;
      await _services.androidTvConnection.controller?.disconnect();
      if (!mounted) return;
      setState(() {
        _restoringCastId = null;
        _castDevice = castDevice;
        _sectionIndex = 0;
      });
    } catch (error) {
      _showMessage('Could not connect to ${device.name}: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _chooseDevice() {
    _services.androidTvConnection.controller?.cancelHeldCommands();
    setState(() => _sectionIndex = 2);
  }

  void _openRoutines() {
    final tv = _castDevice == null
        ? _services.androidTvConnection.controller
        : null;
    tv?.cancelHeldCommands();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutinesScreen(
          store: _services.routines,
          shortcuts: _services.appShortcuts.forDevice(
            tv?.pairedDevice.serviceName,
          ),
          controller: tv,
          isCurrentTarget: () =>
              mounted &&
              _castDevice == null &&
              tv != null &&
              identical(tv, _services.androidTvConnection.controller) &&
              tv.connectionState == RemoteConnectionState.connected,
          onChooseDevice: () {
            Navigator.of(context).pop();
            _chooseDevice();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _services.androidTvConnection.controller;
    final active = _castDevice == null ? controller : null;
    final connected =
        active?.connectionState == RemoteConnectionState.connected &&
        _openingDeviceId == null;
    final scope = _services.appShortcuts.forDevice(
      active?.pairedDevice.serviceName,
    );
    final titles = ['Remote', 'Apps', 'Devices'];
    return PopScope(
      canPop: _sectionIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          controller?.cancelHeldCommands();
          setState(() => _sectionIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_sectionIndex]),
          actions: [
            if (_sectionIndex == 0 && (active != null || _castDevice != null))
              IconButton(
                tooltip: 'Switch TV',
                onPressed: _chooseDevice,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            if (_sectionIndex == 2)
              IconButton(
                tooltip: 'Refresh nearby devices',
                onPressed: _scanning ? null : _rescan,
                icon: _scanning
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            IconButton(
              tooltip: 'Settings and help',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _sectionIndex,
            children: [
              SmartRemoteView(
                playback: _castPlayback ?? _noCast,
                active: _sectionIndex == 0 && _openingDeviceId == null,
                remoteBuilder: (context, controlsActive) => _castDevice != null
                    ? CastRemoteScreen(
                        device: _castDevice!,
                        active: controlsActive,
                        embedded: true,
                        onStopped: () => setState(() {
                          _castDevice = null;
                          _restoringCastId = null;
                          _sectionIndex = 2;
                        }),
                      )
                    : active != null
                    ? AndroidTvRemoteScreen(
                        key: ObjectKey(active),
                        controller: active,
                        embedded: true,
                        active: controlsActive,
                        onChooseDevice: _chooseDevice,
                        onManageApps: () => setState(() => _sectionIndex = 1),
                        onRoutines: _openRoutines,
                        onRetry: () => _openSavedDevice(active.pairedDevice),
                        onForget: () => _forgetSavedDevice(active.pairedDevice),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.settings_remote_outlined,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _restoringCastId == null
                                    ? 'Choose your TV'
                                    : 'Looking for your Cast receiver',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose a TV remote for navigation or a Cast receiver for media playback.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _chooseDevice,
                                icon: const Icon(Icons.tv),
                                label: const Text('Find a TV'),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              AppLibraryView(
                store: scope,
                onRoutines: _openRoutines,
                connectedDeviceName: connected ? active?.deviceName : null,
                onLaunchApp: (app) => _launchApp(
                  app,
                  expectedDeviceId: connected
                      ? active?.pairedDevice.serviceName
                      : null,
                  chooseBeforeLaunch: !connected,
                ),
                onChooseDevice: _chooseDevice,
              ),
              _deviceList(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _sectionIndex,
          onDestinationSelected: (index) {
            controller?.cancelHeldCommands();
            setState(() {
              _sectionIndex = index;
              _userSelected = true;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.settings_remote_outlined),
              selectedIcon: Icon(Icons.settings_remote),
              label: 'Remote',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Apps',
            ),
            NavigationDestination(
              icon: Icon(Icons.tv_outlined),
              selectedIcon: Icon(Icons.tv),
              label: 'Devices',
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceList() {
    final savedNames = _pairedDevices
        .map((device) => 'atv:${device.serviceName}')
        .toSet();
    savedNames.addAll(_savedCast.map((receiver) => receiver.id));
    final nearby = _devices
        .where((device) => !savedNames.contains(device.id))
        .toList();
    final rooms =
        _pairedDevices
            .map(
              (device) =>
                  _services.tvPreferences.cached(device.serviceName).room,
            )
            .where((room) => room.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selectedRoom = rooms.contains(_room) ? _room : null;
    final saved = suggestRoomTvs(
      devices: _pairedDevices,
      nearbyServices: _devices
          .where((device) => device.protocol == DeviceProtocol.androidTvRemote)
          .map((device) => device.id.substring(4))
          .toSet(),
      preferences: _services.tvPreferences.cached,
      room: selectedRoom,
      activeService: _castDevice == null
          ? _services.androidTvConnection.controller?.pairedDevice.serviceName
          : null,
    );
    return AdaptiveContent(
      maxWidth: 800,
      child: ListView(
        key: const PageStorageKey('device-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_pendingApp != null)
            ListTile(
              title: Text('Choose a TV for ${_pendingApp!.name}'),
              subtitle: const Text('You will confirm before opening.'),
              trailing: IconButton(
                tooltip: 'Cancel pending launch',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _pendingApp = null),
              ),
            ),
          if (!widget.castAvailable)
            ListTile(
              leading: const Icon(Icons.cast),
              title: Text(
                widget.castInitializing
                    ? 'Starting Cast playback…'
                    : 'Cast playback unavailable',
              ),
              subtitle: const Text(
                'TV remote discovery is available independently.',
              ),
              trailing: widget.castInitializing
                  ? null
                  : TextButton(
                      onPressed: widget.onRetryCast,
                      child: const Text('Retry'),
                    ),
            ),
          if (_error != null) _ErrorBanner(message: _error!, onRetry: _rescan),
          if (rooms.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(selectedRoom),
              initialValue: selectedRoom,
              decoration: const InputDecoration(labelText: 'Room suggestions'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All rooms'),
                ),
                for (final room in rooms)
                  DropdownMenuItem(value: room, child: Text(room)),
              ],
              onChanged: (value) async {
                setState(() {
                  _room = value;
                  _roomTouched = true;
                });
                if (value == null) {
                  await _services.secureStore.delete('selected_room_v1');
                } else {
                  await _services.secureStore.write('selected_room_v1', value);
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nearby saved TVs are suggested first. Assign rooms in Remote options → Controls and room setup.',
              ),
            ),
          ],
          if (saved.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                selectedRoom == null ? 'Your TVs' : 'TVs for $selectedRoom',
              ),
            ),
            for (final device in saved)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SavedDeviceTile(
                  device: device,
                  tablet: false,
                  busy: _openingDeviceId == device.serviceName,
                  enabled: _openingDeviceId == null,
                  active:
                      _services.androidTvConnection.isActive(
                        device.serviceName,
                      ) &&
                      _castDevice == null,
                  connectionState: _connectionState,
                  nearby: _devices.any(
                    (item) => item.id == 'atv:${device.serviceName}',
                  ),
                  onTap: () => _openSavedDevice(device),
                  onRename: () => _renameSavedDevice(device),
                  onForget: () => _forgetSavedDevice(device),
                ),
              ),
          ],
          if (_savedCast.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Remembered Cast receivers'),
            ),
            for (final receiver in _savedCast)
              ListTile(
                leading: const Icon(Icons.cast),
                title: Text(receiver.name),
                subtitle: Text(
                  _devices.any((device) => device.id == receiver.id)
                      ? 'Nearby · Cast playback'
                      : 'Not currently found · Cast playback',
                ),
                onTap: _openingDeviceId != null
                    ? null
                    : () {
                        final matching = _devices.where(
                          (device) => device.id == receiver.id,
                        );
                        if (matching.isNotEmpty) {
                          _openDevice(matching.first);
                        } else {
                          _showMessage(
                            'Receiver not found. Check power and Wi-Fi, then refresh devices.',
                          );
                        }
                      },
                trailing: PopupMenuButton<String>(
                  tooltip: 'Manage ${receiver.name}',
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'forget',
                      child: Text('Forget receiver'),
                    ),
                  ],
                  onSelected: (_) async {
                    await _services.pairedDevices.forgetCastReceiver(
                      receiver.id,
                    );
                    if (!mounted) return;
                    if (_restoringCastId == receiver.id) {
                      setState(() => _restoringCastId = null);
                    }
                    await _loadPairedDevices();
                  },
                ),
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nearby devices'),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Same Wi-Fi required. TV remote controls navigation; Cast playback controls media sessions.',
            ),
          ),
          for (final device in nearby)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DeviceTile(
                device: device,
                tablet: false,
                busy: _openingDeviceId == device.id,
                enabled: _openingDeviceId == null,
                onTap: () => _openDevice(device),
              ),
            ),
          if (nearby.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    _scanning
                        ? 'Starting discovery…'
                        : 'No additional devices found yet',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Devices appear as they are discovered. Check TV power, Wi-Fi, and local network access if yours is missing.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _scanning ? null : _rescan,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh devices'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onTap,
    required this.tablet,
    required this.busy,
    required this.enabled,
  });

  final DiscoveredDevice device;
  final VoidCallback onTap;
  final bool tablet;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAndroidTv = device.protocol == DeviceProtocol.androidTvRemote;
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tablet ? 20 : 16,
        vertical: tablet ? 12 : 6,
      ),
      leading: Container(
        width: tablet ? 50 : 44,
        height: tablet ? 50 : 44,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isAndroidTv ? Icons.tv : Icons.cast,
          color: colors.onPrimaryContainer,
        ),
      ),
      title: Text(
        device.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          device.protocolLabel,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
      trailing: AnimatedSwitcher(
        duration: AppMotion.standard,
        child: busy
            ? const SizedBox.square(
                key: ValueKey('opening'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

class _SavedDeviceTile extends StatelessWidget {
  const _SavedDeviceTile({
    required this.device,
    this.nearby = false,
    required this.onTap,
    required this.tablet,
    required this.busy,
    required this.enabled,
    required this.active,
    required this.connectionState,
    required this.onRename,
    required this.onForget,
  });

  final PairedAndroidTv device;
  final bool nearby;
  final VoidCallback onTap;
  final bool tablet;
  final bool busy;
  final bool enabled;
  final bool active;
  final RemoteConnectionState connectionState;
  final VoidCallback onRename;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = active
        ? switch (connectionState) {
            RemoteConnectionState.connected => 'Connected now',
            RemoteConnectionState.connecting => 'Connecting…',
            RemoteConnectionState.reconnecting => 'Reconnecting…',
            RemoteConnectionState.error => 'Connection failed',
            _ => nearby ? 'Nearby · saved' : 'Not currently found',
          }
        : device.lastConnectedAt == null
        ? nearby
              ? 'Nearby · saved'
              : 'Not currently found'
        : 'Last connected ${_relativeTime(device.lastConnectedAt!)}';
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tablet ? 20 : 16,
        vertical: tablet ? 12 : 6,
      ),
      leading: Container(
        width: tablet ? 50 : 44,
        height: tablet ? 50 : 44,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.tv_rounded, color: colors.onPrimaryContainer),
      ),
      title: Text(
        device.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          status,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
      trailing: AnimatedSwitcher(
        duration: AppMotion.standard,
        child: busy
            ? const SizedBox.square(
                key: ValueKey('opening-saved'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                key: const ValueKey('saved-actions'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    enabled: enabled,
                    tooltip: 'Manage saved TV',
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'forget') onForget();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Rename'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'forget',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Forget'),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: enabled
                        ? colors.onSurfaceVariant
                        : colors.onSurface.withValues(alpha: 0.38),
                  ),
                ],
              ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().toUtc().difference(timestamp.toUtc());
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
