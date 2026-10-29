import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../shared/models/discovered_device.dart';

/// Real local-network discovery for both control protocols:
///
///  * `_androidtvremote2._tcp` via mDNS (Bonsoir) — Google TV / Android TV
///    devices that support Android TV Remote Protocol v2.
///  * `_googlecast._tcp` via the Google Cast SDK (flutter_chrome_cast).
///
/// Devices are emitted as they appear and removed when the network reports
/// them lost.
class DiscoveryService {
  static const _androidTvServiceType = '_androidtvremote2._tcp';

  BonsoirDiscovery? _bonsoirDiscovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _bonsoirSubscription;
  StreamSubscription<List<GoogleCastDevice>>? _castSubscription;

  final Map<String, DiscoveredDevice> _devices = {};
  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  bool _castDiscoveryStarted = false;
  bool _running = false;
  Future<void> _operations = Future.value();

  Future<void> _serialized(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  /// The currently known devices, re-emitted on every change.
  Stream<List<DiscoveredDevice>> get devices => _devicesController.stream;

  bool get isRunning => _running;

  List<DiscoveredDevice> get currentDevices =>
      List.unmodifiable(_devices.values);
  List<String> errors = const [];

  Future<void> start({bool castAvailable = true}) =>
      _serialized(() => _start(castAvailable));

  Future<void> _start(bool castAvailable) async {
    errors = [];
    if (!_running) {
      _running = true;
      _devices.clear();
      _emit();
    }
    await Future.wait([
      if (_bonsoirDiscovery == null)
        _startAndroidTvDiscovery().catchError((Object error) {
          errors = [
            ...errors,
            'TV discovery could not start. Check local network access and try again.',
          ];
        }),
      if (castAvailable && !_castDiscoveryStarted)
        _startCastDiscovery().catchError((Object error) {
          errors = [
            ...errors,
            'Cast discovery could not start. TV remote discovery remains available.',
          ];
        }),
    ]);
    if (errors.isNotEmpty &&
        _bonsoirDiscovery == null &&
        !_castDiscoveryStarted) {
      _running = false;
    }
  }

  Future<void> stop() => _serialized(_stop);

  Future<void> _stop() async {
    _running = false;
    await _bonsoirSubscription?.cancel();
    _bonsoirSubscription = null;
    try {
      await _bonsoirDiscovery?.stop();
    } catch (_) {
      /* Continue stopping the other discovery backend. */
    }
    _bonsoirDiscovery = null;

    await _castSubscription?.cancel();
    _castSubscription = null;
    if (_castDiscoveryStarted) {
      _castDiscoveryStarted = false;
      try {
        await GoogleCastDiscoveryManager.instance.stopDiscovery();
      } catch (_) {
        // Stopping Cast discovery is best-effort; a failure here must not
        // surface as an app error.
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    await _devicesController.close();
  }

  Future<void> _startAndroidTvDiscovery() async {
    final discovery = BonsoirDiscovery(
      type: _androidTvServiceType,
      printLogs: false,
    );
    _bonsoirDiscovery = discovery;
    try {
      await discovery.initialize();
      _bonsoirSubscription = discovery.eventStream?.listen(_onBonsoirEvent);
      await discovery.start();
    } catch (_) {
      await _bonsoirSubscription?.cancel();
      _bonsoirSubscription = null;
      _bonsoirDiscovery = null;
      rethrow;
    }
  }

  void _onBonsoirEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        _bonsoirDiscovery?.serviceResolver.resolveService(service);
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
      case BonsoirDiscoveryServiceUpdatedEvent(:final service):
        final host = service.hostAddress;
        if (host == null) return;
        _devices['atv:${service.name}'] = DiscoveredDevice(
          id: 'atv:${service.name}',
          name: service.name,
          protocol: DeviceProtocol.androidTvRemote,
          host: host,
          port: service.port,
        );
        _emit();
      case BonsoirDiscoveryServiceLostEvent(:final service):
        if (_devices.remove('atv:${service.name}') != null) _emit();
      default:
        break;
    }
  }

  Future<void> _startCastDiscovery() async {
    _castSubscription = GoogleCastDiscoveryManager.instance.devicesStream
        .listen(_onCastDevices);
    try {
      await GoogleCastDiscoveryManager.instance.startDiscovery(
        activeScan: true,
      );
    } catch (_) {
      await _castSubscription?.cancel();
      _castSubscription = null;
      rethrow;
    }
    _castDiscoveryStarted = true;
  }

  void _onCastDevices(List<GoogleCastDevice> castDevices) {
    _devices.removeWhere((id, _) => id.startsWith('cast:'));
    for (final device in castDevices) {
      _devices['cast:${device.deviceID}'] = DiscoveredDevice(
        id: 'cast:${device.deviceID}',
        name: device.friendlyName,
        protocol: DeviceProtocol.googleCast,
        castDevice: device,
      );
    }
    _emit();
  }

  void _emit() {
    if (_devicesController.isClosed) return;
    final sorted = _devices.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _devicesController.add(List.unmodifiable(sorted));
  }
}
