import 'package:chromecast_remote/core/protocol/android_tv/pairing_secret.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2048-bit test moduli (0xC3 / 0xA7 repeated 256 times).
  final clientModulus = BigInt.parse('C3' * 256, radix: 16);
  final serverModulus = BigInt.parse('A7' * 256, radix: 16);
  final exponent = BigInt.from(65537);

  group('derivePairingSecret', () {
    test('matches the reference implementation output', () {
      // Known-answer vector computed with the Python reference
      // (androidtvremote2 pairing.py): SHA-256 over
      // clientModulus || 0‖clientExp || serverModulus || 0‖serverExp || code[2:].
      final secret = derivePairingSecret(
        clientModulus: clientModulus,
        clientExponent: exponent,
        serverModulus: serverModulus,
        serverExponent: exponent,
        pairingCode: '62b2c3',
      );

      expect(
        secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '62e7c71a8cb5a0b6d1a972d67b41dc1f0cdd1332a09277a61a35a2598744db31',
      );
    });

    test('accepts uppercase hex codes', () {
      final secret = derivePairingSecret(
        clientModulus: clientModulus,
        clientExponent: exponent,
        serverModulus: serverModulus,
        serverExponent: exponent,
        pairingCode: '62B2C3',
      );
      expect(secret.first, 0x62);
    });

    test('rejects a code whose first byte does not match the hash', () {
      // Same suffix as the valid code, wrong prefix: the TV would reject this,
      // and we catch it locally before sending anything.
      expect(
        () => derivePairingSecret(
          clientModulus: clientModulus,
          clientExponent: exponent,
          serverModulus: serverModulus,
          serverExponent: exponent,
          pairingCode: 'a1b2c3',
        ),
        throwsA(isA<InvalidPairingCodeException>()),
      );
    });

    test('rejects malformed codes', () {
      for (final bad in ['', '12345', '1234567', 'zzzzzz', '12 456']) {
        expect(
          () => derivePairingSecret(
            clientModulus: clientModulus,
            clientExponent: exponent,
            serverModulus: serverModulus,
            serverExponent: exponent,
            pairingCode: bad,
          ),
          throwsA(isA<InvalidPairingCodeException>()),
          reason: 'code "$bad" must be rejected',
        );
      }
    });
  });
}
