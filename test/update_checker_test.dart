import 'package:chromecast_remote/features/update/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLatestRelease', () {
    test('parses a GitHub releases/latest response', () {
      final release = parseLatestRelease({
        'tag_name': 'v0.2.0',
        'name': 'v0.2.0',
        'html_url':
            'https://github.com/Guido2002/ChromecastRemote/releases/tag/v0.2.0',
      });

      expect(release.version, '0.2.0');
      expect(release.name, 'v0.2.0');
      expect(release.url.host, 'github.com');
    });

    test('accepts tags without a leading v and falls back to the tag name',
        () {
      final release = parseLatestRelease({
        'tag_name': '1.0.0',
        'name': '',
        'html_url': 'https://github.com/Guido2002/ChromecastRemote/releases/tag/1.0.0',
      });

      expect(release.version, '1.0.0');
      expect(release.name, '1.0.0');
    });

    test('rejects responses without a tag or url', () {
      expect(
        () => parseLatestRelease({'name': 'v1'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseLatestRelease({'tag_name': '', 'html_url': ''}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('isNewerVersion', () {
    test('detects newer versions', () {
      expect(isNewerVersion('0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('1.0.0', '0.9.9'), isTrue);
      expect(isNewerVersion('0.1.1', '0.1.0'), isTrue);
    });

    test('detects equal and older versions', () {
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.1.0', '0.2.0'), isFalse);
      expect(isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('ignores build metadata and missing segments', () {
      expect(isNewerVersion('0.2.0', '0.1.0+3'), isTrue);
      expect(isNewerVersion('0.2.0', '0.2.0+9'), isFalse);
      expect(isNewerVersion('0.2', '0.2.0'), isFalse);
      expect(isNewerVersion('0.2.1', '0.2'), isTrue);
    });
  });
}
