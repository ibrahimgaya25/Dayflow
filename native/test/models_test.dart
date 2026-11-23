import 'dart:convert';

import 'package:dayflow_native/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PWA v1 compatibility', () {
    test('imports and re-exports all durable user data', () {
      final source = jsonEncode({
        'app': 'dayflow',
        'v': 1,
        'rev': 123,
        'prefs': {'name': 'Amina', 'theme': 'light', 'tv': 2, 'focusMin': 25, 'onboarded': true},
        'categories': [
          {'id': 'work', 'name': 'Work', 'color': '#4c715d', 'isDefault': true},
          {'id': 'other', 'name': 'Other', 'color': '#7a827c', 'isDefault': true},
        ],
        'tasks': [
          {
            'id': 'task-1', 'title': 'Prepare tester notes', 'notes': 'Keep this during migration',
            'categoryId': 'work', 'priority': 'high', 'date': '2026-11-23', 'time': '09:30',
            'done': false, 'createdAt': '2026-11-20T08:00:00.000Z', 'updatedAt': '2026-11-20T08:00:00.000Z',
            'completedAt': null, 'repeat': 'weekdays', 'spawnedId': null,
            'subtasks': [{'id': 'sub-1', 'title': 'Collect screenshots', 'done': true}],
          },
        ],
        'sessions': [
          {'id': 'focus-1', 'taskId': 'task-1', 'plannedSec': 1500, 'actualSec': 1500, 'startAt': '2026-11-22T09:00:00.000Z', 'endAt': '2026-11-22T09:25:00.000Z', 'completed': true},
        ],
        'tips': [{'id': 'tip-1', 'text': 'Start before it feels perfect.', 'createdAt': '2026-11-20T08:00:00.000Z'}],
        'badges': {'first': '2026-11-20T08:00:00.000Z'},
      });

      final exported = DayFlowData.fromJsonString(DayFlowData.fromJsonString(source).toJsonString());
      expect(exported.tasks.single.title, 'Prepare tester notes');
      expect(exported.tasks.single.subtasks.single.done, isTrue);
      expect(exported.sessions.single.actualSec, 1500);
      expect(exported.tips.single.text, 'Start before it feels perfect.');
      expect(exported.badges, contains('first'));
    });

    test('rejects a newer export', () {
      expect(() => DayFlowData.fromJsonString('{"app":"dayflow","v":2}'), throwsFormatException);
    });
  });

  group('repeating tasks', () {
    test('weekday repeat skips a weekend', () {
      expect(nextRepeatDate('2026-11-20', 'weekdays', DateTime(2026, 11, 20)), '2026-11-23');
    });

    test('weekly repeat catches up from an overdue occurrence', () {
      expect(nextRepeatDate('2026-11-01', 'weekly', DateTime(2026, 11, 23)), '2026-11-29');
    });
  });
}
