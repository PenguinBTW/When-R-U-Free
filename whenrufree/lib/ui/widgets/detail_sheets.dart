import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/busy_block.dart';
import '../../models/free_slot.dart';
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
        // Scrollable: with several friends the per-person list can exceed
        // the sheet height (overflowed badly before this).
        child: SingleChildScrollView(
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
    ),
  );
}
