import 'dart:convert';

import '../../core/storage/secure_store.dart';

/// A Google TV / Android TV that completed pairing.
class PairedAndroidTv {
  const PairedAndroidTv({
    required this.serviceName,
    required this.displayName,
    required this.lastHost,
    required this.serverCertificateSha256,
    required this.pairedAt,
    this.lastConnectedAt,
  });

  /// mDNS service instance name; used as the identity key.
  final String serviceName;
  final String displayName;

  /// Last known IP, used to attempt reconnection before discovery finds the
  /// device again.
  final String lastHost;

  /// SHA-256 fingerprint (hex) of the server certificate seen during pairing.
  /// Verified on every reconnect so a different device at the same address is
  /// never treated as the paired TV.
  final String serverCertificateSha256;

  final DateTime pairedAt;
  final DateTime? lastConnectedAt;

  PairedAndroidTv copyWith({
    String? displayName,
    String? lastHost,
    DateTime? lastConnectedAt,
  }) => PairedAndroidTv(
    serviceName: serviceName,
    displayName: displayName ?? this.displayName,
    lastHost: lastHost ?? this.lastHost,
    serverCertificateSha256: serverCertificateSha256,
    pairedAt: pairedAt,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
  );

  PairedAndroidTv copyWithHost(String host) => copyWith(lastHost: host);

  factory PairedAndroidTv.fromJson(Map<String, dynamic> json) =>
      PairedAndroidTv(
        serviceName: json['serviceName'] as String,
        displayName: json['displayName'] as String,
        lastHost: json['lastHost'] as String,
        serverCertificateSha256: json['serverCertificateSha256'] as String,
        pairedAt:
            DateTime.tryParse(json['pairedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lastConnectedAt: DateTime.tryParse(
          json['lastConnectedAt'] as String? ?? '',
        ),
      );

  Map<String, dynamic> toJson() => {
    'serviceName': serviceName,
    'displayName': displayName,
    'lastHost': lastHost,
    'serverCertificateSha256': serverCertificateSha256,
    'pairedAt': pairedAt.toIso8601String(),
    if (lastConnectedAt != null)
      'lastConnectedAt': lastConnectedAt!.toIso8601String(),
  };
}

/// Persists paired Android TV devices and the last-used device in secure
/// storage so trust survives app restarts.
class PairedDeviceStore {
  PairedDeviceStore({required this.store});

  static const _pairedTvsKey = 'paired_android_tvs_v1';
  static const _lastDeviceKey = 'last_device_v1';

  final SecureStore store;

  Future<List<PairedAndroidTv>> loadPairedDevices() async {
    final raw = await store.read(_pairedTvsKey);
    if (raw == null || raw.isEmpty) return <PairedAndroidTv>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(PairedAndroidTv.fromJson)
          .toList();
    } on FormatException {
      return <PairedAndroidTv>[];
    }
  }

  Future<PairedAndroidTv?> findByServiceName(String serviceName) async {
    final devices = await loadPairedDevices();
    for (final device in devices) {
      if (device.serviceName == serviceName) return device;
    }
    return null;
  }

  Future<void> save(PairedAndroidTv device) async {
    final devices = await loadPairedDevices();
    devices.removeWhere((d) => d.serviceName == device.serviceName);
    devices.add(device);
    await store.write(
      _pairedTvsKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
  }

  Future<void> remove(String serviceName) async {
    final devices = await loadPairedDevices();
    devices.removeWhere((d) => d.serviceName == serviceName);
    await store.write(
      _pairedTvsKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
    final last = await loadLastDevice();
    if (last?.id == serviceName) await store.delete(_lastDeviceKey);
  }

  /// Remembers which device to auto-reconnect to on the next launch.
  Future<void> saveLastDevice({required String id, required String protocol}) =>
      store.write(_lastDeviceKey, jsonEncode({'id': id, 'protocol': protocol}));

  Future<({String id, String protocol})?> loadLastDevice() async {
    final raw = await store.read(_lastDeviceKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = map['id'];
      final protocol = map['protocol'];
      if (id is String && protocol is String) {
        return (id: id, protocol: protocol);
      }
    } on FormatException {
      // Corrupted entry — treated as absent.
    }
    return null;
  }
}
