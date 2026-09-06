import 'package:flutter_test/flutter_test.dart';
import 'package:whenrufree/models/busy_block.dart';
import 'package:whenrufree/models/lesson.dart';
import 'package:whenrufree/services/availability_service.dart';

const svc = AvailabilityService();

Lesson lesson(String s, int day, int sh, int sm, int eh, int em) =>
    Lesson.create(
        subject: s,
        weekday: day,
        startMin: sh * 60 + sm,
        endMin: eh * 60 + em);

DateTime monday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - 1));
}

void main() {
  group('busy overrides', () {
    test('busy block carves a gap', () {
      final mon = monday();
      final free = svc.freeIntervalsForDate(
        lessons: [],
        busy: [
          BusyBlock.create(
              title: 'Dentist', date: mon, startMin: 750, endMin: 810),
        ],
        date: mon,
        windowStartMin: 480,
        windowEndMin: 1080,
      );
      expect(free.length, 2);
      expect(free[0].endMin, 750);
      expect(free[1].startMin, 810);
    });

    test('busy on another date is ignored', () {
      final mon = monday();
      final tue = mon.add(const Duration(days: 1));
      final free = svc.freeIntervalsForDate(
        lessons: [],
        busy: [
          BusyBlock.create(
              title: 'X', date: tue, startMin: 480, endMin: 1080),
        ],
        date: mon,
        windowStartMin: 480,
        windowEndMin: 1080,
      );
      expect(free.length, 1);
      expect(free.first.durationMin, 600);
    });

    test('mutual free on date honours both timetables and busy', () {
      final mon = monday();
      final mutual = svc.mutualFreeOnDate(
        people: [
          (
            name: 'You',
            lessons: [lesson('Maths', 1, 9, 0, 10, 0)],
            busy: <BusyBlock>[],
          ),
          (
            name: 'Ava',
            lessons: <Lesson>[],
            busy: [
              BusyBlock.create(
                  title: 'Busy', date: mon, startMin: 660, endMin: 720),
            ],
          ),
        ],
        date: mon,
        windowStartMin: 480,
        windowEndMin: 720,
        minDurationMin: 0,
      );
      // You free [8-9,10-12]; Ava free [8-11] => [8-9, 10-11]
      expect(mutual.length, 2);
      expect(mutual[0].startMin, 480);
      expect(mutual[0].endMin, 540);
      expect(mutual[1].startMin, 600);
      expect(mutual[1].endMin, 660);
    });

    test('whoIsFreeAtDate respects busy blocks', () {
      final mon = monday();
      final people = [
        (
          name: 'You',
          lessons: <Lesson>[],
          busy: [
            BusyBlock.create(
                title: 'X', date: mon, startMin: 700, endMin: 760),
          ],
        ),
      ];
      expect(
          svc.whoIsFreeAtDate(people: people, date: mon, timeMin: 720),
          isEmpty);
      expect(
          svc.whoIsFreeAtDate(people: people, date: mon, timeMin: 760),
          contains('You'));
    });
  });

  group('upcomingSharedGaps', () {
    test('lists gaps earliest-first across days', () {
      final now = DateTime.now();
      final gaps = svc.upcomingSharedGaps(
        people: [
          (name: 'You', lessons: <Lesson>[], busy: <BusyBlock>[]),
          (name: 'Ava', lessons: <Lesson>[], busy: <BusyBlock>[]),
        ],
        from: DateTime(now.year, now.month, now.day, 7, 0),
        days: 2,
        windowStartMin: 480,
        windowEndMin: 600,
        maxResults: 5,
      );
      expect(gaps.length, 2);
      expect(gaps[0].date.isBefore(gaps[1].date), isTrue);
      expect(gaps[0].slot.whoFree, containsAll(['You', 'Ava']));
    });

    test('clips first-day slots already in the past', () {
      final now = DateTime.now();
      final gaps = svc.upcomingSharedGaps(
        people: [
          (name: 'You', lessons: <Lesson>[], busy: <BusyBlock>[]),
          (name: 'Ava', lessons: <Lesson>[], busy: <BusyBlock>[]),
        ],
        from: DateTime(now.year, now.month, now.day, 9, 0),
        days: 1,
        windowStartMin: 480,
        windowEndMin: 600,
        minDurationMin: 15,
      );
      expect(gaps.length, 1);
      expect(gaps.first.slot.startMin, 540);
    });

    test('needs at least two people', () {
      expect(
          svc.upcomingSharedGaps(
            people: [
              (name: 'You', lessons: <Lesson>[], busy: <BusyBlock>[])
            ],
            from: DateTime.now(),
            windowStartMin: 480,
            windowEndMin: 1080,
          ),
          isEmpty);
    });
  });

  group('BusyBlock model', () {
    test('json roundtrip + key format', () {
      final b = BusyBlock.create(
          title: 'Shift', date: DateTime(2026, 9, 7), startMin: 600, endMin: 660);
      expect(b.dateKey, '2026-09-07');
      final back = BusyBlock.fromJson(b.toJson());
      expect(back.title, 'Shift');
      expect(back.dateKey, '2026-09-07');
      expect(back.startMin, 600);
      expect(BusyBlock.validate(startMin: 660, endMin: 660), isNotNull);
      expect(BusyBlock.validate(startMin: 600, endMin: 660), isNull);
    });
  });
}
