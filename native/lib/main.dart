import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'dayflow_store.dart';
import 'models.dart';
import 'services/storage_service.dart';

const _ink = Color(0xff17352c);
const _green = Color(0xff315f50);
const _cream = Color(0xfff8f8f3);
const _gold = Color(0xffdfab45);
const _muted = Color(0xff68766e);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DayFlowStore();
  await store.initialize();
  runApp(DayFlowApp(store: store));
}

class DayFlowApp extends StatelessWidget {
  const DayFlowApp({super.key, required this.store});
  final DayFlowStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final mode = store.data.prefs['theme'] as String? ?? 'system';
        return MaterialApp(
          title: 'DayFlow',
          debugShowCheckedModeBanner: false,
          themeMode: switch (mode) {
            'dark' => ThemeMode.dark,
            'light' => ThemeMode.light,
            _ => ThemeMode.system,
          },
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: DayFlowShell(store: store),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: brightness,
      primary: dark ? const Color(0xff9bcdb8) : _green,
      secondary: _gold,
      surface: dark ? const Color(0xff17231f) : Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xff0f1815) : _cream,
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xff17231f) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff21312b) : const Color(0xfff2f3ed),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: dark ? const Color(0xff15251f) : _ink,
        indicatorColor: _gold,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected) ? _ink : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? _ink : Colors.white70,
            )),
      ),
    );
  }
}

class DayFlowShell extends StatefulWidget {
  const DayFlowShell({super.key, required this.store});
  final DayFlowStore store;

  @override
  State<DayFlowShell> createState() => _DayFlowShellState();
}

class _DayFlowShellState extends State<DayFlowShell> {
  int _index = 0;
  StreamSubscription<Uri?>? _widgetSubscription;

  @override
  void initState() {
    super.initState();
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri?.host != 'add') return;
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTaskEditor());
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showTaskEditor([DayFlowTask? task, DateTime? date]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TaskEditor(
        store: widget.store,
        task: task,
        initialDate: date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(store: widget.store, editTask: _showTaskEditor),
      PlannerPage(store: widget.store, editTask: _showTaskEditor),
      FocusPage(store: widget.store),
      InsightsPage(store: widget.store),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.eco_rounded, color: _gold),
            SizedBox(width: 8),
            Text('dayflow.', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(store: widget.store),
            )),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: _index <= 1
          ? FloatingActionButton(
              onPressed: () => _showTaskEditor(null, _index == 1 ? DateTime.now() : null),
              backgroundColor: _gold,
              foregroundColor: _ink,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Planner'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: 'Focus'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),
        ],
      ),
    );
  }
}

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.store, required this.editTask});
  final DayFlowStore store;
  final Future<void> Function([DayFlowTask?, DateTime?]) editTask;

  @override
  Widget build(BuildContext context) {
    final today = ymd(DateTime.now());
    final todayTasks = store.tasksFor(today);
    final pending = store.data.tasks.where((task) => !task.done && task.date.compareTo(today) <= 0).toList()
      ..sort(_taskSort);
    final completed = todayTasks.where((task) => task.done).length;
    final progress = todayTasks.isEmpty ? 0.0 : completed / todayTasks.length;
    final name = (store.data.prefs['name'] as String? ?? '').trim();
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _GreetingCard(greeting: greeting, name: name, store: store),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(value: progress, strokeWidth: 8, color: _gold, backgroundColor: _green.withValues(alpha: .12)),
                    Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Today’s progress', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('${todayTasks.length} planned · $completed done', style: const TextStyle(color: _muted)),
                  ]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _SectionTitle(title: 'Today’s priorities', count: pending.length),
        if (pending.isEmpty)
          const _EmptyCard(
            icon: Icons.eco_outlined,
            title: 'Nothing outstanding',
            body: 'Add a task and give your day a little shape.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < pending.length; i++) ...[
                  TaskTile(
                    task: pending[i],
                    store: store,
                    rank: i < 3 ? i + 1 : null,
                    editTask: editTask,
                  ),
                  if (i != pending.length - 1) const Divider(height: 1, indent: 64),
                ],
              ],
            ),
          ),
        const SizedBox(height: 22),
        _SectionTitle(title: 'Today’s schedule', count: todayTasks.length),
        if (todayTasks.isEmpty)
          const _EmptyCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Your day is open',
            body: 'Timed and anytime tasks will appear here.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < todayTasks.length; i++) ...[
                  TaskTile(task: todayTasks[i], store: store, editTask: editTask),
                  if (i != todayTasks.length - 1) const Divider(height: 1, indent: 64),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.greeting, required this.name, required this.store});
  final String greeting;
  final String name;
  final DayFlowStore store;

  @override
  Widget build(BuildContext context) {
    final tip = store.data.tips.firstOrNull?.text ?? 'Focus on completing your most important task first.';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [_ink, _green], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('EEEE, d MMMM').format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text('$greeting${name.isEmpty ? '.' : ',\n$name.'}', style: const TextStyle(color: Colors.white, fontSize: 34, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -1.4)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .14))),
          child: Row(children: [
            const Icon(Icons.lightbulb_outline, color: _gold),
            const SizedBox(width: 10),
            Expanded(child: Text(tip, style: const TextStyle(color: Colors.white, height: 1.35))),
          ]),
        ),
      ]),
    );
  }
}

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key, required this.store, required this.editTask});
  final DayFlowStore store;
  final Future<void> Function([DayFlowTask?, DateTime?]) editTask;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  DateTime selected = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final weekStart = selected.subtract(Duration(days: selected.weekday - 1));
    final days = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final tasks = widget.store.tasksFor(ymd(selected));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text('Planner', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(DateFormat('MMMM yyyy').format(selected), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
          IconButton(onPressed: () => setState(() => selected = selected.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () => setState(() => selected = selected.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
        ]),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
            child: Row(
              children: days.map((day) {
                final active = ymd(day) == ymd(selected);
                final hasTasks = widget.store.tasksFor(ymd(day)).any((task) => !task.done);
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => selected = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(color: active ? _green : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [
                        Text(DateFormat('E').format(day).substring(0, 1), style: TextStyle(fontSize: 12, color: active ? Colors.white70 : _muted)),
                        const SizedBox(height: 4),
                        Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w900, color: active ? Colors.white : null)),
                        const SizedBox(height: 4),
                        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: hasTasks ? _gold : Colors.transparent)),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text(DateFormat('EEEE, d MMMM').format(selected), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          TextButton.icon(onPressed: () => widget.editTask(null, selected), icon: const Icon(Icons.add), label: const Text('Add')),
        ]),
        const SizedBox(height: 6),
        if (tasks.isEmpty)
          const _EmptyCard(icon: Icons.calendar_today_outlined, title: 'Nothing planned', body: 'Keep the space open or add something for this day.')
        else
          Card(
            child: Column(children: [
              for (var i = 0; i < tasks.length; i++) ...[
                TaskTile(task: tasks[i], store: widget.store, editTask: widget.editTask),
                if (i != tasks.length - 1) const Divider(height: 1, indent: 64),
              ],
            ]),
          ),
      ],
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.store, required this.editTask, this.rank});
  final DayFlowTask task;
  final DayFlowStore store;
  final Future<void> Function([DayFlowTask?, DateTime?]) editTask;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final category = store.data.categories.where((item) => item.id == task.categoryId).firstOrNull;
    final subtitle = [
      if (task.time != null) _formatTime(task.time!),
      category?.name,
      task.priority,
      if (task.subtasks.isNotEmpty) '${task.subtasks.where((item) => item.done).length}/${task.subtasks.length} steps',
    ].whereType<String>().join(' · ');
    return Dismissible(
      key: ValueKey(task.id),
      background: Container(color: _green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 22), child: const Icon(Icons.check, color: Colors.white)),
      secondaryBackground: Container(color: _gold, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 22), child: const Icon(Icons.arrow_forward, color: _ink)),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) await store.toggleTask(task);
        if (direction == DismissDirection.endToStart && !task.done) await store.moveToTomorrow(task);
        return false;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: rank != null
            ? CircleAvatar(backgroundColor: _green.withValues(alpha: .12), child: Text('$rank', style: const TextStyle(color: _green, fontWeight: FontWeight.w900)))
            : Checkbox(value: task.done, onChanged: (_) => store.toggleTask(task), activeColor: _green),
        title: Text(task.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: task.done ? TextDecoration.lineThrough : null, color: task.done ? _muted : null)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: task.repeat == 'none' ? null : const Icon(Icons.repeat, size: 18, color: _muted),
        onTap: () => editTask(task),
      ),
    );
  }
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.store, this.task, this.initialDate});
  final DayFlowStore store;
  final DayFlowTask? task;
  final DateTime? initialDate;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final TextEditingController title;
  late final TextEditingController notes;
  late String category;
  late String priority;
  late String repeat;
  late DateTime date;
  TimeOfDay? time;
  late bool reminder;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    title = TextEditingController(text: task?.title ?? '');
    notes = TextEditingController(text: task?.notes ?? '');
    category = task?.categoryId ?? widget.store.data.categories.first.id;
    priority = task?.priority ?? 'medium';
    repeat = task?.repeat ?? 'none';
    date = task == null ? (widget.initialDate ?? DateTime.now()) : DateTime.parse(task.date);
    time = task?.time == null
        ? null
        : TimeOfDay(
            hour: int.parse(task!.time!.split(':')[0]),
            minute: int.parse(task.time!.split(':')[1]),
          );
    reminder = task?.reminderEnabled ?? true;
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final timeString = time == null
        ? null
        : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
    final task = widget.task ?? DayFlowTask(
      id: newId(),
      title: title.text.trim(),
      categoryId: category,
      priority: priority,
      date: ymd(date),
      createdAt: now,
      updatedAt: now,
    );
    task
      ..title = title.text.trim()
      ..notes = notes.text.trim()
      ..categoryId = category
      ..priority = priority
      ..repeat = repeat
      ..date = ymd(date)
      ..time = timeString
      ..reminderEnabled = reminder
      ..updatedAt = now;
    if (reminder && time != null) await widget.store.requestNotificationPermission();
    await widget.store.saveTask(task, isNew: widget.task == null);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(widget.task == null ? 'New task' : 'Edit task', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 14),
          TextField(controller: title, autofocus: widget.task == null, maxLength: 120, decoration: const InputDecoration(labelText: 'Title', hintText: 'What needs doing?')),
          const SizedBox(height: 10),
          TextField(controller: notes, maxLength: 600, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: widget.store.data.categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(), onChanged: (value) => setState(() => category = value!))),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(initialValue: priority, decoration: const InputDecoration(labelText: 'Priority'), items: const ['high', 'medium', 'low'].map((item) => DropdownMenuItem(value: item, child: Text(item[0].toUpperCase() + item.substring(1)))).toList(), onChanged: (value) => setState(() => priority = value!))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final result = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (result != null) setState(() => date = result); }, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('d MMM yyyy').format(date)))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final result = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now()); if (result != null) setState(() => time = result); }, icon: const Icon(Icons.schedule), label: Text(time?.format(context) ?? 'Any time'))),
          ]),
          if (time != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => time = null), child: const Text('Clear time'))),
          DropdownButtonFormField<String>(initialValue: repeat, decoration: const InputDecoration(labelText: 'Repeat'), items: const {'none': 'Does not repeat', 'daily': 'Every day', 'weekdays': 'Weekdays', 'weekly': 'Every week'}.entries.map((item) => DropdownMenuItem(value: item.key, child: Text(item.value))).toList(), onChanged: (value) => setState(() => repeat = value!)),
          if (time != null) SwitchListTile(contentPadding: EdgeInsets.zero, value: reminder, onChanged: (value) => setState(() => reminder = value), title: const Text('Remind me at this time'), subtitle: const Text('Works offline using Android notifications')),
          const SizedBox(height: 14),
          Row(children: [
            if (widget.task != null) IconButton.filledTonal(onPressed: () async { await widget.store.deleteTask(widget.task!); if (context.mounted) Navigator.pop(context); }, icon: const Icon(Icons.delete_outline)),
            if (widget.task != null) const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: _save, style: FilledButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: _green), child: Text(widget.task == null ? 'Add task' : 'Save changes'))),
          ]),
        ]),
      ),
    );
  }
}

class FocusPage extends StatefulWidget {
  const FocusPage({super.key, required this.store});
  final DayFlowStore store;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  int minutes = 25;
  String? taskId;
  Timer? timer;
  DateTime? startedAt;
  int remaining = 0;
  bool paused = false;

  bool get running => startedAt != null && remaining > 0;

  void _start() {
    startedAt = DateTime.now();
    remaining = minutes * 60;
    paused = false;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (paused || !mounted) return;
      setState(() => remaining--);
      if (remaining <= 0) {
        timer?.cancel();
        await widget.store.recordSession(taskId: taskId, plannedSec: minutes * 60, actualSec: minutes * 60, startedAt: startedAt!);
        await widget.store.notifyFocusComplete('You stayed with it for $minutes minutes.');
        if (mounted) setState(() {});
      }
    });
    setState(() {});
  }

  Future<void> _stop() async {
    timer?.cancel();
    if (startedAt != null) {
      final actual = minutes * 60 - remaining;
      if (actual > 0) await widget.store.recordSession(taskId: taskId, plannedSec: minutes * 60, actualSec: actual, startedAt: startedAt!);
    }
    setState(() { startedAt = null; remaining = 0; paused = false; });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.store.data.tasks.where((task) => !task.done).toList()..sort(_taskSort);
    final label = '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text('Focus', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [_ink, _green], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Column(children: [
            Text(running ? (paused ? 'Paused' : 'Focus session') : 'One task at a time.', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: running ? 1 - remaining / (minutes * 60) : 0, strokeWidth: 10, color: _gold, backgroundColor: Colors.white12),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(running ? label : '$minutes:00', style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -2)),
                  Text(taskId == null ? 'General focus' : (tasks.where((task) => task.id == taskId).firstOrNull?.title ?? 'Task'), style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            if (running)
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _stop, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.all(15)), child: const Text('End'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => setState(() => paused = !paused), style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _ink, padding: const EdgeInsets.all(15)), child: Text(paused ? 'Resume' : 'Pause'))),
              ])
            else
              FilledButton(onPressed: _start, style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _ink, minimumSize: const Size.fromHeight(52)), child: const Text('Start focus session')),
          ]),
        ),
        if (!running) ...[
          const SizedBox(height: 18),
          DropdownButtonFormField<String?>(initialValue: taskId, decoration: const InputDecoration(labelText: 'What are you working on?'), items: [const DropdownMenuItem<String?>(value: null, child: Text('General focus')), ...tasks.map((task) => DropdownMenuItem<String?>(value: task.id, child: Text(task.title, overflow: TextOverflow.ellipsis)))], onChanged: (value) => setState(() => taskId = value)),
          const SizedBox(height: 14),
          SegmentedButton<int>(segments: const [ButtonSegment(value: 15, label: Text('15 min')), ButtonSegment(value: 25, label: Text('25 min')), ButtonSegment(value: 45, label: Text('45 min'))], selected: {minutes}, onSelectionChanged: (value) => setState(() => minutes = value.first)),
        ],
      ],
    );
  }
}

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.store});
  final DayFlowStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = ymd(now);
    final weekStart = ymd(dateOnly(now).subtract(Duration(days: now.weekday - 1)));
    final doneToday = store.data.tasks.where((task) => task.done && task.completedAt?.startsWith(today) == true).length;
    final doneWeek = store.data.tasks.where((task) => task.done && (task.completedAt ?? '').compareTo(weekStart) >= 0).length;
    final focusToday = store.data.sessions.where((item) => item.endAt.startsWith(today)).fold<int>(0, (sum, item) => sum + item.actualSec) ~/ 60;
    final streak = _currentStreak(store.data);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text('Insights', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [_ink, _green])),
          child: Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: _gold, size: 48),
            const SizedBox(width: 14),
            Text('$streak', style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            const Expanded(child: Text('days in a row\nKeep showing up.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _MetricCard(value: '$doneToday', label: 'tasks done today'),
            _MetricCard(value: '$doneWeek', label: 'tasks done this week'),
            _MetricCard(value: '$focusToday', label: 'focus minutes today'),
            _MetricCard(value: '${store.data.badges.length}', label: 'badges carried over'),
          ],
        ),
        const SizedBox(height: 18),
        const Text('Last 7 days', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final date = dateOnly(now).subtract(Duration(days: 6 - index));
                  final count = store.data.tasks
                      .where((task) => task.done && task.completedAt?.startsWith(ymd(date)) == true)
                      .length;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 20,
                              height: (18 + count * 18).clamp(18, 115).toDouble(),
                              decoration: BoxDecoration(
                                color: count == 0 ? _green.withValues(alpha: .12) : _green,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('E').format(date).substring(0, 1),
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final DayFlowStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController name;
  late final TextEditingController tip;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.store.data.prefs['name'] as String? ?? '');
    tip = TextEditingController();
  }

  @override
  void dispose() {
    name.dispose();
    tip.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final file = await StorageService().createExport(widget.store.data);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')], text: 'DayFlow backup');
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    try {
      final source = await File(path).readAsString();
      final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Replace your DayFlow data?'), content: const Text('Importing replaces tasks, sessions, preferences, tips and badges on this device.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import'))])) ?? false;
      if (!ok) return;
      await widget.store.importJson(source);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DayFlow data imported')));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.store.data.prefs['theme'] as String? ?? 'system';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, maxLength: 30, decoration: const InputDecoration(labelText: 'Your name'), onSubmitted: (value) async { widget.store.data.prefs['name'] = value.trim(); await widget.store.saveData(); }),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: theme, decoration: const InputDecoration(labelText: 'Appearance'), items: const [DropdownMenuItem(value: 'system', child: Text('Use phone setting')), DropdownMenuItem(value: 'light', child: Text('Light')), DropdownMenuItem(value: 'dark', child: Text('Dark'))], onChanged: (value) async { widget.store.data.prefs['theme'] = value; await widget.store.saveData(); }),
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Your tips'),
        Row(children: [Expanded(child: TextField(controller: tip, maxLength: 140, decoration: const InputDecoration(hintText: 'Add a reminder or motto'))), const SizedBox(width: 8), IconButton.filled(onPressed: () async { final text = tip.text.trim(); if (text.isEmpty) return; widget.store.data.tips.insert(0, PersonalTip(id: newId('t'), text: text, createdAt: DateTime.now().toIso8601String())); tip.clear(); await widget.store.saveData(); }, icon: const Icon(Icons.add))]),
        for (final item in widget.store.data.tips) ListTile(title: Text(item.text), trailing: IconButton(onPressed: () async { widget.store.data.tips.removeWhere((tip) => tip.id == item.id); await widget.store.saveData(); }, icon: const Icon(Icons.delete_outline))),
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Your data'),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.file_upload_outlined), title: const Text('Export data'), subtitle: const Text('Creates a PWA-compatible DayFlow v1 JSON file'), onTap: _export),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.file_download_outlined), title: const Text('Import data'), subtitle: const Text('Restore an export from the web app or this app'), onTap: _import),
        ])),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Reset DayFlow?'), content: const Text('This removes all local data. Export a backup first if you need it.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset'))])) ?? false; if (ok) await widget.store.reset(); }, icon: const Icon(Icons.delete_forever_outlined), label: const Text('Reset DayFlow')),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _green)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: _muted))])));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});
  final String title;
  final int? count;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (count != null) Text('$count', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))]));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icon(icon, size: 38, color: _green), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 4), Text(body, textAlign: TextAlign.center, style: const TextStyle(color: _muted))])));
}

int _taskSort(DayFlowTask a, DayFlowTask b) {
  const rank = {'high': 0, 'medium': 1, 'low': 2};
  final done = (a.done ? 1 : 0).compareTo(b.done ? 1 : 0);
  if (done != 0) return done;
  final priority = rank[a.priority]!.compareTo(rank[b.priority]!);
  if (priority != 0) return priority;
  final date = a.date.compareTo(b.date);
  if (date != 0) return date;
  return (a.time ?? '99:99').compareTo(b.time ?? '99:99');
}

String _formatTime(String value) {
  final parts = value.split(':');
  return DateFormat.jm().format(DateTime(2020, 1, 1, int.parse(parts[0]), int.parse(parts[1])));
}

int _currentStreak(DayFlowData data) {
  final active = <String>{};
  for (final task in data.tasks) {
    final completed = DateTime.tryParse(task.completedAt ?? '');
    if (task.done && completed != null) active.add(ymd(completed));
  }
  for (final session in data.sessions) {
    if (session.completed) active.add(ymd(DateTime.parse(session.endAt)));
  }
  var cursor = dateOnly(DateTime.now());
  if (!active.contains(ymd(cursor))) cursor = cursor.subtract(const Duration(days: 1));
  var streak = 0;
  while (active.contains(ymd(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
