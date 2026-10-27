import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

/// Which local protocol a discovered device can be controlled with.
enum DeviceProtocol {
  /// Android TV Remote Protocol v2 (Google TV / Android TV) — full remote.
  androidTvRemote,

  /// Google Cast — media session control only, no system navigation.
  googleCast,
}

/// A device found on the local network, unified across discovery mechanisms.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.protocol,
    this.host,
    this.port,
    this.castDevice,
  });

  /// Stable identity within a discovery session.
  ///
  /// Android TV services use their mDNS instance name, Cast devices their
  /// unique device ID. The two protocols share no reliable common identifier,
  /// so a Google TV advertising both services appears as two explicitly
  /// labelled entries rather than being merged on a name guess.
  final String id;

  final String name;
  final DeviceProtocol protocol;

  /// Resolved IP address (Android TV Remote only).
  final String? host;

  /// Service port (Android TV Remote only).
  final int? port;

  /// Underlying Cast SDK handle (Google Cast only).
  final GoogleCastDevice? castDevice;

  String get protocolLabel => switch (protocol) {
        DeviceProtocol.androidTvRemote => 'Google TV / Android TV remote',
        DeviceProtocol.googleCast => 'Google Cast (media control)',
      };

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
