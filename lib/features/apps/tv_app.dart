/// A launchable TV app shown as a shortcut on the remote.
///
/// Apps are launched over Android TV Remote Protocol v2 using their own deep
/// links. Package-based `market://launch` links can open the Play Store even
/// when the app is installed, so they are only a fallback for unknown apps.
/// Deep-link reference:
/// https://community.home-assistant.io/t/android-tv-remote-app-links-deep-linking-guide/567921
///
/// Android TV Remote Protocol v2 offers no API to enumerate installed apps,
/// so shortcuts come from a verified catalog plus user-defined custom entries.
class TvApp {
  const TvApp({
    required this.id,
    required this.name,
    required this.launchUrl,
    this.packageName,
    this.category = TvAppCategory.other,
    this.custom = false,
  });

  /// Stable identity (catalog key or `custom:<name>`).
  final String id;
  final String name;

  /// The app link sent to the TV.
  final String launchUrl;

  /// Android package name, used to highlight the currently active app.
  final String? packageName;

  final TvAppCategory category;

  /// True for user-added entries.
  final bool custom;

  factory TvApp.customEntry({required String name, required String target}) {
    final trimmed = target.trim();
    // Prefer the catalog's direct link for known packages. Explicit deep
    // links are sent as-is, including links to specific content.
    final looksLikePackage = !trimmed.contains('://') && trimmed.contains('.');
    final launchUrl = looksLikePackage ? packageLaunchUrl(trimmed) : trimmed;
    return TvApp(
      id: 'custom:${name.trim().toLowerCase()}',
      name: name.trim(),
      launchUrl: launchUrl,
      packageName: looksLikePackage ? trimmed : null,
      custom: true,
    );
  }

  factory TvApp.fromJson(Map<String, dynamic> json) {
    final packageName = json['packageName'] as String?;
    final launchUrl = json['launchUrl'] as String;
    // Upgrade package shortcuts saved before direct links were introduced,
    // while preserving any explicitly configured content links.
    final wasPackageShortcut =
        packageName != null && launchUrl == 'market://launch?id=$packageName';
    return TvApp(
      id: json['id'] as String,
      name: json['name'] as String,
      launchUrl: wasPackageShortcut ? packageLaunchUrl(packageName) : launchUrl,
      packageName: packageName,
      custom: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'launchUrl': launchUrl,
    if (packageName != null) 'packageName': packageName,
  };
}

enum TvAppCategory { movies, music, gaming, kids, other }

/// Resolves known packages to direct links, avoiding the Play Store.
///
/// Apps without a known deep link retain the package-based fallback, which
/// may open their store page and require selecting Open on some TVs.
String packageLaunchUrl(String packageName) =>
    matchByPackage(catalogApps, packageName)?.launchUrl ??
    'market://launch?id=$packageName';

/// Curated catalog. Package names verified against the Google Play Store.
const catalogApps = <TvApp>[
  TvApp(
    id: 'netflix',
    name: 'Netflix',
    packageName: 'com.netflix.ninja',
    launchUrl: 'netflix://',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'youtube',
    name: 'YouTube',
    packageName: 'com.google.android.youtube.tv',
    launchUrl: 'vnd.youtube.launch://',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'prime-video',
    name: 'Prime Video',
    packageName: 'com.amazon.amazonvideo.livingroom',
    launchUrl: 'https://app.primevideo.com',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'disney-plus',
    name: 'Disney+',
    packageName: 'com.disney.disneyplus',
    launchUrl: 'https://www.disneyplus.com',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'videoland',
    name: 'Videoland',
    packageName: 'nl.rtl.videoland.v2',
    launchUrl: 'videoland-v2://',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'npo-start',
    name: 'NPO Start',
    packageName: 'nl.uitzendinggemist',
    // The TV app has no verified deep link; retain the package fallback.
    launchUrl: 'market://launch?id=nl.uitzendinggemist',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'nlziet',
    name: 'NLZIET',
    packageName: 'nl.nlziet',
    launchUrl: 'nlziet://',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'ziggo-go',
    name: 'Ziggo GO',
    packageName: 'com.ziggo.tv',
    launchUrl: 'ziggogo://',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'spotify',
    name: 'Spotify',
    packageName: 'com.spotify.tv.android',
    launchUrl: 'spotify://',
    category: TvAppCategory.music,
  ),
  TvApp(
    id: 'plex',
    name: 'Plex',
    packageName: 'com.plexapp.android',
    launchUrl: 'plex://',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'twitch',
    name: 'Twitch',
    packageName: 'tv.twitch.android.app',
    launchUrl: 'twitch://home',
    category: TvAppCategory.gaming,
  ),
];

/// Matches a foreground package reported by the TV to a shortcut, so the
/// active app can be highlighted.
TvApp? matchByPackage(Iterable<TvApp> apps, String? packageName) {
  if (packageName == null || packageName.isEmpty) return null;
  for (final app in apps) {
    if (app.packageName == packageName) return app;
  }
  return null;
}
