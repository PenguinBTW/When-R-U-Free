import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whenrufree/data/app_store.dart';
import 'package:whenrufree/ui/app.dart';

Future<AppStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore();
  await store.load();
  return store;
}

Future<void> pumpApp(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: store, child: const WhenRUFApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Fresh launch shows mode choice with Sync recommended',
      (tester) async {
    final store = await freshStore();
    await pumpApp(tester, store);

    expect(find.text('When R U Free'), findsWidgets);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('Choose Sync'), findsOneWidget);
    expect(find.text('Choose Offline'), findsOneWidget);
  });

  testWidgets('Offline choice leads to onboarding then nav shell',
      (tester) async {
    final store = await freshStore();
    await pumpApp(tester, store);

    await tester.scrollUntilVisible(find.text('Choose Offline'), 200);
    await tester.tap(find.text('Choose Offline'));
    await tester.pumpAndSettle();

    expect(find.text('Your first name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(store.onboarded, isTrue);
    expect(store.appMode, AppMode.offline);
  });

  testWidgets('Sync choice opens coming-soon sheet with offline route',
      (tester) async {
    final store = await freshStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('Choose Sync'));
    await tester.pumpAndSettle();

    expect(find.text('Sync is almost here'), findsOneWidget);
    expect(find.text('Calendar auto-sync — ready now'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Continue offline for now'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('syncSheetScroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Continue offline for now'));
    await tester.pumpAndSettle();

    expect(store.appMode, AppMode.offline);
    expect(find.text('Your first name'), findsOneWidget);
  });
}
