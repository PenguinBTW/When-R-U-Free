import 'dart:math';

import '../models/busy_block.dart';
import '../models/free_slot.dart';
import '../models/lesson.dart';

/// One participant in a date-aware comparison: recurring lessons plus
/// one-off busy overrides.
typedef ParticipantTimetable = ({
  String name,
  List<Lesson> lessons,
  List<BusyBlock> busy,
});

/// A shared gap pinned to a concrete date (for notifications/agenda).
typedef DatedSlot = ({DateTime date, FreeSlot slot});

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Pure, testable timetable-comparison logic.
///
/// A "free" interval is any gap inside [windowStartMin, windowEndMin] that is
/// not covered by a lesson. Mutual availability is the intersection of every
/// participant's free intervals.
class AvailabilityService {
  const AvailabilityService();

  /// Free intervals for one person on one weekday.
  List<FreeSlot> freeIntervalsForDay({
    required List<Lesson> lessons,
    required int weekday,
    required int windowStartMin,
    required int windowEndMin,
    List<String> whoFree = const [],
  }) {
    final busy = lessons
        .where((l) => l.weekday == weekday)
        .map((l) => (
              start: max(l.startMin, windowStartMin),
              end: min(l.endMin, windowEndMin),
            ))
        .where((b) => b.end > b.start)
        .toList();
    return _carve(
        busy: busy,
        weekday: weekday,
        windowStartMin: windowStartMin,
        windowEndMin: windowEndMin,
        whoFree: whoFree);
  }

  /// Free intervals for one person on a concrete date, honouring one-off
  /// [busy] overrides in addition to recurring [lessons].
  List<FreeSlot> freeIntervalsForDate({
    required List<Lesson> lessons,
    required List<BusyBlock> busy,
    required DateTime date,
    required int windowStartMin,
    required int windowEndMin,
    List<String> whoFree = const [],
  }) {
    final key = BusyBlock.keyOf(date);
    final ranges = <({int start, int end})>[
      for (final l in lessons)
        if (l.weekday == date.weekday)
          (
            start: max(l.startMin, windowStartMin),
            end: min(l.endMin, windowEndMin),
          ),
      for (final b in busy)
        if (b.dateKey == key)
          (
            start: max(b.startMin, windowStartMin),
            end: min(b.endMin, windowEndMin),
          ),
    ].where((b) => b.end > b.start).toList();
    return _carve(
        busy: ranges,
        weekday: date.weekday,
        windowStartMin: windowStartMin,
        windowEndMin: windowEndMin,
        whoFree: whoFree);
  }

  List<FreeSlot> _carve({
    required List<({int start, int end})> busy,
    required int weekday,
    required int windowStartMin,
    required int windowEndMin,
    required List<String> whoFree,
  }) {
    final sorted = List<({int start, int end})>.from(busy)
      ..sort((a, b) => a.start.compareTo(b.start));

    // Merge overlapping busy blocks.
    final merged = <({int start, int end})>[];
    for (final b in sorted) {
      if (merged.isEmpty || b.start > merged.last.end) {
        merged.add(b);
      } else {
        merged[merged.length - 1] =
            (start: merged.last.start, end: max(merged.last.end, b.end));
      }
    }

    final free = <FreeSlot>[];
    var cursor = windowStartMin;
    for (final b in merged) {
      if (b.start > cursor) {
        free.add(FreeSlot(
            weekday: weekday, startMin: cursor, endMin: b.start, whoFree: whoFree));
      }
      cursor = max(cursor, b.end);
    }
    if (cursor < windowEndMin) {
      free.add(FreeSlot(
          weekday: weekday,
          startMin: cursor,
          endMin: windowEndMin,
          whoFree: whoFree));
    }
    return free;
  }

  /// Intersection of several people's free-interval lists.
  List<FreeSlot> intersectAll(List<List<FreeSlot>> eachPersonFree) {
    if (eachPersonFree.isEmpty) return [];
    var acc = List<FreeSlot>.from(eachPersonFree.first);
    for (var i = 1; i < eachPersonFree.length; i++) {
      acc = _intersectTwo(acc, eachPersonFree[i]);
      if (acc.isEmpty) break;
    }
    return acc;
  }

  List<FreeSlot> _intersectTwo(List<FreeSlot> a, List<FreeSlot> b) {
    final out = <FreeSlot>[];
    var i = 0, j = 0;
    while (i < a.length && j < b.length) {
      final s = max(a[i].startMin, b[j].startMin);
      final e = min(a[i].endMin, b[j].endMin);
      if (e > s) {
        final who = {...a[i].whoFree, ...b[j].whoFree}.toList();
        out.add(FreeSlot(
            weekday: a[i].weekday, startMin: s, endMin: e, whoFree: who));
      }
      if (a[i].endMin < b[j].endMin) {
        i++;
      } else {
        j++;
      }
    }
    return out;
  }

  /// Mutual free slots for a group on one weekday.
  ///
  /// [timetables] maps person-name -> their lessons for context.
  List<FreeSlot> mutualFreeOnDay({
    required Map<String, List<Lesson>> timetables,
    required int weekday,
    required int windowStartMin,
    required int windowEndMin,
    int minDurationMin = 15,
  }) {
    if (timetables.isEmpty) return [];
    final each = timetables.entries
        .map((e) => freeIntervalsForDay(
              lessons: e.value,
              weekday: weekday,
              windowStartMin: windowStartMin,
              windowEndMin: windowEndMin,
              whoFree: [e.key],
            ))
        .toList();
    return intersectAll(each)
        .where((s) => s.durationMin >= minDurationMin)
        .toList();
  }

  /// Names of people free at [timeMin] on [weekday].
  List<String> whoIsFreeAt({
    required Map<String, List<Lesson>> timetables,
    required int weekday,
    required int timeMin,
  }) {
    final free = <String>[];
    for (final entry in timetables.entries) {
      final busy = entry.value.any((l) =>
          l.weekday == weekday &&
          timeMin >= l.startMin &&
          timeMin < l.endMin);
      if (!busy) free.add(entry.key);
    }
    return free;
  }

  /// For each day in [weekdays], count how many people are free in each
  /// [slotMinutes] bucket starting at [windowStartMin]. Used for the heatmap.
  Map<int, List<int>> freeCountHeatmap({
    required Map<String, List<Lesson>> timetables,
    required List<int> weekdays,
    required int windowStartMin,
    required int windowEndMin,
    int slotMinutes = 30,
  }) {
    final result = <int, List<int>>{};
    for (final day in weekdays) {
      final buckets = <int>[];
      for (var t = windowStartMin; t < windowEndMin; t += slotMinutes) {
        final mid = t + slotMinutes ~/ 2;
        buckets.add(whoIsFreeAt(
                timetables: timetables, weekday: day, timeMin: mid)
            .length);
      }
      result[day] = buckets;
    }
    return result;
  }

  /// Ranked meetup suggestions across a week: longest shared breaks first,
  /// requiring at least [minPeople] free and [minDurationMin] length.
  List<FreeSlot> bestSlotsAcrossWeek({
    required Map<String, List<Lesson>> timetables,
    required List<int> weekdays,
    required int windowStartMin,
    required int windowEndMin,
    int minDurationMin = 30,
    int minPeople = 2,
    int maxResults = 8,
  }) {
    if (timetables.length < minPeople) return [];
    final names = timetables.keys.toList();
    final candidates = <FreeSlot>[];

    // Full-group overlaps first.
    for (final day in weekdays) {
      candidates.addAll(mutualFreeOnDay(
        timetables: timetables,
        weekday: day,
        windowStartMin: windowStartMin,
        windowEndMin: windowEndMin,
        minDurationMin: minDurationMin,
      ));
    }
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        final d = b.durationMin.compareTo(a.durationMin);
        if (d != 0) return d;
        if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
        return a.startMin.compareTo(b.startMin);
      });
      return candidates.take(maxResults).toList();
    }

    // Fallback: best partial-group overlaps (largest headcount, then longest).
    final partial = <FreeSlot>[];
    for (final day in weekdays) {
      for (var t = windowStartMin;
          t + minDurationMin <= windowEndMin;
          t += 15) {
        final end = t + minDurationMin;
        final who = names.where((n) {
          final lessons = timetables[n]!;
          return !lessons.any((l) =>
              l.weekday == day && t < l.endMin && l.startMin < end);
        }).toList();
        if (who.length >= minPeople) {
          partial.add(
              FreeSlot(weekday: day, startMin: t, endMin: end, whoFree: who));
        }
      }
    }
    // Merge adjacent buckets with identical groups.
    partial.sort((a, b) {
      final w = b.whoFree.length.compareTo(a.whoFree.length);
      if (w != 0) return w;
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      return a.startMin.compareTo(b.startMin);
    });
    final merged = <FreeSlot>[];
    for (final s in partial) {
      if (merged.isNotEmpty &&
          merged.last.weekday == s.weekday &&
          _sameSet(merged.last.whoFree, s.whoFree) &&
          s.startMin <= merged.last.endMin) {
        merged[merged.length - 1] = merged.last.copyWith(
            endMin: max(merged.last.endMin, s.endMin));
      } else if (merged.length < maxResults * 2) {
        merged.add(s);
      }
    }
    merged.sort((a, b) {
      final w = b.whoFree.length.compareTo(a.whoFree.length);
      if (w != 0) return w;
      return b.durationMin.compareTo(a.durationMin);
    });
    return merged.take(maxResults).toList();
  }

  /// The next mutual free slot today at/after [fromMin], or null.
  FreeSlot? nextFreeToday({
    required Map<String, List<Lesson>> timetables,
    required int weekday,
    required int fromMin,
    required int windowStartMin,
    required int windowEndMin,
    int minDurationMin = 15,
  }) {
    final mutual = mutualFreeOnDay(
      timetables: timetables,
      weekday: weekday,
      windowStartMin: windowStartMin,
      windowEndMin: windowEndMin,
      minDurationMin: 0,
    );
    for (final s in mutual) {
      if (s.endMin <= fromMin) continue;
      final start = max(s.startMin, fromMin);
      if (s.endMin - start >= minDurationMin) {
        return s.copyWith(startMin: start);
      }
    }
    return null;
  }

  // ---------------- date-aware (busy-block) API ----------------

  /// Mutual free slots for [people] on a concrete [date].
  List<FreeSlot> mutualFreeOnDate({
    required List<ParticipantTimetable> people,
    required DateTime date,
    required int windowStartMin,
    required int windowEndMin,
    int minDurationMin = 15,
  }) {
    if (people.isEmpty) return [];
    final day = dateOnly(date);
    final each = people
        .map((p) => freeIntervalsForDate(
              lessons: p.lessons,
              busy: p.busy,
              date: day,
              windowStartMin: windowStartMin,
              windowEndMin: windowEndMin,
              whoFree: [p.name],
            ))
        .toList();
    return intersectAll(each)
        .where((s) => s.durationMin >= minDurationMin)
        .toList();
  }

  /// Names free at [timeMin] on a concrete [date].
  List<String> whoIsFreeAtDate({
    required List<ParticipantTimetable> people,
    required DateTime date,
    required int timeMin,
  }) {
    final day = dateOnly(date);
    final key = BusyBlock.keyOf(day);
    final free = <String>[];
    for (final p in people) {
      final busy = p.lessons.any((l) =>
              l.weekday == day.weekday &&
              timeMin >= l.startMin &&
              timeMin < l.endMin) ||
          p.busy.any((b) =>
              b.dateKey == key &&
              timeMin >= b.startMin &&
              timeMin < b.endMin);
      if (!busy) free.add(p.name);
    }
    return free;
  }

  /// Every shared gap from [from] (inclusive) over the next [days] days,
  /// earliest first. Powers notifications and "upcoming gaps".
  /// Requires at least [minPeople] participants to be meaningful.
  List<DatedSlot> upcomingSharedGaps({
    required List<ParticipantTimetable> people,
    required DateTime from,
    int days = 7,
    required int windowStartMin,
    required int windowEndMin,
    int minDurationMin = 15,
    int minPeople = 2,
    int maxResults = 20,
  }) {
    if (people.length < minPeople) return [];
    final out = <DatedSlot>[];
    final startDay = dateOnly(from);
    final fromMinToday = from.hour * 60 + from.minute;
    for (var d = 0; d < days && out.length < maxResults; d++) {
      final date = startDay.add(Duration(days: d));
      var slots = mutualFreeOnDate(
        people: people,
        date: date,
        windowStartMin: windowStartMin,
        windowEndMin: windowEndMin,
        minDurationMin: minDurationMin,
      );
      if (d == 0) {
        // Drop anything already over.
        slots = slots
            .where((s) => s.endMin > fromMinToday)
            .map((s) => s.startMin < fromMinToday
                ? s.copyWith(startMin: fromMinToday)
                : s)
            .where((s) => s.durationMin >= minDurationMin)
            .toList();
      }
      for (final s in slots) {
        out.add((date: date, slot: s));
        if (out.length >= maxResults) break;
      }
    }
    return out;
  }

  bool _sameSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return Set<String>.from(a).containsAll(b);
  }
}
