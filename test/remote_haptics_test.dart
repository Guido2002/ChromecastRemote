import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/shared/presentation/remote_haptics.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:chromecast_remote/features/remote/presentation/widgets/directional_pad.dart';
import 'package:chromecast_remote/features/settings/presentation/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  late RemoteHaptics original;
  setUp(() {
    original = RemoteHaptics.instance;
    RemoteHaptics.instance = RemoteHaptics(InMemorySecureStore());
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        });
  });
  tearDown(() {
    RemoteHaptics.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  test(
    'preference persists, off suppresses pulses, restore does not vibrate',
    () async {
      final store = InMemorySecureStore();
      final haptics = RemoteHaptics(store);
      await haptics.setEnabled(false);
      await haptics.press();
      expect(calls, isEmpty);
      final restored = RemoteHaptics(store);
      await restored.load();
      expect(restored.enabled, isFalse);
      expect(calls, isEmpty);
      await restored.setEnabled(true);
      expect(calls, ['HapticFeedbackType.lightImpact']);
    },
  );
  testWidgets(
    'D-pad taps and holds each produce one pulse, disabled controls produce none',
    (tester) async {
      var commands = 0;
      Widget pad(bool enabled) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DirectionalPad(
                enabled: enabled,
                onDirection: (_) => commands++,
                onSelect: () => commands++,
                onDirectionLongPressStart: (_) => commands++,
                onDirectionLongPressEnd: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(pad(true));
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(commands, 1);
      expect(calls.length, 1);
      calls.clear();
      final bounds = tester.getRect(find.byType(DirectionalPad));
      final press = await tester.startGesture(
        Offset(bounds.center.dx, bounds.top + 25),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await press.up();
      await tester.pump();
      expect(calls.length, 1);
      expect(commands, 2);
      calls.clear();
      await RemoteHaptics.instance.setEnabled(false);
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(commands, 3);
      expect(calls, isEmpty);
      await tester.pumpWidget(pad(false));
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(commands, 3);
      expect(calls, isEmpty);
    },
  );
  testWidgets('tooltip holds do not bypass disabled haptics', (tester) async {
    await RemoteHaptics.instance.setEnabled(false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: IconButton(
            tooltip: 'Remote power',
            enableFeedback: false,
            onPressed: () => RemoteHaptics.instance.press(),
            icon: const Icon(Icons.power_settings_new),
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Remote power'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Settings exposes the haptic preference', (tester) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'appName': 'Remote',
        'packageName': 'remote',
        'version': '0.11.0',
        'buildNumber': '13',
      },
    );
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Haptic feedback'), findsOneWidget);
    await tester.tap(find.text('Haptic feedback'));
    await tester.pumpAndSettle();
    expect(RemoteHaptics.instance.enabled, isFalse);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });
}
