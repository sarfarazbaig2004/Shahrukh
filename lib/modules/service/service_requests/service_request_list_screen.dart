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
// CACHED ENTERPRISE STYLES (ZOHO / CRM STYLE)
// ==========================================
const _kCompanyNameStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B));
const _kSecondaryTextStyle = TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500);
const _kActivityTextStyle = TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500);
const _kTableTextStyle = TextStyle(fontSize: 13, color: Color(0xFF1E293B));
const _kTableMutedStyle = TextStyle(fontSize: 12, color: Color(0xFF64748B));
const _kTableHeaderStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155));

final _kRowBorder = Border(bottom: BorderSide(color: Colors.grey.shade200));
final _kRowDecoration = BoxDecoration(color: Colors.white, border: _kRowBorder);
final _kSelectedRowDecoration = BoxDecoration(color: Colors.blue.shade50.withOpacity(0.3), border: _kRowBorder);

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
// MAIN SCREEN - SERVICE MODULE
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
      appBar: AppBar(elevation: 0, toolbarHeight: 6, automaticallyImplyLeading: false, backgroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New Request',
        onPressed: _navigateToCreate,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              _buildHeader(stats),
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

  Widget _buildHeader(Map<String, dynamic> stats) {
    return Container(
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
                  hintText: 'Search Request, Customer, Serial...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.trim().isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 17), onPressed: () { _searchController.clear(); _onSearchChanged(''); }),
                  isDense: true, filled: true, fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontSize: 13),
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
                      onTap: () => _openFilterSheet(stats),
                      child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade800),
                            if (_hasActiveFilters) Positioned(right: 8, top: 8, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle))),
                          ]
                      )
                  )
              )
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: PopupMenuButton<String>(
              icon: Icon(
                  _viewMode == 'Table' ? Icons.table_rows :
                  _viewMode == 'Kanban' ? Icons.view_kanban :
                  _viewMode == 'Analytics' ? Icons.analytics :
                  _viewMode == 'Timeline' ? Icons.timeline : Icons.grid_view,
                  size: 20, color: Colors.grey.shade700
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
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(width: 16),
            Text('${_selectedIds.length} selected', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.table_view, color: Colors.green, size: 20), onPressed: _bulkExportExcel, tooltip: 'Export Excel'),
                    IconButton(icon: const Icon(Icons.assignment_ind, color: Colors.blue, size: 20), onPressed: _bulkAssign, tooltip: 'Bulk Assign'),
                    IconButton(icon: const Icon(Icons.edit_note, color: Colors.orange, size: 20), onPressed: _bulkUpdateStatus, tooltip: 'Bulk Status Update'),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: _bulkDelete, tooltip: 'Bulk Delete'),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: _clearSelection, tooltip: 'Clear Selection'),
                  ],
                ),
              ),
            )
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
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)),
      child: Text(label, style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
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

  // --- WORKFLOW PIPELINE & METRICS HELPER ---
  Widget _buildWorkflowAndMetrics(Map<String, dynamic> data, List<String> metricsList) {
    final status = _safeString(data['status']);
    final steps = ['Req', 'Visit', 'Rep', 'Quote', 'Pay', 'Disp', 'Inst', 'Cls'];
    int activeIndex = 0;

    if (status == 'Closed') activeIndex = 7;
    else if (status == 'Completed' || status == 'Resolved') activeIndex = 6;
    else if (_safeString(data['dispatchStatus']) == 'Dispatched') activeIndex = 5;
    else if (_safeString(data['paymentStatus']) == 'Paid') activeIndex = 4;
    else if (_safeInt(data['quotationCount']) > 0) activeIndex = 3;
    else if (status == 'Report Submitted') activeIndex = 2;
    else if (status == 'Visit Created' || status == 'In Progress') activeIndex = 1;

    List<Widget> children = [];

    if (status == 'Cancelled') {
      children.add(Text('CANCELLED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)));
    } else {
      for (int i = 0; i < steps.length; i++) {
        bool isCompleted = i <= activeIndex;
        children.add(Text(
            '${steps[i]}${isCompleted ? '✓' : '○'}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
                color: isCompleted ? Colors.green.shade700 : Colors.grey.shade400
            )
        ));

        // Add subtle separator
        if (i < steps.length - 1) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(Icons.chevron_right, size: 10, color: Colors.grey.shade300),
          ));
        }
      }
    }

    if (metricsList.isNotEmpty) {
      children.add(Container(
          width: 3, height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)
      ));
      children.add(Text(
          metricsList.join('  •  '),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)
      ));
    }

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        )
    );
  }

  // --- LIST VIEWS ---

  Widget _buildCardView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
      itemCount: docs.length,
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

    // OWNERSHIP
    final salesOwner = _safeString(data['salesPersonName']).isNotEmpty
        ? _safeString(data['salesPersonName'])
        : _safeString(data['customerOwnerName']).isNotEmpty
        ? _safeString(data['customerOwnerName'])
        : _safeString(data['recordOwnerName']);

    final serviceOwner = _safeString(data['assignedManagerName']).isNotEmpty
        ? _safeString(data['assignedManagerName'])
        : (_safeString(data['assignedCoordinatorName']).isNotEmpty
        ? _safeString(data['assignedCoordinatorName'])
        : _safeString(data['assignedToName']));

    final techName = _safeString(data['currentTechnicianName']).isNotEmpty
        ? _safeString(data['currentTechnicianName'])
        : _safeString(data['assignedTechnicianName'] ?? data['engineerName']);
    final techUid = _safeString(data['currentTechnicianUid'] ?? data['assignedTechnicianUid']);

    final createdBy = _safeString(data['createdByName'] ?? data['createdBy']);
    final createdDate = _formatDateOnly(_extractDate(data['createdAt']));

    // METRICS
    final qCount = _safeInt(data['quotationCount']);
    final latestQuoteAmt = _safeDouble(data['latestQuotationAmount']);
    final payStatus = _safeString(data['paymentStatus']);
    final dispStatus = _safeString(data['dispatchStatus']);
    final instStatus = _safeString(data['installationStatus']);

    final openVisits = _safeInt(data['openVisitsCount']);
    final compVisits = _safeInt(data['completedVisitsCount']);
    final lastActivity = _getLatestActivity(data);

    final isSelected = _selectedIds.contains(docId);
    final isOverdue = _checkOverdue(_extractDate(data['createdAt']), priority, status);

    List<String> metricsList = [];
    metricsList.add('V:$openVisits/$compVisits');
    if (qCount > 0) metricsList.add('Q:$qCount');
    if (latestQuoteAmt > 0) metricsList.add('₹${_formatCurrency(latestQuoteAmt).replaceAll('₹', '').trim()}');
    if (payStatus.isNotEmpty && payStatus != 'N/A') metricsList.add('Pay:$payStatus');
    if (dispStatus.isNotEmpty && dispStatus != 'N/A') metricsList.add('Disp:$dispStatus');
    if (instStatus.isNotEmpty && instStatus != 'N/A') metricsList.add('Inst:$instStatus');
    if (priority.isNotEmpty && priority != 'N/A') metricsList.add('Pri:$priority');

    return InkWell(
        onTap: () => _navigateToDetails(docId, data),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: isSelected ? _kSelectedRowDecoration : _kRowDecoration,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        visualDensity: VisualDensity.compact,
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(docId),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TOP ROW
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(reqNo.isNotEmpty ? reqNo : 'DRAFT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.blue.shade800, letterSpacing: 0.3)),
                                  const SizedBox(width: 8),
                                  Text('•  ${_timeAgoStrict(lastActivity)}', style: _kActivityTextStyle),
                                  if (isOverdue) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade100)),
                                      child: Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                    ),
                                  ],
                                ]
                            ),
                            const SizedBox(height: 4),

                            // CUSTOMER & MACHINE
                            Text(customer.isNotEmpty ? customer : 'Unknown Customer', style: _kCompanyNameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 1),
                            Text(machineDisplay, style: _kSecondaryTextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),

                            // OWNERSHIP
                            Text(
                                'Sales: ${salesOwner.isEmpty ? 'N/A' : salesOwner}  •  Service: ${serviceOwner.isEmpty ? 'N/A' : serviceOwner}  •  Tech: ${techName.isEmpty ? 'N/A' : techName}',
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis
                            ),
                            const SizedBox(height: 6),

                            // WORKFLOW + METRICS INTEGRATED
                            _buildWorkflowAndMetrics(data, metricsList),
                          ]
                      )
                  ),
                  const SizedBox(width: 12),
                  // RIGHT COLUMN STATUS PANEL (COMPRESSED)
                  SizedBox(
                    width: 85,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                              width: 24, height: 24,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                                onSelected: (val) {
                                  if (val == '360') _navigateToDetails(docId, data);
                                  if (val == 'edit') _navigateToEdit(docId, data);
                                  if (val == 'create_visit') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, prefillRequestId: docId)));
                                  }
                                  if (val == 'view_visit') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, requestId: docId, requestData: data)));
                                  }
                                  if (val == 'create_quote') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(companyId: widget.companyId, currentUserUid: widget.currentUserUid, serviceRequestSeed: {'id': docId, ...data})));
                                  }
                                  if (val == 'quote_360') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, requestId: docId, requestData: data)));
                                  }
                                  if (val == 'tech_360') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceTechnicianDetailsScreen(companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, userId: techUid, technicianData: {'id': techUid, 'name': techName})));
                                  }
                                  if (val == 'close') _closeRequest(docId);
                                  if (val == 'del') _softDelete(docId);
                                  if (val == 'export') _showSnack('Exporting request $reqNo to Excel...');
                                  if (val == 'assign') _showSnack('Assign tool placeholder...');
                                  if (val == 'status') _showSnack('Status Update tool placeholder...');
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: '360', child: Text('Open Request 360')),
                                  const PopupMenuItem(value: 'edit', child: Text('Edit Request')),
                                  if (status != 'Closed' && status != 'Cancelled')
                                    const PopupMenuItem(value: 'create_visit', child: Text('Create Visit')),
                                  if (openVisits > 0 || compVisits > 0)
                                    const PopupMenuItem(value: 'view_visit', child: Text('View Visit')),
                                  if (status != 'Closed' && status != 'Cancelled')
                                    const PopupMenuItem(value: 'create_quote', child: Text('Create Quotation')),
                                  if (qCount > 0)
                                    const PopupMenuItem(value: 'quote_360', child: Text('Quote 360')),
                                  if (techUid.isNotEmpty)
                                    const PopupMenuItem(value: 'tech_360', child: Text('Technician 360')),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'export', child: Text('Export')),
                                  const PopupMenuItem(value: 'assign', child: Text('Assign')),
                                  const PopupMenuItem(value: 'status', child: Text('Status Update')),
                                  const PopupMenuDivider(),
                                  if (_isAdminOrCoordinator && status != 'Closed' && status != 'Cancelled')
                                    const PopupMenuItem(value: 'close', child: Text('Close Request', style: TextStyle(color: Colors.green))),
                                  const PopupMenuItem(value: 'del', child: Text('Delete Request', style: TextStyle(color: Colors.red))),
                                ],
                              )
                          ),
                          const SizedBox(height: 4),
                          Text('STATUS', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                          Text(status.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: _getStatusColor(status)), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('CREATED BY', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                          Text(createdBy.isNotEmpty ? createdBy : 'System', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800, fontWeight: FontWeight.w600), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('CREATED', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                          Text(createdDate.isNotEmpty && createdDate != '-' ? createdDate : 'N/A', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                        ]
                    ),
                  )
                ]
            )
        )
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    SizedBox(width: 200, child: Text('Request No / Customer', style: _kTableHeaderStyle)),
                    SizedBox(width: 150, child: Text('Machine', style: _kTableHeaderStyle)),
                    SizedBox(width: 130, child: Text('Priority & Status', style: _kTableHeaderStyle)),
                    SizedBox(width: 150, child: Text('Sales / Service / Tech', style: _kTableHeaderStyle)),
                    SizedBox(width: 120, child: Text('Last Activity', style: _kTableHeaderStyle)),
                    SizedBox(width: 80, child: Text('Action', style: _kTableHeaderStyle, textAlign: TextAlign.center)),
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

    // OWNERSHIP FALLBACK LOGIC
    final salesOwner = _safeString(data['salesPersonName']).isNotEmpty
        ? _safeString(data['salesPersonName'])
        : _safeString(data['customerOwnerName']).isNotEmpty
        ? _safeString(data['customerOwnerName'])
        : _safeString(data['recordOwnerName']);

    final serviceOwner = _safeString(data['assignedManagerName']).isNotEmpty
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
      onTap: () => _navigateToDetails(doc.id, data),
      child: Container(
        decoration: _kRowDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(reqNo.isNotEmpty ? reqNo : '-', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(custName.isNotEmpty ? custName : '(Unknown)', style: _kTableTextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              child: Container(
                  alignment: Alignment.centerLeft,
                  child: Text(machineDisplayString, style: _kTableMutedStyle, maxLines: 2, overflow: TextOverflow.ellipsis)
              ),
            ),
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status))),
                  const SizedBox(height: 4),
                  if (priority.isNotEmpty) Text(priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPriorityColor(priority))),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (techName.isNotEmpty) Text('Tech: $techName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (serviceOwner.isNotEmpty) Text('Svc: $serviceOwner', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (salesOwner.isNotEmpty) Text('Sales: $salesOwner', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (techName.isEmpty && serviceOwner.isEmpty && salesOwner.isEmpty) const Text('-', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
                width: 120,
                child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(_timeAgoStrict(latestActivityDate), style: _kTableMutedStyle)
                )
            ),
            SizedBox(
                width: 80,
                child: Center(
                  child: IconButton(
                    icon: Icon(Icons.launch, size: 18, color: Colors.blueGrey.shade600),
                    tooltip: 'Open',
                    onPressed: () => _navigateToDetails(doc.id, data),
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
              width: 280,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
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
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: Colors.grey.shade300)),
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
                                            Text(_safeString(data['requestNumber']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade700)),
                                            Text(_safeString(data['priority']).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPriorityColor(_safeString(data['priority'])))),
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
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(month, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
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
                                  Text(priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPriorityColor(priority))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(customer, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status))),
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
              const Text('Analytics & Dashboards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
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
            _buildBarChartRow('0 - 2 Days', age0to2, total, Colors.blueGrey.shade600),
            const SizedBox(height: 12),
            _buildBarChartRow('3 - 5 Days', age3to5, total, Colors.blueGrey.shade700),
            const SizedBox(height: 12),
            _buildBarChartRow('> 5 Days', ageOver5, total, Colors.grey.shade800),
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
                  Icon(Icons.gavel, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('SLA Performance (Open)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]
            ),
            const SizedBox(height: 24),
            _buildBarChartRow('Compliant', compliant, total, Colors.blue.shade600),
            const SizedBox(height: 12),
            _buildBarChartRow('Breached', breached, total, Colors.grey.shade800),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Open Monitored: ${compliant + breached}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('Compliance: ${((compliant / total) * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                children: [
                  const Icon(Icons.warning, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Escalated & Breached Tickets (${escalations.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                ]
            ),
            const SizedBox(height: 16),
            if (escalations.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('No escalations detected. Great job!', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)))
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
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reqNo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
                            Text(customer, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_timeAgoStrict(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Overdue', style: TextStyle(fontSize: 10, color: Colors.grey.shade800)),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New': return Colors.blue.shade600;
      case 'Assigned': return Colors.blue.shade700;
      case 'Visit Created': return Colors.blue.shade800;
      case 'In Progress': return Colors.blue.shade900;
      case 'Report Submitted': return Colors.blueGrey.shade600;
      case 'Completed':
      case 'Resolved': return Colors.blueGrey.shade700;
      case 'Closed': return Colors.grey.shade600;
      case 'Cancelled': return Colors.grey.shade800;
      default: return Colors.grey.shade500;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical': return Colors.red.shade700;
      case 'High': return Colors.orange.shade700;
      case 'Medium': return Colors.blue.shade600;
      case 'Low': return Colors.grey.shade600;
      default: return Colors.grey.shade500;
    }
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

  // --- FILTERS SHEET ---
  Future<void> _openFilterSheet(Map<String, dynamic> stats) async {
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
                  const Text('Request Stats', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _buildStatChip('Total', stats['Total'], Colors.blueGrey.shade800),
                      _buildStatChip('Open', stats['Open'], Colors.blue.shade700),
                      _buildStatChip('Assigned', stats['Assigned'], Colors.blue.shade600),
                      _buildStatChip('In Progress', stats['InProgress'], Colors.blue.shade500),
                      _buildStatChip('Visit Created', stats['VisitCreated'], Colors.blueGrey.shade600),
                      _buildStatChip('Reports', stats['ReportSub'], Colors.blueGrey.shade500),
                      _buildStatChip('Quotes', stats['QuoteCreated'], Colors.blueGrey.shade400),
                      _buildStatChip('Pay Pending', stats['PayPending'], Colors.grey.shade700),
                      _buildStatChip('Completed', stats['Completed'], Colors.grey.shade600),
                      _buildStatChip('Closed', stats['Closed'], Colors.grey.shade500),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('Cross Module Stats', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _buildStatChip('Total Visits', stats['TotalVisits'], Colors.blueGrey.shade700),
                      _buildStatChip('Total Quotes', stats['TotalQuotes'], Colors.blueGrey.shade600),
                      _buildStatChip('Invoices', stats['TotalInvoices'], Colors.blue.shade600),
                      _buildStatChip('Dispatches', stats['TotalDispatches'], Colors.grey.shade700),
                      _buildStatChip('Installs', stats['TotalInstallations'], Colors.grey.shade600),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),

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