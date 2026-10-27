import '../features/discovery/discovery_service.dart';
import '../features/pairing/paired_device_store.dart';
import 'protocol/android_tv/certificate_manager.dart';
import 'storage/secure_store.dart';

/// Application-wide singletons. Deliberately small: the app is a single-user
/// remote, so a service locator is sufficient and keeps widget code lean.
class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final SecureStore secureStore = const FlutterSecureStore();

  late final CertificateManager certificates =
      CertificateManager(store: secureStore);

  late final PairedDeviceStore pairedDevices =
      PairedDeviceStore(store: secureStore);

  late final DiscoveryService discovery = DiscoveryService();
}
