import 'package:flutter/material.dart';
import '../../remote/android_tv_remote_controller.dart';
import '../../remote/remote_controller.dart';
import '../tv_preferences.dart';

Future<void> showControlSetup(
  BuildContext context,
  AndroidTvRemoteController controller,
  TvPreferenceStore store,
) async {
  final initial = await store.load(controller.pairedDevice.serviceName);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ControlSetup(controller: controller, store: store, initial: initial),
  );
}

class _ControlSetup extends StatefulWidget {
  const _ControlSetup({
    required this.controller,
    required this.store,
    required this.initial,
  });
  final AndroidTvRemoteController controller;
  final TvPreferenceStore store;
  final TvPreferences initial;
  @override
  State<_ControlSetup> createState() => _ControlSetupState();
}

class _ControlSetupState extends State<_ControlSetup> {
  late final room = TextEditingController(text: widget.initial.room);
  late bool eyesUp = widget.initial.eyesUp,
      power = widget.initial.power,
      volume = widget.initial.volume;
  String? message;
  bool saving = false;
  @override
  void dispose() {
    room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Controls for ${widget.controller.deviceName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: room,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Room',
                hintText: 'Living room',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Eyes-up mode'),
              subtitle: const Text(
                'Larger directional surface. Favorites remain in Apps.',
              ),
              value: eyesUp,
              onChanged: (value) => setState(() => eyesUp = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use TV power control'),
              subtitle: const Text(
                'Turn this off if power does not work with your TV setup.',
              ),
              value: power,
              onChanged: (value) => setState(() => power = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use TV volume controls'),
              subtitle: const Text(
                'Turn this off if a different audio remote is required.',
              ),
              value: volume,
              onChanged: (value) => setState(() => volume = value),
            ),
            OutlinedButton(
              onPressed: widget.controller.supports(RemoteCommand.volumeDown)
                  ? () async {
                      await widget.controller.sendCommand(
                        RemoteCommand.volumeDown,
                      );
                      if (!context.mounted) return;
                      final worked = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Did the volume decrease?'),
                          content: const Text(
                            'Check the TV or audio system before choosing.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                      if (mounted && worked != null) {
                        setState(() {
                          volume = worked;
                          message = worked
                              ? 'Volume enabled based on your check.'
                              : 'Volume disabled for this TV.';
                        });
                      }
                    }
                  : null,
              child: const Text('Test volume down once'),
            ),
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        await widget.store.save(
                          widget.controller.pairedDevice.serviceName,
                          TvPreferences(
                            room: room.text.trim(),
                            eyesUp: eyesUp,
                            power: power,
                            volume: volume,
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            saving = false;
                            message = 'Could not save controls. Try again.';
                          });
                        }
                      }
                    },
              child: const Text('Save controls'),
            ),
            TextButton(
              onPressed: () => setState(() {
                room.clear();
                eyesUp = false;
                power = true;
                volume = true;
              }),
              child: const Text('Reset to defaults'),
            ),
          ],
        ),
      ),
    ),
  );
}
