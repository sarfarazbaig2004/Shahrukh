// FILE PATH: lib/modules/service/service_visits/service_visit_details_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_service_visit_screen.dart';
import 'upload_service_report_screen.dart';
import '../service_requests/service_request_details_screen.dart';
import '../service_technicians/service_technician_details_screen.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

String _safeString(dynamic val) {
  return (val ?? '').toString().trim();
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

bool _isOverdue(DateTime? visitDate, String status) {
  if (visitDate == null) return false;
  if (status == 'Completed' || status == 'Resolved' || status == 'Cancelled') return false;
  final today = DateTime.now();
  final vDate = DateTime(visitDate.year, visitDate.month, visitDate.day);
  final tDate = DateTime(today.year, today.month, today.day);
  return vDate.isBefore(tDate);
}

// ==========================================
// MAIN DETAILS SCREEN
// ==========================================

class ServiceVisitDetailsScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String visitId;
  final Map<String, dynamic> visitData;

  const ServiceVisitDetailsScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.visitId,
    required this.visitData,
  });

  @override
  State<ServiceVisitDetailsScreen> createState() => _ServiceVisitDetailsScreenState();
}

class _ServiceVisitDetailsScreenState extends State<ServiceVisitDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdminOrCoordinator = false;
  bool _isLoadingDependencies = true;
  Map<String, dynamic>? _requestData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDependencies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDependencies() async {
    try {
      final db = FirebaseFirestore.instance;
      final reqId = _safeString(widget.visitData['requestId']);

      Future<DocumentSnapshot<Map<String, dynamic>>?> reqFuture = reqId.isNotEmpty
          ? db.collection('companies').doc(widget.companyId).collection('service_requests').doc(reqId).get()
          : Future.value(null);

      final userFuture = db.collection('companies').doc(widget.companyId).collection('users').doc(widget.currentUserUid).get();

      final results = await Future.wait([userFuture, reqFuture]);

      final userDoc = results[0];
      final reqDoc = results[1];

      if (mounted) {
        setState(() {
          if (userDoc != null && userDoc.exists) {
            final role = _safeString(userDoc.data()?['role']).toLowerCase();
            _isAdminOrCoordinator = ['admin', 'superadmin', 'manager', 'coordinator', 'service manager', 'service coordinator'].contains(role);
          }
          if (reqDoc != null && reqDoc.exists) {
            _requestData = reqDoc.data();
          }
          _isLoadingDependencies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDependencies = false;
        });
      }
    }
  }

  // --- ACTIONS ---

  Future<void> _startTravel(Map<String, dynamic> data) async {
    try {
      final visitRef = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').doc(widget.visitId);

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

  Future<void> _startService(Map<String, dynamic> data) async {
    try {
      final visitRef = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').doc(widget.visitId);
      final reqId = _safeString(data['requestId']);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(visitRef, {
          'visitStatus': 'In Progress',
          'visitStartedAt': FieldValue.serverTimestamp(),
          'visitStartedByUid': widget.currentUserUid,
          'visitStartedByName': widget.currentUserName,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': widget.currentUserUid,
        });

        if (reqId.isNotEmpty) {
          final reqRef = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_requests').doc(reqId);
          transaction.set(reqRef, {
            'status': 'In Progress',
            'visitStartedAt': FieldValue.serverTimestamp(),
            'lastActivity': 'Service Started',
            'lastActivityAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': widget.currentUserUid,
          }, SetOptions(merge: true));
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Started Successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _uploadReport(Map<String, dynamic> data) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UploadServiceReportScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        visitId: widget.visitId,
        visitData: data,
      )),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _openParentRequest(Map<String, dynamic> data) {
    final reqId = _safeString(data['requestId']);
    if (reqId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request ID missing.'), backgroundColor: Colors.red));
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

  // --- UI COMPONENTS ---

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(priority, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      width: 150,
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

  Widget _buildDetailSection(String title, Map<String, dynamic> fields, {Widget? action}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
        ],
        ...fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map(
                (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 150, child: Text(e.key, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87))),
                ],
              ),
            )
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').doc(widget.visitId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
          if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final data = snapshot.data?.data() ?? widget.visitData;

          final visitNo = _safeString(data['visitNo']);
          final requestNo = _safeString(data['requestNumber']);
          final customerName = _safeString(data['customerName']);
          final status = _safeString(data['visitStatus']).isNotEmpty ? _safeString(data['visitStatus']) : _safeString(data['status']);
          final priority = _safeString(data['priority']);
          final visitDate = _extractDate(data['visitDate']);
          final isOverdue = _isOverdue(visitDate, status);

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, true),
              ),
              title: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(requestNo.isNotEmpty ? requestNo : 'Unknown Request', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(visitNo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      Text(customerName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  _buildStatusBadge(status),
                  const SizedBox(width: 8),
                  if (priority.isNotEmpty) _buildPriorityBadge(priority),
                  const SizedBox(width: 8),
                  if (isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
                      child: Text('Overdue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(() {});
                  },
                ),
                if (_isAdminOrCoordinator && !_isLoadingDependencies)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
                        companyId: widget.companyId,
                        currentUserUid: widget.currentUserUid,
                        currentUserName: widget.currentUserName,
                        existingDocId: widget.visitId,
                        existingData: data,
                      ))),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Visit'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey, textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.indigo,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: 'OVERVIEW'),
                  Tab(text: 'TIMELINE'),
                  Tab(text: 'REPORT IMAGES'),
                  Tab(text: 'ATTACHMENTS'),
                ],
              ),
            ),
            body: Column(
              children: [
                // KPI BANNER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildKpiCard('Visit Type', _safeString(data['visitType']), Icons.category, Colors.indigo),
                        _buildKpiCard('Warranty Status', _safeString(data['warrantyStatus']).isNotEmpty ? _safeString(data['warrantyStatus']) : 'Unknown', Icons.verified_user, Colors.green),
                        _buildKpiCard('Assigned Tech', _safeString(data['assignedTechnicianName']).isNotEmpty ? _safeString(data['assignedTechnicianName']) : _safeString(data['engineerName']), Icons.engineering, Colors.blue),
                        _buildKpiCard('Machine Count', _safeInt(data['machineCount']).toString(), Icons.settings, Colors.orange),
                        _buildKpiCard('Scheduled Date', _formatDateOnly(visitDate), Icons.calendar_month, Colors.teal),
                        _buildKpiCard('Duration', _safeString(data['expectedDuration']), Icons.timer, Colors.purple),
                      ],
                    ),
                  ),
                ),

                // TABS
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(data),
                      _buildTimelineTab(data),
                      _buildReportImagesTab(data),
                      _buildAttachmentsTab(data),
                    ],
                  ),
                ),

                // BOTTOM ACTIONS
                _buildBottomActions(data, status),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParentRequestCard(Map<String, dynamic> visitData) {
    final reqNo = _safeString(visitData['requestNumber']);
    final custName = _safeString(visitData['customerName']);
    final priority = _safeString(visitData['priority']);
    final complaint = _safeString(visitData['complaintDescription']);

    final reqStatus = _requestData != null ? _safeString(_requestData!['status']) : 'Unknown';
    final reqCreated = _requestData != null ? _formatDateOnly(_extractDate(_requestData!['createdAt'])) : '-';

    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assignment, size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text('Parent Request: $reqNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              _buildMiniInfo('Customer', custName),
                              _buildMiniInfo('Status', reqStatus),
                              _buildMiniInfo('Priority', priority),
                              _buildMiniInfo('Created Date', reqCreated),
                            ]
                        ),
                        const SizedBox(height: 12),
                        Text('Complaint: $complaint', style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontStyle: FontStyle.italic)),
                      ]
                  )
              ),
              FilledButton.icon(
                onPressed: () => _openParentRequest(visitData),
                icon: const Icon(Icons.launch, size: 16),
                label: const Text('Open Request'),
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
              )
            ]
        )
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildBottomActions(Map<String, dynamic> data, String status) {
    Widget? smartAction;

    if (status == 'Scheduled' || status == 'New') {
      smartAction = FilledButton.icon(
        icon: const Icon(Icons.directions_car, size: 20),
        label: const Text('Start Travel'),
        style: FilledButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: () => _startTravel(data),
      );
    } else if (status == 'Travel Started') {
      smartAction = FilledButton.icon(
        icon: const Icon(Icons.play_arrow, size: 20),
        label: const Text('Start Service'),
        style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: () => _startService(data),
      );
    } else if (status == 'In Progress') {
      smartAction = FilledButton.icon(
        icon: const Icon(Icons.upload_file, size: 20),
        label: const Text('Upload Report'),
        style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: () => _uploadReport(data),
      );
    } else if (status == 'Completed' || status == 'Resolved') {
      smartAction = OutlinedButton.icon(
        icon: const Icon(Icons.photo_library, size: 20),
        label: const Text('View Report Images'),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: () => _tabController.animateTo(2),
      );
    }

    return Container(
      width: double.infinity,
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
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back To Request'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openParentRequest(data),
              icon: const Icon(Icons.launch, size: 16),
              label: const Text('Open Request'),
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (smartAction != null && status != 'Cancelled') ...[
              const SizedBox(width: 12),
              smartAction,
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> data) {
    final mNames = data['machineNames'] is List ? List<String>.from(data['machineNames']).join(", ") : _safeString(data['machineNames']);
    final reqParts = data['partsRequired'] is List ? List<Map<String, dynamic>>.from(data['partsRequired']) : [];

    final assignedUid = _safeString(data['assignedTechnicianUid']).isNotEmpty ? _safeString(data['assignedTechnicianUid']) : _safeString(data['engineerUid']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParentRequestCard(data),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: _buildDetailSection('Machine Information', {
                        'Machine Names': mNames,
                        'Machine Count': data['machineCount']?.toString(),
                        'Serial Numbers': data['serialNumber'] ?? data['serialNumbers'],
                        'Category': data['category'] ?? data['complaintCategory'],
                        'Warranty Status': data['warrantyStatus'],
                        'Installation Date': _formatDateOnly(_extractDate(data['installationDate'])),
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: _buildDetailSection('Technician Information', {
                        'Assigned Technician': _safeString(data['assignedTechnicianName']).isNotEmpty ? data['assignedTechnicianName'] : data['engineerName'],
                        'Mobile': data['assignedTechnicianMobile'],
                        'Department': 'Service',
                        'Designation': 'Service Engineer / Technician',
                      }, action: assignedUid.isNotEmpty ? OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceTechnicianDetailsScreen(
                            companyId: widget.companyId,
                            currentUserUid: widget.currentUserUid,
                            currentUserName: widget.currentUserName,
                            userId: assignedUid,
                            technicianData: {'id': assignedUid, 'name': _safeString(data['assignedTechnicianName'])}
                        ))),
                        icon: const Icon(Icons.person_pin, size: 16),
                        label: const Text('Technician 360'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ) : null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailSection('Complaint & Visit Logic', {
                        'Complaint Description': data['complaintDescription'],
                        'Priority': data['priority'],
                        'Service Type': data['visitType'],
                        'Remarks': data['remarks'],
                        'Internal Notes': data['internalNotes'],
                      }),
                    ),
                  ],
                ),
              ),
              if (reqParts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Required Parts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
                      const SizedBox(height: 16),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade50),
                            children: const [
                              Padding(padding: EdgeInsets.all(8), child: Text('Part Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          ...reqParts.map((p) => TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(p['partName']))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(p['quantity']))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(_safeString(p['remarks']))),
                            ],
                          ))
                        ],
                      )
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineTab(Map<String, dynamic> data) {
    final tsReqCreated = _requestData != null ? _formatDateTime(_extractDate(_requestData!['createdAt'])) : '-';
    final tsCreated = _formatDateTime(data['createdAt']);
    final tsTravel = _formatDateTime(data['travelStartedAt']);
    final tsStarted = _formatDateTime(data['visitStartedAt']);
    final tsReport = _formatDateTime(data['reportSubmittedAt'] ?? data['completedAt']);
    final tsCompleted = _formatDateTime(data['completedAt']);

    final status = _safeString(data['visitStatus']).isNotEmpty ? _safeString(data['visitStatus']) : _safeString(data['status']);

    bool isVisitCreated = true;
    bool isTravel = status == 'Travel Started' || status == 'In Progress' || status == 'Report Submitted' || status == 'Completed' || status == 'Resolved' || status == 'Closed';
    bool isStarted = status == 'In Progress' || status == 'Report Submitted' || status == 'Completed' || status == 'Resolved' || status == 'Closed';
    bool isReport = status == 'Report Submitted' || status == 'Completed' || status == 'Resolved' || status == 'Closed';
    bool isCompleted = status == 'Completed' || status == 'Resolved' || status == 'Closed';

    final stages = [
      {'label': 'Request Created', 'active': _requestData != null, 'time': tsReqCreated},
      {'label': 'Visit Scheduled', 'active': isVisitCreated, 'time': tsCreated},
      {'label': 'Travel Started', 'active': isTravel, 'time': tsTravel},
      {'label': 'Service Started', 'active': isStarted, 'time': tsStarted},
      {'label': 'Report Uploaded', 'active': isReport, 'time': tsReport},
      {'label': 'Completed', 'active': isCompleted, 'time': tsCompleted},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Visit Lifecycle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        style: TextStyle(fontSize: 13, color: active ? Colors.grey.shade800 : Colors.grey.shade400, fontWeight: active ? FontWeight.bold : FontWeight.normal),
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
                            style: TextStyle(fontSize: 16, color: active ? Colors.black87 : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal)
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

  Widget _buildReportImagesTab(Map<String, dynamic> data) {
    final images = data['reportImages'] is List ? List<dynamic>.from(data['reportImages']) : [];

    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No report uploaded', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // Standardize structure for safe parsing
    final parsedImages = images.map((img) {
      if (img is String) {
        return {'url': img, 'uploadedAt': data['completedAt'] ?? data['updatedAt'], 'uploadedByName': 'Unknown'};
      } else if (img is Map) {
        return img;
      }
      return {'url': '', 'uploadedAt': null, 'uploadedByName': 'Unknown'};
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Images (${parsedImages.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: parsedImages.asMap().entries.map((entry) {
              final idx = entry.key;
              final imgData = entry.value;
              final url = _safeString(imgData['url']);
              final uName = _safeString(imgData['uploadedByName']);
              final ts = _formatDateTime(imgData['uploadedAt']);

              return InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImageViewer(
                    imageUrls: parsedImages.map((e) => _safeString(e['url'])).toList(),
                    initialIndex: idx,
                  )));
                },
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          color: Colors.grey.shade100,
                          child: url.startsWith('http')
                              ? Image.network(url, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey))
                              : const Icon(Icons.description, size: 50, color: Colors.grey),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Expanded(child: Text(uName.isEmpty ? 'System' : uName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Expanded(child: Text(ts, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsTab(Map<String, dynamic> data) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.attachment, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No external attachments found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Check Reports tab for visit execution documents.', style: TextStyle(color: Colors.grey)),
        ],
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