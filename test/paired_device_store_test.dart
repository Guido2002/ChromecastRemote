import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/pairing/paired_device_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore secureStore;
  late PairedDeviceStore store;

  final device = PairedAndroidTv(
    serviceName: 'SHIELD',
    displayName: 'SHIELD',
    lastHost: '192.168.1.20',
    serverCertificateSha256: 'ab' * 32,
    pairedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    secureStore = InMemorySecureStore();
    store = PairedDeviceStore(store: secureStore);
  });

  test('returns no devices when storage is empty', () async {
    expect(await store.loadPairedDevices(), isEmpty);
    expect(await store.findByServiceName('SHIELD'), isNull);
  });

  test('saves and reloads a paired device', () async {
    await store.save(device);

    final devices = await store.loadPairedDevices();
    expect(devices, hasLength(1));
    final loaded = devices.single;
    expect(loaded.serviceName, device.serviceName);
    expect(loaded.displayName, device.displayName);
    expect(loaded.lastHost, device.lastHost);
    expect(loaded.serverCertificateSha256, device.serverCertificateSha256);
    expect(loaded.pairedAt, device.pairedAt);
  });

  test('saving the same service name replaces the entry', () async {
    await store.save(device);
    await store.save(device.copyWithHost('192.168.1.99'));

    final devices = await store.loadPairedDevices();
    expect(devices, hasLength(1));
    expect(devices.single.lastHost, '192.168.1.99');
  });

  test('persists renamed devices and their last connection time', () async {
    final connectedAt = DateTime.utc(2026, 10, 27, 12, 30);
    await store.save(
      device.copyWith(
        displayName: 'Living Room TV',
        lastConnectedAt: connectedAt,
      ),
    );

    final loaded = (await store.loadPairedDevices()).single;
    expect(loaded.displayName, 'Living Room TV');
    expect(loaded.lastConnectedAt, connectedAt);
  });

  test('remove deletes only the matching device', () async {
    await store.save(device);
    await store.save(
      PairedAndroidTv(
        serviceName: 'Chromecast-Ultra',
        displayName: 'Chromecast Ultra',
        lastHost: '192.168.1.30',
        serverCertificateSha256: 'cd' * 32,
        pairedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    await store.remove('SHIELD');

    final devices = await store.loadPairedDevices();
    expect(devices, hasLength(1));
    expect(devices.single.serviceName, 'Chromecast-Ultra');
  });

  test('corrupted storage is treated as empty instead of crashing', () async {
    await secureStore.write('paired_android_tvs_v1', '{not json');
    expect(await store.loadPairedDevices(), isEmpty);
  });

  test('remembers and reloads the last used device', () async {
    expect(await store.loadLastDevice(), isNull);

    await store.saveLastDevice(id: 'SHIELD', protocol: 'androidTvRemote');

    final last = await store.loadLastDevice();
    expect(last?.id, 'SHIELD');
    expect(last?.protocol, 'androidTvRemote');
  });

  test('forgetting the last used device clears auto reconnect', () async {
    await store.save(device);
    await store.saveLastDevice(id: 'SHIELD', protocol: 'androidTvRemote');

    await store.remove('SHIELD');

    expect(await store.loadLastDevice(), isNull);
  });
}
