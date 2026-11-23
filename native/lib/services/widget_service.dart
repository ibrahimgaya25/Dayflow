import 'package:home_widget/home_widget.dart';

import '../models.dart';

class WidgetService {
  static const providerName = 'DayFlowWidgetProvider';

  Future<void> update(DayFlowData data) async {
    final today = ymd(DateTime.now());
    final pending = data.tasks
        .where((task) => !task.done && task.date.compareTo(today) <= 0)
        .toList()
      ..sort((a, b) {
        const rank = {'high': 0, 'medium': 1, 'low': 2};
        final priority = rank[a.priority]!.compareTo(rank[b.priority]!);
        if (priority != 0) return priority;
        return (a.time ?? '99:99').compareTo(b.time ?? '99:99');
      });
    await HomeWidget.saveWidgetData('dayflow_count', pending.length);
    await HomeWidget.saveWidgetData(
      'dayflow_tasks',
      pending.take(3).map((task) => '• ${task.title}').join('\n'),
    );
    await HomeWidget.updateWidget(androidName: providerName);
  }
}
