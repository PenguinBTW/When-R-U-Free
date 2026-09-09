import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../utils/time_fmt.dart';
import '../widgets/common.dart';
import '../widgets/detail_sheets.dart';

/// Week view: for the selected day, one adaptive block per stable free
/// group (e.g. a single "11:45 – 14:30 · Jess, Tim" instead of six rows).
/// Only times when YOU are free with at least one friend are shown — your
/// lessons and busy blocks simply leave no block behind.
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
    final myName = store.myLabel;
    final people = store.timetables().keys.toList();
    final friendCount = store.includedFriends.length;

    // The selected weekday mapped to its upcoming concrete date, so one-off
    // busy overrides apply here too.
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final delta = (_day - todayOnly.weekday) % 7;
    final selectedDate = todayOnly.add(Duration(days: delta));

    final blocks = store.groupedBlocksOn(selectedDate);
    final everyone = Set<String>.from(people);

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
          SectionTitle(
              'Free together · ${weekdayName(_day)}${delta == 0 ? ' (today)' : ''}'),
          Text(
            friendCount == 0
                ? 'Add friends to compare — right now it\'s just you.'
                : 'Only showing times you\'re free with mates (${DateFormat('EEE d MMM').format(selectedDate)}). Tap a block for detail.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (blocks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Nothing where you\'re free with friends this day. Add events or friends — or pick another day.'),
              ),
            )
          else
            ...blocks.map((s) {
              final mates =
                  s.whoFree.where((n) => n != myName).toList();
              final allFree =
                  Set<String>.from(s.whoFree).containsAll(everyone) &&
                      everyone.length == s.whoFree.length;
              return Card(
                color: allFree ? gapHighlight(context) : null,
                child: ListTile(
                  leading: mates.isEmpty
                      ? const Icon(Icons.groups_outlined)
                      : _AvatarStack(
                          mates: mates.take(3).toList(),
                          extra: mates.length - mates.take(3).length),
                  title: Text(
                    '${formatRange(s.startMin, s.endMin)} (${formatDuration(s.durationMin)})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(allFree
                      ? 'Everyone 🎉'
                      : mates.join(', ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showSlotDetail(context, s, people,
                      date: selectedDate,
                      onMarkBusy: (b) async =>
                          store.addBusyBlock(b)),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Overlapping avatar circles for the friends in a block.
class _AvatarStack extends StatelessWidget {
  final List<String> mates;
  final int extra;
  const _AvatarStack({required this.mates, required this.extra});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: mates.length * 24.0 + (extra > 0 ? 30 : 8),
      height: 36,
      child: Stack(
        children: [
          for (var i = 0; i < mates.length; i++)
            Positioned(
              left: i * 24.0,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2),
                ),
                child: PersonAvatar(mates[i], radius: 16),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: mates.length * 24.0,
              top: 0,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child: Text('+$extra',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
