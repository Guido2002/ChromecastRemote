import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/protocol/android_tv/text_input.dart';
import '../remote_controller.dart';
import '../tv_keyboard_target.dart';

Future<void> showTvKeyboard(
  BuildContext context, {
  required TvKeyboardTarget target,
  required bool Function() isCurrentTarget,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) =>
      TvKeyboardSheet(target: target, isCurrentTarget: isCurrentTarget),
);

/// A local, explicit-send composer. It never mirrors or stores a TV field value.
class TvKeyboardSheet extends StatefulWidget {
  const TvKeyboardSheet({
    required this.target,
    required this.isCurrentTarget,
    super.key,
  });
  final TvKeyboardTarget target;
  final bool Function() isCurrentTarget;

  @override
  State<TvKeyboardSheet> createState() => _TvKeyboardSheetState();
}

class _TvKeyboardSheetState extends State<TvKeyboardSheet>
    with WidgetsBindingObserver {
  final _draft = TextEditingController();
  final _focus = FocusNode();
  StreamSubscription<AndroidTvTextSession?>? _sessions;
  StreamSubscription<RemoteConnectionState>? _connection;
  AndroidTvTextSession? _session;
  String? _message;
  bool _paused = false;
  bool _showText = false;

  bool get _ready =>
      !_paused &&
      widget.isCurrentTarget() &&
      widget.target.connectionState == RemoteConnectionState.connected &&
      widget.target.textInputSupported &&
      _session != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = widget.target.textSession;
    _sessions = widget.target.textSessions.listen((session) {
      if (!mounted || identical(session, _session)) return;
      _draft.clear();
      setState(() {
        _session = session;
        _message = session == null
            ? 'TV input is no longer available. Draft cleared.'
            : 'TV input changed. Draft cleared.';
      });
    });
    _connection = widget.target.connectionStates.listen((state) {
      if (!mounted) return;
      if (state == RemoteConnectionState.connected) {
        setState(() {});
        return;
      }
      _pause('Connection changed. Draft cleared.');
    });
  }

  void _pause(String message) {
    _draft.clear();
    _focus.unfocus();
    setState(() {
      _paused = true;
      _session = null;
      _message = message;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause('Keyboard paused. Draft cleared when you left the app.');
    }
  }

  void _send() {
    final session = _session;
    if (!_ready || session == null) {
      _pause('TV input changed. Select a text field on the TV and resume.');
      return;
    }
    if (widget.target.sendText(_draft.text, session)) {
      _draft.clear();
      setState(
        () => _message =
            'Text requested on ${widget.target.deviceName}. Check the TV.',
      );
    } else {
      _pause('Text was not sent. Select a text field on the TV and resume.');
    }
  }

  void _enter() {
    final session = _session;
    if (!_ready || session == null || !widget.target.sendTextEnter(session)) {
      _pause('Enter was not sent. Check the TV connection and input field.');
      return;
    }
    setState(
      () => _message = 'Enter requested on ${widget.target.deviceName}.',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessions?.cancel();
    _connection?.cancel();
    _focus.dispose();
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Phone keyboard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close keyboard',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Send to ${widget.target.deviceName}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Preview · select a text field on your TV first. Support varies by TV and app. Text is sent only when you choose Send.',
            ),
            if (!_ready) ...[
              const SizedBox(height: 12),
              Text(
                widget.target.connectionState != RemoteConnectionState.connected
                    ? 'Reconnect your TV before resuming keyboard input.'
                    : !widget.target.textInputSupported
                    ? 'Phone keyboard is unavailable through this TV connection.'
                    : 'Waiting for a TV input session. Select a search or text field on the TV.',
              ),
              if (_paused)
                TextButton(
                  onPressed:
                      widget.isCurrentTarget() &&
                          widget.target.textInputSupported
                      ? () {
                          setState(() {
                            _paused = false;
                            _session = widget.target.textSession;
                            _message = null;
                          });
                        }
                      : null,
                  child: const Text('Resume keyboard'),
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _draft,
              focusNode: _focus,
              enabled: _ready,
              autofocus: _ready,
              obscureText: !_showText,
              maxLines: _showText ? 3 : 1,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              textInputAction: TextInputAction.done,
              maxLength: AndroidTvTextInput.maxCodePoints,
              decoration: InputDecoration(
                labelText: 'Text to send',
                suffixIcon: _draft.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear draft',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _draft.clear();
                          setState(() {});
                        },
                      ),
                errorMaxLines: 3,
                errorText:
                    _draft.text.runes.length > AndroidTvTextInput.maxCodePoints
                    ? 'Use shorter text before sending.'
                    : _draft.text.contains('\u0000')
                    ? 'Remove the unsupported control character.'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            const Text(
              'Drafts are cleared when the TV input or connection changes.',
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show draft text'),
              value: _showText,
              onChanged: (value) => setState(() => _showText = value),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
                  _ready &&
                      _draft.text.isNotEmpty &&
                      !_draft.text.contains('\u0000') &&
                      _draft.text.runes.length <=
                          AndroidTvTextInput.maxCodePoints
                  ? _send
                  : null,
              icon: const Icon(Icons.send_outlined),
              label: Text(
                'Send to ${widget.target.deviceName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed:
                  _ready &&
                      _draft.text.isEmpty &&
                      widget.target.textEnterSupported
                  ? _enter
                  : null,
              child: const Text('Enter on TV'),
            ),
            if (_draft.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Send or clear your draft before pressing Enter on TV.',
                ),
              ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_message!)),
            ],
          ],
        ),
      ),
    ),
  );
}
