import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromecast_remote/core/protocol/android_tv/text_input.dart';
import 'package:chromecast_remote/features/remote/presentation/tv_keyboard_sheet.dart';
import 'package:chromecast_remote/features/remote/remote_controller.dart';
import 'package:chromecast_remote/features/remote/tv_keyboard_target.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class KeyboardTarget implements TvKeyboardTarget {
  final input = AndroidTvTextInput();
  final states = StreamController<RemoteConnectionState>.broadcast(sync: true);
  final requests = <String>[];
  int enters = 0;
  bool supported = true;
  bool keySupported = true;
  @override
  bool get textEnterSupported => textInputSupported && keySupported;
  @override
  final deviceName = 'Living room';
  @override
  RemoteConnectionState connectionState = RemoteConnectionState.connected;
  @override
  Stream<RemoteConnectionState> get connectionStates => states.stream;
  @override
  bool get textInputSupported =>
      supported && connectionState == RemoteConnectionState.connected;
  @override
  AndroidTvTextSession? get textSession => input.session;
  @override
  Stream<AndroidTvTextSession?> get textSessions => input.changes;
  @override
  bool sendText(String text, AndroidTvTextSession token) {
    if (!textInputSupported || input.createRequest(text, token) == null) {
      return false;
    }
    requests.add(text);
    return true;
  }

  @override
  bool sendTextEnter(AndroidTvTextSession token) {
    if (!textInputSupported || !input.accepts(token)) return false;
    enters++;
    return true;
  }

  Future<void> dispose() async {
    await states.close();
    await input.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fonts = String.fromEnvironment('UPGRADE_FONT_DIR');
    if (fonts.isEmpty) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(
        family,
      )..addFont(File('$fonts/$file').readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  Future<void> pump(
    WidgetTester tester,
    KeyboardTarget target, {
    bool Function()? current,
    double scale = 1,
    Size size = const Size(360, 800),
    double inset = 0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: inset),
          ),
          child: RepaintBoundary(
            key: const ValueKey('keyboard-capture'),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: TvKeyboardSheet(
                target: target,
                isCurrentTarget: current ?? () => true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  late KeyboardTarget target;
  setUp(() => target = KeyboardTarget());
  tearDown(() => target.dispose());

  testWidgets(
    'waits for reported input and never sends while typing or pressing Done',
    (tester) async {
      await pump(tester, target);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      target.input.updateCounters(7, 9);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'search term');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(target.requests, isEmpty);
      expect(target.enters, 0);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(target.requests, ['search term']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        find.text('Text requested on Living room. Check the TV.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'draft is obscured by default and is discarded when the TV field changes',
    (tester) async {
      target.input.updateCounters(1, 2);
      await pump(tester, target);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'private draft');
      target.input.updateCounters(1, 3);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(target.requests, isEmpty);
      expect(find.text('TV input changed. Draft cleared.'), findsOneWidget);
    },
  );

  testWidgets(
    'connection changes clear the draft and require explicit resumption',
    (tester) async {
      target.input.updateCounters(1, 2);
      await pump(tester, target);
      await tester.enterText(find.byType(TextField), 'old connection');
      target.connectionState = RemoteConnectionState.disconnected;
      target.states.add(target.connectionState);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      target.connectionState = RemoteConnectionState.connected;
      target.states.add(target.connectionState);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.text('Resume keyboard'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(target.requests, isEmpty);
    },
  );

  testWidgets('Enter stays unavailable when key commands are unsupported', (
    tester,
  ) async {
    target.input.updateCounters(1, 2);
    target.keySupported = false;
    await pump(tester, target);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(target.enters, 0);
  });

  testWidgets(
    'backgrounding clears the draft instead of retaining sensitive input',
    (tester) async {
      target.input.updateCounters(1, 2);
      await pump(tester, target);
      await tester.enterText(find.byType(TextField), 'sensitive');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(target.requests, isEmpty);
    },
  );

  testWidgets(
    'a changed target is checked again at the moment Send is tapped',
    (tester) async {
      var current = true;
      target.input.updateCounters(1, 2);
      await pump(tester, target, current: () => current);
      await tester.enterText(find.byType(TextField), 'wrong room');
      await tester.pump();
      current = false;
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(target.requests, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'large text composer scrolls without overflow and Enter is separate',
    (tester) async {
      target.input.updateCounters(1, 2);
      await pump(tester, target, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Enter on TV'));
      await tester.tap(find.text('Enter on TV'));
      await tester.pumpAndSettle();
      expect(target.enters, 1);
      expect(target.requests, isEmpty);
    },
  );
  for (final (size, scale, inset) in [
    (const Size(360, 640), 1.0, 260.0),
    (const Size(360, 800), 2.0, 280.0),
  ]) {
    testWidgets(
      'keyboard-visible composer stays usable at $size and text scale $scale',
      (tester) async {
        target.input.updateCounters(1, 2);
        await pump(tester, target, size: size, scale: scale, inset: inset);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), 'Café 😀');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.byType(FilledButton)).dy,
          lessThan(size.height - inset),
        );
        const captures = String.fromEnvironment('UPGRADE_SCREENSHOTS');
        if (captures.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('keyboard-capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(captures).create(recursive: true);
            await File(
              '$captures/keyboard-${size.height.toInt()}-${scale.toInt()}x.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(target.requests, ['Café 😀']);
        expect(target.enters, 0);
      },
    );
  }
}
