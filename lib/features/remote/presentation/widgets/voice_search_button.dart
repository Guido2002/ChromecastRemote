import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/presentation/remote_haptics.dart';
import '../../voice/voice_search.dart';

/// Hold with a pointer; assistive-technology users activate once to start and
/// once again to stop. The same ten-second limit applies to both.
class VoiceSearchButton extends StatefulWidget {
  const VoiceSearchButton({
    required this.target,
    required this.active,
    this.microphone,
    this.onStatusChanged,
    super.key,
  });
  final TvVoiceTarget target;
  final bool active;
  final VoiceMicrophone? microphone;
  final ValueChanged<String?>? onStatusChanged;
  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton>
    with WidgetsBindingObserver {
  late final VoiceSearchController _voice;
  int? _pointer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = VoiceSearchController(
      target: widget.target,
      microphone: widget.microphone ?? RecordVoiceMicrophone(),
      isCurrentTarget: () => mounted && widget.active && _foreground,
    )..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onStatusChanged?.call(switch (_voice.phase) {
      VoiceSearchPhase.recording =>
        'Listening · release to send to ${widget.target.deviceName} · 10s max',
      VoiceSearchPhase.connecting => 'Waiting for ${widget.target.deviceName}…',
      VoiceSearchPhase.permission =>
        'Allow microphone access, then hold again if released.',
      VoiceSearchPhase.stopping => 'Ending voice request…',
      VoiceSearchPhase.idle => _voice.message,
    });
  }

  void _start() {
    if (!widget.active ||
        !_foreground ||
        !widget.target.voiceSupported ||
        _voice.busy) {
      return;
    }
    unawaited(RemoteHaptics.instance.press());
    unawaited(_voice.start());
  }

  @override
  void didUpdateWidget(VoiceSearchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) unawaited(_voice.stop(cancel: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _pointer = null;
      unawaited(_voice.stop(cancel: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_changed);
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.active && widget.target.voiceSupported;
    final label = switch (_voice.phase) {
      VoiceSearchPhase.permission =>
        'Allow microphone access, then hold again if released.',
      VoiceSearchPhase.connecting => 'Waiting for ${widget.target.deviceName}…',
      VoiceSearchPhase.recording =>
        'Listening · release to send · 10 seconds maximum',
      VoiceSearchPhase.stopping => 'Ending voice request…',
      VoiceSearchPhase.idle =>
        _voice.message ??
            'Hold to speak to ${widget.target.deviceName}. Audio goes to the TV’s voice service.',
    };
    return Tooltip(
      enableFeedback: false,
      message: enabled
          ? label
          : 'Voice search unavailable through this TV connection',
      child: Semantics(
        button: true,
        enabled: enabled,
        liveRegion: _voice.busy,
        label: 'Voice search',
        value: label,
        hint: _voice.busy
            ? 'Activate to stop recording'
            : 'Hold to speak. With a screen reader, activate to start and activate again to stop.',
        onTap: enabled
            ? () {
                if (_voice.busy) {
                  unawaited(_voice.stop());
                } else {
                  _start();
                }
              }
            : null,
        child: ExcludeSemantics(
          child: Listener(
            onPointerDown: enabled
                ? (event) {
                    if (_pointer != null) return;
                    _pointer = event.pointer;
                    _start();
                  }
                : null,
            onPointerUp: (event) {
              if (event.pointer != _pointer) return;
              _pointer = null;
              unawaited(_voice.stop());
              if (_voice.message != null) _showMessage();
            },
            onPointerCancel: (event) {
              if (event.pointer != _pointer) return;
              _pointer = null;
              unawaited(_voice.stop(cancel: true));
            },
            child: IconButton(
              onPressed: enabled
                  ? () {
                      // Expose visible status on a short tap too; never reopen a mic.
                      _showMessage();
                    }
                  : null,
              enableFeedback: false,
              color: _voice.recording
                  ? Theme.of(context).colorScheme.error
                  : null,
              icon: Icon(_voice.recording ? Icons.mic : Icons.mic_none_rounded),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _voice.message ??
              (_voice.recording
                  ? 'Listening. Release to send. Audio goes to ${widget.target.deviceName}; its voice service may process it online.'
                  : 'Hold the microphone, wait for Listening, then speak. Audio goes to ${widget.target.deviceName}; its voice service may process it online.'),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
