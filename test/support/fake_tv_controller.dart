import 'dart:async';

import 'package:chromecast_remote/core/protocol/android_tv/certificate_manager.dart';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/pairing/paired_device_store.dart';
import 'package:chromecast_remote/features/remote/android_tv_remote_controller.dart';
import 'package:chromecast_remote/features/remote/remote_controller.dart';

PairedAndroidTv testTv({
  String id = 'living-room',
  String host = '192.0.2.1',
  String pin = 'trusted',
}) => PairedAndroidTv(
  serviceName: id,
  displayName: 'Living room television',
  lastHost: host,
  serverCertificateSha256: pin,
  pairedAt: DateTime.utc(2026),
);

class FakeTvController extends AndroidTvRemoteController {
  FakeTvController(PairedAndroidTv device, {PairedDeviceStore? pairedStore})
    : super(
        pairedDevice: device,
        certificates: CertificateManager(store: InMemorySecureStore()),
        store: pairedStore ?? PairedDeviceStore(store: InMemorySecureStore()),
      );

  final states = StreamController<RemoteConnectionState>.broadcast(sync: true);
  final apps = StreamController<String>.broadcast(sync: true);
  final commands = <RemoteCommand>[];
  final links = <String>[];
  RemoteConnectionState state = RemoteConnectionState.connected;
  String? foreground;
  int connectCalls = 0;
  bool disposed = false;
  Completer<void>? connectGate;

  @override
  RemoteConnectionState get connectionState => state;
  @override
  Stream<RemoteConnectionState> get connectionStates => states.stream;
  @override
  Set<RemoteCapability> get capabilities =>
      state == RemoteConnectionState.connected
      ? RemoteCapability.values.toSet()
      : {};
  @override
  String? get currentApp => foreground;
  @override
  Stream<String> get currentAppUpdates => apps.stream;
  @override
  bool supports(RemoteCommand command) =>
      state == RemoteConnectionState.connected;
  @override
  Future<void> connect() async {
    connectCalls++;
    if (connectGate != null) await connectGate!.future;
    state = RemoteConnectionState.connected;
    states.add(state);
  }

  @override
  Future<void> disconnect() async {
    state = RemoteConnectionState.disconnected;
    states.add(state);
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async =>
      commands.add(command);
  @override
  void launchAppLink(String link) => links.add(link);
  @override
  Future<void> dispose() async {
    disposed = true;
    await states.close();
    await apps.close();
    await super.dispose();
  }
}
