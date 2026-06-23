// FILE PATH: lib/modules/service/service_quotations/service_quotation_details_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'create_service_quotation_screen.dart';
import '../service_requests/service_request_details_screen.dart';
import '../service_visits/service_visit_details_screen.dart';
import 'service_quotation_pdf_preview_screen.dart';

// --- ENTERPRISE WORKSPACE IMPORTS ---
import 'models/service_quotation_models.dart' as ext_models;
import 'widgets/service_quotation_header_card.dart';
import 'widgets/service_items_section.dart';
import 'widgets/quotation_summary_card.dart';
import 'widgets/quotation_bottom_action_bar.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

String _safeString(dynamic val) => (val ?? '').toString().trim();

double _safeDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is double) return val;
  if (val is int) return val.toDouble();
  return double.tryParse(val.toString()) ?? 0.0;
}

DateTime? _extractDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDateOnly(DateTime? dt) {
  if (dt == null) return '-';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  return '$day-$month-$year';
}

String _formatDateTime(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final min = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day-$month-$year $hour:$min $amPm';
}

// ==========================================
// MAIN SCREEN
// ==========================================

class ServiceQuotationDetailsScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String quotationId;
  final Map<String, dynamic> quotationData;

  const ServiceQuotationDetailsScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.quotationId,
    required this.quotationData,
  });

  @override
  State<ServiceQuotationDetailsScreen> createState() => _ServiceQuotationDetailsScreenState();
}

class _ServiceQuotationDetailsScreenState extends State<ServiceQuotationDetailsScreen> {
  bool _isLoading = true;
  bool _isAdminOrCoordinator = false;

  late Map<String, dynamic> _quoteData;
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _visitData;

  @override
  void initState() {
    super.initState();
    _quoteData = widget.quotationData;
    _checkPermissions();
    _loadData();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      // Fetch latest quote data
      final quoteDoc = await db.collection('companies').doc(widget.companyId).collection('service_quotations').doc(widget.quotationId).get();
      if (quoteDoc.exists && quoteDoc.data() != null) {
        _quoteData = quoteDoc.data()!;
      }

      // Fetch Parent Request
      final reqId = _safeString(_quoteData['serviceRequestId']);
      if (reqId.isNotEmpty) {
        final reqDoc = await db.collection('companies').doc(widget.companyId).collection('service_requests').doc(reqId).get();
        if (reqDoc.exists) _requestData = reqDoc.data();
      }

      // Fetch Parent Visit
      final visitId = _safeString(_quoteData['serviceVisitId']);
      if (visitId.isNotEmpty) {
        final visitDoc = await db.collection('companies').doc(widget.companyId).collection('service_visits').doc(visitId).get();
        if (visitDoc.exists) _visitData = visitDoc.data();
      }

    } catch (e) {
      debugPrint('Error loading quotation data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MODEL MAPPERS FOR WORKSPACE WIDGETS ---

  ext_models.ServiceQuotationModel _buildExternalModel() {
    final rawMachines = _quoteData['machines'] as List? ?? [];
    List<ext_models.QuotationMachine> mappedMachines = [];

    if (rawMachines.isNotEmpty) {
      mappedMachines = rawMachines.map((m) => ext_models.QuotationMachine(
        machineId: _safeString(m['machineUid']),
        machineName: _safeString(m['model'] ?? m['machineModel']),
        machineModel: _safeString(m['model'] ?? m['machineModel']),
        serialNumber: _safeString(m['serial'] ?? m['serialNumber']),
        warrantyStatus: _safeString(m['warrantyStatus']),
      )).toList();
    } else {
      mappedMachines.add(ext_models.QuotationMachine(
        machineId: '',
        machineName: _safeString(_quoteData['machineModel']),
        machineModel: _safeString(_quoteData['machineModel']),
        serialNumber: _safeString(_quoteData['serialNumber']),
        warrantyStatus: _safeString(_quoteData['warrantyStatus']),
      ));
    }

    return ext_models.ServiceQuotationModel(
      quotationId: widget.quotationId,
      quotationNumber: _safeString(_quoteData['quoteNumber'] ?? _quoteData['quotationNo']),
      requestId: _safeString(_quoteData['serviceRequestId']),
      requestNumber: _safeString(_quoteData['serviceRequestNumber']),
      visitId: _safeString(_quoteData['serviceVisitId']),
      visitNumber: _safeString(_quoteData['serviceVisitNumber']),
      customerId: _safeString(_quoteData['customerId']),
      customerName: _safeString(_quoteData['clientName'] ?? _quoteData['customerName']),
      quotationType: _safeString(_quoteData['quotationSource']),
      quotationSource: _safeString(_quoteData['quotationSource']),
      billingType: _quoteData['isInterState'] == true ? 'IGST' : 'CGST/SGST',
      followUpAction: '',
      dispatchRequired: _quoteData['dispatchRequired'] == true || _quoteData['packingChargesExtra'] == true,
      installationRequired: _quoteData['installationRequired'] == true,
      visitRequired: _quoteData['visitRequired'] == true,
      status: _safeString(_quoteData['status']),
      paymentStatus: _safeString(_quoteData['paymentStatus']),
      approvalStatus: _safeString(_quoteData['approvalStatus']),
      subtotal: _safeDouble(_quoteData['totalSubtotal'] ?? _quoteData['subtotal']),
      discount: _safeDouble(_quoteData['totalItemDiscount'] ?? _quoteData['discount']),
      taxAmount: _safeDouble(_quoteData['totalCgst']) + _safeDouble(_quoteData['totalSgst']) + _safeDouble(_quoteData['totalIgst']),
      grandTotal: _safeDouble(_quoteData['finalTotal'] ?? _quoteData['grandTotal']),
      remarks: _safeString(_quoteData['subject']),
      machines: mappedMachines,
      lineItems: _getAllLineItemsExt(),
      visitCharges: _getVisitChargesExt(),
      attachments: [],
    );
  }

  List<ext_models.QuotationLineItem> _getAllLineItemsExt() {
    List<ext_models.QuotationLineItem> all = [];
    final flatItems = _quoteData['items'] as List? ?? _quoteData['lineItems'] as List? ?? [];

    if (flatItems.isNotEmpty) {
      all.addAll(flatItems.map((e) => ext_models.QuotationLineItem.fromMap(Map<String, dynamic>.from(e))));
    } else if (_quoteData['machines'] != null) {
      for (var m in _quoteData['machines']) {
        if (m['items'] != null) {
          all.addAll((m['items'] as List).map((e) => ext_models.QuotationLineItem.fromMap(Map<String, dynamic>.from(e))));
        }
      }
    }
    return all;
  }

  List<ext_models.VisitCharge> _getVisitChargesExt() {
    final charges = _quoteData['visitCharges'] as List? ?? [];
    return charges.map((c) => ext_models.VisitCharge.fromMap(Map<String, dynamic>.from(c))).toList();
  }

  List<Map<String, dynamic>> get _activities {
    if (_quoteData['activities'] != null && _quoteData['activities'] is List) {
      return List<Map<String, dynamic>>.from(_quoteData['activities']).reversed.toList();
    }
    return [];
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('draft')) return Colors.grey;
    if (s.contains('sent')) return Colors.blue;
    if (s.contains('approved')) return Colors.green;
    if (s.contains('reject')) return Colors.red;
    if (s.contains('cancel')) return Colors.orange;
    if (s.contains('completed')) return Colors.indigo;
    return Colors.blueGrey;
  }

  Color _getTimelineColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('create')) return Colors.blueGrey;
    if (t.contains('sent')) return Colors.blue;
    if (t.contains('approve')) return Colors.green;
    if (t.contains('reject')) return Colors.red;
    if (t.contains('update')) return Colors.orange;
    if (t.contains('complete')) return Colors.indigo;
    return Colors.grey;
  }

  IconData _getTimelineIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('create')) return Icons.add_circle;
    if (t.contains('sent')) return Icons.send;
    if (t.contains('approve')) return Icons.check_circle;
    if (t.contains('reject')) return Icons.cancel;
    if (t.contains('update')) return Icons.edit;
    if (t.contains('complete')) return Icons.done_all;
    return Icons.info;
  }

  // --- ACTIONS ---

  void _openRequest() {
    final reqId = _safeString(_quoteData['serviceRequestId']);
    if (reqId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No linked Service Request found.'), backgroundColor: Colors.orange));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      currentUserName: widget.currentUserName,
      requestId: reqId,
      requestData: _requestData ?? {},
    )));
  }

  void _openVisit() {
    final visitId = _safeString(_quoteData['serviceVisitId']);
    if (visitId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No linked Service Visit found.'), backgroundColor: Colors.orange));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      currentUserName: widget.currentUserName,
      visitId: visitId,
      visitData: _visitData ?? {},
    )));
  }

  void _previewPdf() {
    final rawItems = (_quoteData['items'] as List<dynamic>? ?? _quoteData['lineItems'] as List<dynamic>? ?? []);
    final itemsList = rawItems
        .map((e) => ext_models.QuotationLineItem.fromMap(Map<String,dynamic>.from(e)))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceQuotationPdfPreviewScreen(
          quotationData: _quoteData,
          items: itemsList,
        ),
      ),
    );
  }

  void _editQuotation() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
      companyId: widget.companyId,
      currentUserUid: widget.currentUserUid,
      quotationId: widget.quotationId,
      existingQuotation: _quoteData,
    ))).then((_) => _loadData());
  }

  void _duplicateQuotation() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplicate functionality triggered')));
  }

  Future<void> _deleteQuotation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: const Text('Are you sure you want to delete this quotation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateStatus({'isDeleted': true}, 'Quotation Deleted');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> updates, String actionNote) async {
    try {
      setState(() => _isLoading = true);

      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['updatedBy'] = widget.currentUserUid;
      updates['activities'] = FieldValue.arrayUnion([{
        'type': 'Status Update',
        'status': updates['status'] ?? _quoteData['status'],
        'note': actionNote,
        'timestamp': Timestamp.now(),
        'byUid': widget.currentUserUid,
        'byName': widget.currentUserName,
      }]);

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('service_quotations')
          .doc(widget.quotationId)
          .update(updates);

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(actionNote), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================
  // UI COMPONENTS
  // ==========================================

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator()));
    }

    final extModel = _buildExternalModel();
    final bool isApproved = extModel.approvalStatus == 'Approved';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Quotation Workspace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ensure Header Card is included
                      ServiceQuotationHeaderCard(
                        quotation: extModel,
                        onOpenRequest: _openRequest,
                        onOpenVisit: _openVisit,
                      ),
                      const SizedBox(height: 16),

                      _buildTopSummaryCard(extModel),
                      const SizedBox(height: 16),
                      _buildCustomerInformationTile(extModel),
                      const SizedBox(height: 16),
                      _buildMachineInformationTile(extModel),
                      const SizedBox(height: 16),
                      _buildItemsAndFinancialTile(extModel),
                      const SizedBox(height: 16),
                      _buildTermsTile(),
                      const SizedBox(height: 16),
                      _buildTimelineTile(),
                      const SizedBox(height: 16),
                      _buildDocumentsTile(),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildBottomActionBar(extModel, isApproved),
        ],
      ),
    );
  }

  Widget _buildTopSummaryCard(ext_models.ServiceQuotationModel quoteModel) {
    final statusColor = _getStatusColor(quoteModel.status);
    final approvalColor = quoteModel.approvalStatus == 'Approved' ? Colors.green : (quoteModel.approvalStatus == 'Rejected' ? Colors.red : Colors.orange);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(quoteModel.quotationNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                  ],
                ),
                Row(
                  children: [
                    _buildStatusChip('Rev: ${_safeString(_quoteData['version']?.toString())}', Colors.blueGrey),
                    const SizedBox(width: 8),
                    _buildStatusChip(quoteModel.approvalStatus.isEmpty ? 'Pending' : quoteModel.approvalStatus, approvalColor),
                    const SizedBox(width: 8),
                    _buildStatusChip(quoteModel.status, statusColor),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(child: _buildSummaryItem('Customer', quoteModel.customerName)),
                Expanded(child: _buildSummaryItem('Machine Model', quoteModel.machines.isNotEmpty ? quoteModel.machines.first.machineModel : '-')),
                Expanded(child: _buildSummaryItem('Quote Date', _formatDateOnly(_extractDate(_quoteData['quoteDate'])))),
                Expanded(child: _buildSummaryItem('Created By', _safeString(_quoteData['byName'] ?? _quoteData['createdByName'] ?? 'System'))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grand Total', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('₹${quoteModel.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildCustomerInformationTile(ext_models.ServiceQuotationModel quoteModel) {
    return ExpansionTile(
      initiallyExpanded: true,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.5))),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      leading: const Icon(Icons.business, color: Colors.indigo),
      title: const Text('1. Customer Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Contact Person', _safeString(_quoteData['contactPerson'])),
                    const SizedBox(height: 12),
                    _buildInfoRow('Mobile', _safeString(_quoteData['clientMobile'] ?? _quoteData['contactMobile'])),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Email', _safeString(_quoteData['clientEmail'] ?? _quoteData['contactEmail'])),
                    const SizedBox(height: 12),
                    _buildInfoRow('Billing Address', _safeString(_quoteData['clientAddress'] ?? _quoteData['addressLine'])),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMachineInformationTile(ext_models.ServiceQuotationModel quoteModel) {
    return ExpansionTile(
      initiallyExpanded: true,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.5))),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      leading: const Icon(Icons.precision_manufacturing, color: Colors.indigo),
      title: const Text('2. Machine Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      children: quoteModel.machines.map((m) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildInfoRow('Category', _safeString(_quoteData['categoryName'] ?? _quoteData['categoryId']))),
                  Expanded(child: _buildInfoRow('Subcategory', _safeString(_quoteData['subcategoryName'] ?? _quoteData['subcategoryId']))),
                  Expanded(child: _buildInfoRow('Machine Model', m.machineModel)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildInfoRow('Serial Number', m.serialNumber)),
                  Expanded(child: _buildInfoRow('Warranty Status', m.warrantyStatus)),
                  Expanded(child: _buildInfoRow('Complaint', _safeString(_quoteData['complaintDescription'] ?? _quoteData['complaint']))),
                ],
              ),
              const Divider(height: 32),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemsAndFinancialTile(ext_models.ServiceQuotationModel quoteModel) {
    return ExpansionTile(
      initiallyExpanded: true,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.5))),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      leading: const Icon(Icons.build_circle_outlined, color: Colors.indigo),
      title: const Text('3 & 4. Items & Financial Summary', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ServiceItemsSection(
                companyId: widget.companyId,
                selectedMachineModel: quoteModel.machines.isNotEmpty ? quoteModel.machines.first.machineModel : null,
                lineItems: quoteModel.lineItems,
                visitCharges: quoteModel.visitCharges,
                onItemsChanged: (_) {},
                onVisitChargesChanged: (_) {},
                isReadOnly: true,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 4,
                    child: QuotationSummaryCard(
                      subtotal: quoteModel.subtotal,
                      discount: quoteModel.discount,
                      taxAmount: quoteModel.taxAmount,
                      grandTotal: quoteModel.grandTotal,
                      status: quoteModel.status,
                      paymentStatus: quoteModel.paymentStatus,
                      approvalStatus: quoteModel.approvalStatus,
                      dispatchRequired: quoteModel.dispatchRequired,
                      installationRequired: quoteModel.installationRequired,
                      visitRequired: quoteModel.visitRequired,
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildTermsTile() {
    final terms = _quoteData['dynamicTerms'] as List? ?? [];
    return ExpansionTile(
      initiallyExpanded: false,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.5))),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      leading: const Icon(Icons.gavel_outlined, color: Colors.indigo),
      title: const Text('5. Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      children: [
        if (terms.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('No terms provided.'))
        else
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: terms.map((t) {
                final title = _safeString(t['title']);
                final val = _safeString(t['value']);
                if (title.isEmpty && val.isEmpty) return const SizedBox.shrink();
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 200, child: Text('$title :', style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.bold))),
                        Expanded(child: Text(val, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
                      ],
                    )
                );
              }).toList(),
            ),
          )
      ],
    );
  }

  Widget _buildTimelineTile() {
    final activitiesList = _activities;

    return ExpansionTile(
      initiallyExpanded: false,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.5))),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      leading: const Icon(Icons.history, color: Colors.indigo),
      title: const Text('6. Timeline & Revision History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      children: [
        if (activitiesList.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('No activities recorded.'))
        else
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: activitiesList.asMap().entries.map((entry) {
                int idx = entry.key;
                var act = entry.value;
                bool isLast = idx == activitiesList.length - 1;

                final timeStr = _formatDateTime(act['timestamp']);
                final byName = _safeString(act['byName']);
                final note = _safeString(act['note']);
                final statusBadge = _safeString(act['status']);
                final typeStr = _safeString(act['type']);

                final iconColor = _getTimelineColor(typeStr.isNotEmpty ? typeStr : statusBadge);
                final iconData = _getTimelineIcon(typeStr.isNotEmpty ? typeStr : statusBadge);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        timeStr,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: iconColor, width: 2),
                          ),
                          child: Icon(iconData, size: 14, color: iconColor),
                        ),
                        if (!isLast)
                          Container(
                            width: 2, height: 40,
                            color: Colors.grey.shade300,
                          )
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(note, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              if (statusBadge.isNotEmpty && statusBadge != 'Unknown')
                                _buildStatusChip(statusBadge, _getStatusColor(statusBadge)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Action by: ${byName.isEmpty ? 'System' : byName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    )
                  ],
                );
              }).toList(),
            ),
          )
      ],
    );
  }

  Widget _buildDocumentsTile() {
    return ExpansionTile(
      initiallyExpanded: false,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.5))),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      leading: const Icon(Icons.folder_copy_outlined, color: Colors.indigo),
      title: const Text('7. Documents', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.1), child: const Icon(Icons.picture_as_pdf, color: Colors.red)),
              title: const Text('Quotation PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('System generated document'),
              trailing: FilledButton.icon(
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Preview PDF'),
                onPressed: _previewPdf,
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value.isNotEmpty ? value : '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildBottomActionBar(ext_models.ServiceQuotationModel extModel, bool isApproved) {
    final status = extModel.status;
    final approvalStatus = extModel.approvalStatus;
    final paymentStatus = extModel.paymentStatus;
    final isCancelled = status == 'Cancelled';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Include the existing action bar for common features
              QuotationBottomActionBar(
                quotation: extModel,
                onSaveDraft: () {},
                onSendQuote: () => _updateStatus({'status': 'Sent'}, 'Sent Quote to Customer'),
                onPreviewPdf: _previewPdf,
                onRefresh: _loadData,
                onOpenRequest: _openRequest,
                onOpenVisit: _openVisit,
                onDuplicate: _duplicateQuotation,
                onDelete: isApproved ? () {} : _deleteQuotation,
              ),

              const SizedBox(width: 16),
              Container(width: 2, height: 30, color: Colors.grey.shade300),
              const SizedBox(width: 16),

              if (!isCancelled && _isAdminOrCoordinator) ...[
                if (status != 'Approved' && status != 'Completed') ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _updateStatus({'approvalStatus': 'Approved', 'status': 'Approved'}, 'Marked as Approved'),
                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                    label: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _updateStatus({'approvalStatus': 'Rejected', 'status': 'Rejected'}, 'Marked as Rejected'),
                    icon: const Icon(Icons.thumb_down_alt_outlined, size: 16),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                ],

                if (approvalStatus == 'Approved' && paymentStatus != 'Paid') ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _updateStatus({'paymentStatus': 'Paid'}, 'Marked Payment as Received'),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Receive Payment'),
                  ),
                  const SizedBox(width: 8),
                ],

                if (status == 'Approved' && extModel.dispatchRequired) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _updateStatus({'dispatchStatus': 'Pending'}, 'Marked Dispatch as Pending'),
                    icon: const Icon(Icons.local_shipping_outlined, size: 16),
                    label: const Text('Start Dispatch'),
                  ),
                  const SizedBox(width: 8),
                ],

                if (status == 'Approved' && status != 'Completed') ...[
                  FilledButton.icon(
                    onPressed: () => _updateStatus({'status': 'Completed'}, 'Marked Quotation as Completed'),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Mark Completed'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  const SizedBox(width: 8),
                ],
              ],

              if (!isCancelled && status != 'Completed') ...[
                OutlinedButton.icon(
                  onPressed: () => _updateStatus({'status': 'Cancelled'}, 'Quotation Cancelled'),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Quote'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
                const SizedBox(width: 16),
              ],

              // Disabled Future Button
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.handyman, size: 16),
                label: const Text('Convert To Work Order'),
              ),
              const SizedBox(width: 16),

              if (!isApproved)
                FilledButton.icon(
                  onPressed: _editQuotation,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                ),
            ],
          ),
        ),
      ),
    );
  }
}