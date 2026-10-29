import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/protocol/android_tv/android_tv_pairing_client.dart';
import '../../../core/protocol/android_tv/pairing_secret.dart';
import '../../../shared/presentation/adaptive_layout.dart';
import '../../../shared/presentation/app_motion.dart';
import '../paired_device_store.dart';

/// Guides the user through Android TV Remote Protocol v2 pairing:
/// connects to the TV's pairing port, asks for the code shown on the TV,
/// verifies it cryptographically, and stores the trusted device.
///
/// On success pops with the resulting [PairedAndroidTv].
class PairingScreen extends StatefulWidget {
  const PairingScreen({
    required this.serviceName,
    required this.displayName,
    required this.host,
    super.key,
  });

  final String serviceName;
  final String displayName;
  final String host;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

enum _PairingPhase { connecting, awaitingCode, verifying, failed }

class _PairingScreenState extends State<PairingScreen> {
  late final AndroidTvPairingClient _pairingClient;
  final _codeController = TextEditingController();

  _PairingPhase _phase = _PairingPhase.connecting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pairingClient = AndroidTvPairingClient(
      certificates: AppServices.instance.certificates,
    );
    unawaited(_beginPairing());
  }

  Future<void> _beginPairing() async {
    setState(() {
      _phase = _PairingPhase.connecting;
      _error = null;
    });
    try {
      await _pairingClient.connect(widget.host);
      await _pairingClient.startPairing();
      if (mounted) setState(() => _phase = _PairingPhase.awaitingCode);
    } on PairingException catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PairingPhase.failed;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PairingPhase.failed;
          _error =
              'Could not complete pairing. Check TV power and Wi-Fi, then try again.';
        });
      }
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (_phase != _PairingPhase.awaitingCode ||
        !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(code)) {
      return;
    }
    setState(() {
      _phase = _PairingPhase.verifying;
      _error = null;
    });
    try {
      final result = await _pairingClient.finishPairing(code);
      final paired = PairedAndroidTv(
        serviceName: widget.serviceName,
        displayName: widget.displayName,
        lastHost: widget.host,
        serverCertificateSha256: sha256
            .convert(result.serverCertificateDer)
            .toString(),
        pairedAt: DateTime.now(),
      );
      await AppServices.instance.pairedDevices.save(paired);
      if (mounted) Navigator.of(context).pop(paired);
    } on InvalidPairingCodeException catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PairingPhase.awaitingCode;
          _error = error.message;
        });
      }
    } on PairingException catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PairingPhase.failed;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PairingPhase.failed;
          _error =
              'Could not complete pairing. Check TV power and Wi-Fi, then try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    unawaited(_pairingClient.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with TV')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AdaptiveContent(
            maxWidth: 560,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(
                AdaptiveLayout.isTablet(context) ? 40 : 24,
              ),
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppMotion.emphasized,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.985, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_phase),
                  child: switch (_phase) {
                    _PairingPhase.connecting => _PairingProgress(
                      title: 'Connecting to ${widget.displayName}…',
                      message:
                          'Starting the pairing session. If the TV shows a '
                          'pairing prompt, accept it.',
                    ),
                    _PairingPhase.verifying => const _PairingProgress(
                      title: 'Verifying code…',
                    ),
                    _PairingPhase.awaitingCode => _buildCodeEntry(colors),
                    _PairingPhase.failed => _buildFailure(colors),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEntry(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.pin_outlined, size: 48, color: colors.primary),
        const SizedBox(height: 16),
        Text(
          'Enter the code shown on your TV',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.displayName} shows a 6-character pairing code.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _CodeInput(
          controller: _codeController,
          onSubmitted: (_) => _submitIfComplete(),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: colors.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _codeController.text.length == 6 ? _submitCode : null,
          child: const Text('Pair'),
        ),
      ],
    );
  }

  void _submitIfComplete() {
    if (_codeController.text.trim().length == 6) unawaited(_submitCode());
  }

  Widget _buildFailure(ColorScheme colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline, size: 48, color: colors.error),
        const SizedBox(height: 16),
        Text(
          'Pairing failed',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Unknown error',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _beginPairing,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      maxLength: 6,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 8),
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
      ],
      decoration: const InputDecoration(
        labelText: 'Six-character TV code',
        hintText: 'A1B2C3',
        counterText: '',
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _PairingProgress extends StatelessWidget {
  const _PairingProgress({required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
