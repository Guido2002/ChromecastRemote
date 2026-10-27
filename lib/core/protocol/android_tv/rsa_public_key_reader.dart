import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';

/// The RSA modulus and exponent extracted from an X.509 certificate.
class RsaPublicKeyParts {
  const RsaPublicKeyParts({required this.modulus, required this.exponent});

  final BigInt modulus;
  final BigInt exponent;
}

/// Extracts the RSA public key from a DER-encoded X.509 certificate.
///
/// Needed for the Android TV pairing secret derivation, which hashes the
/// modulus and exponent of both the client and the server certificate.
RsaPublicKeyParts rsaPublicKeyFromCertificateDer(Uint8List derBytes) {
  final certificate = ASN1Parser(derBytes).nextObject() as ASN1Sequence;
  final tbsCertificate = certificate.elements[0] as ASN1Sequence;
  for (final element in tbsCertificate.elements) {
    // SubjectPublicKeyInfo is the only TBSCertificate field that is a
    // SEQUENCE of (algorithm SEQUENCE, publicKey BIT STRING).
    if (element is! ASN1Sequence || element.elements.length != 2) continue;
    final algorithm = element.elements[0];
    final publicKey = element.elements[1];
    if (algorithm is! ASN1Sequence || publicKey is! ASN1BitString) continue;

    // contentBytes() of an asn1lib bit string excludes the "unused bits"
    // byte, so this is directly the DER-encoded RSAPublicKey sequence.
    final keySequence =
        ASN1Parser(publicKey.contentBytes()).nextObject() as ASN1Sequence;
    final modulus = keySequence.elements[0] as ASN1Integer;
    final exponent = keySequence.elements[1] as ASN1Integer;
    return RsaPublicKeyParts(
      modulus: modulus.valueAsBigInteger,
      exponent: exponent.valueAsBigInteger,
    );
  }
  throw ArgumentError(
    'No RSA SubjectPublicKeyInfo found in the X.509 certificate.',
  );
}
