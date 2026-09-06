import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../utils/time_fmt.dart';
import 'common.dart';

/// Bottom sheet to create or edit a lesson. Returns via [onSave] with
/// `null` error on success, or shows the error inline.
class LessonEditorSheet extends StatefulWidget {
  final Lesson? existing;
  final int initialDay;
  final bool Function(Lesson candidate, {String? ignoreId}) hasOverlap;
  final String? Function(Lesson lesson) onSave;

  const LessonEditorSheet({
    super.key,
    this.existing,
    required this.initialDay,
    required this.hasOverlap,
    required this.onSave,
  });

  @override
  State<LessonEditorSheet> createState() => _LessonEditorSheetState();
}

class _LessonEditorSheetState extends State<LessonEditorSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _location;
  late int _day;
  late int _start;
  late int _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _subject = TextEditingController(text: e?.subject ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _day = e?.weekday ?? widget.initialDay;
    _start = e?.startMin ?? 9 * 60;
    _end = e?.endMin ?? 10 * 60;
  }

  @override
  void dispose() {
    _subject.dispose();
    _location.dispose();
    super.dispose();
  }

  void _save() {
    final lesson = (widget.existing ??
            Lesson.create(
                subject: 'x', weekday: 1, startMin: 0, endMin: 5))
        .copyWith(
      subject: _subject.text,
      weekday: _day,
      startMin: _start,
      endMin: _end,
      location: _location.text,
    );
    final err = widget.onSave(lesson);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final overlaps = widget.hasOverlap(
      Lesson.create(
          subject: _subject.text.isEmpty ? 'x' : _subject.text,
          weekday: _day,
          startMin: _start,
          endMin: _end),
      ignoreId: widget.existing?.id,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.existing == null ? 'Add lesson' : 'Edit lesson',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subject,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  hintText: 'e.g. Maths',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _day,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                items: List.generate(
                  7,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(weekdayName(i + 1)),
                  ),
                ),
                onChanged: (v) => setState(() => _day = v ?? _day),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final m = await pickMinutes(
                            context, _start, 'Lesson starts');
                        if (m != null) {
                          setState(() {
                            _start = m;
                            if (_end <= _start) _end = _start + 60;
                          });
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: Text('Starts\n${formatMinutes(_start)}',
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final m =
                            await pickMinutes(context, _end, 'Lesson ends');
                        if (m != null) setState(() => _end = m);
                      },
                      icon: const Icon(Icons.logout),
                      label: Text('Ends\n${formatMinutes(_end)}',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Room (optional)',
                  hintText: 'e.g. M2, Lab 1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.room_outlined),
                ),
              ),
              if (overlaps) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 16,
                        color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Overlaps another lesson on this day — saving is allowed, but check the times.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: Text(widget.existing == null
                    ? 'Add lesson'
                    : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openLessonEditor(
  BuildContext context, {
  Lesson? existing,
  required int initialDay,
  required bool Function(Lesson candidate, {String? ignoreId}) hasOverlap,
  required String? Function(Lesson lesson) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => LessonEditorSheet(
      existing: existing,
      initialDay: initialDay,
      hasOverlap: hasOverlap,
      onSave: onSave,
    ),
  );
}
