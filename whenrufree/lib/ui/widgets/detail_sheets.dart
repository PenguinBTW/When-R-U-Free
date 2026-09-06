import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/busy_block.dart';
import '../../models/free_slot.dart';
import '../../models/friend.dart';
import '../../utils/time_fmt.dart';
import 'common.dart';

Future<void> showSlotDetail(
  BuildContext context,
  FreeSlot slot,
  List<String> allPeople, {
  DateTime? date,
  Future<String?> Function(BusyBlock block)? onMarkBusy,
}) {
  final dateLabel = date == null
      ? null
      : DateFormat('EEEE d MMM').format(date);
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(slot.label(),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${formatDuration(slot.durationMin)} free • ${slot.whoFree.length}/${allPeople.length} free${dateLabel == null ? '' : ' • $dateLabel'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ...allPeople.map((name) {
              final free = slot.whoFree.contains(name);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PersonAvatar(name),
                title: Text(name),
                trailing: Icon(
                  free ? Icons.check_circle : Icons.cancel,
                  color: free
                      ? Colors.green.shade600
                      : Theme.of(context).colorScheme.outline,
                ),
                subtitle: Text(free ? 'Free' : 'In a lesson'),
              );
            }),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text:
                        'Free: ${slot.label()} (${formatDuration(slot.durationMin)}) — ${slot.whoFree.join(', ')}'));
                Navigator.of(context).pop();
                showInfo(context, 'Slot copied — send it to the group chat.');
              },
              child: const Text('Copy plan for group chat'),
            ),
            if (date != null && onMarkBusy != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final block = BusyBlock.create(
                    title: 'Busy',
                    date: date,
                    startMin: slot.startMin,
                    endMin: slot.endMin,
                  );
                  Navigator.of(context).pop();
                  final err = await onMarkBusy(block);
                  if (context.mounted) {
                    showInfo(context,
                        err ?? 'Marked busy — it no longer counts as a gap.');
                  }
                },
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('I\'m actually busy then'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<void> showFriendTimetable(BuildContext context, Friend friend) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: ListView(
          controller: controller,
          children: [
            Row(
              children: [
                PersonAvatar(friend.displayName, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friend.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Code ${friend.friendCode} • '
                          '${friend.lessons.length} lessons/week'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var day = 1; day <= 7; day++)
              if (friend.lessonsOn(day).isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(weekdayName(day),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                ...friend.lessonsOn(day).map((l) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.book_outlined,
                            color:
                                Theme.of(context).colorScheme.primary),
                        title: Text(l.subject),
                        subtitle: Text(
                            '${formatRange(l.startMin, l.endMin)}${l.location.isNotEmpty ? ' • ${l.location}' : ''}'),
                      ),
                    )),
              ],
            if (friend.lessons.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('No lessons added for this friend yet.'),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showShareCode(
    BuildContext context, String name, String code) {
  final text =
      'Add me on When R U Free! My friend code is $code. Add it under Friends to compare our timetables and find shared breaks.';
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share your code',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              name.isEmpty
                  ? 'Friends add this code to compare timetables with you.'
                  : '$name — friends add this code to compare timetables with you.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(code,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(
                          fontWeight: FontWeight.bold, letterSpacing: 6)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.of(context).pop();
                      showInfo(context, 'Code copied.');
                    },
                    child: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => SharePlus.instance.share(
                        ShareParams(text: text, subject: 'When R U Free')),
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
