import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whenrufree/data/app_store.dart';
import 'package:whenrufree/models/busy_block.dart';
import 'package:whenrufree/models/free_slot.dart';
import 'package:whenrufree/ui/app.dart';
import 'package:whenrufree/ui/widgets/busy_sheet.dart';
import 'package:whenrufree/ui/widgets/detail_sheets.dart';
import 'package:whenrufree/ui/widgets/friend_detail_sheet.dart';
import 'package:whenrufree/ui/widgets/share_sheet.dart';

/// Regression: with a full group (me + 5 demo friends) no screen or sheet
/// may overflow. Every step asserts the framework recorded no error.
Future<AppStore> demoStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore();
  await store.load();
  await store.setAppMode(AppMode.offline);
  await store.completeOnboarding('Me');
  await store.loadSampleTimetable();
  expect(await store.addDemoFriends(), 5);
  return store;
}

Future<void> pumpApp(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: store, child: const WhenRUFApp()),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('5 friends: main tabs render without overflow',
      (tester) async {
    final store = await demoStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('5 friends: every bottom sheet opens + scrolls cleanly',
      (tester) async {
    final store = await demoStore();
    await pumpApp(tester, store);
    final ctx =
        tester.element(find.byType(Scaffold).first);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const people = ['Me', 'Jess', 'Tim', 'Ava', 'Leo', 'Mia'];

    Future<void> openAndClose(Future<void> Function() open) async {
      // NOTE: don't await the sheet future — it only completes on pop.
      unawaited(open());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Exercise the sheet's scrollable (best-effort drag; layout errors
      // surface via takeException regardless).
      final sheetScroll = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      if (sheetScroll.evaluate().isNotEmpty) {
        await tester.drag(sheetScroll.first, const Offset(0, -400),
            warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
    }

    // Slot detail with the whole group + both action buttons.
    await openAndClose(() => showSlotDetail(
          ctx,
          const FreeSlot(
              weekday: 3, startMin: 705, endMin: 870, whoFree: people),
          people,
          date: today,
          onMarkBusy: (_) async => null,
        ));

    // Friend detail with a full 13-lesson timetable.
    final jess = store.friends.firstWhere((f) => f.displayName == 'Jess');
    await openAndClose(() => openFriendDetail(ctx, jess.id));

    // Share sheet (QR) + import sheet.
    await openAndClose(() => showShareTimetable(ctx, store));
    await openAndClose(() => showImportSharedCode(ctx, store));

    // Busy sheet with several overrides listed.
    store.addBusyBlock(BusyBlock.create(
        title: 'Dentist', date: today, startMin: 750, endMin: 810));
    store.addBusyBlock(BusyBlock.create(
        title: 'Shift',
        date: today.add(const Duration(days: 1)),
        startMin: 600,
        endMin: 900));
    await tester.pumpAndSettle();
    await openAndClose(() => openBusyBlocks(ctx, date: today));
  });
}
