import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const TaskListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortField = 'dueDate';
  bool _sortAscending = true;

  static const List<String> taskStatuses = [
    'Pending',
    'In Progress',
    'Completed',
    'On Hold',
  ];

  static const List<String> taskPriorities = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _db.collection('companies').doc(widget.companyId).collection('tasks');

  CollectionReference<Map<String, dynamic>> get _countersRef =>
      _db.collection('companies').doc(widget.companyId).collection('counters');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('companies').doc(widget.companyId).collection('users');

  CollectionReference<Map<String, dynamic>> get _notificationsRef => _db
      .collection('companies')
      .doc(widget.companyId)
      .collection('notifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream() {
    return _tasksRef.snapshots();
  }

  String _safeString(dynamic value) => (value ?? '').toString().trim();

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(dynamic value) {
    final date = _toDate(value);
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _currentYear() => DateTime.now().year.toString();

  Future<String> _nextTaskNumber(Transaction transaction) async {
    final year = _currentYear();
    final counterRef = _countersRef.doc('task_counter_$year');
    final counterSnap = await transaction.get(counterRef);

    int currentSeq = 1;
    if (counterSnap.exists) {
      currentSeq = ((counterSnap.data()?['sequence'] ?? 0) as num).toInt() + 1;
    }

    final formatted = currentSeq.toString().padLeft(3, '0');

    transaction.set(counterRef, <String, dynamic>{
      'sequence': currentSeq,
      'year': year,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return 'TASK-$year-$formatted';
  }

  Future<List<_UserOption>> _loadUsers() async {
    final snap = await _usersRef.limit(200).get();
    final list = snap.docs.map((doc) {
      final data = doc.data();
      final name = _safeString(
        data['displayName'] ??
            data['name'] ??
            data['employeeName'] ??
            data['email'] ??
            doc.id,
      );
      return _UserOption(
        uid: doc.id,
        name: name.isEmpty ? doc.id : name,
        email: _safeString(data['email']),
      );
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!list.any((u) => u.uid == widget.currentUserUid)) {
      list.insert(
        0,
        _UserOption(
          uid: widget.currentUserUid,
          name: widget.currentUserName.isEmpty
              ? 'Current User'
              : widget.currentUserName,
          email: '',
        ),
      );
    }

    return list;
  }

  List<_TaskRecord> _filterTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    final records = docs
        .map((doc) => _TaskRecord.fromDoc(doc))
        .where((task) => task.isDeleted != true)
        .where((task) {
          if (_statusFilter != 'All' && task.status != _statusFilter) {
            return false;
          }
          if (_priorityFilter != 'All' && task.priority != _priorityFilter) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }

          final haystack = [
            task.taskNumber,
            task.title,
            task.description,
            task.status,
            task.priority,
            task.assignedToName,
            task.createdByName,
            task.comments,
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        })
        .toList();

    int compareText(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    int compareDate(dynamic a, dynamic b) {
      final da = _toDate(a);
      final db = _toDate(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    records.sort((a, b) {
      int result;
      switch (_sortField) {
        case 'taskNumber':
          result = compareText(a.taskNumber, b.taskNumber);
          break;
        case 'title':
          result = compareText(a.title, b.title);
          break;
        case 'assignedToName':
          result = compareText(a.assignedToName, b.assignedToName);
          break;
        case 'status':
          result = compareText(a.status, b.status);
          break;
        case 'priority':
          result = compareText(a.priority, b.priority);
          break;
        case 'startDate':
          result = compareDate(a.startDate, b.startDate);
          break;
        case 'createdAt':
          result = (a.createdAt ?? DateTime(1900)).compareTo(
            b.createdAt ?? DateTime(1900),
          );
          break;
        case 'dueDate':
        default:
          result = compareDate(a.dueDate, b.dueDate);
      }

      return _sortAscending ? result : -result;
    });

    return records;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF16A34A);
      case 'In Progress':
        return const Color(0xFF2563EB);
      case 'On Hold':
        return const Color(0xFFF59E0B);
      case 'Pending':
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFDC2626);
      case 'High':
        return const Color(0xFFF97316);
      case 'Medium':
        return const Color(0xFF2563EB);
      case 'Low':
      default:
        return const Color(0xFF16A34A);
    }
  }

  Future<void> _openCreateTaskDialog() async {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final startDateCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController();
    final estimatedHoursCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final attachmentCtrl = TextEditingController();

    String selectedStatus = 'Pending';
    String selectedPriority = 'Medium';
    DateTime? selectedStartDate;
    DateTime? selectedDueDate;

    _UserOption? selectedUser;

    final usersFuture = _loadUsers();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<List<_UserOption>>(
          future: usersFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const AlertDialog(
                content: SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final users = snap.data ?? <_UserOption>[];

            selectedUser ??= users.isNotEmpty
                ? users.firstWhere(
                    (u) => u.uid == widget.currentUserUid,
                    orElse: () => users.first,
                  )
                : _UserOption(
                    uid: widget.currentUserUid,
                    name: widget.currentUserName,
                    email: '',
                  );

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Create Task'),
                  content: SizedBox(
                    width: 680,
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
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: selectedStatus,
                                  items: taskStatuses
                                      .map(
                                        (status) => DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(
                                        () => selectedStatus = value,
                                      );
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: selectedPriority,
                                  items: taskPriorities
                                      .map(
                                        (priority) => DropdownMenuItem(
                                          value: priority,
                                          child: Text(priority),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(
                                        () => selectedPriority = value,
                                      );
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Priority',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<_UserOption>(
                                  isExpanded: true,
                                  initialValue: selectedUser,
                                  items: users
                                      .map(
                                        (user) => DropdownMenuItem(
                                          value: user,
                                          child: Text(
                                            user.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(
                                        () => selectedUser = value,
                                      );
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Assigned To',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: estimatedHoursCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Estimated Hours',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: startDateCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      initialDate:
                                          selectedStartDate ?? DateTime.now(),
                                    );
                                    if (picked != null) {
                                      selectedStartDate = picked;
                                      startDateCtrl.text = DateFormat(
                                        'dd MMM yyyy',
                                      ).format(picked);
                                      setDialogState(() {});
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: dueDateCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Due Date',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      initialDate:
                                          selectedDueDate ?? DateTime.now(),
                                    );
                                    if (picked != null) {
                                      selectedDueDate = picked;
                                      dueDateCtrl.text = DateFormat(
                                        'dd MMM yyyy',
                                      ).format(picked);
                                      setDialogState(() {});
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descriptionCtrl,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Task Description',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: notesCtrl,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Comments / Notes',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: attachmentCtrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Attachments / Links',
                              hintText:
                                  'Paste file links or attachment references',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Task'),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Task title is required'),
                            ),
                          );
                          return;
                        }

                        final estimatedHours = double.tryParse(
                          estimatedHoursCtrl.text.trim(),
                        );
                        final attachments = attachmentCtrl.text
                            .split(RegExp(r'[\n,]'))
                            .map((value) => value.trim())
                            .where((value) => value.isNotEmpty)
                            .toList();

                        try {
                          await _createTask(
                            title: title,
                            description: descriptionCtrl.text.trim(),
                            status: selectedStatus,
                            priority: selectedPriority,
                            startDate: selectedStartDate,
                            dueDate: selectedDueDate,
                            estimatedHours: estimatedHours,
                            notes: notesCtrl.text.trim(),
                            attachments: attachments,
                            assignee: selectedUser,
                          );

                          if (mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Task created successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Task save failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    descriptionCtrl.dispose();
    startDateCtrl.dispose();
    dueDateCtrl.dispose();
    estimatedHoursCtrl.dispose();
    notesCtrl.dispose();
    attachmentCtrl.dispose();
  }

  Future<void> _createTask({
    required String title,
    required String description,
    required String status,
    required String priority,
    required DateTime? startDate,
    required DateTime? dueDate,
    required double? estimatedHours,
    required String notes,
    required List<String> attachments,
    required _UserOption? assignee,
  }) async {
    final docRef = _tasksRef.doc();

    await _db.runTransaction((transaction) async {
      final taskNumber = await _nextTaskNumber(transaction);
      final assignedTo =
          assignee ??
          _UserOption(
            uid: widget.currentUserUid,
            name: widget.currentUserName,
            email: '',
          );

      final payload = <String, dynamic>{
        'companyId': widget.companyId,
        'taskNumber': taskNumber,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        'startDate': startDate == null ? null : Timestamp.fromDate(startDate),
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
        'estimatedHours': estimatedHours,
        'comments': notes,
        'notes': notes,
        'attachments': attachments,
        'assignedToUid': assignedTo.uid,
        'assignedToName': assignedTo.name,
        'assignedToEmail': assignedTo.email,
        'createdByUid': widget.currentUserUid,
        'createdByName': widget.currentUserName,
        'updatedByUid': widget.currentUserUid,
        'updatedByName': widget.currentUserName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'activityLog': [
          <String, dynamic>{
            'action': 'created',
            'message': 'Task created',
            'byUid': widget.currentUserUid,
            'byName': widget.currentUserName,
            'at': Timestamp.now(),
          },
        ],
      };

      transaction.set(docRef, payload);

      final notificationRef = _notificationsRef.doc();
      transaction.set(notificationRef, <String, dynamic>{
        'companyId': widget.companyId,
        'recipientUid': assignedTo.uid,
        'recipientName': assignedTo.name,
        'recipientEmail': assignedTo.email,
        'type': 'task_assignment',
        'title': 'New task assigned: $taskNumber',
        'message': '$title • Priority: $priority',
        'taskId': docRef.id,
        'taskNumber': taskNumber,
        'taskTitle': title,
        'taskStatus': status,
        'taskPriority': priority,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': widget.currentUserUid,
        'createdByName': widget.currentUserName,
      });
    });
  }

  Future<void> _updateTaskField(
    _TaskRecord task,
    String field,
    String value,
  ) async {
    final taskRef = _tasksRef.doc(task.id);
    final batch = _db.batch();

    batch.update(taskRef, <String, dynamic>{
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': widget.currentUserUid,
      'updatedByName': widget.currentUserName,
      'activityLog': FieldValue.arrayUnion([
        <String, dynamic>{
          'action': 'updated',
          'message': '$field changed to $value',
          'byUid': widget.currentUserUid,
          'byName': widget.currentUserName,
          'at': Timestamp.now(),
        },
      ]),
    });

    if (task.assignedToUid.isNotEmpty) {
      final notificationRef = _notificationsRef.doc();
      final readableField = field == 'status' ? 'status' : 'priority';

      batch.set(notificationRef, <String, dynamic>{
        'companyId': widget.companyId,
        'recipientUid': task.assignedToUid,
        'recipientName': task.assignedToName,
        'recipientEmail': '',
        'type': field == 'status' ? 'task_status' : 'task',
        'title': 'Task ${readableField.toLowerCase()} updated',
        'message':
            '${task.taskNumber.isEmpty ? 'Task' : task.taskNumber}: $readableField changed to $value',
        'taskId': task.id,
        'taskNumber': task.taskNumber,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': widget.currentUserUid,
        'createdByName': widget.currentUserName,
      });
    }

    await batch.commit();
  }

  Future<void> _softDeleteTask(_TaskRecord task) async {
    await _tasksRef.doc(task.id).update(<String, dynamic>{
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedByUid': widget.currentUserUid,
      'deletedByName': widget.currentUserName,
    });
  }

  Widget _chip({required String text, required Color color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
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

  Widget _buildTaskToolbar() {
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
                hintText: 'Task number, title, assignee...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
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
            width: 170,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _statusFilter,
              items: ['All', ...taskStatuses]
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _statusFilter = value);
              },
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _priorityFilter,
              items: ['All', ...taskPriorities]
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _priorityFilter = value);
              },
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort tasks',
            onSelected: (field) {
              setState(() {
                if (_sortField == field) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortField = field;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'dueDate', child: Text('Due Date')),
              PopupMenuItem(value: 'startDate', child: Text('Start Date')),
              PopupMenuItem(value: 'priority', child: Text('Priority')),
              PopupMenuItem(value: 'status', child: Text('Status')),
              PopupMenuItem(
                value: 'assignedToName',
                child: Text('Assigned To'),
              ),
              PopupMenuItem(value: 'createdAt', child: Text('Created Date')),
            ],
            child: OutlinedButton.icon(
              onPressed: null,
              icon: Icon(
                _sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 17,
              ),
              label: const Text('Sort'),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openCreateTaskDialog,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Create Task'),
          ),
        ],
      ),
    );
  }

  Widget _miniMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(
          text.trim().isEmpty ? '-' : text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _taskCard(_TaskRecord task) {
    final dueDate = _toDate(task.dueDate);
    final overdue =
        dueDate != null &&
        task.status != 'Completed' &&
        DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );

    final estHours = task.estimatedHours == null
        ? '-'
        : task.estimatedHours!.toStringAsFixed(
            task.estimatedHours! % 1 == 0 ? 0 : 1,
          );

    final initial = task.title.trim().isEmpty
        ? 'T'
        : task.title.trim().characters.first.toUpperCase();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: overdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title.isEmpty ? 'Untitled Task' : task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.taskNumber.isEmpty
                            ? (task.description.isEmpty
                                  ? '-'
                                  : task.description)
                            : '${task.taskNumber} • ${task.description.isEmpty ? 'No description' : task.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Task actions',
                  icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                  onSelected: (value) async {
                    if (value.startsWith('status:')) {
                      await _updateTaskField(
                        task,
                        'status',
                        value.substring('status:'.length),
                      );
                    } else if (value.startsWith('priority:')) {
                      await _updateTaskField(
                        task,
                        'priority',
                        value.substring('priority:'.length),
                      );
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Task?'),
                          content: Text(
                            'This will remove ${task.taskNumber} from active task list.',
                          ),
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
                        await _softDeleteTask(task);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('Change Status'),
                    ),
                    ...taskStatuses.map(
                      (status) => PopupMenuItem(
                        value: 'status:$status',
                        child: Text(status),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('Change Priority'),
                    ),
                    ...taskPriorities.map(
                      (priority) => PopupMenuItem(
                        value: 'priority:$priority',
                        child: Text(priority),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Delete Task'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(text: task.status, color: _statusColor(task.status)),
                _chip(
                  text: task.priority,
                  color: _priorityColor(task.priority),
                  icon: Icons.flag_outlined,
                ),
                if (overdue)
                  _chip(
                    text: 'Overdue',
                    color: const Color(0xFFDC2626),
                    icon: Icons.warning_amber_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _miniMeta(Icons.person_outline, task.assignedToName),
                _miniMeta(
                  Icons.calendar_today_outlined,
                  'Start: ${_formatDate(task.startDate)}',
                ),
                _miniMeta(
                  Icons.event_busy_outlined,
                  'Due: ${_formatDate(task.dueDate)}',
                ),
                _miniMeta(Icons.timer_outlined, 'Hrs: $estHours'),
                _miniMeta(
                  Icons.account_circle_outlined,
                  'By: ${task.createdByName}',
                ),
                _miniMeta(
                  Icons.add_circle_outline,
                  'Created: ${task.createdAt == null ? '-' : DateFormat('dd MMM yyyy').format(task.createdAt!)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<_TaskRecord> tasks) {
    final pending = tasks.where((t) => t.status == 'Pending').length;
    final progress = tasks.where((t) => t.status == 'In Progress').length;
    final completed = tasks.where((t) => t.status == 'Completed').length;
    final critical = tasks.where((t) => t.priority == 'Critical').length;

    Widget pill(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
    }

    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          pill('Total: ${tasks.length}'),
          pill('Pending: $pending'),
          pill('In Progress: $progress'),
          pill('Completed: $completed'),
          pill('Critical: $critical'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTaskDialog,
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _taskStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Task loading error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = _filterTasks(snapshot.data!.docs);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummary(tasks),
                      const SizedBox(height: 18),
                      _buildTaskToolbar(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (tasks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No tasks found. Create your first task.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
                  sliver: SliverList.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) => _taskCard(tasks[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskRecord {
  final String id;
  final String taskNumber;
  final String title;
  final String description;
  final String status;
  final String priority;
  final dynamic startDate;
  final dynamic dueDate;
  final double? estimatedHours;
  final String comments;
  final List<String> attachments;
  final String assignedToUid;
  final String assignedToName;
  final String createdByName;
  final DateTime? createdAt;
  final bool isDeleted;

  _TaskRecord({
    required this.id,
    required this.taskNumber,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.startDate,
    required this.dueDate,
    required this.estimatedHours,
    required this.comments,
    required this.attachments,
    required this.assignedToUid,
    required this.assignedToName,
    required this.createdByName,
    required this.createdAt,
    required this.isDeleted,
  });

  factory _TaskRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is DateTime) {
      created = rawCreated;
    }

    String str(dynamic value) => (value ?? '').toString().trim();

    double? numberValue(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    List<String> stringList(dynamic value) {
      if (value is Iterable) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      final text = str(value);
      if (text.isEmpty) return <String>[];
      return text
          .split(RegExp(r'[\n,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return _TaskRecord(
      id: doc.id,
      taskNumber: str(data['taskNumber']),
      title: str(data['title']).isEmpty ? 'Untitled Task' : str(data['title']),
      description: str(data['description']),
      status: str(data['status']).isEmpty ? 'Pending' : str(data['status']),
      priority: str(data['priority']).isEmpty
          ? 'Medium'
          : str(data['priority']),
      startDate: data['startDate'],
      dueDate: data['dueDate'],
      estimatedHours: numberValue(data['estimatedHours']),
      comments: str(data['comments']).isEmpty
          ? str(data['notes'])
          : str(data['comments']),
      attachments: stringList(data['attachments']),
      assignedToUid: str(data['assignedToUid']),
      assignedToName: str(data['assignedToName']),
      createdByName: str(data['createdByName']),
      createdAt: created,
      isDeleted: data['isDeleted'] == true,
    );
  }
}

class _UserOption {
  final String uid;
  final String name;
  final String email;

  _UserOption({required this.uid, required this.name, required this.email});
}
