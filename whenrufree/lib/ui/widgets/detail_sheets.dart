import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/busy_block.dart';
import '../../models/free_slot.dart';
import '../../utils/time_fmt.dart';
import 'common.dart';

/// Tap-to-inspect drill-down: sticky header (interval + tally), scrollable
/// member list (busy rows dimmed, bright avatars), sticky footer actions.
Future<void> showSlotDetail(
  BuildContext context,
  FreeSlot slot,
  List<String> allPeople, {
  DateTime? date,
  Future<String?> Function(BusyBlock block)? onMarkBusy,
}) {
  final freeCount = slot.whoFree.length;
  final total = allPeople.length;
  final title = date == null
      ? '${weekdayShortName(slot.weekday)} ${formatRange(slot.startMin, slot.endMin)}'
      : '${DateFormat('EEE').format(date)} ${formatRange(slot.startMin, slot.endMin)}';
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- sticky header ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '${formatDuration(slot.durationMin)} long',
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$freeCount/$total free',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ---- scrollable member list ----
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(vertical: 4),
                itemCount: allPeople.length,
                itemBuilder: (_, i) {
                  final name = allPeople[i];
                  final free = slot.whoFree.contains(name);
                  return Opacity(
                    opacity: free ? 1.0 : 0.55,
                    child: ListTile(
                      leading: PersonAvatar(name, radius: 20),
                      title: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: free
                              ? freeChipBg(context)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(999),
                        ),
                        child: Text(free ? 'Free' : 'In a lesson',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: free
                                    ? contrastOn(
                                        freeChipBg(context))
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // ---- sticky footer ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text:
                              'Free: $title (${formatDuration(slot.durationMin)}) — ${slot.whoFree.join(', ')}'));
                      Navigator.of(context).pop();
                      showInfo(context,
                          'Slot copied — send it to the group chat.');
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy plan for group chat'),
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
                      icon: const Icon(Icons.event_busy_outlined,
                          size: 18),
                      label:
                          const Text('I\'m actually busy then'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
