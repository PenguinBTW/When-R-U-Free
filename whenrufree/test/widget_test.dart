import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whenrufree/data/app_store.dart';
import 'package:whenrufree/ui/app.dart';

void main() {
  testWidgets('App boots to onboarding when fresh', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const WhenRUFApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('When R U Free'), findsWidgets);
    expect(find.text('Your first name'), findsOneWidget);
  });

  testWidgets('Onboarding completes and shows nav shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const WhenRUFApp()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Bottom nav destinations visible.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(store.onboarded, isTrue);
  });
}
