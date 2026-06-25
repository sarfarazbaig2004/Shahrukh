// FILE PATH: lib/modules/service/service_visits/service_visit_list_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_service_visit_screen.dart';
import 'service_visit_details_screen.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

int _safeInt(dynamic val) => int.tryParse((val ?? '0').toString()) ?? 0;

String _safeString(dynamic val) => (val ?? '').toString().trim();

DateTime? _extractDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _timeAgoStrict(DateTime? d) {
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays > 1) return '${diff.inDays} days ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String _formatDateOnly(DateTime? dt) {
  if (dt == null) return '-';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  return '$day-$month-$year';
}

String _formatDate(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

bool _isOverdue(DateTime? visitDate, String status) {
  if (visitDate == null) return false;
  if (status == 'Completed' || status == 'Cancelled' || status == 'Resolved') return false;
  final today = DateTime.now();
  final vDate = DateTime(visitDate.year, visitDate.month, visitDate.day);
  final tDate = DateTime(today.year, today.month, today.day);
  return vDate.isBefore(tDate);
}

bool _isToday(DateTime? visitDate) {
  if (visitDate == null) return false;
  final today = DateTime.now();
  return visitDate.year == today.year && visitDate.month == today.month && visitDate.day == today.day;
}

// Helper to reliably extract human names and ignore raw Firebase UIDs
String _resolveName(Map<String, dynamic> data, List<String> keys) {
  for (var key in keys) {
    String val = _safeString(data[key]);
    // Ignore raw UIDs (typically 28 alphanumeric chars without spaces)
    if (val.isNotEmpty && val.length < 35 && !val.contains(RegExp(r'^[a-zA-Z0-9]{25,}$'))) {
      return val;
    }
  }
  return '';
}

// ==========================================
// MAIN SCREEN
// ==========================================

class ServiceVisitListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const ServiceVisitListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<ServiceVisitListScreen> createState() => _ServiceVisitListScreenState();
}

class _ServiceVisitListScreenState extends State<ServiceVisitListScreen> {
  // --- CORE UI STATE ---
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  // --- FILTERS STATE ---
  String _searchQuery = '';
  String _filterEngineer = 'All';
  String _filterType = 'All';
  String _filterStatus = 'All';
  String _filterPriority = 'All';
  bool _filterOnlyOverdue = false;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _isTableView = false;

  // --- SELECTION STATE ---
  final Set<String> _selectedIds = {};

  // --- ROLE BASED ACCESS ---
  bool _isAdminOrManager = false;
  bool _isFetchingRole = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetchUserRole();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .doc(widget.currentUserUid)
          .get();

      if (doc.exists && mounted) {
        final role = _safeString(doc.data()?['role']).toLowerCase();
        setState(() {
          _isAdminOrManager = ['admin', 'superadmin', 'manager', 'coordinator', 'service manager', 'service coordinator'].contains(role);
          _isFetchingRole = false;
        });
      } else {
        if (mounted) setState(() => _isFetchingRole = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingRole = false);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isTableView = prefs.getBool('erp_visit_view_pref') ?? false);
    }
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isTableView = !_isTableView);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('erp_visit_view_pref', _isTableView);
    } catch (_) {}
  }

  void _onSearch(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _searchQuery != query.toLowerCase().trim()) {
        setState(() {
          _searchQuery = query.toLowerCase().trim();
          _currentPage = 1;
        });
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  bool get _hasActiveFilters => _filterEngineer != 'All' || _filterType != 'All' || _filterStatus != 'All' || _filterPriority != 'All' || _filterOnlyOverdue;

  // --- DATA FILTERING ---

  bool _hasAccessToVisit(Map<String, dynamic> data) {
    if (_isAdminOrManager) return true;

    final techUid = _safeString(data['assignedTechnicianUid']);
    final engUid = _safeString(data['engineerUid']);
    final createdBy = _safeString(data['createdBy']);

    return techUid == widget.currentUserUid ||
        engUid == widget.currentUserUid ||
        createdBy == widget.currentUserUid;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final filtered = docs.where((doc) {
      final data = doc.data();
      if (data['isDeleted'] == true) return false;

      // Role Security Rule
      if (!_hasAccessToVisit(data)) return false;

      final engName = _safeString(data['assignedTechnician']) != '' ? _safeString(data['assignedTechnician']) : _safeString(data['engineerName']);
      final type = _safeString(data['visitType']);
      final status = _safeString(data['visitStatus']);
      final priority = _safeString(data['priority']);
      final vDate = _extractDate(data['visitDate']);

      if (_filterEngineer != 'All' && engName != _filterEngineer) return false;
      if (_filterType != 'All' && type != _filterType) return false;
      if (_filterStatus != 'All' && status != _filterStatus) return false;
      if (_filterPriority != 'All' && priority != _filterPriority) return false;
      if (_filterOnlyOverdue && !_isOverdue(vDate, status)) return false;

      if (_searchQuery.isNotEmpty) {
        final vNo = _safeString(data['visitNo']).toLowerCase();
        final rNo = _safeString(data['requestNumber']).toLowerCase();
        final cust = _safeString(data['customerName']).toLowerCase();
        final machine = _safeString(data['machineName']).toLowerCase();
        final serial = _safeString(data['serialNumber']).toLowerCase();
        final mobile = _safeString(data['customerMobile']).toLowerCase();
        final eng = engName.toLowerCase();

        final matchesSearch = vNo.contains(_searchQuery) ||
            rNo.contains(_searchQuery) ||
            cust.contains(_searchQuery) ||
            machine.contains(_searchQuery) ||
            serial.contains(_searchQuery) ||
            mobile.contains(_searchQuery) ||
            eng.contains(_searchQuery);

        if (!matchesSearch) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _extractDate(a.data()['visitDate']) ?? _extractDate(a.data()['createdAt']) ?? DateTime(2000);
      final bDate = _extractDate(b.data()['visitDate']) ?? _extractDate(b.data()['createdAt']) ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Map<String, int> _getStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int todayVisits = 0;
    int scheduled = 0;
    int travelStarted = 0;
    int inProgress = 0;
    int completed = 0;
    int overdue = 0;

    for (var d in docs) {
      final data = d.data();
      if (data['isDeleted'] == true) continue;
      if (!_hasAccessToVisit(data)) continue;

      final s = _safeString(data['visitStatus']);
      final vDate = _extractDate(data['visitDate']);

      if (_isToday(vDate)) todayVisits++;
      if (_isOverdue(vDate, s)) overdue++;

      if (s == 'Scheduled') scheduled++;
      else if (s == 'Travel Started') travelStarted++;
      else if (s == 'In Progress') inProgress++;
      else if (s == 'Completed' || s == 'Resolved') completed++;
    }

    return {
      'Today': todayVisits,
      'Scheduled': scheduled,
      'Travel': travelStarted,
      'WIP': inProgress,
      'Completed': completed,
      'Overdue': overdue
    };
  }

  // --- SMART ACTIONS ---

  Future<void> _startTravel(String docId, Map<String, dynamic> data) async {
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Start Travel?'),
          content: const Text('Update status to Travel Started and log timestamp?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start Travel')),
          ],
        )
    );

    if (confirm != true) return;

    try {
      final visitRef = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').doc(docId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(visitRef, {
          'visitStatus': 'Travel Started',
          'travelStartedAt': FieldValue.serverTimestamp(),
          'travelStartedByUid': widget.currentUserUid,
          'travelStartedByName': widget.currentUserName,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': widget.currentUserUid,
        });
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Travel Started Successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _startService(String docId, Map<String, dynamic> data) async {
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Start Service?'),
          content: const Text('Update status to In Progress and sync with the main service request?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start Service')),
          ],
        )
    );

    if (confirm != true) return;

    try {
      final visitRef = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').doc(docId);
      final reqNo = _safeString(data['requestNumber']);

      QuerySnapshot reqQuery = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId)
          .collection('service_requests').where('requestNumber', isEqualTo: reqNo).limit(1).get();

      DocumentReference? reqRef = reqQuery.docs.isNotEmpty ? reqQuery.docs.first.reference : null;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(visitRef, {
          'visitStatus': 'In Progress',
          'visitStartedAt': FieldValue.serverTimestamp(),
          'visitStartedByUid': widget.currentUserUid,
          'visitStartedByName': widget.currentUserName,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': widget.currentUserUid,
        });

        if (reqRef != null) {
          transaction.update(reqRef, {
            'status': 'In Progress',
            'visitStartedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': widget.currentUserUid,
          });
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Started Successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _uploadReport(String docId, Map<String, dynamic> data) async {
    final bool? uploaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UploadReportDialog(companyId: widget.companyId, currentUserUid: widget.currentUserUid),
    );

    if (uploaded != true) return;

    try {
      final visitRef = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').doc(docId);
      final reqNo = _safeString(data['requestNumber']);

      QuerySnapshot reqQuery = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId)
          .collection('service_requests').where('requestNumber', isEqualTo: reqNo).limit(1).get();

      DocumentReference? reqRef = reqQuery.docs.isNotEmpty ? reqQuery.docs.first.reference : null;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(visitRef, {
          'visitStatus': 'Completed',
          'completedAt': FieldValue.serverTimestamp(),
          'reportSubmittedAt': FieldValue.serverTimestamp(),
          'reportImages': ['https://dummyurl.com/report1.jpg', 'https://dummyurl.com/sig.png'], // Simulated URLs
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': widget.currentUserUid,
        });

        if (reqRef != null) {
          transaction.update(reqRef, {
            'status': 'Report Submitted',
            'reportSubmittedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': widget.currentUserUid,
          });
        }
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Uploaded & Visit Completed'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _softDelete(String docId) {
    FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_visits')
        .doc(docId)
        .update({'isDeleted': true})
        .then((_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit deleted.'), backgroundColor: Colors.red));
    }).catchError((e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    });
  }

  void _navigateToDetails(String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(
        companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, visitId: docId, visitData: data
    )));
  }

  void _viewReport(String docId, Map<String, dynamic> data) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Viewer coming soon...')));
    }
  }

  // --- FILTERS SHEET ---

  Future<void> _openFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, int> stats) async {
    Set<String> engSet = {'All'};
    Set<String> typeSet = {'All'};
    Set<String> prioritySet = {'All', 'Low', 'Medium', 'High', 'Critical'};
    Set<String> statusSet = {'All', 'Scheduled', 'Travel Started', 'In Progress', 'Completed', 'Cancelled'};

    for (var d in docs) {
      final data = d.data();
      if (data['isDeleted'] == true || !_hasAccessToVisit(data)) continue;

      final tech = _resolveName(data, ['assignedTechnicianName', 'assignedTechnician', 'engineerName']);
      if (tech.isNotEmpty) engSet.add(tech);
      if (_safeString(data['visitType']).isNotEmpty) typeSet.add(_safeString(data['visitType']));
    }

    String tEng = _filterEngineer, tType = _filterType, tStatus = _filterStatus, tPri = _filterPriority;
    bool tOverdue = _filterOnlyOverdue;

    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(20, 6, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Visit Analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _buildStatChip('Today', stats['Today'], Colors.indigo.shade600),
                          _buildStatChip('Scheduled', stats['Scheduled'], Colors.blue.shade600),
                          _buildStatChip('Travel', stats['Travel'], Colors.purple.shade600),
                          _buildStatChip('WIP', stats['WIP'], Colors.orange.shade600),
                          _buildStatChip('Completed', stats['Completed'], Colors.green.shade600),
                          _buildStatChip('Overdue', stats['Overdue'], Colors.red.shade600),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      const Text('Advanced Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: statusSet.contains(tStatus) ? tStatus : 'All',
                        decoration: const InputDecoration(labelText: 'Visit Status', isDense: true, border: OutlineInputBorder()),
                        items: statusSet.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (v) => tStatus = v!,
                      ),
                      const SizedBox(height: 16),

                      if (_isAdminOrManager) ...[
                        DropdownButtonFormField<String>(
                          value: engSet.contains(tEng) ? tEng : 'All',
                          decoration: const InputDecoration(labelText: 'Assigned Technician', isDense: true, border: OutlineInputBorder()),
                          items: engSet.toList().map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => tEng = v!,
                        ),
                        const SizedBox(height: 16),
                      ],

                      DropdownButtonFormField<String>(
                        value: prioritySet.contains(tPri) ? tPri : 'All',
                        decoration: const InputDecoration(labelText: 'Priority', isDense: true, border: OutlineInputBorder()),
                        items: prioritySet.toList().map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (v) => tPri = v!,
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text('Show Only Overdue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Visits that missed their scheduled date', style: TextStyle(fontSize: 12)),
                        value: tOverdue,
                        activeColor: Colors.red,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setModalState(() => tOverdue = val),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _filterEngineer = 'All'; _filterType = 'All';
                                  _filterStatus = 'All'; _filterPriority = 'All';
                                  _filterOnlyOverdue = false; _currentPage = 1;
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text('Clear Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _filterEngineer = tEng; _filterType = tType;
                                  _filterStatus = tStatus; _filterPriority = tPri;
                                  _filterOnlyOverdue = tOverdue; _currentPage = 1;
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            }
        )
    );
  }

  Widget _buildStatChip(String title, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title:', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value.toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(elevation: 0, toolbarHeight: 6, automaticallyImplyLeading: false, backgroundColor: Colors.white),
      floatingActionButton: _isAdminOrManager ? FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
            companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName))),
        tooltip: 'New Visit',
        child: const Icon(Icons.add),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final isWaiting = snap.connectionState == ConnectionState.waiting;
          final allDocs = snap.data?.docs ?? [];
          final filteredDocs = _applyFilters(allDocs);
          final stats = _getStats(allDocs);

          final totalPages = math.max(1, (filteredDocs.length / _pageSize).ceil());
          int safePage = _currentPage > totalPages ? totalPages : _currentPage;
          final pagedDocs = filteredDocs.sublist((safePage - 1) * _pageSize, math.min(safePage * _pageSize, filteredDocs.length));

          return Column(
            children: [
              _buildHeader(stats),
              if (_hasActiveFilters) _buildActiveFiltersBar(),
              const Divider(height: 1, thickness: 1),

              Expanded(
                  child: isWaiting ? const Center(child: CircularProgressIndicator())
                      : pagedDocs.isEmpty ? const Center(child: Text('No service visits found.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                      : _isTableView ? _buildTable(pagedDocs) : _buildCards(pagedDocs)
              ),
              if (filteredDocs.length > _pageSize)
                _buildPagination(filteredDocs.length, safePage, totalPages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, int> stats) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search visits, requests, machines, customers...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.trim().isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 17), onPressed: () { _searchCtrl.clear(); _onSearch(''); }),
                    isDense: true, filled: true, fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              height: 38, width: 38,
              child: Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openFilters([], stats), // UI Trigger
                      child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade800),
                            if (_hasActiveFilters) Positioned(right: 8, top: 8, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.indigo.shade700, shape: BoxShape.circle))),
                          ]
                      )
                  )
              )
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
                icon: Icon(_isTableView ? Icons.grid_view : Icons.table_rows, size: 18, color: Colors.grey.shade700),
                onPressed: _toggleViewMode,
                tooltip: 'Toggle View'
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(width: 16),
            Text('${_selectedIds.length} selected', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: _clearSelection, tooltip: 'Clear Selection'),
          ]
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                if (_filterStatus != 'All') _buildFilterChip('Status: $_filterStatus'),
                if (_filterPriority != 'All') _buildFilterChip('Pri: $_filterPriority'),
                if (_filterEngineer != 'All') _buildFilterChip('Eng: $_filterEngineer'),
                if (_filterOnlyOverdue) _buildFilterChip('Overdue Only', color: Colors.red.shade700),
              ],
            ),
          ),
          TextButton(
              onPressed: () => setState(() { _filterEngineer = 'All'; _filterType = 'All'; _filterStatus = 'All'; _filterPriority = 'All'; _filterOnlyOverdue = false; _currentPage = 1; }),
              child: const Text('Clear', style: TextStyle(fontSize: 12))
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {Color? color}) {
    final c = color ?? Colors.blue.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.2))),
      child: Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
        itemCount: docs.length,
        itemBuilder: (ctx, i) {
          return _VisitCard(
            docId: docs[i].id,
            data: docs[i].data(),
            isSelected: _selectedIds.contains(docs[i].id),
            onSelect: _toggleSelection,
            onView: _navigateToDetails,
            onStartTravel: _startTravel,
            onStartService: _startService,
            onUploadReport: _uploadReport,
            onViewReport: _viewReport,
            onDelete: _softDelete,
          );
        }
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            headingTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.blueGrey.shade700),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 56,
            showCheckboxColumn: true,
            columns: const [
              DataColumn(label: Text('VISIT NO')),
              DataColumn(label: Text('CUSTOMER')),
              DataColumn(label: Text('MACHINE')),
              DataColumn(label: Text('TECHNICIAN')),
              DataColumn(label: Text('DATE')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('PRIORITY')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: docs.map((doc) {
              final d = doc.data();
              final tech = _resolveName(d, ['assignedTechnicianName', 'assignedTechnician', 'engineerName']);
              final status = _safeString(d['visitStatus']);
              final isSelected = _selectedIds.contains(doc.id);

              return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => _toggleSelection(doc.id),
                  cells: [
                    DataCell(Text(_safeString(d['visitNo']), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo))),
                    DataCell(Text(_safeString(d['customerName']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    DataCell(Text(_safeString(d['machineName']), style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
                    DataCell(Text(tech.isEmpty ? '-' : tech, style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${_formatDateOnly(_extractDate(d['visitDate']))} ${_safeString(d['visitTime'])}', style: const TextStyle(fontSize: 12))),
                    DataCell(_buildStatusMiniBadge(status, _VisitCard.getStatusColor(status))),
                    DataCell(_buildPriorityMiniBadge(_safeString(d['priority']))),
                    DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.visibility, color: Colors.indigo, size: 18), onPressed: () => _navigateToDetails(doc.id, d), tooltip: 'View'),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                              onSelected: (val) {
                                if (val == 'travel') _startTravel(doc.id, d);
                                if (val == 'service') _startService(doc.id, d);
                                if (val == 'report') _uploadReport(doc.id, d);
                                if (val == 'view_report') _viewReport(doc.id, d);
                                if (val == 'delete') _softDelete(doc.id);
                              },
                              itemBuilder: (ctx) => [
                                if (status == 'Scheduled' || status == 'New') const PopupMenuItem(value: 'travel', child: Text('Start Travel')),
                                if (status == 'Travel Started') const PopupMenuItem(value: 'service', child: Text('Start Service')),
                                if (status == 'In Progress') const PopupMenuItem(value: 'report', child: Text('Upload Report')),
                                if (status == 'Completed' || status == 'Resolved') const PopupMenuItem(value: 'view_report', child: Text('View Report')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        )
                    )
                  ]
              );
            }).toList(),
          ),
        )
    );
  }

  Widget _buildStatusMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildPriorityMiniBadge(String text) {
    Color color = Colors.grey;
    if (text == 'High' || text == 'Critical') color = Colors.red;
    if (text == 'Medium') color = Colors.orange;
    if (text == 'Low') color = Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildPagination(int total, int current, int pages) {
    return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Showing ${docsCount(total, current)} of $total', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            Row(
              children: [
                OutlinedButton(onPressed: current > 1 ? () => setState(() => _currentPage--) : null, child: const Text('Prev')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Page $current of $pages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                OutlinedButton(onPressed: current < pages ? () => setState(() => _currentPage++) : null, child: const Text('Next')),
              ],
            )
          ],
        )
    );
  }

  String docsCount(int total, int curr) => total == 0 ? '0' : '${(curr - 1) * _pageSize + 1}-${math.min(curr * _pageSize, total)}';
}

// ==========================================
// OPTIMIZED VISIT ROW WIDGET (STATELESS)
// ==========================================

class _VisitCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isSelected;
  final Function(String) onSelect;
  final Function(String, Map<String, dynamic>) onView;
  final Function(String, Map<String, dynamic>) onStartTravel;
  final Function(String, Map<String, dynamic>) onStartService;
  final Function(String, Map<String, dynamic>) onUploadReport;
  final Function(String, Map<String, dynamic>) onViewReport;
  final Function(String) onDelete;

  const _VisitCard({
    required this.docId,
    required this.data,
    required this.isSelected,
    required this.onSelect,
    required this.onView,
    required this.onStartTravel,
    required this.onStartService,
    required this.onUploadReport,
    required this.onViewReport,
    required this.onDelete,
  });

  static Color getStatusColor(String status) {
    if (status == 'Scheduled' || status == 'New') return Colors.blue;
    if (status == 'Travel Started') return Colors.purple;
    if (status == 'In Progress') return Colors.orange;
    if (status == 'Completed' || status == 'Resolved') return Colors.green;
    if (status == 'Cancelled') return Colors.red;
    return Colors.grey;
  }

  Widget _buildWorkflowRow(String status) {
    bool travel = false;
    bool service = false;
    bool report = false;
    bool completed = false;

    if (status == 'Travel Started') {
      travel = true;
    } else if (status == 'In Progress') {
      travel = true;
      service = true;
    } else if (status == 'Completed' || status == 'Resolved') {
      travel = true;
      service = true;
      report = true;
      completed = true;
    }

    Widget buildStep(String label, bool isComplete) {
      String mark = isComplete ? '✓' : '○';
      Color color = isComplete ? Colors.green.shade700 : (status == 'Cancelled' ? Colors.red : Colors.grey.shade400);
      if (!isComplete && status != 'Completed' && status != 'Cancelled') {
        if ((label == 'Travel' && !travel) ||
            (label == 'Service' && travel && !service) ||
            (label == 'Report' && service && !report) ||
            (label == 'Complete' && report && !completed)) {
          color = Colors.orange.shade700;
        }
      }

      return Text('$label $mark', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color));
    }

    final arrow = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text('>', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold))
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildStep('Travel', travel), arrow,
          buildStep('Service', service), arrow,
          buildStep('Report', report), arrow,
          buildStep('Complete', completed),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visitNo = _safeString(data['visitNo']);
    final reqNo = _safeString(data['requestNumber']);
    final customer = _safeString(data['customerName']);
    final machine = _safeString(data['machineName']);
    final complaint = _safeString(data['complaintDescription']);
    final priority = _safeString(data['priority']);
    final status = _safeString(data['visitStatus']);
    final vDate = _extractDate(data['visitDate'] ?? data['createdAt']);
    final vTime = _safeString(data['visitTime']);
    final isWarr = _safeString(data['warrantyStatus']).toLowerCase().contains('under warranty');

    // OWNERSHIP HIERARCHY RESOLUTION (Fetch Display Names, Avoid UIDs)
    final techName = _resolveName(data, ['assignedTechnicianName', 'currentTechnicianName', 'assignedTechnician', 'engineerName']);
    final salesName = _resolveName(data, ['salesPersonName', 'customerOwnerName', 'recordOwnerName']);
    final serviceOwner = _resolveName(data, ['assignedManagerName', 'assignedCoordinatorName']); // Removed generic 'createdBy' fallback to preserve integrity

    List<String> ownerLine = [];
    if (salesName.isNotEmpty) ownerLine.add('Sales: $salesName');
    if (serviceOwner.isNotEmpty) ownerLine.add('Service: $serviceOwner');
    if (techName.isNotEmpty) ownerLine.add('Tech: $techName');

    List<String> metricsLine = [];
    if (priority.isNotEmpty) metricsLine.add('Pri: $priority');
    if (isWarr) metricsLine.add('Warranty');
    if (_isToday(vDate)) metricsLine.add('Today');
    if (_isOverdue(vDate, status)) metricsLine.add('Overdue');
    if (vTime.isNotEmpty) metricsLine.add(vTime);

    final isSelectedRowDecoration = BoxDecoration(color: Colors.indigo.shade50.withOpacity(0.3), border: Border(bottom: BorderSide(color: Colors.grey.shade200)));
    final rowDecoration = BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200)));

    return InkWell(
      onTap: () => onView(docId, data),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: isSelected ? isSelectedRowDecoration : rowDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: Checkbox(
                visualDensity: VisualDensity.compact,
                value: isSelected,
                onChanged: (_) => onSelect(docId),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                          children: [
                            TextSpan(text: visitNo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade700)),
                            if (reqNo.isNotEmpty) TextSpan(text: '  •  $reqNo', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            TextSpan(text: '  •  ${_timeAgoStrict(vDate)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ]
                      )
                  ),
                  const SizedBox(height: 4),

                  Text(customer.isNotEmpty ? customer : 'Unknown Customer', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),

                  if (machine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(machine, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],

                  if (complaint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Issue • $complaint', style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],

                  if (ownerLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(ownerLine.join('  •  '), style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],

                  const SizedBox(height: 6),
                  _buildWorkflowRow(status),

                  if (metricsLine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(metricsLine.join('  •  '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]
                ],
              ),
            ),
            const SizedBox(width: 8),

            // RIGHT STATUS PANEL
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                  onSelected: (val) {
                    if (val == 'view') onView(docId, data);
                    if (val == 'travel') onStartTravel(docId, data);
                    if (val == 'service') onStartService(docId, data);
                    if (val == 'report') onUploadReport(docId, data);
                    if (val == 'view_report') onViewReport(docId, data);
                    if (val == 'delete') onDelete(docId);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'view', child: Text('Open Visit')),
                    const PopupMenuDivider(),
                    if (status == 'Scheduled' || status == 'New') const PopupMenuItem(value: 'travel', child: Text('Start Travel')),
                    if (status == 'Travel Started') const PopupMenuItem(value: 'service', child: Text('Start Service')),
                    if (status == 'In Progress') const PopupMenuItem(value: 'report', child: Text('Upload Report')),
                    if (status == 'Completed' || status == 'Resolved') const PopupMenuItem(value: 'view_report', child: Text('View Report')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Status', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: getStatusColor(status)),
                  textAlign: TextAlign.right,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('Tech', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(
                  techName.isEmpty ? 'Unassigned' : techName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                  textAlign: TextAlign.right,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('Visit Date', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(
                  _formatDateOnly(vDate),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                  textAlign: TextAlign.right,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MOCK UPLOAD REPORT UI
// ==========================================

class _UploadReportDialog extends StatefulWidget {
  final String companyId;
  final String currentUserUid;

  const _UploadReportDialog({required this.companyId, required this.currentUserUid});

  @override
  State<_UploadReportDialog> createState() => _UploadReportDialogState();
}

class _UploadReportDialogState extends State<_UploadReportDialog> {
  bool _isUploading = false;
  int _simulatedFiles = 0;

  void _simulateFilePick() {
    setState(() => _simulatedFiles++);
  }

  void _submit() async {
    if (_simulatedFiles == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least 1 report image/document.')));
      return;
    }
    setState(() => _isUploading = true);
    // Simulate network upload delay
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Service Report'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please upload handwritten reports, machine photos, or customer signatures (1-10 photos).', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),

            InkWell(
              onTap: _isUploading ? null : _simulateFilePick,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    border: Border.all(color: Colors.blue.withOpacity(0.3), style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload, size: 40, color: Colors.blue.shade300),
                    const SizedBox(height: 10),
                    const Text('Click to Browse or Take Photo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            if (_simulatedFiles > 0)
              Text('$_simulatedFiles file(s) selected ready for upload.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),

            if (_isUploading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Center(child: CircularProgressIndicator()),
              )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isUploading ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isUploading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Complete Visit & Submit'),
        ),
      ],
    );
  }
}