import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../payments_received/screens/record_payment_screen.dart';
import '../../invoice/export_invoice/widgets/export_invoice_document_view.dart';
import '../../invoice/export_invoice/models/export_invoice_model.dart';

class OutstandingScreen extends StatefulWidget {
  final String companyId;
  final String userUid;

  const OutstandingScreen({super.key, required this.companyId, required this.userUid});

  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  // 🔥 Strict Filters
  bool _includeDrafts = false;
  String _invoiceTypeFilter = 'ALL'; // ALL, DOMESTIC, EXPORT

  // NEW FILTERS
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // Track expanded customers
  final Set<String> _expandedCustomers = {};

  // Professional Indian Number Formatter
  final NumberFormat _formatter = NumberFormat('#,##0.00', 'en_IN');

  // 🔥 SAFETY NET: Prevents crashes if Firestore returns an int or string instead of double
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Receivables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),

                    const Text('Invoice Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _invoiceTypeFilter,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: ['ALL', 'DOMESTIC', 'EXPORT'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) => setModalState(() => _invoiceTypeFilter = val!),
                    ),

                    const SizedBox(height: 16),
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _includeDrafts ? 'drafts' : 'finalized',
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'finalized', child: Text('Finalized Only')),
                        const DropdownMenuItem(value: 'drafts', child: Text('Include Drafts')),
                      ],
                      onChanged: (val) => setModalState(() => _includeDrafts = val == 'drafts'),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                _invoiceTypeFilter = 'ALL';
                                _includeDrafts = false;
                                _startDate = null;
                                _endDate = null;
                              });
                              setState(() {});
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {});
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine target statuses for Dart-side filtering
    List<String> targetPaymentStatuses = ['UNPAID', 'PARTIALLY PAID', 'PARTIAL'];
    if (_includeDrafts) targetPaymentStatuses.add('DRAFT');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('companies')
              .doc(widget.companyId)
              .collection('outstanding')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text("Error loading data."));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Loading receivables...')
                  ],
                ),
              );
            }

            final snapshotData = snapshot.data;
            if (snapshotData == null) return const SizedBox();
            final rawDocs = snapshotData.docs;

            // --- 1. Memory Gatekeeper (Strict ERP filtering) ---
            final docs = rawDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? '').toString().toUpperCase();
              final type = (data['invoiceType'] ?? 'EXPORT').toString().toUpperCase();

              // Client-side whereIn equivalent logic
              if (!targetPaymentStatuses.contains(status)) return false;

              // Base Rule A: Exclude if fully paid or balance is zero
              final pendingFC = _parseDouble(data['outstandingAmount']);
              if (pendingFC <= 0 || status == 'PAID') return false;

              // Base Rule B: Apply UI Type filter
              if (_invoiceTypeFilter != 'ALL' && type != _invoiceTypeFilter) return false;

              // Base Rule C: Strict Draft Check via `isFinalized` gatekeeper
              final isFinalized = data['isFinalized'] ?? (status != 'DRAFT');
              if (!_includeDrafts && !isFinalized) return false;

              // Base Rule D: Search
              if (_searchQuery.isNotEmpty) {
                final sq = _searchQuery.toLowerCase();
                final customerName = (data['customerName'] ?? '').toString().toLowerCase();
                final invoiceNumber = (data['invoiceNumber'] ?? '').toString().toLowerCase();
                if (!customerName.contains(sq) && !invoiceNumber.contains(sq)) return false;
              }

              // Base Rule E: Date Filter
              if (_startDate != null && _endDate != null) {
                final dt = _parseDate(data['invoiceDate']);
                if (dt.isBefore(_startDate!.subtract(const Duration(days: 1))) ||
                    dt.isAfter(_endDate!.add(const Duration(days: 1)))) {
                  return false;
                }
              }

              return true;
            }).toList();

            // --- 2. Advanced Multi-Currency Math Engine ---
            double totalDomesticBase = 0.0;
            double totalExportBase = 0.0;
            Map<String, double> exportFcTotals = {};

            // Customer-wise mapping
            Map<String, double> customerBaseBalances = {};
            Map<String, Map<String, double>> customerFcBalances = {};
            Map<String, int> customerInvoiceCount = {};
            Map<String, List<Map<String, dynamic>>> customerInvoices = {};

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final type = (data['invoiceType'] ?? 'EXPORT').toString().toUpperCase();
              final currency = (data['currency'] ?? 'INR').toString().toUpperCase();

              final pendingFC = _parseDouble(data['outstandingAmount']);
              final exchangeRate = _parseDouble(data['exchangeRate']);
              final finalRate = exchangeRate > 0 ? exchangeRate : 1.0;

              final pendingBase = data.containsKey('baseOutstandingAmount')
                  ? _parseDouble(data['baseOutstandingAmount'])
                  : (pendingFC * finalRate);

              // Aggregate Type Totals
              if (type == 'DOMESTIC') {
                totalDomesticBase += pendingBase;
              } else {
                totalExportBase += pendingBase;
                exportFcTotals[currency] = (exportFcTotals[currency] ?? 0.0) + pendingFC;
              }

              // Aggregate Customer Maps
              final rawCustomer = data['customerName']?.toString().trim() ?? '';
              final customerName = rawCustomer.isEmpty ? 'Unknown Customer' : rawCustomer;

              customerBaseBalances[customerName] = (customerBaseBalances[customerName] ?? 0.0) + pendingBase;
              customerInvoiceCount[customerName] = (customerInvoiceCount[customerName] ?? 0) + 1;

              if (customerFcBalances[customerName] == null) customerFcBalances[customerName] = {};
              customerFcBalances[customerName]![currency] = (customerFcBalances[customerName]![currency] ?? 0.0) + pendingFC;

              if (customerInvoices[customerName] == null) customerInvoices[customerName] = [];

              data['id'] = doc.id;
              customerInvoices[customerName]!.add(data);
            }

            final double grandTotalBaseInr = totalDomesticBase + totalExportBase;

            // Sort customers by highest outstanding balance
            var sortedCustomers = customerBaseBalances.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Column(
              children: [
                _buildCompactSummaryCard(grandTotalBaseInr, totalDomesticBase, totalExportBase, exportFcTotals),
                _buildSearchBar(),
                Expanded(
                  child: docs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
                    itemCount: sortedCustomers.length,
                    itemBuilder: (context, index) {
                      final entry = sortedCustomers[index];
                      String customerName = entry.key;
                      double totalBase = entry.value;
                      int count = customerInvoiceCount[customerName]!;
                      Map<String, double> fcBreakdown = customerFcBalances[customerName]!;
                      List<Map<String, dynamic>> invoices = customerInvoices[customerName] ?? [];

                      String fcSubtitle = fcBreakdown.entries
                          .map((e) => '${e.key} ${_formatter.format(e.value)}')
                          .join('  •  ');

                      bool isExpanded = _expandedCustomers.contains(customerName);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text(
                                  customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$count unpaid invoice(s)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(fcSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.indigo.shade400, fontWeight: FontWeight.w600, fontSize: 12)),
                                  ],
                                ),
                              ),
                              trailing: SizedBox(
                                width: 110,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('₹ ${_formatter.format(totalBase)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RecordPaymentScreen(
                                              companyId: widget.companyId,
                                              userUid: widget.userUid,
                                              customerName: customerName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Record Payment',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedCustomers.remove(customerName);
                                  } else {
                                    _expandedCustomers.add(customerName);
                                  }
                                });
                              },
                            ),

                            if (isExpanded) ...[
                              const Divider(height: 1),
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))
                                ),
                                child: Column(
                                  children: invoices.map((inv) {
                                    return _buildInvoiceRow(inv);
                                  }).toList(),
                                ),
                              )
                            ]
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactSummaryCard(double total, double domestic, double export, Map<String, double> fcTotals) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('TOTAL OUTSTANDING (INR)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          if (_includeDrafts) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: Colors.orange.shade400, borderRadius: BorderRadius.circular(4)),
                              child: const Text('w/ DRAFTS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹ ${_formatter.format(total)}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('DOMESTIC: ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                          Expanded(child: Text('₹ ${_formatter.format(domestic)}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('EXPORT: ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                          Expanded(child: Text('₹ ${_formatter.format(export)}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (fcTotals.isNotEmpty) ...[
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: fcTotals.entries.map((e) {
                  return Text(
                    '${e.key} ${_formatter.format(e.value)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search customer or invoice no...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _openFilterSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
              ),
              child: Stack(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF1E293B), size: 22),
                  if (_invoiceTypeFilter != 'ALL' || _includeDrafts || _startDate != null)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(Map<String, dynamic> inv) {
    String invoiceNo = (inv['invoiceNumber'] ?? 'Unknown').toString();
    DateTime date = _parseDate(inv['invoiceDate']);
    String currency = (inv['currency'] ?? 'INR').toString();
    double total = _parseDouble(inv['totalAmount']);
    double pending = _parseDouble(inv['outstandingAmount']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoiceNo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(DateFormat('dd MMM yyyy').format(date), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$currency ${_formatter.format(pending)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.red)),
                const SizedBox(height: 2),
                Text('Total: ${_formatter.format(total)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.blue),
            onPressed: () async {
              final safeInvoiceId = (inv['invoiceId']?.toString().isNotEmpty == true)
                  ? inv['invoiceId']
                  : inv['id'];

              if (safeInvoiceId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: Invoice ID not found.'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                DocumentSnapshot doc = await FirebaseFirestore.instance
                    .collection('companies')
                    .doc(widget.companyId)
                    .collection('export_invoices')
                    .doc(safeInvoiceId)
                    .get();

                if (!doc.exists) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error: Invoice document not found.'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                ExportInvoiceModel fetchedInvoice = ExportInvoiceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExportInvoiceDocumentView(invoice: fetchedInvoice),
                    ),
                  );
                }

              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error fetching invoice: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
          const SizedBox(height: 16),
          const Text("All Clear!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(
              _includeDrafts ? "You have zero outstanding invoices or drafts." : "You have zero outstanding finalized invoices.",
              style: const TextStyle(color: Colors.grey)
          ),
        ],
      ),
    );
  }
}