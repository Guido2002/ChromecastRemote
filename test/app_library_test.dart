import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/app_shortcut_store.dart';
import 'package:chromecast_remote/features/apps/presentation/app_library_view.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app library searches and persists remote favorites', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppShortcutStore(store: InMemorySecureStore());
    var chooseDeviceCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AppLibraryView(
            store: store,
            onChooseDevice: () => chooseDeviceCalls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Disney');
    await tester.pump();
    expect(find.text('Disney+'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);

    final disneyTile = find.ancestor(
      of: find.text('Disney+'),
      matching: find.byType(ListTile),
    );
    final favoriteButton = find.ancestor(
      of: find.descendant(
        of: disneyTile,
        matching: find.byIcon(Icons.star_border_rounded),
      ),
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(favoriteButton).onPressed!();
    await tester.pumpAndSettle();
    expect(await store.loadSelectedIds(), contains('disney-plus'));

    final chooseButton = find.ancestor(
      of: find.text('Choose TV'),
      matching: find.byType(TextButton),
    );
    tester.widget<TextButton>(chooseButton).onPressed!();
    expect(chooseDeviceCalls, 1);
  });
}
