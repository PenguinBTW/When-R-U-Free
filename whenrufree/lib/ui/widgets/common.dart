import 'package:flutter/material.dart';

/// Shared small widgets to keep screens consistent.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (buttonLabel != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onButton, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class PersonAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const PersonAvatar(this.name, {super.key, this.radius = 18});

  static Color colorFor(String name) {
    final palette = Colors.primaries;
    var h = 0;
    for (final u in name.codeUnits) {
      h = (h * 31 + u) % 997;
    }
    return palette[h % palette.length];
  }

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      return (p.isEmpty ? '?' : p[0]).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = colorFor(name);
    // Solid, bright avatars with guaranteed-contrast bold letters —
    // readable on dark sheets, cards and light surfaces alike.
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(initials,
          style: TextStyle(
              color: contrastOn(bg),
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.8)),
    );
  }
}

int timeOfDayToMin(TimeOfDay t) => t.hour * 60 + t.minute;
TimeOfDay minToTimeOfDay(int m) =>
    TimeOfDay(hour: (m ~/ 60).clamp(0, 23), minute: (m % 60).clamp(0, 59));

Future<int?> pickMinutes(
    BuildContext context, int initial, String help) async {
  final t = await showTimePicker(
    context: context,
    initialTime: minToTimeOfDay(initial),
    helpText: help,
  );
  if (t == null) return null;
  return timeOfDayToMin(t);
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Readable text color on top of an arbitrary background.
Color contrastOn(Color bg) =>
    ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;

/// Card tint for "everyone's free" highlights — the hardcoded
/// `Colors.green.shade50` this replaces is near-white and washes out in
/// dark mode (light card + light text).
Color gapHighlight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B5E20).withValues(alpha: 0.55)
        : Colors.green.shade50;

// ---------- proportional timeline tokens (week view) ----------

/// Page edge padding for the timeline.
const double kTimelineMargin = 16.0;

/// Card radius for free-time blocks.
const double kTimelineCardRadius = 16.0;

/// Minimum block height: small gaps stay tappable + readable.
const double kTimelineMinHeight = 56.0;

/// Minimum height for expanded (multi-row) blocks: the title + names rows
/// cannot fit in 56dp, so 45–85 min blocks floor here instead of overflowing.
const double kTimelineExpandedMinHeight = 112.0;

/// Maximum block height: long gaps never monopolize the screen.
const double kTimelineMaxHeight = 220.0;

/// Height of busy-time skip dividers.
const double kSkipDividerHeight = 30.0;

/// Rich "everyone free" surface. White text on this passes WCAG AA in both
/// brightness modes (unlike muddy dark greens or light greens with glow).
const Color kEveryoneCardBg = Color(0xFF2E7D32);

/// Minutes→pixels, responsive: ~1.25 at standard flagship height (800),
/// shrinking on compact phones and growing on large screens.
double timelinePxPerMin(BuildContext context) =>
    (MediaQuery.heightOf(context) * 0.0016).clamp(0.9, 1.6);

/// Proportional block height with comfort clamps.
double timelineBlockHeight(int minutes, double pxPerMin,
        {double minH = kTimelineMinHeight,
        double maxH = kTimelineMaxHeight}) =>
    (minutes * pxPerMin).clamp(minH, maxH);

/// Chip background for "free" people — dark-safe version of green.shade100.
Color freeChipBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade900
        : Colors.green.shade100;
