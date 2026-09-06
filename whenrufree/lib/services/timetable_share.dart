import 'dart:convert';

import '../models/lesson.dart';

/// Portable offline timetable sharing.
///
/// Encodes a timetable into a short text code (`WRF1-…`) that can be pasted
/// into any chat app. The receiver imports it from Friends → "Import shared
/// timetable" — no account or cloud needed.
///
/// Format: `WRF1-` + base64url(json) with `=` padding stripped.
/// (Deliberately uncompressed: this SDK ships without dart:convert's
/// gzip codec, and plain base64 keeps decode dependency-free.)
/// JSON: {v:1, n:name, c:friendCode, g:college, l:[[subject,weekday,start,end,loc],…]}
class SharedPayload {
  final String displayName;
  final String friendCode;
  final String college;
  final List<Lesson> lessons;

  const SharedPayload({
    required this.displayName,
    required this.friendCode,
    required this.college,
    required this.lessons,
  });
}

class TimetableShare {
  static const prefix = 'WRF1-';

  static String encode({
    required String displayName,
    required String friendCode,
    required String college,
    required List<Lesson> lessons,
  }) {
    final map = {
      'v': 1,
      'n': displayName.trim(),
      'c': friendCode.trim().toUpperCase(),
      'g': college.trim(),
      'l': lessons
          .map((l) => [l.subject, l.weekday, l.startMin, l.endMin, l.location])
          .toList(),
    };
    final bytes = utf8.encode(jsonEncode(map));
    final b64 = base64Url.encode(bytes).replaceAll('=', '');
    return '$prefix$b64';
  }

  /// Throws [FormatException] with a user-friendly message when invalid.
  static SharedPayload decode(String raw) {
    var code = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (code.isEmpty) throw const FormatException('Paste a shared code first.');
    if (!code.toUpperCase().startsWith(prefix)) {
      throw const FormatException(
          'That doesn\'t look like a When R U Free share code (it should start with $prefix).');
    }
    code = code.substring(code.toUpperCase().indexOf(prefix) + prefix.length);
    try {
      final padded = code + '=' * ((4 - code.length % 4) % 4);
      final bytes = base64Url.decode(padded);
      final map = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)) as Map);
      if (map['v'] != 1) {
        throw const FormatException('Unsupported share-code version.');
      }
      final rows = (map['l'] as List?) ?? const [];
      final lessons = <Lesson>[];
      for (final r in rows) {
        final row = (r as List);
        if (row.length < 4) continue;
        final subject = (row[0] as String?) ?? '';
        final weekday = (row[1] as num?)?.toInt() ?? 1;
        final start = (row[2] as num?)?.toInt() ?? 0;
        final end = (row[3] as num?)?.toInt() ?? 0;
        if (subject.trim().isEmpty) continue;
        if (weekday < 1 || weekday > 7) continue;
        if (end <= start) continue;
        lessons.add(Lesson.create(
          subject: subject,
          weekday: weekday,
          startMin: start,
          endMin: end,
          location: row.length > 4 ? ((row[4] as String?) ?? '') : '',
        ));
      }
      if (lessons.isEmpty) {
        throw const FormatException('That code contains no lessons.');
      }
      return SharedPayload(
        displayName: (map['n'] as String?)?.trim().isEmpty ?? true
            ? 'Shared friend'
            : (map['n'] as String).trim(),
        friendCode: ((map['c'] as String?) ?? '').toUpperCase(),
        college: (map['g'] as String?) ?? '',
        lessons: lessons,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'Couldn\'t read that code — check it was copied in full.');
    }
  }
}
