import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/lesson.dart';
import '../../utils/time_fmt.dart';
import '../widgets/common.dart';
import '../widgets/lesson_editor_sheet.dart';

/// View + edit one friend: rename, and add/edit/remove THEIR events.
/// (Adding "a timetable" always happens under a picked friend name.)
class FriendDetailSheet extends StatelessWidget {
  final String friendId;
  const FriendDetailSheet({super.key, required this.friendId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final friend = store.friendById(friendId);
    if (friend == null) {
      // Deleted elsewhere — close quietly on next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    bool friendOverlap(Lesson candidate, {String? ignoreId}) {
      return friend.lessons.any((l) =>
          l.id != ignoreId &&
          l.weekday == candidate.weekday &&
          candidate.startMin < l.endMin &&
          l.startMin < candidate.endMin);
    }

    void addEvent(int day) {
      openLessonEditor(
        context,
        initialDay: day,
        hasOverlap: friendOverlap,
        onSave: (l) => store.addFriendLesson(friend.id, l),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        // Whole sheet scrolls; the lesson list below is shrink-wrapped and
        // never scrolls itself (nested scrollables overflowed with 5+ events).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              children: [
                PersonAvatar(friend.displayName, radius: 24),
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
                      Text(
                          '${friend.lessons.length} events/week${friend.demoData ? ' • SAMPLE' : ''}'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _rename(context, store),
                ),
              ],
            ),
            if (friend.demoData) ...[
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                margin: EdgeInsets.zero,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'Sample timetable. Scan their QR (or edit below) for real gaps.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (friend.lessons.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'No events yet — add their timetable below, or scan their QR.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: friend.lessons.length,
                      itemBuilder: (_, i) {
                        final l = friend.lessons[i];
                        return Card(
                          margin:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: ListTile(
                            dense: true,
                            title: Text(
                                '${weekdayShortName(l.weekday)} • ${l.subject}'),
                            subtitle: Text(formatRange(
                                l.startMin, l.endMin)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 20),
                                  onPressed: () => openLessonEditor(
                                    context,
                                    existing: l,
                                    initialDay: l.weekday,
                                    hasOverlap: friendOverlap,
                                    onSave: (u) => store.updateFriendLesson(
                                        friend.id, u),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20),
                                  onPressed: () =>
                                      store.removeFriendLesson(
                                          friend.id, l.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => addEvent(DateTime.now().weekday),
              icon: const Icon(Icons.add),
              label: const Text('Add event'),
            ),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Remove ${friend.displayName}?'),
                    content: const Text(
                        'You will stop comparing timetables with them.'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(true),
                          child: const Text('Remove')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  Navigator.of(context).pop();
                  await store.removeFriend(friend.id);
                }
              },
              child: Text('Remove friend',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, AppStore store) {
    final friend = store.friendById(friendId);
    final controller =
        TextEditingController(text: friend?.displayName ?? '');
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename friend'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final err =
                  await store.renameFriend(friendId, controller.text);
              if (context.mounted) {
                if (err != null) {
                  showInfo(context, err);
                } else {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

Future<void> openFriendDetail(BuildContext context, String friendId) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => FriendDetailSheet(friendId: friendId),
  );
}
