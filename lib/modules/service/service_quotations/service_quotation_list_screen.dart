// FILE PATH: lib/modules/service/service_quotations/service_quotation_list_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'create_service_quotation_screen.dart';
import 'service_quotation_details_screen.dart';
import 'service_quotation_pdf_generator.dart';
import 'service_quotation_pdf_preview_screen.dart';
import '../service_requests/service_request_details_screen.dart';
import '../service_visits/service_visit_details_screen.dart';
import 'models/service_quotation_models.dart';

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
final _kSelectedRowDecoration = BoxDecoration(color: Colors.indigo.shade50.withOpacity(0.3), border: _kRowBorder);

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

String _safeString(dynamic val) => (val ?? '').toString().trim();

double _safeDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

DateTime? _extractDate(dynamic value) {
  if (value == null) return null;
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

// ==========================================
// MAIN SCREEN - QUOTATION CONTROL TOWER
// ==========================================

class ServiceQuotationListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const ServiceQuotationListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<ServiceQuotationListScreen> createState() => _ServiceQuotationListScreenState();
}

class _ServiceQuotationListScreenState extends State<ServiceQuotationListScreen> {
  // --- CORE UI STATE ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  String _viewMode = 'Card'; // 'Card', 'Table'
  bool _isAdminOrCoordinator = false;

  // --- PAGINATION STATE ---
  int _currentLimit = 50;
  bool _isLoadingMore = false;

  // --- SELECTION STATE ---
  final Set<String> _selectedIds = {};

  // --- SORT STATE ---
  String _sortBy = 'Latest First';
  final List<String> _sortOptions = [
    'Latest First',
    'Oldest First',
    'Highest Amount',
    'Lowest Amount',
    'Customer Name',
    'Quote Number'
  ];

  // --- FILTERS STATE ---
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _approvalFilter = 'All';
  String _paymentFilter = 'All';
  String _typeFilter = 'All';
  DateTimeRange? _dateRangeFilter;

  final TextEditingController _filterCreatedByCtrl = TextEditingController();
  final TextEditingController _filterCustomerCtrl = TextEditingController();
  final TextEditingController _filterMachineCtrl = TextEditingController();
  RangeValues _amountRange = const RangeValues(0, 5000000);

  final List<String> _statuses = ['All', 'Draft', 'Sent', 'Approved', 'Rejected', 'Completed', 'Cancelled'];
  final List<String> _approvalStatuses = ['All', 'Pending', 'Approved', 'Rejected'];
  final List<String> _paymentStatuses = ['All', 'Pending', 'Advance Received', 'Partial Payment', 'Paid'];
  final List<String> _types = ['All', 'Service Request', 'Manual'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermissions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _filterCreatedByCtrl.dispose();
    _filterCustomerCtrl.dispose();
    _filterMachineCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore) {
        setState(() {
          _isLoadingMore = true;
          _currentLimit += 50;
        });
        // Reset loading state after a tiny delay to allow stream to fetch
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isLoadingMore = false);
        });
      }
    }
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
          _viewMode = prefs.getString('erp_service_quote_view_mode') ?? 'Card';
        });
      }
    } catch (_) {}
  }

  Future<void> _setViewMode(String mode) async {
    setState(() => _viewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('erp_service_quote_view_mode', _viewMode);
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

  bool get _hasActiveFilters => _statusFilter != 'All' ||
      _approvalFilter != 'All' ||
      _paymentFilter != 'All' ||
      _typeFilter != 'All' ||
      _dateRangeFilter != null ||
      _filterCreatedByCtrl.text.isNotEmpty ||
      _filterCustomerCtrl.text.isNotEmpty ||
      _filterMachineCtrl.text.isNotEmpty ||
      _amountRange.start > 0 || _amountRange.end < 5000000;

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _approvalFilter = 'All';
      _paymentFilter = 'All';
      _typeFilter = 'All';
      _dateRangeFilter = null;
      _filterCreatedByCtrl.clear();
      _filterCustomerCtrl.clear();
      _filterMachineCtrl.clear();
      _amountRange = const RangeValues(0, 5000000);
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

  // --- DATA FETCHING & FILTERING ---

  Stream<QuerySnapshot<Map<String, dynamic>>> _getQuotationsStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_quotations')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(_currentLimit)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFiltersAndSort(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var filtered = docs.where((doc) {
      final data = doc.data();

      // Extracted Fields for Search/Filter
      final qNo = _safeString(data['quoteNumber'] ?? data['quotationNo']).toLowerCase();
      final rNo = _safeString(data['serviceRequestNumber']).toLowerCase();
      final vNo = _safeString(data['serviceVisitNumber']).toLowerCase();
      final cName = _safeString(data['clientName'] ?? data['customerName']).toLowerCase();
      final cPerson = _safeString(data['contactPerson']).toLowerCase();
      final mobile = _safeString(data['clientMobile'] ?? data['contactMobile']).toLowerCase();
      final createdBy = _safeString(data['byName'] ?? data['createdByName']).toLowerCase();

      String machineInfo = _safeString(data['machineModel']).toLowerCase();
      String serialInfo = _safeString(data['serialNumber']).toLowerCase();

      if (data['machines'] != null && data['machines'] is List && (data['machines'] as List).isNotEmpty) {
        final firstM = (data['machines'] as List).first;
        machineInfo = _safeString(firstM['model']).toLowerCase();
        serialInfo = _safeString(firstM['serial']).toLowerCase();
      }

      final status = _safeString(data['status']);
      final aStatus = _safeString(data['approvalStatus']).isNotEmpty ? _safeString(data['approvalStatus']) : 'Pending';
      final pStatus = _safeString(data['paymentStatus']).isNotEmpty ? _safeString(data['paymentStatus']) : 'Pending';
      final type = _safeString(data['quotationSource']);
      final createdAt = _extractDate(data['quoteDate'] ?? data['createdAt']);
      final val = _safeDouble(data['finalTotal'] ?? data['grandTotal']);

      // 1. Dropdown Filters
      if (_statusFilter != 'All' && status != _statusFilter) return false;
      if (_approvalFilter != 'All' && aStatus != _approvalFilter) return false;
      if (_paymentFilter != 'All' && pStatus != _paymentFilter) return false;
      if (_typeFilter != 'All' && type != _typeFilter) return false;

      // 2. Date Filter
      if (_dateRangeFilter != null && createdAt != null) {
        if (createdAt.isBefore(_dateRangeFilter!.start) || createdAt.isAfter(_dateRangeFilter!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // 3. Text Filters
      if (_filterCreatedByCtrl.text.isNotEmpty && !createdBy.contains(_filterCreatedByCtrl.text.toLowerCase())) return false;
      if (_filterCustomerCtrl.text.isNotEmpty && !cName.contains(_filterCustomerCtrl.text.toLowerCase())) return false;
      if (_filterMachineCtrl.text.isNotEmpty && !machineInfo.contains(_filterMachineCtrl.text.toLowerCase())) return false;

      // 4. Amount Range
      if (val < _amountRange.start || val > _amountRange.end) return false;

      // 5. Global Search (Quote No, Customer, Contact, Machine, Serial, Request No, Visit No, Mobile)
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = qNo.contains(_searchQuery) ||
            rNo.contains(_searchQuery) ||
            vNo.contains(_searchQuery) ||
            cName.contains(_searchQuery) ||
            cPerson.contains(_searchQuery) ||
            machineInfo.contains(_searchQuery) ||
            serialInfo.contains(_searchQuery) ||
            mobile.contains(_searchQuery);
        if (!matchesSearch) return false;
      }

      return true;
    }).toList();

    // 6. Sorting
    filtered.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      if (_sortBy == 'Latest First' || _sortBy == 'Oldest First') {
        final dateA = _extractDate(dataA['quoteDate'] ?? dataA['createdAt']) ?? DateTime(2000);
        final dateB = _extractDate(dataB['quoteDate'] ?? dataB['createdAt']) ?? DateTime(2000);
        return _sortBy == 'Latest First' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      } else if (_sortBy == 'Highest Amount' || _sortBy == 'Lowest Amount') {
        final valA = _safeDouble(dataA['finalTotal'] ?? dataA['grandTotal']);
        final valB = _safeDouble(dataB['finalTotal'] ?? dataB['grandTotal']);
        return _sortBy == 'Highest Amount' ? valB.compareTo(valA) : valA.compareTo(valB);
      } else if (_sortBy == 'Customer Name') {
        final nameA = _safeString(dataA['clientName'] ?? dataA['customerName']).toLowerCase();
        final nameB = _safeString(dataB['clientName'] ?? dataB['customerName']).toLowerCase();
        return nameA.compareTo(nameB);
      } else if (_sortBy == 'Quote Number') {
        final qA = _safeString(dataA['quoteNumber'] ?? dataA['quotationNo']).toLowerCase();
        final qB = _safeString(dataB['quoteNumber'] ?? dataB['quotationNo']).toLowerCase();
        return qB.compareTo(qA); // Descending naturally better for quotes
      }
      return 0;
    });

    return filtered;
  }

  Map<String, dynamic> _calculateStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = docs.length;
    int draft = 0;
    int sent = 0;
    int approved = 0;
    int rejected = 0;
    int completed = 0;
    int pendingApproval = 0;
    int paid = 0;

    double totalValue = 0.0;
    double thisMonthValue = 0.0;
    final now = DateTime.now();

    for (var doc in docs) {
      final data = doc.data();
      final status = _safeString(data['status']);
      final aStatus = _safeString(data['approvalStatus']);
      final pStatus = _safeString(data['paymentStatus']);
      final val = _safeDouble(data['finalTotal'] ?? data['grandTotal']);
      final createdAt = _extractDate(data['quoteDate'] ?? data['createdAt']);

      if (status != 'Cancelled') totalValue += val;

      if (status == 'Draft') draft++;
      if (status == 'Sent') sent++;
      if (aStatus == 'Approved') approved++;
      if (aStatus == 'Rejected') rejected++;
      if (aStatus == 'Pending' || aStatus.isEmpty) pendingApproval++;
      if (status == 'Completed') completed++;
      if (pStatus == 'Paid') paid++;

      if (status != 'Cancelled' && createdAt != null && createdAt.year == now.year && createdAt.month == now.month) {
        thisMonthValue += val;
      }
    }

    double avgValue = total > 0 ? totalValue / total : 0.0;

    return {
      'Total': total,
      'Draft': draft,
      'Sent': sent,
      'Approved': approved,
      'PendingApproval': pendingApproval,
      'Rejected': rejected,
      'Completed': completed,
      'Paid': paid,
      'Value': totalValue,
      'AvgValue': avgValue,
      'ThisMonthValue': thisMonthValue,
    };
  }

  // --- ACTIONS ---

  void _navigateToCreate() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
    )));
  }

  void _navigateToDetails(String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceQuotationDetailsScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      currentUserName: widget.currentUserName,
      quotationId: docId,
      quotationData: data,
    )));
  }

  void _navigateToEdit(String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      quotationId: docId,
      existingQuotation: data,
    )));
  }

  void _previewPdf(Map<String, dynamic> data) {
    final rawItems = data['items'] as List<dynamic>? ?? [];

    // Updated to handle correct parsing and import
    final itemsList = rawItems
        .map((e) => QuotationLineItem.fromMap(
        Map<String, dynamic>.from(e)))
        .toList();

    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceQuotationPdfPreviewScreen(
      quotationData: data,
      items: itemsList,
    )));
  }

  void _updateStatus(String docId, Map<String, dynamic> updates, String actionNote) {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    updates['updatedBy'] = widget.currentUserUid;

    FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_quotations')
        .doc(docId)
        .update(updates)
        .then((_) => _showSnack(actionNote))
        .catchError((e) => _showSnack('Error: $e', isError: true));
  }

  void _duplicateQuotation(Map<String, dynamic> data) {
    final duplicateData = Map<String, dynamic>.from(data);

    // Wipe identifiers
    duplicateData.remove('id');
    duplicateData.remove('quotationId');
    duplicateData.remove('quoteNumber');
    duplicateData.remove('quotationNo');
    duplicateData.remove('createdAt');
    duplicateData.remove('updatedAt');
    duplicateData.remove('activities');

    // Reset status trackers
    duplicateData['status'] = 'Draft';
    duplicateData['approvalStatus'] = 'Pending';
    duplicateData['paymentStatus'] = 'Pending';
    duplicateData['version'] = 1;
    duplicateData['isLatest'] = true;

    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      existingQuotation: duplicateData,
    )));
  }

  void _softDelete(String docId) {
    _updateStatus(docId, {'isDeleted': true}, 'Quotation deleted successfully.');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // --- BULK ACTIONS & EXPORTS ---

  void _bulkSend() {
    _showSnack('Bulk Sending ${_selectedIds.length} quotations...');
    _clearSelection();
  }

  void _bulkExport(String format) {
    _showSnack('Exporting ${_selectedIds.length} quotations to $format...');
    _clearSelection();
  }

  void _bulkDelete() {
    final batch = FirebaseFirestore.instance.batch();
    for (var id in _selectedIds) {
      final ref = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_quotations').doc(id);
      batch.update(ref, {'isDeleted': true});
    }
    batch.commit().then((_) {
      _showSnack('${_selectedIds.length} quotations deleted.');
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
        tooltip: 'New Quotation',
        onPressed: _navigateToCreate,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getQuotationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final isWaiting = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
          final allDocs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyFiltersAndSort(allDocs);
          final stats = _calculateStats(filteredDocs);

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
                    : _buildWorkspaceContent(filteredDocs),
              ),
            ],
          );
        },
      ),
    );
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
                  hintText: 'Search Quote, Customer, Serial...',
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
                            if (_hasActiveFilters) Positioned(right: 8, top: 8, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.indigo.shade700, shape: BoxShape.circle))),
                          ]
                      )
                  )
              )
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.sort, size: 16),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                onChanged: (v) => setState(() => _sortBy = v ?? 'Latest First'),
                items: _sortOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: PopupMenuButton<String>(
              icon: Icon(
                  _viewMode == 'Table' ? Icons.table_rows : Icons.grid_view,
                  size: 20, color: Colors.grey.shade700
              ),
              tooltip: 'View Mode',
              onSelected: _setViewMode,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Card', child: Text('Card View')),
                const PopupMenuItem(value: 'Table', child: Text('Compact Table View')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Colors.blueGrey),
              tooltip: 'Refresh',
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _currentLimit = 50;
                  _isLoadingMore = false;
                });
              },
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(width: 16),
            Text('${_selectedIds.length} selected', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.send, color: Colors.blue, size: 20), onPressed: _bulkSend, tooltip: 'Bulk Send'),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.file_download, color: Colors.green, size: 20),
                      tooltip: 'Bulk Export',
                      onSelected: _bulkExport,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'Excel', child: Text('Export as Excel')),
                        const PopupMenuItem(value: 'PDF', child: Text('Export as PDF')),
                        const PopupMenuItem(value: 'CSV', child: Text('Export as CSV')),
                      ],
                    ),
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
                if (_approvalFilter != 'All') _buildFilterChip('Approval: $_approvalFilter'),
                if (_paymentFilter != 'All') _buildFilterChip('Pay: $_paymentFilter'),
                if (_typeFilter != 'All') _buildFilterChip('Type: $_typeFilter'),
                if (_dateRangeFilter != null) _buildFilterChip('Date: ${_formatDateOnly(_dateRangeFilter!.start)} - ${_formatDateOnly(_dateRangeFilter!.end)}'),
                if (_filterCreatedByCtrl.text.isNotEmpty) _buildFilterChip('Creator: ${_filterCreatedByCtrl.text}'),
                if (_filterCustomerCtrl.text.isNotEmpty) _buildFilterChip('Cust: ${_filterCustomerCtrl.text}'),
                if (_filterMachineCtrl.text.isNotEmpty) _buildFilterChip('Mach: ${_filterMachineCtrl.text}'),
                if (_amountRange.start > 0 || _amountRange.end < 5000000) _buildFilterChip('Amt: ₹${_amountRange.start.toInt()} - ₹${_amountRange.end.toInt()}'),
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
          Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No quotations found.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Try adjusting your search or filters.', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // --- LIST VIEWS ---

  Widget _buildWorkspaceContent(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (_viewMode == 'Table') {
      return _buildTableView(docs);
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: docs.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == docs.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _QuotationCard(
          docId: docs[i].id,
          data: docs[i].data(),
          isSelected: _selectedIds.contains(docs[i].id),
          onSelect: _toggleSelection,
          onView: _navigateToDetails,
          onEdit: _navigateToEdit,
          onPreviewPdf: _previewPdf,
          onDuplicate: _duplicateQuotation,
          onDelete: _softDelete,
          onUpdateStatus: _updateStatus,
          currentUserId: widget.currentUserUid,
        );
      },
    );
  }

  Widget _buildTableView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            headingTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.blueGrey.shade700),
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            showCheckboxColumn: true,
            columns: const [
              DataColumn(label: Text('QUOTE NO')),
              DataColumn(label: Text('DATE')),
              DataColumn(label: Text('CUSTOMER')),
              DataColumn(label: Text('REQUEST / VISIT')),
              DataColumn(label: Text('AMOUNT')),
              DataColumn(label: Text('STATUS / APPROVAL / PAYMENT')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: docs.map((doc) {
              final data = doc.data();
              final docId = doc.id;

              final quoteNo = _safeString(data['quoteNumber'] ?? data['quotationNo']);
              final customer = _safeString(data['clientName'] ?? data['customerName']);
              final reqNo = _safeString(data['serviceRequestNumber']);
              final visitNo = _safeString(data['serviceVisitNumber']);
              final val = _safeDouble(data['finalTotal'] ?? data['grandTotal']);
              final date = _extractDate(data['quoteDate'] ?? data['createdAt']);

              final status = _safeString(data['status']);
              final approval = _safeString(data['approvalStatus']).isNotEmpty ? _safeString(data['approvalStatus']) : 'Pending';
              final payment = _safeString(data['paymentStatus']).isNotEmpty ? _safeString(data['paymentStatus']) : 'Pending';

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

              final isSelected = _selectedIds.contains(docId);
              final isApproved = approval == 'Approved';

              return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => _toggleSelection(docId),
                  cells: [
                    DataCell(Text(quoteNo.isNotEmpty ? quoteNo : 'DRAFT', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo))),
                    DataCell(Text(_formatDateOnly(date))),
                    DataCell(Text(customer, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (reqNo.isNotEmpty) Text('Req: $reqNo', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (visitNo.isNotEmpty) Text('Vis: $visitNo', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (reqNo.isEmpty && visitNo.isEmpty) const Text('-', style: TextStyle(color: Colors.grey))
                      ],
                    )),
                    DataCell(Text(_formatCurrency(val), style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildStatusMiniBadge(status, _QuotationCard.getStatusColor(status)),
                        _buildStatusMiniBadge(approval, _QuotationCard.getApprovalColor(approval)),
                        _buildStatusMiniBadge(payment, _QuotationCard.getPaymentColor(payment)),
                      ],
                    )),
                    DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.visibility, color: Colors.indigo, size: 18), onPressed: () => _navigateToDetails(docId, data), tooltip: 'View 360'),
                            if (!isApproved) IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 18), onPressed: () => _navigateToEdit(docId, data), tooltip: 'Edit'),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                              onSelected: (val) {
                                if (val == 'pdf') _previewPdf(data);
                                if (val == 'dup') _duplicateQuotation(data);
                                if (!isApproved) {
                                  if (val == 'send') _updateStatus(docId, {'status': 'Sent'}, 'Quotation Marked as Sent');
                                  if (val == 'approve') _updateStatus(docId, {'approvalStatus': 'Approved', 'status': 'Approved'}, 'Quotation Approved');
                                  if (val == 'reject') _updateStatus(docId, {'approvalStatus': 'Rejected', 'status': 'Rejected'}, 'Quotation Rejected');
                                  if (val == 'del') _softDelete(docId);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 18, color: Colors.red), SizedBox(width: 8), Text('Preview PDF')])),
                                const PopupMenuItem(value: 'dup', child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('Duplicate')])),
                                if (!isApproved) ...[
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'send', child: Row(children: [Icon(Icons.send, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Mark Sent')])),
                                  const PopupMenuItem(value: 'approve', child: Row(children: [Icon(Icons.thumb_up, size: 18, color: Colors.green), SizedBox(width: 8), Text('Approve')])),
                                  const PopupMenuItem(value: 'reject', child: Row(children: [Icon(Icons.thumb_down, size: 18, color: Colors.red), SizedBox(width: 8), Text('Reject')])),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'del', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                ],
                              ],
                            ),
                          ],
                        )
                    )
                  ]
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
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

  // --- FILTERS SHEET ---
  Future<void> _openFilterSheet(Map<String, dynamic> stats) async {
    String tStatus = _statusFilter;
    String tApproval = _approvalFilter;
    String tPayment = _paymentFilter;
    String tType = _typeFilter;
    DateTimeRange? tDateRange = _dateRangeFilter;
    RangeValues tAmountRange = _amountRange;

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
                  const Text('Quotation Analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _buildStatChip('Total', stats['Total'], Colors.blueGrey.shade800),
                      _buildStatChip('Draft', stats['Draft'], Colors.grey.shade700),
                      _buildStatChip('Sent', stats['Sent'], Colors.blue.shade600),
                      _buildStatChip('Approved', stats['Approved'], Colors.green.shade600),
                      _buildStatChip('Pending Appr.', stats['PendingApproval'], Colors.orange.shade600),
                      _buildStatChip('Rejected', stats['Rejected'], Colors.red.shade600),
                      _buildStatChip('Completed', stats['Completed'], Colors.indigo.shade600),
                      _buildStatChip('Paid', stats['Paid'], Colors.teal.shade600),
                      _buildStatChip('Total Value', _formatCurrency(stats['Value']), Colors.green.shade700),
                      _buildStatChip('Avg Value', _formatCurrency(stats['AvgValue']), Colors.purple.shade600),
                      _buildStatChip('This Month', _formatCurrency(stats['ThisMonthValue']), Colors.brown.shade600),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  const Text('Advanced Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                      if (picked != null) setSheetState(() => tDateRange = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date Range', isDense: true, border: OutlineInputBorder()),
                      child: Text(tDateRange == null ? 'All Time' : '${_formatDateOnly(tDateRange!.start)} - ${_formatDateOnly(tDateRange!.end)}'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tStatus,
                          decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                          items: _statuses.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => tStatus = v ?? 'All',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tApproval,
                          decoration: const InputDecoration(labelText: 'Approval', isDense: true, border: OutlineInputBorder()),
                          items: _approvalStatuses.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => tApproval = v ?? 'All',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tPayment,
                          decoration: const InputDecoration(labelText: 'Payment', isDense: true, border: OutlineInputBorder()),
                          items: _paymentStatuses.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => tPayment = v ?? 'All',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tType,
                          decoration: const InputDecoration(labelText: 'Source', isDense: true, border: OutlineInputBorder()),
                          items: _types.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => tType = v ?? 'All',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _filterCustomerCtrl,
                    decoration: const InputDecoration(labelText: 'Customer Name', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _filterMachineCtrl,
                    decoration: const InputDecoration(labelText: 'Machine Model', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _filterCreatedByCtrl,
                    decoration: const InputDecoration(labelText: 'Created By', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),

                  const Text('Amount Range', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  RangeSlider(
                    values: tAmountRange,
                    min: 0,
                    max: 5000000,
                    divisions: 100,
                    labels: RangeLabels('₹${tAmountRange.start.toInt()}', '₹${tAmountRange.end.toInt()}'),
                    onChanged: (RangeValues values) {
                      setSheetState(() {
                        tAmountRange = values;
                      });
                    },
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tStatus = 'All'; tApproval = 'All'; tPayment = 'All'; tType = 'All'; tDateRange = null;
                              _filterCreatedByCtrl.clear(); _filterCustomerCtrl.clear(); _filterMachineCtrl.clear();
                              tAmountRange = const RangeValues(0, 5000000);
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
                              _approvalFilter = tApproval;
                              _paymentFilter = tPayment;
                              _typeFilter = tType;
                              _dateRangeFilter = tDateRange;
                              _amountRange = tAmountRange;
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
          ),
        );
      },
    );
  }
}

// ==========================================
// OPTIMIZED QUOTATION ROW WIDGET (STATELESS)
// ==========================================

class _QuotationCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isSelected;
  final Function(String) onSelect;
  final Function(String, Map<String, dynamic>) onView;
  final Function(String, Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onPreviewPdf;
  final Function(Map<String, dynamic>) onDuplicate;
  final Function(String) onDelete;
  final Function(String, Map<String, dynamic>, String) onUpdateStatus;
  final String currentUserId;

  const _QuotationCard({
    required this.docId,
    required this.data,
    required this.isSelected,
    required this.onSelect,
    required this.onView,
    required this.onEdit,
    required this.onPreviewPdf,
    required this.onDuplicate,
    required this.onDelete,
    required this.onUpdateStatus,
    required this.currentUserId,
  });

  static Color getStatusColor(String status) {
    if (status == 'Draft') return Colors.grey;
    if (status == 'Sent') return Colors.blue;
    if (status == 'Approved') return Colors.green;
    if (status == 'Completed') return Colors.indigo;
    if (status == 'Rejected') return Colors.red;
    if (status == 'Cancelled') return Colors.orange;
    return Colors.blueGrey;
  }

  static Color getApprovalColor(String status) {
    if (status == 'Approved') return Colors.green;
    if (status == 'Rejected') return Colors.red;
    return Colors.orange;
  }

  static Color getPaymentColor(String status) {
    if (status == 'Paid') return Colors.green;
    if (status == 'Partial Payment' || status == 'Advance Received') return Colors.teal;
    return Colors.red; // Pending
  }

  Widget _buildWorkflowRow(String status, String approval, String payment) {
    Widget buildStep(String state, String type) {
      bool isComplete = false;
      bool isRejected = false;

      if (type == 'status') {
        isComplete = ['Sent', 'Approved', 'Completed'].contains(state);
        isRejected = ['Rejected', 'Cancelled'].contains(state);
      } else if (type == 'approval') {
        isComplete = state == 'Approved';
        isRejected = state == 'Rejected';
      } else if (type == 'payment') {
        isComplete = state == 'Paid';
      }

      String mark = isComplete ? '✓' : (isRejected ? '✗' : '○');
      Color color = isComplete ? Colors.green.shade700 : (isRejected ? Colors.red.shade700 : Colors.orange.shade700);

      return Text('$state $mark', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildStep(status, 'status'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(Icons.chevron_right, size: 10, color: Colors.grey.shade400),
          ),
          buildStep(approval, 'approval'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(Icons.chevron_right, size: 10, color: Colors.grey.shade400),
          ),
          buildStep(payment, 'payment'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quoteNo = _safeString(data['quoteNumber'] ?? data['quotationNo']);
    final rev = _safeString(data['version']?.toString());
    final reqNo = _safeString(data['serviceRequestNumber']);
    final visitNo = _safeString(data['serviceVisitNumber']);
    final customer = _safeString(data['clientName'] ?? data['customerName']);
    final contactPerson = _safeString(data['contactPerson']);
    final createdBy = _safeString(data['byName'] ?? data['createdByName'] ?? 'System');

    String machineInfo = _safeString(data['machineModel']);
    if (data['machines'] != null && data['machines'] is List && (data['machines'] as List).isNotEmpty) {
      final firstM = (data['machines'] as List).first;
      machineInfo = _safeString(firstM['model']);
      if ((data['machines'] as List).length > 1) {
        machineInfo += ' (+${(data['machines'] as List).length - 1} more)';
      }
    }

    final val = _safeDouble(data['finalTotal'] ?? data['grandTotal']);
    final date = _extractDate(data['quoteDate'] ?? data['createdAt']);

    final status = _safeString(data['status']);
    final approval = _safeString(data['approvalStatus']).isNotEmpty ? _safeString(data['approvalStatus']) : 'Pending';
    final payment = _safeString(data['paymentStatus']).isNotEmpty ? _safeString(data['paymentStatus']) : 'Pending';

    // OWNERSHIP LOGIC
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

    final bool isApproved = approval == 'Approved';

    // Build Contact/Req Line
    List<String> contactLine = [];
    if (contactPerson.isNotEmpty) contactLine.add('Attn: $contactPerson');
    if (reqNo.isNotEmpty) contactLine.add('Req: $reqNo');
    if (visitNo.isNotEmpty) contactLine.add('Vis: $visitNo');

    // Build Ownership Line
    List<String> ownerLine = [];
    if (salesOwner.isNotEmpty) ownerLine.add('Sales: $salesOwner');
    if (serviceOwner.isNotEmpty) ownerLine.add('Svc: $serviceOwner');
    ownerLine.add('By: $createdBy');

    return InkWell(
      onTap: () => onView(docId, data),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isSelected ? _kSelectedRowDecoration : _kRowDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              height: 18,
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
                  // HEADER ROW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(quoteNo.isNotEmpty ? quoteNo : 'DRAFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '•  Rev ${rev.isNotEmpty ? rev : '1'}  •  ${_timeAgoStrict(date)}',
                          style: _kActivityTextStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),

                  // CUSTOMER HIERARCHY
                  Text(customer.isNotEmpty ? customer : 'Unknown Customer', style: _kCompanyNameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),

                  if (machineInfo.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(machineInfo, style: _kSecondaryTextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],

                  if (contactLine.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(contactLine.join('  •  '), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],

                  const SizedBox(height: 3),
                  // OWNERSHIP
                  Text(
                      ownerLine.join('  •  '),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis
                  ),

                  const SizedBox(height: 6),

                  // WORKFLOW
                  _buildWorkflowRow(status, approval, payment),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // RIGHT STATUS PANEL
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(val).replaceAll('₹', '').trim(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade700),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                        onSelected: (val) {
                          if (val == '360') onView(docId, data);
                          if (val == 'edit') onEdit(docId, data);
                          if (val == 'pdf') onPreviewPdf(data);
                          if (val == 'dup') onDuplicate(data);
                          if (!isApproved) {
                            if (val == 'send') onUpdateStatus(docId, {'status': 'Sent'}, 'Quotation Marked as Sent');
                            if (val == 'approve') onUpdateStatus(docId, {'approvalStatus': 'Approved', 'status': 'Approved'}, 'Quotation Approved');
                            if (val == 'reject') onUpdateStatus(docId, {'approvalStatus': 'Rejected', 'status': 'Rejected'}, 'Quotation Rejected');
                            if (val == 'del') onDelete(docId);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: '360', child: Text('Open Quotation 360')),
                          if (!isApproved) const PopupMenuItem(value: 'edit', child: Text('Edit Quotation')),
                          const PopupMenuItem(value: 'pdf', child: Text('Preview PDF')),
                          const PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                          if (!isApproved) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'send', child: Text('Mark Sent')),
                            const PopupMenuItem(value: 'approve', child: Text('Approve', style: TextStyle(color: Colors.green))),
                            const PopupMenuItem(value: 'reject', child: Text('Reject', style: TextStyle(color: Colors.red))),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'del', child: Text('Delete Quotation', style: TextStyle(color: Colors.red))),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('STATUS', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: getStatusColor(status)),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text('APPROVAL', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                Text(
                  approval.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: getApprovalColor(approval)),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text('PAYMENT', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                Text(
                  payment.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: getPaymentColor(payment)),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}