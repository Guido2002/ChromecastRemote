import 'package:chromecast_remote/core/protocol/android_tv/proto/remotemessage.pb.dart';
import 'package:chromecast_remote/core/protocol/android_tv/text_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AndroidTvTextInput input;
  setUp(() => input = AndroidTvTextInput());
  tearDown(() => input.dispose());

  test('no input token is invented before the TV reports counters', () {
    expect(input.session, isNull);
    input.updateCounters(0, 0);
    final request = input.createRequest('hello', input.session!);
    expect(request, isNotNull);
    expect(request!.remoteImeBatchEdit.imeCounter, 0);
    expect(request.remoteImeBatchEdit.fieldCounter, 0);
  });

  test('encodes a text request to the reference wire format', () {
    input.updateCounters(7, 9);
    expect(input.createRequest('ab', input.session!)!.writeToBuffer(), [
      0xaa,
      0x01,
      0x12,
      0x08,
      0x07,
      0x10,
      0x09,
      0x1a,
      0x0c,
      0x08,
      0x01,
      0x12,
      0x08,
      0x08,
      0x01,
      0x10,
      0x01,
      0x1a,
      0x02,
      0x61,
      0x62,
    ]);
  });

  test(
    'Unicode offsets follow reference code point length rather than UTF16 units',
    () {
      input.updateCounters(17, 23);
      final bytes = input.createRequest('é😀', input.session!)!.writeToBuffer();
      final batch = RemoteMessage.fromBuffer(bytes).remoteImeBatchEdit;
      expect(batch.imeCounter, 17);
      expect(batch.fieldCounter, 23);
      final text = batch.editInfo.single.textFieldStatus;
      expect(text.value, 'é😀');
      expect(text.start, 1);
      expect(text.end, 1);
    },
  );

  test(
    'field changes reject the old draft token and duplicate reports preserve it',
    () {
      input.updateCounters(1, 2);
      final token = input.session!;
      input.updateCounters(1, 2);
      expect(input.session, same(token));
      input.updateCounters(1, 3);
      expect(input.createRequest('old draft', token), isNull);
      expect(input.createRequest('new draft', input.session!), isNotNull);
    },
  );

  test(
    'app switches and reconnection invalidate tokens even when counters repeat',
    () {
      input.updateApp('com.example.first');
      input.updateCounters(1, 2);
      final first = input.session!;
      input.updateApp('com.example.second');
      expect(input.session, isNull);
      input.updateCounters(1, 2);
      expect(input.createRequest('old app', first), isNull);
      final second = input.session!;
      input.reset();
      input.updateCounters(1, 2);
      expect(input.createRequest('old connection', second), isNull);
    },
  );

  test('empty, NUL, and oversized input never produces a request', () {
    input.updateCounters(1, 2);
    for (final text in ['', 'a\u0000b', 'x' * 2001]) {
      expect(input.createRequest(text, input.session!), isNull);
    }
    expect(input.createRequest(' ', input.session!), isNotNull);
    expect(input.createRequest('😀' * 2000, input.session!), isNotNull);
  });
}
