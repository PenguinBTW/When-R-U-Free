import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/lesson.dart';
import '../../utils/time_fmt.dart';
import '../widgets/busy_sheet.dart';
import '../widgets/common.dart';
import '../widgets/lesson_editor_sheet.dart';
import '../widgets/share_sheet.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this, initialIndex: _todayIndex());
  }

  int _todayIndex() => (DateTime.now().weekday - 1).clamp(0, 6);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _add(AppStore store, int day) {
    openLessonEditor(
      context,
      initialDay: day,
      hasOverlap: store.hasOverlap,
      onSave: store.addLesson,
    );
  }

  void _edit(AppStore store, Lesson lesson) {
    openLessonEditor(
      context,
      existing: lesson,
      initialDay: lesson.weekday,
      hasOverlap: store.hasOverlap,
      onSave: store.updateLesson,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My timetable'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: List.generate(
              7, (i) => Tab(text: weekdayShortName(i + 1))),
        ),
        actions: [
          IconButton(
            tooltip: 'Busy overrides',
            icon: Badge(
              isLabelVisible: store.busyBlocks.isNotEmpty,
              label: Text('${store.busyBlocks.length}'),
              child: const Icon(Icons.event_busy_outlined),
            ),
            onPressed: () => openBusyBlocks(context),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final day = _tabs.index + 1;
              switch (v) {
                case 'share':
                  showShareTimetable(context, store);
                case 'import_shared':
                  showImportSharedCode(context, store);
                case 'busy':
                  openBusyBlocks(context,
                      date: DateTime.now());
                case 'sample':
                  await store.loadSampleTimetable();
                  if (context.mounted) {
                    showInfo(context, 'Sample timetable loaded.');
                  }
                case 'clear_day':
                  await store.clearDay(day);
                case 'clear_all':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete all events?'),
                      content: const Text(
                          'This removes your whole timetable. Friends are kept.'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            child: const Text('Delete all')),
                      ],
                    ),
                  );
                  if (ok == true) await store.clearAllLessons();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'share', child: Text('Share my timetable')),
              PopupMenuItem(
                  value: 'import_shared',
                  child: Text('Import a shared timetable')),
              PopupMenuItem(
                  value: 'busy', child: Text('Busy overrides')),
              PopupMenuDivider(),
              PopupMenuItem(
                  value: 'sample', child: Text('Load sample timetable')),
              PopupMenuItem(value: 'clear_day', child: Text('Clear this day')),
              PopupMenuItem(value: 'clear_all', child: Text('Clear everything')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: List.generate(7, (i) {
          final day = i + 1;
          final items = store.lessonsOn(day);
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.free_breakfast_outlined,
                  title: 'Free all day ${weekdayShortName(day)}',
                  subtitle:
                      'No events on ${weekdayName(day)}. Enjoy it — or add one with +.',
                  buttonLabel: 'Add an event',
                  onButton: () => _add(store, day),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, idx) {
              final l = items[idx];
              return Dismissible(
                key: ValueKey(l.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => store.removeLesson(l.id),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: PersonAvatar.colorFor(l.subject),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(l.subject,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${formatRange(l.startMin, l.endMin)}${l.location.isNotEmpty ? ' • ${l.location}' : ''}'),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _edit(store, l),
                  ),
                ),
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(store, _tabs.index + 1),
        icon: const Icon(Icons.add),
        label: const Text('Event'),
      ),
    );
  }
}
