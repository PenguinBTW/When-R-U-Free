import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../services/timetable_share.dart';
import '../widgets/common.dart';

/// Camera scanner for a friend's timetable QR. On a successful decode it
/// shows a preview (add / update by name); anything else shows an error and
/// keeps scanning. Paste-import stays available as a fallback.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue ?? '')
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;
    SharedPayload? payload;
    try {
      payload = TimetableShare.decode(raw);
    } on FormatException {
      if (mounted) {
        showInfo(context,
            'That QR isn\'t a When R U Free timetable — keep pointing at their share code.');
      }
      return;
    }
    _handled = true;
    _controller.stop();
    _confirm(payload);
  }

  Future<void> _confirm(SharedPayload payload) async {
    final store = context.read<AppStore>();
    final existing = store.friends.any((f) =>
        f.displayName.trim().toLowerCase() ==
        payload.displayName.trim().toLowerCase());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing ? 'Update timetable?' : 'Add friend?'),
        content: Text(existing
            ? '${payload.displayName} is already in your group — replace their timetable with this scan (${payload.lessons.length} events)?'
            : 'Add ${payload.displayName} with ${payload.lessons.length} events/week and start comparing gaps?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(existing ? 'Update' : 'Add')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      final result = await store.applySharedPayloadOffline(payload);
      if (mounted) {
        Navigator.of(context).pop();
        final name = result.split(':').last;
        showInfo(context,
            result.startsWith('updated:')
                ? 'Updated $name\'s timetable.'
                : 'Added $name — shared gaps updating now.');
      }
    } else {
      setState(() => _handled = false);
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan timetable QR')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.no_photography_outlined,
                              size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Camera unavailable — allow camera access in system settings, or import their share text instead.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () =>
                                Navigator.of(context).pop('paste'),
                            child: const Text('Paste share text'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Viewfinder frame.
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Point at your friend\'s share QR (Timetable → Share on their phone).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
