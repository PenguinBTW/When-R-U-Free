import 'package:flutter_test/flutter_test.dart';
import 'package:whenrufree/services/graph/graph_calendar.dart';

void main() {
  group('GraphCalendar.parseEventsJson', () {
    test('maps events, skips all-day / free / cancelled', () {
      final result = GraphCalendar.instance.parseEventsJson({
        'value': [
          {
            'subject': 'Maths',
            'start': {'dateTime': '2026-09-07T09:00:00.0000000', 'timeZone': 'UTC'},
            'end': {'dateTime': '2026-09-07T10:00:00.0000000', 'timeZone': 'UTC'},
            'location': {'displayName': 'M2'},
            'isAllDay': false,
            'isCancelled': false,
            'showAs': 'busy',
          },
          {
            'subject': 'Birthday',
            'start': {'dateTime': '2026-09-07T00:00:00.0000000', 'timeZone': 'UTC'},
            'end': {'dateTime': '2026-09-08T00:00:00.0000000', 'timeZone': 'UTC'},
            'isAllDay': true,
            'isCancelled': false,
            'showAs': 'free',
          },
          {
            'subject': 'Free period',
            'start': {'dateTime': '2026-09-07T11:00:00.0000000', 'timeZone': 'UTC'},
            'end': {'dateTime': '2026-09-07T12:00:00.0000000', 'timeZone': 'UTC'},
            'isAllDay': false,
            'isCancelled': false,
            'showAs': 'free',
          },
          {
            'subject': 'Cancelled lecture',
            'start': {'dateTime': '2026-09-07T13:00:00.0000000', 'timeZone': 'UTC'},
            'end': {'dateTime': '2026-09-07T14:00:00.0000000', 'timeZone': 'UTC'},
            'isAllDay': false,
            'isCancelled': true,
            'showAs': 'busy',
          },
          {
            // malformed: no end
            'subject': 'Broken',
            'start': {'dateTime': '2026-09-07T15:00:00.0000000', 'timeZone': 'UTC'},
            'isAllDay': false,
            'isCancelled': false,
            'showAs': 'busy',
          },
        ],
      });
      expect(result.events.length, 1);
      expect(result.events.first.subject, 'Maths');
      expect(result.events.first.location, 'M2');
      expect(result.skippedAllDay, 1);
      expect(result.skippedFree, 1);
    });

    test('offset timestamps convert to local wall time', () {
      final result = GraphCalendar.instance.parseEventsJson({
        'value': [
          {
            'subject': 'Physics',
            'start': {'dateTime': '2026-09-07T09:00:00+00:00', 'timeZone': 'UTC'},
            'end': {'dateTime': '2026-09-07T10:00:00+00:00', 'timeZone': 'UTC'},
            'isAllDay': false,
            'showAs': 'busy',
          },
        ],
      });
      expect(result.events.length, 1);
      final e = result.events.first;
      expect(e.endLocal.difference(e.startLocal), const Duration(hours: 1));
    });
  });

  group('GraphCalendar.eventsToLessons', () {
    test('single-day mapping', () {
      final lessons = GraphCalendar.instance.eventsToLessons([
        GraphEvent(
            subject: 'Chem',
            startLocal: DateTime(2026, 9, 9, 13, 30),
            endLocal: DateTime(2026, 9, 9, 14, 30),
            location: 'Lab 2',
            showAs: 'busy',
            isAllDay: false),
      ]);
      expect(lessons.length, 1);
      expect(lessons.first.weekday, DateTime.wednesday);
      expect(lessons.first.startMin, 810);
      expect(lessons.first.endMin, 870);
    });

    test('overnight event splits across days', () {
      final lessons = GraphCalendar.instance.eventsToLessons([
        GraphEvent(
            subject: 'Hackathon',
            startLocal: DateTime(2026, 9, 11, 22, 0),
            endLocal: DateTime(2026, 9, 12, 2, 0),
            location: '',
            showAs: 'oof',
            isAllDay: false),
      ]);
      expect(lessons.length, 2);
      expect(lessons[0].startMin, 1320);
      expect(lessons[0].endMin, 1440);
      expect(lessons[1].startMin, 0);
      expect(lessons[1].endMin, 120);
    });

    test('demo preview generates lessons', () {
      final monday = DateTime(2026, 9, 7);
      final events = GraphCalendar.instance.demoEventsForWeek(monday);
      expect(events, isNotEmpty);
      final lessons = GraphCalendar.instance.eventsToLessons(events);
      expect(lessons, isNotEmpty);
      expect(lessons.every((l) => l.weekday >= 1 && l.weekday <= 7), isTrue);
    });
  });
}
