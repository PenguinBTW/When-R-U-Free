import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/lesson.dart';
import '../../services/sample_data.dart';
import 'graph_auth.dart';

/// Minimal Microsoft Graph client: profile + weekly calendar view.
///
/// Only `Calendars.Read` (+ identity) is ever requested. Events are mapped to
/// [Lesson]s in memory; nothing is saved until the user taps Import.
class GraphProfile {
  final String displayName;
  final String mail;
  const GraphProfile({required this.displayName, required this.mail});
}

class GraphEvent {
  final String subject;
  final DateTime startLocal;
  final DateTime endLocal;
  final String location;
  final String showAs; // free|tentative|busy|oof|workingElsewhere|unknown
  final bool isAllDay;

  const GraphEvent({
    required this.subject,
    required this.startLocal,
    required this.endLocal,
    required this.location,
    required this.showAs,
    required this.isAllDay,
  });
}

class GraphWeekResult {
  final List<GraphEvent> events;
  final int skippedAllDay;
  final int skippedFree;
  const GraphWeekResult({
    required this.events,
    required this.skippedAllDay,
    required this.skippedFree,
  });
}

class GraphCalendar {
  GraphCalendar._();
  static final GraphCalendar instance = GraphCalendar._();

  Future<GraphProfile> fetchProfile() async {
    final token = await GraphAuth.instance.getValidAccessToken();
    final res = await http.get(
      Uri.https('graph.microsoft.com', '/v1.0/me',
          {'\$select': 'displayName,mail,userPrincipalName'}),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw GraphAuthException(
          'Could not read your Microsoft profile (${res.statusCode}).');
    }
    final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return GraphProfile(
      displayName: (body['displayName'] as String?)?.trim() ?? '',
      mail: (body['mail'] as String?) ??
          (body['userPrincipalName'] as String?) ??
          '',
    );
  }

  /// Events from [weekMonday] 00:00 to the following Monday 00:00.
  Future<GraphWeekResult> fetchWeekEvents(DateTime weekMonday) async {
    final token = await GraphAuth.instance.getValidAccessToken();
    final start = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final end = start.add(const Duration(days: 7));
    String tzName = 'UTC';
    try {
      tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    final uri = Uri.https('graph.microsoft.com', '/v1.0/me/calendarview', {
      'startDateTime': start.toIso8601String(),
      'endDateTime': end.toIso8601String(),
      '\$select':
          'subject,start,end,location,isAllDay,isCancelled,showAs',
      '\$orderby': 'start/dateTime',
      '\$top': '200',
    });
    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Prefer': 'outlook.timezone="$tzName"',
    });
    if (res.statusCode != 200) {
      throw GraphAuthException(
          'Could not read your calendar (${res.statusCode}). Check the Calendars.Read permission.');
    }
    final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return parseEventsJson(body);
  }

  /// Pure parser — unit-tested without network.
  GraphWeekResult parseEventsJson(Map<String, dynamic> body) {
    final values = (body['value'] as List?) ?? const [];
    final events = <GraphEvent>[];
    var skippedAllDay = 0;
    var skippedFree = 0;
    for (final raw in values) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      if (m['isCancelled'] == true) continue;
      final isAllDay = m['isAllDay'] == true;
      if (isAllDay) {
        skippedAllDay++;
        continue;
      }
      final showAs = ((m['showAs'] as String?) ?? 'busy').toLowerCase();
      if (showAs == 'free') {
        skippedFree++;
        continue;
      }
      final start = _parseDateTime(m['start']);
      final end = _parseDateTime(m['end']);
      if (start == null || end == null || !end.isAfter(start)) continue;
      final loc = m['location'];
      String location = '';
      if (loc is Map) {
        location = ((loc['displayName'] as String?) ?? '').trim();
      }
      events.add(GraphEvent(
        subject: ((m['subject'] as String?) ?? '').trim().isEmpty
            ? '(No title)'
            : (m['subject'] as String).trim(),
        startLocal: start,
        endLocal: end,
        location: location,
        showAs: showAs,
        isAllDay: false,
      ));
    }
    return GraphWeekResult(
        events: events,
        skippedAllDay: skippedAllDay,
        skippedFree: skippedFree);
  }

  DateTime? _parseDateTime(dynamic node) {
    if (node is! Map) return null;
    final raw = (node['dateTime'] as String?) ?? '';
    if (raw.isEmpty) return null;
    try {
      // With an offset/UTC marker, convert to local; bare wall-time from
      // Graph (in the requested outlook.timezone) parses as local already.
      final parsed = DateTime.parse(raw);
      if (raw.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw)) {
        return parsed.toLocal();
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// Splits multi-day events per day and clamps to 00:00–24:00.
  List<Lesson> eventsToLessons(List<GraphEvent> events) {
    final lessons = <Lesson>[];
    for (final e in events) {
      var day = DateTime(e.startLocal.year, e.startLocal.month, e.startLocal.day);
      final lastDay =
          DateTime(e.endLocal.year, e.endLocal.month, e.endLocal.day);
      while (!day.isAfter(lastDay)) {
        final dayStart =
            DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final s = e.startLocal.isAfter(dayStart) ? e.startLocal : dayStart;
        final en = e.endLocal.isBefore(dayEnd) ? e.endLocal : dayEnd;
        if (en.isAfter(s)) {
          final startMin = s.hour * 60 + s.minute;
          // Midnight at the day boundary means end-of-day, not 00:00.
          final endMin =
              en == dayEnd ? 24 * 60 : (en.hour * 60 + en.minute).clamp(1, 24 * 60);
          lessons.add(Lesson.create(
            subject: e.subject,
            weekday: day.weekday,
            startMin: startMin,
            endMin: endMin,
            location: e.location,
          ));
        }
        day = day.add(const Duration(days: 1));
      }
    }
    lessons.sort((a, b) {
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      return a.startMin.compareTo(b.startMin);
    });
    return lessons;
  }

  /// Demo preview so the import UI is tryable before Azure is wired up.
  /// Maps a sample timetable onto the given week as pseudo-calendar events.
  List<GraphEvent> demoEventsForWeek(DateTime weekMonday) {
    final monday = DateTime(
        weekMonday.year, weekMonday.month, weekMonday.day);
    final out = <GraphEvent>[];
    for (final l in sampleTimetable(seed: 0)) {
      final date = monday.add(Duration(days: l.weekday - 1));
      out.add(GraphEvent(
        subject: l.subject,
        startLocal: date.add(Duration(minutes: l.startMin)),
        endLocal: date.add(Duration(minutes: l.endMin)),
        location: l.location,
        showAs: 'busy',
        isAllDay: false,
      ));
    }
    debugPrint('[graph] demo preview generated (${out.length} events).');
    return out;
  }
}
