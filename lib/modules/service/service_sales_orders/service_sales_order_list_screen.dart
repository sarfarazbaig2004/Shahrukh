// FILE PATH: lib/modules/service/service_sales_orders/service_sales_order_list_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'create_service_sales_order_screen.dart';
import 'service_sales_order_details_screen.dart';

// ==========================================
// CACHED ENTERPRISE STYLES (ZOHO / CRM STYLE)
// ==========================================
const _kCompanyNameStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B));
const _kSecondaryTextStyle = TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500);
const _kActivityTextStyle = TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500);

final _kRowBorder = Border(bottom: BorderSide(color: Colors.grey.shade200));
final _kRowDecoration = BoxDecoration(color: Colors.white, border: _kRowBorder);
final _kSelectedRowDecoration = BoxDecoration(color: Colors.indigo.shade50.withOpacity(0.3), border: _kRowBorder);

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

double _safeDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

String _safeString(dynamic val) => (val ?? '').toString().trim();

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

String _resolveName(Map<String, dynamic> data, List<String> keys) {
  for (var key in keys) {
    String val = _safeString(data[key]);
    if (val.isNotEmpty && val.length < 35 && !val.contains(RegExp(r'^[a-zA-Z0-9]{25,}$'))) {
      return val;
    }
  }
  return '';
}

// ==========================================
// MAIN SCREEN
// ==========================================

class ServiceSalesOrderListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const ServiceSalesOrderListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<ServiceSalesOrderListScreen> createState() => _ServiceSalesOrderListScreenState();
}

class _ServiceSalesOrderListScreenState extends State<ServiceSalesOrderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // --- FILTERS STATE ---
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _customerFilter = '';
  String _salesFilter = '';
  String _createdFilter = '';
  bool _poPendingOnly = false;
  bool _invoicePendingOnly = false;

  bool _isTableView = false;
  final Set<String> _selectedIds = {};

  final List<String> _statuses = [
    'All', 'Draft', 'Awaiting PO', 'Approved', 'In Progress', 'Completed', 'Closed', 'Cancelled'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _searchQuery != value.toLowerCase().trim()) {
        setState(() => _searchQuery = value.toLowerCase().trim());
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

  bool get _hasActiveFilters => _statusFilter != 'All' || _customerFilter.isNotEmpty || _salesFilter.isNotEmpty || _createdFilter.isNotEmpty || _poPendingOnly || _invoicePendingOnly;

  Stream<QuerySnapshot<Map<String, dynamic>>> _getStream() {
    // We maintain the exact original Firestore query constraints to prevent missing index errors
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_sales_orders')
        .where('isDeleted', isEqualTo: false);

    if (_statusFilter != 'All') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) {
      final data = doc.data();

      // Advanced Form Filters
      if (_customerFilter.isNotEmpty && !_safeString(data['customerName']).toLowerCase().contains(_customerFilter.toLowerCase())) return false;
      if (_salesFilter.isNotEmpty && !_safeString(data['salesPersonName']).toLowerCase().contains(_salesFilter.toLowerCase())) return false;
      if (_createdFilter.isNotEmpty && !_safeString(data['createdByName']).toLowerCase().contains(_createdFilter.toLowerCase())) return false;

      final po = _safeString(data['poNumber']);
      if (_poPendingOnly && po.isNotEmpty && po != 'Pending' && po != 'N/A') return false;

      final invStatus = _safeString(data['invoiceStatus']);
      if (_invoicePendingOnly && invStatus == 'Invoiced') return false;

      // Global Search Filter (Preserved from original logic)
      if (_searchQuery.isNotEmpty) {
        final sso = _safeString(data['ssoNumber']).toLowerCase();
        final cust = _safeString(data['customerName']).toLowerCase();
        final poNum = po.toLowerCase();
        final quote = _safeString(data['serviceQuotationNumber']).toLowerCase();
        final req = _safeString(data['serviceRequestNumber']).toLowerCase();
        final machine = _safeString(data['machineName'] ?? data['machineModel']).toLowerCase();

        final matchesSearch = sso.contains(_searchQuery) ||
            cust.contains(_searchQuery) ||
            poNum.contains(_searchQuery) ||
            quote.contains(_searchQuery) ||
            req.contains(_searchQuery) ||
            machine.contains(_searchQuery);

        if (!matchesSearch) return false;
      }

      return true;
    }).toList();
  }

  void _navigateToDetails(String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceSalesOrderDetailsScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      currentUserName: widget.currentUserName,
      ssoId: docId,
      ssoData: data,
    )));
  }

  void _softDelete(String docId) {
    FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_sales_orders')
        .doc(docId)
        .update({'isDeleted': true})
        .then((_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales Order deleted.'), backgroundColor: Colors.red)))
        .catchError((e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)));
  }

  Future<void> _openFilterSheet() async {
    String tStatus = _statusFilter;
    String tCust = _customerFilter;
    String tSales = _salesFilter;
    String tCreated = _createdFilter;
    bool tPoPending = _poPendingOnly;
    bool tInvPending = _invoicePendingOnly;

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
                      const Text('Filter Sales Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: tStatus,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: _statuses.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (v) => tStatus = v ?? 'All',
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: tCust,
                        decoration: const InputDecoration(labelText: 'Customer Name', isDense: true, border: OutlineInputBorder()),
                        onChanged: (v) => tCust = v,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: tSales,
                        decoration: const InputDecoration(labelText: 'Sales Person', isDense: true, border: OutlineInputBorder()),
                        onChanged: (v) => tSales = v,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: tCreated,
                        decoration: const InputDecoration(labelText: 'Created By', isDense: true, border: OutlineInputBorder()),
                        onChanged: (v) => tCreated = v,
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text('PO Pending Only', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        value: tPoPending,
                        activeColor: Colors.indigo,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setModalState(() => tPoPending = val),
                      ),
                      SwitchListTile(
                        title: const Text('Invoice Pending Only', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        value: tInvPending,
                        activeColor: Colors.indigo,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setModalState(() => tInvPending = val),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = 'All'; _customerFilter = ''; _salesFilter = ''; _createdFilter = ''; _poPendingOnly = false; _invoicePendingOnly = false;
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
                                  _statusFilter = tStatus; _customerFilter = tCust; _salesFilter = tSales; _createdFilter = tCreated; _poPendingOnly = tPoPending; _invoicePendingOnly = tInvPending;
                                });
                                Navigator.pop(ctx);
                              },
                              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(elevation: 0, toolbarHeight: 6, automaticallyImplyLeading: false, backgroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceSalesOrderScreen(
            companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName))),
        tooltip: 'New SSO',
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          _buildToolbar(),
          if (_hasActiveFilters) _buildActiveFiltersBar(),
          const Divider(height: 1, thickness: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));

                final allDocs = snapshot.data?.docs ?? [];
                final filteredDocs = _applyLocalFilters(allDocs);

                if (filteredDocs.isEmpty) return const Center(child: Text('No Service Sales Orders found.', style: TextStyle(color: Colors.grey, fontSize: 16)));

                return _isTableView ? _buildTable(filteredDocs) : _buildCards(filteredDocs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
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
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search Sales Orders, Customer, Request, Quotation, PO, Machine...',
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
          ),
          const SizedBox(width: 8),
          SizedBox(
              height: 38, width: 38,
              child: Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openFilterSheet,
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
                onPressed: () => setState(() => _isTableView = !_isTableView),
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
                if (_statusFilter != 'All') _buildFilterChip('Status: $_statusFilter'),
                if (_customerFilter.isNotEmpty) _buildFilterChip('Cust: $_customerFilter'),
                if (_salesFilter.isNotEmpty) _buildFilterChip('Sales: $_salesFilter'),
                if (_createdFilter.isNotEmpty) _buildFilterChip('Created: $_createdFilter'),
                if (_poPendingOnly) _buildFilterChip('PO Pending', color: Colors.orange.shade700),
                if (_invoicePendingOnly) _buildFilterChip('Invoice Pending', color: Colors.orange.shade700),
              ],
            ),
          ),
          TextButton(
              onPressed: () => setState(() { _statusFilter = 'All'; _customerFilter = ''; _salesFilter = ''; _createdFilter = ''; _poPendingOnly = false; _invoicePendingOnly = false; }),
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
          return _SalesOrderCard(
            docId: docs[i].id,
            data: docs[i].data(),
            isSelected: _selectedIds.contains(docs[i].id),
            onSelect: _toggleSelection,
            onView: _navigateToDetails,
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
              DataColumn(label: Text('SSO NO')),
              DataColumn(label: Text('CUSTOMER')),
              DataColumn(label: Text('DATE')),
              DataColumn(label: Text('VALUE')),
              DataColumn(label: Text('PO NO')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: docs.map((doc) {
              final d = doc.data();
              final isSelected = _selectedIds.contains(doc.id);
              final status = _safeString(d['status']);
              final po = _safeString(d['poNumber']);

              return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => _toggleSelection(doc.id),
                  cells: [
                    DataCell(Text(_safeString(d['ssoNumber']), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo))),
                    DataCell(Text(_safeString(d['customerName']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    DataCell(Text(_formatDateOnly(_extractDate(d['ssoDate'] ?? d['createdAt'])))),
                    DataCell(Text(_formatCurrency(_safeDouble(d['finalTotal'] ?? d['grandTotal'])), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(po.isEmpty ? 'Pending' : po, style: TextStyle(color: po.isEmpty || po == 'Pending' ? Colors.orange.shade700 : Colors.black))),
                    DataCell(_SalesOrderCard.buildStatusMiniBadge(status)),
                    DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.visibility, color: Colors.indigo, size: 18), onPressed: () => _navigateToDetails(doc.id, d), tooltip: 'View'),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                              onSelected: (val) {
                                if (val == 'view') _navigateToDetails(doc.id, d);
                                if (val == 'delete') _softDelete(doc.id);
                                if (val != 'view' && val != 'delete') {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action $val coming soon...')));
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'view', child: Text('Open Sales Order')),
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'pdf', child: Text('Generate PDF')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'dispatch', child: Text('Create Dispatch')),
                                const PopupMenuItem(value: 'invoice', child: Text('Create Invoice')),
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
}

// ==========================================
// OPTIMIZED SSO ROW WIDGET (STATELESS)
// ==========================================

class _SalesOrderCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isSelected;
  final Function(String) onSelect;
  final Function(String, Map<String, dynamic>) onView;
  final Function(String) onDelete;

  const _SalesOrderCard({
    required this.docId,
    required this.data,
    required this.isSelected,
    required this.onSelect,
    required this.onView,
    required this.onDelete,
  });

  static Color getStatusColor(String status) {
    if (status == 'Draft') return Colors.grey;
    if (status == 'Awaiting PO') return Colors.orange;
    if (status == 'Approved') return Colors.blue;
    if (status == 'In Progress') return Colors.purple;
    if (status == 'Completed' || status == 'Closed') return Colors.green;
    if (status == 'Cancelled') return Colors.red;
    return Colors.blueGrey;
  }

  static Widget buildStatusMiniBadge(String status) {
    Color color = getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildWorkflowRow(String status) {
    bool req = _safeString(data['serviceRequestNumber']).isNotEmpty;
    bool quote = _safeString(data['serviceQuotationNumber']).isNotEmpty;
    bool so = status != 'Draft' && status != 'Cancelled';
    bool dispatch = status == 'Completed' || status == 'Closed' || _safeString(data['dispatchStatus']) == 'Dispatched';
    bool invoice = status == 'Closed' || _safeString(data['invoiceStatus']) == 'Invoiced';

    Widget buildStep(String label, bool isComplete, bool isCurrent) {
      String mark = isComplete ? '✓' : '○';
      Color color = isComplete ? Colors.green.shade700 : (isCurrent ? Colors.orange.shade700 : Colors.grey.shade400);
      if (status == 'Cancelled') color = Colors.red.shade700;

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
          buildStep('Request', req, !req), arrow,
          buildStep('Quotation', quote, req && !quote), arrow,
          buildStep('Sales Order', so, quote && !so), arrow,
          buildStep('Dispatch', dispatch, so && !dispatch), arrow,
          buildStep('Invoice', invoice, dispatch && !invoice),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ssoNo = _safeString(data['ssoNumber']);
    final rev = _safeString(data['version']?.toString());
    final date = _extractDate(data['ssoDate'] ?? data['createdAt']);

    final customer = _safeString(data['customerName']);
    final machine = _safeString(data['machineName'] ?? data['machineModel']);

    final srNo = _safeString(data['serviceRequestNumber']);
    final quoteNo = _safeString(data['serviceQuotationNumber']);
    final poNo = _safeString(data['poNumber']);

    final status = _safeString(data['status']);
    final val = _safeDouble(data['finalTotal'] ?? data['grandTotal']);
    final gst = _safeString(data['gstPercentage']);
    final paymentStatus = _safeString(data['paymentStatus']);
    final invoiceStatus = _safeString(data['invoiceStatus']);

    // OWNERSHIP HIERARCHY
    final salesName = _resolveName(data, ['salesPersonName', 'customerOwnerName']);
    final serviceName = _resolveName(data, ['assignedManagerName', 'assignedCoordinatorName']);
    final createdName = _resolveName(data, ['createdByName', 'createdBy']);

    List<String> ownerLine = [];
    if (salesName.isNotEmpty) ownerLine.add('Sales: $salesName');
    if (serviceName.isNotEmpty) ownerLine.add('Service: $serviceName');
    if (createdName.isNotEmpty) ownerLine.add('Created: $createdName');

    // DOC CHAIN
    List<String> docChain = [];
    if (srNo.isNotEmpty) docChain.add('SR: $srNo');
    if (quoteNo.isNotEmpty) docChain.add('Quotation: $quoteNo');
    if (poNo.isNotEmpty && poNo != 'Pending' && poNo != 'N/A') {
      docChain.add('PO: $poNo');
    } else {
      docChain.add('PO Pending');
    }

    // METRICS
    List<String> metricsLine = [];
    metricsLine.add(_formatCurrency(val).replaceAll('.00', ''));
    if (gst.isNotEmpty) metricsLine.add('GST $gst%');
    if (paymentStatus.isNotEmpty) metricsLine.add(paymentStatus == 'Paid' ? 'Paid' : 'Payment Pending');
    if (invoiceStatus.isNotEmpty) metricsLine.add(invoiceStatus == 'Invoiced' ? 'Invoiced' : 'Invoice Pending');

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
                            TextSpan(text: ssoNo.isNotEmpty ? ssoNo : 'DRAFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade700)),
                            TextSpan(text: '  •  ${_timeAgoStrict(date)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            if (rev.isNotEmpty) TextSpan(text: '  •  Rev $rev', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ]
                      )
                  ),
                  const SizedBox(height: 4),

                  Text(customer.isNotEmpty ? customer : 'Unknown Customer', style: _kCompanyNameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),

                  if (machine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(machine, style: _kSecondaryTextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],

                  if (ownerLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(ownerLine.join('  •  '), style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],

                  if (docChain.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(docChain.join('  •  '), style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    if (val == 'delete') onDelete(docId);
                    if (val != 'view' && val != 'delete') {
                      // Standard fallback for unimplemented UI actions while keeping functionality unchanged
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action $val coming soon...')));
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'view', child: Text('Open Sales Order')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'pdf', child: Text('Generate PDF')),
                    const PopupMenuItem(value: 'preview', child: Text('Preview')),
                    const PopupMenuItem(value: 'print', child: Text('Print')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'dispatch', child: Text('Create Dispatch')),
                    const PopupMenuItem(value: 'invoice', child: Text('Create Invoice')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
                const SizedBox(height: 2),
                Text('STATUS', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: getStatusColor(status)),
                  textAlign: TextAlign.right,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('CREATED', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(
                  _formatDateOnly(date),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                  textAlign: TextAlign.right,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('VALUE', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(
                  _formatCurrency(val).replaceAll('.00', ''),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
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