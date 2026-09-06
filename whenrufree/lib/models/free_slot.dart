import '../utils/time_fmt.dart';

/// A free interval on a given weekday.
class FreeSlot {
  final int weekday; // 1–7
  final int startMin;
  final int endMin;
  /// Ids/names of the people free for the whole slot (for detail sheets).
  final List<String> whoFree;

  const FreeSlot({
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.whoFree = const [],
  });

  int get durationMin => endMin - startMin;

  String label() => '${weekdayShortName(weekday)} ${formatRange(startMin, endMin)}';

  FreeSlot copyWith({int? weekday, int? startMin, int? endMin, List<String>? whoFree}) {
    return FreeSlot(
      weekday: weekday ?? this.weekday,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      whoFree: whoFree ?? this.whoFree,
    );
  }
}
