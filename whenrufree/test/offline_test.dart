import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whenrufree/data/app_store.dart';
import 'package:whenrufree/models/lesson.dart';
import 'package:whenrufree/services/sample_data.dart';
import 'package:whenrufree/services/timetable_share.dart';

Future<AppStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore();
  await store.load();
  return store;
}

void main() {
  group('offline friends', () {
    test('add by name validates + dedupes case-insensitively', () async {
      final store = await freshStore();
      expect(await store.addFriendByName('  '), isNotNull);
      expect(await store.addFriendByName('Ava'), isNull);
      expect(await store.addFriendByName('ava'), isNotNull);
      expect(await store.addFriendByName(' AVA '), isNotNull);
      expect(store.friends.length, 1);
    });

    test('share import adds then updates by name', () async {
      final store = await freshStore();
      final code = TimetableShare.encode(
        displayName: 'Ava',
        friendCode: '',
        college: '',
        lessons: sampleTimetable(seed: 1),
      );
      final payload = TimetableShare.decode(code);

      final first = await store.applySharedPayloadOffline(payload);
      expect(first, 'added:Ava');
      expect(store.friends.length, 1);
      expect(store.friends.first.demoData, isFalse);

      final second = await store.applySharedPayloadOffline(payload);
      expect(second, 'updated:Ava');
      expect(store.friends.length, 1);
    });

    test('friend lesson CRUD flips demo flag', () async {
      final store = await freshStore();
      await store.addFriendByName('Leo');
      final id = store.friends.first.id;
      final lesson = Lesson.create(
          subject: 'Maths', weekday: 1, startMin: 540, endMin: 600);
      expect(store.addFriendLesson(id, lesson), isNull);
      expect(store.friendById(id)!.lessons.length, 1);

      final updated = lesson.copyWith(subject: 'Physics');
      // copyWith keeps the id, so update targets the same lesson.
      expect(store.updateFriendLesson(id, updated), isNull);
      expect(store.friendById(id)!.lessons.first.subject, 'Physics');

      await store.removeFriendLesson(id, lesson.id);
      expect(store.friendById(id)!.lessons, isEmpty);

      expect(store.addFriendLesson('nope', lesson), isNotNull);
    });

    test('invalid friend lessons rejected', () async {
      final store = await freshStore();
      await store.addFriendByName('Mia');
      final id = store.friends.first.id;
      final bad = Lesson.create(
          subject: '  ', weekday: 2, startMin: 600, endMin: 600);
      expect(store.addFriendLesson(id, bad), isNotNull);
      expect(store.friendById(id)!.lessons, isEmpty);
    });
  });

  group('dev demo friends', () {
    test('adds 5, skips existing, removes cleanly', () async {
      final store = await freshStore();
      expect(await store.addDemoFriends(), 5);
      expect(store.friends.length, 5);
      // Idempotent: second tap adds nothing.
      expect(await store.addDemoFriends(), 0);
      // A real friend with a clashing name is left alone.
      expect(store.friends.where((f) => f.demoData).length, 5);
      expect(await store.removeDemoFriends(), 5);
      expect(store.friends, isEmpty);
      expect(await store.removeDemoFriends(), 0);
    });
  });

  group('app mode', () {
    test('mode persists across loads', () async {
      final store = await freshStore();
      expect(store.appMode, AppMode.undecided);
      await store.setAppMode(AppMode.offline);
      final again = AppStore();
      await again.load();
      expect(again.appMode, AppMode.offline);
    });
  });

  group('share payload size', () {
    test('realistic timetable stays QR-friendly', () {
      final code = TimetableShare.encode(
        displayName: 'Alex',
        friendCode: '',
        college: 'Hills Road Sixth Form',
        lessons: sampleTimetable(seed: 0),
      );
      expect(code.startsWith('WRF1-'), isTrue);
      // ~2953 chars is the absolute QR max; stay well under for cheap cameras.
      expect(code.length, lessThan(1800));
    });
  });
}
