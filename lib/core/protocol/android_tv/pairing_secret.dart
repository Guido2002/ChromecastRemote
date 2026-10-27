import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Error raised while completing Android TV pairing.
class PairingException implements Exception {
  const PairingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The pairing code the user entered was wrong or malformed.
class InvalidPairingCodeException extends PairingException {
  const InvalidPairingCodeException(super.message);
}

/// Derives the pairing secret for the Google TV pairing protocol ("polo").
///
/// Mirrors the reference implementation in
/// https://github.com/tronikos/androidtvremote2 (pairing.py), which is based
/// on https://android.googlesource.com/platform/external/google-tv-pairing-protocol:
///
///   secret = SHA-256(clientModulus || 0x00‖clientExponent ||
///                    serverModulus || 0x00‖serverExponent || code[2:])
///
/// The first byte of the SHA-256 digest must equal the first byte of the
/// pairing code; the TV shows only codes for which this holds, which lets us
/// detect a mistyped code before sending anything.
///
/// [pairingCode] is the 6-character hexadecimal code shown on the TV.
Uint8List derivePairingSecret({
  required BigInt clientModulus,
  required BigInt clientExponent,
  required BigInt serverModulus,
  required BigInt serverExponent,
  required String pairingCode,
}) {
  final code = pairingCode.trim();
  if (code.length != 6 || int.tryParse(code, radix: 16) == null) {
    throw const InvalidPairingCodeException(
      'The pairing code must be the 6 hexadecimal characters shown on the TV.',
    );
  }

  final digest = sha256.convert(<int>[
    ..._bigIntToBytes(clientModulus),
    ..._exponentToBytes(clientExponent),
    ..._bigIntToBytes(serverModulus),
    ..._exponentToBytes(serverExponent),
    ..._hexToBytes(code.substring(2)),
  ]);
  final secret = Uint8List.fromList(digest.bytes);

  if (secret[0] != int.parse(code.substring(0, 2), radix: 16)) {
    throw const InvalidPairingCodeException(
      'That code does not match. Check the code shown on the TV and try again.',
    );
  }
  return secret;
}

/// Minimal big-endian bytes of [value], matching Python's
/// `bytes.fromhex(f"{value:X}")`.
Uint8List _bigIntToBytes(BigInt value) {
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  return _hexToBytes(hex);
}

/// Exponent encoding used by the protocol: the hex representation prefixed
/// with a literal '0' nibble (e.g. 65537 -> 0x01 0x00 0x01).
Uint8List _exponentToBytes(BigInt value) =>
    _hexToBytes('0${value.toRadixString(16)}');

Uint8List _hexToBytes(String hex) {
  assert(hex.length.isEven);
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
