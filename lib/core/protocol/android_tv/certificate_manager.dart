import 'dart:convert';
import 'dart:io';


import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/foundation.dart';

import '../../storage/secure_store.dart';
import 'rsa_public_key_reader.dart';

/// Runs in a background isolate; must stay a top-level function.
Map<String, String> _generateKeyPairAndCertificate(int keySize) {
  final pair = CryptoUtils.generateRSAKeyPair(keySize: keySize);
  final publicKey = pair.publicKey as RSAPublicKey;
  final privateKey = pair.privateKey as RSAPrivateKey;

  final csrPem = X509Utils.generateRsaCsrPem(
    {'CN': 'atvremote'},
    privateKey,
    publicKey,
  );
  final certificatePem =
      X509Utils.generateSelfSignedCertificate(privateKey, csrPem, 3650);

  // PKCS#8 ("BEGIN PRIVATE KEY") — Dart's SecurityContext/BoringSSL does not
  // accept PKCS#1 ("BEGIN RSA PRIVATE KEY") here.
  final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

  return {'cert': certificatePem, 'key': keyPem};
}

/// Manages this app's self-signed TLS client identity.
///
/// Android TV Remote Protocol v2 uses mutual TLS: the client presents a
/// self-signed X.509 certificate, and the TV remembers it during pairing.
/// The key pair is generated once (RSA-2048) and persisted as PEM in secure
/// platform storage, so pairings survive app restarts.
class CertificateManager {
  CertificateManager({required this.store});

  static const _certificateKey = 'atv_client_cert_pem_v1';
  static const _privateKeyKey = 'atv_client_key_pem_v1';

  final SecureStore store;

  String? _certificatePem;
  String? _privateKeyPem;

  /// Loads the identity from secure storage, generating it on first launch.
  Future<void> ensureReady() async {
    if (_certificatePem != null && _privateKeyPem != null) return;

    _certificatePem = await store.read(_certificateKey);
    _privateKeyPem = await store.read(_privateKeyKey);

    if (_certificatePem == null || _privateKeyPem == null) {
      final result = await compute(_generateKeyPairAndCertificate, 2048);
      _certificatePem = result['cert']!;
      _privateKeyPem = result['key']!;
      await store.write(_certificateKey, _certificatePem!);
      await store.write(_privateKeyKey, _privateKeyPem!);
    }
  }

  /// Builds a [SecurityContext] carrying our client certificate.
  Future<SecurityContext> buildSecurityContext() async {
    await ensureReady();
    final context = SecurityContext(withTrustedRoots: false);
    context.useCertificateChainBytes(utf8.encode(_certificatePem!));
    context.usePrivateKeyBytes(utf8.encode(_privateKeyPem!));
    return context;
  }

  /// DER bytes of our certificate (used for pairing secret derivation).
  Future<Uint8List> certificateDer() async {
    await ensureReady();
    return CryptoUtils.getBytesFromPEMString(_certificatePem!);
  }

  /// RSA modulus/exponent of our certificate's public key.
  Future<RsaPublicKeyParts> publicKeyParts() async =>
      rsaPublicKeyFromCertificateDer(await certificateDer());
}
