import 'package:chromecast_remote/features/remote/presentation/widgets/directional_pad.dart';
import 'package:chromecast_remote/shared/presentation/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches to tablet layout at the shared breakpoint', (
    tester,
  ) async {
    Future<void> pumpAt(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: Builder(
              builder: (context) =>
                  Text(AdaptiveLayout.isTablet(context) ? 'tablet' : 'phone'),
            ),
          ),
        ),
      );
    }

    await pumpAt(699);
    expect(find.text('phone'), findsOneWidget);

    await pumpAt(700);
    expect(find.text('tablet'), findsOneWidget);
  });

  testWidgets('tablet content stays within its reachable maximum width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContent(
            child: ColoredBox(
              key: ValueKey('content'),
              color: Colors.red,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 1180);
  });

  testWidgets(
    'direction pad accepts a larger tablet target without stretching',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: DirectionalPad(
                key: const ValueKey('pad'),
                enabled: true,
                maxDiameter: 370,
                onDirection: (_) {},
                onSelect: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('pad'))),
        const Size(370, 370),
      );
      expect(find.text('OK'), findsOneWidget);
    },
  );

  testWidgets('minimum-width tablet control columns do not overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: AdaptiveContent(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TabletPanel(
                      child: DirectionalPad(
                        enabled: true,
                        maxDiameter: 370,
                        onDirection: (_) {},
                        onSelect: () {},
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Expanded(
                    flex: 6,
                    child: TabletPanel(child: SizedBox(height: 520)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
