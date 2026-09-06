import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A one-off busy override on a specific date, e.g. "Dentist — Tue 12:30–13:30".
///
/// Unlike [Lesson] (which recurs weekly), a busy block carves time out of a
/// single date's free intervals. Used for "I'm actually busy in that gap".
class BusyBlock {
  final String id;
  final String title;
  final String dateKey; // local yyyy-MM-dd
  final int startMin;
  final int endMin;

  const BusyBlock({
    required this.id,
    required this.title,
    required this.dateKey,
    required this.startMin,
    required this.endMin,
  });

  factory BusyBlock.create({
    required String title,
    required DateTime date,
    required int startMin,
    required int endMin,
  }) {
    return BusyBlock(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Busy' : title.trim(),
      dateKey: keyOf(date),
      startMin: startMin,
      endMin: endMin,
    );
  }

  static String keyOf(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  static DateTime dateOf(String key) {
    final parts = key.split('-');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  int get durationMin => endMin - startMin;

  static String? validate({required int startMin, required int endMin}) {
    if (endMin <= startMin) return 'End time must be after start time.';
    if (endMin - startMin < 5) return 'Busy blocks must be at least 5 minutes.';
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateKey': dateKey,
        'startMin': startMin,
        'endMin': endMin,
      };

  factory BusyBlock.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return BusyBlock(
      id: json['id'] as String? ?? _uuid.v4(),
      title: json['title'] as String? ?? 'Busy',
      dateKey: json['dateKey'] as String? ?? keyOf(now),
      startMin: (json['startMin'] as num? ?? 720).toInt(),
      endMin: (json['endMin'] as num? ?? 780).toInt(),
    );
  }
}
