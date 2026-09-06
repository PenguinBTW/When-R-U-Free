/// Small time helpers. Times are stored as minutes since midnight.
library;

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String formatRange(int start, int end) =>
    '${formatMinutes(start)} – ${formatMinutes(end)}';

String formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

const weekdayNames = <int, String>{
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

const weekdayShort = <int, String>{
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

String weekdayName(int weekday) => weekdayNames[weekday] ?? 'Day $weekday';
String weekdayShortName(int weekday) => weekdayShort[weekday] ?? 'D$weekday';
