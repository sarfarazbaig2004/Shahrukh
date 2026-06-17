import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'add_service_technician_screen.dart';

class ServiceTechnicianListScreen extends StatefulWidget {
  final String companyId;

  const ServiceTechnicianListScreen({Key? key, required this.companyId})
      : super(key: key);

  @override
  State<ServiceTechnicianListScreen> createState() =>
      _ServiceTechnicianListScreenState();
}

class _ServiceTechnicianListScreenState
    extends State<ServiceTechnicianListScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Raw Data
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allUsers = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allVisits = [];

  // Filtered & Processed Data
  List<Map<String, dynamic>> _technicians = [];
  Map<String, List<Map<String, dynamic>>> _technicianVisits = {};

  // Dashboard Analytics Data
  List<Map<String, dynamic>> _todaysFleetVisits = [];
  Map<String, int> _territoryWorkload = {};
  Map<String, int> _skillDistribution = {};
  Map<String, int> _certDistribution = {};
  List<int> _weeklyUtilizationData = List.filled(7, 0);

  // Operations Center Data
  int _opsOverdue = 0;
  int _opsPending = 0;
  int _opsCompletedToday = 0;
  int _totalTechs = 0;
  int _totalAvailable = 0;
  int _totalBusy = 0;
  int _totalOnLeave = 0;
  double _avgUtilization = 0.0;
  double _avgReadiness = 0.0;

  // Rankings
  List<Map<String, dynamic>> _recommendedTechs = [];
  List<Map<String, dynamic>> _topPerformersUtilized = [];
  List<Map<String, dynamic>> _topPerformersAvailable = [];
  List<Map<String, dynamic>> _topPerformersReadiness = [];

  // UI State
  String _searchQuery = '';
  String _viewMode = 'Planner'; // Card, Table, Planner
  String _plannerMode = 'Week'; // Day, Week, Month
  int _plannerDaysToDisplay = 7; // 7, 14, 30

  // Filters
  String _availabilityFilter = 'All';
  String _designationFilter = 'All';
  String _territoryFilter = 'All';
  String _regionFilter = 'All';
  String _skillFilter = 'All';
  String _certFilter = 'All';
  String _readinessFilter = 'All';
  String _completenessFilter = 'All';
  bool _showDispatchPanel = true;
  bool _showAdvancedFilters = false;

  // Constants
  final Color _primaryColor = const Color(0xFF17324D);
  final Color _accentColor = const Color(0xFF3B82F6);
  final Color _surfaceColor = const Color(0xFFF1F5F9);
  final Color _borderColor = const Color(0xFFE2E8F0);

  // Derived filter options
  List<String> _territories = ['All'];
  List<String> _regions = ['All'];
  List<String> _skills = ['All'];
  List<String> _certs = ['All'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // =========================================================================
  // ROBUST DATA HELPERS & SCHEMA COMPATIBILITY
  // =========================================================================

  String _getUserName(Map<String, dynamic> data) {
    return (data['fullName'] ?? data['name'] ?? data['userName'] ?? data['employeeName'] ?? 'Unknown').toString().trim();
  }

  String _getDepartment(Map<String, dynamic> data) {
    return (data['department'] ?? data['departmentName'] ?? data['dept'] ?? '').toString().toLowerCase().trim();
  }

  String _getDesignation(Map<String, dynamic> data) {
    return (data['designation'] ?? data['designationName'] ?? data['role'] ?? '').toString().toLowerCase().trim();
  }

  DateTime? _getVisitDate(Map<String, dynamic> data) {
    final val = data['visitDate'] ?? data['date'];
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  DateTime? _getTimestampDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  List<String> _getList(Map<String, dynamic> data, String arrayKey, String? legacyStringKey) {
    if (data[arrayKey] is List) {
      return List<String>.from(data[arrayKey]);
    } else if (legacyStringKey != null && data[legacyStringKey] is String) {
      String str = data[legacyStringKey];
      if (str.isNotEmpty) return str.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  // =========================================================================
  // DATA FETCHING & PROCESSING
  // =========================================================================

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
      setState(() => _errorMessage = 'Failed to load dispatch board: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    _technicians.clear();
    _technicianVisits.clear();
    _todaysFleetVisits.clear();
    _territoryWorkload.clear();
    _skillDistribution.clear();
    _certDistribution.clear();
    _weeklyUtilizationData = List.filled(7, 0);

    _opsOverdue = 0;
    _opsPending = 0;
    _opsCompletedToday = 0;
    _totalAvailable = 0;
    _totalBusy = 0;
    _totalOnLeave = 0;

    double sumUtil = 0;
    double sumReadiness = 0;

    Set<String> uniqueTerritories = {'All'};
    Set<String> uniqueRegions = {'All'};
    Set<String> uniqueSkills = {'All'};
    Set<String> uniqueCerts = {'All'};

    // 1. Build Technicians
    for (var userDoc in _allUsers) {
      final data = userDoc.data();
      final department = _getDepartment(data);
      final designation = _getDesignation(data);

      bool isServiceDept = department == 'service';
      bool isTechOrEngineer = designation.contains('engineer') || designation.contains('technician');

      if (isServiceDept && isTechOrEngineer) {
        _technicians.add({'id': userDoc.id, ...data});
        _technicianVisits[userDoc.id] = [];

        String territory = (data['territory'] ?? 'Unassigned').toString().trim();
        if (territory.isNotEmpty && territory != 'Unassigned') uniqueTerritories.add(territory);

        String region = (data['serviceRegion'] ?? 'Unassigned').toString().trim();
        if (region.isNotEmpty && region != 'Unassigned') uniqueRegions.add(region);

        String skill = (data['primarySkill'] ?? 'General').toString().trim();
        if (skill.isNotEmpty) uniqueSkills.add(skill);
        _skillDistribution[skill] = (_skillDistribution[skill] ?? 0) + 1;

        List<String> certs = _getList(data, 'certifications', null);
        for(var c in certs) {
          uniqueCerts.add(c);
          _certDistribution[c] = (_certDistribution[c] ?? 0) + 1;
        }
      }
    }

    _totalTechs = _technicians.length;
    _territories = uniqueTerritories.toList()..sort();
    _regions = uniqueRegions.toList()..sort();
    _skills = uniqueSkills.toList()..sort();
    _certs = uniqueCerts.toList()..sort();

    // 2. Map Visits & Global Ops
    for (var visitDoc in _allVisits) {
      final data = visitDoc.data();
      final assignedToUid = (data['assignedToUid'] ?? data['engineerUid'] ?? '').toString();
      final vDate = _getVisitDate(data);
      final status = (data['status'] ?? '').toString().toLowerCase();

      bool isCompleted = status == 'completed';
      bool isCancelled = status == 'cancelled';
      bool isOpen = !isCompleted && !isCancelled;

      if (assignedToUid.isNotEmpty && _technicianVisits.containsKey(assignedToUid)) {
        final visitMap = {'id': visitDoc.id, ...data};
        _technicianVisits[assignedToUid]!.add(visitMap);

        if (vDate != null) {
          // Today
          if (vDate.year == today.year && vDate.month == today.month && vDate.day == today.day) {
            if (isOpen) _todaysFleetVisits.add(visitMap);
            if (isCompleted) _opsCompletedToday++;
          }
          // Overdue / Pending
          if (isOpen) {
            _opsPending++;
            if (vDate.isBefore(startOfToday)) _opsOverdue++;
          }
          // Utilization Chart
          if (isOpen) {
            int diffDays = vDate.difference(startOfToday).inDays;
            if (diffDays >= 0 && diffDays < 7) {
              _weeklyUtilizationData[diffDays]++;
            }
          }
        }
      }
    }

    // 3. Compute Technician Capabilities & KPIs
    for (var tech in _technicians) {
      final visits = _technicianVisits[tech['id']] ?? [];

      int todayVisitsCount = 0;
      int openVisitsCount = 0;
      int completedVisitsCount = 0;
      int thisMonthVisitsCount = 0;
      Map<String, dynamic>? nextVisit;
      DateTime? closestFutureDate;

      for (var visit in visits) {
        final vDate = _getVisitDate(visit);
        final status = (visit['status'] ?? '').toString().toLowerCase();

        if (status != 'completed' && status != 'cancelled') openVisitsCount++;
        if (status == 'completed') completedVisitsCount++;

        if (vDate != null) {
          if (vDate.year == today.year && vDate.month == today.month) thisMonthVisitsCount++;
          if (vDate.year == today.year && vDate.month == today.month && vDate.day == today.day) todayVisitsCount++;
          if (vDate.isAfter(today) && status != 'completed' && status != 'cancelled') {
            if (closestFutureDate == null || vDate.isBefore(closestFutureDate)) {
              closestFutureDate = vDate;
              nextVisit = visit;
            }
          }
        }
      }

      // Arrays Fallback mapping
      List<String> wDays = _getList(tech, 'workingDays', null);
      if (wDays.isEmpty) wDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

      List<String> sSkills = _getList(tech, 'secondarySkillsList', 'secondarySkills');
      List<String> certs = _getList(tech, 'certifications', null);
      List<String> secTerritories = _getList(tech, 'secondaryTerritories', null);

      // Automated Leave Checking (Inclusive)
      String currentAvail = (tech['availabilityStatus'] ?? '').toString();
      DateTime? leaveFrom = _getTimestampDate(tech['leaveFrom']);
      DateTime? leaveTo = _getTimestampDate(tech['leaveTo']);

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

      // Capacity Logic (Phase 2)
      int monthlyCap = int.tryParse((tech['monthlyCapacity'] ?? 60).toString()) ?? 60;
      if (monthlyCap <= 0) monthlyCap = 60;
      double utilization = (thisMonthVisitsCount / monthlyCap).clamp(0.0, 1.0);
      sumUtil += utilization;

      // Profile Completeness Scoring (Phase 10)
      int completeness = 0;
      String pSkill = (tech['primarySkill'] ?? 'General Service').toString();
      if (pSkill != 'General Service') completeness += 15;
      if (sSkills.isNotEmpty) completeness += 15;
      if (certs.isNotEmpty) completeness += 10;
      if ((int.tryParse((tech['experienceYears'] ?? 0).toString()) ?? 0) > 0) completeness += 10;
      String terr = (tech['territory'] ?? '').toString().trim();
      if (terr.isNotEmpty && terr != 'Unassigned') completeness += 15;
      String reg = (tech['serviceRegion'] ?? '').toString().trim();
      if (reg.isNotEmpty && reg != 'Unassigned') completeness += 10;
      if (wDays.isNotEmpty) completeness += 15;
      if ((tech['canHandleInstallation'] == true) || (tech['canHandleBreakdown'] == true) || (tech['canHandlePM'] == true)) completeness += 10;

      // Dispatch Readiness Scoring (Phase 11)
      int readiness = 0;
      if (currentAvail == 'Available') readiness += 40;
      else if (currentAvail == 'Busy') readiness += 20;
      if (wDays.isNotEmpty) readiness += 20;
      if (terr.isNotEmpty && terr != 'Unassigned') readiness += 20;
      if (pSkill != 'General Service') readiness += 20;

      sumReadiness += readiness;

      // Dispatch Recommendation Engine Score (Phase 3)
      double matchScore = (readiness * 0.4) + ((1.0 - utilization) * 100 * 0.4) + (completeness * 0.2);

      tech['calculated_todayVisits'] = todayVisitsCount;
      tech['calculated_openVisits'] = openVisitsCount;
      tech['calculated_completedVisits'] = completedVisitsCount;
      tech['calculated_thisMonthVisits'] = thisMonthVisitsCount;
      tech['calculated_nextVisit'] = nextVisit;
      tech['calculated_status'] = currentAvail;
      tech['calculated_utilization'] = utilization;
      tech['calculated_completeness'] = completeness.clamp(0, 100);
      tech['calculated_readiness'] = readiness.clamp(0, 100);
      tech['calculated_matchScore'] = matchScore.clamp(0.0, 100.0);
      tech['calculated_workingDays'] = wDays;
      tech['calculated_sSkills'] = sSkills;
      tech['calculated_certs'] = certs;
      tech['calculated_secTerritories'] = secTerritories;

      _territoryWorkload[terr] = (_territoryWorkload[terr] ?? 0) + openVisitsCount;
    }

    if (_totalTechs > 0) {
      _avgUtilization = sumUtil / _totalTechs;
      _avgReadiness = sumReadiness / _totalTechs;
    }

    // Prepare Rankings
    _topPerformersUtilized = List.from(_technicians)..sort((a, b) => (b['calculated_utilization'] as double).compareTo(a['calculated_utilization'] as double));
    _topPerformersAvailable = List.from(_technicians)..sort((a, b) => (a['calculated_utilization'] as double).compareTo(b['calculated_utilization'] as double));
    _topPerformersReadiness = List.from(_technicians)..sort((a, b) => (b['calculated_readiness'] as int).compareTo(a['calculated_readiness'] as int));
    _recommendedTechs = List.from(_technicians)..sort((a, b) => (b['calculated_matchScore'] as double).compareTo(a['calculated_matchScore'] as double));

    // Sort main list by readiness for default view
    _technicians.sort((a,b) => (b['calculated_readiness'] as int).compareTo(a['calculated_readiness'] as int));
  }

  List<Map<String, dynamic>> _getFilteredTechnicians() {
    return _technicians.where((tech) {
      final searchLower = _searchQuery.toLowerCase();
      final name = _getUserName(tech).toLowerCase();
      final email = (tech['email'] ?? '').toString().toLowerCase();
      final phone = (tech['phone'] ?? '').toString().toLowerCase();
      final territory = (tech['territory'] ?? '').toString().toLowerCase();
      final region = (tech['serviceRegion'] ?? '').toString().toLowerCase();
      final primarySkill = (tech['primarySkill'] ?? '').toString().toLowerCase();
      final certs = tech['calculated_certs'] as List<String>;

      bool matchesSearch = searchLower.isEmpty || name.contains(searchLower) || email.contains(searchLower) || phone.contains(searchLower);

      bool matchesAvail = _availabilityFilter == 'All' || (tech['calculated_status'] as String).toLowerCase() == _availabilityFilter.toLowerCase();
      bool matchesDesig = _designationFilter == 'All' || _getDesignation(tech).contains(_designationFilter.toLowerCase());
      bool matchesTerr = _territoryFilter == 'All' || territory == _territoryFilter.toLowerCase();
      bool matchesReg = _regionFilter == 'All' || region == _regionFilter.toLowerCase();
      bool matchesSkill = _skillFilter == 'All' || primarySkill == _skillFilter.toLowerCase();
      bool matchesCert = _certFilter == 'All' || certs.any((c) => c.toLowerCase() == _certFilter.toLowerCase());

      bool matchesReadiness = true;
      int read = tech['calculated_readiness'] as int;
      if (_readinessFilter == '> 80%') matchesReadiness = read > 80;
      if (_readinessFilter == '50% - 80%') matchesReadiness = read >= 50 && read <= 80;
      if (_readinessFilter == '< 50%') matchesReadiness = read < 50;

      bool matchesComp = true;
      int comp = tech['calculated_completeness'] as int;
      if (_completenessFilter == '> 80%') matchesComp = comp > 80;
      if (_completenessFilter == '50% - 80%') matchesComp = comp >= 50 && comp <= 80;
      if (_completenessFilter == '< 50%') matchesComp = comp < 50;

      return matchesSearch && matchesAvail && matchesDesig && matchesTerr && matchesReg && matchesSkill && matchesCert && matchesReadiness && matchesComp;
    }).toList();
  }

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: _surfaceColor, body: const Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(backgroundColor: _surfaceColor, body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))));
    }

    final filteredData = _getFilteredTechnicians();

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Column(
        children: [
          _buildExecutiveKPIHeader(),
          _buildToolbar(),
          if (_showAdvancedFilters) _buildAdvancedFiltersRow(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: filteredData.isEmpty ? _buildEmptyState() : _buildContentArea(filteredData)),
                if (_showDispatchPanel)
                  Container(width: 320, decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: _borderColor))), child: _buildDispatchControlCenter())
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PHASE 1: EXECUTIVE KPI HEADER ---
  Widget _buildExecutiveKPIHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _primaryColor, border: Border(bottom: BorderSide(color: _primaryColor.withOpacity(0.8)))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiTop('Total Fleet', _totalTechs.toString(), Icons.engineering),
            _buildKpiTop('Available', _totalAvailable.toString(), Icons.check_circle, color: Colors.greenAccent),
            _buildKpiTop('Busy / Dispatched', _totalBusy.toString(), Icons.directions_car, color: Colors.orangeAccent),
            _buildKpiTop('On Leave', _totalOnLeave.toString(), Icons.event_busy, color: Colors.redAccent),
            Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
            _buildKpiTop('Pending Visits', _opsPending.toString(), Icons.pending_actions),
            _buildKpiTop('Overdue', _opsOverdue.toString(), Icons.warning_amber, color: _opsOverdue > 0 ? Colors.redAccent : Colors.white),
            Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
            _buildKpiTop('Avg Utilization', '${(_avgUtilization * 100).toInt()}%', Icons.bar_chart, color: Colors.cyanAccent),
            _buildKpiTop('Fleet Readiness', '${_avgReadiness.toInt()}%', Icons.shield, color: Colors.tealAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiTop(String title, String val, IconData icon, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.8), size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(val, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.engineering_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No technicians found matching criteria.', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // --- TOOLBAR & FILTERS ---
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _borderColor))),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search fleet...', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _accentColor)),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(width: 12),
            _buildDropdownFilter(_availabilityFilter, ['All', 'Available', 'Busy', 'On Leave'], (val) => setState(() => _availabilityFilter = val!)),
            const SizedBox(width: 12),
            _buildDropdownFilter(_regionFilter, _regions.map((e) => e == 'All' ? 'All Regions' : e).toList(), (val) {
              setState(() { _regionFilter = val == 'All Regions' ? 'All' : val!; });
            }),
            const SizedBox(width: 12),
            _buildDropdownFilter(_territoryFilter, _territories.map((e) => e == 'All' ? 'All Territories' : e).toList(), (val) {
              setState(() { _territoryFilter = val == 'All Territories' ? 'All' : val!; });
            }),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(_showAdvancedFilters ? Icons.filter_alt : Icons.filter_alt_outlined, size: 20),
              color: _showAdvancedFilters ? _accentColor : Colors.blueGrey,
              tooltip: 'Advanced Smart Filters',
              onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
            ),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Planner', icon: Icon(Icons.calendar_view_week, size: 16), label: Text('Planner', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'Card', icon: Icon(Icons.grid_view, size: 16), label: Text('Cards', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'Table', icon: Icon(Icons.table_chart_outlined, size: 16), label: Text('Table', style: TextStyle(fontSize: 12))),
              ],
              selected: {_viewMode},
              onSelectionChanged: (Set<String> newSelection) => setState(() => _viewMode = newSelection.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.white, selectedForegroundColor: Colors.white, selectedBackgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(_showDispatchPanel ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left, size: 20),
              color: _showDispatchPanel ? _accentColor : Colors.blueGrey,
              tooltip: 'Toggle Operations Center',
              onPressed: () => setState(() => _showDispatchPanel = !_showDispatchPanel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFiltersRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, border: Border(bottom: BorderSide(color: _borderColor))),
      child: Row(
        children: [
          const Icon(Icons.psychology, size: 16, color: Colors.blueGrey), const SizedBox(width: 8),
          _buildDropdownFilter(_skillFilter, _skills.map((e) => e == 'All' ? 'All Skills' : e).toList(), (val) => setState(() => _skillFilter = val == 'All Skills' ? 'All' : val!)),
          const SizedBox(width: 12),
          _buildDropdownFilter(_certFilter, _certs.map((e) => e == 'All' ? 'All Certifications' : e).toList(), (val) => setState(() => _certFilter = val == 'All Certifications' ? 'All' : val!)),
          const SizedBox(width: 12),
          _buildDropdownFilter(_readinessFilter, ['All', '> 80%', '50% - 80%', '< 50%'], (val) => setState(() => _readinessFilter = val!)),
          const SizedBox(width: 12),
          _buildDropdownFilter(_completenessFilter, ['All', '> 80%', '50% - 80%', '< 50%'], (val) => setState(() => _completenessFilter = val!)),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(String value, List<String> options, ValueChanged<String?> onChanged) {
    String displayValue = options.contains(value) ? value : options.first;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: _borderColor), borderRadius: BorderRadius.circular(6), color: Colors.white),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: displayValue,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
          items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildContentArea(List<Map<String, dynamic>> data) {
    if (_viewMode == 'Card') return _buildCardView(data);
    if (_viewMode == 'Table') return _buildTableView(data);
    return _buildPlannerView(data);
  }

  // =========================================================================
  // DISPATCH CONTROL CENTER (RIGHT PANEL)
  // =========================================================================

  Widget _buildDispatchControlCenter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operations Center', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 24),

          // Phase 3: Recommendation Engine
          const Text('Best Available Resources', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          ..._recommendedTechs.take(3).map((t) => _buildRecommendationRow(t)).toList(),
          const SizedBox(height: 24),

          // Phase 13: Today's Operations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Today\'s Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('${_todaysFleetVisits.length}', style: TextStyle(fontSize: 10, color: _accentColor, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          _buildTodaysAppointments(),
          const SizedBox(height: 24),

          // Phase 2: Smart Capacity Planning
          const Text('Capacity Planning', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          _buildCapacityList('Most Loaded', _topPerformersUtilized.take(3).toList(), Colors.red.shade50, Colors.red.shade700),
          const SizedBox(height: 8),
          _buildCapacityList('Highest Capacity', _topPerformersAvailable.take(3).toList(), Colors.green.shade50, Colors.green.shade700),
          const SizedBox(height: 24),

          // Phase 4: Territory Analytics
          const Text('Territory Workload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          ..._buildAnalyticsRows(_territoryWorkload),
          const SizedBox(height: 24),

          // Phase 5: Skill Analytics
          const Text('Skill Distribution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          ..._buildAnalyticsRows(_skillDistribution),
        ],
      ),
    );
  }

  List<Widget> _buildAnalyticsRows(Map<String, int> data) {
    if (data.isEmpty) return [const Text('No data', style: TextStyle(fontSize: 11, color: Colors.grey))];
    var entries = data.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    )).toList();
  }

  Widget _buildRecommendationRow(Map<String, dynamic> tech) {
    double score = tech['calculated_matchScore'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getUserName(tech), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(tech['calculated_status'], style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
            child: Text('${score.toInt()}% Match', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
          )
        ],
      ),
    );
  }

  Widget _buildCapacityList(String title, List<Map<String, dynamic>> techs, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: fg.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 8),
          ...techs.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(_getUserName(t), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${(t['calculated_utilization'] * 100).toInt()}% Utilized', style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold)),
              ],
            ),
          )),
          if(techs.isEmpty) Text('No data', style: TextStyle(fontSize: 11, color: fg.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildTodaysAppointments() {
    if (_todaysFleetVisits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
        child: const Center(child: Text('No appointments today', style: TextStyle(fontSize: 12, color: Colors.black45))),
      );
    }
    return Column(
      children: _todaysFleetVisits.map((v) {
        final d = _getVisitDate(v);
        final timeStr = d != null ? DateFormat('hh:mm a').format(d) : 'Time TBD';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.directions_car, size: 14, color: Colors.blueGrey),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((v['customerName'] ?? 'Unknown').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${v['assignedToName'] ?? 'Tech'} • $timeStr', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // VIEW MODES
  // =========================================================================

  // --- 1. CARD VIEW (High Density FSM Compatible) ---
  Widget _buildCardView(List<Map<String, dynamic>> data) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 440,
        mainAxisExtent: 260, // Increased for Completeness & Readiness
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final tech = data[index];
        final name = _getUserName(tech);
        final designation = (tech['designation'] ?? 'Technician').toString();
        final pSkill = (tech['primarySkill'] ?? 'General').toString();
        final sSkills = tech['calculated_sSkills'] as List<String>;
        final certs = tech['calculated_certs'] as List<String>;
        final status = tech['calculated_status'] as String;
        final readiness = tech['calculated_readiness'] as int;
        final completeness = tech['calculated_completeness'] as int;
        final util = tech['calculated_utilization'] as double;
        final nextVisit = tech['calculated_nextVisit'] as Map<String, dynamic>?;
        DateTime? nextDate;
        if (nextVisit != null) nextDate = _getVisitDate(nextVisit);

        return Card(
          margin: EdgeInsets.zero, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _borderColor)),
          child: InkWell(
            onTap: () => _showTechnicianDetails(tech),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 22, backgroundColor: _accentColor.withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 18))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(designation, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.indigo.shade100)), child: Text(pSkill, style: TextStyle(fontSize: 9, color: Colors.indigo.shade700, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 6),
                      Text('•  ${tech['experienceYears'] ?? 0} Yrs', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('•  ${tech['territory'] ?? 'Unassigned'}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),

                  // Phase 9: Certifications Badge & Secondary Skills
                  if(sSkills.isNotEmpty || certs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: [
                        if (certs.isNotEmpty)
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 10, color: Colors.green.shade700), const SizedBox(width: 4), Text(certs.length == 1 ? certs.first : '${certs.length} Certifications', style: TextStyle(fontSize: 9, color: Colors.green.shade800, fontWeight: FontWeight.bold))])),
                        ...sSkills.take(2).map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text(s, style: TextStyle(fontSize: 9, color: Colors.grey.shade700)))).toList(),
                      ],
                    )
                  ],

                  // Phase 10 & 11: Progress Bars
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildCardMiniProgress('Completeness', completeness, _getScoreColor(completeness))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCardMiniProgress('Readiness', readiness, _getScoreColor(readiness))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCardMiniProgress('Utilization', (util * 100).toInt(), util > 0.8 ? Colors.red : Colors.green)),
                      ],
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: nextVisit != null && nextDate != null
                            ? Row(
                          children: [
                            const Icon(Icons.event, size: 14, color: Colors.blueGrey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Next: ${DateFormat('MMM dd').format(nextDate)} - ${(nextVisit['customerName'] ?? 'Unknown')}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        )
                            : const Text('No upcoming visits', style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic)),
                      ),
                      Row(
                        children: [
                          _quickActionIcon(Icons.edit_outlined, 'Edit Profile', () => _navigateToEditProfile(tech), Colors.blueGrey),
                          const SizedBox(width: 8),
                          _quickActionIcon(Icons.add_task, 'Schedule Visit', () => _scheduleTechnician(tech), Colors.green),
                        ],
                      )
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

  Color _getScoreColor(int score) {
    if (score < 50) return Colors.red;
    if (score < 80) return Colors.orange;
    return Colors.green;
  }

  Widget _buildCardMiniProgress(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.blueGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$value%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value / 100, backgroundColor: Colors.grey.shade200, color: color, minHeight: 3, borderRadius: BorderRadius.circular(2)),
      ],
    );
  }

  Widget _quickActionIcon(IconData icon, String tooltip, VoidCallback onTap, Color color) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Icon(icon, size: 16, color: color)),
      ),
    );
  }

  Widget _buildDenseStat(String label, String val, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color), const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87)),
      ],
    );
  }

  // --- 2. TABLE VIEW ---
  Widget _buildTableView(List<Map<String, dynamic>> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44, dataRowMinHeight: 52, dataRowMaxHeight: 52, horizontalMargin: 20, columnSpacing: 28,
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
            headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.blueGrey.shade700),
            dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
            columns: const [
              DataColumn(label: Text('TECHNICIAN')),
              DataColumn(label: Text('TERRITORY')),
              DataColumn(label: Text('SKILL')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('COMPLETENESS')),
              DataColumn(label: Text('READINESS')),
              DataColumn(label: Text('OPEN VISITS')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: data.map((tech) {
              final skill = (tech['primarySkill'] ?? 'General').toString();
              return DataRow(
                cells: [
                  DataCell(Text(_getUserName(tech), style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text((tech['territory'] ?? 'Unassigned').toString(), style: const TextStyle(color: Colors.black54))),
                  DataCell(Text(skill, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600))),
                  DataCell(_buildStatusBadge(tech['calculated_status'])),
                  DataCell(Text('${tech['calculated_completeness']}%', style: TextStyle(fontWeight: FontWeight.w600, color: _getScoreColor(tech['calculated_completeness'] as int)))),
                  DataCell(Text('${tech['calculated_readiness']}%', style: TextStyle(fontWeight: FontWeight.w600, color: _getScoreColor(tech['calculated_readiness'] as int)))),
                  DataCell(Text(tech['calculated_openVisits'].toString())),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _quickActionIcon(Icons.visibility_outlined, 'View', () => _showTechnicianDetails(tech), Colors.blue),
                        const SizedBox(width: 8),
                        _quickActionIcon(Icons.edit_outlined, 'Edit Profile', () => _navigateToEditProfile(tech), Colors.orange),
                        const SizedBox(width: 8),
                        _quickActionIcon(Icons.add_task, 'Schedule Visit', () => _scheduleTechnician(tech), Colors.green),
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

  // --- 3. PLANNER VIEWS (Day / Week / Month) ---
  Widget _buildPlannerView(List<Map<String, dynamic>> data) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
      child: Column(
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Resource Planner', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
                      const SizedBox(width: 24),
                      if (_plannerMode == 'Week') ...[
                        _buildDaysToggle(7), const SizedBox(width: 8),
                        _buildDaysToggle(14), const SizedBox(width: 8),
                        _buildDaysToggle(30),
                      ]
                    ],
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Day', label: Text('Timeline', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'Week', label: Text('Grid', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'Month', label: Text('Calendar', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_plannerMode},
                    onSelectionChanged: (Set<String> newSelection) => setState(() => _plannerMode = newSelection.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white, selectedForegroundColor: Colors.white, selectedBackgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  )
                ],
              )
          ),
          if (_plannerMode == 'Week') _buildPlannerLegend(),
          Expanded(
            child: _plannerMode == 'Month' ? _buildMonthCalendar(data) : _plannerMode == 'Day' ? _buildDayTimeline(data) : _buildWeekGrid(data),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysToggle(int days) {
    final isSel = _plannerDaysToDisplay == days;
    return InkWell(
      onTap: () => setState(() => _plannerDaysToDisplay = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: isSel ? _accentColor : Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
        child: Text('$days Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black87)),
      ),
    );
  }

  // Phase 8: Legend
  Widget _buildPlannerLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blueGrey.shade50,
      child: Row(
        children: [
          _legendItem(Colors.grey.shade100, Colors.grey.shade400, Icons.check, 'Available'), const SizedBox(width: 16),
          _legendItem(Colors.orange, Colors.deepOrange, Icons.assignment, 'Scheduled'), const SizedBox(width: 16),
          _legendItem(Colors.red.shade50, Colors.red.shade200, Icons.event_busy, 'On Leave'), const SizedBox(width: 16),
          _legendItem(Colors.grey.shade200, Colors.grey.shade300, Icons.block, 'Off Duty'),
        ],
      ),
    );
  }

  Widget _legendItem(Color bg, Color border, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
          child: Icon(icon, size: 10, color: border == Colors.grey.shade400 ? Colors.green : border),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildWeekGrid(List<Map<String, dynamic>> data) {
    final today = DateTime.now();
    final List<DateTime> days = List.generate(_plannerDaysToDisplay, (i) => today.add(Duration(days: i)));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _borderColor))),
          child: Row(
            children: [
              const SizedBox(width: 180, child: Padding(padding: EdgeInsets.only(left: 16), child: Text('TECHNICIAN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.black54, letterSpacing: 0.5)))),
              ...days.map((d) => Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('EEE').format(d).toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(DateFormat('dd MMM').format(d), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: data.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final tech = data[index];
              final visits = _technicianVisits[tech['id']] ?? [];
              final List<String> wDays = tech['calculated_workingDays'];

              DateTime? lFrom = _getTimestampDate(tech['leaveFrom']);
              DateTime? lTo = _getTimestampDate(tech['leaveTo']);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_getUserName(tech), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text((tech['territory'] ?? 'Unassigned').toString(), style: const TextStyle(fontSize: 10, color: Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    ...days.map((d) {
                      String dayName = DateFormat('E').format(d);
                      bool isWorkingDay = wDays.contains(dayName);
                      bool isLeave = false;

                      if (lFrom != null && lTo != null) {
                        final checkD = DateTime(d.year, d.month, d.day);
                        final startD = DateTime(lFrom.year, lFrom.month, lFrom.day);
                        final endD = DateTime(lTo.year, lTo.month, lTo.day, 23, 59, 59);
                        if(checkD.compareTo(startD) >= 0 && checkD.compareTo(endD) <= 0) {
                          isLeave = true;
                        }
                      }

                      List<Map<String, dynamic>> dayVisits = visits.where((v) {
                        DateTime? vDate = _getVisitDate(v);
                        if (vDate == null) return false;
                        return vDate.year == d.year && vDate.month == d.month && vDate.day == d.day;
                      }).toList();

                      int dailyVisitsCount = dayVisits.length;
                      String tooltipMsg = isLeave ? 'On Leave' : (!isWorkingDay ? 'Off Duty' : (dailyVisitsCount > 0 ? '$dailyVisitsCount Scheduled Visit(s)' : 'Available'));

                      return Expanded(
                        child: Center(
                          child: Tooltip(
                            message: tooltipMsg,
                            child: InkWell(
                              onTap: dailyVisitsCount > 0 ? () => _showDayVisits(tech, d, dayVisits) : null,
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                    color: isLeave ? Colors.red.shade50 : (!isWorkingDay ? Colors.grey.shade200 : (dailyVisitsCount > 0 ? Colors.orange : Colors.grey.shade100)),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isLeave ? Colors.red.shade200 : (!isWorkingDay ? Colors.grey.shade300 : (dailyVisitsCount > 0 ? Colors.deepOrange : Colors.grey.shade300)))
                                ),
                                child: dailyVisitsCount > 0 && !isLeave
                                    ? Center(child: Text('$dailyVisitsCount', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)))
                                    : (isLeave
                                    ? Center(child: Icon(Icons.event_busy, size: 14, color: Colors.red.shade400))
                                    : (!isWorkingDay ? Center(child: Icon(Icons.block, size: 14, color: Colors.grey.shade400)) : Center(child: Icon(Icons.check, size: 12, color: Colors.green.shade300)))),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayTimeline(List<Map<String, dynamic>> data) {
    final List<int> hours = [8, 10, 12, 14, 16, 18];
    final today = DateTime.now();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: _borderColor))),
          child: Row(
            children: [
              const SizedBox(width: 180, child: Padding(padding: EdgeInsets.only(left: 16), child: Text('TECHNICIAN TODAY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.black54, letterSpacing: 0.5)))),
              ...hours.map((h) => Expanded(
                child: Center(
                  child: Text('$h:00', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueGrey)),
                ),
              )),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: data.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final tech = data[index];
              final visits = _technicianVisits[tech['id']] ?? [];
              final todayVisits = visits.where((v) {
                final vd = _getVisitDate(v);
                return vd != null && vd.year == today.year && vd.month == today.month && vd.day == today.day;
              }).toList();

              bool isLeave = false;
              DateTime? lFrom = _getTimestampDate(tech['leaveFrom']);
              DateTime? lTo = _getTimestampDate(tech['leaveTo']);
              if (lFrom != null && lTo != null) {
                final startD = DateTime(lFrom.year, lFrom.month, lFrom.day);
                final endD = DateTime(lTo.year, lTo.month, lTo.day, 23, 59, 59);
                if(today.compareTo(startD) >= 0 && today.compareTo(endD) <= 0) {
                  isLeave = true;
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(_getUserName(tech), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    ...hours.map((h) {
                      final vInSlot = todayVisits.where((v) {
                        final vd = _getVisitDate(v);
                        return vd != null && vd.hour >= h && vd.hour < h+2;
                      }).toList();

                      return Expanded(
                        child: Center(
                          child: InkWell(
                            onTap: vInSlot.isNotEmpty ? () => _showDayVisits(tech, today, vInSlot) : null,
                            child: Container(
                              height: 20, margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                  color: isLeave ? Colors.red.shade100 : (vInSlot.isNotEmpty ? _accentColor : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(4)
                              ),
                              child: isLeave ? Center(child: Icon(Icons.event_busy, size: 12, color: Colors.red.shade400)) : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCalendar(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    int offset = firstDayOfMonth.weekday - 1;
    int totalCells = offset + lastDayOfMonth.day;
    int totalRows = (totalCells / 7).ceil();

    final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10), color: Colors.blueGrey.shade50,
          child: Row(children: weekdays.map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey))))).toList()),
        ),
        Expanded(
          child: LayoutBuilder(
              builder: (context, constraints) {
                double cellHeight = constraints.maxHeight / totalRows;
                return GridView.builder(
                  padding: EdgeInsets.zero, physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: (constraints.maxWidth / 7) / cellHeight),
                  itemCount: totalRows * 7,
                  itemBuilder: (context, index) {
                    if (index < offset || index >= offset + lastDayOfMonth.day) return Container(decoration: BoxDecoration(border: Border.all(color: _borderColor, width: 0.5), color: Colors.grey.shade50));

                    int dayNum = index - offset + 1;
                    DateTime cellDate = DateTime(now.year, now.month, dayNum);
                    bool isToday = dayNum == now.day;

                    List<Map<String, dynamic>> dayVisits = _allVisits.where((v) {
                      final vd = _getVisitDate(v.data());
                      return vd != null && vd.year == cellDate.year && vd.month == cellDate.month && vd.day == cellDate.day;
                    }).map((v) => {'id': v.id, ...v.data()}).toList();

                    return InkWell(
                      onTap: () => _showDayVisits(null, cellDate, dayVisits),
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: _borderColor, width: 0.5), color: isToday ? Colors.blue.shade50 : Colors.white),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$dayNum', style: TextStyle(fontWeight: isToday ? FontWeight.w900 : FontWeight.w600, fontSize: 12, color: isToday ? _accentColor : Colors.black87)),
                            const SizedBox(height: 4),
                            if (dayVisits.isNotEmpty)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: Text('${dayVisits.length} Visits', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
          ),
        ),
      ],
    );
  }

  void _showDayVisits(Map<String, dynamic>? tech, DateTime date, List<Map<String, dynamic>> visits) {
    String titleObj = tech != null ? _getUserName(tech) : "Entire Fleet";
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('Assignments for $titleObj on ${DateFormat('MMM dd, yyyy').format(date)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
                width: 500,
                child: visits.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No visits scheduled.')))
                    : ListView.builder(
                    shrinkWrap: true, itemCount: visits.length,
                    itemBuilder: (context, i) {
                      final v = visits[i];
                      final vd = _getVisitDate(v);
                      final timeStr = vd != null ? DateFormat('hh:mm a').format(vd) : '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(border: Border.all(color: _borderColor), borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.blueGrey.shade50, child: const Icon(Icons.directions_car, color: Colors.blueGrey, size: 20)),
                          title: Text((v['customerName'] ?? 'Unknown Customer').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('${v['assignedToName'] ?? 'Unassigned'} • $timeStr', style: const TextStyle(fontSize: 12)),
                          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text((v['status'] ?? 'Draft').toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        ),
                      );
                    }
                )
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          );
        }
    );
  }

  // --- HELPERS & ACTIONS ---

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;

    final s = status.toLowerCase();
    if (s == 'available') { bg = Colors.green.shade50; fg = Colors.green.shade700; }
    else if (s == 'busy') { bg = Colors.orange.shade50; fg = Colors.orange.shade800; }
    else if (s == 'on leave' || s == 'leave') { bg = Colors.red.shade50; fg = Colors.red.shade700; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    );
  }

  void _scheduleTechnician(Map<String, dynamic> tech) {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.add_task, color: Colors.green),
                const SizedBox(width: 10),
                Text('Dispatch ${_getUserName(tech)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select an existing Work Order or Service Request to schedule this technician.', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextFormField(decoration: const InputDecoration(labelText: 'Customer / Location', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Time', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)))),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visit securely dispatched to ${_getUserName(tech)}.'), backgroundColor: Colors.green));
                },
                child: const Text('Confirm Dispatch', style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
    );
  }

  void _navigateToEditProfile(Map<String, dynamic> technician) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddServiceTechnicianScreen(companyId: widget.companyId, userId: technician['id'], existingData: technician)),
    ).then((_) => _loadData());
  }

  // Phase 15: Details Dialog Enhancement
  void _showTechnicianDetails(Map<String, dynamic> tech) {
    final certs = tech['calculated_certs'] as List<String>;
    final sSkills = tech['calculated_sSkills'] as List<String>;
    final secTerr = tech['calculated_secTerritories'] as List<String>;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 800,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 20, backgroundColor: _accentColor.withOpacity(0.1), child: Icon(Icons.engineering, color: _accentColor)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_getUserName(tech), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 12),
                                _buildStatusBadge(tech['calculated_status']),
                              ],
                            ),
                            Text('${(tech['designation'] ?? '')} • ${(tech['department'] ?? 'Service')}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                          ],
                        )
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Core Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONTACT & TERRITORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
                          const SizedBox(height: 12),
                          _buildDetailRow('Email', (tech['email'] ?? 'N/A').toString()),
                          _buildDetailRow('Phone', (tech['phone'] ?? 'N/A').toString()),
                          _buildDetailRow('Primary Territory', (tech['territory'] ?? 'Unassigned').toString()),
                          _buildDetailRow('Service Region', (tech['serviceRegion'] ?? 'Unassigned').toString()),
                          if (secTerr.isNotEmpty) _buildDetailRow('Secondary Territories', secTerr.join(', ')),
                          _buildDetailRow('Experience', '${tech['experienceYears'] ?? 0} Years'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Column 2: Capabilities
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SKILLS & ROUTING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
                          const SizedBox(height: 12),
                          _buildDetailRow('Primary Skill', (tech['primarySkill'] ?? 'General').toString()),
                          if (sSkills.isNotEmpty) _buildDetailRow('Secondary Skills', sSkills.join(', ')),
                          if (certs.isNotEmpty) _buildDetailRow('Certifications', certs.join(', ')),

                          const SizedBox(height: 8),
                          const Text('Preferences', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 11)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: [
                              if (tech['canHandleInstallation'] == true) _prefChip('Installation'),
                              if (tech['canHandleBreakdown'] == true) _prefChip('Breakdown'),
                              if (tech['canHandlePM'] == true) _prefChip('PM'),
                              if (tech['canHandleEmergency'] == true) _prefChip('Emergency'),
                              if (tech['canHandleTraining'] == true) _prefChip('Training'),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Column 3: Capacity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CAPACITY & WORKLOAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
                          const SizedBox(height: 12),
                          _buildDetailRow('Daily Capacity', '${tech['dailyCapacity'] ?? 3} Visits'),
                          _buildDetailRow('Monthly Quota', '${tech['monthlyCapacity'] ?? 60} Visits'),
                          _buildDetailRow('Working Days', (tech['calculated_workingDays'] as List).join(', ')),
                          _buildDetailRow('Currently Open', '${tech['calculated_openVisits']} Tasks'),
                          _buildDetailRow('Completed', '${tech['calculated_completedVisits']} Tasks'),

                          if (tech['leaveFrom'] != null && tech['leaveTo'] != null)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade100)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Upcoming Leave', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                                  const SizedBox(height: 2),
                                  Text('${DateFormat('MMM dd').format(_getTimestampDate(tech['leaveFrom'])!)} - ${DateFormat('MMM dd').format(_getTimestampDate(tech['leaveTo'])!)}', style: TextStyle(fontSize: 11, color: Colors.red.shade900)),
                                  if ((tech['leaveReason'] ?? '').toString().trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(tech['leaveReason'].toString(), style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontStyle: FontStyle.italic)),
                                    )
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                  ],
                ),

                if((tech['remarks'] ?? '').toString().isNotEmpty) ... [
                  const SizedBox(height: 16),
                  const Text('Internal Remarks', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 11)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                    child: Text(tech['remarks'].toString(), style: const TextStyle(fontSize: 12)),
                  )
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_task, size: 16, color: Colors.green),
                      label: const Text('Schedule Dispatch', style: TextStyle(color: Colors.green)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                      onPressed: () {
                        Navigator.pop(context);
                        _scheduleTechnician(tech);
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                      label: const Text('Edit Resource Profile', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToEditProfile(tech);
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _prefChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 10, color: Colors.blue),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}