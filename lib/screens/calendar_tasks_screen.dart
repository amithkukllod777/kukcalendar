import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../db_calendar.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Google-Tasks-style to-do list for Kuk Calendar. Offline-first, stored in the
/// local calendar_tasks table.
class CalendarTasksScreen extends StatefulWidget {
  const CalendarTasksScreen({super.key});
  @override
  State<CalendarTasksScreen> createState() => _CalendarTasksScreenState();
}

class _CalendarTasksScreenState extends State<CalendarTasksScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _tasks = [];
  final _dfmt = DateFormat('EEE, d MMM');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await AppDb.instance.getCalendarTasks();
      if (mounted) setState(() { _tasks = t; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _tasks = []; _loading = false; });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleCtl =
        TextEditingController(text: (existing?['title'] as String?) ?? '');
    final notesCtl =
        TextEditingController(text: (existing?['notes'] as String?) ?? '');
    DateTime? due;
    final ds = (existing?['dueDate'] as String?) ?? '';
    if (ds.isNotEmpty) {
      try {
        due = DateTime.parse(ds);
      } catch (_) {}
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(isEdit ? 'Edit task' : 'New task',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtl,
                autofocus: !isEdit,
                decoration: const InputDecoration(
                    labelText: 'Task', hintText: 'What do you need to do?'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtl,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Details (optional)'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(due == null
                        ? 'Add date'
                        : _dfmt.format(due!)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: due ?? DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setSheet(() => due = d);
                    },
                  ),
                ),
                if (due != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setSheet(() => due = null),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                if (isEdit)
                  TextButton.icon(
                    onPressed: () async {
                      await AppDb.instance
                          .deleteCalendarTask(existing['id'] as int);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.danger),
                    label: const Text('Delete',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    if (titleCtl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Task title is required')));
                      return;
                    }
                    await AppDb.instance.saveCalendarTask(
                      id: isEdit ? existing['id'] as int? : null,
                      title: titleCtl.text.trim(),
                      notes: notesCtl.text.trim(),
                      dueDate: due == null
                          ? ''
                          : '${due!.year.toString().padLeft(4, '0')}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}',
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: _loading
          ? const LoadingView()
          : _tasks.isEmpty
              ? const EmptyState(
                  icon: Icons.checklist_rtl_outlined,
                  title: 'No tasks yet',
                  subtitle: 'Tap + to add a to-do.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _tile(_tasks[i]),
                ),
    );
  }

  Widget _tile(Map<String, dynamic> t) {
    final done = t['completed'] == true;
    final ds = (t['dueDate'] as String?) ?? '';
    DateTime? due;
    if (ds.isNotEmpty) {
      try {
        due = DateTime.parse(ds);
      } catch (_) {}
    }
    final overdue = due != null &&
        !done &&
        due.isBefore(DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day));
    return AppCard(
      onTap: () => _openForm(existing: t),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: done,
            shape: const CircleBorder(),
            onChanged: (v) async {
              await AppDb.instance
                  .toggleCalendarTask(t['id'] as int, v ?? false);
              await _load();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (t['title'] as String?) ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? AppColors.textSecondary : null,
                  ),
                ),
                if (due != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(_dfmt.format(due),
                        style: TextStyle(
                            fontSize: 12,
                            color: overdue
                                ? AppColors.danger
                                : AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child:
                Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
