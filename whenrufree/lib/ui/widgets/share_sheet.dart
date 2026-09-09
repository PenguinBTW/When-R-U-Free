import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_store.dart';
import '../../services/timetable_share.dart';
import '../widgets/common.dart';

/// QR capacity guard: byte-mode max is ~2953 chars at version 40-L, but big
/// codes scan poorly on cheap cameras — steer to text above ~1800 chars.
bool qrFriendly(String code) => code.length <= 1800;

/// Shows MY timetable as a scannable QR code, with a "can't scan" text
/// fallback (as long as needed) for chat apps.
Future<void> showShareTimetable(BuildContext context, AppStore store) {
  if (store.lessons.isEmpty) {
    showInfo(context, 'Add some events first, then share.');
    return Future.value();
  }
  final name = store.profile.displayName.trim().isEmpty
      ? 'Shared friend'
      : store.profile.displayName.trim();
  final code = TimetableShare.encode(
    displayName: name,
    friendCode: '',
    college: store.profile.college,
    lessons: store.lessons,
  );
  final text =
      'Here\'s my When R U Free timetable! In the app go to Friends → Import and paste this:\n\n$code';
  final fitsQr = qrFriendly(code);
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ShareBody(
      name: name,
      lessonCount: store.lessons.length,
      code: code,
      text: text,
      fitsQr: fitsQr,
    ),
  );
}

class _ShareBody extends StatefulWidget {
  final String name;
  final int lessonCount;
  final String code;
  final String text;
  final bool fitsQr;
  const _ShareBody({
    required this.name,
    required this.lessonCount,
    required this.code,
    required this.text,
    required this.fitsQr,
  });

  @override
  State<_ShareBody> createState() => _ShareBodyState();
}

class _ShareBodyState extends State<_ShareBody> {
  // Start on text when the payload is too dense to scan reliably.
  late bool _showText = !widget.fitsQr;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: SingleChildScrollView(
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
              '${widget.name} • ${widget.lessonCount} events • works offline, no account needed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (!_showText) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest),
                  ),
                  child: QrImageView(
                    data: widget.code,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your mate scans this from Friends → Scan QR.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showText = true),
                icon: const Icon(Icons.text_fields_outlined),
                label: const Text("Can't scan? Send as text"),
              ),
            ] else ...[
              if (!widget.fitsQr)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  margin: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Big timetable — too dense for a reliable QR, so here it is as text (as long as it needs to be).',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              if (!widget.fitsQr) const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(widget.code,
                      style:
                          const TextStyle(fontSize: 12, height: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.code));
                        Navigator.of(context).pop();
                        showInfo(context, 'Share text copied.');
                      },
                      child: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => SharePlus.instance.share(
                          ShareParams(
                              text: widget.text,
                              subject: 'My timetable')),
                      child: const Text('Share'),
                    ),
                  ),
                ],
              ),
              if (widget.fitsQr) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _showText = false),
                  child: const Text('Back to QR code'),
                ),
              ],
            ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastes a friend's share text (the "can't scan" path — scanning lives in
/// the Scan screen). Matches by name: updates that friend or adds them.
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
          child: SingleChildScrollView(
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
                  'Paste the text your friend sent. If you already have a friend with that name, their timetable is updated.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Share text (WRF1-…)',
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
                  color:
                      Theme.of(context).colorScheme.primaryContainer,
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
                            '${payload!.lessons.length} events/week'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    final result = await store
                        .applySharedPayloadOffline(payload!);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      final name = result.split(':').last;
                      showInfo(context,
                          result.startsWith('updated:')
                              ? 'Updated $name\'s timetable.'
                              : 'Added $name — shared gaps updating now.');
                    }
                  },
                  child: const Text('Add / update friend'),
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
    ),
  );
}
