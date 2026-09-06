import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A single recurring weekly lesson, e.g. "Maths, Monday 09:00–10:00".
class Lesson {
  final String id;
  final String subject;
  final int weekday; // 1 = Monday … 7 = Sunday (matches DateTime.weekday)
  final int startMin; // minutes since midnight
  final int endMin; // minutes since midnight
  final String location;
  final int colorValue; // ARGB int, 0 = auto

  const Lesson({
    required this.id,
    required this.subject,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.location = '',
    this.colorValue = 0,
  });

  factory Lesson.create({
    required String subject,
    required int weekday,
    required int startMin,
    required int endMin,
    String location = '',
    int colorValue = 0,
  }) {
    return Lesson(
      id: _uuid.v4(),
      subject: subject.trim(),
      weekday: weekday,
      startMin: startMin,
      endMin: endMin,
      location: location.trim(),
      colorValue: colorValue,
    );
  }

  Lesson copyWith({
    String? subject,
    int? weekday,
    int? startMin,
    int? endMin,
    String? location,
    int? colorValue,
  }) {
    return Lesson(
      id: id,
      subject: subject ?? this.subject,
      weekday: weekday ?? this.weekday,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      location: location ?? this.location,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  int get durationMin => endMin - startMin;

  /// Returns a validation error, or null when valid.
  static String? validate({
    required String subject,
    required int startMin,
    required int endMin,
  }) {
    if (subject.trim().isEmpty) return 'Give the lesson a subject name.';
    if (startMin < 0 || endMin > 24 * 60) return 'Time must be within a day.';
    if (endMin <= startMin) return 'End time must be after start time.';
    if (endMin - startMin < 5) return 'Lessons must be at least 5 minutes.';
    return null;
  }

  /// True when this lesson overlaps [other] on the same weekday.
  bool overlaps(Lesson other) {
    if (weekday != other.weekday) return false;
    return startMin < other.endMin && other.startMin < endMin;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'weekday': weekday,
        'startMin': startMin,
        'endMin': endMin,
        'location': location,
        'colorValue': colorValue,
      };

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String? ?? _uuid.v4(),
        subject: json['subject'] as String? ?? 'Lesson',
        weekday: (json['weekday'] as num? ?? 1).toInt().clamp(1, 7),
        startMin: (json['startMin'] as num? ?? 540).toInt(),
        endMin: (json['endMin'] as num? ?? 600).toInt(),
        location: json['location'] as String? ?? '',
        colorValue: (json['colorValue'] as num? ?? 0).toInt(),
      );
}
