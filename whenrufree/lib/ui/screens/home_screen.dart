import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/free_slot.dart';
import '../../utils/time_fmt.dart';
import '../widgets/common.dart';
import '../widgets/detail_sheets.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int index) goTo;
  const HomeScreen({super.key, required this.goTo});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMin = now.hour * 60 + now.minute;
    final timetables = store.timetables();
    final people = timetables.keys.toList();

    // Date-aware: one-off busy overrides honoured.
    final freeNow = store.freeNowAt(now);
    final mutualToday = store.mutualFreeOnDate(today);
    FreeSlot? next;
    for (final s in mutualToday) {
      if (s.endMin <= nowMin) continue;
      final start = s.startMin < nowMin ? nowMin : s.startMin;
      if (s.endMin - start >= 15) {
        next = s.copyWith(startMin: start);
        break;
      }
    }
    final best = store.bestSlots().take(4).toList();
    final myLessonsToday = store.lessonsOn(today.weekday);
    final myBusyToday = store.busyOn(today);

    final hour = now.hour;
    final greeting =
        hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final firstName = store.profile.displayName.trim().split(' ').firstOrNull ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('When R U Free'),
        actions: [
          IconButton(
            tooltip: 'My friend code',
            icon: const Icon(Icons.qr_code_2_outlined),
            onPressed: () => showShareCode(
                context, store.profile.displayName, store.profile.friendCode),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Text('$greeting${firstName.isEmpty ? '' : ', $firstName'} 👋',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              DateFormat('EEEE d MMMM').format(now),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            if (!store.notifPrompted)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Get pinged before shared breaks?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                          'We\'ll notify you shortly before each gap friends share with you — naming who else is free.'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () => store.acceptGapAlerts(),
                            child: const Text('Notify me'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => store.declineGapAlerts(),
                            child: const Text('Not now'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ---- Free-now card ----
            Card(
              color: freeNow.length == people.length && people.length > 1
                  ? Colors.green.shade50
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.bolt,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                freeNow.isEmpty
                                    ? 'Everyone is in lessons'
                                    : '${freeNow.length}/${people.length} free right now',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                next == null
                                    ? 'No more shared breaks today.'
                                    : 'Next all-free: ${formatRange(next.startMin, next.endMin)} (${formatDuration(next.endMin - next.startMin)})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (people.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: people.map((name) {
                          final free = freeNow.contains(name);
                          return Chip(
                            avatar: PersonAvatar(name, radius: 12),
                            label: Text(name),
                            backgroundColor: free
                                ? Colors.green.shade100
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (store.lessons.isEmpty)
              EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'Add your timetable',
                subtitle:
                    'Add your lessons once, then invite friends to find every shared break automatically.',
                buttonLabel: 'Add lessons',
                onButton: () => goTo(2),
              )
            else if (store.friends.isEmpty)
              EmptyState(
                icon: Icons.group_add_outlined,
                title: 'Invite your friends',
                subtitle:
                    'Share your friend code (${store.profile.friendCode}) so mates can add you — or add them by code.',
                buttonLabel: 'Add friends',
                onButton: () => goTo(3),
              ),

            SectionTitle('Today\'s shared breaks',
                actionLabel: 'Week view',
                onAction: () => goTo(1)),
            if (mutualToday.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'No shared free time today. Try the week view to find the next gap.'),
                ),
              )
            else
              ...mutualToday.map((s) => Card(
                    child: ListTile(
                      leading: Icon(Icons.watch_later_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(formatRange(s.startMin, s.endMin)),
                      subtitle: Text(
                          '${formatDuration(s.durationMin)} • ${s.whoFree.length} free'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showSlotDetail(context, s, people,
                          date: today,
                          onMarkBusy: (b) async =>
                              store.addBusyBlock(b)),
                    ),
                  )),

            SectionTitle('Best meetups this week',
                actionLabel: 'All',
                onAction: () => goTo(1)),
            if (best.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Add friends to see the best shared breaks ranked here.'),
                ),
              )
            else
              ...best.map((s) => Card(
                    child: ListTile(
                      leading: PersonAvatar(
                          s.whoFree.isEmpty ? '?' : s.whoFree.first),
                      title: Text(
                          '${weekdayShortName(s.weekday)} ${formatRange(s.startMin, s.endMin)}'),
                      subtitle: Text(
                          '${formatDuration(s.durationMin)} • ${s.whoFree.join(', ')}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showSlotDetail(context, s, people),
                    ),
                  )),
            SectionTitle(
                'Your lessons today (${myLessonsToday.length + myBusyToday.length})'),
            ...myBusyToday.map((b) => Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.event_busy_outlined,
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer),
                    title: Text(b.title),
                    subtitle: Text(
                        '${formatRange(b.startMin, b.endMin)} • busy override'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove busy block',
                      onPressed: () => store.removeBusyBlock(b.id),
                    ),
                  ),
                )),
            if (myLessonsToday.isEmpty && myBusyToday.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nothing on — enjoy the free day. 🎉'),
                ),
              )
            else
              ...myLessonsToday.map((l) => Card(
                    child: ListTile(
                      leading: Icon(Icons.book_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(l.subject),
                      subtitle: Text(
                          '${formatRange(l.startMin, l.endMin)}${l.location.isNotEmpty ? ' • ${l.location}' : ''}'),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
