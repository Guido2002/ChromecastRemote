import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'certificate_manager.dart';
import 'framing.dart';
import 'pairing_secret.dart';
import 'proto/polo.pb.dart';
import 'rsa_public_key_reader.dart';

/// Result of a completed pairing: the server certificate, which the caller
/// should pin so future connections can verify they reach the same TV.
class PairingResult {
  const PairingResult({required this.serverCertificateDer});

  final Uint8List serverCertificateDer;
}

/// Implements the Google TV pairing protocol ("polo") on TCP port 6467.
///
/// Flow, mirroring https://github.com/tronikos/androidtvremote2 pairing.py:
///   client -> PairingRequest
///   server -> PairingRequestAck
///   client -> Options (input role, hexadecimal encoding, 6 symbols)
///   server -> Options
///   client -> Configuration
///   server -> ConfigurationAck          (startPairing completes)
///   ... user enters the code shown on the TV ...
///   client -> Secret (SHA-256 derived from both certificates + code)
///   server -> SecretAck                 (finishPairing completes)
///
/// Every message is an [OuterMessage] framed with a varint length prefix.
class AndroidTvPairingClient {
  AndroidTvPairingClient({required this.certificates});

  static const defaultPort = 6467;
  static const _stepTimeout = Duration(seconds: 10);

  final CertificateManager certificates;
  final MessageFraming _framing = MessageFraming();

  SecureSocket? _socket;
  StreamSubscription<List<int>>? _subscription;
  Completer<void>? _startCompleter;
  Completer<void>? _finishCompleter;
  X509Certificate? _serverCertificate;

  /// The certificate the TV presented during the TLS handshake.
  X509Certificate? get serverCertificate => _serverCertificate;

  bool get isConnected => _socket != null;

  /// Opens the TLS connection to the pairing port.
  ///
  /// The TV presents a self-signed certificate. Its authenticity is not
  /// established by a CA but by the pairing code: the user visually compares a
  /// code derived from both certificates, so accepting the certificate here is
  /// required by the protocol design. After pairing, callers pin the returned
  /// certificate and verify it on reconnect.
  Future<X509Certificate> connect(
    String host, {
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await close();
    final context = await certificates.buildSecurityContext();
    try {
      _socket = await SecureSocket.connect(
        host,
        port,
        context: context,
        onBadCertificate: (certificate) {
          _serverCertificate = certificate;
          return true;
        },
        timeout: timeout,
      );
    } on SocketException catch (error) {
      throw PairingException('Could not reach the TV: ${error.message}');
    } on HandshakeException catch (error) {
      throw PairingException('TLS handshake with the TV failed: $error');
    }

    _framing.clear();
    _subscription = _socket!.listen(
      _onData,
      onError: (Object error) => _failAll('Connection error: $error'),
      onDone: () => _failAll('The TV closed the pairing connection.'),
    );

    final certificate = _serverCertificate ?? _socket!.peerCertificate;
    if (certificate == null) {
      await close();
      throw const PairingException('The TV did not present a certificate.');
    }
    _serverCertificate = certificate;
    return certificate;
  }

  /// Sends the pairing request and waits until the TV is ready to accept a
  /// pairing code (ConfigurationAck received).
  Future<void> startPairing({String clientName = 'Chromecast Remote'}) {
    _ensureConnected();
    _startCompleter = Completer<void>();
    final message = _outerMessage()
      ..pairingRequest = (PairingRequest()
        ..serviceName = 'atvremote'
        ..clientName = clientName);
    _send(message);
    return _withTimeout(_startCompleter!.future);
  }

  /// Completes pairing with the 6-character hexadecimal code shown on the TV.
  ///
  /// Throws [InvalidPairingCodeException] for a wrong code and
  /// [PairingException] for protocol/connection failures.
  Future<PairingResult> finishPairing(String pairingCode) async {
    _ensureConnected();
    final serverDer = _serverCertificate?.der;
    if (serverDer == null) {
      throw const PairingException('Missing TV certificate; reconnect first.');
    }

    final clientParts = await certificates.publicKeyParts();
    final serverParts =
        rsaPublicKeyFromCertificateDer(Uint8List.fromList(serverDer));

    final secret = derivePairingSecret(
      clientModulus: clientParts.modulus,
      clientExponent: clientParts.exponent,
      serverModulus: serverParts.modulus,
      serverExponent: serverParts.exponent,
      pairingCode: pairingCode,
    );

    _finishCompleter = Completer<void>();
    final message = _outerMessage()..secret = (Secret()..secret = secret);
    _send(message);
    await _withTimeout(_finishCompleter!.future);
    return PairingResult(serverCertificateDer: Uint8List.fromList(serverDer));
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    socket?.destroy();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  OuterMessage _outerMessage() => OuterMessage()
    ..protocolVersion = 2
    ..status = OuterMessage_Status.STATUS_OK;

  void _send(OuterMessage message) {
    final socket = _socket;
    if (socket == null) return;
    socket.add(MessageFraming.encode(message.writeToBuffer()));
  }

  void _onData(List<int> data) {
    final List<Uint8List> rawMessages;
    try {
      rawMessages = _framing.addData(data);
    } on FramingException catch (error) {
      _failAll(error.message);
      return;
    }
    for (final raw in rawMessages) {
      _handleMessage(raw);
    }
  }

  void _handleMessage(Uint8List raw) {
    final OuterMessage message;
    try {
      message = OuterMessage.fromBuffer(raw);
    } catch (_) {
      _failAll('Received an unreadable pairing message from the TV.');
      return;
    }

    if (message.status != OuterMessage_Status.STATUS_OK) {
      if (message.status == OuterMessage_Status.STATUS_BAD_SECRET) {
        _finishCompleter?.completeError(
          const InvalidPairingCodeException(
            'The TV rejected the pairing code. Try again.',
          ),
        );
      } else {
        _failAll('Pairing failed with status ${message.status.name}.');
      }
      return;
    }

    if (message.hasPairingRequestAck()) {
      final encoding = Options_Encoding()
        ..type = Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL
        ..symbolLength = 6;
      final reply = _outerMessage()
        ..options = (Options()
          ..preferredRole = Options_RoleType.ROLE_TYPE_INPUT
          ..inputEncodings.add(encoding));
      _send(reply);
    } else if (message.hasOptions()) {
      final reply = _outerMessage()
        ..configuration = (Configuration()
          ..clientRole = Options_RoleType.ROLE_TYPE_INPUT
          ..encoding = (Options_Encoding()
            ..type = Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL
            ..symbolLength = 6));
      _send(reply);
    } else if (message.hasConfigurationAck()) {
      _startCompleter?.complete();
    } else if (message.hasSecretAck()) {
      _finishCompleter?.complete();
    }
    // Unknown messages are ignored; the pairing flow above is exhaustive.
  }

  Future<void> _withTimeout(Future<void> future) {
    return future.timeout(
      _stepTimeout,
      onTimeout: () {
        unawaited(close());
        throw const PairingException(
          'The TV did not respond in time. Make sure the pairing screen is '
          'visible on the TV and try again.',
        );
      },
    );
  }

  void _ensureConnected() {
    if (_socket == null) {
      throw const PairingException('Not connected to the TV.');
    }
  }

  void _failAll(String message) {
    final error = PairingException(message);
    if (_startCompleter?.isCompleted == false) {
      _startCompleter!.completeError(error);
    }
    if (_finishCompleter?.isCompleted == false) {
      _finishCompleter!.completeError(error);
    }
  }
}
