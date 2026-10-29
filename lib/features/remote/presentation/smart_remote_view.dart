import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../smart_now_playing.dart';
import 'cast_remote_screen.dart';

/// Switches the Remote pane only. Apps and Devices keep their navigation state.
/// A manual override lasts for this media session and never stops playback.
class SmartRemoteView extends StatefulWidget {
  const SmartRemoteView({
    required this.playback,
    required this.remoteBuilder,
    this.castBuilder,
    this.active = true,
    super.key,
  });
  final ValueListenable<CastPlaybackSnapshot> playback;
  final Widget Function(BuildContext context, bool controlsActive)
  remoteBuilder;
  final Widget Function(BuildContext context, CastPlaybackSnapshot playback)?
  castBuilder;
  final bool active;
  @override
  State<SmartRemoteView> createState() => _SmartRemoteViewState();
}

class _SmartRemoteViewState extends State<SmartRemoteView> {
  String? _manualFor;
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<CastPlaybackSnapshot>(
    valueListenable: widget.playback,
    builder: (context, playback, _) {
      final available = playback.available;
      final nowPlaying = available && _manualFor != playback.identity;
      return Column(
        children: [
          if (available)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.cast_connected, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cast · ${playback.session!.device!.friendlyName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _manualFor = nowPlaying ? playback.identity : null,
                    ),
                    child: Text(nowPlaying ? 'TV remote' : 'Now playing'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: nowPlaying ? 1 : 0,
              children: [
                widget.remoteBuilder(context, widget.active && !nowPlaying),
                if (nowPlaying)
                  widget.castBuilder?.call(context, playback) ??
                      CastRemoteScreen(
                        key: ValueKey(playback.session!.device!.deviceID),
                        device: playback.session!.device!,
                        embedded: true,
                        active: widget.active,
                        nowPlaying: true,
                      )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      );
    },
  );
}
