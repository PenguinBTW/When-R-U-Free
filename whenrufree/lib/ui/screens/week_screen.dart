import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/free_slot.dart';
import '../../utils/time_fmt.dart';
import '../../utils/timeline.dart';
import '../widgets/common.dart';
import '../widgets/detail_sheets.dart';

/// Proportional shared-break timeline: free blocks scale with duration
/// (clamped), busy stretches collapse into compact skip dividers.
/// Only times when YOU are free with mates are rendered — nothing else.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _day = DateTime.now().weekday.clamp(1, 5);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final myName = store.myLabel;
    final people = store.timetables().keys.toList();
    final everyone = Set<String>.from(people);
    final friendCount = store.includedFriends.length;
    final pxPerMin = timelinePxPerMin(context);

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final delta = (_day - todayOnly.weekday) % 7;
    final selectedDate = todayOnly.add(Duration(days: delta));

    final entries = store.timelineOn(selectedDate);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- sticky header ----
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kTimelineMargin, 12, kTimelineMargin, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Week view',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${DateFormat('EEEE d MMM').format(selectedDate)}${delta == 0 ? ' · today' : ''}${friendCount == 0 ? '' : ' · $friendCount friend${friendCount == 1 ? '' : 's'}'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // ---- sticky Mon–Fri pills ----
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                  kTimelineMargin, 4, kTimelineMargin, 8),
              child: Row(
                children: List.generate(5, (i) {
                  final d = i + 1;
                  final selected = d == _day;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(weekdayShortName(d)),
                      selected: selected,
                      showCheckmark: false,
                      avatar: d == todayOnly.weekday
                          ? const Icon(Icons.today_outlined, size: 16)
                          : null,
                      onSelected: (_) => setState(() => _day = d),
                    ),
                  );
                }),
              ),
            ),
            // ---- timeline ----
            Expanded(
              child: entries.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(kTimelineMargin),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(friendCount == 0
                                ? 'Add friends to compare — right now it\'s just you.'
                                : 'Nothing shared on ${weekdayName(_day)}. Your busy time leaves no blocks behind — try another day.'),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          kTimelineMargin, 4, kTimelineMargin, 100),
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        if (e is SkipEntry) {
                          return _SkipDivider(entry: e);
                        }
                        final slot = (e as FreeEntry).slot;
                        final mates = slot.whoFree
                            .where((n) => n != myName)
                            .toList();
                        final allFree =
                            Set<String>.from(slot.whoFree)
                                    .containsAll(everyone) &&
                                everyone.length ==
                                    slot.whoFree.length;
                        final expanded = slot.durationMin >= 45;
                        var height = timelineBlockHeight(
                            slot.durationMin, pxPerMin);
                        if (expanded &&
                            height < kTimelineExpandedMinHeight) {
                          height = kTimelineExpandedMinHeight;
                        }
                        return _FreeCard(
                          slot: slot,
                          mates: mates,
                          allFree: allFree,
                          height: height,
                          expanded: expanded,
                          onTap: () => showSlotDetail(
                              context, slot, people,
                              date: selectedDate,
                              onMarkBusy: (b) async =>
                                  store.addBusyBlock(b)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One proportional free block with a left time gutter.
class _FreeCard extends StatelessWidget {
  final FreeSlot slot;
  final List<String> mates;
  final bool allFree;
  final double height;
  final bool expanded;
  final VoidCallback onTap;

  const _FreeCard({
    required this.slot,
    required this.mates,
    required this.allFree,
    required this.height,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onCard = allFree ? Colors.white : null;
    final subColor =
        allFree ? Colors.white70 : cs.onSurfaceVariant;
    final accent = allFree ? Colors.white : cs.primary;

    return SizedBox(
      height: height,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: allFree ? kEveryoneCardBg : null,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(kTimelineCardRadius),
        ),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(kTimelineCardRadius),
          onTap: onTap,
          child: Padding(
            // Compact blocks run at the 56dp floor: tighter padding keeps
            // the single row + gutter inside with room to spare.
            padding: EdgeInsets.all(expanded ? 12 : 8),
            child: Row(
              children: [
                // ---- time gutter ----
                SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      // FittedBox + single line: gutter times can never wrap
                      // (huge fonts just shrink) so the fixed-height card
                      // cannot overflow whatever the font metrics are.
                      SizedBox(
                        height: 13,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(formatMinutes(slot.startMin),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.1,
                                  fontWeight: FontWeight.bold,
                                  color: onCard)),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 3,
                            margin:
                                const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(
                                  alpha: allFree ? 0.9 : 0.55),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 13,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(formatMinutes(slot.endMin),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.1,
                                  fontWeight: FontWeight.bold,
                                  color: onCard)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // ---- content ----
                Expanded(
                  child: expanded
                      ? Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${formatRange(slot.startMin, slot.endMin)} (${formatDuration(slot.durationMin)})',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: onCard),
                                  ),
                                ),
                                _DurationPill(
                                    text: formatDuration(
                                        slot.durationMin),
                                    allFree: allFree),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (allFree)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                      alpha: 0.22),
                                  borderRadius:
                                      BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'All friends free 🎉',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  _MiniStack(
                                      mates:
                                          mates.take(4).toList()),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      mates.join(', '),
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: subColor),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        )
                      : Row(
                          children: [
                            _DurationPill(
                                text: formatDuration(
                                    slot.durationMin),
                                allFree: allFree),
                            const Spacer(),
                            _MiniStack(
                                mates: mates.take(3).toList()),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  final String text;
  final bool allFree;
  const _DurationPill({required this.text, required this.allFree});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: allFree
            ? Colors.white.withValues(alpha: 0.22)
            : cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: allFree ? Colors.white : cs.onPrimaryContainer)),
    );
  }
}

/// Overlapping avatar circles (no overflow: fixed count, fixed width).
class _MiniStack extends StatelessWidget {
  final List<String> mates;
  const _MiniStack({required this.mates});

  @override
  Widget build(BuildContext context) {
    if (mates.isEmpty) {
      return const Icon(Icons.groups_outlined);
    }
    return SizedBox(
      width: (mates.length - 1) * 20.0 + 32,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < mates.length; i++)
            Positioned(
              left: i * 20.0,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2),
                ),
                child: PersonAvatar(mates[i], radius: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ultra-compact busy separator, e.g. "09:30 – 10:30 · In lessons (1h)".
class _SkipDivider extends StatelessWidget {
  final SkipEntry entry;
  const _SkipDivider({required this.entry});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final label =
        '${formatRange(entry.startMin, entry.endMin)} · ${entry.lessons ? 'In lessons' : 'No shared break'} (${formatDuration(entry.durationMin)})';
    return SizedBox(
      height: kSkipDividerHeight,
      child: Row(
        children: [
          Expanded(child: Divider(color: muted.withValues(alpha: 0.4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label,
                style: TextStyle(fontSize: 11, color: muted)),
          ),
          Expanded(child: Divider(color: muted.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
