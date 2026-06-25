// FILE PATH: lib/modules/service/service_requests/service_request_details_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'add_service_request_screen.dart';
import '../service_visits/add_service_visit_screen.dart';
import '../service_visits/service_visit_details_screen.dart';
import '../service_technicians/service_technician_details_screen.dart';
import '../service_quotations/create_service_quotation_screen.dart';
import '../service_quotations/service_quotation_details_screen.dart';
import '../service_quotations/service_quotation_pdf_generator.dart';
import '../service_quotations/service_quotation_pdf_preview_screen.dart';
import '../service_quotations/models/service_quotation_models.dart';
import '../service_sales_orders/create_service_sales_order_screen.dart';
import '../service_sales_orders/service_sales_order_details_screen.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

String _safeString(dynamic val) => (val ?? '').toString().trim();

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

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

String _formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final min = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day-$month-$year $hour:$min $amPm';
}

String _formatCurrency(double amount) {
  final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  return format.format(amount);
}

// ==========================================
// MAIN DETAILS SCREEN
// ==========================================

class ServiceRequestDetailsScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String requestId;
  final Map<String, dynamic> requestData;

  const ServiceRequestDetailsScreen({
    Key? key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.requestId,
    required this.requestData,
  }) : super(key: key);

  @override
  State<ServiceRequestDetailsScreen> createState() => _ServiceRequestDetailsScreenState();
}

class _ServiceRequestDetailsScreenState extends State<ServiceRequestDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isAdminOrCoordinator = false;

  // Data State
  late Map<String, dynamic> _requestData;
  List<Map<String, dynamic>> _allVisits = [];
  List<Map<String, dynamic>> _completedVisits = [];
  List<Map<String, dynamic>> _allQuotations = [];
  List<Map<String, dynamic>> _allSalesOrders = [];

  // Cross Module Data State
  List<Map<String, dynamic>> _involvedTechnicians = [];
  List<Map<String, dynamic>> _allAttachments = [];

  // KPI State
  int _machineCount = 0;
  int _visitCount = 0;
  int _openVisitsCount = 0;
  int _completedVisitsCount = 0;
  bool _reportSubmitted = false;
  DateTime? _lastVisitDate;

  @override
  void initState() {
    super.initState();
    _requestData = widget.requestData;
    _tabController = TabController(length: 8, vsync: this);
    _checkPermissions();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        db.collection('companies').doc(widget.companyId).collection('service_requests').doc(widget.requestId).get(),
        db.collection('companies').doc(widget.companyId).collection('service_visits').where('requestId', isEqualTo: widget.requestId).where('isDeleted', isEqualTo: false).get(),
        db.collection('companies').doc(widget.companyId).collection('service_quotations').where('serviceRequestId', isEqualTo: widget.requestId).where('isDeleted', isEqualTo: false).get(),
        db.collection('companies').doc(widget.companyId).collection('service_sales_orders').where('serviceRequestId', isEqualTo: widget.requestId).where('isDeleted', isEqualTo: false).get(),
      ]);

      final reqDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final visitsQuery = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final quotesQuery = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final ssoQuery = results[3] as QuerySnapshot<Map<String, dynamic>>;

      if (reqDoc.exists && reqDoc.data() != null) {
        _requestData = reqDoc.data()!;
      }

      // Process Quotations
      _allQuotations.clear();
      for (var doc in quotesQuery.docs) {
        _allQuotations.add({'id': doc.id, ...doc.data()});
      }

      // Process Sales Orders
      _allSalesOrders.clear();
      for (var doc in ssoQuery.docs) {
        _allSalesOrders.add({'id': doc.id, ...doc.data()});
      }

      // Process Visits
      _allVisits.clear();
      _completedVisits.clear();
      _openVisitsCount = 0;
      _completedVisitsCount = 0;
      _lastVisitDate = null;
      _reportSubmitted = false;
      _allAttachments.clear();

      Set<String> uniqueTechUids = {};
      List<String> techUidsToFetch = [];

      for (var doc in visitsQuery.docs) {
        final data = doc.data();
        final visitMap = {'id': doc.id, ...data};
        final status = _safeString(data['visitStatus']).isNotEmpty ? _safeString(data['visitStatus']) : _safeString(data['status']);
        final vDate = _extractDate(data['visitDate']);

        final assignedTechId = _safeString(data['assignedTechnicianUid']).isNotEmpty ? _safeString(data['assignedTechnicianUid']) : _safeString(data['engineerUid']);
        if (assignedTechId.isNotEmpty && !uniqueTechUids.contains(assignedTechId)) {
          uniqueTechUids.add(assignedTechId);
          techUidsToFetch.add(assignedTechId);
        }

        _allVisits.add(visitMap);

        if (status == 'Completed' || status == 'Resolved') {
          _completedVisits.add(visitMap);
          _completedVisitsCount++;

          // Aggregate Attachments Safely
          void extractAttachments(String key, String type) {
            if (data[key] != null && data[key] is List) {
              for(var img in (data[key] as List)) {
                if (img is Map) {
                  _allAttachments.add({
                    'url': _safeString(img['url']),
                    'type': type,
                    'uploadedAt': _extractDate(img['uploadedAt']),
                    'uploadedByName': _safeString(img['uploadedByName']),
                    'visitNo': _safeString(data['visitNo'])
                  });
                } else if (img is String) {
                  _allAttachments.add({
                    'url': img,
                    'type': type,
                    'uploadedAt': _extractDate(data['completedAt'] ?? data['updatedAt']),
                    'uploadedByName': 'Unknown',
                    'visitNo': _safeString(data['visitNo'])
                  });
                }
              }
            }
          }

          extractAttachments('reportImages', 'Report');
          extractAttachments('machinePhotos', 'Machine Photo');
          extractAttachments('customerSignatures', 'Signature');
          extractAttachments('documents', 'Document');

          if (_allAttachments.any((a) => a['type'] == 'Report')) {
            _reportSubmitted = true;
          }

        } else if (status != 'Cancelled') {
          _openVisitsCount++;
        }

        if (vDate != null) {
          if (_lastVisitDate == null || vDate.isAfter(_lastVisitDate!)) {
            _lastVisitDate = vDate;
          }
        }
      }

      // Fetch Technician Details Manually & Gather KPIs
      _involvedTechnicians.clear();
      if (techUidsToFetch.isNotEmpty) {
        final chunks = [for (var i = 0; i < techUidsToFetch.length; i += 10) techUidsToFetch.sublist(i, techUidsToFetch.length > i + 10 ? i + 10 : techUidsToFetch.length)];

        for(var chunk in chunks) {
          final techSnap = await db.collection('companies').doc(widget.companyId).collection('users').where(FieldPath.documentId, whereIn: chunk).get();
          for(var tDoc in techSnap.docs) {
            final techId = tDoc.id;
            int openCnt = 0;
            int compCnt = 0;

            // Safely fetch open/completed visits for this technician to provide dynamic KPIs
            final vSnap = await db.collection('companies').doc(widget.companyId)
                .collection('service_visits')
                .where('isDeleted', isEqualTo: false)
                .where('assignedTechnicianUid', isEqualTo: techId)
                .get();

            for(var vDoc in vSnap.docs) {
              final st = _safeString(vDoc.data()['visitStatus']).isNotEmpty ? _safeString(vDoc.data()['visitStatus']) : _safeString(vDoc.data()['status']);
              if (st == 'Completed' || st == 'Resolved') compCnt++;
              else if (st != 'Cancelled') openCnt++;
            }

            _involvedTechnicians.add({
              'id': techId,
              ...tDoc.data(),
              'globalOpenVisits': openCnt,
              'globalCompletedVisits': compCnt,
            });
          }
        }
      }

      _visitCount = _allVisits.length;

      // Extract Machine Count Safely
      if (_requestData['serviceItems'] is List) {
        _machineCount = (_requestData['serviceItems'] as List).length;
      } else {
        final mName = _safeString(_requestData['machineName'] ?? _requestData['machineModel']);
        _machineCount = mName.isNotEmpty ? 1 : 0;
      }

      // Sort lists (latest first)
      _allVisits.sort((a, b) {
        final aDate = _extractDate(a['visitDate']) ?? DateTime(2000);
        final bDate = _extractDate(b['visitDate']) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      _completedVisits.sort((a, b) {
        final aDate = _extractDate(a['visitDate']) ?? DateTime(2000);
        final bDate = _extractDate(b['visitDate']) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      _allSalesOrders.sort((a, b) {
        final aDate = _extractDate(a['ssoDate']) ?? _extractDate(a['createdAt']) ?? DateTime(2000);
        final bDate = _extractDate(b['ssoDate']) ?? _extractDate(b['createdAt']) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

    } catch (e) {
      debugPrint('Error loading request details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS ---

  Future<void> _closeRequest() async {
    try {
      final reqRef = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_requests').doc(widget.requestId);

      await reqRef.set({
        'status': 'Closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedByUid': widget.currentUserUid,
        'closedByName': widget.currentUserName,
        'lastActivity': 'Request Closed',
        'lastActivityAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request Closed Successfully'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _navigateToCreateVisit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        prefillRequestId: widget.requestId,
        serviceRequestId: widget.requestId,
        serviceRequestNumber: _safeString(_requestData['requestNumber']),
        customerId: _safeString(_requestData['customerId']),
        customerName: _safeString(_requestData['customerName']),
        siteAddress: _safeString(_requestData['address']),
        contactPerson: _safeString(_requestData['contactPerson']),
        complaint: _safeString(_requestData['complaintDescription']),
      )),
    ).then((_) => _loadData());
  }

  void _createNewQuotation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        serviceRequestSeed: {'id': widget.requestId, ..._requestData},
      )),
    ).then((_) => _loadData());
  }

  void _createNewSalesOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateServiceSalesOrderScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        prefillRequestId: widget.requestId,
        prefillRequestNumber: _safeString(_requestData['requestNumber']),
        prefillCustomerId: _safeString(_requestData['customerId']),
        prefillCustomerName: _safeString(_requestData['customerName']),
        prefillSiteAddress: _safeString(_requestData['address']),
        prefillContactPerson: _safeString(_requestData['contactPerson']),
        prefillComplaint: _safeString(_requestData['complaintDescription']),
      )),
    ).then((_) => _loadData());
  }

  void _navigateToViewVisits() {
    _tabController.animateTo(1);
  }

  void _previewPdf(Map<String, dynamic> data) {
    final rawItems = (data['items'] as List<dynamic>? ?? []);
    final itemsList = rawItems
        .map((e) => QuotationLineItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceQuotationPdfPreviewScreen(
          quotationData: data,
          items: itemsList,
        ),
      ),
    );
  }

  String _getNextAction(Map<String, dynamic> data) {
    final s = _safeString(data['status']).toLowerCase();
    final a = _safeString(data['approvalStatus']).toLowerCase();
    final p = _safeString(data['paymentStatus']).toLowerCase();
    final dispatchReq = data['dispatchRequired'] == true || data['packingChargesExtra'] == true;
    final instReq = data['installationRequired'] == true || data['visitRequired'] == true;

    if (s == 'cancelled') return 'Archived';
    if (s == 'draft') return 'Send Quote';
    if (a == 'rejected') return 'Review Rejection';
    if (s == 'sent' && a == 'pending') return 'Follow-up Customer';
    if (a == 'approved' && (p == 'pending' || p == 'unpaid')) return 'Collect Payment';
    if (dispatchReq && s != 'completed') return 'Dispatch Material';
    if (instReq && s != 'completed') return 'Schedule Visit';
    if (s == 'completed') return 'No Action';

    return 'Complete Flow';
  }

  // --- UI COMPONENTS ---

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;

    switch (status) {
      case 'New': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'Assigned': bg = Colors.purple.shade50; fg = Colors.purple.shade800; break;
      case 'Visit Created': bg = Colors.indigo.shade50; fg = Colors.indigo.shade800; break;
      case 'In Progress': bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Report Submitted': bg = Colors.teal.shade50; fg = Colors.teal.shade800; break;
      case 'Completed':
      case 'Resolved': bg = Colors.green.shade50; fg = Colors.green.shade800; break;
      case 'Closed': bg = Colors.grey.shade200; fg = Colors.grey.shade800; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg, letterSpacing: 0.5)),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color = Colors.grey;
    switch (priority) {
      case 'Critical': color = Colors.red.shade700; break;
      case 'High': color = Colors.orange.shade700; break;
      case 'Medium': color = Colors.blue.shade700; break;
      case 'Low': color = Colors.grey.shade700; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(priority, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Color _getQuoteStatusColor(String status) {
    if (status == 'Draft') return Colors.orange;
    if (status == 'Sent') return Colors.blue;
    if (status == 'Approved') return Colors.green;
    if (status == 'Completed') return Colors.purple;
    if (status == 'Rejected' || status == 'Cancelled') return Colors.red;
    return Colors.grey;
  }

  Color _getApprovalColor(String status) {
    if (status == 'Approved') return Colors.green;
    if (status == 'Rejected') return Colors.red;
    return Colors.orange;
  }

  Color _getPaymentColor(String status) {
    if (status == 'Paid') return Colors.green;
    if (status == 'Partial Payment' || status == 'Advance Received') return Colors.teal;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Colors.grey.shade50, body: const Center(child: CircularProgressIndicator()));
    }

    final reqNo = _safeString(_requestData['requestNumber']);
    final customerName = _safeString(_requestData['customerName']);
    final status = _safeString(_requestData['status']);
    final priority = _safeString(_requestData['priority']);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reqNo.isNotEmpty ? reqNo : 'Request Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(customerName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(width: 16),
            _buildStatusBadge(status),
            const SizedBox(width: 8),
            if (priority.isNotEmpty) _buildPriorityBadge(priority),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh'),
          if (_isAdminOrCoordinator) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
                  companyId: widget.companyId,
                  currentUserUid: widget.currentUserUid,
                  currentUserName: widget.currentUserName,
                  existingDocId: widget.requestId,
                  existingData: _requestData,
                ))).then((_) => _loadData()),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit Request'),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            if (status != 'Closed')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: FilledButton.icon(
                  onPressed: _navigateToCreateVisit,
                  icon: const Icon(Icons.add_location_alt, size: 16),
                  label: const Text('Create Visit'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                ),
              ),
          ]
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.indigo,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'VISITS'),
            Tab(text: 'QUOTATIONS'),
            Tab(text: 'SALES ORDERS'),
            Tab(text: 'REPORTS'),
            Tab(text: 'TIMELINE'),
            Tab(text: 'ATTACHMENTS'),
            Tab(text: 'TECHNICIANS'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildKpiBanner(status, priority),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildVisitsTab(),
                _buildQuotationsTab(),
                _buildSalesOrdersTab(),
                _buildReportsTab(),
                _buildTimelineTab(),
                _buildAttachmentsTab(),
                _buildTechniciansTab(),
              ],
            ),
          ),
          _buildBottomBar(status),
        ],
      ),
    );
  }

  Widget _buildKpiBanner(String status, String priority) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('Status', status, Icons.info_outline, Colors.blue),
            _buildKpiCard('Priority', priority, Icons.flag, Colors.red),
            _buildKpiCard('Machines', _machineCount.toString(), Icons.settings, Colors.orange),
            _buildKpiCard('Total Visits', _visitCount.toString(), Icons.event, Colors.indigo),
            _buildKpiCard('Open Visits', _openVisitsCount.toString(), Icons.directions_car, Colors.purple),
            _buildKpiCard('Quotations', _allQuotations.length.toString(), Icons.request_quote, Colors.green),
            _buildKpiCard('Sales Orders', _allSalesOrders.length.toString(), Icons.assignment_turned_in, Colors.brown),
            _buildKpiCard('Report Status', _reportSubmitted ? 'Submitted' : 'Pending', Icons.description, _reportSubmitted ? Colors.green : Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color.shade700),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, color: color.shade800, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSectionCard('Customer Information', {
                      'Customer Name': _safeString(_requestData['customerName']),
                      'Contact Person': _safeString(_requestData['contactPerson']),
                      'Mobile': _safeString(_requestData['mobileNumber']),
                      'Email': _safeString(_requestData['email']),
                      'Address': _safeString(_requestData['address']),
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSectionCard('Complaint Information', {
                      'Complaint Description': _safeString(_requestData['complaintDescription']),
                      'Problem Category': _safeString(_requestData['complaintCategory']),
                      'Severity': _safeString(_requestData['severity']),
                      'Priority': _safeString(_requestData['priority']),
                      'Service Type': _safeString(_requestData['serviceType'] ?? 'Breakdown'),
                      'Remarks': _safeString(_requestData['remarks']),
                      'Internal Notes': _safeString(_requestData['internalNotes']),
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMachineDetailsSection(),
              const SizedBox(height: 16),
              _buildSectionCard('Assignment & Logistics', {
                'Department': 'Service',
                'Assigned Coordinator': _safeString(_requestData['assignedToName']),
                'Assigned Manager': _safeString(_requestData['assignedManagerName']),
                'Created By': _safeString(_requestData['createdByName']),
                'Created Date': _formatDateTime(_extractDate(_requestData['createdAt'])),
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMachineDetailsSection() {
    List<Map<String, dynamic>> items = [];
    if (_requestData['serviceItems'] is List) {
      items = List<Map<String, dynamic>>.from(_requestData['serviceItems']);
    } else {
      // Legacy Fallback mapping
      items.add({
        'itemName': _safeString(_requestData['machineName'] ?? _requestData['machineModel']),
        'serialNumber': _safeString(_requestData['serialNumber'] ?? _requestData['machineSerialNumber']),
        'categoryName': _safeString(_requestData['machineCategory'] ?? _requestData['serviceCategoryName']),
        'subcategoryName': _safeString(_requestData['machineSubCategory'] ?? _requestData['serviceSubCategoryName']),
        'isWarranty': _requestData['isWarranty'],
        'installationDate': _requestData['installationDate'],
      });
    }

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Machine Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
            const SizedBox(height: 16),
            if (items.isNotEmpty && items[0]['itemName'].toString().isNotEmpty)
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: const [
                      Padding(padding: EdgeInsets.all(8), child: Text('Machine Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Serial No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Warranty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Inst. Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  ...items.map((m) {
                    String wStatus = (m['isWarranty'] == true || m['isWarranty'] == 'true') ? 'Under Warranty' : 'Out of Warranty';
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(m['itemName']), style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(m['serialNumber']), style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(m['categoryName']), style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(wStatus, style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(_formatDateOnly(_extractDate(m['installationDate'])), style: const TextStyle(fontSize: 12))),
                      ],
                    );
                  })
                ],
              )
            else
              Text('No specific machine details logged.', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
          ],
        )
    );
  }

  Widget _buildVisitsTab() {
    if (_allVisits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No visits scheduled yet.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            if (_isAdminOrCoordinator) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _navigateToCreateVisit,
                icon: const Icon(Icons.add),
                label: const Text('Create New Visit'),
              )
            ]
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isAdminOrCoordinator)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FilledButton.icon(
                    onPressed: _navigateToCreateVisit,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create New Visit'),
                  ),
                ),
              ..._allVisits.map((v) {
                final visitNo = _safeString(v['visitNo']);
                final status = _safeString(v['visitStatus']).isNotEmpty ? _safeString(v['visitStatus']) : _safeString(v['status']);
                final type = _safeString(v['visitType']);
                final tech = _safeString(v['assignedTechnicianName']).isNotEmpty ? _safeString(v['assignedTechnicianName']) : _safeString(v['engineerName']);
                final date = _extractDate(v['visitDate']);
                final time = _safeString(v['visitTime']);
                final priority = _safeString(v['priority']);

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(
                      companyId: widget.companyId,
                      currentUserUid: widget.currentUserUid,
                      currentUserName: widget.currentUserName,
                      visitId: v['id'].toString(),
                      visitData: v,
                    ))).then((_) => _loadData()),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: Colors.purple.shade50, child: const Icon(Icons.directions_car, color: Colors.purple)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(visitNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(status),
                                    const SizedBox(width: 8),
                                    if (priority.isNotEmpty) _buildPriorityBadge(priority),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Tech: ${tech.isEmpty ? 'Unassigned' : tech}', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                                Text('Type: $type', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_formatDateOnly(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (time.isNotEmpty) Text(time, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(
                                  companyId: widget.companyId,
                                  currentUserUid: widget.currentUserUid,
                                  currentUserName: widget.currentUserName,
                                  visitId: v['id'].toString(),
                                  visitData: v,
                                ))).then((_) => _loadData()),
                                icon: const Icon(Icons.launch, size: 16),
                                label: const Text('View Visit'),
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }).toList()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotationsTab() {
    if (_allQuotations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No quotations created', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            if (_isAdminOrCoordinator) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _createNewQuotation,
                icon: const Icon(Icons.add),
                label: const Text('Create New Quotation'),
              )
            ]
          ],
        ),
      );
    }

    // Group by quoteNumber
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var q in _allQuotations) {
      final qNo = _safeString(q['quoteNumber']);
      if (!grouped.containsKey(qNo)) grouped[qNo] = [];
      grouped[qNo]!.add(q);
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_isAdminOrCoordinator)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: FilledButton.icon(
                            onPressed: _createNewQuotation,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create New Quotation'),
                          ),
                        ),
                      ...grouped.entries.map((entry) {
                        final revisions = entry.value;
                        revisions.sort((a,b) => _safeInt(b['version']).compareTo(_safeInt(a['version'])));
                        final latest = revisions.first;

                        if (revisions.length == 1) {
                          return _buildQuotationCard(latest, false);
                        }

                        return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                            child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  title: Row(
                                      children: [
                                        Text(_safeString(latest['quoteNumber']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
                                          child: Text('v${latest['version']} (Latest)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${revisions.length} Revisions', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ]
                                  ),
                                  childrenPadding: const EdgeInsets.all(16),
                                  children: revisions.map((rev) {
                                    final isLatest = rev['id'] == latest['id'];
                                    return _buildQuotationCard(rev, isLatest);
                                  }).toList(),
                                )
                            )
                        );
                      }).toList()
                    ]
                )
            )
        )
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> data, bool showVersionBadge) {
    final qNo = _safeString(data['quoteNumber']);
    final type = _safeString(data['quotationType'] ?? data['quotationSource']);
    final amount = _safeDouble(data['grandTotal'] ?? data['finalTotal']);
    final status = _safeString(data['status']);
    final approval = _safeString(data['approvalStatus']).isNotEmpty ? _safeString(data['approvalStatus']) : 'Pending';
    final payment = _safeString(data['paymentStatus']).isNotEmpty ? _safeString(data['paymentStatus']) : 'Pending';
    final dispatch = _safeString(data['dispatchStatus']).isNotEmpty ? _safeString(data['dispatchStatus']) : (data['dispatchRequired'] == true ? 'Pending' : 'N/A');
    final installation = _safeString(data['installationStatus']).isNotEmpty ? _safeString(data['installationStatus']) : (data['installationRequired'] == true ? 'Pending' : 'N/A');
    final createdAt = _extractDate(data['createdAt']);
    final nextAction = _getNextAction(data);
    final version = _safeInt(data['version']);

    return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceQuotationDetailsScreen(
            companyId: widget.companyId,
            currentUserUid: widget.currentUserUid,
            currentUserName: widget.currentUserName,
            quotationId: data['id'],
            quotationData: data,
          ))).then((_) => _loadData()),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(qNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (showVersionBadge) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
                                  child: Text('v$version', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                                ),
                              ]
                            ],
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatDateOnly(createdAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('Next: $nextAction', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                              ]
                          )
                        ]
                    ),
                    const SizedBox(height: 12),
                    Row(
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Type: ${type.isEmpty ? 'Service' : type}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('Amount: ${_formatCurrency(amount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green)),
                                  ]
                              )
                          ),
                          Expanded(
                              child: Wrap(
                                  spacing: 6, runSpacing: 6,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    _buildMiniBadge(status, _getQuoteStatusColor(status)),
                                    _buildMiniBadge(approval, _getApprovalColor(approval)),
                                    _buildMiniBadge(payment, _getPaymentColor(payment)),
                                    if (dispatch != 'N/A') _buildMiniBadge('Disp: $dispatch', Colors.brown),
                                    if (installation != 'N/A') _buildMiniBadge('Inst: $installation', Colors.teal),
                                  ]
                              )
                          )
                        ]
                    ),
                    const Divider(height: 24),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _previewPdf(data),
                            icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                            label: const Text('Preview PDF', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceQuotationDetailsScreen(
                              companyId: widget.companyId,
                              currentUserUid: widget.currentUserUid,
                              currentUserName: widget.currentUserName,
                              quotationId: data['id'],
                              quotationData: data,
                            ))).then((_) => _loadData()),
                            icon: const Icon(Icons.launch, size: 16),
                            label: const Text('Quote 360'),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                          const SizedBox(width: 8),
                          if (_isAdminOrCoordinator)
                            FilledButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateServiceQuotationScreen(
                                companyId: widget.companyId,
                                currentUserUid: widget.currentUserUid,
                                quotationId: data['id'],
                                existingQuotation: data,
                              ))).then((_) => _loadData()),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: Colors.blueGrey),
                            )
                        ]
                    )
                  ]
              )
          ),
        )
    );
  }

  Widget _buildSalesOrdersTab() {
    if (_allSalesOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No service sales orders created.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            if (_isAdminOrCoordinator) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _createNewSalesOrder,
                icon: const Icon(Icons.add),
                label: const Text('Create Service Sales Order'),
              )
            ]
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isAdminOrCoordinator)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FilledButton.icon(
                    onPressed: _createNewSalesOrder,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Service Sales Order'),
                  ),
                ),
              ..._allSalesOrders.map((sso) {
                final ssoNo = _safeString(sso['ssoNumber']);
                final status = _safeString(sso['status']);
                final poNo = _safeString(sso['poNumber']);
                final date = _extractDate(sso['ssoDate']) ?? _extractDate(sso['createdAt']);

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceSalesOrderDetailsScreen(
                      companyId: widget.companyId,
                      currentUserUid: widget.currentUserUid,
                      currentUserName: widget.currentUserName,
                      ssoId: sso['id'],
                      ssoData: sso,
                    ))).then((_) => _loadData()),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: Colors.brown.shade50, child: const Icon(Icons.assignment_turned_in, color: Colors.brown)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(ssoNo.isNotEmpty ? ssoNo : 'Draft SSO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('PO No: ${poNo.isEmpty ? 'N/A' : poNo}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_formatDateOnly(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceSalesOrderDetailsScreen(
                                  companyId: widget.companyId,
                                  currentUserUid: widget.currentUserUid,
                                  currentUserName: widget.currentUserName,
                                  ssoId: sso['id'],
                                  ssoData: sso,
                                ))).then((_) => _loadData()),
                                icon: const Icon(Icons.launch, size: 16),
                                label: const Text('View Order'),
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }).toList()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    List<Map<String, dynamic>> reportsOnly = _allAttachments.where((a) => a['type'] == 'Report').toList();

    if (reportsOnly.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No reports uploaded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // Group reports by visit
    Map<String, List<Map<String, dynamic>>> groupedReports = {};
    for(var r in reportsOnly) {
      final vNo = _safeString(r['visitNo']);
      if(!groupedReports.containsKey(vNo)) groupedReports[vNo] = [];
      groupedReports[vNo]!.add(r);
    }

    return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: groupedReports.length,
        itemBuilder: (context, index) {
          final visitNo = groupedReports.keys.elementAt(index);
          final images = groupedReports[visitNo]!;
          final reportDate = _formatDateTime(_extractDate(images.first['uploadedAt']));

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.receipt_long, color: Colors.indigo, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Visit: $visitNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Submitted: $reportDate', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        Text('${images.length} Report Pages', style: TextStyle(color: Colors.indigo.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      List<String> urls = images.map((i) => _safeString(i['url'])).toList();
                      if(urls.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImageViewer(imageUrls: urls, initialIndex: 0)));
                      }
                    },
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('View Images'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
                  )
                ],
              ),
            ),
          );
        }
    );
  }

  Widget _buildAttachmentsTab() {
    List<Map<String, dynamic>> nonReports = _allAttachments.where((a) => a['type'] != 'Report').toList();

    if (nonReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attachment, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No external attachments found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Documents, signatures, and machine photos will appear here.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16, runSpacing: 16,
        children: nonReports.asMap().entries.map((entry) {
          final idx = entry.key;
          final att = entry.value;
          return InkWell(
            onTap: () {
              List<String> urls = nonReports.map((i) => _safeString(i['url'])).toList();
              Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImageViewer(imageUrls: urls, initialIndex: idx)));
            },
            child: Container(
              width: 200,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Container(
                      height: 140, width: double.infinity, color: Colors.grey.shade100,
                      child: _safeString(att['url']).startsWith('http')
                          ? Image.network(att['url'], fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image))
                          : const Icon(Icons.insert_drive_file, size: 40, color: Colors.grey),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(att['type'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Visit: ${att['visitNo']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        Text(_formatDateOnly(att['uploadedAt']), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineTab() {
    final tsReqCreated = _formatDateTime(_extractDate(_requestData['createdAt']));

    DateTime? lastVisitCompleted;
    for (var v in _completedVisits) {
      final tComp = _extractDate(v['completedAt']);
      if (tComp != null && (lastVisitCompleted == null || tComp.isAfter(lastVisitCompleted))) {
        lastVisitCompleted = tComp;
      }
    }

    DateTime? firstQuoteCreated;
    DateTime? lastQuoteApproved;
    DateTime? lastPayment;
    DateTime? lastDispatch;
    DateTime? lastInstall;

    for(var q in _allQuotations) {
      final tCreated = _extractDate(q['createdAt']);
      if(tCreated != null && (firstQuoteCreated == null || tCreated.isBefore(firstQuoteCreated))) firstQuoteCreated = tCreated;

      if (q['approvalStatus'] == 'Approved') {
        final tApp = _extractDate(q['updatedAt']);
        if (tApp != null && (lastQuoteApproved == null || tApp.isAfter(lastQuoteApproved))) lastQuoteApproved = tApp;
      }
      if (q['paymentStatus'] == 'Paid' || q['paymentStatus'] == 'Advance Received') {
        final tPay = _extractDate(q['updatedAt']);
        if (tPay != null && (lastPayment == null || tPay.isAfter(lastPayment))) lastPayment = tPay;
      }
      if (q['dispatchStatus'] == 'Dispatched' || q['dispatchStatus'] == 'Completed') {
        final tDisp = _extractDate(q['dispatchedAt'] ?? q['updatedAt']);
        if (tDisp != null && (lastDispatch == null || tDisp.isAfter(lastDispatch))) lastDispatch = tDisp;
      }
      if (q['installationStatus'] == 'Completed') {
        final tInst = _extractDate(q['installedAt'] ?? q['updatedAt']);
        if (tInst != null && (lastInstall == null || tInst.isAfter(lastInstall))) lastInstall = tInst;
      }
    }

    DateTime? firstSalesOrderCreated;
    for(var sso in _allSalesOrders) {
      final tCreated = _extractDate(sso['createdAt']) ?? _extractDate(sso['ssoDate']);
      if (tCreated != null && (firstSalesOrderCreated == null || tCreated.isBefore(firstSalesOrderCreated))) {
        firstSalesOrderCreated = tCreated;
      }
    }

    final isClosed = _safeString(_requestData['status']) == 'Closed';
    final tsClosed = _formatDateTime(_extractDate(_requestData['closedAt'] ?? _requestData['updatedAt']));

    final stages = [
      {'label': 'Request Created', 'active': true, 'time': tsReqCreated},
      {'label': 'Quotation Created', 'active': firstQuoteCreated != null, 'time': _formatDateTime(firstQuoteCreated)},
      {'label': 'Quotation Approved', 'active': lastQuoteApproved != null, 'time': _formatDateTime(lastQuoteApproved)},
      {'label': 'Sales Order Created', 'active': firstSalesOrderCreated != null, 'time': _formatDateTime(firstSalesOrderCreated)},
      {'label': 'Visit Completed', 'active': lastVisitCompleted != null, 'time': _formatDateTime(lastVisitCompleted)},
      {'label': 'Payment Received', 'active': lastPayment != null, 'time': _formatDateTime(lastPayment)},
      {'label': 'Dispatch Started', 'active': lastDispatch != null, 'time': _formatDateTime(lastDispatch)},
      {'label': 'Installation Completed', 'active': lastInstall != null, 'time': _formatDateTime(lastInstall)},
      {'label': 'Request Closed', 'active': isClosed, 'time': tsClosed},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request Lifecycle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ...stages.asMap().entries.map((entry) {
                int idx = entry.key;
                var stage = entry.value;
                bool active = stage['active'] as bool;
                String timeStr = stage['time'] as String;
                bool isLast = idx == stages.length - 1;

                if (active && timeStr == '-') timeStr = '(Time Unknown / Legacy)';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: Text(
                        active ? timeStr : '-',
                        style: TextStyle(fontSize: 12, color: active ? Colors.grey.shade800 : Colors.grey.shade400, fontWeight: active ? FontWeight.bold : FontWeight.normal),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: active ? Colors.green : Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(color: active ? Colors.green.shade700 : Colors.grey.shade300, width: 2),
                          ),
                          child: active ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                        if (!isLast)
                          Container(
                            width: 3, height: 50,
                            color: active ? Colors.green : Colors.grey.shade200,
                          )
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                            stage['label'] as String,
                            style: TextStyle(fontSize: 15, color: active ? Colors.black87 : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal)
                        ),
                      ),
                    )
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechniciansTab() {
    if (_involvedTechnicians.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.engineering_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No technicians assigned yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _involvedTechnicians.length,
        itemBuilder: (context, index) {
          final tech = _involvedTechnicians[index];
          final name = _safeString(tech['name'] ?? tech['fullName'] ?? tech['employeeName']);
          final designation = _safeString(tech['designation'] ?? tech['designationName']);
          final mobile = _safeString(tech['mobile'] ?? tech['phone']);
          final status = _safeString(tech['availabilityStatus']).isNotEmpty ? _safeString(tech['availabilityStatus']) : 'Available';
          final openVisits = _safeInt(tech['globalOpenVisits']);
          final completedVisits = _safeInt(tech['globalCompletedVisits']);

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: Colors.blue.withValues(alpha: 0.1), child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 8),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(designation.isNotEmpty ? designation : 'Technician', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        if(mobile.isNotEmpty) Text('Mobile: $mobile', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Open: $openVisits', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      const SizedBox(height: 4),
                      Text('Completed: $completedVisits', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceTechnicianDetailsScreen(
                        companyId: widget.companyId,
                        currentUserUid: widget.currentUserUid,
                        currentUserName: widget.currentUserName,
                        userId: tech['id'],
                        technicianData: tech
                    ))),
                    icon: const Icon(Icons.person_pin, size: 16),
                    label: const Text('Technician 360'),
                  )
                ],
              ),
            ),
          );
        }
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
                    SizedBox(width: 140, child: Text(e.key, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600))),
                    Expanded(child: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87))),
                  ],
                ),
              )
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(String status) {
    Widget? smartAction;

    if (status == 'New' || status == 'Assigned' || status == 'Open') {
      smartAction = FilledButton.icon(
        onPressed: _navigateToCreateVisit,
        icon: const Icon(Icons.add_location_alt, size: 16),
        label: const Text('Create Visit'),
        style: FilledButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      );
    } else if (status == 'Visit Created') {
      smartAction = FilledButton.icon(
        onPressed: _navigateToViewVisits,
        icon: const Icon(Icons.directions_car, size: 16),
        label: const Text('View Visits'),
        style: FilledButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      );
    } else if (status == 'In Progress') {
      smartAction = FilledButton.icon(
        onPressed: _navigateToViewVisits,
        icon: const Icon(Icons.build, size: 16),
        label: const Text('View Active Visit'),
        style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      );
    } else if (status == 'Report Submitted' || status == 'Completed' || status == 'Resolved') {
      if (_isAdminOrCoordinator) {
        smartAction = FilledButton.icon(
          onPressed: _closeRequest,
          icon: const Icon(Icons.done_all, size: 16),
          label: const Text('Close Request'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            if (_isAdminOrCoordinator && status != 'Closed') ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
                  companyId: widget.companyId,
                  currentUserUid: widget.currentUserUid,
                  currentUserName: widget.currentUserName,
                  existingDocId: widget.requestId,
                  existingData: _requestData,
                ))).then((_) => _loadData()),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit Request'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              ),
            ],
            if (smartAction != null && _isAdminOrCoordinator) ...[
              const SizedBox(width: 12),
              smartAction,
            ]
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FULL SCREEN IMAGE VIEWER
// ==========================================

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer({required this.imageUrls, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Image ${_currentIndex + 1} of ${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (context, index) {
          final url = widget.imageUrls[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: url.startsWith('http')
                  ? Image.network(url, fit: BoxFit.contain, errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 64))
                  : const Icon(Icons.description, color: Colors.white, size: 100),
            ),
          );
        },
      ),
    );
  }
}