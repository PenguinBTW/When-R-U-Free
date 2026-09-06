import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/busy_block.dart';
import '../models/friend.dart';
import '../models/lesson.dart';
import '../models/user_profile.dart';
import '../services/availability_service.dart';
import '../services/notification_service.dart';
import '../services/sample_data.dart';
import '../services/timetable_share.dart';
import '../models/free_slot.dart';
import 'cloud/firestore_data_store.dart';

/// Central app state. Local-first: every mutation saves to SharedPreferences
/// immediately; when the cloud backend is enabled it also pushes to Firestore
/// (best-effort, never blocks the UI).
class AppStore extends ChangeNotifier {
  static const _kProfile = 'wrf_profile_v1';
  static const _kLessons = 'wrf_lessons_v1';
  static const _kFriends = 'wrf_friends_v1';
  static const _kWindow = 'wrf_window_v1';
  static const _kOnboarded = 'wrf_onboarded_v1';
  static const _kBusy = 'wrf_busy_v1';
  static const _kGapAlerts = 'wrf_gap_alerts_v1';
  static const _kReminderMin = 'wrf_reminder_min_v1';
  static const _kNotifPrompted = 'wrf_notif_prompted_v1';

  static const defaultWindowStart = 8 * 60;
  static const defaultWindowEnd = 18 * 60;

  final AvailabilityService availability = const AvailabilityService();

  UserProfile profile = UserProfile.fresh();
  List<Lesson> lessons = [];
  List<Friend> friends = [];
  List<BusyBlock> busyBlocks = [];
  int windowStartMin = defaultWindowStart;
  int windowEndMin = defaultWindowEnd;
  bool onboarded = false;
  bool loaded = false;
  bool cloudActive = false;
  bool gapAlertsEnabled = true;
  int reminderMinBefore = 10;
  bool notifPrompted = false;

  List<int> get weekdays => const [1, 2, 3, 4, 5];

  List<Friend> get includedFriends => friends.where((f) => f.included).toList();

  /// person-name -> lessons, including me under "You" (or display name).
  Map<String, List<Lesson>> timetables({bool includedOnly = true}) {
    final map = <String, List<Lesson>>{};
    map[myLabel] = List<Lesson>.from(lessons);
    final fs = includedOnly ? includedFriends : friends;
    for (final f in fs) {
      map[f.displayName] = List<Lesson>.from(f.lessons);
    }
    return map;
  }

  String get myLabel => profile.displayName.trim().isEmpty
      ? 'You'
      : profile.displayName.trim();

  /// Date-aware participant list (recurring lessons + one-off busy blocks).
  List<ParticipantTimetable> participants({bool includedOnly = true}) {
    final list = <ParticipantTimetable>[
      (name: myLabel, lessons: List<Lesson>.from(lessons), busy: List<BusyBlock>.from(busyBlocks)),
    ];
    final fs = includedOnly ? includedFriends : friends;
    for (final f in fs) {
      list.add((
        name: f.displayName,
        lessons: List<Lesson>.from(f.lessons),
        busy: List<BusyBlock>.from(f.busyBlocks),
      ));
    }
    return list;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final p = prefs.getString(_kProfile);
      if (p != null) {
        profile = UserProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(p) as Map));
      }
      final l = prefs.getString(_kLessons);
      if (l != null) {
        lessons = ((jsonDecode(l) as List))
            .whereType<Map>()
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final f = prefs.getString(_kFriends);
      if (f != null) {
        friends = ((jsonDecode(f) as List))
            .whereType<Map>()
            .map((e) => Friend.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final w = prefs.getString(_kWindow);
      if (w != null) {
        final m = Map<String, dynamic>.from(jsonDecode(w) as Map);
        windowStartMin =
            (m['start'] as num?)?.toInt() ?? defaultWindowStart;
        windowEndMin = (m['end'] as num?)?.toInt() ?? defaultWindowEnd;
      }
      onboarded = prefs.getBool(_kOnboarded) ?? false;
      final b = prefs.getString(_kBusy);
      if (b != null) {
        busyBlocks = ((jsonDecode(b) as List))
            .whereType<Map>()
            .map((e) => BusyBlock.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      gapAlertsEnabled = prefs.getBool(_kGapAlerts) ?? true;
      reminderMinBefore = prefs.getInt(_kReminderMin) ?? 10;
      notifPrompted = prefs.getBool(_kNotifPrompted) ?? false;
    } catch (e) {
      debugPrint('[store] load failed, using defaults: $e');
    }
    loaded = true;
    cloudActive = FirestoreDataStore.instance.isReady;
    notifyListeners();
  }

  Future<void> _save({bool gaps = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, jsonEncode(profile.toJson()));
    await prefs.setString(
        _kLessons, jsonEncode(lessons.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _kFriends, jsonEncode(friends.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _kBusy, jsonEncode(busyBlocks.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _kWindow, jsonEncode({'start': windowStartMin, 'end': windowEndMin}));
    await prefs.setBool(_kOnboarded, onboarded);
    await prefs.setBool(_kGapAlerts, gapAlertsEnabled);
    await prefs.setInt(_kReminderMin, reminderMinBefore);
    await prefs.setBool(_kNotifPrompted, notifPrompted);
    notifyListeners();
    if (gaps) {
      // Best-effort: never let notifications break the UI.
      try {
        await NotificationService.instance.reschedule(
          people: participants(),
          windowStartMin: windowStartMin,
          windowEndMin: windowEndMin,
          enabled: gapAlertsEnabled,
          reminderMinBefore: reminderMinBefore,
        );
      } catch (e) {
        debugPrint('[store] reschedule failed: $e');
      }
    }
    // Best-effort cloud push (never throws into UI).
    try {
      if (FirestoreDataStore.instance.isReady) {
        await FirestoreDataStore.instance.pushProfile(profile);
        await FirestoreDataStore.instance.pushLessons(lessons);
      }
    } catch (e) {
      debugPrint('[store] cloud push failed: $e');
    }
  }

  void _sortLessons() {
    lessons.sort((a, b) {
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      return a.startMin.compareTo(b.startMin);
    });
  }

  // ---------- onboarding / profile ----------

  Future<void> completeOnboarding(String displayName) async {
    profile = profile.copyWith(displayName: displayName.trim());
    onboarded = true;
    await _save();
  }

  Future<void> updateProfile({String? displayName, String? college}) async {
    profile = profile.copyWith(
      displayName: displayName?.trim(),
      college: college?.trim(),
    );
    await _save();
  }

  Future<void> regenerateCode() async {
    profile = profile.copyWith(friendCode: generateFriendCode());
    await _save();
  }

  Future<void> setWindow(int start, int end) async {
    if (end - start < 60) return;
    windowStartMin = start;
    windowEndMin = end;
    await _save(gaps: true);
  }

  // ---------- lessons ----------

  /// Returns error string when clashing/invalid, else null.
  String? addLesson(Lesson lesson) {
    final err = Lesson.validate(
        subject: lesson.subject,
        startMin: lesson.startMin,
        endMin: lesson.endMin);
    if (err != null) return err;
    lessons.add(lesson);
    _sortLessons();
    _save(gaps: true);
    return null;
  }

  /// Returns error string, else null.
  String? updateLesson(Lesson updated) {
    final err = Lesson.validate(
        subject: updated.subject,
        startMin: updated.startMin,
        endMin: updated.endMin);
    if (err != null) return err;
    final i = lessons.indexWhere((l) => l.id == updated.id);
    if (i == -1) return 'Lesson not found.';
    lessons[i] = updated;
    _sortLessons();
    _save(gaps: true);
    return null;
  }

  Future<void> removeLesson(String id) async {
    lessons.removeWhere((l) => l.id == id);
    await _save(gaps: true);
  }

  Future<void> clearDay(int weekday) async {
    lessons.removeWhere((l) => l.weekday == weekday);
    await _save(gaps: true);
  }

  Future<void> loadSampleTimetable() async {
    lessons = sampleTimetable(seed: 0);
    _sortLessons();
    await _save(gaps: true);
  }

  Future<void> clearAllLessons() async {
    lessons = [];
    await _save(gaps: true);
  }

  bool hasOverlap(Lesson candidate, {String? ignoreId}) {
    return lessons.any((l) =>
        l.id != ignoreId &&
        l.weekday == candidate.weekday &&
        candidate.startMin < l.endMin &&
        l.startMin < candidate.endMin);
  }

  List<Lesson> lessonsOn(int weekday) {
    final list = lessons.where((l) => l.weekday == weekday).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    return list;
  }

  // ---------- friends ----------

  /// Adds a friend by code. In cloud mode this looks the code up in
  /// Firestore; offline it creates a deterministic demo friend so overlap
  /// features work end-to-end. Returns error string or null.
  Future<String?> addFriendByCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (!isValidFriendCode(code)) {
      return 'Codes are 6 characters (letters + numbers).';
    }
    if (code == profile.friendCode) return 'That is your own code.';
    if (friends.any((f) => f.friendCode == code)) {
      return 'You already added that friend.';
    }
    // Try cloud first (no-op when disabled).
    try {
      final found =
          await FirestoreDataStore.instance.lookupByFriendCode(code);
      if (found != null) {
        friends.add(found);
        await _save(gaps: true);
        return null;
      }
    } catch (e) {
      debugPrint('[store] friend lookup failed: $e');
    }
    // Local/demo fallback.
    friends.add(demoFriendForCode(code, nameSalt: friends.length));
    await _save(gaps: true);
    return null;
  }

  Future<void> addStarterFriends() async {
    final existing = friends.map((f) => f.friendCode).toSet();
    for (final f in starterFriends()) {
      if (!existing.contains(f.friendCode)) friends.add(f);
    }
    await _save(gaps: true);
  }

  Future<void> removeFriend(String id) async {
    friends.removeWhere((f) => f.id == id);
    await _save(gaps: true);
  }

  Future<void> toggleFriendIncluded(String id) async {
    final i = friends.indexWhere((f) => f.id == id);
    if (i == -1) return;
    friends[i] = friends[i].copyWith(included: !friends[i].included);
    await _save(gaps: true);
  }

  // ---------- busy overrides ----------

  List<BusyBlock> busyOn(DateTime date) {
    final key = BusyBlock.keyOf(date);
    final list = busyBlocks.where((b) => b.dateKey == key).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    return list;
  }

  /// Returns error string, else null.
  String? addBusyBlock(BusyBlock block) {
    final err =
        BusyBlock.validate(startMin: block.startMin, endMin: block.endMin);
    if (err != null) return err;
    busyBlocks.add(block);
    busyBlocks.sort((a, b) {
      final d = a.dateKey.compareTo(b.dateKey);
      if (d != 0) return d;
      return a.startMin.compareTo(b.startMin);
    });
    _save(gaps: true);
    return null;
  }

  Future<void> removeBusyBlock(String id) async {
    busyBlocks.removeWhere((b) => b.id == id);
    await _save(gaps: true);
  }

  // ---------- derived availability ----------

  /// Mutual free slots on a concrete date (lessons + busy blocks honoured).
  List<FreeSlot> mutualFreeOnDate(DateTime date) {
    return availability.mutualFreeOnDate(
      people: participants(),
      date: date,
      windowStartMin: windowStartMin,
      windowEndMin: windowEndMin,
    );
  }

  List<String> freeNowAt(DateTime now) {
    return availability.whoIsFreeAtDate(
      people: participants(),
      date: now,
      timeMin: now.hour * 60 + now.minute,
    );
  }

  List<DatedSlot> upcomingGaps({int days = 7}) {
    return availability.upcomingSharedGaps(
      people: participants(),
      from: DateTime.now(),
      days: days,
      windowStartMin: windowStartMin,
      windowEndMin: windowEndMin,
    );
  }

  List<FreeSlot> mutualFreeToday(int weekday) {
    return availability.mutualFreeOnDay(
      timetables: timetables(),
      weekday: weekday,
      windowStartMin: windowStartMin,
      windowEndMin: windowEndMin,
    );
  }

  List<String> freeNow(int weekday, int timeMin) {
    return availability.whoIsFreeAt(
      timetables: timetables(),
      weekday: weekday,
      timeMin: timeMin,
    );
  }

  List<FreeSlot> bestSlots() {
    return availability.bestSlotsAcrossWeek(
      timetables: timetables(),
      weekdays: weekdays,
      windowStartMin: windowStartMin,
      windowEndMin: windowEndMin,
    );
  }

  // ---------- shared-timetable import ----------

  /// Applies a scanned [SharedPayload]. Returns a short result code:
  /// 'self' when it is the user's own code, 'friend-updated' when an
  /// existing friend matched, 'friend-added' otherwise.
  Future<String> applySharedPayload(SharedPayload p) async {
    if (p.friendCode == profile.friendCode) return 'self';
    final i = friends.indexWhere((f) => f.friendCode == p.friendCode);
    if (i != -1) {
      friends[i] = friends[i].copyWith(
        displayName: p.displayName,
        lessons: p.lessons,
      );
      await _save(gaps: true);
      return 'friend-updated';
    }
    friends.add(Friend(
      id: 'shared-${p.friendCode}',
      displayName: p.displayName,
      friendCode: p.friendCode,
      lessons: p.lessons,
    ));
    await _save(gaps: true);
    return 'friend-added';
  }

  /// Merges a shared payload into MY timetable, skipping exact duplicates.
  /// Returns the number of lessons added.
  Future<int> mergeSharedIntoMine(SharedPayload p) =>
      mergeLessons(p.lessons);

  /// Merges [incoming] lessons into MY timetable, skipping exact duplicates.
  /// Returns the number of lessons added.
  Future<int> mergeLessons(List<Lesson> incoming) async {
    var added = 0;
    for (final l in incoming) {
      final dupe = lessons.any((e) =>
          e.weekday == l.weekday &&
          e.startMin == l.startMin &&
          e.endMin == l.endMin &&
          e.subject.toLowerCase() == l.subject.toLowerCase());
      if (!dupe) {
        lessons.add(l);
        added++;
      }
    }
    _sortLessons();
    await _save(gaps: true);
    return added;
  }

  // ---------- gap-alert prefs ----------

  Future<void> setGapAlerts(bool enabled) async {
    gapAlertsEnabled = enabled;
    if (enabled) {
      await NotificationService.instance.requestPermission();
    }
    await _save(gaps: true);
  }

  Future<void> setReminderMinBefore(int minutes) async {
    reminderMinBefore = minutes.clamp(0, 120);
    await _save(gaps: true);
  }

  /// First-run prompt result: user accepted system permission flow.
  Future<void> acceptGapAlerts() async {
    notifPrompted = true;
    gapAlertsEnabled = true;
    await NotificationService.instance.requestPermission();
    await _save(gaps: true);
  }

  /// First-run prompt result: user declined alerts for now.
  Future<void> declineGapAlerts() async {
    notifPrompted = true;
    gapAlertsEnabled = false;
    await _save(gaps: true);
  }

  // ---------- backup / reset ----------

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'profile': profile.toJson(),
      'lessons': lessons.map((e) => e.toJson()).toList(),
      'friends': friends.map((e) => e.toJson()).toList(),
      'busyBlocks': busyBlocks.map((e) => e.toJson()).toList(),
      'window': {'start': windowStartMin, 'end': windowEndMin},
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Returns error string or null.
  Future<String?> importJson(String raw) async {
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (m['profile'] != null) {
        profile = UserProfile.fromJson(
            Map<String, dynamic>.from(m['profile'] as Map));
      }
      if (m['lessons'] != null) {
        lessons = ((m['lessons'] as List))
            .whereType<Map>()
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _sortLessons();
      }
      if (m['friends'] != null) {
        friends = ((m['friends'] as List))
            .whereType<Map>()
            .map((e) => Friend.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (m['busyBlocks'] != null) {
        busyBlocks = ((m['busyBlocks'] as List))
            .whereType<Map>()
            .map((e) => BusyBlock.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      await _save(gaps: true);
      return null;
    } catch (e) {
      return 'Could not read that backup: $e';
    }
  }

  Future<void> resetAll() async {
    profile = UserProfile.fresh();
    lessons = [];
    friends = [];
    busyBlocks = [];
    windowStartMin = defaultWindowStart;
    windowEndMin = defaultWindowEnd;
    onboarded = false;
    try {
      await NotificationService.instance.cancelAll();
    } catch (_) {
      // Notifications may never have been initialised.
    }
    await _save(gaps: true);
  }
}
