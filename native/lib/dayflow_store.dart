import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';

class DayFlowStore extends ChangeNotifier {
  DayFlowStore({
    StorageService? storage,
    NotificationService? notifications,
    WidgetService? widgets,
  })  : _storage = storage ?? StorageService(),
        _notifications = notifications ?? NotificationService(),
        _widgets = widgets ?? WidgetService();

  final StorageService _storage;
  final NotificationService _notifications;
  final WidgetService _widgets;

  DayFlowData data = DayFlowData.fresh();
  bool ready = false;

  List<DayFlowTask> tasksFor(String date) => data.tasks.where((task) => task.date == date).toList()
    ..sort((a, b) => (a.time ?? '99:99').compareTo(b.time ?? '99:99'));

  Future<void> initialize() async {
    data = await _storage.load();
    ready = true;
    notifyListeners();
    await _notifications.initialize();
    await _widgets.update(data);
  }

  Future<void> _commit({DayFlowTask? syncTask, String? cancelTaskId}) async {
    await _storage.save(data);
    if (cancelTaskId != null) await _notifications.cancelTask(cancelTaskId);
    if (syncTask != null) await _notifications.syncTask(syncTask);
    await _widgets.update(data);
    notifyListeners();
  }

  Future<bool> requestNotificationPermission() => _notifications.requestPermission();

  Future<void> saveData() => _commit();

  Future<void> saveTask(DayFlowTask task, {bool isNew = false}) async {
    if (isNew) data.tasks.add(task);
    await _commit(syncTask: task);
  }

  Future<void> deleteTask(DayFlowTask task) async {
    data.tasks.removeWhere((item) => item.id == task.id);
    await _commit(cancelTaskId: task.id);
  }

  Future<void> toggleTask(DayFlowTask task) async {
    final now = DateTime.now();
    task.done = !task.done;
    task.completedAt = task.done ? now.toIso8601String() : null;
    task.updatedAt = now.toIso8601String();
    if (task.done && task.repeat != 'none') {
      final next = DayFlowTask(
        id: newId(),
        title: task.title,
        notes: task.notes,
        categoryId: task.categoryId,
        priority: task.priority,
        date: nextRepeatDate(task.date, task.repeat, now),
        time: task.time,
        repeat: task.repeat,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
        subtasks: task.subtasks
            .map((item) => DayFlowSubtask(id: newId('s'), title: item.title))
            .toList(),
        reminderEnabled: task.reminderEnabled,
      );
      task.spawnedId = next.id;
      data.tasks.add(next);
      await _notifications.syncTask(next);
    } else if (!task.done && task.spawnedId != null) {
      final spawnedId = task.spawnedId;
      final spawned = data.tasks.where((item) => item.id == spawnedId).firstOrNull;
      if (spawned != null && !spawned.done) {
        data.tasks.remove(spawned);
        await _notifications.cancelTask(spawned.id);
      }
      task.spawnedId = null;
    }
    await _commit(syncTask: task);
  }

  Future<void> moveToTomorrow(DayFlowTask task) async {
    final today = dateOnly(DateTime.now());
    final current = DateTime.parse(task.date);
    final base = current.isBefore(today) ? today : current;
    task.date = ymd(base.add(const Duration(days: 1)));
    task.updatedAt = DateTime.now().toIso8601String();
    await _commit(syncTask: task);
  }

  Future<void> recordSession({required String? taskId, required int plannedSec, required int actualSec, required DateTime startedAt}) async {
    data.sessions.add(FocusSession(
      id: newId('f'),
      taskId: taskId,
      plannedSec: plannedSec,
      actualSec: actualSec,
      startAt: startedAt.toIso8601String(),
      endAt: DateTime.now().toIso8601String(),
      completed: actualSec >= plannedSec,
    ));
    await _commit();
  }

  Future<void> importJson(String source) async {
    final imported = DayFlowData.fromJsonString(source);
    imported.prefs['onboarded'] = true;
    data = imported;
    await _storage.save(data);
    await _notifications.rescheduleAll(data.tasks);
    await _widgets.update(data);
    notifyListeners();
  }

  Future<void> reset() async {
    data = DayFlowData.fresh();
    await _storage.save(data);
    await _notifications.rescheduleAll(const []);
    await _widgets.update(data);
    notifyListeners();
  }

  Future<void> notifyFocusComplete(String message) => _notifications.showFocusComplete(message);
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
