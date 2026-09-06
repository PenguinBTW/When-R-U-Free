import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_store.dart';
import '../../models/lesson.dart';
import '../../services/graph/graph_auth.dart';
import '../../services/graph/graph_calendar.dart';
import '../../utils/time_fmt.dart';
import '../widgets/common.dart';

enum _Step { setup, connect, username, review }

/// Microsoft 365 import wizard: setup → connect → username → review.
///
/// Manual entry stays available throughout (Timetable tab) — this screen is
/// purely additive. Without an Azure client ID the wizard runs in demo
/// preview mode so the flow is tryable end-to-end.
class GraphImportScreen extends StatefulWidget {
  const GraphImportScreen({super.key});

  @override
  State<GraphImportScreen> createState() => _GraphImportScreenState();
}

class _GraphImportScreenState extends State<GraphImportScreen> {
  _Step _step = _Step.setup;
  bool _loading = true;
  bool _working = false;
  String? _error;
  bool _signedIn = false;
  bool _demoMode = false;

  final _clientId = TextEditingController();
  final _username = TextEditingController();
  final _pasteUrl = TextEditingController();
  bool _showPasteFallback = false;

  GraphProfile? _msProfile;
  List<Lesson> _found = [];
  late List<bool> _checked;
  int _skippedAllDay = 0;
  int _skippedFree = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _clientId.dispose();
    _username.dispose();
    _pasteUrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final configured = await GraphAuth.instance.isConfigured();
    final signedIn = configured && await GraphAuth.instance.isSignedIn();
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _loading = false;
      _step = !configured
          ? _Step.setup
          : signedIn
              ? _Step.username
              : _Step.connect;
    });
    if (signedIn) await _loadMsProfile(silent: true);
  }

  Future<void> _fail(Object e) async {
    if (!mounted) return;
    setState(() {
      _working = false;
      _error = e is GraphAuthException ? e.message : 'Something went wrong: $e';
    });
  }

  // ---------- setup ----------

  Future<void> _saveClientId() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await GraphAuth.instance.setClientIdOverride(_clientId.text);
      final configured = await GraphAuth.instance.isConfigured();
      final signedIn = configured && await GraphAuth.instance.isSignedIn();
      if (!mounted) return;
      setState(() {
        _signedIn = signedIn;
        _working = false;
        _step = !configured
            ? _Step.setup
            : signedIn
                ? _Step.username
                : _Step.connect;
      });
      if (signedIn) await _loadMsProfile(silent: true);
    } catch (e) {
      await _fail(e);
    }
  }

  // ---------- connect ----------

  Future<void> _connect() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final code = await GraphAuth.instance.signInInteractive();
      await GraphAuth.instance.exchangeCode(code: code);
      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _demoMode = false;
      });
      await _loadMsProfile();
    } catch (e) {
      await _fail(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openBrowserOnly() async {
    try {
      final req = await GraphAuth.instance.buildAuthorizeRequest();
      await launchUrl(req.url, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _showPasteFallback = true);
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> _pasteContinue() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final code =
          GraphAuth.instance.parseCodeFromRedirectUrl(_pasteUrl.text);
      await GraphAuth.instance.exchangeCode(code: code);
      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _demoMode = false;
      });
      await _loadMsProfile();
    } catch (e) {
      await _fail(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _loadMsProfile({bool silent = false}) async {
    try {
      final p = await GraphCalendar.instance.fetchProfile();
      if (!mounted) return;
      final store = context.read<AppStore>();
      _msProfile = p;
      if (_username.text.trim().isEmpty) {
        _username.text = store.profile.displayName.trim().isEmpty
            ? p.displayName
            : store.profile.displayName;
      }
      setState(() {
        _working = false;
        _step = _Step.username;
      });
    } catch (e) {
      if (silent) {
        // Stored refresh token is dead (revoked/expired) — ask to reconnect.
        await GraphAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _signedIn = false;
            _working = false;
            _step = _Step.connect;
          });
        }
      } else {
        await _fail(e);
      }
    }
  }

  Future<void> _disconnect() async {
    await GraphAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _msProfile = null;
      _step = _Step.connect;
    });
    showInfo(context, 'Microsoft disconnected.');
  }

  // ---------- username ----------

  Future<void> _saveUsernameAndFetch() async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'Pick a username so friends recognise you.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final store = context.read<AppStore>();
      if (store.profile.displayName.trim() != _username.text.trim()) {
        await store.updateProfile(displayName: _username.text);
      }
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      if (_demoMode) {
        final events = GraphCalendar.instance.demoEventsForWeek(monday);
        _found = GraphCalendar.instance.eventsToLessons(events);
        _skippedAllDay = 1;
        _skippedFree = 0;
      } else {
        final result = await GraphCalendar.instance.fetchWeekEvents(monday);
        _found = GraphCalendar.instance.eventsToLessons(result.events);
        _skippedAllDay = result.skippedAllDay;
        _skippedFree = result.skippedFree;
      }
      _checked = List<bool>.filled(_found.length, true);
      if (!mounted) return;
      setState(() {
        _working = false;
        _step = _Step.review;
      });
      if (_found.isEmpty && mounted) {
        setState(() => _error =
            'No classes found this week. Your calendar may be empty, or everything is marked Free/all-day.');
      }
    } catch (e) {
      await _fail(e);
    }
  }

  // ---------- review / import ----------

  Future<void> _import() async {
    final selected = [
      for (var i = 0; i < _found.length; i++)
        if (_checked[i]) _found[i],
    ];
    if (selected.isEmpty) {
      setState(() => _error = 'Tick at least one class to import.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final added = await context.read<AppStore>().mergeLessons(selected);
      if (!mounted) return;
      Navigator.of(context).pop();
      showInfo(context,
          added == 0 ? 'Already up to date — nothing new.' : 'Imported $added classes 🎉');
    } catch (e) {
      await _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Microsoft 365'),
        actions: [
          if (_signedIn && !_demoMode)
            TextButton(
                onPressed: _working ? null : _disconnect,
                child: const Text('Disconnect')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _StepIndicator(step: _step, demo: _demoMode),
                const SizedBox(height: 12),
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!)),
                        ],
                      ),
                    ),
                  ),
                if (_step == _Step.setup) _setupCard(),
                if (_step == _Step.connect) _connectCard(),
                if (_step == _Step.username) _usernameCard(),
                if (_step == _Step.review) _reviewCard(),
              ],
            ),
    );
  }

  Widget _setupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Connect your school calendar',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Sign in with Microsoft (read-only calendar access) and pull this week\'s classes in. '
              'Manual entry keeps working — import just saves typing.\n\n'
              'Privacy: only a login refresh key is stored on this device. Timetable events are fetched when you ask and saved only when you tap Import.',
            ),
            const SizedBox(height: 12),
            Text('Option A — live import (2 min, once)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Text(
              '1. entra.microsoft.com → App registrations → New registration.\n'
              '2. Account type: any directory + personal accounts.\n'
              '3. Redirect URI → Mobile/desktop → add:  whenrufree://auth\n'
              '4. API permissions → add Calendars.Read (delegated).\n'
              '5. Paste the Application (client) ID below.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clientId,
              decoration: const InputDecoration(
                labelText: 'Application (client) ID',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _working ? null : _saveClientId,
              child: _working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save & continue'),
            ),
            const Divider(height: 28),
            Text('Option B — try it now, no setup',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Text(
                'Preview the whole flow with sample calendar data. Nothing is saved until you import.'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                final store = context.read<AppStore>();
                _username.text = store.profile.displayName;
                setState(() {
                  _demoMode = true;
                  _step = _Step.username;
                  _error = null;
                });
              },
              child: const Text('Continue with demo preview'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sign in with Microsoft',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Your browser opens Microsoft login. The app asks only for: sign you in, keep you signed in, and read your calendars. Approve, and you\'ll bounce straight back here.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _working ? null : _connect,
              icon: const Icon(Icons.login),
              label: _working
                  ? const Text('Waiting for browser…')
                  : const Text('Connect Microsoft'),
            ),
            TextButton(
              onPressed: _openBrowserOnly,
              child: const Text('Browser didn\'t return? Open link + paste URL'),
            ),
            if (_showPasteFallback) ...[
              TextField(
                controller: _pasteUrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Paste the full redirect URL here',
                  hintText: 'whenrufree://auth?code=…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _working ? null : _pasteContinue,
                child: const Text('Continue with pasted URL'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: ''));
                setState(() {
                  _demoMode = true;
                  _step = _Step.username;
                  _error = null;
                });
              },
              child: const Text('Use demo preview instead'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _usernameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What should friends call you?',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_msProfile != null)
              Text(
                'Signed in as ${_msProfile!.displayName}${_msProfile!.mail.isNotEmpty ? ' (${_msProfile!.mail})' : ''}. '
                'This username is what shows next to your timetable.',
              )
            else
              const Text(
                  'Demo preview — pick any username to see how it works.'),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Username *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              onSubmitted: (_) => _saveUsernameAndFetch(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _working ? null : _saveUsernameAndFetch,
              child: _working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Fetch my classes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week of ${DateFormat('d MMM').format(monday)} — ${_found.length} classes found',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_skippedAllDay > 0 || _skippedFree > 0)
                  Text(
                    'Skipped: $_skippedAllDay all-day, $_skippedFree marked Free.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 4),
                const Text(
                    'Untick anything you don\'t want (free periods, lunch). Duplicates of lessons you already have are skipped automatically.'),
              ],
            ),
          ),
        ),
        ...List.generate(_found.length, (i) {
          final l = _found[i];
          return Card(
            child: CheckboxListTile(
              value: _checked[i],
              onChanged: (v) => setState(() => _checked[i] = v ?? true),
              title: Text(l.subject),
              subtitle: Text(
                  '${weekdayShortName(l.weekday)} ${formatRange(l.startMin, l.endMin)}${l.location.isNotEmpty ? ' • ${l.location}' : ''}'),
              secondary: Icon(Icons.event_outlined,
                  color: Theme.of(context).colorScheme.primary),
            ),
          );
        }),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _working ? null : _import,
          icon: const Icon(Icons.download_outlined),
          label: Text(_working
              ? 'Importing…'
              : 'Import ${_checked.where((c) => c).length} classes'),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _Step step;
  final bool demo;
  const _StepIndicator({required this.step, required this.demo});

  @override
  Widget build(BuildContext context) {
    const labels = ['Setup', 'Connect', 'Username', 'Review'];
    final idx = _Step.values.indexOf(step);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              _Dot(
                  done: i < idx,
                  current: i == idx,
                  label: labels[i]),
              if (i < labels.length - 1)
                Expanded(
                    child: Container(
                        height: 2,
                        color: i < idx
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest)),
            ],
            if (demo) ...[
              const SizedBox(width: 8),
              const Chip(label: Text('demo'), visualDensity: VisualDensity.compact),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool done;
  final bool current;
  final String label;
  const _Dot({required this.done, required this.current, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || current ? cs.primary : cs.surfaceContainerHighest,
          ),
          child: Icon(
            done ? Icons.check : Icons.circle,
            size: 14,
            color: done || current ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: current ? FontWeight.bold : null)),
      ],
    );
  }
}
