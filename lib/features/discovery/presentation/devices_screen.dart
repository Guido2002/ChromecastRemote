import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../../core/app_services.dart';
import '../../../shared/presentation/adaptive_layout.dart';
import '../../../shared/presentation/app_motion.dart';
import '../../../shared/models/discovered_device.dart';
import '../../apps/presentation/app_library_view.dart';
import '../../pairing/paired_device_store.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../../remote/android_tv_remote_controller.dart';
import '../../remote/presentation/android_tv_remote_screen.dart';
import '../../remote/presentation/cast_remote_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../update/presentation/update_actions.dart';

/// Home screen: live list of Google TV / Android TV and Chromecast devices
/// found on the local Wi-Fi network.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _services = AppServices.instance;
  StreamSubscription<List<DiscoveredDevice>>? _subscription;
  List<DiscoveredDevice> _devices = const [];
  List<PairedAndroidTv> _pairedDevices = const [];
  bool _scanning = false;
  bool _showSaved = false;
  bool _autoReconnectAttempted = false;
  String? _openingDeviceId;
  String? _error;
  int _sectionIndex = 0;

  @override
  void initState() {
    super.initState();
    _subscription = _services.discovery.devices.listen((devices) {
      if (mounted) setState(() => _devices = devices);
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

  /// Reconnects to the last used Google TV once per app launch. Failures are
  /// silent here; the user can still pick the device manually from the list.
  Future<void> _reconnectToLastDevice() async {
    if (_autoReconnectAttempted) return;
    _autoReconnectAttempted = true;
    try {
      final last = await _services.pairedDevices.loadLastDevice();
      if (last == null || last.protocol != 'androidTvRemote') return;
      final paired = await _services.pairedDevices.findByServiceName(last.id);
      if (paired == null || !mounted) return;
      await _openPairedAndroidTv(paired);
    } catch (_) {
      // Auto-reconnect is best-effort; discovery remains available.
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      await _services.discovery.start();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Discovery failed: $error. Check that you are on Wi-Fi and that '
              'local network access is allowed.',
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _rescan() async {
    await _services.discovery.stop();
    await _startScan();
  }

  Future<void> _loadPairedDevices() async {
    final devices = await _services.pairedDevices.loadPairedDevices();
    devices.sort((a, b) => b.pairedAt.compareTo(a.pairedAt));
    if (mounted) setState(() => _pairedDevices = devices);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_services.discovery.stop());
    super.dispose();
  }

  Future<void> _openDevice(DiscoveredDevice device) async {
    if (_openingDeviceId != null) return;
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
    final controller = AndroidTvRemoteController(
      pairedDevice: pairedDevice,
      certificates: _services.certificates,
      store: _services.pairedDevices,
    );
    await _services.pairedDevices.saveLastDevice(
      id: pairedDevice.serviceName,
      protocol: 'androidTvRemote',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AndroidTvRemoteScreen(controller: controller),
      ),
    );
    await controller.dispose();
    await _loadPairedDevices();
  }

  Future<void> _openSavedDevice(PairedAndroidTv device) async {
    if (_openingDeviceId != null) return;
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
      await _services.pairedDevices.saveLastDevice(
        id: device.id,
        protocol: 'googleCast',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CastRemoteScreen(device: castDevice)),
      );
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

  Widget _buildSavedDevices(bool tablet) {
    if (_pairedDevices.isEmpty) {
      return _EmptySavedDevices(
        onNearby: () => setState(() => _showSaved = false),
      );
    }
    if (tablet) {
      return GridView.builder(
        key: const ValueKey('saved-devices-tablet-grid'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 92,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _pairedDevices.length,
        itemBuilder: (context, index) {
          final device = _pairedDevices[index];
          return _SavedDeviceTile(
            device: device,
            tablet: true,
            busy: _openingDeviceId == device.serviceName,
            enabled: _openingDeviceId == null,
            onTap: () => _openSavedDevice(device),
          );
        },
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _pairedDevices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = _pairedDevices[index];
        return _SavedDeviceTile(
          device: device,
          tablet: false,
          busy: _openingDeviceId == device.serviceName,
          enabled: _openingDeviceId == null,
          onTap: () => _openSavedDevice(device),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tablet = AdaptiveLayout.isTablet(context);
    const titles = ['Devices', 'Remote', 'Apps', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_sectionIndex]),
        actions: [
          if (_sectionIndex == 0)
            IconButton(
              tooltip: 'Scan again',
              onPressed: _scanning ? null : _rescan,
              icon: _scanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.standard,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(_sectionIndex),
          child: switch (_sectionIndex) {
            1 => _RemoteLanding(
              devices: _pairedDevices,
              openingDeviceId: _openingDeviceId,
              onOpen: _openSavedDevice,
              onChooseDevice: () => setState(() => _sectionIndex = 0),
            ),
            2 => AppLibraryView(
              store: _services.appShortcuts,
              onChooseDevice: () => setState(() => _sectionIndex = 0),
            ),
            3 => const SettingsView(),
            _ => AdaptiveContent(
              maxWidth: 1040,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tablet ? 24 : 16,
                      8,
                      tablet ? 24 : 16,
                      4,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: SegmentedButton<bool>(
                        expandedInsets: EdgeInsets.zero,
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.radar_rounded),
                            label: Text('Nearby'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.bookmark_outline_rounded),
                            label: Text('Saved'),
                          ),
                        ],
                        selected: {_showSaved},
                        onSelectionChanged: (selection) {
                          setState(() => _showSaved = selection.first);
                          if (selection.first) unawaited(_loadPairedDevices());
                        },
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: AppMotion.standard,
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            key: const ValueKey('discovery-error'),
                            padding: EdgeInsets.fromLTRB(
                              tablet ? 24 : 16,
                              tablet ? 12 : 0,
                              tablet ? 24 : 16,
                              8,
                            ),
                            child: _ErrorBanner(
                              message: _error!,
                              onRetry: _rescan,
                            ),
                          ),
                  ),
                  Expanded(
                    child: _showSaved
                        ? _buildSavedDevices(tablet)
                        : _devices.isEmpty
                        ? _EmptyDevices(
                            scanning: _scanning,
                            error: _error,
                            onScan: _rescan,
                          )
                        : tablet
                        ? GridView.builder(
                            key: const ValueKey('devices-tablet-grid'),
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 92,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              return MotionEntrance(
                                delay: Duration(
                                  milliseconds: (index.clamp(0, 5)) * 45,
                                ),
                                child: _DeviceTile(
                                  device: device,
                                  tablet: true,
                                  busy: _openingDeviceId == device.id,
                                  enabled: _openingDeviceId == null,
                                  onTap: () => _openDevice(device),
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _devices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              return MotionEntrance(
                                delay: Duration(
                                  milliseconds: (index.clamp(0, 5)) * 45,
                                ),
                                child: _DeviceTile(
                                  device: device,
                                  tablet: false,
                                  busy: _openingDeviceId == device.id,
                                  enabled: _openingDeviceId == null,
                                  onTap: () => _openDevice(device),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tablet ? 24 : 16,
                      0,
                      tablet ? 24 : 16,
                      tablet ? 24 : 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Phone or tablet and TV must be on the same Wi-Fi network.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sectionIndex,
        onDestinationSelected: (index) => setState(() => _sectionIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.tv_outlined),
            selectedIcon: Icon(Icons.tv_rounded),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_remote_outlined),
            selectedIcon: Icon(Icons.settings_remote_rounded),
            label: 'Remote',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _RemoteLanding extends StatelessWidget {
  const _RemoteLanding({
    required this.devices,
    required this.openingDeviceId,
    required this.onOpen,
    required this.onChooseDevice,
  });

  final List<PairedAndroidTv> devices;
  final String? openingDeviceId;
  final ValueChanged<PairedAndroidTv> onOpen;
  final VoidCallback onChooseDevice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AdaptiveContent(
      maxWidth: 720,
      child: Padding(
        padding: AdaptiveLayout.pagePadding(context),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.settings_remote_rounded,
                size: 36,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              devices.isEmpty ? 'No remote connected' : 'Choose a saved TV',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              devices.isEmpty
                  ? 'Find and pair a TV before opening the remote.'
                  : 'Your saved TVs reconnect securely without pairing again.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (devices.isEmpty)
              FilledButton.icon(
                onPressed: onChooseDevice,
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Find a TV'),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: devices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _SavedDeviceTile(
                      device: device,
                      tablet: false,
                      busy: openingDeviceId == device.serviceName,
                      enabled: openingDeviceId == null,
                      onTap: () => onOpen(device),
                    );
                  },
                ),
              ),
          ],
        ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
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
              : FilledButton(
                  key: const ValueKey('open'),
                  onPressed: enabled ? onTap : null,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(tablet ? 88 : 76, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Connect'),
                ),
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _SavedDeviceTile extends StatelessWidget {
  const _SavedDeviceTile({
    required this.device,
    required this.onTap,
    required this.tablet,
    required this.busy,
    required this.enabled,
  });

  final PairedAndroidTv device;
  final VoidCallback onTap;
  final bool tablet;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
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
            'Google TV · ${device.lastHost}',
            maxLines: 1,
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
              : FilledButton(
                  key: const ValueKey('open-saved'),
                  onPressed: enabled ? onTap : null,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(tablet ? 88 : 76, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Open'),
                ),
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _EmptySavedDevices extends StatelessWidget {
  const _EmptySavedDevices({required this.onNearby});

  final VoidCallback onNearby;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 48,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved TVs yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pair a nearby Google TV once and it will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNearby,
              icon: const Icon(Icons.radar_rounded),
              label: const Text('Find nearby TVs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({
    required this.scanning,
    required this.error,
    required this.onScan,
  });

  final bool scanning;
  final String? error;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              scanning ? Icons.wifi_find : Icons.devices_other,
              size: 48,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              scanning
                  ? 'Looking for TVs and Chromecasts…'
                  : error != null
                  ? 'Could not scan the network'
                  : 'No devices found yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Google TV devices appear when their remote service is enabled, '
              'Chromecasts appear automatically.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: scanning ? null : onScan,
              icon: scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar_rounded),
              label: Text(scanning ? 'Scanning…' : 'Scan again'),
            ),
          ],
        ),
      ),
    );
  }
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
