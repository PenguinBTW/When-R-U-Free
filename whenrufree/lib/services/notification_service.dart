import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'availability_service.dart';

/// Local "gap alerts": notifies you shortly before each upcoming break that
/// friends share with you, naming who else is free.
///
/// Fully on-device (no server / push needed). When the cloud backend ships,
/// this same surface can be driven by FCM — the scheduling seam
/// ([reschedule]) already takes plain data, so either caller works.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;
  bool _available = false;
  bool get isAvailable => _available;

  static const _channelId = 'wrf_gaps';
  static const _channelName = 'Shared breaks';
  static const _channelDesc =
      'Alerts before breaks you share with friends';
  static const _maxScheduled = 12;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      tzdata.initializeTimeZones();
      try {
        final local = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(local.identifier));
      } catch (_) {
        // Fall back to UTC rather than failing init.
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linux = LinuxInitializationSettings(
          defaultActionName: 'Open When R U Free');
      const windows = WindowsInitializationSettings(
        appName: 'When R U Free',
        appUserModelId: 'Vio.WhenRUFree',
        guid: 'd7f8a2b4-1c3e-4f5a-9b6d-2e8c0a4f6b12',
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
            android: android,
            iOS: darwin,
            macOS: darwin,
            linux: linux,
            windows: windows),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ));
      _available = true;
    } catch (e) {
      debugPrint('[notify] init unavailable on this platform: $e');
      _available = false;
    }
  }

  /// Shows the system permission prompt. Returns true when alerts can fire.
  Future<bool> requestPermission() async {
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (mac != null) {
        await mac.requestPermissions(alert: true, badge: true, sound: true);
        return true;
      }
      return _available;
    } catch (e) {
      debugPrint('[notify] permission request failed: $e');
      return false;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      );

  /// Recomputes the next shared gaps and schedules one alert each,
  /// [reminderMinBefore] minutes before the gap starts.
  Future<void> reschedule({
    required List<ParticipantTimetable> people,
    required int windowStartMin,
    required int windowEndMin,
    required bool enabled,
    required int reminderMinBefore,
  }) async {
    if (!_inited) return;
    try {
      await cancelAll();
      if (!enabled || !_available) return;
      final gaps = const AvailabilityService().upcomingSharedGaps(
        people: people,
        from: DateTime.now(),
        windowStartMin: windowStartMin,
        windowEndMin: windowEndMin,
      );
      final now = DateTime.now();
      var scheduled = 0;
      for (final g in gaps) {
        if (scheduled >= _maxScheduled) break;
        final start = DateTime(g.date.year, g.date.month, g.date.day)
            .add(Duration(minutes: g.slot.startMin));
        final notifyAt =
            start.subtract(Duration(minutes: reminderMinBefore));
        if (!notifyAt.isAfter(now.add(const Duration(minutes: 1)))) {
          continue;
        }
        final names = g.slot.whoFree.length > 3
            ? '${g.slot.whoFree.take(2).join(', ')} +${g.slot.whoFree.length - 2} more'
            : g.slot.whoFree.join(', ');
        await _plugin.zonedSchedule(
          id: _idFor(g.date, g.slot.startMin),
          title: reminderMinBefore <= 0
              ? 'You\'re all free now 🎉'
              : 'Free with $names soon',
          body: '${_dayLabel(g.date)} ${_fmtRange(g.slot.startMin, g.slot.endMin)} • '
              '${_fmtDur(g.slot.endMin - g.slot.startMin)} with $names',
          scheduledDate: tz.TZDateTime.from(notifyAt, tz.local),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled++;
      }
      debugPrint('[notify] scheduled $scheduled gap alerts.');
    } catch (e) {
      debugPrint('[notify] reschedule failed: $e');
    }
  }

  /// Immediate test alert from Settings.
  Future<void> showNow({required String title, required String body}) async {
    try {
      await init();
      if (!_available) return;
      await _plugin.show(
          id: 9001,
          title: title,
          body: body,
          notificationDetails: _details);
    } catch (e) {
      debugPrint('[notify] showNow failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Plugin may not exist on this platform/test env.
    }
  }

  int _idFor(DateTime date, int startMin) =>
      (date.year * 372 + date.month * 31 + date.day) * 1440 + startMin;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][
        date.weekday - 1];
  }

  String _fmtRange(int s, int e) => '${_fmt(s)}–${_fmt(e)}';
  String _fmt(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  String _fmtDur(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}

/// Kept tiny on purpose: the schedule payload is derived, never stored.
String debugDescribeGaps(List<DatedSlot> gaps) =>
    jsonEncode(gaps.map((g) => g.slot.label()).toList());
