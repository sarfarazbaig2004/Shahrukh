import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const List<String> kTaskStatuses = [
  'Pending',
  'In Progress',
  'Completed',
  'On Hold',
];

const List<String> kTaskPriorities = ['Low', 'Medium', 'High', 'Critical'];

String normalizeTaskStatus(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();

  if (raw == 'in progress' || raw == 'in_progress' || raw == 'progress') {
    return 'In Progress';
  }
  if (raw == 'completed' || raw == 'complete' || raw == 'done') {
    return 'Completed';
  }
  if (raw == 'on hold' ||
      raw == 'on_hold' ||
      raw == 'hold' ||
      raw == 'cancelled' ||
      raw == 'canceled') {
    return 'On Hold';
  }

  return 'Pending';
}

String normalizeTaskPriority(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();

  if (raw == 'low') return 'Low';
  if (raw == 'high') return 'High';
  if (raw == 'critical' || raw == 'urgent') return 'Critical';

  return 'Medium';
}

List<DropdownMenuItem<String>> taskStatusItems({bool includeAll = false}) {
  final values = <String>[
    if (includeAll) 'All',
    ...kTaskStatuses,
  ].toSet().toList();

  return values
      .map(
        (status) =>
            DropdownMenuItem<String>(value: status, child: Text(status)),
      )
      .toList();
}

List<DropdownMenuItem<String>> taskPriorityItems({bool includeAll = false}) {
  final values = <String>[
    if (includeAll) 'All',
    ...kTaskPriorities,
  ].toSet().toList();

  return values
      .map(
        (priority) =>
            DropdownMenuItem<String>(value: priority, child: Text(priority)),
      )
      .toList();
}

class TaskListScreen extends StatefulWidget {
  final String? companyId;
  final String? userUid;
  final String? currentUserId;
  final String? currentUserUid;
  final String? currentUserName;
  final String? userName;
  final String? userEmail;
  final String? currentUserEmail;
  final String? role;
  final String? currentUserRole;

  const TaskListScreen({
    super.key,
    this.companyId,
    this.userUid,
    this.currentUserId,
    this.currentUserUid,
    this.currentUserName,
    this.userName,
    this.userEmail,
    this.currentUserEmail,
    this.role,
    this.currentUserRole,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  String _searchQuery = '';
  bool _sortAscending = false;

  String get _companyId => (widget.companyId ?? '').trim();

  String get _currentUserId {
    final authUser = FirebaseAuth.instance.currentUser;
    return (widget.currentUserId ??
            widget.currentUserUid ??
            widget.userUid ??
            authUser?.uid ??
            '')
        .trim();
  }

  String get _currentUserName {
    final authUser = FirebaseAuth.instance.currentUser;
    return (widget.currentUserName ??
            widget.userName ??
            authUser?.displayName ??
            authUser?.email ??
            'User')
        .trim();
  }

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _db.collection('companies').doc(_companyId).collection('tasks');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _nextTaskNumber() async {
    final year = DateTime.now().year.toString();
    final prefix = 'TASK-$year-';

    final snap = await _tasksRef
        .where('taskNumber', isGreaterThanOrEqualTo: prefix)
        .where('taskNumber', isLessThan: '$prefix\uf8ff')
        .get();

    var maxNo = 0;

    for (final doc in snap.docs) {
      final taskNumber = (doc.data()['taskNumber'] ?? '').toString().trim();
      final match = RegExp(r'^TASK-\d{4}-(\d+)$').firstMatch(taskNumber);
      if (match == null) continue;

      final no = int.tryParse(match.group(1) ?? '') ?? 0;
      if (no > maxNo) maxNo = no;
    }

    var nextNo = maxNo + 1;

    while (true) {
      final candidate = '$prefix${nextNo.toString().padLeft(3, '0')}';

      final existing = await _tasksRef
          .where('taskNumber', isEqualTo: candidate)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return candidate;
      }

      nextNo++;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream() {
    return _tasksRef.snapshots();
  }

  List<_TaskRecord> _filteredTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    final tasks = docs.map(_TaskRecord.fromDoc).where((task) {
      final statusOk =
          _statusFilter == 'All' ||
          task.status == normalizeTaskStatus(_statusFilter);

      final priorityOk =
          _priorityFilter == 'All' ||
          task.priority == normalizeTaskPriority(_priorityFilter);

      final text = [
        task.taskNumber,
        task.title,
        task.description,
        task.assignedToName,
      ].join(' ').toLowerCase();

      final searchOk = query.isEmpty || text.contains(query);

      return statusOk && priorityOk && searchOk;
    }).toList();

    tasks.sort((a, b) {
      final aDate = a.dueDate ?? a.createdAt ?? DateTime(1900);
      final bDate = b.dueDate ?? b.createdAt ?? DateTime(1900);
      return _sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });

    return tasks;
  }

  Future<void> _createTaskDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final assignedNameCtrl = TextEditingController(text: _currentUserName);
    final assignedUidCtrl = TextEditingController(text: _currentUserId);

    String selectedStatus = 'Pending';
    String selectedPriority = 'Medium';
    DateTime? dueDate;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveTask() async {
              if (titleCtrl.text.trim().isEmpty) {
                _showMessage('Task title is required');
                return;
              }

              setDialogState(() => saving = true);

              try {
                final taskNumber = await _nextTaskNumber();

                await _tasksRef.add({
                  'taskNumber': taskNumber,
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'status': normalizeTaskStatus(selectedStatus),
                  'priority': normalizeTaskPriority(selectedPriority),
                  'assignedToName': assignedNameCtrl.text.trim(),
                  'assignedToUid': assignedUidCtrl.text.trim(),
                  'assignedToUids': assignedUidCtrl.text.trim().isEmpty
                      ? <String>[]
                      : <String>[assignedUidCtrl.text.trim()],
                  'createdByUid': _currentUserId,
                  'createdByName': _currentUserName,
                  'dueDate': dueDate == null
                      ? null
                      : Timestamp.fromDate(dueDate!),
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) Navigator.pop(dialogContext);
                _showMessage('Task created successfully');
              } catch (e) {
                _showMessage('Failed to create task: $e');
              } finally {
                if (mounted) setDialogState(() => saving = false);
              }
            }

            return AlertDialog(
              title: const Text('Create Task'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Task Title *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: taskStatusItems(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedStatus = normalizeTaskStatus(value);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedPriority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(),
                              ),
                              items: taskPriorityItems(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedPriority = normalizeTaskPriority(
                                    value,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: assignedNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Assigned To Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: assignedUidCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Assigned To UID',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: dueDate ?? DateTime.now(),
                          );

                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            dueDate == null
                                ? 'Select due date'
                                : DateFormat('dd/MM/yyyy').format(dueDate!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : saveTask,
                  icon: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(saving ? 'Saving...' : 'Save Task'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    descCtrl.dispose();
    assignedNameCtrl.dispose();
    assignedUidCtrl.dispose();
  }

  Future<void> _updateTaskStatus(_TaskRecord task, String? newStatus) async {
    final status = normalizeTaskStatus(newStatus);

    await task.ref.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'Completed') 'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteTask(_TaskRecord task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete ${task.taskNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await task.ref.delete();
      _showMessage('Task deleted');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _statusColor(String status) {
    switch (normalizeTaskStatus(status)) {
      case 'In Progress':
        return const Color(0xFF2563EB);
      case 'Completed':
        return const Color(0xFF16A34A);
      case 'On Hold':
        return const Color(0xFFF59E0B);
      case 'Pending':
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _priorityColor(String priority) {
    switch (normalizeTaskPriority(priority)) {
      case 'Low':
        return const Color(0xFF64748B);
      case 'High':
        return const Color(0xFFF97316);
      case 'Critical':
        return const Color(0xFFDC2626);
      case 'Medium':
      default:
        return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty) {
      return const Center(
        child: Text('Company not selected. Task module cannot load.'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildToolbar(),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _taskStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load tasks: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = _filteredTasks(snapshot.data!.docs);

                  return Column(
                    children: [
                      _buildSummary(tasks),
                      const SizedBox(height: 14),
                      Expanded(
                        child: tasks.isEmpty
                            ? const Center(child: Text('No tasks found'))
                            : ListView.separated(
                                itemCount: tasks.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  return _TaskCard(
                                    task: task,
                                    statusColor: _statusColor(task.status),
                                    priorityColor: _priorityColor(
                                      task.priority,
                                    ),
                                    onStatusChanged: (value) =>
                                        _updateTaskStatus(task, value),
                                    onDelete: () => _deleteTask(task),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Tasks',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        FilledButton.icon(
          onPressed: _createTaskDialog,
          icon: const Icon(Icons.add_task),
          label: const Text('Create Task'),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                labelText: 'Search tasks',
                hintText: 'Task no, title, assignee...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              value: _statusFilter == 'All'
                  ? 'All'
                  : normalizeTaskStatus(_statusFilter),
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: taskStatusItems(includeAll: true),
              onChanged: (value) {
                setState(() {
                  _statusFilter = value == 'All'
                      ? 'All'
                      : normalizeTaskStatus(value);
                });
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: _priorityFilter == 'All'
                  ? 'All'
                  : normalizeTaskPriority(_priorityFilter),
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: taskPriorityItems(includeAll: true),
              onChanged: (value) {
                setState(() {
                  _priorityFilter = value == 'All'
                      ? 'All'
                      : normalizeTaskPriority(value);
                });
              },
            ),
          ),
          IconButton.filledTonal(
            tooltip: _sortAscending ? 'Oldest first' : 'Newest first',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<_TaskRecord> tasks) {
    final pending = tasks.where((t) => t.status == 'Pending').length;
    final progress = tasks.where((t) => t.status == 'In Progress').length;
    final completed = tasks.where((t) => t.status == 'Completed').length;
    final hold = tasks.where((t) => t.status == 'On Hold').length;
    final critical = tasks.where((t) => t.priority == 'Critical').length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryChip(label: 'Total', value: tasks.length.toString()),
        _SummaryChip(label: 'Pending', value: pending.toString()),
        _SummaryChip(label: 'In Progress', value: progress.toString()),
        _SummaryChip(label: 'Completed', value: completed.toString()),
        _SummaryChip(label: 'On Hold', value: hold.toString()),
        _SummaryChip(label: 'Critical', value: critical.toString()),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final _TaskRecord task;
  final Color statusColor;
  final Color priorityColor;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.statusColor,
    required this.priorityColor,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dueText = task.dueDate == null
        ? 'No due date'
        : DateFormat('dd/MM/yyyy').format(task.dueDate!);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  task.taskNumber.isEmpty ? 'TASK' : task.taskNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: normalizeTaskStatus(task.status),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: taskStatusItems(),
                    onChanged: onStatusChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description,
                style: const TextStyle(color: Color(0xFF475569)),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniPill(
                  label: task.status,
                  color: statusColor,
                  icon: Icons.flag_outlined,
                ),
                _MiniPill(
                  label: task.priority,
                  color: priorityColor,
                  icon: Icons.priority_high,
                ),
                _MiniPill(
                  label: 'Due: $dueText',
                  color: const Color(0xFF64748B),
                  icon: Icons.event_outlined,
                ),
                if (task.assignedToName.isNotEmpty)
                  _MiniPill(
                    label: 'Assigned: ${task.assignedToName}',
                    color: const Color(0xFF2563EB),
                    icon: Icons.person_outline,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      label: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _MiniPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRecord {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String taskNumber;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String assignedToName;
  final String assignedToUid;
  final DateTime? dueDate;
  final DateTime? createdAt;

  const _TaskRecord({
    required this.id,
    required this.ref,
    required this.taskNumber,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignedToName,
    required this.assignedToUid,
    required this.dueDate,
    required this.createdAt,
  });

  factory _TaskRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    String str(dynamic value) => (value ?? '').toString().trim();

    DateTime? date(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return _TaskRecord(
      id: doc.id,
      ref: doc.reference,
      taskNumber: str(data['taskNumber']).isEmpty
          ? str(data['taskNo'])
          : str(data['taskNumber']),
      title: str(data['title']).isEmpty ? 'Untitled Task' : str(data['title']),
      description: str(data['description']),
      status: normalizeTaskStatus(data['status']),
      priority: normalizeTaskPriority(data['priority']),
      assignedToName: str(data['assignedToName']),
      assignedToUid: str(data['assignedToUid']),
      dueDate: date(data['dueDate']),
      createdAt: date(data['createdAt']),
    );
  }
}
