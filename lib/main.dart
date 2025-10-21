import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool('isDark') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = value;
    });
    await prefs.setBool('isDark', _isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: TaskListScreen(
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

// ----- Task model -----
class Task {
  final String id;
  String name;
  bool completed;
  int priority; // 1=Low, 2=Medium, 3=High

  Task({
    required this.id,
    required this.name,
    this.completed = false,
    this.priority = 2,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        completed: json['completed'] as bool? ?? false,
        priority: json['priority'] as int? ?? 2,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'completed': completed,
        'priority': priority,
      };
}

enum Priority { low, medium, high }

extension PriorityX on Priority {
  int get value =>
      switch (this) { Priority.low => 1, Priority.medium => 2, Priority.high => 3 };
  String get label =>
      switch (this) { Priority.low => 'Low', Priority.medium => 'Medium', Priority.high => 'High' };

  static Priority fromInt(int v) =>
      v <= 1 ? Priority.low : (v >= 3 ? Priority.high : Priority.medium);

  // Updated colors
  static Color colorFor(BuildContext context, int v) {
    return switch (fromInt(v)) {
      Priority.high => Colors.red,
      Priority.medium => Colors.yellow.shade700,
      Priority.low => Colors.green,
    };
  }
}

// ----- Task List Screen -----
class TaskListScreen extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onToggleTheme;
  const TaskListScreen(
      {super.key, required this.isDark, required this.onToggleTheme});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _controller = TextEditingController();
  Priority _selectedPriority = Priority.medium;
  final List<Task> _tasks = [];
  bool _sortHighFirst = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tasks');
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List;
      _tasks
        ..clear()
        ..addAll(decoded.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      setState(() {});
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString('tasks', raw);
  }

  void _addTask() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _tasks.add(Task(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: text,
        priority: _selectedPriority.value,
      ));
      _controller.clear();
    });
    _sortByPriority(announce: false);
    _saveTasks();
  }

  void _toggleComplete(Task task, bool? value) {
    setState(() {
      task.completed = value ?? false;
    });
    _saveTasks();
  }

  void _deleteTask(Task task) {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    _saveTasks();
  }

  void _sortByPriority({bool announce = true}) {
    setState(() {
      _tasks.sort((a, b) => _sortHighFirst
          ? b.priority.compareTo(a.priority)
          : a.priority.compareTo(b.priority));
    });
    if (announce && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sorted by priority (${_sortHighFirst ? 'High → Low' : 'Low → High'})'),
        ),
      );
    }
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            tooltip: 'Sort by priority',
            onPressed: _sortByPriority,
            icon: const Icon(Icons.sort),
          ),
          Row(children: [
            const Icon(Icons.light_mode),
            Switch(
              value: widget.isDark,
              onChanged: widget.onToggleTheme,
            ),
            const Icon(Icons.dark_mode),
          ]),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Updated layout: vertical inputs ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Task name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _addTask(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Priority>(
                  value: _selectedPriority,
                  onChanged: (p) => setState(
                      () => _selectedPriority = p ?? Priority.medium),
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: Priority.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.label),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(
                    'Sorting: ${_sortHighFirst ? 'High → Low' : 'Low → High'}'),
                avatar: const Icon(Icons.priority_high),
                selected: true,
                onSelected: (_) {
                  setState(() => _sortHighFirst = !_sortHighFirst);
                  _sortByPriority();
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox, size: 48, color: scheme.outline),
                          const SizedBox(height: 8),
                          Text('Name your task, set your priority then add!',
                              style: TextStyle(color: scheme.outline)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Dismissible(
                          key: ValueKey(task.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: scheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(Icons.delete,
                                color: scheme.onErrorContainer),
                          ),
                          onDismissed: (_) => _deleteTask(task),
                          child: ListTile(
                            leading: Checkbox(
                              value: task.completed,
                              onChanged: (v) => _toggleComplete(task, v),
                            ),
                            title: Text(
                              task.name,
                              style: TextStyle(
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                _PriorityBadge(priority: task.priority),
                                const SizedBox(width: 12),
                                if (task.completed)
                                  const Text('Completed',
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic)),
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _deleteTask(task),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final int priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = PriorityX.colorFor(context, priority);
    final text = PriorityX.fromInt(priority).label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}