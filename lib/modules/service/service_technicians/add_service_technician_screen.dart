// FILE PATH: lib/modules/service/technicians/add_service_technician_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  State<AddServiceTechnicianScreen> createState() => _AddServiceTechnicianScreenState();
}

class _AddServiceTechnicianScreenState extends State<AddServiceTechnicianScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingStats = true;

  // --- Controllers ---
  late TextEditingController _experienceController;
  late TextEditingController _territoryController;
  late TextEditingController _regionController;
  late TextEditingController _remarksController;
  late TextEditingController _leaveReasonController;
  late TextEditingController _dailyCapCtrl;
  late TextEditingController _monthlyCapCtrl;

  // --- State Variables ---
  String _primarySkill = 'General Service';
  String _availabilityStatus = 'Available';

  List<String> _secondarySkillsList = [];
  List<String> _certificationsList = [];
  List<String> _workingDaysList = [];

  DateTime? _leaveFrom;
  DateTime? _leaveTo;

  bool _canHandleInstallation = true;
  bool _canHandleBreakdown = true;
  bool _canHandlePM = true;

  // --- Performance Stats (Read-Only) ---
  int _openVisits = 0;
  int _completedVisits = 0;
  int _upcomingVisits = 0;
  int _thisMonthVisits = 0;

  // --- Options ---
  final List<String> _primarySkillOptions = [
    'General Service', 'Installation', 'Breakdown Maintenance',
    'Preventive Maintenance', 'Electrical', 'Mechanical',
    'PLC', 'Automation', 'Calibration', 'Training'
  ];

  final List<String> _secondarySkillOptions = [
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
    'Available', 'Busy', 'On Leave', 'Inactive'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadPerformanceStats();
  }

  void _initializeData() {
    final d = widget.existingData;

    _experienceController = TextEditingController(text: _safeString(d['experienceYears']));
    _territoryController = TextEditingController(text: _safeString(d['territory']));
    _regionController = TextEditingController(text: _safeString(d['serviceRegion']));
    _remarksController = TextEditingController(text: _safeString(d['remarks']));
    _leaveReasonController = TextEditingController(text: _safeString(d['leaveReason']));

    _dailyCapCtrl = TextEditingController(text: _safeInt(d['dailyCapacity'] ?? 3).toString());
    _monthlyCapCtrl = TextEditingController(text: _safeInt(d['monthlyCapacity'] ?? 60).toString());

    String pSkill = _safeString(d['primarySkill']);
    if (pSkill.isNotEmpty && _primarySkillOptions.contains(pSkill)) {
      _primarySkill = pSkill;
    }

    String aStatus = _safeString(d['availabilityStatus']);
    if (aStatus.isNotEmpty && _statusOptions.contains(aStatus)) {
      _availabilityStatus = aStatus;
    }

    if (d['secondarySkillsList'] is List) {
      _secondarySkillsList = List<String>.from(d['secondarySkillsList']);
    } else {
      String secSkillsStr = _safeString(d['secondarySkills']);
      if (secSkillsStr.isNotEmpty) {
        _secondarySkillsList = secSkillsStr.split(',').map((e) => e.trim()).toList();
      }
    }
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

  Future<void> _loadPerformanceStats() async {
    try {
      final res = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('service_visits')
          .where('isDeleted', isEqualTo: false)
          .get();

      int open = 0, completed = 0, upcoming = 0, thisMonth = 0;
      final today = DateTime.now();

      for (var doc in res.docs) {
        final data = doc.data();
        final assignedUid = _safeString(data['assignedTechnicianUid'].toString().isNotEmpty ? data['assignedTechnicianUid'] : data['engineerUid']);
        if (assignedUid != widget.userId) continue;

        final status = _safeString(data['visitStatus']).isNotEmpty ? _safeString(data['visitStatus']) : _safeString(data['status']);
        final vDateRaw = data['visitDate'] ?? data['date'];
        DateTime? vDate;

        if (vDateRaw is Timestamp) vDate = vDateRaw.toDate();
        else if (vDateRaw is String) vDate = DateTime.tryParse(vDateRaw);

        bool isCompleted = status == 'Completed' || status == 'Resolved';
        bool isCancelled = status == 'Cancelled';
        bool isOpen = !isCompleted && !isCancelled;

        if (isOpen) open++;
        if (isCompleted) completed++;

        if (vDate != null) {
          if (vDate.year == today.year && vDate.month == today.month) thisMonth++;
          if (vDate.isAfter(today) && isOpen) upcoming++;
        }
      }

      if (mounted) {
        setState(() {
          _openVisits = open;
          _completedVisits = completed;
          _upcomingVisits = upcoming;
          _thisMonthVisits = thisMonth;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    _experienceController.dispose();
    _territoryController.dispose();
    _regionController.dispose();
    _remarksController.dispose();
    _leaveReasonController.dispose();
    _dailyCapCtrl.dispose();
    _monthlyCapCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final payload = {
        'primarySkill': _primarySkill,
        'secondarySkills': _secondarySkillsList.join(', '),
        'secondarySkillsList': _secondarySkillsList,
        'certifications': _certificationsList,
        'experienceYears': _safeInt(_experienceController.text),
        'territory': _territoryController.text.trim(),
        'serviceRegion': _regionController.text.trim(),
        'availabilityStatus': _availabilityStatus,
        'dailyCapacity': _safeInt(_dailyCapCtrl.text),
        'monthlyCapacity': _safeInt(_monthlyCapCtrl.text),
        'workingDays': _workingDaysList,
        'leaveFrom': _leaveFrom != null ? Timestamp.fromDate(_leaveFrom!) : null,
        'leaveTo': _leaveTo != null ? Timestamp.fromDate(_leaveTo!) : null,
        'leaveReason': _leaveReasonController.text.trim(),
        'canHandleInstallation': _canHandleInstallation,
        'canHandleBreakdown': _canHandleBreakdown,
        'canHandlePM': _canHandlePM,
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technician profile updated successfully'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Technician Profile Configurator', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInformation(),
                        const SizedBox(height: 20),
                        _buildPerformanceSnapshot(),
                        const SizedBox(height: 20),
                        _buildSkillsSection(),
                        const SizedBox(height: 20),
                        _buildTerritorySection(),
                        const SizedBox(height: 20),
                        _buildCapacityAndWorkingDays(),
                        const SizedBox(height: 20),
                        _buildAvailabilityAndCapabilities(),
                        const SizedBox(height: 20),
                        _buildLeaveManagement(),
                        const SizedBox(height: 20),
                        _buildInternalRemarks(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomSaveBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInformation() {
    final d = widget.existingData;
    final name = _safeString(d['name'] ?? d['fullName'] ?? d['employeeName']);
    final email = _safeString(d['email']);
    final mobile = _safeString(d['mobile'] ?? d['mobileNumber'] ?? d['phone']);
    final dept = _safeString(d['department'] ?? d['departmentName']);
    final desig = _safeString(d['designation'] ?? d['designationName']);

    return _SectionBlock(
      title: '1. Basic Information (Read-Only)',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 28)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                const SizedBox(height: 4),
                Text('$desig • $dept', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500), const SizedBox(width: 4),
                    Text(mobile.isEmpty ? 'N/A' : mobile, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(width: 16),
                    Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500), const SizedBox(width: 4),
                    Text(email.isEmpty ? 'N/A' : email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSnapshot() {
    if (_isLoadingStats) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }

    return _SectionBlock(
        title: '9. Performance Snapshot',
        child: Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            _buildKpiCard('Open Visits', _openVisits.toString(), Icons.pending_actions, Colors.blue),
            _buildKpiCard('Completed Visits', _completedVisits.toString(), Icons.task_alt, Colors.green),
            _buildKpiCard('Upcoming Visits', _upcomingVisits.toString(), Icons.event_available, Colors.orange),
            _buildKpiCard('This Month Visits', _thisMonthVisits.toString(), Icons.calendar_month, Colors.purple),
          ],
        )
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    List<String> availableSecondary = _secondarySkillOptions.where((s) => s != _primarySkill).toList();

    return _SectionBlock(
        title: '2. Skills',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _primarySkill,
                    decoration: _inputDecoration('Primary Skill'),
                    items: _primarySkillOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _primarySkill = val!;
                        _secondarySkillsList.remove(_primarySkill);
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
                    decoration: _inputDecoration('Experience (Years)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Secondary Skills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: availableSecondary.map((skill) {
                final isSelected = _secondarySkillsList.contains(skill);
                return FilterChip(
                  label: Text(skill, style: TextStyle(fontSize: 12, color: isSelected ? Colors.blue.shade800 : Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.blue.withValues(alpha: 0.1),
                  checkmarkColor: Colors.blue.shade800,
                  backgroundColor: Colors.grey.shade50,
                  side: BorderSide(color: isSelected ? Colors.blue.withValues(alpha: 0.5) : Colors.grey.shade300),
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
            const Text('Certifications', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _certOptions.map((cert) {
                final isSelected = _certificationsList.contains(cert);
                return FilterChip(
                  avatar: isSelected ? const Icon(Icons.verified, size: 16, color: Colors.green) : null,
                  label: Text(cert, style: TextStyle(fontSize: 12, color: isSelected ? Colors.green.shade800 : Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.green.shade50,
                  showCheckmark: false,
                  backgroundColor: Colors.grey.shade50,
                  side: BorderSide(color: isSelected ? Colors.green.shade300 : Colors.grey.shade300),
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

  Widget _buildTerritorySection() {
    return _SectionBlock(
        title: '3. Territory',
        child: Row(
          children: [
            Expanded(child: TextFormField(controller: _territoryController, decoration: _inputDecoration('Primary Territory'))),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _regionController, decoration: _inputDecoration('Service Region'))),
          ],
        )
    );
  }

  Widget _buildCapacityAndWorkingDays() {
    return _SectionBlock(
        title: '4. Capacity & 5. Working Days',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _dailyCapCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration('Daily Capacity (Visits)'),
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _monthlyCapCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration('Monthly Capacity (Visits)'),
                )),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Working Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _dayOptions.map((day) {
                final isSelected = _workingDaysList.contains(day);
                return FilterChip(
                  label: Text(day, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: Colors.blueGrey.shade700,
                  backgroundColor: Colors.grey.shade100,
                  checkmarkColor: Colors.white,
                  side: isSelected ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
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

  Widget _buildAvailabilityAndCapabilities() {
    return _SectionBlock(
        title: '6. Availability & 7. Service Capability',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String>(
                value: _availabilityStatus,
                decoration: _inputDecoration('Current Availability'),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _availabilityStatus = val!),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Service Capability', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24, runSpacing: 12,
              children: [
                _buildCheckbox('Can Handle Installation', _canHandleInstallation, (v) => setState(() => _canHandleInstallation = v)),
                _buildCheckbox('Can Handle Breakdown', _canHandleBreakdown, (v) => setState(() => _canHandleBreakdown = v)),
                _buildCheckbox('Can Handle PM', _canHandlePM, (v) => setState(() => _canHandlePM = v)),
              ],
            )
          ],
        )
    );
  }

  Widget _buildCheckbox(String title, bool val, Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: val, onChanged: (v) => onChanged(v ?? false), activeColor: Colors.blue.shade700),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLeaveManagement() {
    String leaveDurationStr = '';
    if (_leaveFrom != null && _leaveTo != null) {
      final days = _leaveTo!.difference(_leaveFrom!).inDays + 1;
      if (days > 0) leaveDurationStr = '$days Days Leave Scheduled';
    }

    return _SectionBlock(
        title: '8. Leave Management',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _leaveFrom ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() { _leaveFrom = d; _checkAutoLeaveStatus(); });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_leaveFrom != null ? DateFormat('MMM dd, yyyy').format(_leaveFrom!) : 'Leave From', style: TextStyle(color: _leaveFrom != null ? Colors.black87 : Colors.grey.shade600)),
                          Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _leaveTo ?? _leaveFrom ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() { _leaveTo = d; _checkAutoLeaveStatus(); });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_leaveTo != null ? DateFormat('MMM dd, yyyy').format(_leaveTo!) : 'Leave To', style: TextStyle(color: _leaveTo != null ? Colors.black87 : Colors.grey.shade600)),
                          Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_leaveFrom != null || _leaveTo != null) ...[
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.clear, color: Colors.red), tooltip: 'Clear Leave', onPressed: () => setState((){ _leaveFrom = null; _leaveTo = null; })),
                ]
              ],
            ),
            if (leaveDurationStr.isNotEmpty) ... [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade100)),
                child: Text(leaveDurationStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
              )
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _leaveReasonController,
              decoration: _inputDecoration('Leave Reason'),
            ),
          ],
        )
    );
  }

  Widget _buildInternalRemarks() {
    return _SectionBlock(
        title: '10. Internal Remarks',
        child: TextFormField(
          controller: _remarksController,
          maxLines: 3,
          decoration: _inputDecoration('Internal notes for dispatchers...'),
        )
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -4), blurRadius: 10)]
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade400)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade800)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}