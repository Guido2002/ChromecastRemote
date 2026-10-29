import 'dart:async';
import '../features/household/tv_preferences.dart';
import '../features/automation/routines.dart';

import '../features/apps/app_shortcut_store.dart';
import '../shared/models/discovered_device.dart';
import '../features/discovery/discovery_service.dart';
import '../features/pairing/paired_device_store.dart';
import '../features/remote/android_tv_connection_manager.dart';
import 'protocol/android_tv/certificate_manager.dart';
import 'storage/secure_store.dart';

/// Application-wide singletons. Deliberately small: the app is a single-user
/// remote, so a service locator is sufficient and keeps widget code lean.
class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final SecureStore secureStore = const FlutterSecureStore();

  late final CertificateManager certificates = CertificateManager(
    store: secureStore,
  );

  late final PairedDeviceStore pairedDevices = PairedDeviceStore(
    store: secureStore,
  );

  late final DiscoveryService discovery = DiscoveryService();

  late final AndroidTvConnectionManager androidTvConnection =
      AndroidTvConnectionManager(
        certificates: certificates,
        store: pairedDevices,
        resolveHost: (serviceName) async {
          String? find(Iterable<DiscoveredDevice> devices) {
            for (final device in devices) {
              if (device.id == 'atv:$serviceName') {
                return device.host;
              }
            }
            return null;
          }

          final cached = find(discovery.currentDevices);
          if (cached != null) return cached;
          try {
            final devices = await discovery.devices
                .firstWhere((devices) => find(devices) != null)
                .timeout(const Duration(seconds: 2));
            return find(devices);
          } on TimeoutException {
            return null;
          }
        },
      );

  late final RoutineStore routines = RoutineStore(secureStore);

  late final TvPreferenceStore tvPreferences = TvPreferenceStore(secureStore);

  late final AppShortcutStore appShortcuts = AppShortcutStore(
    store: secureStore,
  );
}
