import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/cloud_config.dart';
import '../../data/app_store.dart';
import '../../firebase_options.dart';
import '../../services/notification_service.dart';
import '../../utils/time_fmt.dart';
import '../widgets/common.dart';
import 'graph_import_screen.dart';
import 'mode_choice_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _name;
  late TextEditingController _college;
  bool _init = false;

  @override
  void dispose() {
    _name.dispose();
    _college.dispose();
    super.dispose();
  }

  void _ensure(AppStore store) {
    if (_init) return;
    _init = true;
    _name = TextEditingController(text: store.profile.displayName);
    _college = TextEditingController(text: store.profile.college);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    _ensure(store);

    final cloudOn =
        kCloudBackendEnabled && DefaultFirebaseOptions.isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          SectionTitle('Profile'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      PersonAvatar(
                          store.profile.displayName.isEmpty
                              ? '?'
                              : store.profile.displayName,
                          radius: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                store.profile.displayName.isEmpty
                                    ? 'Unnamed student'
                                    : store.profile.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            Text(store.appMode == AppMode.sync
                                ? 'Sync mode'
                                : 'Offline mode — private to this phone'),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => showSyncComingSoon(context),
                        child: Text(store.appMode == AppMode.sync
                            ? 'Sync info'
                            : 'Try Sync'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onSubmitted: (v) {
                      store.updateProfile(displayName: v);
                      showInfo(context, 'Name saved.');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _college,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Sixth form / college / uni (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    onSubmitted: (v) {
                      store.updateProfile(college: v);
                      showInfo(context, 'Saved.');
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        store.updateProfile(
                          displayName: _name.text,
                          college: _college.text,
                        );
                        showInfo(context, 'Profile saved.');
                      },
                      child: const Text('Save profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionTitle('Day window'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Only look for free time between ${formatMinutes(store.windowStartMin)} and ${formatMinutes(store.windowEndMin)}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final m = await pickMinutes(context,
                                store.windowStartMin, 'Day starts');
                            if (m != null) {
                              await store.setWindow(
                                  m, store.windowEndMin);
                            }
                          },
                          child: Text(
                              'Start\n${formatMinutes(store.windowStartMin)}',
                              textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final m = await pickMinutes(context,
                                store.windowEndMin, 'Day ends');
                            if (m != null) {
                              await store.setWindow(
                                  store.windowStartMin, m);
                            }
                          },
                          child: Text(
                              'End\n${formatMinutes(store.windowEndMin)}',
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionTitle('Sync & import'),
          Card(
            child: ListTile(
              leading: Icon(
                cloudOn ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(cloudOn
                  ? 'Cloud sync: ON'
                  : 'Cloud sync: OFF (local-only mode)'),
              subtitle: Text(cloudOn
                  ? 'Firebase Auth + Firestore active.'
                  : 'Running offline. Add Firebase keys to enable sharing across devices — see setup guide.'),
              onTap: () => _cloudInfo(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Import from Microsoft 365'),
              subtitle: const Text(
                  'Sign in with Microsoft, pick a username, pull in this week\'s classes. Manual entry keeps working too.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const GraphImportScreen())),
            ),
          ),
          SectionTitle('Gap alerts'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Notify before shared breaks'),
                  subtitle: const Text(
                      'A heads-up naming who else is free, before each shared gap.'),
                  value: store.gapAlertsEnabled,
                  onChanged: (v) => store.setGapAlerts(v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Remind me before'),
                  trailing: DropdownButton<int>(
                    value: [0, 5, 10, 15, 30]
                            .contains(store.reminderMinBefore)
                        ? store.reminderMinBefore
                        : 10,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('At start')),
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                      DropdownMenuItem(value: 10, child: Text('10 min')),
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                    ],
                    onChanged: (v) {
                      if (v != null) store.setReminderMinBefore(v);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: const Text('Send a test notification'),
                  subtitle: const Text(
                      'Checks alerts work on this device right now.'),
                  onTap: () async {
                    final ok = await NotificationService.instance
                        .requestPermission();
                    await NotificationService.instance.showNow(
                      title: 'Gap alerts are working 🎉',
                      body:
                          'You\'ll be notified before breaks friends share with you.',
                    );
                    if (context.mounted && !ok) {
                      showInfo(context,
                          'System permission was not granted — enable notifications in system settings.');
                    }
                  },
                ),
              ],
            ),
          ),
          SectionTitle('Backup'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text('Export backup'),
                  subtitle:
                      const Text('Copy or share your data as JSON.'),
                  onTap: () {
                    final json = store.exportJson();
                    Clipboard.setData(ClipboardData(text: json));
                    SharePlus.instance.share(ShareParams(
                        text: json, subject: 'When R U Free backup'));
                    showInfo(context, 'Backup copied + share sheet opened.');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('Import backup'),
                  subtitle: const Text('Paste a previously exported JSON.'),
                  onTap: () => _importDialog(context, store),
                ),
              ],
            ),
          ),
          SectionTitle('Developer'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.bug_report_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Add 5 demo friends'),
                  subtitle: const Text(
                      'Jess, Tim, Ava, Leo + Mia with sample timetables, for testing gaps. Skips names you already have.'),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      final added = await store.addDemoFriends();
                      if (context.mounted) {
                        showInfo(context,
                            added == 0
                                ? 'Demo friends already here.'
                                : 'Added $added demo friend${added == 1 ? '' : 's'}.');
                      }
                    },
                    child: const Text('Add'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Remove demo friends'),
                  subtitle: const Text(
                      'Clears all sample-timetable friends.'),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      final removed =
                          await store.removeDemoFriends();
                      if (context.mounted) {
                        showInfo(context,
                            removed == 0
                                ? 'No demo friends to remove.'
                                : 'Removed $removed demo friend${removed == 1 ? '' : 's'}.');
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle('About'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'When R U Free — find when friends between lessons are free.\n\n'
                'Offline mode: manual + Microsoft 365 timetable entry, QR sharing, mutual-break comparison.\n'
                'Roadmap: cloud sync with automatic friend updates.\n\n'
                'Source-available under the Vio License.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reset everything?'),
                    content: const Text(
                        'Deletes your profile, timetable and friends on this device.'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(true),
                          child: const Text('Reset')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await store.resetAll();
                  if (context.mounted) {
                    showInfo(context, 'Reset done.');
                    setState(() => _init = false);
                  }
                }
              },
              child: Text('Reset all data',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ),
          Center(
            child: Text('When R U Free v1.0.0 • local-first MVP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  void _cloudInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cloud sync status'),
        content: const Text(
          'LOCAL-ONLY MODE (default)\n'
          'Everything is stored on this device — no account needed.\n\n'
          'TO ENABLE FIREBASE SHARING:\n'
          '1. Owner creates a free Firebase project (Spark plan: Auth + Firestore, no billing).\n'
          '2. Run `flutterfire configure` (or paste keys into lib/firebase_options.dart).\n'
          '3. Set kCloudBackendEnabled = true in lib/config/cloud_config.dart.\n'
          '4. Add google-services.json / GoogleService-Info.plist.\n'
          '5. Re-run: anonymous sign-in + Firestore sync activate automatically.\n\n'
          'The sync code is already written (FirestoreDataStore) — it just needs keys.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it')),
        ],
      ),
    );
  }

  void _importDialog(BuildContext context, AppStore store) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import backup'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste backup JSON here…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final err = await store.importJson(controller.text);
              if (context.mounted) {
                Navigator.of(context).pop();
                showInfo(context,
                    err ?? 'Backup imported.');
                if (err == null) setState(() => _init = false);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
