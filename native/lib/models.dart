import 'dart:convert';

const defaultCategories = <DayFlowCategory>[
  DayFlowCategory(id: 'work', name: 'Work', color: '#4c715d', isDefault: true),
  DayFlowCategory(id: 'personal', name: 'Personal', color: '#a46a5e', isDefault: true),
  DayFlowCategory(id: 'business', name: 'Business', color: '#a17b46', isDefault: true),
  DayFlowCategory(id: 'learning', name: 'Learning', color: '#666f9c', isDefault: true),
  DayFlowCategory(id: 'health', name: 'Health', color: '#4f8f86', isDefault: true),
  DayFlowCategory(id: 'errands', name: 'Errands', color: '#8a6f9a', isDefault: true),
  DayFlowCategory(id: 'other', name: 'Other', color: '#7a827c', isDefault: true),
];

String newId([String prefix = 'n']) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

String ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class DayFlowCategory {
  const DayFlowCategory({
    required this.id,
    required this.name,
    required this.color,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String color;
  final bool isDefault;

  factory DayFlowCategory.fromJson(Map<String, dynamic> json) {
    final color = json['color'];
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        color is! String ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
      throw const FormatException('A category is invalid.');
    }
    return DayFlowCategory(
      id: json['id'],
      name: (json['name'] as String).trim().length > 30
          ? (json['name'] as String).trim().substring(0, 30)
          : (json['name'] as String).trim(),
      color: color,
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'isDefault': isDefault,
      };
}

class DayFlowSubtask {
  DayFlowSubtask({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  bool done;

  factory DayFlowSubtask.fromJson(Map<String, dynamic> json, int index) {
    final title = (json['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) throw const FormatException('A subtask is empty.');
    return DayFlowSubtask(
      id: (json['id'] as String?)?.isNotEmpty == true
          ? json['id']
          : 'sub_$index',
      title: title.length > 80 ? title.substring(0, 80) : title,
      done: json['done'] == true,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
}

class DayFlowTask {
  DayFlowTask({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.priority,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.time,
    this.done = false,
    this.completedAt,
    this.repeat = 'none',
    this.spawnedId,
    List<DayFlowSubtask>? subtasks,
    this.reminderEnabled = true,
  }) : subtasks = subtasks ?? [];

  final String id;
  String title;
  String notes;
  String categoryId;
  String priority;
  String date;
  String? time;
  bool done;
  final String createdAt;
  String updatedAt;
  String? completedAt;
  String repeat;
  String? spawnedId;
  List<DayFlowSubtask> subtasks;
  bool reminderEnabled;

  DateTime? get scheduledAt {
    if (time == null) return null;
    final d = DateTime.tryParse(date);
    final parts = time!.split(':');
    if (d == null || parts.length != 2) return null;
    return DateTime(d.year, d.month, d.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  factory DayFlowTask.fromJson(
    Map<String, dynamic> json,
    Set<String> categoryIds,
    String fallbackCategory,
  ) {
    final id = json['id'];
    final rawTitle = json['title'];
    final date = json['date'];
    final priority = json['priority'];
    final time = json['time'];
    if (id is! String || id.isEmpty || rawTitle is! String || rawTitle.trim().isEmpty) {
      throw const FormatException('A task has a missing ID or title.');
    }
    if (date is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null) {
      throw FormatException('“${rawTitle.trim()}” has an invalid date.');
    }
    if (time != null &&
        time != '' &&
        (time is! String || !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time))) {
      throw FormatException('“${rawTitle.trim()}” has an invalid time.');
    }
    if (!const {'high', 'medium', 'low'}.contains(priority)) {
      throw FormatException('“${rawTitle.trim()}” has an invalid priority.');
    }
    final now = DateTime.now().toIso8601String();
    final title = rawTitle.trim();
    final notes = json['notes'] is String ? json['notes'] as String : '';
    final rawSubs = json['subtasks'] is List ? json['subtasks'] as List : const [];
    final subs = <DayFlowSubtask>[];
    for (var i = 0; i < rawSubs.length && subs.length < 20; i++) {
      final item = rawSubs[i];
      if (item is Map<String, dynamic> && (item['title'] as String?)?.trim().isNotEmpty == true) {
        subs.add(DayFlowSubtask.fromJson(item, i));
      }
    }
    return DayFlowTask(
      id: id,
      title: title.length > 120 ? title.substring(0, 120) : title,
      notes: notes.length > 600 ? notes.substring(0, 600) : notes,
      categoryId: categoryIds.contains(json['categoryId'])
          ? json['categoryId']
          : fallbackCategory,
      priority: priority,
      date: date,
      time: time == '' ? null : time,
      done: json['done'] == true,
      createdAt: json['createdAt'] is String ? json['createdAt'] : now,
      updatedAt: json['updatedAt'] is String ? json['updatedAt'] : now,
      completedAt: json['done'] == true
          ? (json['completedAt'] is String ? json['completedAt'] : now)
          : null,
      repeat: const {'daily', 'weekdays', 'weekly'}.contains(json['repeat'])
          ? json['repeat']
          : 'none',
      spawnedId: json['spawnedId'] is String ? json['spawnedId'] : null,
      subtasks: subs,
      reminderEnabled: json['reminderEnabled'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'categoryId': categoryId,
        'priority': priority,
        'date': date,
        'time': time,
        'done': done,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'completedAt': completedAt,
        'repeat': repeat,
        'spawnedId': spawnedId,
        'subtasks': subtasks.map((item) => item.toJson()).toList(),
        // PWA v1 ignores unknown fields, so this remains round-trip compatible.
        'reminderEnabled': reminderEnabled,
      };
}

class FocusSession {
  FocusSession({
    required this.id,
    required this.plannedSec,
    required this.actualSec,
    required this.startAt,
    required this.endAt,
    required this.completed,
    this.taskId,
  });

  final String id;
  final String? taskId;
  final int plannedSec;
  final int actualSec;
  final String startAt;
  final String endAt;
  final bool completed;

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['plannedSec'] is! num ||
        json['actualSec'] is! num ||
        (json['plannedSec'] as num) < 0 ||
        (json['actualSec'] as num) < 0 ||
        json['endAt'] is! String ||
        DateTime.tryParse(json['endAt']) == null) {
      throw const FormatException('A focus session is invalid.');
    }
    return FocusSession(
      id: json['id'],
      taskId: json['taskId'] is String ? json['taskId'] : null,
      plannedSec: (json['plannedSec'] as num).round(),
      actualSec: (json['actualSec'] as num).round(),
      startAt: json['startAt'] is String ? json['startAt'] : json['endAt'],
      endAt: json['endAt'],
      completed: json['completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'plannedSec': plannedSec,
        'actualSec': actualSec,
        'startAt': startAt,
        'endAt': endAt,
        'completed': completed,
      };
}

class PersonalTip {
  const PersonalTip({required this.id, required this.text, required this.createdAt});
  final String id;
  final String text;
  final String createdAt;

  factory PersonalTip.fromJson(Map<String, dynamic> json) {
    final text = (json['text'] as String?)?.trim() ?? '';
    if (json['id'] is! String || (json['id'] as String).isEmpty || text.isEmpty) {
      throw const FormatException('A tip is invalid.');
    }
    return PersonalTip(
      id: json['id'],
      text: text.length > 140 ? text.substring(0, 140) : text,
      createdAt: json['createdAt'] is String
          ? json['createdAt']
          : DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'createdAt': createdAt};
}

class DayFlowData {
  DayFlowData({
    required this.prefs,
    required this.categories,
    required this.tasks,
    required this.sessions,
    required this.tips,
    required this.badges,
    this.rev = 0,
  });

  factory DayFlowData.fresh() => DayFlowData(
        prefs: {
          'name': '',
          'interests': <String>[],
          'theme': 'system',
          'tv': 2,
          'focusMin': 25,
          'onboarded': true,
          'ownTipsOnly': false,
          'chime': true,
          'swiped': false,
        },
        categories: List.of(defaultCategories),
        tasks: [],
        sessions: [],
        tips: [],
        badges: {},
      );

  Map<String, dynamic> prefs;
  List<DayFlowCategory> categories;
  List<DayFlowTask> tasks;
  List<FocusSession> sessions;
  List<PersonalTip> tips;
  Map<String, String> badges;
  int rev;

  static DayFlowData fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('This is not a DayFlow export.');
    }
    return fromJson(decoded);
  }

  static DayFlowData fromJson(Map<String, dynamic> json) {
    if (json['app'] != 'dayflow') {
      throw const FormatException('This is not a DayFlow export.');
    }
    if (json['v'] is! num || (json['v'] as num) > 1) {
      throw const FormatException('This export comes from a newer version of DayFlow.');
    }
    if (json['categories'] is! List || json['tasks'] is! List || json['sessions'] is! List) {
      throw const FormatException('The export is missing tasks, categories, or focus sessions.');
    }
    final categories = (json['categories'] as List)
        .map((item) => DayFlowCategory.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    if (categories.isEmpty) throw const FormatException('The export has no categories.');
    final ids = categories.map((item) => item.id).toSet();
    if (ids.length != categories.length) {
      throw const FormatException('Two categories share the same ID.');
    }
    final fallback = ids.contains('other') ? 'other' : categories.first.id;
    final tasks = (json['tasks'] as List)
        .map((item) => DayFlowTask.fromJson(
              Map<String, dynamic>.from(item as Map),
              ids,
              fallback,
            ))
        .toList();
    if (tasks.map((item) => item.id).toSet().length != tasks.length) {
      throw const FormatException('Two tasks share the same ID.');
    }
    final sessions = (json['sessions'] as List)
        .map((item) => FocusSession.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final tips = json['tips'] is List
        ? (json['tips'] as List)
            .map((item) => PersonalTip.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList()
        : <PersonalTip>[];
    final rawBadges = json['badges'];
    final badges = <String, String>{};
    if (rawBadges is Map) {
      for (final entry in rawBadges.entries) {
        if (entry.key is String && entry.value is String && DateTime.tryParse(entry.value) != null) {
          badges[entry.key] = entry.value;
        }
      }
    }
    final incomingPrefs = json['prefs'] is Map
        ? Map<String, dynamic>.from(json['prefs'] as Map)
        : <String, dynamic>{};
    final prefs = DayFlowData.fresh().prefs..addAll(incomingPrefs);
    return DayFlowData(
      prefs: prefs,
      categories: categories,
      tasks: tasks,
      sessions: sessions,
      tips: tips,
      badges: badges,
      rev: json['rev'] is num ? (json['rev'] as num).round() : 0,
    );
  }

  Map<String, dynamic> toJson({bool includeExportedAt = true}) => {
        'app': 'dayflow',
        'v': 1,
        if (includeExportedAt) 'exportedAt': DateTime.now().toIso8601String(),
        'rev': rev,
        'prefs': prefs,
        'categories': categories.map((item) => item.toJson()).toList(),
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'sessions': sessions.map((item) => item.toJson()).toList(),
        'tips': tips.map((item) => item.toJson()).toList(),
        'badges': badges,
      };

  String toJsonString({bool pretty = false}) {
    final encoder = pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(toJson());
  }
}

String nextRepeatDate(String from, String repeat, DateTime now) {
  var candidate = DateTime.parse(from);
  final today = dateOnly(now);
  if (repeat == 'weekly') {
    do {
      candidate = candidate.add(const Duration(days: 7));
    } while (candidate.isBefore(today));
  } else {
    do {
      candidate = candidate.add(const Duration(days: 1));
    } while (candidate.isBefore(today) ||
        (repeat == 'weekdays' &&
            (candidate.weekday == DateTime.saturday || candidate.weekday == DateTime.sunday)));
  }
  return ymd(candidate);
}
