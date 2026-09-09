import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../screens/scan_screen.dart';
import '../widgets/common.dart';
import '../widgets/friend_detail_sheet.dart';
import '../widgets/share_sheet.dart';

/// Offline group management: friends are just names + timetables.
/// No codes — timetables arrive by QR scan, pasted share text, or manual
/// entry under the friend's name.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _nameController = TextEditingController();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _add(AppStore store) async {
    final name = _nameController.text.trim();
    setState(() {
      _adding = true;
      _error = null;
    });
    final err = await store.addFriendByName(name);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _error = err;
      if (err == null) _nameController.clear();
    });
    if (err != null) return;
    final friend = store.friends.firstWhere(
        (f) => f.displayName.trim().toLowerCase() == name.toLowerCase());
    if (!mounted) return;
    final next = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add $name\'s timetable?'),
        content: const Text(
            'Gaps only work with their events in. Scan their QR, paste their share text, or type it in.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop('later'),
              child: const Text('Later')),
          TextButton(
              onPressed: () => Navigator.of(context).pop('scan'),
              child: const Text('Scan QR')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop('manual'),
              child: const Text('Enter it')),
        ],
      ),
    );
    if (!mounted) return;
    if (next == 'manual') {
      openFriendDetail(context, friend.id);
    } else if (next == 'scan') {
      final res = await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ScanScreen()));
      if (res == 'paste' && mounted) {
        showImportSharedCode(context, store);
      }
    }
  }

  Future<void> _scan(AppStore store) async {
    final res = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (res == 'paste' && mounted) {
      showImportSharedCode(context, store);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
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
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          decoration: const InputDecoration(
                            labelText: "Friend's name",
                            hintText: 'e.g. Ava',
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _scan(store),
                          icon:
                              const Icon(Icons.qr_code_scanner_outlined),
                          label: const Text('Scan QR'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              showImportSharedCode(context, store),
                          icon: const Icon(Icons.paste_outlined),
                          label: const Text('Paste code'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Their timetable arrives by scanning their QR, pasting their share text — or type it in under their name. Nothing leaves this phone.',
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
                if (context.mounted) {
                  showInfo(context,
                      'Demo friends added (sample timetables).');
                }
              }),
          if (store.friends.isEmpty)
            EmptyState(
              icon: Icons.group_outlined,
              title: 'No friends yet',
              subtitle:
                  'Add friends by name above, or load demo friends to see how shared gaps work.',
              buttonLabel: 'Add demo friends',
              onButton: () => store.addStarterFriends(),
            )
          else ...[
            if (store.friends.any((f) => f.demoData))
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .tertiaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Friends marked SAMPLE use placeholder timetables — gaps with them are previews. Scan their QR or type in their real events.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ...store.friends.map((f) => Card(
                  child: ListTile(
                    leading: PersonAvatar(f.displayName, radius: 22),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(f.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (f.demoData) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('SAMPLE',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer)),
                          ),
                        ],
                      ],
                    ),
                    subtitle:
                        Text('${f.lessons.length} events/week'),
                    trailing: Switch(
                      value: f.included,
                      onChanged: (_) =>
                          store.toggleFriendIncluded(f.id),
                    ),
                    onTap: () => openFriendDetail(context, f.id),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tap a friend to edit their timetable. Use the toggle to pause comparisons without removing them.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
