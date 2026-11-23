import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notifications = await android?.requestNotificationsPermission() ?? true;
    await android?.requestExactAlarmsPermission();
    return notifications;
  }

  int _notificationId(String id) => id.hashCode & 0x7fffffff;

  Future<void> syncTask(DayFlowTask task) async {
    await initialize();
    await _plugin.cancel(_notificationId(task.id));
    final scheduled = task.scheduledAt;
    if (task.done || !task.reminderEnabled || scheduled == null || !scheduled.isAfter(DateTime.now())) {
      return;
    }
    try {
      await _plugin.zonedSchedule(
        _notificationId(task.id),
        task.title,
        task.notes.isEmpty ? 'Scheduled for now' : task.notes,
        tz.TZDateTime.from(scheduled, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dayflow_tasks',
            'Task reminders',
            channelDescription: 'Reminders for scheduled DayFlow tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        _notificationId(task.id),
        task.title,
        task.notes.isEmpty ? 'Scheduled for now' : task.notes,
        tz.TZDateTime.from(scheduled, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dayflow_tasks',
            'Task reminders',
            channelDescription: 'Reminders for scheduled DayFlow tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    }
  }

  Future<void> cancelTask(String taskId) => _plugin.cancel(_notificationId(taskId));

  Future<void> rescheduleAll(Iterable<DayFlowTask> tasks) async {
    await initialize();
    await _plugin.cancelAll();
    for (final task in tasks) {
      await syncTask(task);
    }
  }

  Future<void> showFocusComplete(String title) async {
    await initialize();
    await _plugin.show(
      2147483000,
      'Focus session complete',
      title,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dayflow_focus',
          'Focus timer',
          channelDescription: 'Focus timer completion alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
