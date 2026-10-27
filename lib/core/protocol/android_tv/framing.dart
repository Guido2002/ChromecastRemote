import 'dart:typed_data';

/// Thrown when an incoming byte stream cannot be decoded as a framed message.
class FramingException implements Exception {
  const FramingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Varint length-delimited framing used by the Android TV Remote Protocol v2
/// for both the pairing port (6467) and the remote port (6466).
///
/// Each protobuf message on the wire is preceded by its length encoded as a
/// base-128 varint. A single TCP read may deliver a partial message, several
/// messages, or a split in the middle of the varint itself.
class MessageFraming {
  final List<int> _buffer = <int>[];

  /// Returns [message] prefixed with its varint-encoded length.
  static Uint8List encode(Uint8List message) {
    final builder = BytesBuilder();
    var length = message.length;
    while (true) {
      final byte = length & 0x7F;
      length >>= 7;
      if (length == 0) {
        builder.addByte(byte);
        break;
      }
      builder.addByte(byte | 0x80);
    }
    builder.add(message);
    return builder.toBytes();
  }

  /// Appends [data] to the internal buffer and returns every complete message
  /// that is now available. Incomplete trailing data stays buffered.
  ///
  /// Throws [FramingException] if the length prefix is malformed; the stream
  /// cannot be resynchronized after a corrupt length, so the caller should
  /// close the connection.
  List<Uint8List> addData(List<int> data) {
    _buffer.addAll(data);
    final messages = <Uint8List>[];
    while (_buffer.isNotEmpty) {
      var length = 0;
      var shift = 0;
      var varintLength = 0;
      var complete = false;
      for (var i = 0; i < _buffer.length && i < 5; i++) {
        final byte = _buffer[i];
        length |= (byte & 0x7F) << shift;
        shift += 7;
        varintLength++;
        if (byte & 0x80 == 0) {
          complete = true;
          break;
        }
      }
      if (!complete) {
        if (_buffer.length >= 5) {
          _buffer.clear();
          throw const FramingException(
            'Malformed varint length prefix in Android TV message stream.',
          );
        }
        break;
      }
      if (_buffer.length < varintLength + length) break;
      messages.add(
        Uint8List.fromList(_buffer.sublist(varintLength, varintLength + length)),
      );
      _buffer.removeRange(0, varintLength + length);
    }
    return messages;
  }

  void clear() => _buffer.clear();
}
