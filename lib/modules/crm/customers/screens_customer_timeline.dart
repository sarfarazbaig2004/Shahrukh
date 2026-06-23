import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

bool _safeBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is int) return val == 1;
  final s = val.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String _safeString(dynamic val) {
  return (val ?? '').toString().trim();
}

DateTime? _extractDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();

  final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final amPm = value.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year $hour12:$minute $amPm';
}

String _formatDateOnly(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String _timeAgo(DateTime? d) {
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  if (diff.isNegative) return 'Upcoming';
  return 'Just now';
}

Map<String, dynamic>? _extractPrimaryAddress(List<dynamic>? addresses) {
  if (addresses == null || addresses.isEmpty) return null;
  for (var a in addresses) {
    if (a is Map<String, dynamic> && _safeBool(a['isPrimary'])) {
      return a;
    }
  }
  final first = addresses.first;
  return first is Map<String, dynamic> ? first : null;
}

String _getTimelineGroup(DateTime date, bool isPinned) {
  if (isPinned) return 'PINNED';

  final now = DateTime.now();
  if (date.isAfter(now)) return 'UPCOMING';

  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);

  final diff = today.difference(target).inDays;

  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  if (diff > 1 && diff <= 7) return 'THIS WEEK';
  if (diff > 7 && date.month == now.month && date.year == now.year) return 'THIS MONTH';
  return 'OLDER';
}

// ==========================================
// CUSTOMER TIMELINE / CRM ACTIVITY ENGINE
// ==========================================

class ScreensCustomerTimeline extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String customerName;

  const ScreensCustomerTimeline({
    super.key,
    required this.customerRef,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.customerName,
  });

  @override
  State<ScreensCustomerTimeline> createState() =>
      _ScreensCustomerTimelineState();
}

class _ScreensCustomerTimelineState extends State<ScreensCustomerTimeline> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _modeFilter = '';
  String _outcomeFilter = '';
  String _dueFilter = '';
  String _activityTypeFilter = 'all';
  String _sortOrder = 'newest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _modeFilter.isNotEmpty ||
          _outcomeFilter.isNotEmpty ||
          _dueFilter.isNotEmpty ||
          (_activityTypeFilter != 'all');

  void _resetFilters() {
    setState(() {
      _modeFilter = '';
      _outcomeFilter = '';
      _dueFilter = '';
      _activityTypeFilter = 'all';
      _sortOrder = 'newest';
    });
  }

  // --- ACTIVITY TIMELINE HELPERS ---

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'quotation':
        return const Color(0xFF8B5CF6);
      case 'invoice':
        return const Color(0xFF10B981);
      case 'dispatch':
        return const Color(0xFFF59E0B);
      case 'service':
        return const Color(0xFFEF4444);
      case 'note':
        return const Color(0xFFEAB308);
      case 'whatsapp':
        return const Color(0xFF22C55E);
      case 'email':
        return const Color(0xFF0EA5E9);
      case 'payment':
        return const Color(0xFF6366F1);
      case 'meeting':
        return const Color(0xFFD946EF);
      case 'visit':
        return const Color(0xFFF97316);
      case 'document':
        return const Color(0xFF64748B);
      case 'call':
      case 'followup':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'quotation':
        return Icons.request_quote_outlined;
      case 'invoice':
        return Icons.receipt_long_outlined;
      case 'dispatch':
        return Icons.local_shipping_outlined;
      case 'service':
        return Icons.build_outlined;
      case 'note':
        return Icons.note_alt_outlined;
      case 'whatsapp':
        return Icons.chat_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'payment':
        return Icons.payments_outlined;
      case 'meeting':
        return Icons.groups_outlined;
      case 'visit':
        return Icons.directions_car_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'call':
        return Icons.phone_in_talk_outlined;
      case 'followup':
      default:
        return Icons.timeline;
    }
  }

  String _getActivityTitle(Map<String, dynamic> data, String type) {
    final mode = _safeString(data['followUpMode']);
    if (type == 'followup' || type == 'call' || type == 'visit' || type == 'meeting') {
      return mode.isEmpty ? type.toUpperCase() : mode;
    }
    if (type == 'note') return 'Internal Note';
    if (type == 'quotation') return 'Quotation Created';
    if (type == 'invoice') return 'Invoice Generated';
    if (type == 'dispatch') return 'Dispatch Scheduled';
    if (type == 'service') return 'Service Record';
    if (type == 'payment') return 'Payment Received';
    if (type == 'email') return 'Email Sent';
    if (type == 'document') return 'Document Attached';
    return type.toUpperCase();
  }

  void _openFutureModule(String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          '$moduleName is planned for the enterprise workflow upgrade. Current customer timeline records are available here.',
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    String tempMode = _modeFilter;
    String tempOutcome = _outcomeFilter;
    String tempDue = _dueFilter;
    String tempSort = _sortOrder;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Advanced CRM Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: tempSort,
                  decoration: const InputDecoration(
                    labelText: 'Sort Order',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                    DropdownMenuItem(value: 'upcoming_first', child: Text('Upcoming First')),
                    DropdownMenuItem(value: 'overdue_first', child: Text('Overdue First')),
                  ],
                  onChanged: (value) => tempSort = value ?? 'newest',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempMode.isEmpty ? null : tempMode,
                  decoration: const InputDecoration(
                    labelText: 'Activity Mode',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _activityModeOptions
                      .map((e) => DropdownMenuItem<String>(value: e.toLowerCase(), child: Text(e)))
                      .toList(),
                  onChanged: (value) => tempMode = value ?? '',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempOutcome.isEmpty ? null : tempOutcome,
                  decoration: const InputDecoration(
                    labelText: 'Outcome',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _activityOutcomeOptions
                      .map((e) => DropdownMenuItem<String>(value: e.toLowerCase(), child: Text(e)))
                      .toList(),
                  onChanged: (value) => tempOutcome = value ?? '',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempDue.isEmpty ? null : tempDue,
                  decoration: const InputDecoration(
                    labelText: 'Next Action Status',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                    DropdownMenuItem(value: 'no_next_date', child: Text('Completed / No Next Action')),
                  ],
                  onChanged: (value) => tempDue = value ?? '',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _modeFilter = '';
                            _outcomeFilter = '';
                            _dueFilter = '';
                            _sortOrder = 'newest';
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _modeFilter = tempMode;
                            _outcomeFilter = tempOutcome;
                            _dueFilter = tempDue;
                            _sortOrder = tempSort;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddActivityDialog({
    String defaultType = 'followup',
    String defaultMode = 'Phone Call'
  }) async {
    final discussionController = TextEditingController();
    final nextActionController = TextEditingController();

    String selectedType = defaultType;
    String selectedMode = defaultMode;
    String selectedOutcome = 'Completed';
    DateTime activityDateTime = DateTime.now();
    DateTime? nextActionDate;

    String? selectedContactId = '';
    String selectedContactName = '';
    String selectedContactPhone = '';
    String selectedContactEmail = '';
    String selectedContactDesignation = '';

    Future<void> pickActivityDateTime(StateSetter setModalState) async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: activityDateTime,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(activityDateTime),
      );
      if (pickedTime == null) return;
      setModalState(() {
        activityDateTime = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute,
        );
      });
    }

    Future<void> pickNextActionDate(StateSetter setModalState) async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: nextActionDate ?? DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );
      if (pickedTime == null) return;
      setModalState(() {
        nextActionDate = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute,
        );
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSubmitting = false;
        bool isDialogClosed = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Add ${defaultMode.split(' ').first} Record'),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: widget.customerRef
                            .collection('contacts')
                            .where('isActive', isEqualTo: true)
                            .snapshots(),
                        builder: (context, contactSnap) {
                          final contactDocs = contactSnap.data?.docs ?? [];
                          bool contactExists = selectedContactId == '' || contactDocs.any((doc) => doc.id == selectedContactId);
                          if (!contactExists) {
                            selectedContactId = '';
                            selectedContactName = '';
                            selectedContactPhone = '';
                            selectedContactEmail = '';
                            selectedContactDesignation = '';
                          }

                          return DropdownButtonFormField<String>(
                            value: selectedContactId,
                            decoration: const InputDecoration(
                              labelText: 'Contact Person',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No specific contact'),
                              ),
                              ...contactDocs.map((doc) {
                                final data = doc.data();
                                final name = _safeString(data['name']);
                                final designation = _safeString(data['designation']);
                                final title = [name, if (designation.isNotEmpty) designation].join(' • ');
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(title.isEmpty ? doc.id : title, overflow: TextOverflow.ellipsis),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setModalState(() {
                                selectedContactId = value;
                                if (value == null || value.isEmpty) {
                                  selectedContactName = '';
                                  selectedContactPhone = '';
                                  selectedContactEmail = '';
                                  selectedContactDesignation = '';
                                  return;
                                }
                                final selectedDoc = contactDocs.where((e) => e.id == value).firstOrNull;
                                if (selectedDoc != null) {
                                  final data = selectedDoc.data();
                                  selectedContactName = _safeString(data['name']);
                                  selectedContactPhone = _safeString(data['phone']);
                                  selectedContactEmail = _safeString(data['email']);
                                  selectedContactDesignation = _safeString(data['designation']);
                                }
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedMode,
                        decoration: const InputDecoration(
                          labelText: 'Activity Mode',
                          prefixIcon: Icon(Icons.merge_type_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _activityModeOptions
                            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedMode = value ?? defaultMode;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedOutcome,
                        decoration: const InputDecoration(
                          labelText: 'Outcome / Status',
                          prefixIcon: Icon(Icons.flag_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _activityOutcomeOptions
                            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedOutcome = value ?? 'Completed';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => pickActivityDateTime(setModalState),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Activity Date & Time',
                            prefixIcon: Icon(Icons.schedule_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_formatDateTime(activityDateTime)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: discussionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes / Discussion *',
                          prefixIcon: Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nextActionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Next Action Details (Optional)',
                          prefixIcon: Icon(Icons.playlist_add_check_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => pickNextActionDate(setModalState),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Next Action Due',
                            prefixIcon: Icon(Icons.event_repeat_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            nextActionDate == null
                                ? 'No next action planned'
                                : _formatDateTime(nextActionDate!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () {
                    isDialogClosed = true;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    final discussion = discussionController.text.trim();
                    final nextAction = nextActionController.text.trim();

                    if (discussion.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter notes/discussion details'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    setModalState(() => isSubmitting = true);

                    try {
                      final activitiesRef = widget.customerRef.collection('followUps');

                      await activitiesRef.add({
                        'activityType': selectedType,
                        'companyId': widget.companyId,
                        'customerId': widget.customerRef.id,
                        'customerName': widget.customerName,
                        'contactId': selectedContactId ?? '',
                        'contactName': selectedContactName,
                        'contactPhone': selectedContactPhone,
                        'contactEmail': selectedContactEmail,
                        'contactDesignation': selectedContactDesignation,
                        'followUpDate': Timestamp.fromDate(activityDateTime),
                        'followUpMode': selectedMode,
                        'discussion': discussion,
                        'outcome': selectedOutcome,
                        'nextAction': nextAction,
                        'nextFollowUpDate': nextActionDate != null ? Timestamp.fromDate(nextActionDate!) : null,
                        'isPinned': false,
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdByUid': widget.currentUserUid,
                        'createdByName': widget.currentUserName,
                        'updatedAt': FieldValue.serverTimestamp(),
                        'updatedByUid': widget.currentUserUid,
                        'updatedByName': widget.currentUserName,
                      });

                      final latestSnap = await activitiesRef.orderBy('followUpDate', descending: true).limit(1).get();
                      final totalSnap = await activitiesRef.get();

                      if (latestSnap.docs.isNotEmpty) {
                        final latestData = latestSnap.docs.first.data();
                        await widget.customerRef.update({
                          'lastFollowUpAt': latestData['followUpDate'],
                          'lastFollowUpByUid': latestData['createdByUid'] ?? '',
                          'lastFollowUpByName': latestData['createdByName'] ?? '',
                          'lastFollowUpMode': latestData['followUpMode'] ?? '',
                          'lastFollowUpSummary': latestData['discussion'] ?? '',
                          'lastFollowUpOutcome': latestData['outcome'] ?? '',
                          'nextFollowUpDate': latestData['nextFollowUpDate'],
                          'followUpCount': totalSnap.docs.length,
                          'updatedAt': FieldValue.serverTimestamp(),
                          'updatedBy': widget.currentUserUid,
                          'updatedByUid': widget.currentUserUid,
                          'updatedByName': widget.currentUserName,
                        });
                      }

                      if (!mounted) return;
                      isDialogClosed = true;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity logged successfully'), backgroundColor: Colors.green));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to log activity: $e'), backgroundColor: Colors.red));
                    } finally {
                      if (mounted && !isDialogClosed) {
                        setModalState(() => isSubmitting = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Activity'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _togglePinStatus(String activityId, bool currentStatus) async {
    try {
      await widget.customerRef.collection('followUps').doc(activityId).update({
        'isPinned': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': widget.currentUserUid,
        'updatedByName': widget.currentUserName,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update pin: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteActivity(String activityId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: const Text('This timeline entry will be permanently deleted and cannot be recovered.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.customerRef.collection('followUps').doc(activityId).delete();

      final latestSnap = await widget.customerRef.collection('followUps').orderBy('followUpDate', descending: true).limit(1).get();
      final totalSnap = await widget.customerRef.collection('followUps').get();

      if (latestSnap.docs.isEmpty) {
        await widget.customerRef.update({
          'lastFollowUpAt': null, 'lastFollowUpByUid': '', 'lastFollowUpByName': '',
          'lastFollowUpMode': '', 'lastFollowUpSummary': '', 'lastFollowUpOutcome': '',
          'nextFollowUpDate': null, 'followUpCount': 0, 'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': widget.currentUserUid, 'updatedByName': widget.currentUserName,
        });
      } else {
        final latestData = latestSnap.docs.first.data();
        await widget.customerRef.update({
          'lastFollowUpAt': latestData['followUpDate'], 'lastFollowUpByUid': latestData['createdByUid'] ?? '',
          'lastFollowUpByName': latestData['createdByName'] ?? '', 'lastFollowUpMode': latestData['followUpMode'] ?? '',
          'lastFollowUpSummary': latestData['discussion'] ?? '', 'lastFollowUpOutcome': latestData['outcome'] ?? '',
          'nextFollowUpDate': latestData['nextFollowUpDate'], 'followUpCount': totalSnap.docs.length,
          'updatedAt': FieldValue.serverTimestamp(), 'updatedByUid': widget.currentUserUid, 'updatedByName': widget.currentUserName,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity deleted'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red));
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFiltersAndSort(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final query = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    final filtered = docs.where((doc) {
      final data = doc.data();

      final type = _safeString(data['activityType']).toLowerCase();
      final mode = _safeString(data['followUpMode']).toLowerCase();
      final outcome = _safeString(data['outcome']).toLowerCase();
      final discussion = _safeString(data['discussion']).toLowerCase();
      final nextAction = _safeString(data['nextAction']).toLowerCase();
      final contactName = _safeString(data['contactName']).toLowerCase();
      final createdByName = _safeString(data['createdByName']).toLowerCase();

      final nextFollowUpDate = _extractDate(data['nextFollowUpDate']);
      final nextOnly = nextFollowUpDate == null ? null : DateTime(nextFollowUpDate.year, nextFollowUpDate.month, nextFollowUpDate.day);

      final matchesSearch = query.isEmpty ||
          type.contains(query) || mode.contains(query) || outcome.contains(query) ||
          discussion.contains(query) || nextAction.contains(query) || contactName.contains(query) || createdByName.contains(query);

      final derivedActivityType = type.isEmpty ? 'followup' : type;
      final matchesActivity = _activityTypeFilter == 'all' || derivedActivityType == _activityTypeFilter;

      final matchesMode = _modeFilter.isEmpty || mode == _modeFilter.trim().toLowerCase();
      final matchesOutcome = _outcomeFilter.isEmpty || outcome == _outcomeFilter.trim().toLowerCase();

      bool matchesDue = true;
      if (_dueFilter == 'overdue') {
        matchesDue = nextOnly != null && nextOnly.isBefore(todayOnly);
      } else if (_dueFilter == 'today') {
        matchesDue = nextOnly != null && nextOnly == todayOnly;
      } else if (_dueFilter == 'upcoming') {
        matchesDue = nextOnly != null && nextOnly.isAfter(todayOnly);
      } else if (_dueFilter == 'no_next_date') {
        matchesDue = nextOnly == null;
      }

      return matchesSearch && matchesActivity && matchesMode && matchesOutcome && matchesDue;
    }).toList();

    filtered.sort((aDoc, bDoc) {
      final a = aDoc.data();
      final b = bDoc.data();

      final aDate = _extractDate(a['followUpDate']) ?? _extractDate(a['createdAt']) ?? DateTime(2000);
      final bDate = _extractDate(b['followUpDate']) ?? _extractDate(b['createdAt']) ?? DateTime(2000);

      final aNext = _extractDate(a['nextFollowUpDate']) ?? DateTime(2100);
      final bNext = _extractDate(b['nextFollowUpDate']) ?? DateTime(2100);

      if (_sortOrder == 'newest') return bDate.compareTo(aDate);
      if (_sortOrder == 'oldest') return aDate.compareTo(bDate);
      if (_sortOrder == 'upcoming_first') return aNext.compareTo(bNext);
      if (_sortOrder == 'overdue_first') return aNext.compareTo(bNext);

      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  _CustomerHealth _calculateCustomerHealth(DocumentSnapshot<Map<String, dynamic>> custDoc, List<QueryDocumentSnapshot<Map<String, dynamic>>> allActivities) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    int overdueCount = 0;
    int pendingCount = 0;

    for (var doc in allActivities) {
      final next = _extractDate(doc.data()['nextFollowUpDate']);
      if (next != null) {
        final nextOnly = DateTime(next.year, next.month, next.day);
        if (nextOnly.isBefore(todayOnly)) {
          overdueCount++;
        } else {
          pendingCount++;
        }
      }
    }

    final data = custDoc.data() ?? {};
    final lastActivityDate = _extractDate(data['lastFollowUpAt']);

    if (overdueCount > 2) return _CustomerHealth(label: 'At Risk', color: const Color(0xFFEF4444), icon: Icons.warning_amber_rounded);
    if (overdueCount > 0) return _CustomerHealth(label: 'Action Required', color: const Color(0xFFF59E0B), icon: Icons.error_outline_rounded);
    if (lastActivityDate != null && now.difference(lastActivityDate).inDays > 60) {
      return _CustomerHealth(label: 'Inactive', color: const Color(0xFF64748B), icon: Icons.snooze_rounded);
    }
    if (pendingCount > 0 || (lastActivityDate != null && now.difference(lastActivityDate).inDays <= 7)) {
      return _CustomerHealth(label: 'Healthy / Active', color: const Color(0xFF10B981), icon: Icons.check_circle_outline);
    }

    return _CustomerHealth(label: 'No Recent Activity', color: const Color(0xFF94A3B8), icon: Icons.hourglass_empty_rounded);
  }

  Widget _buildCustomer360Header(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.customerRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data!.data() ?? {};
          final customerCode = _safeString(data['customerCode']);
          final addresses = data['addresses'] as List<dynamic>?;
          final primaryAddr = _extractPrimaryAddress(addresses);
          final city = primaryAddr != null ? _safeString(primaryAddr['city']) : _safeString(data['city']);
          final state = primaryAddr != null ? _safeString(primaryAddr['state']) : _safeString(data['state']);

          final locText = [city, state].where((e) => e.isNotEmpty).join(', ');
          final health = _calculateCustomerHealth(snapshot.data!, docs);

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.domain, color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (customerCode.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, bottom: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: Text(customerCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                              ),
                            ),
                          Text(
                            widget.customerName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: health.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: health.color.withOpacity(0.2))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(health.icon, size: 14, color: health.color),
                                const SizedBox(width: 4),
                                Text(health.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: health.color)),
                              ],
                            ),
                          ),
                          if (locText.isNotEmpty) _MetaText(icon: Icons.location_on_outlined, text: locText),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF64748B)),
                  tooltip: 'Customer Actions',
                  onSelected: _openFutureModule,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'Customer Profile', child: Text('View Full Profile')),
                    PopupMenuItem(value: 'Quotations', child: Text('View Quotations')),
                    PopupMenuItem(value: 'Invoices', child: Text('View Invoices')),
                    PopupMenuItem(value: 'Service History', child: Text('View Service History')),
                  ],
                ),
              ],
            ),
          );
        });
  }

  Widget _buildStickyActionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openAddActivityDialog(defaultType: 'call', defaultMode: 'Phone Call'),
              icon: const Icon(Icons.phone_in_talk_outlined, size: 16),
              label: const Text('Log Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openAddActivityDialog(defaultType: 'meeting', defaultMode: 'Meeting'),
              icon: const Icon(Icons.groups_outlined, size: 16),
              label: const Text('Meeting'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openAddActivityDialog(defaultType: 'note', defaultMode: 'Internal Note'),
              icon: const Icon(Icons.note_alt_outlined, size: 16),
              label: const Text('Add Note'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openAddActivityDialog(defaultType: 'visit', defaultMode: 'Site Visit'),
              icon: const Icon(Icons.directions_car_outlined, size: 16),
              label: const Text('Visit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openFutureModule('Create Document'),
              icon: const Icon(Icons.add_box_outlined, size: 16),
              label: const Text('More'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    final Map<String, String> filters = {
      'all': 'All Activities',
      'call': 'Calls',
      'meeting': 'Meetings',
      'note': 'Notes',
      'quotation': 'Quotations',
      'invoice': 'Invoices',
      'visit': 'Visits',
    };

    return Container(
      decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: filters.entries.map((entry) {
            final key = entry.key;
            final label = entry.value;
            final isSelected = _activityTypeFilter == key;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : const Color(0xFF475569))),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _activityTypeFilter = key);
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1))),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNextActionPanel(List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs) {
    final now = DateTime.now();
    QueryDocumentSnapshot<Map<String, dynamic>>? nextActionDoc;
    DateTime? closestDate;

    for (var doc in allDocs) {
      final data = doc.data();
      final nextDate = _extractDate(data['nextFollowUpDate']);
      if (nextDate != null && nextDate.isAfter(now)) {
        if (closestDate == null || nextDate.isBefore(closestDate)) {
          closestDate = nextDate;
          nextActionDoc = doc;
        }
      }
    }

    if (nextActionDoc == null) return const SizedBox.shrink();

    final data = nextActionDoc.data();
    final actionDesc = _safeString(data['nextAction']).isNotEmpty ? _safeString(data['nextAction']) : 'Scheduled Follow-up';
    final assigned = _safeString(data['createdByName']);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEXT SCHEDULED ACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(actionDesc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 12, color: Color(0xFFCBD5E1)),
                        const SizedBox(width: 4),
                        Text(_formatDateTime(closestDate!), style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                      ],
                    ),
                    if (assigned.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 12, color: Color(0xFFCBD5E1)),
                          const SizedBox(width: 4),
                          Text(assigned, style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                        ],
                      ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineItem> _buildTimelineData(List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs) {
    if (filteredDocs.isEmpty) return [];

    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};

    for (var doc in filteredDocs) {
      final data = doc.data();
      final date = _extractDate(data['followUpDate']) ?? _extractDate(data['createdAt']) ?? DateTime.now();
      final isPinned = _safeBool(data['isPinned']);
      final groupKey = _getTimelineGroup(date, isPinned);
      grouped.putIfAbsent(groupKey, () => []).add(doc);
    }

    final List<String> groupOrder = ['PINNED', 'UPCOMING', 'TODAY', 'YESTERDAY', 'THIS WEEK', 'THIS MONTH', 'OLDER'];

    List<_TimelineItem> timelineItems = [];

    for (String key in groupOrder) {
      if (grouped.containsKey(key)) {
        timelineItems.add(_TimelineHeader(key));

        final docs = grouped[key]!;

        if (key == 'UPCOMING') {
          docs.sort((a, b) {
            final da = _extractDate(a.data()['followUpDate']) ?? DateTime(2100);
            final db = _extractDate(b.data()['followUpDate']) ?? DateTime(2100);
            return da.compareTo(db);
          });
        } else {
          docs.sort((a, b) {
            final da = _extractDate(a.data()['followUpDate']) ?? DateTime(2000);
            final db = _extractDate(b.data()['followUpDate']) ?? DateTime(2000);
            return db.compareTo(da);
          });
        }

        for (int i = 0; i < docs.length; i++) {
          timelineItems.add(_TimelineActivity(
            doc: docs[i],
            isFirstInGroup: i == 0,
            isLastInGroup: i == docs.length - 1,
            isGlobalLast: key == groupOrder.lastWhere((k) => grouped.containsKey(k)) && i == docs.length - 1,
          ));
        }
      }
    }
    return timelineItems;
  }

  @override
  Widget build(BuildContext context) {
    final activitiesRef = widget.customerRef.collection('followUps');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('CRM Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _openFutureModule('Customer Profile'),
            icon: const Icon(Icons.contact_page_outlined, size: 20),
            tooltip: 'View Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: activitiesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load timeline:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data?.docs ?? [];
              final filteredDocs = _applyFiltersAndSort(allDocs);
              final timelineItems = _buildTimelineData(filteredDocs);

              return Column(
                children: [
                  _buildCustomer360Header(allDocs),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildStickyActionBar(),
                  _buildQuickFilters(),

                  // Filters & Search Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _searchQuery = value),
                            decoration: InputDecoration(
                              hintText: 'Search activities, notes...',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 16),
                              suffixIcon: _searchQuery.trim().isEmpty ? null : IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              filled: true, fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _openFilterSheet,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF475569)),
                                  if (_hasActiveFilters)
                                    Positioned(
                                        right: -4, top: -4,
                                        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle))
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: Text('Filters applied', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600))),
                          TextButton(
                            onPressed: _resetFilters,
                            style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),

                  if (_activityTypeFilter == 'all' && _searchQuery.isEmpty) _buildNextActionPanel(allDocs),

                  // Timeline List
                  Expanded(
                    child: timelineItems.isEmpty
                        ? _EmptyTimelineState(
                      hasSearch: _searchQuery.trim().isNotEmpty || _hasActiveFilters,
                      onReset: () {
                        _searchController.clear();
                        _resetFilters();
                      },
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: timelineItems.length,
                      itemBuilder: (context, index) {
                        final item = timelineItems[index];

                        if (item is _TimelineHeader) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 48, top: 16, bottom: 12),
                            child: Text(
                              item.title,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xFF94A3B8)),
                            ),
                          );
                        } else if (item is _TimelineActivity) {
                          return _buildTimelineNode(item);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineNode(_TimelineActivity item) {
    final doc = item.doc;
    final data = doc.data();

    final activityType = _safeString(data['activityType']).isEmpty ? 'followup' : _safeString(data['activityType']);
    final iconData = _getActivityIcon(activityType);
    final color = _getActivityColor(activityType);
    final isPinned = _safeBool(data['isPinned']);

    // Stack and border-based Timeline Node (NO INTRINSIC HEIGHT - ZERO OVERFLOW)
    return Container(
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.only(left: 24, bottom: 16),
      decoration: BoxDecoration(
        border: item.isGlobalLast
            ? null
            : const Border(left: BorderSide(width: 2, color: Color(0xFFE2E8F0))),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -41, // 24 padding + 1px border shift + 16 (half icon width)
            top: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 4)]
              ),
              child: Icon(iconData, size: 14, color: color),
            ),
          ),
          _ActivityCard(
            doc: doc,
            data: data,
            activityType: activityType,
            color: color,
            isPinned: isPinned,
            onTogglePin: () => _togglePinStatus(doc.id, isPinned),
            onDelete: () => _deleteActivity(doc.id),
            parentState: this,
          ),
        ],
      ),
    );
  }

  _DueMeta? _buildDueMeta({required DateTime? nextFollowUpDate}) {
    if (nextFollowUpDate == null) return null;

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final nextOnly = DateTime(nextFollowUpDate.year, nextFollowUpDate.month, nextFollowUpDate.day);

    if (nextOnly.isBefore(todayOnly)) {
      return _DueMeta(label: 'Overdue Action', background: const Color(0xFFFEF2F2), foreground: const Color(0xFFDC2626));
    }
    if (nextOnly == todayOnly) {
      return _DueMeta(label: 'Due Today', background: const Color(0xFFFFFBEB), foreground: const Color(0xFFD97706));
    }
    return _DueMeta(label: 'Upcoming', background: const Color(0xFFF0FDF4), foreground: const Color(0xFF059669));
  }
}

// --- DOMAIN MODELS FOR TIMELINE RENDERING ---
abstract class _TimelineItem {}

class _TimelineHeader implements _TimelineItem {
  final String title;
  _TimelineHeader(this.title);
}

class _TimelineActivity implements _TimelineItem {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isGlobalLast;

  _TimelineActivity({
    required this.doc,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.isGlobalLast,
  });
}

class _CustomerHealth {
  final String label;
  final Color color;
  final IconData icon;
  _CustomerHealth({required this.label, required this.color, required this.icon});
}

// --- ACTIVITY CARD WIDGET (COLLAPSIBLE) ---
class _ActivityCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic> data;
  final String activityType;
  final Color color;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final _ScreensCustomerTimelineState parentState;

  const _ActivityCard({
    required this.doc,
    required this.data,
    required this.activityType,
    required this.color,
    required this.isPinned,
    required this.onTogglePin,
    required this.onDelete,
    required this.parentState,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.parentState._getActivityTitle(widget.data, widget.activityType);
    final followUpDate = _extractDate(widget.data['followUpDate']) ?? _extractDate(widget.data['createdAt']);
    final nextFollowUpDate = _extractDate(widget.data['nextFollowUpDate']);
    final createdByName = _safeString(widget.data['createdByName']);

    final discussion = _safeString(widget.data['discussion']);
    final outcome = _safeString(widget.data['outcome']);
    final nextAction = _safeString(widget.data['nextAction']);

    final contactName = _safeString(widget.data['contactName']);

    final dueMeta = widget.parentState._buildDueMeta(nextFollowUpDate: nextFollowUpDate);

    final bool isLongNote = discussion.length > 120;
    final String displayNote = (!_isExpanded && isLongNote) ? '${discussion.substring(0, 120)}...' : discussion;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isPinned ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.isPinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFFD97706))),
                          Expanded(
                            child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(_timeAgo(followUpDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  splashRadius: 24,
                  onSelected: (value) {
                    if (value == 'pin') widget.onTogglePin();
                    if (value == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'pin', child: Text(widget.isPinned ? 'Unpin Activity' : 'Pin to Top', style: const TextStyle(fontSize: 13))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Activity', style: TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ],
            ),
          ),

          if (outcome.isNotEmpty || dueMeta != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (outcome.isNotEmpty && outcome != 'Completed')
                    _MiniChip(label: outcome, background: const Color(0xFFF1F5F9), foreground: const Color(0xFF475569)),
                  if (dueMeta != null)
                    _MiniChip(label: dueMeta.label, background: dueMeta.background, foreground: dueMeta.foreground),
                ],
              ),
            ),

          if (discussion.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayNote, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5)),
                  if (isLongNote)
                    InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Text(_isExpanded ? 'Show Less' : 'Read More', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ),
                    )
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (widget.activityType == 'document' || widget.activityType == 'quotation' || widget.activityType == 'invoice')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('${title}_Document.pdf', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nextAction.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NEXT: $nextAction', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            if (nextFollowUpDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('Due: ${_formatDateOnly(nextFollowUpDate)}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              )
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    if (createdByName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 8, backgroundColor: const Color(0xFFE2E8F0), child: Text(createdByName[0].toUpperCase(), style: const TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.bold))),
                          const SizedBox(width: 6),
                          Text(createdByName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    if (contactName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Flexible(child: Text(contactName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                        ],
                      )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- REUSABLE UI COMPONENTS ---

class _DueMeta {
  final String label;
  final Color background;
  final Color foreground;
  _DueMeta({required this.label, required this.background, required this.foreground});
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _MiniChip({required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background, borderRadius: BorderRadius.circular(4),
        border: Border.all(color: foreground.withOpacity(0.1)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9.5, color: foreground, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    );
  }
}

class _EmptyTimelineState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyTimelineState({required this.hasSearch, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0), width: 1)),
              child: Icon(hasSearch ? Icons.search_off : Icons.timeline_outlined, size: 40, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),
            Text(
              hasSearch ? 'No matching activities found' : 'No Activity History Yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try changing your search terms or adjusting the filters above.'
                  : 'Start engaging with the customer. Log calls, meetings, notes, and emails to build a comprehensive history.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (hasSearch)
              OutlinedButton.icon(
                onPressed: onReset, icon: const Icon(Icons.refresh, size: 16), label: const Text('Reset Filters'),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
          ],
        ),
      ),
    );
  }
}

const List<String> _activityModeOptions = [
  'Phone Call',
  'WhatsApp',
  'Email',
  'Meeting',
  'Internal Note',
  'Site Visit',
  'Video Call',
  'Demo',
  'Service Visit',
  'System Auto-log',
  'Other',
];

const List<String> _activityOutcomeOptions = [
  'Completed',
  'Interested',
  'Very Interested',
  'Quotation Sent',
  'Demo Required',
  'Negotiation Ongoing',
  'No Response',
  'Call Back Later',
  'Not Interested',
  'Issue Resolved',
  'Closed Won',
  'Closed Lost',
];