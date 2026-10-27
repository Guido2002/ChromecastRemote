/// A launchable TV app shown as a shortcut on the remote.
///
/// Apps are launched over Android TV Remote Protocol v2 using a
/// `market://launch?id=<package>` app link, the mechanism documented by the
/// Home Assistant deep-linking guide for launching any app by package name:
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
    // A bare package name is turned into the standard launch link; anything
    // with a URI scheme is sent as-is (deep link).
    final looksLikePackage =
        !trimmed.contains('://') && trimmed.contains('.');
    final launchUrl =
        looksLikePackage ? 'market://launch?id=$trimmed' : trimmed;
    return TvApp(
      id: 'custom:${name.trim().toLowerCase()}',
      name: name.trim(),
      launchUrl: launchUrl,
      packageName: looksLikePackage ? trimmed : null,
      custom: true,
    );
  }

  factory TvApp.fromJson(Map<String, dynamic> json) => TvApp(
        id: json['id'] as String,
        name: json['name'] as String,
        launchUrl: json['launchUrl'] as String,
        packageName: json['packageName'] as String?,
        custom: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'launchUrl': launchUrl,
        if (packageName != null) 'packageName': packageName,
      };
}

enum TvAppCategory { movies, music, gaming, kids, other }

/// Launch link used to start an app by its package name.
String packageLaunchUrl(String packageName) => 'market://launch?id=$packageName';

/// Curated catalog. Package names verified against the Google Play Store.
const catalogApps = <TvApp>[
  TvApp(
    id: 'netflix',
    name: 'Netflix',
    packageName: 'com.netflix.ninja',
    launchUrl: 'market://launch?id=com.netflix.ninja',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'youtube',
    name: 'YouTube',
    packageName: 'com.google.android.youtube.tv',
    launchUrl: 'market://launch?id=com.google.android.youtube.tv',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'prime-video',
    name: 'Prime Video',
    packageName: 'com.amazon.amazonvideo.livingroom',
    launchUrl: 'market://launch?id=com.amazon.amazonvideo.livingroom',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'disney-plus',
    name: 'Disney+',
    packageName: 'com.disney.disneyplus',
    launchUrl: 'market://launch?id=com.disney.disneyplus',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'videoland',
    name: 'Videoland',
    packageName: 'nl.rtl.videoland.v2',
    launchUrl: 'market://launch?id=nl.rtl.videoland.v2',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'npo-start',
    name: 'NPO Start',
    packageName: 'nl.uitzendinggemist',
    launchUrl: 'market://launch?id=nl.uitzendinggemist',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'nlziet',
    name: 'NLZIET',
    packageName: 'nl.nlziet',
    launchUrl: 'market://launch?id=nl.nlziet',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'ziggo-go',
    name: 'Ziggo GO',
    packageName: 'com.ziggo.tv',
    launchUrl: 'market://launch?id=com.ziggo.tv',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'spotify',
    name: 'Spotify',
    packageName: 'com.spotify.tv.android',
    launchUrl: 'market://launch?id=com.spotify.tv.android',
    category: TvAppCategory.music,
  ),
  TvApp(
    id: 'plex',
    name: 'Plex',
    packageName: 'com.plexapp.android',
    launchUrl: 'market://launch?id=com.plexapp.android',
    category: TvAppCategory.movies,
  ),
  TvApp(
    id: 'twitch',
    name: 'Twitch',
    packageName: 'tv.twitch.android.app',
    launchUrl: 'market://launch?id=tv.twitch.android.app',
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
