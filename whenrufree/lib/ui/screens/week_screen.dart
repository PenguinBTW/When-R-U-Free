import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/free_slot.dart';
import '../../utils/time_fmt.dart';
import '../widgets/common.dart';
import '../widgets/detail_sheets.dart';

/// Week heatmap: for the selected day, every 30-min row shows how many of the
/// group are free, plus the exact mutual blocks below.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _day = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final timetables = store.timetables();
    final people = timetables.keys.toList();
    final total = people.length;
    final participants = store.participants();

    // The selected weekday mapped to its upcoming concrete date, so one-off
    // busy overrides apply here too.
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    var delta = (_day - todayOnly.weekday) % 7;
    final selectedDate = todayOnly.add(Duration(days: delta));

    // Heatmap buckets honour busy blocks on the selected date.
    final bucketCount =
        ((store.windowEndMin - store.windowStartMin) / 30).ceil();
    final heat = List<int>.generate(bucketCount, (i) {
      final mid = store.windowStartMin + i * 30 + 15;
      if (mid >= store.windowEndMin) return 0;
      return store.availability.whoIsFreeAtDate(
          people: participants, date: selectedDate, timeMin: mid).length;
    });
    final mutual = store.availability.mutualFreeOnDate(
      people: participants,
      date: selectedDate,
      windowStartMin: store.windowStartMin,
      windowEndMin: store.windowEndMin,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Week view')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (i) {
                final d = i + 1;
                final selected = d == _day;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(weekdayShortName(d)),
                    selected: selected,
                    onSelected: (_) => setState(() => _day = d),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weekdayName(_day)} — who\'s free when',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'Add lessons to get started.'
                        : '$total in comparison (you + ${store.includedFriends.length} friends). Tap a row for detail.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(heat.length, (i) {
                    final start = store.windowStartMin + i * 30;
                    final end = start + 30;
                    final count = heat[i];
                    final frac = total == 0 ? 0.0 : count / total;
                    final allFree = total > 0 && count == total;
                    // Who exactly is free mid-slot?
                    final who = total == 0
                        ? <String>[]
                        : store.availability.whoIsFreeAtDate(
                            people: participants,
                            date: selectedDate,
                            timeMin: start + 15);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: total == 0
                          ? null
                          : () => showSlotDetail(
                                context,
                                FreeSlot(
                                    weekday: _day,
                                    startMin: start,
                                    endMin: end,
                                    whoFree: who),
                                people,
                                date: selectedDate,
                                onMarkBusy: (b) async =>
                                    store.addBusyBlock(b),
                              ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(formatMinutes(start),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  minHeight: 18,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation(
                                    allFree
                                        ? Colors.green.shade500
                                        : Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.35 + frac * 0.65),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 36,
                              child: Text('$count/$total',
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          fontWeight: allFree
                                              ? FontWeight.bold
                                              : null,
                                          color: allFree
                                              ? Colors.green.shade700
                                              : null)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          SectionTitle('All-free blocks on ${weekdayShortName(_day)}'),
          if (mutual.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No time when everyone is free this day.'),
              ),
            )
          else
            ...mutual.map((s) => Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(
                        '${formatRange(s.startMin, s.endMin)} (${formatDuration(s.durationMin)})'),
                    subtitle: Text(s.whoFree.join(', ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showSlotDetail(context, s, people,
                        date: selectedDate,
                        onMarkBusy: (b) async =>
                            store.addBusyBlock(b)),
                  ),
                )),
        ],
      ),
    );
  }
}
