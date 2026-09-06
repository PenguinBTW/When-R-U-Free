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
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg.withValues(alpha: 0.18),
      child: Text(initials,
          style: TextStyle(
              color: bg is MaterialColor ? bg.shade700 : bg,
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
