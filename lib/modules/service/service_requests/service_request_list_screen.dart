// FILE PATH: lib/modules/service/service_requests/service_request_list_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_service_request_screen.dart';
import 'service_request_details_screen.dart';
import '../service_visits/add_service_visit_screen.dart';
import '../service_visits/service_visit_details_screen.dart';
import '../service_technicians/service_technician_details_screen.dart';
import '../service_quotations/create_service_quotation_screen.dart';
import '../service_quotations/service_quotation_details_screen.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

double _safeDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
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

String _formatCurrency(double amount) {
  final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  return format.format(amount);
}

DateTime? _getLatestActivity(Map<String, dynamic> data) {
  final dates = [
    _extractDate(data['lastActivityAt']),
    _extractDate(data['updatedAt']),
    _extractDate(data['reportSubmittedAt']),
    _extractDate(data['completedAt']),
    _extractDate(data['visitStartedAt']),
    _extractDate(data['travelStartedAt']),
    _extractDate(data['closedAt']),
  ];
  dates.removeWhere((d) => d == null);
  if (dates.isEmpty) return null;
  dates.sort((a, b) => b!.compareTo(a!));
  return dates.first;
}

bool _checkOverdue(DateTime? createdAt, String priority, String status) {
  if (createdAt == null) return false;
  if (status == 'Closed' || status == 'Completed' || status == 'Resolved' || status == 'Cancelled') return false;

  final hours = DateTime.now().difference(createdAt).inHours;
  final p = priority.toLowerCase();

  if (p == 'critical' && hours > 24) return true;
  if (p == 'high' && hours > 48) return true;
  if (p == 'medium' && hours > 72) return true;
  if ((p == 'low' || p.isEmpty) && hours > 120) return true;

  return false;
}

// ==========================================
// MAIN SCREEN - SERVICE CONTROL TOWER
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
  String _viewMode = 'Card'; // 'Card', 'Table', 'Kanban', 'Timeline', 'Analytics'
  bool _isAdminOrCoordinator = false;

  // --- SELECTION STATE ---
  final Set<String> _selectedIds = {};

  // --- FILTERS STATE ---
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  String _categoryFilter = 'All';
  String _warrantyFilter = 'All';
  String _departmentFilter = 'All';
  DateTimeRange? _dateRangeFilter;

  final List<String> _requestStatuses = [
    'All', 'New', 'Assigned', 'Visit Created', 'In Progress', 'Report Submitted', 'Completed', 'Closed', 'Cancelled'
  ];

  final List<String> _priorities = ['All', 'Low', 'Medium', 'High', 'Critical'];
  final List<String> _warranties = ['All', 'Under Warranty', 'Out Of Warranty', 'AMC Active', 'AMC Expired'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermissions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
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
          _isAdminOrCoordinator = ['admin', 'superadmin', 'manager', 'coordinator', 'service manager', 'service coordinator'].contains(role);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _viewMode = prefs.getString('erp_request_tower_view_mode') ?? 'Card';
        });
      }
    } catch (_) {}
  }

  Future<void> _setViewMode(String mode) async {
    setState(() => _viewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('erp_request_tower_view_mode', _viewMode);
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _searchQuery != query.trim().toLowerCase()) {
        setState(() => _searchQuery = query.trim().toLowerCase());
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

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  bool get _hasActiveFilters => _statusFilter != 'All' ||
      _priorityFilter != 'All' ||
      _categoryFilter != 'All' ||
      _warrantyFilter != 'All' ||
      _departmentFilter != 'All' ||
      _dateRangeFilter != null;

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _priorityFilter = 'All';
      _categoryFilter = 'All';
      _warrantyFilter = 'All';
      _departmentFilter = 'All';
      _dateRangeFilter = null;
    });
  }

  // --- DATA FETCHING & FILTERING ---
  Stream<QuerySnapshot<Map<String, dynamic>>> _getRequestsStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_requests')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {

    final filtered = docs.where((doc) {
      final data = doc.data();

      final reqNo = _safeString(data['requestNumber']).toLowerCase();
      final customer = _safeString(data['customerName'] ?? data['clientName']).toLowerCase();
      final mobile = _safeString(data['mobileNumber'] ?? data['mobile']).toLowerCase();
      final priority = _safeString(data['priority']);
      final status = _safeString(data['status']);
      final category = _safeString(data['complaintCategory']);

      final serviceItems = data['serviceItems'] is List ? List<Map<String, dynamic>>.from(data['serviceItems']) : [];
      final firstMachine = serviceItems.isNotEmpty ? _safeString(serviceItems.first['itemName']).toLowerCase() : _safeString(data['machineModel'] ?? data['machineName']).toLowerCase();
      final serial = serviceItems.isNotEmpty ? _safeString(serviceItems.first['serialNumber']).toLowerCase() : _safeString(data['serialNumber'] ?? data['machineSerialNumber']).toLowerCase();
      final warr = _safeString(data['warrantyStatus']);

      final coordinator = _safeString(data['assignedToName']).toLowerCase();
      final manager = _safeString(data['assignedManagerName']).toLowerCase();
      final technician = _safeString(data['currentTechnicianName'] ?? data['assignedTechnicianName']).toLowerCase();
      final quoteNo = _safeString(data['quotationNumber']).toLowerCase();

      final createdAt = _extractDate(data['createdAt']);

      final normalizedStatus = (status == 'Resolved') ? 'Completed' : status;

      // Status & Property Filters
      if (_statusFilter != 'All' && normalizedStatus != _statusFilter) return false;
      if (_priorityFilter != 'All' && priority != _priorityFilter) return false;
      if (_categoryFilter != 'All' && category != _categoryFilter) return false;
      if (_warrantyFilter != 'All' && warr != _warrantyFilter) return false;

      // Date Range Filter
      if (_dateRangeFilter != null && createdAt != null) {
        if (createdAt.isBefore(_dateRangeFilter!.start) || createdAt.isAfter(_dateRangeFilter!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Universal Search
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = reqNo.contains(_searchQuery) ||
            customer.contains(_searchQuery) ||
            mobile.contains(_searchQuery) ||
            firstMachine.contains(_searchQuery) ||
            serial.contains(_searchQuery) ||
            coordinator.contains(_searchQuery) ||
            manager.contains(_searchQuery) ||
            technician.contains(_searchQuery) ||
            quoteNo.contains(_searchQuery);
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

  Map<String, dynamic> _calculateStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = 0, open = 0, assigned = 0, visitCreated = 0, inProgress = 0;
    int reportSub = 0, quoteCreated = 0, payPending = 0, dispPending = 0;
    int instPending = 0, completed = 0, closed = 0;

    // Cross module aggregate stats
    int totalVisits = 0;
    int totalQuotes = 0;
    int totalInvoices = 0;
    int totalDispatches = 0;
    int totalInstallations = 0;

    for (var doc in docs) {
      final data = doc.data();
      total++;
      final status = _safeString(data['status']);
      final pStatus = _safeString(data['paymentStatus']);
      final dStatus = _safeString(data['dispatchStatus']);
      final iStatus = _safeString(data['installationStatus']);
      final qCount = _safeInt(data['quotationCount']);

      if (status == 'New' || status == 'Open') open++;
      if (status == 'Assigned') assigned++;
      if (status == 'Visit Created') visitCreated++;
      if (status == 'In Progress') inProgress++;
      if (status == 'Report Submitted') reportSub++;
      if (status == 'Completed' || status == 'Resolved') completed++;
      if (status == 'Closed') closed++;

      if (qCount > 0) quoteCreated++;
      if (pStatus == 'Pending' || pStatus == 'Unpaid') payPending++;
      if (dStatus == 'Pending') dispPending++;
      if (iStatus == 'Pending') instPending++;

      totalVisits += _safeInt(data['openVisitsCount']) + _safeInt(data['completedVisitsCount']);
      totalQuotes += qCount;
      totalInvoices += _safeInt(data['invoiceCount']);
      totalDispatches += dStatus == 'Dispatched' ? 1 : 0;
      totalInstallations += iStatus == 'Completed' ? 1 : 0;
    }

    return {
      'Total': total,
      'Open': open,
      'Assigned': assigned,
      'VisitCreated': visitCreated,
      'InProgress': inProgress,
      'ReportSub': reportSub,
      'QuoteCreated': quoteCreated,
      'PayPending': payPending,
      'DispPending': dispPending,
      'InstPending': instPending,
      'Completed': completed,
      'Closed': closed,
      'TotalVisits': totalVisits,
      'TotalQuotes': totalQuotes,
      'TotalInvoices': totalInvoices,
      'TotalDispatches': totalDispatches,
      'TotalInstallations': totalInstallations,
    };
  }

  // --- ACTIONS ---

  void _navigateToCreate() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      currentUserName: widget.currentUserName,
    )));
  }

  void _navigateToDetails(String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      currentUserName: widget.currentUserName,
      requestId: docId,
      requestData: data,
    )));
  }

  void _navigateToEdit(String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      currentUserName: widget.currentUserName,
      existingDocId: docId,
      existingData: data,
    )));
  }

  Future<void> _closeRequest(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('service_requests')
          .doc(docId)
          .update({
        'status': 'Closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedByUid': widget.currentUserUid,
        'closedByName': widget.currentUserName,
        'lastActivity': 'Request Closed',
        'lastActivityAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnack('Request Closed Successfully');
    } catch (e) {
      _showSnack('Error closing request: $e', isError: true);
    }
  }

  void _softDelete(String docId) {
    FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_requests')
        .doc(docId)
        .update({'isDeleted': true})
        .then((_) => _showSnack('Request deleted successfully.'))
        .catchError((e) => _showSnack('Error deleting: $e', isError: true));
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // --- BULK ACTIONS ---

  void _bulkExportExcel() {
    _showSnack('Exporting ${_selectedIds.length} requests to Excel...');
    _clearSelection();
  }

  void _bulkAssign() {
    _showSnack('Bulk Assignment tool placeholder...');
    _clearSelection();
  }

  void _bulkUpdateStatus() {
    _showSnack('Bulk Status Update tool placeholder...');
    _clearSelection();
  }

  void _bulkDelete() {
    final batch = FirebaseFirestore.instance.batch();
    for (var id in _selectedIds) {
      final ref = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_requests').doc(id);
      batch.update(ref, {'isDeleted': true});
    }
    batch.commit().then((_) {
      _showSnack('${_selectedIds.length} requests deleted.');
      _clearSelection();
    }).catchError((e) => _showSnack('Error bulk deleting: $e', isError: true));
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Service Control Tower', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (_selectedIds.isNotEmpty) ...[
            Text('${_selectedIds.length} selected', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.table_view, color: Colors.green), onPressed: _bulkExportExcel, tooltip: 'Export Excel'),
            IconButton(icon: const Icon(Icons.assignment_ind, color: Colors.blue), onPressed: _bulkAssign, tooltip: 'Bulk Assign'),
            IconButton(icon: const Icon(Icons.edit_note, color: Colors.orange), onPressed: _bulkUpdateStatus, tooltip: 'Bulk Status Update'),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _bulkDelete, tooltip: 'Bulk Delete'),
            IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: _clearSelection, tooltip: 'Clear Selection'),
            const SizedBox(width: 16),
          ]
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'New Request',
        onPressed: _navigateToCreate,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final isWaiting = snapshot.connectionState == ConnectionState.waiting;
          final allDocs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyFilters(allDocs);
          final stats = _calculateStats(allDocs);

          return Column(
            children: [
              _buildHeader(stats, isWaiting),
              if (_hasActiveFilters) _buildActiveFiltersBar(),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: isWaiting
                    ? const Center(child: CircularProgressIndicator())
                    : filteredDocs.isEmpty
                    ? _buildEmptyState()
                    : _buildWorkspaceContent(filteredDocs, stats),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceContent(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, dynamic> stats) {
    switch (_viewMode) {
      case 'Table': return _buildTableView(docs);
      case 'Kanban': return _buildKanbanView(docs);
      case 'Timeline': return _buildTimelineView(docs);
      case 'Analytics': return _buildAnalyticsView(docs, stats);
      case 'Card':
      default: return _buildCardView(docs);
    }
  }

  Widget _buildHeader(Map<String, dynamic> stats, bool isWaiting) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Row 1: Request Status KPIs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKpiCard('Total Requests', stats['Total'].toString(), Icons.assignment, Colors.blueGrey),
                _buildKpiCard('Open / New', stats['Open'].toString(), Icons.fiber_new, Colors.blue),
                _buildKpiCard('Assigned', stats['Assigned'].toString(), Icons.assignment_ind, Colors.purple),
                _buildKpiCard('Visit Created', stats['VisitCreated'].toString(), Icons.directions_car, Colors.indigo),
                _buildKpiCard('In Progress', stats['InProgress'].toString(), Icons.build, Colors.orange),
                _buildKpiCard('Report Submitted', stats['ReportSub'].toString(), Icons.fact_check, Colors.teal),
                _buildKpiCard('Quote Created', stats['QuoteCreated'].toString(), Icons.request_quote, Colors.green),
                _buildKpiCard('Pay Pending', stats['PayPending'].toString(), Icons.payments, Colors.red),
                _buildKpiCard('Disp. Pending', stats['DispPending'].toString(), Icons.local_shipping, Colors.brown),
                _buildKpiCard('Inst. Pending', stats['InstPending'].toString(), Icons.handyman, Colors.deepOrange),
                _buildKpiCard('Completed', stats['Completed'].toString(), Icons.done_all, Colors.lightGreen),
                _buildKpiCard('Closed', stats['Closed'].toString(), Icons.lock, Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 2: Cross Module KPIs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMiniStatText(label: 'Total Visits:', value: stats['TotalVisits'].toString()),
                const SizedBox(width: 16),
                _buildMiniStatText(label: 'Total Quotes:', value: stats['TotalQuotes'].toString()),
                const SizedBox(width: 16),
                _buildMiniStatText(label: 'Total Invoices:', value: stats['TotalInvoices'].toString()),
                const SizedBox(width: 16),
                _buildMiniStatText(label: 'Total Dispatches:', value: stats['TotalDispatches'].toString()),
                const SizedBox(width: 16),
                _buildMiniStatText(label: 'Total Installs:', value: stats['TotalInstallations'].toString()),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search Request, Customer, Serial, Tech, Quote...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ) : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 40,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  icon: const Icon(Icons.filter_list, size: 20),
                  tooltip: 'Filters',
                  onPressed: _openFilterSheet,
                  color: _hasActiveFilters ? Colors.indigo : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: PopupMenuButton<String>(
                  icon: Icon(
                      _viewMode == 'Table' ? Icons.table_rows :
                      _viewMode == 'Kanban' ? Icons.view_kanban :
                      _viewMode == 'Analytics' ? Icons.analytics :
                      _viewMode == 'Timeline' ? Icons.timeline : Icons.grid_view,
                      size: 20
                  ),
                  tooltip: 'View Mode',
                  onSelected: _setViewMode,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Card', child: Text('Card View')),
                    const PopupMenuItem(value: 'Table', child: Text('Table View')),
                    const PopupMenuItem(value: 'Kanban', child: Text('Kanban View')),
                    const PopupMenuItem(value: 'Timeline', child: Text('Timeline View')),
                    const PopupMenuItem(value: 'Analytics', child: Text('Analytics View')),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniStatText({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 12, color: Colors.indigo.shade800, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, MaterialColor color) {
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
          Row(
            children: [
              Icon(icon, size: 14, color: color.shade700),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, color: color.shade800, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color.shade900), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                if (_statusFilter != 'All') _buildFilterChip('Status: $_statusFilter'),
                if (_priorityFilter != 'All') _buildFilterChip('Priority: $_priorityFilter'),
                if (_categoryFilter != 'All') _buildFilterChip('Category: $_categoryFilter'),
                if (_warrantyFilter != 'All') _buildFilterChip('Warranty: $_warrantyFilter'),
                if (_departmentFilter != 'All') _buildFilterChip('Dept: $_departmentFilter'),
                if (_dateRangeFilter != null) _buildFilterChip('Date: ${_formatDateOnly(_dateRangeFilter!.start)} - ${_formatDateOnly(_dateRangeFilter!.end)}'),
              ],
            ),
          ),
          TextButton(onPressed: _resetFilters, child: const Text('Clear', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.indigo.shade100)),
      child: Text(label, style: TextStyle(fontSize: 10, color: Colors.indigo.shade700, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No service requests found.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Try adjusting your search or filters.', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // --- WORKFLOW PIPELINE HELPER ---
  Widget _buildWorkflowPipeline(Map<String, dynamic> data) {
    final status = _safeString(data['status']);

    // Standard pipeline stages with full names
    final steps = ['Request', 'Visit', 'Report', 'Quotation', 'Payment', 'Dispatch', 'Install', 'Closed'];

    // Determine active index based on aggregate data heuristics
    int activeIndex = 0;

    if (status == 'Closed') {
      activeIndex = 7;
    } else if (status == 'Completed' || status == 'Resolved') {
      activeIndex = 6;
    } else if (_safeString(data['dispatchStatus']) == 'Dispatched') {
      activeIndex = 5;
    } else if (_safeString(data['paymentStatus']) == 'Paid') {
      activeIndex = 4;
    } else if (_safeInt(data['quotationCount']) > 0) {
      activeIndex = 3;
    } else if (status == 'Report Submitted') {
      activeIndex = 2;
    } else if (status == 'Visit Created' || status == 'In Progress') {
      activeIndex = 1;
    }

    if (status == 'Cancelled') {
      return Text('PIPELINE CANCELLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(steps.length, (index) {
          bool isActive = index <= activeIndex;
          bool isCurrent = index == activeIndex;

          return Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.indigo : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: isCurrent ? Border.all(color: Colors.orange, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              steps[index],
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey.shade600
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- LIST VIEWS ---

  Widget _buildCardView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) => _buildRequestCard(docs[i].id, docs[i].data()),
    );
  }

  Widget _buildRequestCard(String docId, Map<String, dynamic> data) {
    final reqNo = _safeString(data['requestNumber']);
    final customer = _safeString(data['customerName'] ?? data['clientName']);
    final priority = _safeString(data['priority']);
    final status = _safeString(data['status']);

    final serviceItems = data['serviceItems'] is List ? List<Map<String, dynamic>>.from(data['serviceItems']) : [];
    final firstMachine = serviceItems.isNotEmpty ? _safeString(serviceItems.first['itemName']) : _safeString(data['machineModel'] ?? data['machineName']);
    final machineCount = serviceItems.length;
    final machineDisplay = machineCount > 1 ? '$machineCount Machines' : (firstMachine.isEmpty ? 'Unknown Machine' : firstMachine);

    final ownerName = _safeString(data['assignedManagerName']).isNotEmpty
        ? _safeString(data['assignedManagerName'])
        : (_safeString(data['assignedCoordinatorName']).isNotEmpty
        ? _safeString(data['assignedCoordinatorName'])
        : _safeString(data['assignedToName']));

    final techName = _safeString(data['currentTechnicianName']).isNotEmpty
        ? _safeString(data['currentTechnicianName'])
        : _safeString(data['assignedTechnicianName'] ?? data['engineerName']);
    final techUid = _safeString(data['currentTechnicianUid'] ?? data['assignedTechnicianUid']);

    final qCount = _safeInt(data['quotationCount']);
    final latestQuoteAmt = _safeDouble(data['latestQuotationAmount']);
    final payStatus = _safeString(data['paymentStatus']).isNotEmpty ? _safeString(data['paymentStatus']) : 'N/A';
    final dispStatus = _safeString(data['dispatchStatus']).isNotEmpty ? _safeString(data['dispatchStatus']) : 'N/A';
    final instStatus = _safeString(data['installationStatus']).isNotEmpty ? _safeString(data['installationStatus']) : 'N/A';

    final openVisits = _safeInt(data['openVisitsCount']);
    final compVisits = _safeInt(data['completedVisitsCount']);
    final lastActivity = _getLatestActivity(data);

    final isSelected = _selectedIds.contains(docId);
    final isOverdue = _checkOverdue(_extractDate(data['createdAt']), priority, status);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.indigo : Colors.grey.shade200, width: isSelected ? 2 : 1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(docId),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.indigo.shade100)),
                      child: Text(reqNo.isNotEmpty ? reqNo : 'DRAFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo.shade900)),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(4)),
                        child: const Text('OVERDUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                      ),
                    ]
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_timeAgoStrict(lastActivity), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Last Activity', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),

            // Core Identity
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: Colors.blueGrey.shade50, child: const Icon(Icons.business, color: Colors.blueGrey, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.isNotEmpty ? customer : 'Unknown Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(machineDisplay, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.manage_accounts, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('Owner: ${ownerName.isEmpty ? 'N/A' : ownerName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.engineering, size: 14, color: Colors.indigo.shade600),
                            const SizedBox(width: 4),
                            Text('Tech: ${techName.isEmpty ? 'N/A' : techName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo.shade800)),
                          ],
                        ),
                      ],
                    )
                )
              ],
            ),
            const SizedBox(height: 16),

            // Pipeline & Badges
            _buildWorkflowPipeline(data),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(status),
                if (priority.isNotEmpty) _buildPriorityChip(priority),
                _buildMiniBadge('Visits: $openVisits Open / $compVisits Done', Colors.blueGrey),
                if (qCount > 0) _buildMiniBadge('Quotes: $qCount', Colors.green),
                if (latestQuoteAmt > 0) _buildMiniBadge('Val: ${_formatCurrency(latestQuoteAmt)}', Colors.teal),
                if (payStatus != 'N/A') _buildMiniBadge('Pay: $payStatus', Colors.orange),
                if (dispStatus != 'N/A') _buildMiniBadge('Disp: $dispStatus', Colors.brown),
                if (instStatus != 'N/A') _buildMiniBadge('Inst: $instStatus', Colors.purple),
              ],
            ),
            const Divider(height: 24),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _navigateToDetails(docId, data),
                      icon: const Icon(Icons.launch, size: 16),
                      label: const Text('Request 360'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    if (status != 'Closed' && status != 'Cancelled')
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
                          companyId: widget.companyId,
                          currentUserUid: widget.currentUserUid,
                          currentUserName: widget.currentUserName,
                          prefillRequestId: docId,
                        ))),
                        icon: const Icon(Icons.add_location_alt, size: 16, color: Colors.purple),
                        label: const Text('Visit', style: TextStyle(color: Colors.purple)),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    if (openVisits > 0 || compVisits > 0)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen( // Open 360 and default to Visits tab ideally, simplified to 360
                          companyId: widget.companyId,
                          currentUserUid: widget.currentUserUid,
                          currentUserName: widget.currentUserName,
                          requestId: docId,
                          requestData: data,
                        ))),
                        icon: const Icon(Icons.directions_car, size: 16, color: Colors.blue),
                        label: const Text('View Visit', style: TextStyle(color: Colors.blue)),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    if (status != 'Closed' && status != 'Cancelled')
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
                          companyId: widget.companyId,
                          currentUserUid: widget.currentUserUid,
                          serviceRequestSeed: {'id': docId, ...data},
                        ))),
                        icon: const Icon(Icons.request_quote, size: 16, color: Colors.green),
                        label: const Text('Create Quote', style: TextStyle(color: Colors.green)),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    if (qCount > 0)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(
                          companyId: widget.companyId,
                          currentUserUid: widget.currentUserUid,
                          currentUserName: widget.currentUserName,
                          requestId: docId,
                          requestData: data,
                        ))), // Direct them to 360 to see all quotes
                        icon: const Icon(Icons.receipt_long, size: 16, color: Colors.teal),
                        label: const Text('Quote 360', style: TextStyle(color: Colors.teal)),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    if (techUid.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceTechnicianDetailsScreen(
                          companyId: widget.companyId,
                          currentUserUid: widget.currentUserUid,
                          currentUserName: widget.currentUserName,
                          userId: techUid,
                          technicianData: {'id': techUid, 'name': techName},
                        ))),
                        icon: const Icon(Icons.engineering, size: 16, color: Colors.indigo),
                        label: const Text('Tech 360', style: TextStyle(color: Colors.indigo)),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    if (_isAdminOrCoordinator && status != 'Closed' && status != 'Cancelled')
                      FilledButton.icon(
                        onPressed: () => _closeRequest(docId),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Close'),
                        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: Colors.green),
                      )
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') _navigateToEdit(docId, data);
                    if (val == 'quote') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
                        companyId: widget.companyId,
                        currentUserUid: widget.currentUserUid,
                        serviceRequestSeed: {'id': docId, ...data},
                      )));
                    }
                    if (val == 'close') _closeRequest(docId);
                    if (val == 'del') _softDelete(docId);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Request')])),
                    const PopupMenuItem(value: 'quote', child: Row(children: [Icon(Icons.request_quote, size: 18), SizedBox(width: 8), Text('Create Quotation')])),
                    if (status != 'Closed') const PopupMenuItem(value: 'close', child: Row(children: [Icon(Icons.done_all, size: 18, color: Colors.green), SizedBox(width: 8), Text('Close Request', style: TextStyle(color: Colors.green))])),
                    const PopupMenuItem(value: 'del', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                )
              ],
            )
          ],
        ),
      ),
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
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    SizedBox(width: 200, child: Text('Request No / Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                    SizedBox(width: 160, child: Text('Machine', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                    SizedBox(width: 140, child: Text('Priority & Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                    SizedBox(width: 140, child: Text('Owner / Tech', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                    SizedBox(width: 120, child: Text('Last Activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                    SizedBox(width: 120, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              ...docs.map((doc) => _buildRequestTableRow(doc)),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTableRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final reqNo = _safeString(data['requestNumber']);
    final custName = _safeString(data['customerName']);
    final status = _safeString(data['status']);
    final priority = _safeString(data['priority']);

    // Separation of Owner vs Technician in Table View
    final ownerName = _safeString(data['assignedManagerName']).isNotEmpty
        ? _safeString(data['assignedManagerName'])
        : (_safeString(data['assignedCoordinatorName']).isNotEmpty
        ? _safeString(data['assignedCoordinatorName'])
        : _safeString(data['assignedToName']));

    final techName = _safeString(data['currentTechnicianName']).isNotEmpty
        ? _safeString(data['currentTechnicianName'])
        : _safeString(data['assignedTechnicianName'] ?? data['engineerName']);

    final latestActivityDate = _getLatestActivity(data);

    final serviceItems = data['serviceItems'] is List ? List<Map<String, dynamic>>.from(data['serviceItems']) : [];
    final firstMachine = serviceItems.isNotEmpty ? _safeString(serviceItems.first['itemName']) : _safeString(data['machineModel'] ?? data['machineName']);
    final machineCount = serviceItems.length;
    final machineDisplayString = machineCount > 1 ? '$machineCount Machines' : (firstMachine.isEmpty ? '-' : firstMachine);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        requestId: doc.id,
        requestData: data,
      ))),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reqNo.isNotEmpty ? reqNo : '-', style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(custName.isNotEmpty ? custName : '(Unknown)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: Text(machineDisplayString, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(status),
                  const SizedBox(height: 6),
                  if (priority.isNotEmpty) _buildPriorityChip(priority),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (techName.isNotEmpty) Text('Tech: $techName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (techName.isNotEmpty && ownerName.isNotEmpty) const SizedBox(height: 2),
                  if (ownerName.isNotEmpty) Text('Owner: $ownerName', style: TextStyle(fontSize: 11, color: techName.isNotEmpty ? Colors.grey.shade600 : Colors.black87, fontWeight: techName.isNotEmpty ? FontWeight.normal : FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (techName.isEmpty && ownerName.isEmpty) const Text('-', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            SizedBox(width: 120, child: Text(_timeAgoStrict(latestActivityDate), style: const TextStyle(fontSize: 13))),
            SizedBox(
                width: 120,
                child: Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.blueGrey,
                    ),
                    icon: const Icon(Icons.launch, size: 14),
                    label: const Text('Open', style: TextStyle(fontSize: 11)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(
                      companyId: widget.companyId,
                      currentUserUid: widget.currentUserUid,
                      currentUserName: widget.currentUserName,
                      requestId: doc.id,
                      requestData: data,
                    ))),
                  ),
                )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final columns = ['New', 'Assigned', 'Visit Created', 'In Progress', 'Report Submitted', 'Completed', 'Closed'];

    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> board = {
      for (var c in columns) c: []
    };

    for (var doc in docs) {
      String st = _safeString(doc.data()['status']);
      if (st == 'Resolved') st = 'Completed';
      if (!columns.contains(st)) st = 'New'; // Fallback
      board[st]?.add(doc);
    }

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columns.map((colName) {
            final colDocs = board[colName]!;
            return Container(
              width: 300,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(colName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: Text('${colDocs.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                      child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          itemCount: colDocs.length,
                          itemBuilder: (ctx, i) {
                            final data = colDocs[i].data();
                            return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: InkWell(
                                  onTap: () => _navigateToDetails(colDocs[i].id, data),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(_safeString(data['requestNumber']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                                            _buildPriorityChip(_safeString(data['priority'])),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(_safeString(data['customerName']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(_safeString(data['machineModel'] ?? data['machineName']), style: TextStyle(color: Colors.grey.shade600, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 8),
                                        Text(_timeAgoStrict(_extractDate(data['createdAt'])), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                )
                            );
                          }
                      )
                  )
                ],
              ),
            );
          }).toList(),
        )
    );
  }

  Widget _buildTimelineView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return _buildEmptyState();

    // Group by Month-Year
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
    for (var doc in docs) {
      final date = _extractDate(doc.data()['createdAt']);
      final key = date != null ? DateFormat('MMMM yyyy').format(date) : 'Unknown Date';
      grouped.putIfAbsent(key, () => []).add(doc);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: grouped.keys.length,
      itemBuilder: (ctx, index) {
        String month = grouped.keys.elementAt(index);
        List<QueryDocumentSnapshot<Map<String, dynamic>>> monthDocs = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(month, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
            ),
            const SizedBox(height: 16),
            ...monthDocs.map((doc) {
              final data = doc.data();
              final date = _extractDate(data['createdAt']);
              final reqNo = _safeString(data['requestNumber']);
              final customer = _safeString(data['clientName'] ?? data['customerName']);
              final status = _safeString(data['status']);
              final priority = _safeString(data['priority']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(date != null ? DateFormat('dd MMM').format(date) : '-', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    ),
                    Column(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: _getStatusColor(status))),
                        Container(width: 2, height: 60, color: Colors.grey.shade300),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _navigateToDetails(doc.id, data),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(reqNo.isNotEmpty ? reqNo : 'Draft', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  _buildPriorityChip(priority),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(customer, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              const SizedBox(height: 8),
                              _buildStatusChip(status),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              );
            }).toList()
          ],
        );
      },
    );
  }

  // --- ANALYTICS DASHBOARDS ---

  Widget _buildAnalyticsView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, dynamic> stats) {
    if (docs.isEmpty) return _buildEmptyState();

    // Calculate Aging
    int age0to2 = 0;
    int age3to5 = 0;
    int ageOver5 = 0;

    // Calculate SLAs
    int slaBreached = 0;
    int slaCompliant = 0;

    // Calculate Workload
    Map<String, int> workload = {};

    // Calculate Escalations
    List<QueryDocumentSnapshot<Map<String, dynamic>>> escalations = [];

    final now = DateTime.now();

    for (var doc in docs) {
      final data = doc.data();
      final status = _safeString(data['status']);
      final priority = _safeString(data['priority']);
      final createdAt = _extractDate(data['createdAt']);

      if (status != 'Closed' && status != 'Completed' && status != 'Resolved' && status != 'Cancelled' && createdAt != null) {
        final days = now.difference(createdAt).inDays;
        if (days <= 2) age0to2++;
        else if (days <= 5) age3to5++;
        else ageOver5++;

        // Workload
        final techName = _safeString(data['currentTechnicianName']).isNotEmpty
            ? _safeString(data['currentTechnicianName'])
            : _safeString(data['assignedTechnicianName'] ?? data['engineerName']);

        if (techName.isNotEmpty) {
          workload[techName] = (workload[techName] ?? 0) + 1;
        } else {
          workload['Unassigned'] = (workload['Unassigned'] ?? 0) + 1;
        }

        // SLA Breach (Simple logic: Critical > 1 day, High > 2 days, Medium > 3 days, Low > 5 days)
        bool isBreached = false;
        if (priority == 'Critical' && days > 1) isBreached = true;
        if (priority == 'High' && days > 2) isBreached = true;
        if (priority == 'Medium' && days > 3) isBreached = true;
        if ((priority == 'Low' || priority.isEmpty) && days > 5) isBreached = true;

        if (isBreached) {
          slaBreached++;
          escalations.add(doc);
        } else {
          slaCompliant++;
        }
      }
    }

    // Sort Workload
    final sortedWorkload = workload.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Sort Escalations
    escalations.sort((a, b) {
      final aDate = _extractDate(a.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _extractDate(b.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate); // Oldest first
    });

    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Analytics & Dashboards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 24),

              LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isWide ? 1 : 0,
                          child: _buildAgingDashboard(age0to2, age3to5, ageOver5),
                        ),
                        SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                        Expanded(
                          flex: isWide ? 1 : 0,
                          child: _buildSLADashboard(slaCompliant, slaBreached),
                        )
                      ],
                    );
                  }
              ),

              const SizedBox(height: 24),

              LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isWide ? 1 : 0,
                          child: _buildWorkloadDashboard(sortedWorkload),
                        ),
                        SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                        Expanded(
                          flex: isWide ? 1 : 0,
                          child: _buildEscalationDashboard(escalations),
                        )
                      ],
                    );
                  }
              ),
            ]
        )
    );
  }

  Widget _buildAgingDashboard(int age0to2, int age3to5, int ageOver5) {
    int total = age0to2 + age3to5 + ageOver5;
    if (total == 0) total = 1; // Prevent division by zero

    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
                children: [
                  Icon(Icons.hourglass_bottom, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Ticket Aging (Open)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]
            ),
            const SizedBox(height: 24),
            _buildBarChartRow('0 - 2 Days', age0to2, total, Colors.green),
            const SizedBox(height: 12),
            _buildBarChartRow('3 - 5 Days', age3to5, total, Colors.orange),
            const SizedBox(height: 12),
            _buildBarChartRow('> 5 Days', ageOver5, total, Colors.red),
          ],
        )
    );
  }

  Widget _buildSLADashboard(int compliant, int breached) {
    int total = compliant + breached;
    if (total == 0) total = 1;

    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
                children: [
                  Icon(Icons.gavel, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('SLA Performance (Open)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]
            ),
            const SizedBox(height: 24),
            _buildBarChartRow('Compliant', compliant, total, Colors.teal),
            const SizedBox(height: 12),
            _buildBarChartRow('Breached', breached, total, Colors.red.shade700),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Open Monitored: ${compliant + breached}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('Compliance: ${((compliant / total) * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
              ],
            )
          ],
        )
    );
  }

  Widget _buildBarChartRow(String label, int value, int total, Color color) {
    double percentage = value / total;
    return Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(
              child: Stack(
                children: [
                  Container(height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
                  FractionallySizedBox(
                    widthFactor: percentage,
                    child: Container(height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10))),
                  )
                ],
              )
          ),
          SizedBox(width: 40, child: Text(value.toString(), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
        ]
    );
  }

  Widget _buildWorkloadDashboard(List<MapEntry<String, int>> workload) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
                children: [
                  Icon(Icons.engineering, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Technician Workload (Open)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]
            ),
            const SizedBox(height: 16),
            if (workload.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('No active assignments.'))
            else
              ...workload.take(10).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 12, backgroundColor: Colors.blue.shade50, child: Text(e.key[0].toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.blue.shade800))),
                        const SizedBox(width: 12),
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Text('${e.value} Tickets', style: const TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ))
          ],
        )
    );
  }

  Widget _buildEscalationDashboard(List<QueryDocumentSnapshot<Map<String, dynamic>>> escalations) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Escalated & Breached Tickets (${escalations.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                ]
            ),
            const SizedBox(height: 16),
            if (escalations.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('No escalations detected. Great job!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
            else
              ...escalations.take(5).map((doc) {
                final data = doc.data();
                final reqNo = _safeString(data['requestNumber']);
                final customer = _safeString(data['customerName'] ?? data['clientName']);
                final date = _extractDate(data['createdAt']);

                return InkWell(
                  onTap: () => _navigateToDetails(doc.id, data),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reqNo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                            Text(customer, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_timeAgoStrict(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Overdue', style: TextStyle(fontSize: 10, color: Colors.red)),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              })
          ],
        )
    );
  }

  // --- HELPERS ---

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildStatusChip(String status) {
    final Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    final Color color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New': return Colors.blue;
      case 'Assigned': return Colors.purple;
      case 'Visit Created': return Colors.indigo;
      case 'In Progress': return Colors.orange;
      case 'Report Submitted': return Colors.teal;
      case 'Completed':
      case 'Resolved': return Colors.green;
      case 'Closed': return Colors.grey;
      case 'Cancelled': return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical': return Colors.red.shade700;
      case 'High': return Colors.orange.shade700;
      case 'Medium': return Colors.blue.shade700;
      case 'Low': return Colors.grey.shade700;
      default: return Colors.grey;
    }
  }

  // --- FILTERS SHEET ---
  Future<void> _openFilterSheet() async {
    String tStatus = _statusFilter;
    String tPriority = _priorityFilter;
    String tCategory = _categoryFilter;
    String tWarranty = _warrantyFilter;
    String tDept = _departmentFilter;
    DateTimeRange? tDateRange = _dateRangeFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setSheetState) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),

                  // Date Range Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: tDateRange,
                      );
                      if (picked != null) {
                        setSheetState(() => tDateRange = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date Range', isDense: true, border: OutlineInputBorder()),
                      child: Text(tDateRange == null ? 'All Time' : '${_formatDateOnly(tDateRange!.start)} - ${_formatDateOnly(tDateRange!.end)}'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: tStatus,
                    decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                    items: _requestStatuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => tStatus = v ?? 'All',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tPriority,
                    decoration: const InputDecoration(labelText: 'Priority', isDense: true, border: OutlineInputBorder()),
                    items: _priorities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => tPriority = v ?? 'All',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tWarranty,
                    decoration: const InputDecoration(labelText: 'Warranty Status', isDense: true, border: OutlineInputBorder()),
                    items: _warranties.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => tWarranty = v ?? 'All',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tStatus = 'All';
                              tPriority = 'All';
                              tCategory = 'All';
                              tWarranty = 'All';
                              tDept = 'All';
                              tDateRange = null;
                            });
                          },
                          child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _statusFilter = tStatus;
                              _priorityFilter = tPriority;
                              _categoryFilter = tCategory;
                              _warrantyFilter = tWarranty;
                              _departmentFilter = tDept;
                              _dateRangeFilter = tDateRange;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// SHARED ENTERPRISE UI COMPONENTS
// ==========================================

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStatText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 13, color: Colors.indigo.shade800, fontWeight: FontWeight.w800)),
      ],
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
                      radius: 36,
                      backgroundColor: Colors.indigo.shade50,
                      child: Icon(
                        hasSearch ? Icons.search_off : Icons.support_agent_outlined,
                        size: 36,
                        color: Colors.indigo.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      hasSearch ? 'No matching service requests found' : 'No service requests found',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasSearch ? 'Try changing the search text or filter.' : 'Click the button below to log your first service request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (hasSearch)
                      FilledButton.tonal(
                          onPressed: onReset,
                          child: const Text('Clear Search & Filters', style: TextStyle(fontWeight: FontWeight.bold))
                      ),
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