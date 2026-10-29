import 'dart:async';
import 'package:flutter/material.dart';
import '../../apps/app_shortcut_store.dart';
import '../../apps/tv_app.dart';
import '../../remote/android_tv_remote_controller.dart';
import '../../remote/remote_controller.dart';
import '../routines.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({
    required this.store,
    required this.shortcuts,
    required this.controller,
    required this.isCurrentTarget,
    required this.onChooseDevice,
    super.key,
  });
  final RoutineStore store;
  final AppShortcutStore shortcuts;
  final AndroidTvRemoteController? controller;
  final bool Function() isCurrentTarget;
  final VoidCallback onChooseDevice;
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<TvAudioRoutine> _routines = [];
  List<TvApp> _apps = [];
  HomeAssistantConfig? _config;
  RoutineCancellation? _cancel;
  StreamSubscription<RemoteConnectionState>? _connection;
  String? _message;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _connection = widget.controller?.connectionStates.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    final routines = await widget.store.load();
    final apps = await widget.shortcuts.loadShortcuts();
    final config = await widget.store.loadConfig();
    if (mounted) {
      setState(() {
        _routines = routines;
        _apps = apps;
        _config = config;
      });
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _connection?.cancel();
    super.dispose();
  }

  Future<void> _configure() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ConnectionDialog(store: widget.store, initial: _config),
    );
    await _load();
  }

  Future<void> _add() async {
    final tv = widget.controller;
    if (tv == null || _apps.isEmpty) {
      setState(() => _message = 'Choose a TV and add an app favorite first.');
      return;
    }
    final routine = await showDialog<TvAudioRoutine>(
      context: context,
      builder: (_) => _RoutineDialog(tv: tv, apps: _apps),
    );
    if (routine != null) {
      await widget.store.save(routine);
      await _load();
    }
  }

  Future<void> _run(TvAudioRoutine routine) async {
    final tv = widget.controller;
    final app = _apps.where((app) => app.id == routine.appId).firstOrNull;
    final config = _config;
    if (_busy ||
        tv == null ||
        app == null ||
        config == null ||
        !widget.isCurrentTarget() ||
        routine.tvId != tv.pairedDevice.serviceName) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Run ${routine.name}?'),
        content: Text(
          'Set ${routine.entity} to ${(routine.volume * 100).round()}%, then request ${app.name} on ${tv.deviceName}. Cancellation cannot undo a volume change already sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run routine'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final cancel = RoutineCancellation();
    setState(() {
      _cancel = cancel;
      _busy = true;
      _message = 'Applying audio preset…';
    });
    try {
      final result = await runTvAudioRoutine(
        routine: routine,
        app: app,
        audio: HomeAssistantClient(config),
        tv: tv,
        tvId: tv.pairedDevice.serviceName,
        isCurrentTarget: widget.isCurrentTarget,
        cancellation: cancel,
      );
      if (mounted) setState(() => _message = result.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cancel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('TV and audio routines'),
      actions: [
        IconButton(
          tooltip: 'Home Assistant connection',
          onPressed: _busy ? null : _configure,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Optional Home Assistant integration. Each routine confirms an audio volume preset before opening a TV favorite. No timed remote-key sequences.',
          ),
          const SizedBox(height: 12),
          Text(
            widget.controller == null
                ? 'Choose a TV to create or run a routine.'
                : 'TV: ${widget.controller!.deviceName}',
          ),
          if (_config == null)
            OutlinedButton(
              onPressed: _configure,
              child: const Text('Connect Home Assistant'),
            ),
          TextButton(
            onPressed: _busy ? null : widget.onChooseDevice,
            child: const Text('Choose TV'),
          ),
          for (final routine in _routines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(routine.name),
              subtitle: Text(
                '${routine.entity} · ${(routine.volume * 100).round()}%',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Run ${routine.name}',
                    onPressed:
                        !_busy &&
                            _config != null &&
                            widget.isCurrentTarget() &&
                            widget.controller?.pairedDevice.serviceName ==
                                routine.tvId &&
                            _apps.any((app) => app.id == routine.appId)
                        ? () => _run(routine)
                        : null,
                    icon: const Icon(Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: 'Delete ${routine.name}',
                    onPressed: _busy
                        ? null
                        : () async {
                            await widget.store.remove(routine.id);
                            await _load();
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          if (_routines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No routines yet. Create a preset for your TV and an audio entity.',
              ),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Create routine'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            TextButton(
              onPressed: () {
                _cancel?.cancel();
                setState(
                  () => _message =
                      'Cancelling. Previously sent audio changes may remain.',
                );
              },
              child: const Text('Cancel routine'),
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
        ],
      ),
    ),
  );
}

class _ConnectionDialog extends StatefulWidget {
  const _ConnectionDialog({required this.store, this.initial});
  final RoutineStore store;
  final HomeAssistantConfig? initial;
  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  late final url = TextEditingController(text: widget.initial?.base.toString());
  late final token = TextEditingController(text: widget.initial?.token);
  String? error;
  bool busy = false;
  @override
  void dispose() {
    url.dispose();
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Home Assistant connection'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Use your server URL and a long-lived access token. The token stays in secure storage and is sent only to this server. Remote connections require HTTPS.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://home.example.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: token,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'Access token'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!),
            ),
        ],
      ),
    ),
    actions: [
      if (widget.initial != null)
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  await widget.store.clearConfig();
                  if (context.mounted) Navigator.pop(context);
                },
          child: const Text('Disconnect'),
        ),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  final config = HomeAssistantConfig(url.text, token.text);
                  await HomeAssistantClient(config).testConnection();
                  await widget.store.saveConfig(config);
                  if (context.mounted) Navigator.pop(context);
                } on FormatException catch (failure) {
                  if (mounted) {
                    setState(() {
                      busy = false;
                      error = failure.message;
                    });
                  }
                } on RoutineFailure catch (failure) {
                  if (mounted) {
                    setState(() {
                      busy = false;
                      error = failure.message;
                    });
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      busy = false;
                      error = 'Could not save this connection.';
                    });
                  }
                }
              },
        child: Text(busy ? 'Checking…' : 'Test and save'),
      ),
    ],
  );
}

class _RoutineDialog extends StatefulWidget {
  const _RoutineDialog({required this.tv, required this.apps});
  final AndroidTvRemoteController tv;
  final List<TvApp> apps;
  @override
  State<_RoutineDialog> createState() => _RoutineDialogState();
}

class _RoutineDialogState extends State<_RoutineDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final entity = TextEditingController();
  late String appId = widget.apps.first.id;
  double volume = 0.2;
  @override
  void dispose() {
    name.dispose();
    entity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create TV and audio routine'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('TV: ${widget.tv.deviceName}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Routine name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a name.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: appId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'TV favorite'),
              items: [
                for (final app in widget.apps)
                  DropdownMenuItem(value: app.id, child: Text(app.name)),
              ],
              onChanged: (value) {
                if (value != null) appId = value;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: entity,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Audio entity',
                hintText: 'media_player.living_room',
              ),
              validator: (value) =>
                  RegExp(
                    r'^media_player\.[a-z0-9_]+$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a media_player entity ID.',
            ),
            const SizedBox(height: 16),
            Text('Audio volume ${(volume * 100).round()}%'),
            Slider(
              value: volume,
              min: 0,
              max: 1,
              divisions: 100,
              label: '${(volume * 100).round()}%',
              onChanged: (value) => setState(() => volume = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              TvAudioRoutine(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                tvId: widget.tv.pairedDevice.serviceName,
                appId: appId,
                entity: entity.text.trim(),
                volume: volume,
              ),
            );
          }
        },
        child: const Text('Save routine'),
      ),
    ],
  );
}
