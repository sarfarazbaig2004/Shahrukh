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

String _formatDate(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

String _formatDateTime(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $hour:$min $amPm';
}

bool _isOverdue(DateTime? visitDate, String status) {
  if (visitDate == null) return false;
  if (status == 'Completed' || status == 'Cancelled') return false;
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
    // Show mock UI for uploading 1-10 photos and generating a report
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

  // --- FILTERS SHEET ---

  Future<void> _openFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    Set<String> engSet = {'All'};
    Set<String> typeSet = {'All'};
    Set<String> prioritySet = {'All', 'Low', 'Medium', 'High', 'Critical'};
    Set<String> statusSet = {'All', 'Scheduled', 'Travel Started', 'In Progress', 'Completed', 'Cancelled'};

    for (var d in docs) {
      final data = d.data();
      if (data['isDeleted'] == true || !_hasAccessToVisit(data)) continue;

      final tech = _safeString(data['assignedTechnician']) != '' ? _safeString(data['assignedTechnician']) : _safeString(data['engineerName']);
      if (tech.isNotEmpty) engSet.add(tech);
      if (_safeString(data['visitType']).isNotEmpty) typeSet.add(_safeString(data['visitType']));
    }

    String tEng = _filterEngineer, tType = _filterType, tStatus = _filterStatus, tPri = _filterPriority;
    bool tOverdue = _filterOnlyOverdue;

    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filter Workspace', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: statusSet.contains(tStatus) ? tStatus : 'All',
                        decoration: const InputDecoration(labelText: 'Visit Status', border: OutlineInputBorder()),
                        items: statusSet.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => tStatus = v!,
                      ),
                      const SizedBox(height: 12),
                      if (_isAdminOrManager) ...[
                        DropdownButtonFormField<String>(
                          value: engSet.contains(tEng) ? tEng : 'All',
                          decoration: const InputDecoration(labelText: 'Assigned Technician', border: OutlineInputBorder()),
                          items: engSet.toList().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => tEng = v!,
                        ),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<String>(
                        value: prioritySet.contains(tPri) ? tPri : 'All',
                        decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                        items: prioritySet.toList().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => tPri = v!,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Show Only Overdue'),
                        subtitle: const Text('Visits that missed their scheduled date'),
                        value: tOverdue,
                        activeColor: Colors.red,
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
                              child: const Text('Clear Filters'),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
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

  @override
  Widget build(BuildContext context) {
    if (_isFetchingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: _isAdminOrManager ? FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
            companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName))),
        child: const Icon(Icons.add),
      ) : null,
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
              // KPI DASHBOARD
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKpiCard('Today\'s Visits', stats['Today'].toString(), Colors.indigo),
                      _buildKpiCard('Scheduled', stats['Scheduled'].toString(), Colors.blue),
                      _buildKpiCard('Travel Started', stats['Travel'].toString(), Colors.purple),
                      _buildKpiCard('In Progress', stats['WIP'].toString(), Colors.orange),
                      _buildKpiCard('Completed', stats['Completed'].toString(), Colors.green),
                      _buildKpiCard('Overdue', stats['Overdue'].toString(), Colors.red),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // TOOLBAR
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl, onChanged: _onSearch,
                          decoration: InputDecoration(
                              hintText: 'Search visits, requests, machines, customers...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              contentPadding: EdgeInsets.zero
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: IconButton(icon: const Icon(Icons.tune, size: 20), onPressed: () => _openFilters(allDocs), tooltip: 'Filters'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: IconButton(icon: Icon(_isTableView ? Icons.grid_view : Icons.table_rows, size: 20), onPressed: _toggleViewMode, tooltip: 'Toggle View'),
                    ),
                  ],
                ),
              ),
              if (_filterEngineer != 'All' || _filterType != 'All' || _filterStatus != 'All' || _filterPriority != 'All' || _filterOnlyOverdue)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Text('Filters Applied: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      if (_filterStatus != 'All') _buildFilterChip(_filterStatus),
                      if (_filterPriority != 'All') _buildFilterChip('Pri: $_filterPriority'),
                      if (_filterEngineer != 'All') _buildFilterChip('Eng: $_filterEngineer'),
                      if (_filterOnlyOverdue) _buildFilterChip('Overdue Only', color: Colors.red),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() { _filterEngineer = 'All'; _filterType = 'All'; _filterStatus = 'All'; _filterPriority = 'All'; _filterOnlyOverdue = false; _currentPage = 1; }),
                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                ),

              // MAIN CONTENT
              Expanded(
                  child: isWaiting ? const Center(child: CircularProgressIndicator())
                      : pagedDocs.isEmpty ? const Center(child: Text('No service visits found for this criteria.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                      : _isTableView ? _buildTable(pagedDocs) : _buildCards(pagedDocs)
              ),
              _buildPagination(filteredDocs.length, safePage, totalPages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, {Color color = Colors.blue}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildKpiCard(String title, String value, MaterialColor color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color.shade800, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color.shade900)),
        ],
      ),
    );
  }

  Widget _buildCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (ctx, i) {
          final d = docs[i].data();
          final String docId = docs[i].id;

          final String status = _safeString(d['visitStatus']);
          final String priority = _safeString(d['priority']);
          final String reqNo = _safeString(d['requestNumber']);
          final String visitNo = _safeString(d['visitNo']);
          final String customer = _safeString(d['customerName']);
          final String machine = _safeString(d['machineName']);
          final String complaint = _safeString(d['complaintDescription']);
          final String address = _safeString(d['customerAddress']) != '' ? _safeString(d['customerAddress']) : _safeString(d['address']);
          final String techName = _safeString(d['assignedTechnician']) != '' ? _safeString(d['assignedTechnician']) : _safeString(d['engineerName']);

          final bool isWarr = _safeString(d['warrantyStatus']).toLowerCase().contains('under warranty');

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Identifiers & Badges
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6)), child: Text('Visit: $visitNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Text('Req: $reqNo', style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
                      const Spacer(),
                      _buildStatusBadge(status),
                      const SizedBox(width: 6),
                      if (priority.isNotEmpty) _buildPriorityBadge(priority),
                      const SizedBox(width: 6),
                      if (isWarr) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)), child: const Icon(Icons.verified_user, size: 12, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Customer
                  Row(
                    children: [
                      CircleAvatar(radius: 18, backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.business, size: 18, color: Colors.indigo)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(customer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 3: Machine & Complaint
                  if (machine.isNotEmpty || complaint.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (machine.isNotEmpty) Row(children: [const Icon(Icons.settings, size: 14, color: Colors.grey), const SizedBox(width: 6), Expanded(child: Text('Machine: $machine', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))]),
                          if (machine.isNotEmpty && complaint.isNotEmpty) const SizedBox(height: 6),
                          if (complaint.isNotEmpty) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.error_outline, size: 14, color: Colors.redAccent), const SizedBox(width: 6), Expanded(child: Text(complaint, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)))]),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Row 4: Details
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _iconText(Icons.calendar_today, '${_formatDate(d['visitDate'])} ${_safeString(d['visitTime'])}'),
                      _iconText(Icons.engineering, techName.isEmpty ? 'Unassigned' : techName),
                      if (address.isNotEmpty) _iconText(Icons.location_on, address),
                    ],
                  ),

                  const Divider(height: 24),

                  // Row 5: Smart Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _buildSmartActions(status, docId, d),
                  )
                ],
              ),
            ),
          );
        }
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
      ],
    );
  }

  List<Widget> _buildSmartActions(String status, String docId, Map<String, dynamic> data) {
    List<Widget> actions = [];

    // Always View
    actions.add(OutlinedButton.icon(
      icon: const Icon(Icons.visibility, size: 14),
      label: const Text('View'),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(
          companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, visitId: docId, visitData: data
      ))),
    ));
    actions.add(const SizedBox(width: 8));

    if (status == 'Scheduled' || status == 'New') {
      actions.add(ElevatedButton.icon(
        icon: const Icon(Icons.directions_car, size: 14),
        label: const Text('Start Travel'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
        onPressed: () => _startTravel(docId, data),
      ));
    } else if (status == 'Travel Started') {
      actions.add(ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow, size: 14),
        label: const Text('Start Service'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
        onPressed: () => _startService(docId, data),
      ));
    } else if (status == 'In Progress') {
      actions.add(ElevatedButton.icon(
        icon: const Icon(Icons.upload_file, size: 14),
        label: const Text('Upload Report'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        onPressed: () => _uploadReport(docId, data),
      ));
    } else if (status == 'Completed' || status == 'Resolved') {
      actions.add(ElevatedButton.icon(
        icon: const Icon(Icons.assignment_turned_in, size: 14),
        label: const Text('View Report'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Viewer opening...'))),
      ));
    }

    return actions;
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Scheduled': color = Colors.blue; break;
      case 'Travel Started': color = Colors.purple; break;
      case 'In Progress': color = Colors.orange; break;
      case 'Completed':
      case 'Resolved': color = Colors.green; break;
      case 'Cancelled': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority) {
      case 'Critical': color = Colors.red.shade700; break;
      case 'High': color = Colors.orange.shade700; break;
      case 'Medium': color = Colors.blue.shade700; break;
      case 'Low': color = Colors.grey.shade700; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(priority, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Visit No', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Request No', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Technician', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: docs.map((doc) {
            final d = doc.data();
            final tech = _safeString(d['assignedTechnician']) != '' ? _safeString(d['assignedTechnician']) : _safeString(d['engineerName']);
            return DataRow(
                cells: [
                  DataCell(Text(_safeString(d['visitNo']), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, visitId: doc.id, visitData: d)))),
                  DataCell(Text(_safeString(d['customerName']))),
                  DataCell(Text(_safeString(d['requestNumber']))),
                  DataCell(_buildPriorityBadge(_safeString(d['priority']))),
                  DataCell(Text(tech.isEmpty ? '-' : tech)),
                  DataCell(_buildStatusBadge(_safeString(d['visitStatus']))),
                  DataCell(Text('${_formatDate(d['visitDate'])} ${_safeString(d['visitTime'])}')),
                  DataCell(TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, visitId: doc.id, visitData: d))), child: const Text('View'))),
                ]
            );
          }).toList(),
        )
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
                  child: Text('Page $current of $pages', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    color: Colors.blue.withValues(alpha: 0.05),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3), style: BorderStyle.solid),
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