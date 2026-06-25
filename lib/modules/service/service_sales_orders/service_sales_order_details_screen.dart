// FILE PATH: lib/modules/service/service_sales_orders/service_sales_order_details_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'create_service_sales_order_screen.dart';
import '../service_visits/add_service_visit_screen.dart';

class ServiceSalesOrderDetailsScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String ssoId;
  final Map<String, dynamic> ssoData;

  const ServiceSalesOrderDetailsScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.ssoId,
    required this.ssoData,
  });

  @override
  State<ServiceSalesOrderDetailsScreen> createState() => _ServiceSalesOrderDetailsScreenState();
}

class _ServiceSalesOrderDetailsScreenState extends State<ServiceSalesOrderDetailsScreen> {
  bool _isLoading = false;
  late Map<String, dynamic> _data;
  List<Map<String, dynamic>> _relatedVisits = [];
  List<Map<String, dynamic>> _techniciansData = [];

  @override
  void initState() {
    super.initState();
    _data = widget.ssoData;
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      // Fetch Latest Data
      final doc = await db.collection('companies').doc(widget.companyId).collection('service_sales_orders').doc(widget.ssoId).get();
      if (doc.exists) {
        _data = doc.data()!;
      }

      // Fetch Related Visits (Now strictly linked to the Service Sales Order to prevent duplication)
      final visitSnap = await db.collection('companies').doc(widget.companyId).collection('service_visits')
          .where('serviceSalesOrderId', isEqualTo: widget.ssoId)
          .where('isDeleted', isEqualTo: false)
          .get();
      _relatedVisits = visitSnap.docs.map((e) => {'id': e.id, ...e.data()}).toList();

      // Fetch Technician Details
      _techniciansData.clear();
      if (_data['assignedTechnicians'] != null) {
        List uids = _data['assignedTechnicians'];
        if (uids.isNotEmpty) {
          final techSnap = await db.collection('companies').doc(widget.companyId).collection('users').where(FieldPath.documentId, whereIn: uids).get();
          _techniciansData = techSnap.docs.map((e) => {'id': e.id, ...e.data()}).toList();
        }
      }

    } catch (e) {
      debugPrint("Error loading details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_sales_orders').doc(widget.ssoId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _loadExtraData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order marked as $newStatus'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;

    switch (status) {
      case 'Draft': bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Awaiting PO': bg = Colors.amber.shade50; fg = Colors.amber.shade900; break;
      case 'Approved': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'In Progress': bg = Colors.purple.shade50; fg = Colors.purple.shade800; break;
      case 'Completed': bg = Colors.green.shade50; fg = Colors.green.shade800; break;
      case 'Closed': bg = Colors.teal.shade50; fg = Colors.teal.shade800; break;
      case 'Cancelled': bg = Colors.red.shade50; fg = Colors.red.shade800; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: fg.withOpacity(0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ssoNo = _data['ssoNumber'] ?? 'Unknown';
    final custName = _data['customerName'] ?? 'Unknown';
    final status = _data['status'] ?? 'Draft';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SSO: $ssoNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(custName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          _buildStatusBadge(status),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSectionCard('Customer & Core Info', {
                        'Customer Name': _data['customerName'],
                        'Site Address': _data['siteAddress'],
                        'Contact Person': _data['contactPerson'],
                        'Service Request': _data['serviceRequestNumber'] ?? 'None',
                        'Quotation': _data['serviceQuotationNumber'] ?? 'None',
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSectionCard('Work Details', {
                        'Complaint': _data['complaint'],
                        'Scope Of Work': _data['scopeOfWork'],
                        'Internal Notes': _data['internalNotes'],
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSectionCard('PO Information', {
                        'Document Type': _data['poDocumentType'],
                        'PO Number': _data['poNumber'],
                        'PO Date': _data['poDate'] != null ? DateFormat('dd-MM-yyyy').format((_data['poDate'] as Timestamp).toDate()) : '-',
                        'Ref Contact': _data['poReferenceContact'],
                        'Remarks': _data['poRemarks'],
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Assigned Technicians', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
                            const SizedBox(height: 16),
                            if (_techniciansData.isEmpty) const Text('No technicians assigned.', style: TextStyle(color: Colors.grey)),
                            ..._techniciansData.map((t) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(t['name'] ?? t['fullName'] ?? 'Unknown'),
                              subtitle: Text(t['designation'] ?? 'Technician'),
                            ))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildVisitsSection(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (status != 'Closed' && status != 'Cancelled') ...[
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceSalesOrderScreen(
                  companyId: widget.companyId,
                  currentUserUid: widget.currentUserUid,
                  currentUserName: widget.currentUserName,
                  existingDocId: widget.ssoId,
                  existingData: _data,
                ))).then((_) => _loadExtraData()),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Order'),
              ),
              const SizedBox(width: 12),

              // NEW ENTERPRISE INTEGRATION: Contextual Prefilled Visit Creation
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
                  companyId: widget.companyId,
                  currentUserUid: widget.currentUserUid,
                  currentUserName: widget.currentUserName,
                  serviceSalesOrderId: widget.ssoId,
                  serviceSalesOrderNumber: _data['ssoNumber'],
                  serviceRequestId: _data['serviceRequestId'],
                  serviceRequestNumber: _data['serviceRequestNumber'],
                  serviceQuotationId: _data['serviceQuotationId'],
                  serviceQuotationNumber: _data['serviceQuotationNumber'],
                  customerId: _data['customerId'],
                  customerName: _data['customerName'],
                  siteAddress: _data['siteAddress'],
                  contactPerson: _data['contactPerson'],
                  complaint: _data['complaint'],
                  scopeOfWork: _data['scopeOfWork'],
                  assignedTechnicians: _data['assignedTechnicians'] != null ? List<String>.from(_data['assignedTechnicians']) : null,
                ))).then((_) => _loadExtraData()),
                icon: const Icon(Icons.directions_car),
                label: const Text('Create Visit'),
                style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _updateStatus('Closed'),
                icon: const Icon(Icons.done_all),
                label: const Text('Close Order'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, Map<String, dynamic> fields) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
          const SizedBox(height: 16),
          ...fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map(
                  (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 120, child: Text(e.key, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600))),
                    Expanded(child: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87))),
                  ],
                ),
              )
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Related Service Visits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
          const SizedBox(height: 16),
          if (_relatedVisits.isEmpty) const Text('No visits scheduled yet.', style: TextStyle(color: Colors.grey)),
          ..._relatedVisits.map((v) {
            final vNo = v['visitNo'] ?? 'Unknown';
            final vDate = v['visitDate'] != null ? DateFormat('dd-MM-yyyy').format((v['visitDate'] as Timestamp).toDate()) : '-';
            final vStatus = v['visitStatus'] ?? v['status'] ?? 'Scheduled';
            return ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.directions_car, color: Colors.white, size: 20)),
              title: Text('$vNo - $vDate', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(v['assignedTechnicianName'] ?? 'Unassigned'),
              trailing: _buildStatusBadge(vStatus),
            );
          }),
        ],
      ),
    );
  }
}