import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/busy_block.dart';
import '../../utils/time_fmt.dart';
import 'common.dart';

/// Manage one-off busy overrides ("I'm actually busy in that gap").
class BusyBlocksSheet extends StatelessWidget {
  final DateTime initialDate;
  const BusyBlocksSheet({super.key, required this.initialDate});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final upcoming = store.busyBlocks
        .where((b) => !BusyBlock.dateOf(b.dateKey)
            .isBefore(DateTime.now().subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) {
        final d = a.dateKey.compareTo(b.dateKey);
        return d != 0 ? d : a.startMin.compareTo(b.startMin);
      });
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text('Busy overrides',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              'One-off blocks that carve time out of shared gaps. Your weekly timetable is untouched.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No busy overrides. Gaps come straight from your timetable.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcoming.length,
                itemBuilder: (_, i) {
                  final b = upcoming[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.event_busy_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(b.title),
                      subtitle: Text(
                          '${DateFormat('EEE d MMM').format(BusyBlock.dateOf(b.dateKey))} • ${formatRange(b.startMin, b.endMin)}'),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => store.removeBusyBlock(b.id),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _openEditor(context, store),
              icon: const Icon(Icons.add),
              label: const Text('Add busy time'),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, AppStore store) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BusyEditor(initialDate: initialDate),
    );
  }
}

class _BusyEditor extends StatefulWidget {
  final DateTime initialDate;
  const _BusyEditor({required this.initialDate});

  @override
  State<_BusyEditor> createState() => _BusyEditorState();
}

class _BusyEditorState extends State<_BusyEditor> {
  late final TextEditingController _title;
  late DateTime _date;
  late int _start;
  late int _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _date = widget.initialDate;
    _start = 12 * 60 + 30;
    _end = 13 * 60 + 30;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add busy time',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What\'s on? (optional)',
                hintText: 'e.g. Dentist, shift, match',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(DateFormat('EEEE d MMM yyyy').format(_date)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final m = await pickMinutes(context, _start, 'Busy from');
                      if (m != null) {
                        setState(() {
                          _start = m;
                          if (_end <= _start) _end = _start + 60;
                        });
                      }
                    },
                    child: Text('From\n${formatMinutes(_start)}',
                        textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final m = await pickMinutes(context, _end, 'Busy until');
                      if (m != null) setState(() => _end = m);
                    },
                    child: Text('Until\n${formatMinutes(_end)}',
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final err = store.addBusyBlock(BusyBlock.create(
                  title: _title.text,
                  date: _date,
                  startMin: _start,
                  endMin: _end,
                ));
                if (err != null) {
                  setState(() => _error = err);
                  return;
                }
                Navigator.of(context).pop();
                showInfo(context, 'Busy time added.');
              },
              child: const Text('Save busy time'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openBusyBlocks(BuildContext context, {DateTime? date}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BusyBlocksSheet(initialDate: date ?? DateTime.now()),
  );
}
