import 'dart:typed_data';

import 'package:chromecast_remote/core/protocol/android_tv/framing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageFraming.encode', () {
    test('prefixes short messages with a single varint byte', () {
      final framed = MessageFraming.encode(Uint8List.fromList([1, 2, 3]));
      expect(framed, [3, 1, 2, 3]);
    });

    test('encodes lengths >= 128 as multi-byte varints', () {
      final framed =
          MessageFraming.encode(Uint8List(300)); // 300 = 0xAC 0x02
      expect(framed[0], 0xAC);
      expect(framed[1], 0x02);
      expect(framed.length, 302);
    });

    test('encodes an empty message', () {
      expect(MessageFraming.encode(Uint8List(0)), [0]);
    });
  });

  group('MessageFraming.addData', () {
    test('decodes a single complete message', () {
      final framing = MessageFraming();
      final messages =
          framing.addData(MessageFraming.encode(Uint8List.fromList([9, 8])));
      expect(messages.single, [9, 8]);
    });

    test('reassembles a message split across reads', () {
      final framing = MessageFraming();
      final framed =
          MessageFraming.encode(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(framing.addData(framed.sublist(0, 2)), isEmpty);
      expect(framing.addData(framed.sublist(2, 4)), isEmpty);
      final messages = framing.addData(framed.sublist(4));
      expect(messages.single, [1, 2, 3, 4, 5]);
    });

    test('decodes multiple messages from one read', () {
      final framing = MessageFraming();
      final combined = BytesBuilder()
        ..add(MessageFraming.encode(Uint8List.fromList([1])))
        ..add(MessageFraming.encode(Uint8List.fromList([2, 3])));
      final messages = framing.addData(combined.toBytes());
      expect(messages, [
        [1],
        [2, 3],
      ]);
    });

    test('handles a varint split across reads', () {
      final framing = MessageFraming();
      final framed = MessageFraming.encode(Uint8List(300));
      expect(framing.addData(framed.sublist(0, 1)), isEmpty);
      final messages = framing.addData(framed.sublist(1));
      expect(messages.single.length, 300);
    });

    test('throws FramingException on a malformed length prefix', () {
      final framing = MessageFraming();
      expect(
        // Five continuation bytes: not a valid 32-bit varint.
        () => framing.addData([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
        throwsA(isA<FramingException>()),
      );
    });
  });
}
