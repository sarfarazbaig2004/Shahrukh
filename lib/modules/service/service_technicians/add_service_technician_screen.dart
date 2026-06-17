import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AddServiceTechnicianScreen extends StatefulWidget {
  final String companyId;
  final String userId;
  final Map<String, dynamic> existingData;

  const AddServiceTechnicianScreen({
    Key? key,
    required this.companyId,
    required this.userId,
    required this.existingData,
  }) : super(key: key);

  @override
  State<AddServiceTechnicianScreen> createState() =>
      _AddServiceTechnicianScreenState();
}

class _AddServiceTechnicianScreenState extends State<AddServiceTechnicianScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingStats = true;

  // --- Theme Constants ---
  final Color _primaryColor = const Color(0xFF17324D);
  final Color _accentColor = const Color(0xFF3B82F6);
  final Color _surfaceColor = const Color(0xFFF1F5F9);
  final Color _borderColor = const Color(0xFFE2E8F0);

  // --- Controllers ---
  late TextEditingController _experienceController;
  late TextEditingController _territoryController;
  late TextEditingController _secondaryTerritoryController;
  late TextEditingController _regionController;
  late TextEditingController _remarksController;
  late TextEditingController _leaveReasonController;
  late TextEditingController _dailyCapCtrl;
  late TextEditingController _weeklyCapCtrl;
  late TextEditingController _monthlyCapCtrl;

  // --- State Variables ---
  String _primarySkill = 'General Service';
  String _availabilityStatus = 'Available';

  List<String> _secondarySkillsList = [];
  List<String> _certificationsList = [];
  List<String> _workingDaysList = [];
  List<String> _secondaryTerritoriesList = [];

  DateTime? _leaveFrom;
  DateTime? _leaveTo;

  bool _canHandleInstallation = true;
  bool _canHandleBreakdown = true;
  bool _canHandlePM = true;
  bool _canHandleTraining = false;
  bool _canHandleEmergency = false;

  // --- Performance Stats (Read-Only) ---
  int _openVisits = 0;
  int _completedVisits = 0;
  int _thisMonthVisits = 0;
  int _upcomingVisits = 0;
  int _last30DaysVisits = 0;
  double _utilization = 0.0;

  // --- Options ---
  final List<String> _skillOptions = [
    'Installation', 'Breakdown Maintenance', 'Preventive Maintenance',
    'Electrical', 'Mechanical', 'PLC', 'Automation', 'Calibration',
    'Training', 'General Service',
  ];

  final List<String> _certOptions = [
    'PLC Certified', 'Automation Certified', 'Electrical Licensed',
    'OEM Certified', 'Safety Certified', 'Calibration Certified', 'First Aid CPR'
  ];

  final List<String> _dayOptions = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final List<String> _statusOptions = [
    'Available', 'Busy', 'On Leave', 'Training', 'Inactive'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadPerformanceStats();

    // Auto-recalculate utilization when monthly capacity changes
    _monthlyCapCtrl.addListener(_recalculateUtilization);
  }

  void _initializeData() {
    final d = widget.existingData;

    _experienceController = TextEditingController(text: (d['experienceYears'] ?? '').toString());
    _territoryController = TextEditingController(text: (d['territory'] ?? '').toString());
    _regionController = TextEditingController(text: (d['serviceRegion'] ?? '').toString());
    _remarksController = TextEditingController(text: (d['remarks'] ?? '').toString());
    _leaveReasonController = TextEditingController(text: (d['leaveReason'] ?? '').toString());

    _dailyCapCtrl = TextEditingController(text: (d['dailyCapacity'] ?? 3).toString());
    _weeklyCapCtrl = TextEditingController(text: (d['weeklyCapacity'] ?? 15).toString());
    _monthlyCapCtrl = TextEditingController(text: (d['monthlyCapacity'] ?? 60).toString());

    _secondaryTerritoryController = TextEditingController();
    if (d['secondaryTerritories'] is List) {
      _secondaryTerritoriesList = List<String>.from(d['secondaryTerritories']);
    }

    if (_skillOptions.contains(d['primarySkill'])) {
      _primarySkill = d['primarySkill'];
    }
    if (_statusOptions.contains(d['availabilityStatus'])) {
      _availabilityStatus = d['availabilityStatus'];
    }

    if (d['secondarySkillsList'] is List) {
      _secondarySkillsList = List<String>.from(d['secondarySkillsList']);
    } else {
      String secSkillsStr = (d['secondarySkills'] ?? '').toString();
      if (secSkillsStr.isNotEmpty) {
        _secondarySkillsList = secSkillsStr.split(',').map((e) => e.trim()).toList();
      }
    }
    // Prevent duplicate of primary skill in secondary
    _secondarySkillsList.removeWhere((s) => s == _primarySkill);

    if (d['certifications'] is List) {
      _certificationsList = List<String>.from(d['certifications']);
    }

    if (d['workingDays'] is List) {
      _workingDaysList = List<String>.from(d['workingDays']);
    } else {
      _workingDaysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    }

    if (d['leaveFrom'] is Timestamp) _leaveFrom = (d['leaveFrom'] as Timestamp).toDate();
    if (d['leaveTo'] is Timestamp) _leaveTo = (d['leaveTo'] as Timestamp).toDate();

    _canHandleInstallation = d['canHandleInstallation'] ?? true;
    _canHandleBreakdown = d['canHandleBreakdown'] ?? true;
    _canHandlePM = d['canHandlePM'] ?? true;
    _canHandleTraining = d['canHandleTraining'] ?? false;
    _canHandleEmergency = d['canHandleEmergency'] ?? false;

    _checkAutoLeaveStatus();
  }

  void _checkAutoLeaveStatus() {
    if (_leaveFrom != null && _leaveTo != null) {
      final now = DateTime.now();
      final start = DateTime(_leaveFrom!.year, _leaveFrom!.month, _leaveFrom!.day);
      final end = DateTime(_leaveTo!.year, _leaveTo!.month, _leaveTo!.day, 23, 59, 59);
      if (now.isAfter(start) && now.isBefore(end)) {
        _availabilityStatus = 'On Leave';
      }
    }
  }

  void _recalculateUtilization() {
    int monthlyCap = int.tryParse(_monthlyCapCtrl.text) ?? 60;
    if (monthlyCap > 0) {
      setState(() {
        _utilization = (_thisMonthVisits / monthlyCap).clamp(0.0, 1.0);
      });
    }
  }

  Future<void> _loadPerformanceStats() async {
    try {
      final res = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('service_visits')
          .where('isDeleted', isEqualTo: false)
          .get();

      int open = 0, completed = 0, thisMonth = 0, upcoming = 0, last30 = 0;
      final today = DateTime.now();
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));

      for (var doc in res.docs) {
        final data = doc.data();
        final assignedUid = (data['assignedToUid'] ?? data['engineerUid'] ?? '').toString();
        if (assignedUid != widget.userId) continue;

        final status = (data['status'] ?? '').toString().toLowerCase();
        final vDateRaw = data['visitDate'] ?? data['date'];
        DateTime? vDate;

        if (vDateRaw is Timestamp) vDate = vDateRaw.toDate();
        else if (vDateRaw is String) vDate = DateTime.tryParse(vDateRaw);

        if (status != 'completed' && status != 'cancelled') open++;
        if (status == 'completed') completed++;

        if (vDate != null) {
          if (vDate.year == today.year && vDate.month == today.month) thisMonth++;
          if (vDate.isAfter(thirtyDaysAgo) && vDate.isBefore(today.add(const Duration(days: 1)))) last30++;
          if (vDate.isAfter(today) && status != 'completed' && status != 'cancelled') upcoming++;
        }
      }

      if (mounted) {
        setState(() {
          _openVisits = open;
          _completedVisits = completed;
          _thisMonthVisits = thisMonth;
          _last30DaysVisits = last30;
          _upcomingVisits = upcoming;
          _isLoadingStats = false;
        });
        _recalculateUtilization();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    _monthlyCapCtrl.removeListener(_recalculateUtilization);
    _experienceController.dispose();
    _territoryController.dispose();
    _secondaryTerritoryController.dispose();
    _regionController.dispose();
    _remarksController.dispose();
    _leaveReasonController.dispose();
    _dailyCapCtrl.dispose();
    _weeklyCapCtrl.dispose();
    _monthlyCapCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check capacity validation errors.'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);

    try {
      final payload = {
        'primarySkill': _primarySkill,
        'secondarySkills': _secondarySkillsList.join(', '), // Kept for list compatibility
        'secondarySkillsList': _secondarySkillsList, // Structured for future queries
        'certifications': _certificationsList,
        'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
        'territory': _territoryController.text.trim(),
        'secondaryTerritories': _secondaryTerritoriesList,
        'serviceRegion': _regionController.text.trim(),
        'availabilityStatus': _availabilityStatus,
        'dailyCapacity': int.tryParse(_dailyCapCtrl.text.trim()) ?? 3,
        'weeklyCapacity': int.tryParse(_weeklyCapCtrl.text.trim()) ?? 15,
        'monthlyCapacity': int.tryParse(_monthlyCapCtrl.text.trim()) ?? 60,
        'workingDays': _workingDaysList,
        'leaveFrom': _leaveFrom != null ? Timestamp.fromDate(_leaveFrom!) : null,
        'leaveTo': _leaveTo != null ? Timestamp.fromDate(_leaveTo!) : null,
        'leaveReason': _leaveReasonController.text.trim(),
        'canHandleInstallation': _canHandleInstallation,
        'canHandleBreakdown': _canHandleBreakdown,
        'canHandlePM': _canHandlePM,
        'canHandleTraining': _canHandleTraining,
        'canHandleEmergency': _canHandleEmergency,
        'remarks': _remarksController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .doc(widget.userId)
          .update(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Technician resource profile updated'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Dynamic KPI Calculations ---
  int get _profileCompleteness {
    int score = 0;
    if (_primarySkill != 'General Service') score += 15;
    if (_secondarySkillsList.isNotEmpty) score += 15;
    if (_certificationsList.isNotEmpty) score += 10;
    if ((int.tryParse(_experienceController.text) ?? 0) > 0) score += 10;
    if (_territoryController.text.isNotEmpty) score += 15;
    if (_regionController.text.isNotEmpty) score += 10;
    if (_workingDaysList.isNotEmpty) score += 15;
    if (_canHandleInstallation || _canHandleBreakdown || _canHandlePM) score += 10;
    return score.clamp(0, 100);
  }

  int get _dispatchReadiness {
    int score = 0;
    if (_availabilityStatus == 'Available') score += 40;
    else if (_availabilityStatus == 'Busy') score += 20;

    if (_workingDaysList.isNotEmpty) score += 20;
    if (_territoryController.text.isNotEmpty) score += 20;
    if (_primarySkill != 'General Service') score += 20;
    return score.clamp(0, 100);
  }

  String get _leaveDuration {
    if (_leaveFrom != null && _leaveTo != null) {
      final days = _leaveTo!.difference(_leaveFrom!).inDays + 1;
      if (days > 0) return '$days Days Leave Scheduled';
      return 'Invalid Date Range';
    }
    return '';
  }

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      // Removed Internal AppBar
      body: SafeArea(
        child: Column(
          children: [
            _buildStickyActionBar(),
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      children: [
                        _buildOverviewHeader(),
                        const SizedBox(height: 20),
                        _buildPerformanceSnapshot(),
                        const SizedBox(height: 20),
                        _buildSkillsMatrix(),
                        const SizedBox(height: 20),
                        _buildCapacityAndTerritory(),
                        const SizedBox(height: 20),
                        _buildDispatchPreferences(),
                        const SizedBox(height: 20),
                        _buildLeaveManagement(),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: 'Internal Remarks',
                          icon: Icons.speaker_notes_outlined,
                          child: TextFormField(
                            controller: _remarksController,
                            maxLines: 3,
                            decoration: InputDecoration(hintText: 'Internal notes for dispatchers...', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor))),
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sections ---

  Widget _buildStickyActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _borderColor)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          const Text('Resource Profile Configurator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
            label: const Text('Save Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: _isSaving ? null : _saveProfile,
          )
        ],
      ),
    );
  }

  Widget _buildOverviewHeader() {
    final d = widget.existingData;
    final name = (d['fullName'] ?? d['name'] ?? 'Technician').toString();
    final email = (d['email'] ?? 'No Email').toString();
    final phone = (d['phone'] ?? 'No Phone').toString();
    final designation = (d['designation'] ?? 'Service Department').toString();
    final dept = (d['department'] ?? 'Service').toString();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: _accentColor.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 28)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
                    const SizedBox(width: 12),
                    _buildStatusBadge(_availabilityStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text('$designation • $dept', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500), const SizedBox(width: 4),
                    Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(width: 16),
                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500), const SizedBox(width: 4),
                    Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          Container(
            width: 240,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMiniProgressBar('Profile Completeness', _profileCompleteness, Colors.blue),
                const SizedBox(height: 12),
                _buildMiniProgressBar('Dispatch Readiness', _dispatchReadiness, Colors.green),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniProgressBar(String title, int percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
            Text('$percent%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: percent / 100, backgroundColor: Colors.grey.shade200, color: color, minHeight: 4, borderRadius: BorderRadius.circular(2)),
      ],
    );
  }

  Widget _buildPerformanceSnapshot() {
    if (_isLoadingStats) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }

    // Safely extract the monthly capacity integer for rendering
    final monthlyCapacity = int.tryParse(_monthlyCapCtrl.text) ?? 0;

    return _buildSection(
        title: 'Real-time Performance Snapshot',
        icon: Icons.dashboard_outlined,
        child: Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            _buildKpiCard('Open Visits', _openVisits.toString(), Icons.pending_actions, Colors.blue),
            _buildKpiCard('Completed', _completedVisits.toString(), Icons.task_alt, Colors.green),
            _buildKpiCard('Upcoming', _upcomingVisits.toString(), Icons.event_available, Colors.orange),
            _buildKpiCard('Month Vol.', _thisMonthVisits.toString(), Icons.calendar_month, Colors.purple),
            _buildKpiCard('30 Days', _last30DaysVisits.toString(), Icons.history, Colors.blueGrey),
            _buildKpiCard('Avg/Week', (_last30DaysVisits / 4).toStringAsFixed(1), Icons.trending_up, Colors.teal),

            // Utilization Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueGrey.shade100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BUG FIX: Using properly parsed integer variable instead of controller object mapping
                  Text('Est. Monthly Utilization (vs $monthlyCapacity capacity limit)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: LinearProgressIndicator(value: _utilization, backgroundColor: Colors.white, color: _utilization > 0.8 ? Colors.red : (_utilization > 0.5 ? Colors.orange : Colors.green), minHeight: 8, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 12),
                      Text('${(_utilization * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  )
                ],
              ),
            ),
          ],
        )
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Container(
      width: 130, // Responsive wrap size
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSkillsMatrix() {
    List<String> availableSecondary = _skillOptions.where((s) => s != _primarySkill).toList();

    return _buildSection(
        title: 'Skills & Certifications Matrix',
        icon: Icons.psychology_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _primarySkill,
                    decoration: InputDecoration(labelText: 'Primary Skill Specialty', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50),
                    items: _skillOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _primarySkill = val!;
                        _secondarySkillsList.remove(_primarySkill); // Auto remove from secondary
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _experienceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'Experience (Years)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50),
                    validator: (val) {
                      if (val != null && val.isNotEmpty && int.parse(val) < 0) return 'Must be >= 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Secondary Skills (Multi-select)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: availableSecondary.map((skill) {
                final isSelected = _secondarySkillsList.contains(skill);
                return FilterChip(
                  label: Text(skill, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _primaryColor : Colors.black87)),
                  selected: isSelected,
                  selectedColor: _primaryColor.withOpacity(0.1),
                  checkmarkColor: _primaryColor,
                  backgroundColor: Colors.grey.shade50,
                  side: BorderSide(color: isSelected ? _primaryColor.withOpacity(0.5) : _borderColor),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) _secondarySkillsList.add(skill);
                      else _secondarySkillsList.remove(skill);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Certifications / Licenses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _certOptions.map((cert) {
                final isSelected = _certificationsList.contains(cert);
                return FilterChip(
                  avatar: isSelected ? const Icon(Icons.verified, size: 16, color: Colors.green) : null,
                  label: Text(cert, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.green.shade800 : Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.green.shade50,
                  showCheckmark: false, // Replaced by avatar icon
                  backgroundColor: Colors.grey.shade50,
                  side: BorderSide(color: isSelected ? Colors.green.shade300 : _borderColor),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) _certificationsList.add(cert);
                      else _certificationsList.remove(cert);
                    });
                  },
                );
              }).toList(),
            )
          ],
        )
    );
  }

  Widget _buildCapacityAndTerritory() {
    return _buildSection(
        title: 'Capacity & Territory Management',
        icon: Icons.map_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: TextFormField(controller: _territoryController, decoration: InputDecoration(labelText: 'Primary Territory', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50))),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _regionController, decoration: InputDecoration(labelText: 'Service Region', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _secondaryTerritoryController,
                    decoration: InputDecoration(
                        labelText: 'Add Secondary Territory',
                        hintText: 'Type and press enter or +',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true, fillColor: Colors.grey.shade50,
                        suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blue),
                            onPressed: _addSecondaryTerritory
                        )
                    ),
                    onFieldSubmitted: (_) => _addSecondaryTerritory(),
                  ),
                ),
              ],
            ),
            if (_secondaryTerritoriesList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _secondaryTerritoriesList.map((t) => InputChip(
                  label: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                  onDeleted: () => setState(() => _secondaryTerritoriesList.remove(t)),
                  backgroundColor: Colors.blueGrey.shade50,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                )).toList(),
              )
            ],
            const SizedBox(height: 32),
            const Text('Planned Capacity Quotas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _dailyCapCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Daily Visits', prefixIcon: const Icon(Icons.today, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50),
                  validator: (val) {
                    int v = int.tryParse(val ?? '') ?? 0;
                    if (v <= 0) return '> 0';
                    return null;
                  },
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _weeklyCapCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Weekly Target', prefixIcon: const Icon(Icons.view_week, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50),
                  validator: (val) {
                    int w = int.tryParse(val ?? '') ?? 0;
                    int d = int.tryParse(_dailyCapCtrl.text) ?? 0;
                    if (w < d) return 'Must be >= Daily';
                    return null;
                  },
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _monthlyCapCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Monthly Target', prefixIcon: const Icon(Icons.calendar_month, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50),
                  validator: (val) {
                    int m = int.tryParse(val ?? '') ?? 0;
                    int w = int.tryParse(_weeklyCapCtrl.text) ?? 0;
                    if (m < w) return 'Must be >= Weekly';
                    return null;
                  },
                )),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Standard Working Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _dayOptions.map((day) {
                final isSelected = _workingDaysList.contains(day);
                return FilterChip(
                  label: Text(day, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: _primaryColor,
                  backgroundColor: Colors.grey.shade100,
                  checkmarkColor: Colors.white,
                  side: isSelected ? BorderSide.none : BorderSide(color: _borderColor),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) _workingDaysList.add(day);
                      else _workingDaysList.remove(day);
                    });
                  },
                );
              }).toList(),
            )
          ],
        )
    );
  }

  void _addSecondaryTerritory() {
    final t = _secondaryTerritoryController.text.trim();
    final primary = _territoryController.text.trim();
    if (t.isNotEmpty) {
      if (t.toLowerCase() == primary.toLowerCase()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already set as Primary Territory'), backgroundColor: Colors.orange));
        return;
      }
      if (!_secondaryTerritoriesList.any((e) => e.toLowerCase() == t.toLowerCase())) {
        setState(() => _secondaryTerritoriesList.add(t));
      }
      _secondaryTerritoryController.clear();
    }
  }

  Widget _buildDispatchPreferences() {
    return _buildSection(
        title: 'Dispatch Routing Preferences',
        icon: Icons.route_outlined,
        child: Wrap(
          spacing: 16, runSpacing: 12,
          children: [
            _buildPrefCheckbox('Can Handle Installations', _canHandleInstallation, (v) => setState(() => _canHandleInstallation = v)),
            _buildPrefCheckbox('Can Handle Breakdowns', _canHandleBreakdown, (v) => setState(() => _canHandleBreakdown = v)),
            _buildPrefCheckbox('Can Handle PM Visits', _canHandlePM, (v) => setState(() => _canHandlePM = v)),
            _buildPrefCheckbox('Can Conduct Training', _canHandleTraining, (v) => setState(() => _canHandleTraining = v)),
            _buildPrefCheckbox('Available for Emergency Calls', _canHandleEmergency, (v) => setState(() => _canHandleEmergency = v)),
          ],
        )
    );
  }

  Widget _buildPrefCheckbox(String title, bool val, Function(bool) onChanged) {
    return SizedBox(
      width: 250,
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        value: val,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: _primaryColor,
        onChanged: (v) => onChanged(v ?? false),
      ),
    );
  }

  Widget _buildLeaveManagement() {
    return _buildSection(
        title: 'Leave & Absence Planning',
        icon: Icons.event_busy_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _leaveFrom ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) {
                        setState(() { _leaveFrom = d; _checkAutoLeaveStatus(); });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: _borderColor), borderRadius: BorderRadius.circular(8), color: Colors.grey.shade50),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_leaveFrom != null ? DateFormat('MMM dd, yyyy').format(_leaveFrom!) : 'Select Leave Start', style: TextStyle(color: _leaveFrom != null ? Colors.black87 : Colors.grey, fontWeight: FontWeight.bold)),
                          const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey)),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _leaveTo ?? _leaveFrom ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) {
                        setState(() { _leaveTo = d; _checkAutoLeaveStatus(); });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: _borderColor), borderRadius: BorderRadius.circular(8), color: Colors.grey.shade50),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_leaveTo != null ? DateFormat('MMM dd, yyyy').format(_leaveTo!) : 'Select Leave End', style: TextStyle(color: _leaveTo != null ? Colors.black87 : Colors.grey, fontWeight: FontWeight.bold)),
                          const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_leaveFrom != null || _leaveTo != null) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    tooltip: 'Clear Leave',
                    onPressed: () => setState((){ _leaveFrom = null; _leaveTo = null; }),
                  )
                ]
              ],
            ),
            if (_leaveDuration.isNotEmpty) ... [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
                child: Text(_leaveDuration, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
              )
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _leaveReasonController,
              decoration: InputDecoration(labelText: 'Leave Reason / Notes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50),
            ),
          ],
        )
    );
  }

  // --- Reusable Widget ---

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: _primaryColor),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _primaryColor)),
            ],
          ),
          const SizedBox(height: 20),
          child,
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
    else if (s == 'on leave' || s == 'leave') { bg = Colors.red.shade50; fg = Colors.red.shade700; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withOpacity(0.2))),
      child: Text(status.toUpperCase(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}