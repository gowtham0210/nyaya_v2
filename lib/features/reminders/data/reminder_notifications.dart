import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_plan.dart';

/// One notification ready to schedule.
typedef ReminderNotice = ({int id, DateTime at, String title, String body});

/// The phone's notifications, behind an interface so tests use a fake.
abstract interface class ReminderNotifications {
  /// Asks to show notifications (iOS and Android 13+); true when allowed.
  Future<bool> requestPermission();

  /// Clears every reminder this app scheduled and schedules [notices].
  Future<void> replaceAll(List<ReminderNotice> notices);
}

final reminderNotificationsProvider = Provider<ReminderNotifications>((ref) => LocalReminderNotifications());

class LocalReminderNotifications implements ReminderNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static const _channel = AndroidNotificationDetails(
    'daily_reminder',
    'Daily reminder',
    channelDescription: 'One reminder a day to practise',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _init() => _ready ??= () async {
        tzdata.initializeTimeZones();
        try {
          final zone = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(zone.identifier));
        } catch (e) {
          // Unknown zone name: India's, where nearly every learner is.
          debugPrint('Reminder time zone not found ($e); using Asia/Kolkata');
          tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        }
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            // Permission is asked at a chosen moment, not when the plugin starts.
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
      }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    return false;
  }

  @override
  Future<void> replaceAll(List<ReminderNotice> notices) async {
    await _init();
    for (var i = 0; i < reminderDaysAhead; i++) {
      await _plugin.cancel(id: reminderIdBase + i);
    }
    for (final n in notices) {
      // A time that passed while this ran would be refused and stop the rest.
      if (!n.at.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        // Within a few minutes is fine for a reminder, and needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
