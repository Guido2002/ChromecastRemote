class MediaUrlException implements Exception {
  const MediaUrlException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CastMediaUrl {
  const CastMediaUrl({
    required this.uri,
    required this.contentType,
    required this.hasKnownFormat,
  });

  final Uri uri;
  final String contentType;
  final bool hasKnownFormat;

  static CastMediaUrl parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const MediaUrlException('Enter a direct media URL first.');
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const MediaUrlException(
        'Use a valid direct media link starting with http:// or https://.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const MediaUrlException(
        'Links containing a username or password are not supported.',
      );
    }

    final extension = _extension(uri.path);
    final contentType = _contentTypes[extension];
    return CastMediaUrl(
      uri: uri,
      contentType: contentType ?? 'application/octet-stream',
      hasKnownFormat: contentType != null,
    );
  }

  static String _extension(String path) {
    final filename = path.split('/').where((part) => part.isNotEmpty).lastOrNull;
    if (filename == null) return '';
    final separator = filename.lastIndexOf('.');
    return separator == -1 ? '' : filename.substring(separator + 1).toLowerCase();
  }

  static const _contentTypes = <String, String>{
    'aac': 'audio/aac',
    'm3u8': 'application/x-mpegURL',
    'm4a': 'audio/mp4',
    'm4v': 'video/mp4',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
    'mpd': 'application/dash+xml',
    'oga': 'audio/ogg',
    'ogg': 'audio/ogg',
    'ogv': 'video/ogg',
    'wav': 'audio/wav',
    'webm': 'video/webm',
  };
}

extension on Iterable<String> {
  String? get lastOrNull {
    if (isEmpty) return null;
    return last;
  }
}
