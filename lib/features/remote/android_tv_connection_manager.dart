import 'dart:async';

import '../../core/protocol/android_tv/certificate_manager.dart';
import '../pairing/paired_device_store.dart';
import 'android_tv_remote_controller.dart';
import 'remote_controller.dart';

/// Keeps one Android TV connection alive while the user moves between tabs.
class AndroidTvConnectionManager {
  AndroidTvConnectionManager({required this.certificates, required this.store});

  final CertificateManager certificates;
  final PairedDeviceStore store;

  final _changes = StreamController<RemoteConnectionState>.broadcast();
  StreamSubscription<RemoteConnectionState>? _subscription;
  AndroidTvRemoteController? _controller;

  AndroidTvRemoteController? get controller => _controller;
  RemoteConnectionState get state =>
      _controller?.connectionState ?? RemoteConnectionState.disconnected;
  Stream<RemoteConnectionState> get changes => _changes.stream;

  bool isActive(String serviceName) =>
      _controller?.pairedDevice.serviceName == serviceName;

  Future<AndroidTvRemoteController> connect(PairedAndroidTv device) async {
    final current = _controller;
    final canReuse =
        current != null &&
        current.pairedDevice.serviceName == device.serviceName &&
        current.pairedDevice.lastHost == device.lastHost &&
        current.pairedDevice.serverCertificateSha256 ==
            device.serverCertificateSha256;

    if (!canReuse) {
      await _replaceController(device);
    } else {
      current.updatePairedDevice(device);
    }

    final target = _controller!;
    await store.saveLastDevice(
      id: device.serviceName,
      protocol: 'androidTvRemote',
    );
    await target.connect();
    if (target.connectionState == RemoteConnectionState.connected) {
      final updated = device.copyWith(lastConnectedAt: DateTime.now().toUtc());
      target.updatePairedDevice(updated);
      await store.save(updated);
    }
    return target;
  }

  Future<void> rename(PairedAndroidTv device, String displayName) async {
    final source = isActive(device.serviceName)
        ? _controller!.pairedDevice
        : device;
    final updated = source.copyWith(displayName: displayName.trim());
    await store.save(updated);
    if (isActive(device.serviceName)) _controller?.updatePairedDevice(updated);
  }

  Future<void> forget(PairedAndroidTv device) async {
    final wasActive = isActive(device.serviceName);
    if (wasActive) await _clearController();
    await store.remove(device.serviceName);
    if (wasActive) _changes.add(RemoteConnectionState.disconnected);
  }

  Future<void> _replaceController(PairedAndroidTv device) async {
    await _clearController();
    final controller = AndroidTvRemoteController(
      pairedDevice: device,
      certificates: certificates,
      store: store,
    );
    _controller = controller;
    _subscription = controller.connectionStates.listen(_changes.add);
  }

  Future<void> _clearController() async {
    await _subscription?.cancel();
    _subscription = null;
    final current = _controller;
    _controller = null;
    await current?.disconnect();
    await current?.dispose();
  }
}
