import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_store.dart';
import '../../services/timetable_share.dart';
import '../../utils/time_fmt.dart';
import 'common.dart';

/// Shows MY timetable as a portable share code.
Future<void> showShareTimetable(BuildContext context, AppStore store) {
  if (store.lessons.isEmpty) {
    showInfo(context, 'Add some lessons first, then share.');
    return Future.value();
  }
  final code = TimetableShare.encode(
    displayName: store.profile.displayName.isEmpty
        ? 'Shared friend'
        : store.profile.displayName,
    friendCode: store.profile.friendCode,
    college: store.profile.college,
    lessons: store.lessons,
  );
  final text =
      'Here\'s my When R U Free timetable! Paste this code in the app under Friends → Import shared timetable:\n\n$code';
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Share your timetable',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${store.lessons.length} lessons • works offline, no account needed. Your friend imports it and instantly sees shared gaps.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(code,
                  style: const TextStyle(fontSize: 12, height: 1.5)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.of(context).pop();
                      showInfo(context, 'Share code copied.');
                    },
                    child: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => SharePlus.instance.share(
                        ShareParams(text: text, subject: 'My timetable')),
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

/// Pastes a friend's share code and imports it (as a friend, or into MY
/// timetable when it is my own code).
Future<void> showImportSharedCode(BuildContext context, AppStore store) {
  final controller = TextEditingController();
  SharedPayload? payload;
  String? error;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Import shared timetable',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  'Paste the code your friend sent you. It becomes a friend entry with their real lessons.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Share code (WRF1-…)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (payload != null || error != null) {
                    setState(() {
                      payload = null;
                      error = null;
                    });
                  }
                },
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600)),
              ],
              if (payload == null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    try {
                      final p = TimetableShare.decode(controller.text);
                      setState(() {
                        payload = p;
                        error = null;
                      });
                    } on FormatException catch (e) {
                      setState(() => error = e.message);
                    }
                  },
                  child: const Text('Preview'),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payload!.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                            '${payload!.lessons.length} lessons/week${payload!.friendCode.isNotEmpty ? ' • code ${payload!.friendCode}' : ''}'),
                        const SizedBox(height: 4),
                        Text(
                          _previewDays(payload!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (payload!.friendCode == store.profile.friendCode) ...[
                  FilledButton(
                    onPressed: () async {
                      final n =
                          await store.mergeLessons(payload!.lessons);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        showInfo(context,
                            n == 0 ? 'Already up to date.' : 'Merged $n lessons into your timetable.');
                      }
                    },
                    child: const Text('Merge into my timetable'),
                  ),
                ] else
                  FilledButton(
                    onPressed: () async {
                      final name = payload!.displayName;
                      final result =
                          await store.applySharedPayload(payload!);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        showInfo(context,
                            result == 'friend-updated'
                                ? 'Updated $name\'s timetable.'
                                : 'Added $name — shared gaps updating now.');
                      }
                    },
                    child: const Text('Add as friend'),
                  ),
                TextButton(
                  onPressed: () => setState(() {
                    payload = null;
                    controller.clear();
                  }),
                  child: const Text('Try a different code'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

String _previewDays(SharedPayload p) {
  final days = p.lessons.map((l) => l.weekday).toSet().toList()..sort();
  return days.map(weekdayShortName).join(' • ');
}
