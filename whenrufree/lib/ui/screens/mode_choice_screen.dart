import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../widgets/common.dart';
import 'graph_import_screen.dart';

/// First-launch mode choice: Sync (recommended) or Offline.
///
/// Sync is the vision but the cloud side isn't built yet, so tapping it
/// opens an honest coming-soon sheet that maps what's ALREADY usable today
/// (Microsoft 365 import, peer-to-peer sharing) and routes into offline.
class ModeChoiceScreen extends StatelessWidget {
  const ModeChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.groups,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('When R U Free',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'See every break you share with friends between lessons. Pick how you want to run it:',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  _ModeCard(
                    icon: Icons.cloud_sync_outlined,
                    title: 'Sync',
                    badge: 'RECOMMENDED',
                    highlighted: true,
                    points: const [
                      'Timetable changes update for all friends automatically',
                      'Pulls classes from your calendars',
                      'Same account on every device',
                    ],
                    buttonLabel: 'Choose Sync',
                    onTap: () => showSyncComingSoon(context),
                  ),
                  const SizedBox(height: 12),
                  _ModeCard(
                    icon: Icons.phonelink_lock_outlined,
                    title: 'Offline',
                    badge: null,
                    highlighted: false,
                    points: const [
                      'Complete privacy — everything stays on this phone',
                      'Quick QR sharing with mates',
                      'Changes won\'t reach friends automatically',
                    ],
                    buttonLabel: 'Choose Offline',
                    onTap: () async {
                      await context
                          .read<AppStore>()
                          .setAppMode(AppMode.offline);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final bool highlighted;
  final List<String> points;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.highlighted,
    required this.points,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: highlighted ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highlighted
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide.none,
      ),
      color: highlighted ? cs.primaryContainer.withValues(alpha: 0.35) : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: highlighted
                          ? cs.onPrimary
                          : cs.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: cs.onPrimary)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...points.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p)),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onTap,
              style: highlighted
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest,
                      foregroundColor: cs.onSurface),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coming-soon sheet for Sync: honest about what's live today vs gated.
Future<void> showSyncComingSoon(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: SingleChildScrollView(
          key: const ValueKey('syncSheetScroll'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text('Sync is almost here',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'The full cloud sync (automatic updates across friends, friend-code lookup) still needs its server keys — it\'s not in this test build. But parts of the sync story already work:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _SyncRow(
              icon: Icons.calendar_month_outlined,
              title: 'Calendar auto-sync — ready now',
              subtitle:
                  'Sign in with Microsoft and pull this week\'s classes straight in.',
              actionLabel: 'Try it',
              onAction: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GraphImportScreen()));
              },
            ),
            _SyncRow(
              icon: Icons.qr_code_2_outlined,
              title: 'Peer-to-peer sharing — ready now',
              subtitle:
                  'QR and text codes already carry timetables phone-to-phone, no account.',
              actionLabel: null,
              onAction: null,
            ),
            _SyncRow(
              icon: Icons.cloud_upload_outlined,
              title: 'Automatic friend updates — coming soon',
              subtitle:
                  'Needs the cloud database. Your vote for it is counted.',
              actionLabel: null,
              onAction: null,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await context.read<AppStore>().setAppMode(AppMode.offline);
                if (context.mounted) {
                  showInfo(context,
                      'Offline mode on — you can switch to Sync later in Settings.');
                }
              },
              child: const Text('Continue offline for now'),
            ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SyncRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SyncRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon,
            color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: actionLabel == null
            ? null
            : FilledButton.tonal(
                onPressed: onAction, child: Text(actionLabel!)),
      ),
    );
  }
}
