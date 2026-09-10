import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whenrufree/models/free_slot.dart';
import 'package:whenrufree/ui/widgets/common.dart';
import 'package:whenrufree/utils/timeline.dart';
import 'package:whenrufree/utils/time_fmt.dart';

FreeSlot slot(int day, int s, int e, [List<String> who = const ['Me']]) =>
    FreeSlot(weekday: day, startMin: s, endMin: e, whoFree: who);

void main() {
  group('timelineBlockHeight', () {
    // pxPerMin is injected (responsive in the UI); use the ~1.25 guide here.
    test('scales with duration', () {
      expect(timelineBlockHeight(60, 1.25), 75.0);
      expect(timelineBlockHeight(120, 1.25), 150.0);
    });

    test('minimum clamp keeps small gaps tappable', () {
      expect(timelineBlockHeight(10, 1.25), kTimelineMinHeight);
      expect(timelineBlockHeight(15, 1.25), kTimelineMinHeight);
      expect(timelineBlockHeight(30, 1.25), kTimelineMinHeight);
    });

    test('maximum clamp caps long gaps', () {
      expect(timelineBlockHeight(180, 1.25), kTimelineMaxHeight);
      expect(timelineBlockHeight(240, 1.25), kTimelineMaxHeight);
    });

    test('adapts to density (compact vs large screens)', () {
      // Compact phone shrinks, large screen grows, same 1h block.
      expect(timelineBlockHeight(60, 0.9), 56.0);
      expect(timelineBlockHeight(60, 1.6), 96.0);
    });
  });

  group('timelinePxPerMin', () {
    testWidgets('tracks screen height within bounds', (tester) async {
      double? px;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              px = timelinePxPerMin(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(px, isNotNull);
      expect(px!, greaterThanOrEqualTo(0.9));
      expect(px!, lessThanOrEqualTo(1.6));
    });
  });

  group('buildTimeline', () {
    test('free blocks interleaved with lesson skips', () {
      final entries = buildTimeline(
        blocks: [
          slot(3, 630, 660, ['Me', 'Jess']),
          slot(3, 840, 990, ['Me', 'Jess', 'Tim']),
        ],
        windowStartMin: 480,
        windowEndMin: 1080,
        imBusy: (t) => t >= 570 && t < 840,
      );
      expect(entries.length, 4);
      expect(entries[0], isA<SkipEntry>());
      expect((entries[0] as SkipEntry).startMin, 480);
      expect((entries[0] as SkipEntry).endMin, 630);
      expect(entries[1], isA<FreeEntry>());
      expect(entries[2], isA<SkipEntry>());
      final mid = entries[2] as SkipEntry;
      expect(mid.startMin, 660);
      expect(mid.endMin, 840);
      expect(mid.lessons, isTrue);
      expect(mid.durationMin, 180);
      expect(entries[3], isA<FreeEntry>());
    });

    test('labels non-lesson gaps honestly', () {
      final entries = buildTimeline(
        blocks: [slot(3, 700, 760)],
        windowStartMin: 600,
        windowEndMin: 1080,
        imBusy: (_) => false,
      );
      expect(entries.length, 2);
      expect((entries[0] as SkipEntry).lessons, isFalse);
    });

    test('adjacent blocks produce no divider', () {
      final entries = buildTimeline(
        blocks: [slot(3, 600, 660), slot(3, 660, 720)],
        windowStartMin: 600,
        windowEndMin: 1080,
        imBusy: (_) => true,
      );
      expect(entries.length, 2);
      expect(entries.every((e) => e is FreeEntry), isTrue);
    });

    test('no trailing divider after the last block', () {
      final entries = buildTimeline(
        blocks: [slot(3, 600, 660)],
        windowStartMin: 480,
        windowEndMin: 1080,
        imBusy: (_) => true,
      );
      expect(entries.length, 2); // leading skip + block, nothing after
      expect(entries.last, isA<FreeEntry>());
    });

    test('empty day yields no entries', () {
      expect(
          buildTimeline(
            blocks: [],
            windowStartMin: 480,
            windowEndMin: 1080,
            imBusy: (_) => true,
          ),
          isEmpty);
    });

    test('divider label format matches spec', () {
      // "09:30 – 10:30 · In lessons (1h)"
      final label =
          '${formatRange(570, 630)} · In lessons (${formatDuration(60)})';
      expect(label, '09:30 – 10:30 · In lessons (1h)');
    });
  });
}
