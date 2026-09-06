import 'package:flutter_test/flutter_test.dart';
import 'package:whenrufree/models/lesson.dart';
import 'package:whenrufree/services/availability_service.dart';

const svc = AvailabilityService();

Lesson lesson(String s, int day, int sh, int sm, int eh, int em) =>
    Lesson.create(
        subject: s,
        weekday: day,
        startMin: sh * 60 + sm,
        endMin: eh * 60 + em);

void main() {
  group('freeIntervalsForDay', () {
    test('empty timetable = whole window free', () {
      final free = svc.freeIntervalsForDay(
          lessons: [], weekday: 1, windowStartMin: 480, windowEndMin: 1080);
      expect(free.length, 1);
      expect(free.first.startMin, 480);
      expect(free.first.endMin, 1080);
    });

    test('gaps around lessons', () {
      final free = svc.freeIntervalsForDay(
        lessons: [lesson('Maths', 1, 9, 0, 10, 0)],
        weekday: 1,
        windowStartMin: 480,
        windowEndMin: 1080,
      );
      expect(free.length, 2);
      expect(free[0].startMin, 480);
      expect(free[0].endMin, 540);
      expect(free[1].startMin, 600);
      expect(free[1].endMin, 1080);
    });

    test('overlapping lessons merge', () {
      final free = svc.freeIntervalsForDay(
        lessons: [
          lesson('A', 1, 9, 0, 10, 0),
          lesson('B', 1, 9, 30, 10, 30),
        ],
        weekday: 1,
        windowStartMin: 480,
        windowEndMin: 720,
      );
      expect(free.length, 2);
      expect(free[1].startMin, 630);
    });

    test('other weekdays ignored', () {
      final free = svc.freeIntervalsForDay(
        lessons: [lesson('PE', 2, 9, 0, 17, 0)],
        weekday: 1,
        windowStartMin: 480,
        windowEndMin: 1080,
      );
      expect(free.length, 1);
      expect(free.first.durationMin, 600);
    });
  });

  group('mutualFreeOnDay', () {
    test('intersection of two timetables', () {
      final mutual = svc.mutualFreeOnDay(
        timetables: {
          'You': [lesson('Maths', 1, 9, 0, 10, 0)],
          'Ava': [lesson('Bio', 1, 10, 0, 11, 0)],
        },
        weekday: 1,
        windowStartMin: 480,
        windowEndMin: 720,
        minDurationMin: 0,
      );
      // Free: You [8-9,10-12], Ava [8-10,11-12] => [8-9, 11-12]
      expect(mutual.length, 2);
      expect(mutual[0].startMin, 480);
      expect(mutual[0].endMin, 540);
      expect(mutual[1].startMin, 660);
    });

    test('min duration filters short gaps', () {
      final mutual = svc.mutualFreeOnDay(
        timetables: {
          'You': [lesson('Maths', 1, 9, 0, 10, 50)],
          'Ava': [lesson('Bio', 1, 9, 0, 11, 0)],
        },
        weekday: 1,
        windowStartMin: 540,
        windowEndMin: 660,
        minDurationMin: 30,
      );
      expect(mutual, isEmpty);
    });
  });

  group('whoIsFreeAt', () {
    test('busy boundary is end-exclusive', () {
      final who = svc.whoIsFreeAt(
        timetables: {
          'You': [lesson('Maths', 1, 9, 0, 10, 0)],
        },
        weekday: 1,
        timeMin: 600, // exactly 10:00 -> free
      );
      expect(who, contains('You'));
      final busy = svc.whoIsFreeAt(
        timetables: {
          'You': [lesson('Maths', 1, 9, 0, 10, 0)],
        },
        weekday: 1,
        timeMin: 599,
      );
      expect(busy, isEmpty);
    });
  });

  group('bestSlotsAcrossWeek', () {
    test('finds longest shared break first', () {
      final best = svc.bestSlotsAcrossWeek(
        timetables: {
          'You': [lesson('Maths', 1, 9, 0, 10, 0)],
          'Ava': [lesson('Bio', 2, 9, 0, 10, 0)],
        },
        weekdays: const [1, 2],
        windowStartMin: 480,
        windowEndMin: 720,
      );
      expect(best, isNotEmpty);
      // Whole free days (Mon 10-12 / Tue 10-12) should rank top.
      expect(best.first.durationMin, greaterThanOrEqualTo(120));
    });

    test('empty group returns empty', () {
      expect(
          svc.bestSlotsAcrossWeek(
            timetables: {},
            weekdays: const [1],
            windowStartMin: 480,
            windowEndMin: 1080,
          ),
          isEmpty);
    });
  });

  group('nextFreeToday', () {
    test('clips slot to fromMin', () {
      final next = svc.nextFreeToday(
        timetables: {
          'You': [lesson('Maths', 1, 9, 0, 10, 0)],
        },
        weekday: 1,
        fromMin: 500, // 08:20, inside 08:00-09:00 free block
        windowStartMin: 480,
        windowEndMin: 1080,
      );
      expect(next, isNotNull);
      expect(next!.startMin, 500);
      expect(next.endMin, 540);
    });

    test('null when nothing left', () {
      final next = svc.nextFreeToday(
        timetables: {
          'You': [lesson('All day', 1, 8, 0, 18, 0)],
        },
        weekday: 1,
        fromMin: 600,
        windowStartMin: 480,
        windowEndMin: 1080,
      );
      expect(next, isNull);
    });
  });
}
