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

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _db.collection('companies').doc(widget.companyId).collection('tasks');

  CollectionReference<Map<String, dynamic>> get _countersRef =>
      _db.collection('companies').doc(widget.companyId).collection('counters');

  CollectionReference<Map<String, dynamic>> get _inquiriesRef =>
      _db.collection('companies').doc(widget.companyId).collection('inquiries');

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

  Future<List<_InquiryOption>> _loadInquiries() async {
    final snap = await _inquiriesRef.limit(200).get();
    final list = snap.docs
        .where((doc) {
          final data = doc.data();
          return data['isDeleted'] != true && data['isActive'] != false;
        })
        .map((doc) {
          final data = doc.data();
          return _InquiryOption(
            id: doc.id,
            number: _safeString(data['inquiryNumber']),
            subject: _safeString(data['subject']),
            customerName: _safeString(data['customerName']),
          );
        })
        .toList();

    list.sort((a, b) => b.number.compareTo(a.number));
    return list;
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
    final records = docs
        .map((doc) => _TaskRecord.fromDoc(doc))
        .where((task) => task.isDeleted != true)
        .where((task) {
          if (_statusFilter != 'All' && task.status != _statusFilter)
            return false;
          if (_priorityFilter != 'All' && task.priority != _priorityFilter)
            return false;
          return true;
        })
        .toList();

    records.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
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
    final dueDateCtrl = TextEditingController();

    String selectedStatus = 'Pending';
    String selectedPriority = 'Medium';
    DateTime? selectedDueDate;

    _InquiryOption? selectedInquiry;
    _UserOption? selectedUser;

    final inquiriesFuture = _loadInquiries();
    final usersFuture = _loadUsers();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([inquiriesFuture, usersFuture]),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const AlertDialog(
                content: SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final inquiries =
                (snap.data?[0] as List<_InquiryOption>? ?? <_InquiryOption>[]);
            final users =
                (snap.data?[1] as List<_UserOption>? ?? <_UserOption>[]);

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
                          DropdownButtonFormField<_InquiryOption?>(
                            value: selectedInquiry,
                            items: [
                              const DropdownMenuItem<_InquiryOption?>(
                                value: null,
                                child: Text('No inquiry linked'),
                              ),
                              ...inquiries.map(
                                (inq) => DropdownMenuItem<_InquiryOption?>(
                                  value: inq,
                                  child: Text(
                                    '${inq.number.isEmpty ? 'Inquiry' : inq.number}  ${inq.subject.isEmpty ? inq.customerName : inq.subject}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setDialogState(() => selectedInquiry = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Linked Inquiry',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedStatus,
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
                                  value: selectedPriority,
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
                                  value: selectedUser,
                                  items: users
                                      .map(
                                        (user) => DropdownMenuItem(
                                          value: user,
                                          child: Text(
                                            user.name,
                                            overflow: TextOverflow.ellipsis,
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
                              labelText: 'Description / Notes',
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

                        try {
                          await _createTask(
                            title: title,
                            description: descriptionCtrl.text.trim(),
                            status: selectedStatus,
                            priority: selectedPriority,
                            dueDate: selectedDueDate,
                            inquiry: selectedInquiry,
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
    dueDateCtrl.dispose();
  }

  Future<void> _createTask({
    required String title,
    required String description,
    required String status,
    required String priority,
    required DateTime? dueDate,
    required _InquiryOption? inquiry,
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
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
        'inquiryId': inquiry?.id ?? '',
        'inquiryNumber': inquiry?.number ?? '',
        'inquirySubject': inquiry?.subject ?? '',
        'customerName': inquiry?.customerName ?? '',
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
        'message': inquiry?.number == null || inquiry!.number.isEmpty
            ? title
            : '$title • Linked Inquiry: ${inquiry.number}',
        'taskId': docRef.id,
        'taskNumber': taskNumber,
        'inquiryId': inquiry?.id ?? '',
        'inquiryNumber': inquiry?.number ?? '',
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
        'inquiryId': task.inquiryId,
        'inquiryNumber': task.inquiryNumber,
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

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
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
          width: 190,
          child: DropdownButtonFormField<String>(
            value: _priorityFilter,
            items: ['All', ...taskPriorities]
                .map(
                  (priority) =>
                      DropdownMenuItem(value: priority, child: Text(priority)),
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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;

            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      text: task.taskNumber.isEmpty ? 'TASK' : task.taskNumber,
                      color: const Color(0xFF0F172A),
                      icon: Icons.confirmation_number_outlined,
                    ),
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
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _infoLine(
                      Icons.person_outline,
                      'Assigned: ${task.assignedToName.isEmpty ? '-' : task.assignedToName}',
                    ),
                    _infoLine(
                      Icons.event_outlined,
                      'Due: ${_formatDate(task.dueDate)}',
                    ),
                    if (task.inquiryNumber.isNotEmpty)
                      _infoLine(
                        Icons.campaign_outlined,
                        'Inquiry: ${task.inquiryNumber}',
                      ),
                    if (task.customerName.isNotEmpty)
                      _infoLine(Icons.business_outlined, task.customerName),
                  ],
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Change Status',
                  onSelected: (value) =>
                      _updateTaskField(task, 'status', value),
                  itemBuilder: (context) => taskStatuses
                      .map(
                        (status) =>
                            PopupMenuItem(value: status, child: Text(status)),
                      )
                      .toList(),
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.sync_alt_outlined),
                    label: const Text('Status'),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Change Priority',
                  onSelected: (value) =>
                      _updateTaskField(task, 'priority', value),
                  itemBuilder: (context) => taskPriorities
                      .map(
                        (priority) => PopupMenuItem(
                          value: priority,
                          child: Text(priority),
                        ),
                      )
                      .toList(),
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Priority'),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Task',
                  onPressed: () async {
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
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [left, const SizedBox(height: 12), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
    final critical = tasks.where((t) => t.priority == 'Critical').length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          'Pending',
          '$pending',
          Icons.pending_actions_outlined,
          const Color(0xFF64748B),
        ),
        _summaryCard(
          'In Progress',
          '$progress',
          Icons.play_circle_outline,
          const Color(0xFF2563EB),
        ),
        _summaryCard(
          'Completed',
          '$completed',
          Icons.check_circle_outline,
          const Color(0xFF16A34A),
        ),
        _summaryCard(
          'Critical',
          '$critical',
          Icons.priority_high_outlined,
          const Color(0xFFDC2626),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTaskDialog,
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('Create Task'),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 700;
                          final titleBlock = const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tasks',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Inquiry-linked task management with real-time status and priority tracking.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          );

                          final button = ElevatedButton.icon(
                            onPressed: _openCreateTaskDialog,
                            icon: const Icon(Icons.add_task_outlined),
                            label: const Text('Create Task'),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                titleBlock,
                                const SizedBox(height: 12),
                                button,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: titleBlock),
                              button,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildSummary(tasks),
                      const SizedBox(height: 18),
                      _buildFilters(),
                    ],
                  ),
                ),
              ),
              if (tasks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No tasks found. Create your first inquiry-linked task.',
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
  final dynamic dueDate;
  final String inquiryId;
  final String inquiryNumber;
  final String inquirySubject;
  final String customerName;
  final String assignedToUid;
  final String assignedToName;
  final DateTime? createdAt;
  final bool isDeleted;

  _TaskRecord({
    required this.id,
    required this.taskNumber,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.inquiryId,
    required this.inquiryNumber,
    required this.inquirySubject,
    required this.customerName,
    required this.assignedToUid,
    required this.assignedToName,
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

    return _TaskRecord(
      id: doc.id,
      taskNumber: str(data['taskNumber']),
      title: str(data['title']).isEmpty ? 'Untitled Task' : str(data['title']),
      description: str(data['description']),
      status: str(data['status']).isEmpty ? 'Pending' : str(data['status']),
      priority: str(data['priority']).isEmpty
          ? 'Medium'
          : str(data['priority']),
      dueDate: data['dueDate'],
      inquiryId: str(data['inquiryId']),
      inquiryNumber: str(data['inquiryNumber']),
      inquirySubject: str(data['inquirySubject']),
      customerName: str(data['customerName']),
      assignedToUid: str(data['assignedToUid']),
      assignedToName: str(data['assignedToName']),
      createdAt: created,
      isDeleted: data['isDeleted'] == true,
    );
  }
}

class _InquiryOption {
  final String id;
  final String number;
  final String subject;
  final String customerName;

  _InquiryOption({
    required this.id,
    required this.number,
    required this.subject,
    required this.customerName,
  });
}

class _UserOption {
  final String uid;
  final String name;
  final String email;

  _UserOption({required this.uid, required this.name, required this.email});
}
