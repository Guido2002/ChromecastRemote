import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../../core/app_services.dart';
import '../../../shared/models/discovered_device.dart';
import '../../pairing/paired_device_store.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../../remote/android_tv_remote_controller.dart';
import '../../remote/presentation/android_tv_remote_screen.dart';
import '../../remote/presentation/cast_remote_screen.dart';
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
  bool _scanning = false;
  bool _autoReconnectAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _services.discovery.devices.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    unawaited(_startScan());
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
      final paired =
          await _services.pairedDevices.findByServiceName(last.id);
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
        setState(() => _error =
            'Discovery failed: $error. Check that you are on Wi-Fi and that '
            'local network access is allowed.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _rescan() async {
    await _services.discovery.stop();
    await _startScan();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_services.discovery.stop());
    super.dispose();
  }

  Future<void> _openDevice(DiscoveredDevice device) async {
    switch (device.protocol) {
      case DeviceProtocol.androidTvRemote:
        await _openAndroidTv(device);
      case DeviceProtocol.googleCast:
        await _openCastDevice(device);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            tooltip: 'Check for updates',
            onPressed: () => checkForAppUpdate(context, userInitiated: true),
            icon: const Icon(Icons.system_update_alt),
          ),
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
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _ErrorBanner(message: _error!, onRetry: _rescan),
            ),
          Expanded(
            child: _devices.isEmpty
                ? _EmptyDevices(scanning: _scanning, error: _error)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return _DeviceTile(
                        device: device,
                        onTap: () => _openDevice(device),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Phone and TV must be on the same Wi-Fi network.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});

  final DiscoveredDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAndroidTv = device.protocol == DeviceProtocol.androidTvRemote;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: colors.primary.withValues(alpha: 0.14),
          child: Icon(
            isAndroidTv ? Icons.tv : Icons.cast,
            color: colors.primary,
          ),
        ),
        title: Text(
          device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(device.protocolLabel),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.scanning, required this.error});

  final bool scanning;
  final String? error;

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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
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
