import 'package:basic_utils/basic_utils.dart';
import 'package:chromecast_remote/core/protocol/android_tv/rsa_public_key_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rsaPublicKeyFromCertificateDer', () {
    test('extracts modulus and exponent from a generated certificate', () {
      final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
      final publicKey = pair.publicKey as RSAPublicKey;
      final privateKey = pair.privateKey as RSAPrivateKey;

      final csrPem = X509Utils.generateRsaCsrPem(
        {'CN': 'atvremote-test'},
        privateKey,
        publicKey,
      );
      final certPem =
          X509Utils.generateSelfSignedCertificate(privateKey, csrPem, 365);
      final der = CryptoUtils.getBytesFromPEMString(certPem);

      final parts = rsaPublicKeyFromCertificateDer(der);

      expect(parts.modulus, publicKey.modulus);
      expect(parts.exponent, publicKey.exponent);
      expect(parts.exponent, BigInt.from(65537));
    });

    test('rejects data that is not a certificate', () {
      expect(
        () => rsaPublicKeyFromCertificateDer(
          CryptoUtils.getBytesFromPEMString(''),
        ),
        throwsA(anything),
      );
    });
  });
}
