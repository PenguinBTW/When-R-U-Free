import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../widgets/common.dart';
import '../widgets/detail_sheets.dart';
import '../widgets/share_sheet.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeController = TextEditingController();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _add(AppStore store) async {
    setState(() {
      _adding = true;
      _error = null;
    });
    final err = await store.addFriendByCode(_codeController.text);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _error = err;
      if (err == null) _codeController.clear();
    });
    if (err == null) showInfo(context, 'Friend added.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // My code card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('MY FRIEND CODE',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(letterSpacing: 2)),
                  const SizedBox(height: 4),
                  SelectableText(store.profile.friendCode,
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                              fontWeight: FontWeight.bold, letterSpacing: 6)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: store.profile.friendCode));
                          showInfo(context, 'Code copied.');
                        },
                        child: const Text('Copy'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => showShareCode(context,
                            store.profile.displayName, store.profile.friendCode),
                        child: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionTitle('Add a friend'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Friend code',
                            hintText: 'e.g. KQ7X2P',
                            border: OutlineInputBorder(),
                            counterText: '',
                            prefixIcon:
                                Icon(Icons.person_add_alt_outlined),
                          ),
                          onSubmitted: (_) => _add(store),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _adding ? null : () => _add(store),
                        child: _adding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Add'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        showImportSharedCode(context, store),
                    icon: const Icon(Icons.qr_code_2_outlined),
                    label: const Text(
                        'Import a shared timetable instead'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Got a WRF1-… code in chat? Import it to add that friend with their REAL timetable. '
                    'Any other 6-character code adds a demo friend until cloud lookup is enabled.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          SectionTitle('Your group (${store.friends.length})',
              actionLabel: store.friends.isEmpty ? 'Try demo friends' : null,
              onAction: () async {
                await store.addStarterFriends();
                if (context.mounted) showInfo(context, 'Demo friends added.');
              }),
          if (store.friends.isEmpty)
            EmptyState(
              icon: Icons.group_outlined,
              title: 'No friends yet',
              subtitle:
                  'Add friends by code above, or load two demo friends to see how shared breaks work.',
              buttonLabel: 'Add demo friends',
              onButton: () => store.addStarterFriends(),
            )
          else
            ...store.friends.map((f) => Card(
                  child: ListTile(
                    leading: PersonAvatar(f.displayName, radius: 22),
                    title: Text(f.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${f.friendCode} • ${f.lessons.length} lessons/week'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: f.included,
                          onChanged: (_) =>
                              store.toggleFriendIncluded(f.id),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'view') {
                              showFriendTimetable(context, f);
                            } else if (v == 'remove') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text('Remove ${f.displayName}?'),
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
                              if (ok == true) {
                                await store.removeFriend(f.id);
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'view',
                                child: Text('View timetable')),
                            PopupMenuItem(
                                value: 'remove', child: Text('Remove')),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => showFriendTimetable(context, f),
                  ),
                )),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tip: use the toggle to temporarily exclude someone from comparisons without removing them.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
