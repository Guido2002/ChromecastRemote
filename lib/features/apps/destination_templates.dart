import 'tv_app.dart';

enum DestinationProvider { custom, youtube, spotify }

abstract final class DestinationTemplates {
  static TvApp create(DestinationProvider provider, String name, String input) {
    if (name.trim().isEmpty) throw const FormatException('Enter a name.');
    var target = input.trim();
    String? package;
    switch (provider) {
      case DestinationProvider.custom:
        final packageName = RegExp(
          r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$',
        ).hasMatch(target);
        final uri = Uri.tryParse(target);
        if (!packageName &&
            (uri == null ||
                !uri.hasScheme ||
                uri.userInfo.isNotEmpty ||
                [
                  'file',
                  'javascript',
                  'data',
                  'intent',
                ].contains(uri.scheme.toLowerCase()))) {
          throw const FormatException(
            'Enter a valid app link or package name.',
          );
        }
        return TvApp.customEntry(name: name, target: target);
      case DestinationProvider.youtube:
        final uri = Uri.tryParse(target);
        String? id;
        if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty) {
          if (uri.host == 'youtu.be' && uri.pathSegments.length == 1) {
            id = uri.pathSegments.first;
          }
          if ([
                'youtube.com',
                'www.youtube.com',
                'm.youtube.com',
              ].contains(uri.host) &&
              uri.path == '/watch') {
            id = uri.queryParameters['v'];
          }
        }
        if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
          throw const FormatException('Paste a YouTube video share link.');
        }
        target = Uri.https('www.youtube.com', '/watch', {'v': id}).toString();
        package = 'com.google.android.youtube.tv';
      case DestinationProvider.spotify:
        final uri = Uri.tryParse(target);
        String? kind, id;
        if (uri?.scheme == 'spotify') {
          final parts = uri!.path.split(':');
          if (parts.length == 2) {
            kind = parts[0];
            id = parts[1];
          }
        } else if (uri?.scheme == 'https' &&
            uri?.host == 'open.spotify.com' &&
            uri!.userInfo.isEmpty) {
          final parts = uri.pathSegments;
          if (parts.length == 2) {
            kind = parts[0];
            id = parts[1];
          }
        }
        if (!['track', 'album', 'playlist'].contains(kind) ||
            id == null ||
            !RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(id)) {
          throw const FormatException(
            'Paste a Spotify track, album, or playlist link.',
          );
        }
        target = 'spotify:$kind:$id';
        package = 'com.spotify.tv.android';
    }
    return TvApp(
      id: 'custom:${name.trim().toLowerCase()}',
      name: name.trim(),
      launchUrl: target,
      packageName: package,
      custom: true,
    );
  }
}
