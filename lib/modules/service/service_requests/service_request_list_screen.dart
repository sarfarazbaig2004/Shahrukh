import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_service_request_screen.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
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

String _timeAgo(DateTime? d) {
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String _formatAnyTimestamp(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year $hour:$minute $amPm';
}

// ==========================================
// WORKFLOW TRACKING HELPERS
// ==========================================

String _getWorkflowStage(Map<String, dynamic> data) {
  final stage = _safeString(data['currentWorkflowStage']);
  if (stage.isNotEmpty) return stage;

  // Safe Fallback for Legacy Records without migrating Firestore
  final status = _safeString(data['status']);
  switch (status) {
    case 'New': return 'REQUEST_CREATED';
    case 'Assigned': return 'ASSIGNED';
    case 'In Progress': return 'VISIT_IN_PROGRESS';
    case 'Resolved':
    case 'Completed': return 'WORK_COMPLETED';
    case 'Closed': return 'CLOSED';
    default: return 'REQUEST_CREATED';
  }
}

String _getWorkflowDisplayName(String stage) {
  if (stage.isEmpty) return 'Unknown';
  return stage.split('_').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

int _getWorkflowPhaseIndex(String stage) {
  if (stage == 'REQUEST_CREATED') return 0;
  if (stage == 'ASSIGNED') return 1;
  if (stage == 'WORK_COMPLETED' || stage == 'CUSTOMER_SIGNOFF') return 3;
  if (stage == 'CLOSED') return 4;
  return 2; // All execution phases: VISITS, INSTALLATIONS, WAITING, TRAINING
}

String _getWorkflowPhase(String stage) {
  const phases = ['Created', 'Assigned', 'Execution', 'Completion', 'Closed'];
  return phases[_getWorkflowPhaseIndex(stage)];
}

Color _getWorkflowColor(String stage) {
  if (stage.contains('SPARE')) return Colors.orange.shade600;
  if (stage.contains('WAITING') || stage.contains('APPROVAL')) return Colors.amber.shade700;
  if (stage.contains('COMPLETED') || stage.contains('SIGNOFF')) return Colors.green.shade700;
  if (stage == 'CLOSED') return Colors.grey.shade700;
  if (stage == 'ASSIGNED') return Colors.indigo.shade600;
  if (stage == 'REQUEST_CREATED') return Colors.blue.shade700;
  return Colors.teal.shade600; // Execution / Scheduled / In Progress
}

bool _isWorkflowDelayed(Map<String, dynamic> data, {int thresholdDays = 5}) {
  final stage = _getWorkflowStage(data);
  if (stage == 'CLOSED' || stage == 'WORK_COMPLETED' || stage == 'CUSTOMER_SIGNOFF') return false;

  final updated = _extractDate(data['workflowUpdatedAt'] ?? data['updatedAt'] ?? data['createdAt']);
  if (updated == null) return false;

  return DateTime.now().difference(updated).inDays >= thresholdDays;
}

// ==========================================
// MAIN SCREEN
// ==========================================

class ServiceRequestListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const ServiceRequestListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<ServiceRequestListScreen> createState() => _ServiceRequestListScreenState();
}

class _ServiceRequestListScreenState extends State<ServiceRequestListScreen> {
  // --- CORE UI STATE ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // --- FILTERS STATE ---
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedPriority = 'All';
  String _selectedNature = 'All';
  String _selectedAssignee = 'All';
  String _selectedCreator = 'All';

  // Standardized ERP Status Workflow (Preserving legacy "Completed" via mapping)
  final List<String> _statuses = ['All', 'New', 'Assigned', 'In Progress', 'Resolved', 'Closed'];
  final List<String> _priorities = ['All', 'Low', 'Medium', 'High', 'Critical'];

  // --- PAGINATION STATE ---
  int _currentPage = 1;
  final int _recordsPerPage = 20;

  // --- PREFERENCES & ENTERPRISE STATE ---
  bool _isTableView = false;
  final Set<String> _selectedRequestIds = {};

  // --- PERMISSION STATE ---
  bool _isFetchingRole = true;
  bool _isAdmin = false;
  String _currentUserRole = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchUserRole();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- ROLE FETCHING ---
  Future<void> _fetchUserRole() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .doc(widget.currentUserUid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _currentUserRole = (doc.data()?['role'] ?? '').toString().toLowerCase();
          _isAdmin = ['admin', 'superadmin', 'manager', 'director', 'md'].contains(_currentUserRole);
          _isFetchingRole = false;
        });
      } else if (mounted) {
        setState(() => _isFetchingRole = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingRole = false);
    }
  }

  // --- PREFERENCES PERSISTENCE ---
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isTableView = prefs.getBool('erp_service_view_preference') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isTableView = !_isTableView);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('erp_service_view_preference', _isTableView);
    } catch (_) {}
  }

  // --- DATA FETCHING & FILTERING ---
  Stream<QuerySnapshot<Map<String, dynamic>>> _getRequestsStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_requests')
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {

    final filtered = docs.where((doc) {
      final data = doc.data();

      if (data['isDeleted'] == true) return false;

      // 🛡️ ROLE-BASED VISIBILITY (Customer Module Architecture)
      if (!_isAdmin) {
        final assignedUid = _safeString(data['assignedToUid']);
        final createdBy = _safeString(data['createdBy']);
        final salesPersonId = _safeString(data['salesPersonId']);

        if (assignedUid != widget.currentUserUid &&
            createdBy != widget.currentUserUid &&
            salesPersonId != widget.currentUserUid) {
          return false;
        }
      }

      final status = _safeString(data['status']);
      final priority = _safeString(data['priority']);
      final nature = _safeString(data['serviceItemNature'] ?? data['machineNature']);
      final assigneeName = _safeString(data['assignedToName']);
      final creatorName = _safeString(data['createdByName']);
      final assigneeUid = _safeString(data['assignedToUid']);

      // Exact Filters
      if (_selectedStatus != 'All') {
        if (_selectedStatus == 'Resolved' && status == 'Completed') {
          // Allow legacy 'Completed' to map into 'Resolved'
        } else if (status != _selectedStatus) {
          return false;
        }
      }

      if (_selectedPriority != 'All' && priority != _selectedPriority) return false;
      if (_selectedNature != 'All' && nature != _selectedNature) return false;
      if (_selectedCreator != 'All' && creatorName != _selectedCreator) return false;

      if (_selectedAssignee != 'All') {
        if (_selectedAssignee == 'Unassigned' && assigneeUid.isNotEmpty) return false;
        if (_selectedAssignee != 'Unassigned' && assigneeName != _selectedAssignee) return false;
      }

      // Dynamic Deep Search (Supports backend searchKeywords + local fields)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();

        final searchKeywords = data['searchKeywords'] as List<dynamic>? ?? [];
        final keywordMatch = searchKeywords.any((k) => _safeString(k).toLowerCase().contains(q));

        final reqNo = _safeString(data['requestNumber']).toLowerCase();
        final custName = _safeString(data['customerName']).toLowerCase();
        final custCode = _safeString(data['customerCode']).toLowerCase();
        final contact = _safeString(data['contactPerson']).toLowerCase();
        final mobile = _safeString(data['mobileNumber']).toLowerCase();
        final itemName = _safeString(data['serviceItemName'] ?? data['machineModel']).toLowerCase();
        final serial = _safeString(data['serialNumber'] ?? data['machineSerialNumber']).toLowerCase();
        final assignee = assigneeName.toLowerCase();

        final matchesSearch = keywordMatch || reqNo.contains(q) || custName.contains(q) || custCode.contains(q) ||
            contact.contains(q) || mobile.contains(q) || itemName.contains(q) ||
            serial.contains(q) || assignee.contains(q);

        if (!matchesSearch) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _extractDate(a.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _extractDate(b.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Map<String, int> _calculateStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = 0, newReq = 0, assigned = 0, inProg = 0, resolved = 0, closed = 0, unassigned = 0;

    for (var doc in docs) {
      final data = doc.data();
      if (data['isDeleted'] == true) continue;

      total++;
      final status = _safeString(data['status']);
      final assignedUid = _safeString(data['assignedToUid']);

      if (status == 'New') newReq++;
      if (status == 'Assigned') assigned++;
      if (status == 'In Progress') inProg++;
      if (status == 'Resolved' || status == 'Completed') resolved++;
      if (status == 'Closed') closed++;
      if (assignedUid.isEmpty) unassigned++;
    }

    return {
      'Total': total,
      'New': newReq,
      'Assigned': assigned,
      'In Progress': inProg,
      'Resolved': resolved,
      'Closed': closed,
      'Unassigned': unassigned,
    };
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1; // Reset pagination
        });
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedRequestIds.contains(id)) {
        _selectedRequestIds.remove(id);
      } else {
        _selectedRequestIds.add(id);
      }
    });
  }

  bool get _hasActiveFilters {
    return _selectedStatus != 'All' ||
        _selectedPriority != 'All' ||
        _selectedNature != 'All' ||
        _selectedAssignee != 'All' ||
        _selectedCreator != 'All';
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'All';
      _selectedPriority = 'All';
      _selectedNature = 'All';
      _selectedAssignee = 'All';
      _selectedCreator = 'All';
      _currentPage = 1;
    });
  }

  // --- ACTIONS ---

  // Fetches latest Firestore document safely before launching edit screen to prevent stale data mutations
  Future<void> _editRequest(String docId) async {
    try {
      final freshDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('service_requests')
          .doc(docId)
          .get();

      if (!freshDoc.exists || freshDoc.data() == null || freshDoc.data()!['isDeleted'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Service request no longer exists or was deleted.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
          companyId: widget.companyId,
          currentUserUid: widget.currentUserUid,
          currentUserName: widget.currentUserName,
          existingDocId: docId,
          existingData: freshDoc.data()!,
        )));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load latest data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteRequest(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request?'),
        content: const Text('Are you sure you want to delete this service request? This will safely hide it from all views.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('service_requests')
            .doc(docId)
            .update({
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedByUid': widget.currentUserUid,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showDetailsDialog(Map<String, dynamic> data) {
    final requiredPartsRaw = data['requiredParts'] as List<dynamic>? ?? [];
    final workflowStage = _getWorkflowStage(data);
    final visitCount = _safeInt(data['visitCount']);
    final isDelayed = _isWorkflowDelayed(data);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['requestNumber'] ?? 'Details', style: TextStyle(fontSize: 14, color: Colors.blue.shade700, fontWeight: FontWeight.w800)),
                Text(_safeString(data['customerName']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            Row(
              children: [
                if (isDelayed) const Padding(padding: EdgeInsets.only(right: 8.0), child: _DelayBadge()),
                _buildAttentionChip(workflowStage),
              ],
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 750,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailSection('Customer Information', {
                        'Contact Person': data['contactPerson'],
                        'Mobile Number': data['mobileNumber'],
                        'Email': data['email'],
                        'Address': data['address'],
                        'City/State': '${_safeString(data['city'])} ${_safeString(data['state'])}'.trim(),
                      }),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailSection('Service Item Information', {
                        'Product Nature': data['serviceItemNature'] ?? data['machineNature'],
                        'Product Name': data['serviceItemName'] ?? data['machineModel'],
                        'Item Code': data['serviceItemCode'] ?? data['machineCode'],
                        'Brand/Make': data['brand'] ?? data['machineBrand'],
                        'Serial Number': data['serialNumber'] ?? data['machineSerialNumber'],
                        'Category': data['serviceCategoryName'] ?? data['machineCategory'],
                      }),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailSection('Service Operations', {
                        'Current Stage': _getWorkflowDisplayName(workflowStage),
                        'Workflow Phase': _getWorkflowPhase(workflowStage),
                        'Stage Updated': _formatAnyTimestamp(data['workflowUpdatedAt'] ?? data['updatedAt']),
                        'Pending Reason': data['pendingReason'],
                        'Next Action': data['nextAction'],
                        'Total Visits': visitCount.toString(),
                        'Last Visit Date': _formatAnyTimestamp(data['lastVisitDate']),
                        'Last Engineer': _safeString(data['lastVisitEngineer']),
                        'Last Remarks': _safeString(data['lastVisitRemarks']),
                        'Last Activity': _safeString(data['lastActivity']),
                        'Activity Time': _formatAnyTimestamp(data['lastActivityAt']),
                      }),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailSection('Complaint & Assignment', {
                        'Complaint Category': data['complaintCategory'],
                        'Priority': data['priority'],
                        'Under Warranty': (data['isWarranty'] ?? false) ? 'Yes' : 'No',
                        'Description': data['complaintDescription'],
                        'Assigned To': _safeString(data['assignedToName']).isEmpty ? 'Unassigned' : data['assignedToName'],
                        'Created By': data['createdByName'],
                        'Created At': _formatAnyTimestamp(data['createdAt']),
                      }),
                    ),
                  ],
                ),

                if (requiredPartsRaw.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Text('Required Parts & Accessories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(8), child: Text('Part Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Nature', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          ],
                        ),
                        ...requiredPartsRaw.where((p) => p is Map).map((p) {
                          final partMap = p as Map<dynamic, dynamic>;
                          return TableRow(
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(partMap['partName']), style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(partMap['partNature']), style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(partMap['quantity']), style: const TextStyle(fontSize: 12))),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, Map<String, dynamic> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        ...fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map(
                (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 140, child: Text('${e.key}:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500))),
                  Expanded(child: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                ],
              ),
            )
        ),
      ],
    );
  }

  // --- FILTERS SHEET ---
  Future<void> _openFilterSheet(List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs) async {
    final naturesSet = <String>{'All'};
    final assigneesSet = <String>{'All', 'Unassigned'};
    final creatorsSet = <String>{'All'};

    for (var doc in allDocs) {
      final d = doc.data();
      if (d['isDeleted'] == true) continue;

      final nature = _safeString(d['serviceItemNature'] ?? d['machineNature']);
      if (nature.isNotEmpty) naturesSet.add(nature);

      final assignee = _safeString(d['assignedToName']);
      if (assignee.isNotEmpty) assigneesSet.add(assignee);

      final creator = _safeString(d['createdByName']);
      if (creator.isNotEmpty) creatorsSet.add(creator);
    }

    final naturesList = naturesSet.toList()..sort();
    final assigneesList = assigneesSet.toList()..sort();
    final creatorsList = creatorsSet.toList()..sort();

    String tempStatus = _selectedStatus;
    String tempPriority = _selectedPriority;
    String tempNature = _selectedNature;
    String tempAssignee = _selectedAssignee;
    String tempCreator = _selectedCreator;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Advanced Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: tempStatus,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: _statuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (value) => tempStatus = value ?? 'All',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: tempPriority,
                        decoration: const InputDecoration(labelText: 'Priority', isDense: true, border: OutlineInputBorder()),
                        items: _priorities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (value) => tempPriority = value ?? 'All',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: naturesSet.contains(tempNature) ? tempNature : 'All',
                  decoration: const InputDecoration(labelText: 'Product Nature', isDense: true, border: OutlineInputBorder()),
                  items: naturesList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (value) => tempNature = value ?? 'All',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: assigneesSet.contains(tempAssignee) ? tempAssignee : 'All',
                  decoration: const InputDecoration(labelText: 'Assigned User', isDense: true, border: OutlineInputBorder()),
                  items: assigneesList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (value) => tempAssignee = value ?? 'All',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: creatorsSet.contains(tempCreator) ? tempCreator : 'All',
                  decoration: const InputDecoration(labelText: 'Created By', isDense: true, border: OutlineInputBorder()),
                  items: creatorsList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (value) => tempCreator = value ?? 'All',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _resetFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset All'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatus = tempStatus;
                            _selectedPriority = tempPriority;
                            _selectedNature = tempNature;
                            _selectedAssignee = tempAssignee;
                            _selectedCreator = tempCreator;
                            _currentPage = 1; // Reset pagination on filter
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply Filters'),
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

  // --- DYNAMIC PAGINATION RENDERER ---
  Widget _buildPaginationBar(int totalRecords, int safeCurrentPage, int totalPages) {
    int start = (safeCurrentPage - 1) * _recordsPerPage + 1;
    int end = math.min(safeCurrentPage * _recordsPerPage, totalRecords);
    if (totalRecords == 0) {
      start = 0;
      end = 0;
    }

    // 8-page sliding window logic
    List<Widget> pageButtons = [];
    int startPage = safeCurrentPage;
    int endPage = startPage + 7;

    // Shift window back if we're near the final page bounds
    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = math.max(1, endPage - 7);
    }

    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(
        InkWell(
          onTap: () {
            if (_currentPage != i) setState(() => _currentPage = i);
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: safeCurrentPage == i ? Colors.blue.shade600 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: safeCurrentPage == i ? Colors.blue.shade600 : Colors.transparent),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(
                fontSize: 13,
                color: safeCurrentPage == i ? Colors.white : Colors.grey.shade800,
                fontWeight: safeCurrentPage == i ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      // The 80px right padding ensures the FloatingActionButton never overlaps page controls
      padding: const EdgeInsets.fromLTRB(16, 12, 80, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), offset: const Offset(0, -4), blurRadius: 10)],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          Text(
            'Showing $start–$end of $totalRecords records',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onPressed: safeCurrentPage > 1 ? () => setState(() => _currentPage = safeCurrentPage - 1) : null,
                  child: const Text('Previous', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ...pageButtons,
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onPressed: safeCurrentPage < totalPages ? () => setState(() => _currentPage = safeCurrentPage + 1) : null,
                  child: const Text('Next', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingRole) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New Request',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
          companyId: widget.companyId,
          currentUserUid: widget.currentUserUid,
          currentUserName: widget.currentUserName,
        ))),
        child: const Icon(Icons.add),
      ),
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final isWaiting = snapshot.connectionState == ConnectionState.waiting;
          final allDocs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyFilters(allDocs);
          final stats = _calculateStats(allDocs);

          // Safe Pagination Calculation
          final totalRecords = filteredDocs.length;
          int totalPages = (totalRecords / _recordsPerPage).ceil();
          if (totalPages == 0) totalPages = 1;

          int safeCurrentPage = _currentPage;
          if (safeCurrentPage > totalPages) safeCurrentPage = totalPages;

          final startIndex = (safeCurrentPage - 1) * _recordsPerPage;
          final endIndex = math.min(startIndex + _recordsPerPage, totalRecords);
          final pageDocs = totalRecords == 0 ? <QueryDocumentSnapshot<Map<String, dynamic>>>[] : filteredDocs.sublist(startIndex, endIndex);

          return Column(
            children: [
              // ENTERPRISE HEADER
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search request, customer, item...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.trim().isEmpty ? null : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      width: 38,
                      child: Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openFilterSheet(allDocs),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade800),
                              if (_hasActiveFilters)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded, size: 20),
                      tooltip: _isTableView ? 'Switch to List View' : 'Switch to Table View',
                      onPressed: _toggleViewMode,
                      color: Colors.grey.shade700,
                    ),
                    const Spacer(),
                    if (!isWaiting) ...[
                      _MiniStatText(label: 'Total', value: stats['Total'].toString()),
                      const SizedBox(width: 10),
                      _MiniStatText(label: 'New', value: stats['New'].toString()),
                      const SizedBox(width: 10),
                      _MiniStatText(label: 'Assigned', value: stats['Assigned'].toString()),
                      const SizedBox(width: 10),
                      _MiniStatText(label: 'In Progress', value: stats['In Progress'].toString()),
                      const SizedBox(width: 10),
                      _MiniStatText(label: 'Resolved', value: stats['Resolved'].toString()),
                      const SizedBox(width: 10),
                      _MiniStatText(label: 'Unassigned', value: stats['Unassigned'].toString(), highlight: stats['Unassigned']! > 0),
                    ],
                  ],
                ),
              ),
              if (_hasActiveFilters)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('Filters applied', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500))),
                      TextButton(onPressed: _resetFilters, child: const Text('Clear')),
                    ],
                  ),
                ),
              const Divider(height: 1, thickness: 1),

              // MAIN CONTENT
              Expanded(
                child: isWaiting
                    ? _buildSkeletonLoader()
                    : pageDocs.isEmpty
                    ? _EmptyRequestsState(
                  hasSearch: _searchQuery.trim().isNotEmpty || _hasActiveFilters,
                  onReset: _resetFilters,
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final forceCardView = constraints.maxWidth < 1100;
                    final effectiveTableView = forceCardView ? false : _isTableView;
                    return effectiveTableView ? _buildTableView(pageDocs) : _buildListView(pageDocs);
                  },
                ),
              ),

              // PAGINATION FOOTER
              if (!isWaiting && totalRecords > 0)
                _buildPaginationBar(totalRecords, safeCurrentPage, totalPages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => Container(
        height: 100,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildRequestCard(docs[index]);
      },
    );
  }

  Widget _buildTableView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    SizedBox(width: 40),
                    SizedBox(width: 200, child: Text('Request No / Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 140, child: Text('Contact Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 160, child: Text('Product & Nature', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 140, child: Text('Complaint & Priority', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 130, child: Text('Workflow Stage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 120, child: Text('Assigned To', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 120, child: Text('Created By', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 50, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                ),
              ),
              ...docs.map((doc) => _buildRequestTableRow(doc)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowTracker(String currentStage) {
    final int step = _getWorkflowPhaseIndex(currentStage);

    Widget dot(int index, String label) {
      bool active = index <= step;
      bool current = index == step;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: current ? 12 : 10,
            height: current ? 12 : 10,
            decoration: BoxDecoration(
              color: active ? Colors.green.shade600 : Colors.grey.shade300,
              shape: BoxShape.circle,
              border: current ? Border.all(color: Colors.green.shade200, width: 3) : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? Colors.black87 : Colors.grey.shade500,
              fontWeight: current ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      );
    }

    Widget line(int index) {
      bool active = index < step;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 15), // Aligns perfectly with the center of the dots
          height: 2,
          color: active ? Colors.green.shade600 : Colors.grey.shade200,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          dot(0, 'Created'), line(0),
          dot(1, 'Assigned'), line(1),
          dot(2, 'Execution'), line(2),
          dot(3, 'Completed'), line(3),
          dot(4, 'Closed'),
        ],
      ),
    );
  }

  Widget _buildRequestCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final requestNo = _safeString(data['requestNumber']);
    final customerName = _safeString(data['customerName']);
    final itemName = _safeString(data['serviceItemName'] ?? data['machineModel']);
    final itemNature = _safeString(data['serviceItemNature'] ?? data['machineNature']);

    // Enterprise Extensions
    final workflowStage = _getWorkflowStage(data);
    final visitCount = _safeInt(data['visitCount']);
    final lastVisitDate = _formatAnyTimestamp(data['lastVisitDate']);
    final isDelayed = _isWorkflowDelayed(data);
    final pendingReason = _safeString(data['pendingReason']);

    final priority = _safeString(data['priority']);
    final category = _safeString(data['complaintCategory']);
    final isWarranty = data['isWarranty'] == true;

    final assignedToName = _safeString(data['assignedToName']);
    final createdByName = _safeString(data['createdByName']);
    final createdAt = _extractDate(data['createdAt']);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showDetailsDialog(data),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedRequestIds.contains(doc.id) ? Colors.blue.shade300 : Colors.grey.shade200,
            width: _selectedRequestIds.contains(doc.id) ? 1.5 : 0.8,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _selectedRequestIds.contains(doc.id),
                  onChanged: (v) => _toggleSelection(doc.id),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Identifier + Customer + Date
                    Row(
                      children: [
                        if (requestNo.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.indigo.shade100)),
                            child: Text(requestNo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.indigo.shade800)),
                          ),
                        Expanded(
                          child: Text(
                            customerName.isNotEmpty ? customerName : '(Unknown Customer)',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(_timeAgo(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                            onSelected: (val) {
                              if (val == 'view') _showDetailsDialog(data);
                              if (val == 'edit') _editRequest(doc.id);
                              if (val == 'delete') _deleteRequest(doc.id);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'view', child: Text('View Details', style: TextStyle(fontSize: 13))),
                              const PopupMenuItem(value: 'edit', child: Text('Edit Request', style: TextStyle(fontSize: 13))),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'delete', child: Text('Delete Request', style: TextStyle(color: Colors.red, fontSize: 13))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // ROW 2: Product Info + Chips (Highly Condensed)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (itemName.isNotEmpty)
                          Text('$itemName ${itemNature.isNotEmpty ? '($itemNature)' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                        if (category.isNotEmpty)
                          _InfoChip(label: category, backgroundColor: Colors.purple.shade50, textColor: Colors.purple.shade800),

                        _buildAttentionChip(workflowStage),
                        if (isDelayed) const _DelayBadge(),

                        if (priority.isNotEmpty) _buildPriorityChip(priority),
                        if (isWarranty) _InfoChip(label: 'Warranty', backgroundColor: Colors.teal.shade50, textColor: Colors.teal.shade800),
                      ],
                    ),

                    // ROW 3: Pending Reason (If any)
                    if (pendingReason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade100)),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Pending: $pendingReason', style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ROW 4: Service Progress Tracker
                    _buildWorkflowTracker(workflowStage),
                    const SizedBox(height: 12),

                    // ROW 5: Assignments, Visits & Ownership
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _InlineInfo(icon: Icons.engineering_outlined, text: 'Assigned: ${assignedToName.isEmpty ? 'Unassigned' : assignedToName}'),
                        _InlineInfo(icon: Icons.pin_drop_outlined, text: 'Visits: $visitCount${lastVisitDate != '-' ? ' (Last: $lastVisitDate)' : ''}'),
                        _InlineInfo(icon: Icons.person_outline, text: 'Created By: ${createdByName.isEmpty ? 'System' : createdByName}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTableRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final requestNo = _safeString(data['requestNumber']);
    final customerName = _safeString(data['customerName']);
    final contactPerson = _safeString(data['contactPerson']);
    final mobile = _safeString(data['mobileNumber']);
    final category = _safeString(data['complaintCategory']);
    final itemName = _safeString(data['serviceItemName'] ?? data['machineModel']);
    final itemNature = _safeString(data['serviceItemNature'] ?? data['machineNature']);

    // Enterprise Extensions
    final workflowStage = _getWorkflowStage(data);
    final isDelayed = _isWorkflowDelayed(data);
    final pendingReason = _safeString(data['pendingReason']);

    final priority = _safeString(data['priority']);
    final assignedToName = _safeString(data['assignedToName']);
    final createdByName = _safeString(data['createdByName']);
    final createdAt = _extractDate(data['createdAt']);

    return InkWell(
      onTap: () => _showDetailsDialog(data),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(value: _selectedRequestIds.contains(doc.id), onChanged: (v) => _toggleSelection(doc.id)),
            ),
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customerName.isNotEmpty ? customerName : '(Unknown)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (requestNo.isNotEmpty) Text(requestNo, style: TextStyle(fontSize: 10, color: Colors.indigo.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contactPerson.isNotEmpty ? contactPerson : '-', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(mobile, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemName.isNotEmpty ? itemName : '-', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(itemNature.isNotEmpty ? itemNature.toUpperCase() : 'UNKNOWN', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.isNotEmpty ? category : '-', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  _buildPriorityChip(priority),
                ],
              ),
            ),
            SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildAttentionChip(workflowStage),
                        if (isDelayed) const _DelayBadge(),
                      ],
                    ),
                    if (pendingReason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('Pending: $pendingReason', style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                )
            ),
            SizedBox(
                width: 120,
                child: Text(assignedToName.isNotEmpty ? assignedToName : 'Unassigned', style: TextStyle(fontSize: 12, color: assignedToName.isEmpty ? Colors.red.shade700 : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)
            ),
            SizedBox(
                width: 120,
                child: Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(child: Text(createdByName.isNotEmpty ? createdByName : '-', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                )
            ),
            SizedBox(width: 100, child: Text(_timeAgo(createdAt), style: const TextStyle(fontSize: 11))),
            SizedBox(
                width: 50,
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
                  padding: EdgeInsets.zero,
                  tooltip: 'Actions',
                  onSelected: (val) {
                    if (val == 'view') _showDetailsDialog(data);
                    if (val == 'edit') _editRequest(doc.id);
                    if (val == 'delete') _deleteRequest(doc.id);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'view', child: Text('View Details', style: TextStyle(fontSize: 13))),
                    const PopupMenuItem(value: 'edit', child: Text('Edit Request', style: TextStyle(fontSize: 13))),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Request', style: TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionChip(String stage) {
    final name = _getWorkflowDisplayName(stage);
    final color = _getWorkflowColor(stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color bg; Color fg;
    switch (priority) {
      case 'Critical': bg = Colors.red.shade50; fg = Colors.red.shade800; break;
      case 'High': bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Medium': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'Low': bg = Colors.grey.shade100; fg = Colors.grey.shade800; break;
      default: bg = Colors.grey.shade100; fg = Colors.grey.shade800;
    }
    return _InfoChip(label: priority, backgroundColor: bg, textColor: fg);
  }
}

// ==========================================
// SHARED ENTERPRISE UI COMPONENTS
// ==========================================

class _DelayBadge extends StatelessWidget {
  const _DelayBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(4)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 10, color: Colors.white),
          SizedBox(width: 2),
          Text('Delayed', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _MiniStatText({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: TextStyle(fontSize: 12, color: highlight ? Colors.red.shade700 : Colors.grey.shade700, fontWeight: highlight ? FontWeight.w800 : FontWeight.w600));
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: text.contains('Unassigned') ? Colors.red.shade700 : Colors.grey.shade800, fontWeight: text.contains('Unassigned') ? FontWeight.bold : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  const _InfoChip({required this.label, required this.backgroundColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;
  const _EmptyRequestsState({required this.hasSearch, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: IntrinsicHeight(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        hasSearch ? Icons.search_off : Icons.support_agent_outlined,
                        size: 28,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch ? 'No matching service requests found' : 'No service requests found',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch ? 'Try changing the search text or filters.' : 'Click the button below to create your first service request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    if (hasSearch) OutlinedButton(onPressed: onReset, child: const Text('Reset Filters')),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}