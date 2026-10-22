import 'package:flutter/material.dart';

import '../brand.dart';
import '../controller.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.controller});

  final PomodoroController controller;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    widget.controller.addTask(_input.text);
    _input.clear();
  }

  void _delete(TaskItem task) {
    final index = widget.controller.deleteTask(task);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.tr('taskDeleted')),
          action: SnackBarAction(
            label: context.tr('undo'),
            onPressed: () => widget.controller.restoreTask(task, index),
          ),
        ),
      );
  }

  Future<void> _edit(TaskItem task) async {
    final result = await showDialog<({String title, int estimate})>(
      context: context,
      builder: (_) => _EditTaskDialog(task: task),
    );
    if (result != null) {
      widget.controller.updateTask(
        task,
        title: result.title,
        estimate: result.estimate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final open = c.tasks.where((t) => !t.isDone).toList();
        final done = c.tasks.where((t) => t.isDone).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('tasks')),
            actions: [
              if (done.isNotEmpty)
                IconButton(
                  onPressed: c.clearDoneTasks,
                  tooltip: context.tr('clearDone'),
                  icon: const Icon(Icons.cleaning_services_rounded),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: context.tr('newTaskHint'),
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _add,
                    tooltip: context.tr('addTask'),
                    style: IconButton.styleFrom(
                      backgroundColor: Brand.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (c.tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.checklist_rounded,
                        size: 56,
                        color: Brand.chartBar,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('noTasks'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Brand.textSecondary),
                      ),
                    ],
                  ),
                ),
              if (open.isNotEmpty) ...[
                SectionHeader('${context.tr('openTasks')} · ${open.length}'),
                for (final task in open) _taskTile(c, task),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionHeader('${context.tr('doneTasks')} · ${done.length}'),
                for (final task in done) _taskTile(c, task),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _taskTile(PomodoroController c, TaskItem task) {
    final isActive = c.activeTaskId == task.id;
    final count = c.pomodorosForTask(task.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(task.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(task),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(60),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline_rounded),
        ),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isActive ? Brand.chartBar : Brand.outline,
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: ListTile(
            onTap: () => _edit(task),
            contentPadding: const EdgeInsets.only(left: 8, right: 4),
            leading: Checkbox(
              value: task.isDone,
              shape: const CircleBorder(),
              onChanged: (_) => c.toggleTask(task),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                color: task.isDone ? Brand.textMuted : Brand.textPrimary,
              ),
            ),
            subtitle:
                count > 0 || task.estimate > 0
                    ? _TaskProgress(done: count, estimate: task.estimate)
                    : null,
            trailing:
                task.isDone
                    ? IconButton(
                      onPressed: () => _delete(task),
                      tooltip: context.tr('deleteTask'),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    )
                    : IconButton(
                      onPressed:
                          () => c.setActiveTask(isActive ? null : task.id),
                      tooltip: context.tr('setActive'),
                      icon: Icon(
                        isActive
                            ? Icons.flag_rounded
                            : Icons.outlined_flag_rounded,
                        color: isActive ? Brand.cyan : Brand.textMuted,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class _TaskProgress extends StatelessWidget {
  const _TaskProgress({required this.done, required this.estimate});

  final int done;
  final int estimate;

  @override
  Widget build(BuildContext context) {
    final label =
        estimate > 0
            ? '$done / $estimate ${context.tr('pomodoroCount')}'
            : '$done ${context.tr('pomodoroCount')}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Brand.textMuted, fontSize: 12),
          ),
          if (estimate > 0) ...[
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (done / estimate).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Brand.surfaceHigh,
                  color: done >= estimate ? Brand.success : Brand.chartBar,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _EditTaskDialog extends StatefulWidget {
  const _EditTaskDialog({required this.task});

  final TaskItem task;

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late final _title = TextEditingController(text: widget.task.title);
  late int _estimate = widget.task.estimate;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('editTask')),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.tr('taskTitle')),
            ),
          ),
          const SizedBox(height: 12),
          Transform.translate(
            offset: const Offset(-16, 0),
            child: NumberStepper(
              label: context.tr('estimate'),
              valueLabel:
                  _estimate == 0 ? context.tr('noEstimate') : '$_estimate',
              value: _estimate,
              range: AppSettings.estimateRange,
              onChanged: (v) => setState(() => _estimate = v),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed:
              () => Navigator.pop(context, (
                title: _title.text,
                estimate: _estimate,
              )),
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}
