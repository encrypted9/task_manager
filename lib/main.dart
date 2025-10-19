import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(TaskManagerApp());
}

enum Priority { high, medium, low }

extension PriorityExt on Priority {
  String get label {
    switch (this) {
      case Priority.high:
        return 'High';
      case Priority.medium:
        return 'Medium';
      case Priority.low:
      default:
        return 'Low';
    }
  }

  int get value {
    switch (this) {
      case Priority.high:
        return 3;
      case Priority.medium:
        return 2;
      case Priority.low:
      default:
        return 1;
    }
  }
}

class Task {
  String name;
  bool completed;
  Priority priority;

  Task({required this.name, this.completed = false, this.priority = Priority.medium});

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      name: json['name'] ?? '',
      completed: json['completed'] ?? false,
      priority: Priority.values[(json['priority'] ?? 1)],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'completed': completed,
        'priority': priority.index,
      };
}

class TaskManagerApp extends StatefulWidget {
  @override
  _TaskManagerAppState createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends State<TaskManagerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _toggleTheme(bool isDark) async {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        appBarTheme: AppBarTheme(elevation: 2),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueGrey,
        appBarTheme: AppBarTheme(elevation: 2),
      ),
      home: TaskListScreen(onToggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  final Function(bool) onToggleTheme;
  final ThemeMode themeMode;

  TaskListScreen({required this.onToggleTheme, required this.themeMode});

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _controller = TextEditingController();
  Priority _selectedPriority = Priority.medium;
  List<Task> _tasks = [];
  bool _sortByPriorityDesc = true;

  static const _prefsKey = 'tasks_v1';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final List decoded = json.decode(raw);
        setState(() {
          _tasks = decoded.map((e) => Task.fromJson(Map<String, dynamic>.from(e))).toList();
          _applySorting();
        });
      } catch (e) {
        // corrupted data - ignore
        setState(() => _tasks = []);
      }
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  void _addTask() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _tasks.add(Task(name: text, completed: false, priority: _selectedPriority));
      _controller.clear();
      _applySorting();
    });
    _saveTasks();
  }

  void _toggleCompleted(int index, bool? value) {
    if (value == null) return;
    setState(() {
      _tasks[index].completed = value;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  void _applySorting() {
    setState(() {
      _tasks.sort((a, b) {
        if (_sortByPriorityDesc) {
          final cmp = b.priority.value.compareTo(a.priority.value);
          if (cmp != 0) return cmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        } else {
          final cmp = a.priority.value.compareTo(b.priority.value);
          if (cmp != 0) return cmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      });
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortByPriorityDesc = !_sortByPriorityDesc;
      _applySorting();
    });
  }

  void _changePriority(int index, Priority newPriority) {
    setState(() {
      _tasks[index].priority = newPriority;
      _applySorting();
    });
    _saveTasks();
  }

  Widget _buildPriorityChip(Priority p) {
    final text = p.label;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).chipTheme.backgroundColor ?? Colors.grey.shade300,
      ),
      child: Text(text, style: TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
        actions: [
          IconButton(
            tooltip: 'Sort by priority',
            icon: Icon(Icons.sort),
            onPressed: _toggleSortOrder,
          ),
          Row(children: [
            Icon(Icons.light_mode, size: 18),
            Switch(
              value: widget.themeMode == ThemeMode.dark,
              onChanged: (v) => widget.onToggleTheme(v),
            ),
            Icon(Icons.dark_mode, size: 18),
          ])
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Enter task name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addTask,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text('Priority:'),
                SizedBox(width: 8),
                DropdownButton<Priority>(
                  value: _selectedPriority,
                  items: Priority.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (p) {
                    if (p == null) return;
                    setState(() => _selectedPriority = p);
                  },
                ),
                Spacer(),
                Text('Sorting: ' + (_sortByPriorityDesc ? 'High → Low' : 'Low → High')),
              ],
            ),
            SizedBox(height: 12),
            Expanded(
              child: _tasks.isEmpty
                  ? Center(child: Text('No tasks yet — add one!'))
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final t = _tasks[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: Checkbox(
                              value: t.completed,
                              onChanged: (val) => _toggleCompleted(index, val),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name,
                                    style: TextStyle(
                                      decoration: t.completed ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                _buildPriorityChip(t.priority),
                              ],
                            ),
                            subtitle: Text(t.completed ? 'Completed' : 'Incomplete'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Priority change menu
                                PopupMenuButton<Priority>(
                                  tooltip: 'Change priority',
                                  onSelected: (p) => _changePriority(index, p),
                                  itemBuilder: (ctx) => Priority.values
                                      .map((p) => PopupMenuItem(value: p, child: Text(p.label)))
                                      .toList(),
                                  child: Icon(Icons.flag),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => _confirmDelete(index),
                                ),
                              ],
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

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete task?'),
        content: Text('Are you sure you want to delete "${_tasks[index].name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTask(index);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }
}
