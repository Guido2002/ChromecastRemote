import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chromecast_remote/features/remote/presentation/widgets/voice_search_button.dart';
import 'support/fake_voice.dart';

void main() {
  testWidgets(
    'hold records, release ends, and app background discards the pending tail',
    (tester) async {
      final mic = FakeMicrophone();
      final tv = FakeVoiceTv();
      final status = ValueNotifier<String?>(null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VoiceSearchButton(
                  target: tv,
                  active: true,
                  microphone: mic,
                  onStatusChanged: (s) => status.value = s,
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: status,
                  builder: (_, text, _) => Text(text ?? 'Ready'),
                ),
              ],
            ),
          ),
        ),
      );
      final button = find.byType(IconButton);
      final held = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump();
      expect(mic.starts, 1);
      expect(find.textContaining('Listening · release'), findsOneWidget);
      mic.audio.add(Uint8List(500));
      await held.up();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(tv.sent.single.length, 500);
      expect(tv.ends, 1);
      expect(find.textContaining('Check the result'), findsOneWidget);
      final next = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump();
      mic.audio.add(Uint8List(400));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(tv.sent.length, 1);
      await next.up();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      status.dispose();
      await tv.states.close();
    },
  );
  testWidgets(
    'release during permission prompt cannot open the mic after permission returns',
    (tester) async {
      final mic = FakeMicrophone()..permission = Completer<bool>();
      final tv = FakeVoiceTv();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceSearchButton(target: tv, active: true, microphone: mic),
          ),
        ),
      );
      final press = await tester.startGesture(
        tester.getCenter(find.byType(IconButton)),
      );
      await tester.pump();
      await press.up();
      await tester.pump();
      mic.permission!.complete(true);
      await tester.pump();
      await tester.pump();
      expect(mic.starts, 0);
      expect(tv.starts, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tv.states.close();
    },
  );
}
