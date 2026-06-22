// FILE PATH: lib/modules/service/technicians/service_technician_list_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_service_technician_screen.dart';
import 'service_technician_details_screen.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================
String _safeString(dynamic val) => (val ?? '').toString().trim();

DateTime? _extractDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class ServiceTechnicianListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const ServiceTechnicianListScreen({
    Key? key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  }) : super(key: key);

  @override
  State<ServiceTechnicianListScreen> createState() => _ServiceTechnicianListScreenState();
}

class _ServiceTechnicianListScreenState extends State<ServiceTechnicianListScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Raw Data
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allUsers = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allVisits = [];

  // Processed Data
  List<Map<String, dynamic>> _technicians = [];
  Map<String, List<Map<String, dynamic>>> _technicianVisits = {};

  // KPI Data
  int _totalTechs = 0;
  int _totalAvailable = 0;
  int _totalBusy = 0;
  int _totalOnLeave = 0;
  int _opsPending = 0;
  int _opsCompletedToday = 0;

  // UI State
  String _searchQuery = '';
  bool _isTableView = false;
  Timer? _debounceTimer;

  // Filters
  String _availabilityFilter = 'All';
  String _designationFilter = 'All';
  String _skillFilter = 'All';

  // Derived Options
  List<String> _designations = ['All'];
  List<String> _skills = ['All'];

  // --- ROLE BASED ACCESS ---
  bool _isAdminOrManager = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkPermissions();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
          _isAdminOrManager = ['admin', 'superadmin', 'manager', 'coordinator', 'service manager', 'service coordinator'].contains(role);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _isTableView = prefs.getBool('erp_tech_view_pref') ?? false);
      }
    } catch (_) {}
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isTableView = !_isTableView);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('erp_tech_view_pref', _isTableView);
    } catch (_) {}
  }

  void _onSearch(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = query.toLowerCase().trim());
    });
  }

  // ==========================================
  // DATA FETCHING & PROCESSING
  // ==========================================
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users').where('isActive', isEqualTo: true).get(),
        FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').where('isDeleted', isEqualTo: false).get(),
      ]);

      _allUsers = results[0].docs;
      _allVisits = results[1].docs;

      _processData();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load technicians: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    final today = DateTime.now();

    _technicians.clear();
    _technicianVisits.clear();

    _totalTechs = 0;
    _totalAvailable = 0;
    _totalBusy = 0;
    _totalOnLeave = 0;
    _opsPending = 0;
    _opsCompletedToday = 0;

    Set<String> uniqueDesigs = {'All'};
    Set<String> uniqueSkills = {'All'};

    // 1. Build Technicians
    for (var userDoc in _allUsers) {
      final data = userDoc.data();
      final department = _safeString(data['department'] ?? data['departmentName']).toLowerCase();
      final designation = _safeString(data['designation'] ?? data['designationName']).toLowerCase();

      bool isServiceDept = department.contains('service');
      bool isTechOrEngineer = designation.contains('engineer') || designation.contains('technician');

      if (isServiceDept && isTechOrEngineer) {
        _technicians.add({'id': userDoc.id, ...data});
        _technicianVisits[userDoc.id] = [];
        _totalTechs++;

        final dStr = _safeString(data['designation'] ?? data['designationName']);
        if (dStr.isNotEmpty) uniqueDesigs.add(dStr);

        final sStr = _safeString(data['primarySkill']);
        if (sStr.isNotEmpty) uniqueSkills.add(sStr);
      }
    }

    _designations = uniqueDesigs.toList()..sort();
    _skills = uniqueSkills.toList()..sort();

    // 2. Map Visits
    for (var visitDoc in _allVisits) {
      final data = visitDoc.data();
      final assignedToUid = _safeString(data['assignedTechnicianUid'].toString().isNotEmpty ? data['assignedTechnicianUid'] : data['engineerUid']);
      final vDate = _extractDate(data['visitDate']);
      final status = _safeString(data['visitStatus']).isNotEmpty ? _safeString(data['visitStatus']) : _safeString(data['status']);

      bool isCompleted = status == 'Completed' || status == 'Resolved';
      bool isCancelled = status == 'Cancelled';
      bool isOpen = !isCompleted && !isCancelled;

      if (assignedToUid.isNotEmpty && _technicianVisits.containsKey(assignedToUid)) {
        final visitMap = {'id': visitDoc.id, ...data};
        _technicianVisits[assignedToUid]!.add(visitMap);

        if (isOpen) _opsPending++;
        if (isCompleted && vDate != null && vDate.year == today.year && vDate.month == today.month && vDate.day == today.day) {
          _opsCompletedToday++;
        }
      }
    }

    // 3. Compute Individual Status
    for (var tech in _technicians) {
      final visits = _technicianVisits[tech['id']] ?? [];

      int todayVisitsCount = 0;
      int openVisitsCount = 0;
      int completedVisitsCount = 0;
      Map<String, dynamic>? nextVisit;
      DateTime? closestFutureDate;

      for (var visit in visits) {
        final vDate = _extractDate(visit['visitDate']);
        final status = _safeString(visit['visitStatus']).isNotEmpty ? _safeString(visit['visitStatus']) : _safeString(visit['status']);

        bool isCompleted = status == 'Completed' || status == 'Resolved';
        bool isCancelled = status == 'Cancelled';
        bool isOpen = !isCompleted && !isCancelled;

        if (isOpen) openVisitsCount++;
        if (isCompleted) completedVisitsCount++;

        if (vDate != null) {
          if (vDate.year == today.year && vDate.month == today.month && vDate.day == today.day) todayVisitsCount++;
          if (vDate.isAfter(today) && isOpen) {
            if (closestFutureDate == null || vDate.isBefore(closestFutureDate)) {
              closestFutureDate = vDate;
              nextVisit = visit;
            }
          }
        }
      }

      String currentAvail = _safeString(tech['availabilityStatus']);
      DateTime? leaveFrom = _extractDate(tech['leaveFrom']);
      DateTime? leaveTo = _extractDate(tech['leaveTo']);

      if (leaveFrom != null && leaveTo != null) {
        final start = DateTime(leaveFrom.year, leaveFrom.month, leaveFrom.day);
        final end = DateTime(leaveTo.year, leaveTo.month, leaveTo.day, 23, 59, 59);
        if (today.compareTo(start) >= 0 && today.compareTo(end) <= 0) {
          currentAvail = 'On Leave';
        }
      }

      if (currentAvail.isEmpty || currentAvail == 'Available') {
        currentAvail = todayVisitsCount > 0 ? 'Busy' : 'Available';
      }

      if (currentAvail == 'Available') _totalAvailable++;
      else if (currentAvail == 'Busy') _totalBusy++;
      else if (currentAvail == 'On Leave') _totalOnLeave++;

      tech['calculated_status'] = currentAvail;
      tech['calculated_openVisits'] = openVisitsCount;
      tech['calculated_completedVisits'] = completedVisitsCount;
      tech['calculated_nextVisit'] = nextVisit;
    }
  }

  List<Map<String, dynamic>> _getFilteredTechnicians() {
    return _technicians.where((tech) {
      final name = _safeString(tech['name'] ?? tech['fullName'] ?? tech['employeeName']).toLowerCase();
      final phone = _safeString(tech['mobile'] ?? tech['mobileNumber'] ?? tech['phone']).toLowerCase();
      final territory = _safeString(tech['territory']).toLowerCase();
      final primarySkill = _safeString(tech['primarySkill']).toLowerCase();
      final designation = _safeString(tech['designation'] ?? tech['designationName']);

      bool matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          territory.contains(_searchQuery) ||
          primarySkill.contains(_searchQuery);

      bool matchesAvail = _availabilityFilter == 'All' || (tech['calculated_status'] as String).toLowerCase() == _availabilityFilter.toLowerCase();
      bool matchesDesig = _designationFilter == 'All' || designation == _designationFilter;
      bool matchesSkill = _skillFilter == 'All' || primarySkill == _skillFilter.toLowerCase();

      return matchesSearch && matchesAvail && matchesDesig && matchesSkill;
    }).toList();
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: Colors.grey.shade50, body: const Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(backgroundColor: Colors.grey.shade50, body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))));

    final filteredData = _getFilteredTechnicians();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          _buildKPIHeader(),
          _buildToolbar(),
          Expanded(
            child: filteredData.isEmpty ? _buildEmptyState() : _isTableView ? _buildTableView(filteredData) : _buildCardView(filteredData),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('Total Technicians', _totalTechs.toString(), Icons.engineering, Colors.blueGrey),
            _buildKpiCard('Available', _totalAvailable.toString(), Icons.check_circle, Colors.green),
            _buildKpiCard('Busy', _totalBusy.toString(), Icons.directions_car, Colors.orange),
            _buildKpiCard('On Leave', _totalOnLeave.toString(), Icons.event_busy, Colors.red),
            _buildKpiCard('Open Visits', _opsPending.toString(), Icons.pending_actions, Colors.blue),
            _buildKpiCard('Completed Today', _opsCompletedToday.toString(), Icons.task_alt, Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, MaterialColor color) {
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
          Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search technicians, territories, skills...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildDropdownFilter(_availabilityFilter, ['All', 'Available', 'Busy', 'On Leave', 'Inactive'], (val) => setState(() => _availabilityFilter = val!)),
          const SizedBox(width: 8),
          _buildDropdownFilter(_designationFilter, _designations, (val) => setState(() => _designationFilter = val!)),
          const SizedBox(width: 8),
          _buildDropdownFilter(_skillFilter, _skills, (val) => setState(() => _skillFilter = val!)),
          const SizedBox(width: 12),
          Container(
            height: 38,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: IconButton(icon: Icon(_isTableView ? Icons.grid_view : Icons.table_rows, size: 20), onPressed: _toggleViewMode, tooltip: 'Toggle View'),
          ),
        ],
      ),
    );
  }

  final TextEditingController _searchCtrl = TextEditingController();

  Widget _buildDropdownFilter(String value, List<String> options, ValueChanged<String?> onChanged) {
    String displayValue = options.contains(value) ? value : options.first;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: displayValue,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
          items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.engineering_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No technicians found', style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- CARD VIEW ---
  Widget _buildCardView(List<Map<String, dynamic>> data) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final tech = data[index];
        final name = _safeString(tech['name'] ?? tech['fullName'] ?? tech['employeeName']);
        final designation = _safeString(tech['designation'] ?? tech['designationName']);
        final mobile = _safeString(tech['mobile'] ?? tech['mobileNumber'] ?? tech['phone']);
        final pSkill = _safeString(tech['primarySkill']);
        final territory = _safeString(tech['territory']);
        final status = _safeString(tech['calculated_status']);
        final openVisits = tech['calculated_openVisits'] as int;
        final completedVisits = tech['calculated_completedVisits'] as int;
        final nextVisit = tech['calculated_nextVisit'] as Map<String, dynamic>?;

        String nextVisitStr = 'No upcoming visits';
        if (nextVisit != null) {
          final vd = _extractDate(nextVisit['visitDate']);
          if (vd != null) {
            nextVisitStr = '${DateFormat('MMM dd').format(vd)} - ${_safeString(nextVisit['customerName'])}';
          }
        }

        return Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: InkWell(
            onTap: () => _navigateToDetails(tech),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(designation.isEmpty ? 'Technician' : designation, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoChip(Icons.phone, mobile.isEmpty ? 'N/A' : mobile),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.map, territory.isEmpty ? 'Unassigned' : territory),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoChip(Icons.psychology, pSkill.isEmpty ? 'General' : pSkill),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Open: $openVisits', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          const SizedBox(height: 2),
                          Text('Completed: $completedVisits', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Next Visit', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 120,
                            child: Text(nextVisitStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_isAdminOrManager)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _navigateToEdit(tech),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, side: BorderSide(color: Colors.grey.shade300)),
                            child: const Text('Edit Profile', style: TextStyle(color: Colors.black87)),
                          ),
                        ),
                      if (_isAdminOrManager) const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _navigateToDetails(tech),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('View Details'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey.shade800), maxLines: 1, overflow: TextOverflow.ellipsis)),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: fg.withValues(alpha: 0.2))),
      child: Text(status.toUpperCase(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  // --- TABLE VIEW ---
  Widget _buildTableView(List<Map<String, dynamic>> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
            headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.blueGrey.shade700),
            columns: const [
              DataColumn(label: Text('NAME')),
              DataColumn(label: Text('DESIGNATION')),
              DataColumn(label: Text('SKILL')),
              DataColumn(label: Text('TERRITORY')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('OPEN')),
              DataColumn(label: Text('COMPLETED')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: data.map((tech) {
              final name = _safeString(tech['name'] ?? tech['fullName'] ?? tech['employeeName']);
              final designation = _safeString(tech['designation'] ?? tech['designationName']);
              final pSkill = _safeString(tech['primarySkill']);
              final territory = _safeString(tech['territory']);

              return DataRow(
                cells: [
                  DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text(designation.isEmpty ? '-' : designation)),
                  DataCell(Text(pSkill.isEmpty ? '-' : pSkill)),
                  DataCell(Text(territory.isEmpty ? '-' : territory)),
                  DataCell(_buildStatusBadge(tech['calculated_status'])),
                  DataCell(Text(tech['calculated_openVisits'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(tech['calculated_completedVisits'].toString())),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAdminOrManager)
                          IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey), onPressed: () => _navigateToEdit(tech)),
                        IconButton(icon: const Icon(Icons.visibility, size: 18, color: Colors.blue), onPressed: () => _navigateToDetails(tech)),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- NAVIGATION ---
  void _navigateToDetails(Map<String, dynamic> tech) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ServiceTechnicianDetailsScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        userId: tech['id'],
        technicianData: tech,
      )),
    );
  }

  void _navigateToEdit(Map<String, dynamic> tech) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddServiceTechnicianScreen(
        companyId: widget.companyId,
        userId: tech['id'],
        existingData: tech,
      )),
    ).then((_) => _loadData());
  }
}