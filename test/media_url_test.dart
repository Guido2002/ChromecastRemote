import 'package:chromecast_remote/media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CastMediaUrl.parse', () {
    test('trims whitespace and recognizes video content types', () {
      final media = CastMediaUrl.parse('  https://media.example/movie.mp4  ');

      expect(media.uri.toString(), 'https://media.example/movie.mp4');
      expect(media.contentType, 'video/mp4');
      expect(media.hasKnownFormat, isTrue);
    });

    test('recognizes audio, HLS, and DASH formats', () {
      expect(
        CastMediaUrl.parse('https://media.example/song.MP3').contentType,
        'audio/mpeg',
      );
      expect(
        CastMediaUrl.parse('https://media.example/channel.m3u8').contentType,
        'application/x-mpegURL',
      );
      expect(
        CastMediaUrl.parse('https://media.example/manifest.mpd').contentType,
        'application/dash+xml',
      );
    });

    test('flags extensions the app cannot identify', () {
      final media = CastMediaUrl.parse('https://media.example/stream.unknown');

      expect(media.hasKnownFormat, isFalse);
      expect(media.contentType, 'application/octet-stream');
    });

    test('rejects empty, relative, and non-http links', () {
      expect(
        () => CastMediaUrl.parse('  '),
        throwsA(isA<MediaUrlException>()),
      );
      expect(
        () => CastMediaUrl.parse('/media/movie.mp4'),
        throwsA(isA<MediaUrlException>()),
      );
      expect(
        () => CastMediaUrl.parse('file:///movie.mp4'),
        throwsA(isA<MediaUrlException>()),
      );
    });

    test('rejects links that expose embedded credentials', () {
      expect(
        () => CastMediaUrl.parse('https://user:password@media.example/movie.mp4'),
        throwsA(isA<MediaUrlException>()),
      );
    });
  });
}
