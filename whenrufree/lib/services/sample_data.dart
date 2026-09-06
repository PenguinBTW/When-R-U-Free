import '../models/friend.dart';
import '../models/lesson.dart';
import '../models/user_profile.dart';

int _m(int h, int min) => h * 60 + min;

/// Deterministic sample timetable so first-run users (and demo friends)
/// immediately see something useful.
List<Lesson> sampleTimetable({int seed = 0}) {
  Lesson l(String subject, int day, int sh, int sm, int eh, int em,
      [String loc = '']) {
    return Lesson.create(
      subject: subject,
      weekday: day,
      startMin: _m(sh, sm),
      endMin: _m(eh, em),
      location: loc,
    );
  }

  final variants = <List<Lesson>>[
    [
      l('Maths', 1, 9, 0, 10, 0, 'M2'),
      l('English', 1, 10, 15, 11, 15, 'E4'),
      l('Physics', 1, 13, 0, 14, 30, 'Lab 1'),
      l('Maths', 2, 9, 0, 10, 30, 'M2'),
      l('History', 2, 11, 0, 12, 0, 'H1'),
      l('Free period', 2, 13, 30, 14, 30, 'Library'),
      l('Chemistry', 3, 9, 0, 10, 0, 'Lab 2'),
      l('Maths', 3, 10, 15, 11, 15, 'M2'),
      l('PE', 3, 14, 0, 15, 0, 'Sports hall'),
      l('English', 4, 9, 30, 10, 30, 'E4'),
      l('Physics', 4, 11, 0, 12, 30, 'Lab 1'),
      l('Maths', 5, 9, 0, 10, 0, 'M2'),
      l('History', 5, 10, 15, 11, 15, 'H1'),
    ],
    [
      l('Biology', 1, 9, 0, 10, 30, 'Lab 3'),
      l('Maths', 1, 11, 0, 12, 0, 'M1'),
      l('Art', 1, 13, 30, 15, 0, 'Art block'),
      l('English', 2, 9, 0, 10, 0, 'E2'),
      l('Biology', 2, 10, 15, 11, 45, 'Lab 3'),
      l('Psychology', 3, 9, 30, 10, 30, 'P1'),
      l('Maths', 3, 11, 0, 12, 0, 'M1'),
      l('Biology', 4, 9, 0, 10, 30, 'Lab 3'),
      l('Sociology', 4, 13, 0, 14, 0, 'S2'),
      l('English', 5, 10, 0, 11, 0, 'E2'),
      l('Biology', 5, 11, 30, 12, 30, 'Lab 3'),
    ],
    [
      l('Computer Science', 1, 10, 0, 11, 30, 'IT2'),
      l('Maths', 1, 13, 0, 14, 0, 'M3'),
      l('Business', 2, 9, 30, 10, 30, 'B1'),
      l('Computer Science', 2, 11, 0, 12, 30, 'IT2'),
      l('English', 3, 9, 0, 10, 0, 'E1'),
      l('Business', 3, 13, 30, 14, 30, 'B1'),
      l('Computer Science', 4, 9, 0, 10, 0, 'IT2'),
      l('Maths', 4, 10, 30, 11, 30, 'M3'),
      l('EPQ', 5, 9, 0, 10, 0, 'Library'),
      l('Computer Science', 5, 13, 0, 14, 30, 'IT2'),
    ],
  ];
  return variants[seed % variants.length];
}

const _demoNames = ['Ava', 'Liam', 'Mia', 'Noah', 'Isla', 'Leo'];

/// Builds a demo friend from a 6-char code so every code yields a stable,
/// distinct timetable (local stand-in until the cloud lookup is enabled).
Friend demoFriendForCode(String code, {int nameSalt = 0}) {
  final c = code.trim().toUpperCase();
  var hash = nameSalt;
  for (final unit in c.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final name = _demoNames[hash % _demoNames.length];
  return Friend(
    id: 'demo-$c',
    displayName: '$name (${c.substring(0, 3)})',
    friendCode: c,
    lessons: sampleTimetable(seed: hash % 3),
  );
}

List<Friend> starterFriends() => [
      Friend(
          id: 'demo-AVA111',
          displayName: 'Ava',
          friendCode: 'AVA111',
          lessons: sampleTimetable(seed: 1)),
      Friend(
          id: 'demo-LEO222',
          displayName: 'Leo',
          friendCode: 'LEO222',
          lessons: sampleTimetable(seed: 2)),
    ];

UserProfile starterProfile() =>
    UserProfile.fresh().copyWith(displayName: '');
