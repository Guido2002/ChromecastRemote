import 'package:chromecast_remote/shared/presentation/app_motion.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
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
  });

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
