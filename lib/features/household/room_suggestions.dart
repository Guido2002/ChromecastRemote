import '../pairing/paired_device_store.dart';
import 'tv_preferences.dart';

/// Suggestions use an explicit room and discovery; never infer physical location.
List<PairedAndroidTv> suggestRoomTvs({
  required List<PairedAndroidTv> devices,
  required Set<String> nearbyServices,
  required TvPreferences Function(String) preferences,
  String? room,
  String? activeService,
}) {
  final result = devices
      .where(
        (device) =>
            room == null || preferences(device.serviceName).room == room,
      )
      .toList();
  result.sort((a, b) {
    if (a.serviceName == activeService) return -1;
    if (b.serviceName == activeService) return 1;
    final nearby =
        (nearbyServices.contains(b.serviceName) ? 1 : 0) -
        (nearbyServices.contains(a.serviceName) ? 1 : 0);
    if (nearby != 0) return nearby;
    final recent = (b.lastConnectedAt ?? b.pairedAt).compareTo(
      a.lastConnectedAt ?? a.pairedAt,
    );
    return recent != 0 ? recent : a.displayName.compareTo(b.displayName);
  });
  return result;
}
