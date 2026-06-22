// FILE PATH: lib/modules/service/technicians/service_technician_details_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'add_service_technician_screen.dart';
import '../service_visits/service_visit_details_screen.dart';
import '../service_requests/service_request_details_screen.dart';

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

// ==========================================
// MAIN SCREEN
// ==========================================

class ServiceTechnicianDetailsScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String userId;
  final Map<String, dynamic> technicianData;

  const ServiceTechnicianDetailsScreen({
    Key? key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.userId,
    required this.technicianData,
  }) : super(key: key);

  @override
  State<ServiceTechnicianDetailsScreen> createState() => _ServiceTechnicianDetailsScreenState();
}

class _ServiceTechnicianDetailsScreenState extends State<ServiceTechnicianDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isAdminOrCoordinator = false;

  // Data State
  late Map<String, dynamic> _userData;
  List<Map<String, dynamic>> _assignedVisits = [];
  List<Map<String, dynamic>> _completedVisits = [];
  List<Map<String, dynamic>> _assignedRequests = [];

  // KPI State
  int _openVisitsCount = 0;
  int _completedVisitsCount = 0;
  int _upcomingVisitsCount = 0;
  int _thisMonthVisitsCount = 0;

  int _openRequestsCount = 0;
  int _completedRequestsCount = 0;

  // Timeline State
  DateTime? _lastAssignedVisitDate;
  DateTime? _lastCompletedVisitDate;
  DateTime? _lastAssignedRequestDate;

  // Dynamic Status
  String _currentStatus = 'Available';

  @override
  void initState() {
    super.initState();
    _userData = widget.technicianData;
    _tabController = TabController(length: 7, vsync: this);
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

      // Fetch fresh user data and visits concurrently
      final results = await Future.wait([
        db.collection('companies').doc(widget.companyId).collection('users').doc(widget.userId).get(),
        db.collection('companies').doc(widget.companyId).collection('service_visits').where('isDeleted', isEqualTo: false).get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final visitsQuery = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (userDoc.exists && userDoc.data() != null) {
        _userData = userDoc.data()!;
      }

      _assignedVisits.clear();
      _completedVisits.clear();
      _assignedRequests.clear();

      _openVisitsCount = 0;
      _completedVisitsCount = 0;
      _upcomingVisitsCount = 0;
      _thisMonthVisitsCount = 0;

      _openRequestsCount = 0;
      _completedRequestsCount = 0;

      _lastAssignedVisitDate = null;
      _lastCompletedVisitDate = null;
      _lastAssignedRequestDate = null;

      final today = DateTime.now();

      // Temporary map to collect request IDs and their states
      Map<String, Map<String, dynamic>> requestsMap = {};

      for (var doc in visitsQuery.docs) {
        final data = doc.data();
        final assignedUid = _safeString(data['assignedTechnicianUid']).isNotEmpty
            ? _safeString(data['assignedTechnicianUid'])
            : _safeString(data['engineerUid']);

        if (assignedUid != widget.userId) continue;

        final visitMap = {'id': doc.id, ...data};
        final status = _safeString(data['visitStatus']).isNotEmpty ? _safeString(data['visitStatus']) : _safeString(data['status']);
        final vDate = _extractDate(data['visitDate']);
        final reqId = _safeString(data['requestId']);

        bool isCompleted = status == 'Completed' || status == 'Resolved';
        bool isCancelled = status == 'Cancelled';
        bool isOpen = !isCompleted && !isCancelled;

        if (isOpen) {
          _assignedVisits.add(visitMap);
          _openVisitsCount++;
          if (vDate != null) {
            if (vDate.isAfter(today)) _upcomingVisitsCount++;
            if (_lastAssignedVisitDate == null || vDate.isAfter(_lastAssignedVisitDate!)) {
              _lastAssignedVisitDate = vDate;
            }
          }
        } else if (isCompleted) {
          _completedVisits.add(visitMap);
          _completedVisitsCount++;
          if (vDate != null) {
            if (_lastCompletedVisitDate == null || vDate.isAfter(_lastCompletedVisitDate!)) {
              _lastCompletedVisitDate = vDate;
            }
          }
        }

        if (vDate != null && vDate.year == today.year && vDate.month == today.month) {
          _thisMonthVisitsCount++;
        }

        // Aggregate Requests
        if (reqId.isNotEmpty) {
          if (!requestsMap.containsKey(reqId)) {
            requestsMap[reqId] = {
              'id': reqId,
              'requestNumber': _safeString(data['requestNumber']),
              'customerName': _safeString(data['customerName']),
              'priority': _safeString(data['priority']),
              'openVisits': 0,
              'completedVisits': 0,
              'lastVisitDate': vDate,
              'status': 'Open', // Derived default
            };
          }

          if (isOpen) {
            requestsMap[reqId]!['openVisits'] = (requestsMap[reqId]!['openVisits'] as int) + 1;
          } else if (isCompleted) {
            requestsMap[reqId]!['completedVisits'] = (requestsMap[reqId]!['completedVisits'] as int) + 1;
          }

          DateTime? currentLast = requestsMap[reqId]!['lastVisitDate'] as DateTime?;
          if (vDate != null && (currentLast == null || vDate.isAfter(currentLast))) {
            requestsMap[reqId]!['lastVisitDate'] = vDate;
          }
        }
      }

      // Determine Request Statuses and Final Lists
      for (var req in requestsMap.values) {
        int open = req['openVisits'] as int;
        int completed = req['completedVisits'] as int;
        DateTime? lastV = req['lastVisitDate'] as DateTime?;

        if (open > 0) {
          req['status'] = 'Open';
          _openRequestsCount++;
        } else {
          req['status'] = 'Completed';
          _completedRequestsCount++;
        }

        if (lastV != null && (_lastAssignedRequestDate == null || lastV.isAfter(_lastAssignedRequestDate!))) {
          _lastAssignedRequestDate = lastV;
        }

        _assignedRequests.add(req);
      }

      // Sort lists
      _assignedVisits.sort((a, b) {
        final aDate = _extractDate(a['visitDate']) ?? DateTime(2000);
        final bDate = _extractDate(b['visitDate']) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      _completedVisits.sort((a, b) {
        final aDate = _extractDate(a['visitDate']) ?? DateTime(2000);
        final bDate = _extractDate(b['visitDate']) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      _assignedRequests.sort((a, b) {
        final aDate = a['lastVisitDate'] as DateTime? ?? DateTime(2000);
        final bDate = b['lastVisitDate'] as DateTime? ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      // Calculate Availability
      _currentStatus = _safeString(_userData['availabilityStatus']);
      if (_currentStatus.isEmpty) _currentStatus = 'Available';

      final leaveFrom = _extractDate(_userData['leaveFrom']);
      final leaveTo = _extractDate(_userData['leaveTo']);

      if (leaveFrom != null && leaveTo != null) {
        final start = DateTime(leaveFrom.year, leaveFrom.month, leaveFrom.day);
        final end = DateTime(leaveTo.year, leaveTo.month, leaveTo.day, 23, 59, 59);
        if (today.isAfter(start.subtract(const Duration(milliseconds: 1))) && today.isBefore(end)) {
          _currentStatus = 'On Leave';
        }
      } else if (_currentStatus == 'Available' && _openVisitsCount > 0) {
        _currentStatus = 'Busy';
      }

    } catch (e) {
      debugPrint('Error loading technician details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Colors.grey.shade50, body: const Center(child: CircularProgressIndicator()));
    }

    final name = _safeString(_userData['name'] ?? _userData['fullName'] ?? _userData['employeeName']);
    final designation = _safeString(_userData['designation'] ?? _userData['designationName']);
    final territory = _safeString(_userData['territory']);
    final primarySkill = _safeString(_userData['primarySkill']);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    _buildStatusBadge(_currentStatus),
                  ],
                ),
                Text(designation.isNotEmpty ? designation : 'Technician', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(width: 16),
            if (territory.isNotEmpty) _buildHeaderChip(Icons.map, territory),
            const SizedBox(width: 8),
            if (primarySkill.isNotEmpty) _buildHeaderChip(Icons.psychology, primarySkill),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh'),
          if (_isAdminOrCoordinator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceTechnicianScreen(
                  companyId: widget.companyId,
                  userId: widget.userId,
                  existingData: _userData,
                ))).then((_) => _loadData()),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit Profile'),
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
            )
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
            Tab(text: 'ASSIGNED VISITS'),
            Tab(text: 'COMPLETED VISITS'),
            Tab(text: 'ASSIGNED REQUESTS'),
            Tab(text: 'SKILLS & CERTS'),
            Tab(text: 'LEAVE HISTORY'),
            Tab(text: 'TIMELINE'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildKpiBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildVisitsTab(true),
                _buildVisitsTab(false),
                _buildRequestsTab(),
                _buildSkillsTab(),
                _buildLeaveTab(),
                _buildTimelineTab(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    final s = status.toLowerCase();

    if (s == 'available') { bg = Colors.green.shade50; fg = Colors.green.shade700; }
    else if (s == 'busy') { bg = Colors.orange.shade50; fg = Colors.orange.shade800; }
    else if (s == 'on leave') { bg = Colors.red.shade50; fg = Colors.red.shade700; }
    else if (s == 'open') { bg = Colors.blue.shade50; fg = Colors.blue.shade800; }
    else if (s == 'completed') { bg = Colors.green.shade50; fg = Colors.green.shade800; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildKpiBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('Open Visits', _openVisitsCount.toString(), Icons.pending_actions, Colors.blue),
            _buildKpiCard('Completed', _completedVisitsCount.toString(), Icons.task_alt, Colors.green),
            _buildKpiCard('Upcoming', _upcomingVisitsCount.toString(), Icons.event_available, Colors.orange),
            _buildKpiCard('Month Vol.', _thisMonthVisitsCount.toString(), Icons.calendar_month, Colors.purple),
            _buildKpiCard('Experience', '${_safeInt(_userData['experienceYears'])} Yrs', Icons.star, Colors.indigo),
            _buildKpiCard('Daily Cap.', '${_safeInt(_userData['dailyCapacity'] ?? 3)}', Icons.view_day, Colors.blueGrey),
            _buildKpiCard('Monthly Cap.', '${_safeInt(_userData['monthlyCapacity'] ?? 60)}', Icons.date_range, Colors.teal),
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
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    child: _buildSectionCard('Basic Information', {
                      'Name': _safeString(_userData['name'] ?? _userData['fullName'] ?? _userData['employeeName']),
                      'Mobile': _safeString(_userData['mobile'] ?? _userData['mobileNumber'] ?? _userData['phone']),
                      'Email': _safeString(_userData['email']),
                      'Department': _safeString(_userData['department'] ?? _userData['departmentName']),
                      'Designation': _safeString(_userData['designation'] ?? _userData['designationName']),
                      'Employee Code': _safeString(_userData['employeeCode'] ?? _userData['empCode']),
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSectionCard('Territory & Region', {
                      'Primary Territory': _safeString(_userData['territory']),
                      'Service Region': _safeString(_userData['serviceRegion']),
                      'Secondary Territories': _userData['secondaryTerritories'] is List ? (_userData['secondaryTerritories'] as List).join(', ') : '',
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSectionCard('Availability Configuration', {
                      'Current Status': _currentStatus,
                      'Daily Capacity': '${_safeInt(_userData['dailyCapacity'] ?? 3)} Visits',
                      'Monthly Capacity': '${_safeInt(_userData['monthlyCapacity'] ?? 60)} Visits',
                      'Working Days': _userData['workingDays'] is List ? (_userData['workingDays'] as List).join(', ') : '',
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSectionCard('Performance Metrics', {
                      'Total Assigned Requests': _assignedRequests.length.toString(),
                      'Open Requests': _openRequestsCount.toString(),
                      'Completed Requests': _completedRequestsCount.toString(),
                      'Open Visits': _openVisitsCount.toString(),
                      'Completed Visits': _completedVisitsCount.toString(),
                    }),
                  ),
                ],
              ),
              if (_safeString(_userData['remarks']).isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionCard('Internal Remarks', {
                  'Notes': _safeString(_userData['remarks'])
                }),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisitsTab(bool isOpen) {
    final list = isOpen ? _assignedVisits : _completedVisits;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isOpen ? 'No assigned visits.' : 'No completed visits.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final v = list[index];
        final visitNo = _safeString(v['visitNo']);
        final customer = _safeString(v['customerName']);
        final machine = _safeString(v['machineName']);
        final status = _safeString(v['visitStatus']).isNotEmpty ? _safeString(v['visitStatus']) : _safeString(v['status']);
        final priority = _safeString(v['priority']);

        final vDate = _extractDate(v['visitDate']);
        final timeStr = _safeString(v['visitTime']);

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
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
                          Text(visitNo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13)),
                          const SizedBox(width: 8),
                          _buildVisitStatusBadge(status),
                          const SizedBox(width: 8),
                          if (priority.isNotEmpty) _buildPriorityBadge(priority),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      if (machine.isNotEmpty) Text(machine, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatDateOnly(vDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (timeStr.isNotEmpty) Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceVisitDetailsScreen(
                        companyId: widget.companyId,
                        currentUserUid: widget.currentUserUid,
                        currentUserName: widget.currentUserName,
                        visitId: v['id'],
                        visitData: v,
                      ))).then((_) => _loadData()),
                      icon: const Icon(Icons.visibility, size: 14),
                      label: Text(isOpen ? 'View / Execute' : 'View Details'),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12)),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    if (_assignedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No requests assigned.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _assignedRequests.length,
      itemBuilder: (context, index) {
        final req = _assignedRequests[index];
        final reqNo = _safeString(req['requestNumber']);
        final customer = _safeString(req['customerName']);
        final status = _safeString(req['status']);
        final priority = _safeString(req['priority']);
        final openVisits = _safeInt(req['openVisits']);
        final completedVisits = _safeInt(req['completedVisits']);
        final lastDate = req['lastVisitDate'] as DateTime?;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.assignment, color: Colors.indigo)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(reqNo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13)),
                          const SizedBox(width: 8),
                          _buildStatusBadge(status),
                          const SizedBox(width: 8),
                          if (priority.isNotEmpty) _buildPriorityBadge(priority),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Visits: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text('$openVisits Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                          Text(' | ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                          Text('$completedVisits Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      )
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Last Visit', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(_formatDateOnly(lastDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestDetailsScreen(
                        companyId: widget.companyId,
                        currentUserUid: widget.currentUserUid,
                        currentUserName: widget.currentUserName,
                        requestId: req['id'],
                        requestData: req,
                      ))).then((_) => _loadData()),
                      icon: const Icon(Icons.launch, size: 14),
                      label: const Text('Request 360'),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: Colors.blueGrey, textStyle: const TextStyle(fontSize: 12)),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisitStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;

    switch (status) {
      case 'Scheduled': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'Travel Started': bg = Colors.purple.shade50; fg = Colors.purple.shade800; break;
      case 'In Progress': bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Completed':
      case 'Resolved': bg = Colors.green.shade50; fg = Colors.green.shade800; break;
      case 'Cancelled': bg = Colors.red.shade50; fg = Colors.red.shade800; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color = Colors.grey;
    switch (priority) {
      case 'Critical': color = Colors.red.shade700; break;
      case 'High': color = Colors.orange.shade700; break;
      case 'Medium': color = Colors.blue.shade700; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(priority, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildSkillsTab() {
    List<String> secSkills = _userData['secondarySkillsList'] is List
        ? List<String>.from(_userData['secondarySkillsList'])
        : (_safeString(_userData['secondarySkills']).isNotEmpty ? _safeString(_userData['secondarySkills']).split(',').map((e) => e.trim()).toList() : []);

    List<String> certs = _userData['certifications'] is List ? List<String>.from(_userData['certifications']) : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard('Primary Skill & Experience', {
                'Primary Skill': _safeString(_userData['primarySkill']),
                'Experience': '${_safeInt(_userData['experienceYears'])} Years',
              }),
              const SizedBox(height: 16),
              if (secSkills.isNotEmpty) ...[
                const Text('Secondary Skills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: secSkills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.blue.shade50, side: BorderSide(color: Colors.blue.shade100))).toList(),
                ),
                const SizedBox(height: 24),
              ],
              if (certs.isNotEmpty) ...[
                const Text('Certifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: certs.map((c) => Chip(avatar: const Icon(Icons.verified, color: Colors.green, size: 16), label: Text(c, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.green.shade50, side: BorderSide(color: Colors.green.shade200))).toList(),
                ),
                const SizedBox(height: 24),
              ],
              const Text('Service Capabilities', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  if (_userData['canHandleInstallation'] == true) _buildCapabilityChip('Installation'),
                  if (_userData['canHandleBreakdown'] == true) _buildCapabilityChip('Breakdown'),
                  if (_userData['canHandlePM'] == true) _buildCapabilityChip('Preventive Maintenance'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilityChip(String label) {
    return Chip(
      avatar: const Icon(Icons.check_circle, color: Colors.indigo, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.indigo.shade200),
    );
  }

  Widget _buildLeaveTab() {
    final leaveFrom = _extractDate(_userData['leaveFrom']);
    final leaveTo = _extractDate(_userData['leaveTo']);
    final reason = _safeString(_userData['leaveReason']);

    if (leaveFrom == null || leaveTo == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.green.shade200),
            const SizedBox(height: 16),
            Text('No active or upcoming leave scheduled.', style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final duration = leaveTo.difference(leaveFrom).inDays + 1;
    final isCurrentlyOnLeave = _currentStatus == 'On Leave';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isCurrentlyOnLeave ? Colors.red.shade200 : Colors.orange.shade200)),
            color: isCurrentlyOnLeave ? Colors.red.shade50 : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isCurrentlyOnLeave ? Icons.event_busy : Icons.edit_calendar, size: 28, color: isCurrentlyOnLeave ? Colors.red.shade700 : Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Text(isCurrentlyOnLeave ? 'Currently On Leave' : 'Upcoming Leave Scheduled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCurrentlyOnLeave ? Colors.red.shade900 : Colors.orange.shade900)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildDetailSection('', { 'Leave From': _formatDateOnly(leaveFrom) })),
                      Expanded(child: _buildDetailSection('', { 'Leave To': _formatDateOnly(leaveTo) })),
                      Expanded(child: _buildDetailSection('', { 'Duration': '$duration Days' })),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Reason / Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade800)),
                    const SizedBox(height: 4),
                    Text(reason, style: const TextStyle(fontSize: 14)),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineTab() {
    final tsCreated = _formatDateTime(_extractDate(_userData['createdAt']));
    final tsUpdated = _formatDateTime(_extractDate(_userData['updatedAt']));
    final tsLastReq = _formatDateTime(_lastAssignedRequestDate);
    final tsLastVisit = _formatDateTime(_lastAssignedVisitDate);
    final tsLastCompleted = _formatDateTime(_lastCompletedVisitDate);

    final stages = [
      {'label': 'Profile Created', 'time': tsCreated},
      {'label': 'Last Profile Update', 'time': tsUpdated},
      {'label': 'Last Request Assigned', 'time': tsLastReq},
      {'label': 'Last Visit Assigned', 'time': tsLastVisit},
      {'label': 'Last Visit Completed', 'time': tsLastCompleted},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Technician Activity Lifecycle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ...stages.asMap().entries.map((entry) {
                int idx = entry.key;
                var stage = entry.value;
                String timeStr = stage['time'] as String;
                bool isLast = idx == stages.length - 1;
                bool active = timeStr != '-';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: Text(
                        active ? timeStr : 'N/A',
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
                            color: active ? Colors.indigo : Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(color: active ? Colors.indigo.shade700 : Colors.grey.shade300, width: 2),
                          ),
                          child: active ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                        if (!isLast)
                          Container(
                            width: 3, height: 50,
                            color: active ? Colors.indigo : Colors.grey.shade200,
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

  Widget _buildDetailSection(String title, Map<String, dynamic> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
          const SizedBox(height: 12),
        ],
        ...fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map(
                (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87)),
                ],
              ),
            )
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
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
              label: const Text('Refresh Data'),
            ),
            if (_isAdminOrCoordinator) ...[
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceTechnicianScreen(
                  companyId: widget.companyId,
                  userId: widget.userId,
                  existingData: _userData,
                ))).then((_) => _loadData()),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
            ]
          ],
        ),
      ),
    );
  }
}