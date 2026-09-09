import 'package:flutter_test/flutter_test.dart';
import 'package:whenrufree/models/friend.dart';
import 'package:whenrufree/models/lesson.dart';
import 'package:whenrufree/services/sample_data.dart';
import 'package:whenrufree/services/timetable_share.dart';

List<Lesson> sample() => [
      Lesson.create(
          subject: 'Maths', weekday: 1, startMin: 540, endMin: 600, location: 'M2'),
      Lesson.create(
          subject: 'English & Art', weekday: 3, startMin: 615, endMin: 675),
    ];

void main() {
  group('TimetableShare', () {
    test('encode/decode roundtrip', () {
      final code = TimetableShare.encode(
        displayName: 'Alex',
        friendCode: 'KQ7X2P',
        college: 'Hills Road',
        lessons: sample(),
      );
      expect(code.startsWith('WRF1-'), isTrue);

      final back = TimetableShare.decode(code);
      expect(back.displayName, 'Alex');
      expect(back.friendCode, 'KQ7X2P');
      expect(back.college, 'Hills Road');
      expect(back.lessons.length, 2);
      expect(back.lessons[0].subject, 'Maths');
      expect(back.lessons[0].weekday, 1);
      expect(back.lessons[0].startMin, 540);
      expect(back.lessons[0].location, 'M2');
    });

    test('tolerates whitespace/newlines from chat apps', () {
      final code = TimetableShare.encode(
          displayName: 'A',
          friendCode: 'AAAAAA',
          college: '',
          lessons: sample());
      final innerSpaced =
          '${code.substring(0, 30)}\n ${code.substring(30, 60)} ${code.substring(60)}';
      expect(TimetableShare.decode(innerSpaced).lessons.length, 2);
    });

    test('friendly errors for garbage', () {
      expect(() => TimetableShare.decode(''),
          throwsA(isA<FormatException>()));
      expect(() => TimetableShare.decode('hello world'),
          throwsA(isA<FormatException>()));
      expect(() => TimetableShare.decode('WRF1-!!!not-base64!!!'),
          throwsA(isA<FormatException>()));
    });
  });

  group('demo-data flag', () {
    test('sample friends are flagged, share imports are not', () {
      final demo = demoFriendForCode('KQ7X2P');
      expect(demo.demoData, isTrue);
      final payload = TimetableShare.decode(TimetableShare.encode(
          displayName: 'Real Mate',
          friendCode: 'KQ7X2P',
          college: '',
          lessons: sample()));
      // Applying a share payload clears the flag (see AppStore).
      final updated = demo.copyWith(
          displayName: payload.displayName,
          lessons: payload.lessons,
          demoData: false);
      expect(updated.demoData, isFalse);
      // Flag survives a save/load roundtrip.
      final back = Friend.fromJson(updated.toJson());
      expect(back.demoData, isFalse);
      expect(Friend.fromJson(demo.toJson()).demoData, isTrue);
    });
  });
}
