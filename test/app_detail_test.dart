import 'package:chromecast_remote/core/storage/secure_store.dart';
import 'package:chromecast_remote/features/apps/app_shortcut_store.dart';
import 'package:chromecast_remote/features/apps/presentation/app_detail_screen.dart';
import 'package:chromecast_remote/features/apps/tv_app.dart';
import 'package:chromecast_remote/shared/presentation/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app details expose launch information and persist favorites', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = AppShortcutStore(store: InMemorySecureStore());
    final netflix = catalogApps.singleWhere((app) => app.id == 'netflix');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppDetailScreen(
          app: netflix,
          store: store,
          connectedDeviceName: 'Living Room TV',
          onLaunchApp: (_) async => true,
          onChooseDevice: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Direct app link'), findsOneWidget);
    expect(find.text('com.netflix.ninja'), findsOneWidget);
    expect(find.text('Open on Living Room TV'), findsOneWidget);

    await tester.tap(find.text('Remove from remote shortcuts'));
    await tester.pumpAndSettle();
    expect(await store.loadSelectedIds(), isNot(contains('netflix')));
    expect(find.text('Add to remote shortcuts'), findsOneWidget);
  });
}
