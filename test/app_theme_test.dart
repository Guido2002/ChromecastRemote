import 'package:chromecast_remote/shared/presentation/app_motion.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme defines a distinct, semantic dark surface hierarchy', () {
    final theme = buildAppTheme();

    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.secondary, AppColors.secondary);
    expect(
      theme.colorScheme.surfaceContainerLow,
      isNot(theme.scaffoldBackgroundColor),
    );
    expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerLow);
    expect(theme.colorScheme.primary, const Color(0xFF2388FF));
  });

  test(
    'the branded launcher artwork is bundled for the Flutter splash',
    () async {
      final data = await rootBundle.load('assets/branding/app_icon.png');
      expect(data.lengthInBytes, greaterThan(0));
    },
  );

  testWidgets('entrance motion becomes instant when reduced motion is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MotionEntrance(
            key: ValueKey('entrance'),
            child: Text('Ready'),
          ),
        ),
      ),
    );

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(const ValueKey('entrance')),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 1);
    expect(find.text('Ready'), findsOneWidget);
  });
}
