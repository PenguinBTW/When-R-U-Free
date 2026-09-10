import 'dart:math';

import '../models/free_slot.dart';

/// Pure timeline model for the proportional week view: free blocks in order,
/// with compact skip dividers wherever busy time sits between them.
///
/// Kept UI-free so it is unit-testable; widgets live in week_screen.dart.
sealed class TimelineEntry {
  const TimelineEntry();
}

/// A rendered shared-free block.
class FreeEntry extends TimelineEntry {
  final FreeSlot slot;
  const FreeEntry(this.slot);
}

/// A busy stretch between (or before) free blocks, e.g.
/// "09:30 – 10:30 · In lessons (1h)".
class SkipEntry extends TimelineEntry {
  final int startMin;
  final int endMin;
  /// True when you are the one busy (lessons/busy block) at the midpoint,
  /// false when it is merely time with no shared break.
  final bool lessons;
  const SkipEntry({
    required this.startMin,
    required this.endMin,
    required this.lessons,
  });

  int get durationMin => endMin - startMin;
}

/// Builds the timeline for one day window.
///
/// [blocks] must be time-ordered (as [groupedFreeBlocks] returns); a defensive
/// copy is sorted anyway. Gaps before the first block and between blocks
/// become [SkipEntry]s; time after the last block is intentionally left out
/// (end of the visible day, not a jump).
List<TimelineEntry> buildTimeline({
  required List<FreeSlot> blocks,
  required int windowStartMin,
  required int windowEndMin,
  required bool Function(int minute) imBusy,
}) {
  final sorted = List<FreeSlot>.from(blocks)
    ..sort((a, b) => a.startMin.compareTo(b.startMin));
  final entries = <TimelineEntry>[];
  var cursor = windowStartMin;
  for (final b in sorted) {
    final s = max(b.startMin, cursor);
    if (s > cursor) {
      entries.add(SkipEntry(
        startMin: cursor,
        endMin: s,
        lessons: imBusy(cursor + (s - cursor) ~/ 2),
      ));
    }
    if (b.endMin > cursor) {
      entries.add(FreeEntry(b.copyWith(startMin: max(b.startMin, cursor))));
      cursor = max(cursor, b.endMin);
    }
    if (cursor >= windowEndMin) break;
  }
  return entries;
}
