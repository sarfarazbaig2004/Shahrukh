// FILE PATH: lib/modules/service/service_visits/add_service_visit_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

class AddServiceVisitScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;
  final String? prefillRequestId;

  const AddServiceVisitScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    this.existingDocId,
    this.existingData,
    this.prefillRequestId,
  });

  @override
  State<AddServiceVisitScreen> createState() => _AddServiceVisitScreenState();
}

class _AddServiceVisitScreenState extends State<AddServiceVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // --- REQUEST RELATIONSHIP STATE ---
  String? _selectedRequestId;
  String? _selectedRequestNumber;
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  int _machineCount = 0;
  List<String> _machineNames = [];
  String _complaintDescription = '';
  String _warrantyStatus = 'Unknown';
  String _requestPriority = 'Medium';
  String _requestServiceType = '-';
  DateTime? _requestCreatedDate;

  // --- TECHNICIAN ASSIGNMENT & WORKLOAD ---
  String? _assignedTechnicianUid;
  String? _assignedTechnicianName;
  String? _assignedTechnicianMobile;
  Map<String, int> _technicianWorkload = {};
  StreamSubscription? _workloadSubscription;

  // --- VISIT SCHEDULING STATE ---
  String _visitType = 'Breakdown';
  String _visitStatus = 'Scheduled';
  String _priority = 'Medium';
  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();
  String _expectedDuration = '2 Hours';

  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _internalNotesCtrl = TextEditingController();

  List<Map<String, dynamic>> _partsRequired = [];

  // --- CONSTANTS ---
  final List<String> _visitTypes = [
    'Breakdown', 'Preventive Maintenance', 'Installation',
    'Commissioning', 'Warranty', 'AMC', 'General Service'
  ];

  final List<String> _priorities = [
    'Low', 'Medium', 'High', 'Critical'
  ];

  final List<String> _durations = [
    '1 Hour', '2 Hours', '3 Hours', '4 Hours', 'Half Day', 'Full Day', 'Multiple Days'
  ];

  // --- GETTERS ---
  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_requests');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users');

  CollectionReference<Map<String, dynamic>> get _visitsRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits');

  @override
  void initState() {
    super.initState();
    _initData();
    _listenToTechnicianWorkload();
  }

  void _initData() {
    if (widget.existingData != null) {
      final d = widget.existingData!;
      _selectedRequestId = _safeString(d['requestId']).isEmpty ? null : _safeString(d['requestId']);
      _selectedRequestNumber = _safeString(d['requestNumber']).isEmpty ? null : _safeString(d['requestNumber']);
      _selectedCustomerId = _safeString(d['customerId']).isEmpty ? null : _safeString(d['customerId']);
      _selectedCustomerName = _safeString(d['customerName']).isEmpty ? null : _safeString(d['customerName']);

      _machineCount = _safeInt(d['machineCount']);
      if (d['machineNames'] is List) {
        _machineNames = List<String>.from(d['machineNames']);
      }
      _complaintDescription = _safeString(d['complaintDescription']);
      _warrantyStatus = _safeString(d['warrantyStatus']).isNotEmpty ? _safeString(d['warrantyStatus']) : 'Unknown';
      _priority = _safeString(d['priority']).isNotEmpty ? _safeString(d['priority']) : 'Medium';

      // Support legacy fields & new fields
      _assignedTechnicianUid = _safeString(d['assignedTechnicianUid']).isNotEmpty ? _safeString(d['assignedTechnicianUid']) : (_safeString(d['engineerUid']).isEmpty ? null : _safeString(d['engineerUid']));
      _assignedTechnicianName = _safeString(d['assignedTechnicianName']).isNotEmpty ? _safeString(d['assignedTechnicianName']) : (_safeString(d['engineerName']).isEmpty ? null : _safeString(d['engineerName']));
      _assignedTechnicianMobile = _safeString(d['assignedTechnicianMobile']).isEmpty ? null : _safeString(d['assignedTechnicianMobile']);

      _visitType = _safeString(d['visitType']).isNotEmpty ? _safeString(d['visitType']) : 'Breakdown';
      _visitStatus = _safeString(d['visitStatus']).isNotEmpty ? _safeString(d['visitStatus']) : 'Scheduled';
      _expectedDuration = _safeString(d['expectedDuration']).isNotEmpty ? _safeString(d['expectedDuration']) : '2 Hours';

      if (d['visitDate'] != null) {
        _visitDate = _extractDate(d['visitDate']) ?? DateTime.now();
      }

      final vTimeStr = _safeString(d['visitTime']);
      if (vTimeStr.isNotEmpty) {
        try {
          final parts = vTimeStr.split(' ');
          final timeParts = parts[0].split(':');
          int hour = int.parse(timeParts[0]);
          final min = int.parse(timeParts[1]);
          if (parts.length > 1) {
            if (parts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
            if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
          }
          _visitTime = TimeOfDay(hour: hour, minute: min);
        } catch (_) {}
      }

      _remarksCtrl.text = _safeString(d['remarks']);
      _internalNotesCtrl.text = _safeString(d['internalNotes']);

      if (d['partsRequired'] is List) {
        _partsRequired = List<Map<String, dynamic>>.from(
            (d['partsRequired'] as List).map((x) => Map<String, dynamic>.from(x))
        );
      }

      if (_selectedRequestId != null && _selectedRequestId!.isNotEmpty) {
        _fetchAndPopulateRequestDetails(_selectedRequestId!);
      }
    } else {
      if (widget.prefillRequestId != null) {
        _selectedRequestId = widget.prefillRequestId;
        _fetchAndPopulateRequestDetails(widget.prefillRequestId!);
      }
    }
  }

  void _listenToTechnicianWorkload() {
    _workloadSubscription = _visitsRef
        .where('isDeleted', isEqualTo: false)
        .where('visitStatus', whereIn: ['Scheduled', 'Travel Started', 'In Progress'])
        .snapshots()
        .listen((snap) {
      final Map<String, int> counts = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final uid = _safeString(data['assignedTechnicianUid']);
        final engUid = _safeString(data['engineerUid']);
        final targetUid = uid.isNotEmpty ? uid : engUid;

        if (targetUid.isNotEmpty) {
          counts[targetUid] = (counts[targetUid] ?? 0) + 1;
        }
      }
      if (mounted) {
        setState(() {
          _technicianWorkload = counts;
        });
      }
    });
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    _internalNotesCtrl.dispose();
    _workloadSubscription?.cancel();
    super.dispose();
  }

  // ==========================================
  // ENTERPRISE USER HELPERS
  // ==========================================

  String _getUserDisplayName(Map<String, dynamic>? userData) {
    if (userData == null) return 'Unknown User';
    final name = userData['name'] ?? userData['fullName'] ?? userData['employeeName'];
    if (name != null && name.toString().trim().isNotEmpty) return name.toString().trim();
    return 'Unknown User';
  }

  String _getUserDepartment(Map<String, dynamic>? userData) {
    if (userData == null) return '';
    return (userData['department'] ?? userData['departmentName'] ?? '').toString().trim();
  }

  String _getUserDesignation(Map<String, dynamic>? userData) {
    if (userData == null) return '';
    return (userData['designation'] ?? userData['designationName'] ?? '').toString().trim();
  }

  String _getUserMobile(Map<String, dynamic>? userData) {
    if (userData == null) return '';
    return (userData['mobile'] ?? userData['mobileNumber'] ?? userData['phone'] ?? '').toString().trim();
  }

  bool _isServiceTechnician(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    final dept = _getUserDepartment(userData).toLowerCase();
    final desig = _getUserDesignation(userData).toLowerCase();
    final isServiceDept = dept.contains('service');
    final isEngineerOrTech = desig.contains('engineer') || desig.contains('technician');
    return isServiceDept && isEngineerOrTech;
  }

  // ==========================================
  // DATA FETCHING & ACTIONS
  // ==========================================

  Future<void> _fetchAndPopulateRequestDetails(String reqId) async {
    try {
      final doc = await _requestsRef.doc(reqId).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;

        int mCount = 0;
        List<String> mNames = [];
        String wStatus = 'Unknown';

        if (d['serviceItems'] is List) {
          final items = d['serviceItems'] as List;
          mCount = items.length;
          for (var item in items) {
            if (item is Map) {
              final mName = _safeString(item['itemName'] ?? item['machineName']);
              if (mName.isNotEmpty) mNames.add(mName);

              if (wStatus == 'Unknown') {
                final wEnd = _extractDate(item['warrantyEndDate']);
                final amcEnd = _extractDate(item['amcEndDate']);
                final now = DateTime.now();
                if (amcEnd != null) {
                  wStatus = amcEnd.isAfter(now) ? 'AMC Active' : 'AMC Expired';
                } else if (wEnd != null) {
                  wStatus = wEnd.isAfter(now) ? 'Under Warranty' : 'Out Of Warranty';
                } else if (item['isWarranty'] == true || item['isWarranty'] == 'true') {
                  wStatus = 'Under Warranty';
                }
              }
            }
          }
        } else {
          final mName = _safeString(d['machineName'] ?? d['machineModel']);
          if (mName.isNotEmpty) {
            mNames.add(mName);
            mCount = 1;
          }
        }

        setState(() {
          _selectedRequestNumber = _safeString(d['requestNumber']);
          _selectedCustomerId = _safeString(d['customerId']);
          _selectedCustomerName = _safeString(d['customerName']);
          _complaintDescription = _safeString(d['complaintDescription']);
          _requestPriority = _safeString(d['priority']).isNotEmpty ? _safeString(d['priority']) : 'Medium';
          _requestServiceType = _safeString(d['complaintCategory']).isNotEmpty ? _safeString(d['complaintCategory']) : '-';
          _requestCreatedDate = _extractDate(d['createdAt']);
          _machineCount = mCount;
          _machineNames = mNames;
          if (wStatus != 'Unknown') _warrantyStatus = wStatus;
        });
      }
    } catch (_) {}
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _visitDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
    );
    if (picked != null && mounted) {
      setState(() => _visitTime = picked);
    }
  }

  void _addPartRequired() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Required Part'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Part Name / Description')),
            const SizedBox(height: 12),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _partsRequired.add({
                    'partName': nameCtrl.text.trim(),
                    'quantity': double.tryParse(qtyCtrl.text.trim()) ?? 1.0,
                    'remarks': remarksCtrl.text.trim(),
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = "0${tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod}".length > 2
        ? "${tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod}"
        : "0${tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod}";
    final min = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$min $period";
  }

  // --- SAVE ENGINE & PARENT SYNC ---
  String _getFinancialYear() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return '${startYear.toString().substring(2)}-${endYear.toString().substring(2)}';
  }

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRequestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Service Request.'), backgroundColor: Colors.red));
      return;
    }
    if (_assignedTechnicianUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please assign a Service Technician.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((transaction) async {
        String docId = widget.existingDocId ?? _visitsRef.doc().id;
        String visitNo = widget.existingData?['visitNo'] ?? '';
        bool isNew = widget.existingDocId == null;

        if (isNew) {
          final fy = _getFinancialYear();
          final counterRef = db.collection('companies').doc(widget.companyId).collection('counters').doc('service_visit_$fy');
          final counterSnap = await transaction.get(counterRef);
          int nextSeq = 1;

          if (counterSnap.exists) {
            nextSeq = (counterSnap.data()?['sequence'] ?? 0) + 1;
          }
          transaction.set(counterRef, {'sequence': nextSeq}, SetOptions(merge: true));
          visitNo = 'VIS/$fy/${nextSeq.toString().padLeft(4, '0')}';
        }

        final visitData = {
          'id': docId,
          'companyId': widget.companyId,
          'visitNo': visitNo,
          'requestId': _selectedRequestId,
          'requestNumber': _selectedRequestNumber ?? '',
          'customerId': _selectedCustomerId ?? '',
          'customerName': _selectedCustomerName ?? '',

          'machineCount': _machineCount,
          'machineNames': _machineNames,
          'complaintDescription': _complaintDescription,

          'priority': _priority,
          'visitType': _visitType,

          'visitDate': Timestamp.fromDate(_visitDate),
          'visitTime': _formatTimeOfDay(_visitTime),
          'visitHour': _visitTime.hour,
          'visitMinute': _visitTime.minute,
          'visitDay': _visitDate.day,
          'visitMonth': _visitDate.month,
          'visitYear': _visitDate.year,

          'expectedDuration': _expectedDuration,

          'assignedTechnicianUid': _assignedTechnicianUid,
          'assignedTechnicianName': _assignedTechnicianName ?? 'Unassigned',
          'assignedTechnicianMobile': _assignedTechnicianMobile ?? '',

          // Legacy mappings to prevent breaks
          'engineerUid': _assignedTechnicianUid,
          'engineerName': _assignedTechnicianName ?? 'Unassigned',

          'remarks': _remarksCtrl.text.trim(),
          'internalNotes': _internalNotesCtrl.text.trim(),
          'partsRequired': _partsRequired,

          'isDeleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isNew) {
          visitData['visitStatus'] = 'Scheduled';
          visitData['createdAt'] = FieldValue.serverTimestamp();
          visitData['createdBy'] = widget.currentUserUid;
          visitData['createdByName'] = widget.currentUserName;
          transaction.set(_visitsRef.doc(docId), visitData);
        } else {
          visitData['visitStatus'] = _visitStatus;
          transaction.update(_visitsRef.doc(docId), visitData);
        }

        // 🛡️ CRITICAL ERP REQUIREMENT: UPDATE PARENT SERVICE REQUEST
        final srRef = _requestsRef.doc(_selectedRequestId);
        final srUpdates = <String, dynamic>{
          'status': 'Visit Created',
          'lastVisitNo': visitNo,
          'lastVisitDate': Timestamp.fromDate(_visitDate),
          'lastVisitEngineer': _assignedTechnicianName ?? 'Unassigned',
          'lastActivity': 'Visit $visitNo Scheduled',
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isNew) {
          srUpdates['visitCount'] = FieldValue.increment(1);
          srUpdates['visitCreatedAt'] = FieldValue.serverTimestamp();
        }

        transaction.set(srRef, srUpdates, SetOptions(merge: true));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Visit saved successfully.'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(widget.existingDocId == null ? 'Schedule Service Visit' : 'Edit Visit Schedule', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiBanner(),
                        const SizedBox(height: 16),
                        _buildRequestSelectionSection(),
                        const SizedBox(height: 16),
                        if (_selectedRequestId != null) ...[
                          _buildRequestInformationCard(),
                          const SizedBox(height: 16),
                        ],
                        _buildSchedulingSection(),
                        const SizedBox(height: 16),
                        _buildTechnicianSection(),
                        const SizedBox(height: 16),
                        _buildNotesSection(),
                        const SizedBox(height: 16),
                        _buildPartsRequiredSection(),
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

  Widget _buildKpiBanner() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildKpiCard('Visit Type', _visitType, Icons.category, Colors.indigo),
          _buildKpiCard('Priority', _priority, Icons.flag, Colors.red),
          _buildKpiCard('Assigned To', _assignedTechnicianName ?? 'Pending', Icons.engineering, Colors.blue),
          _buildKpiCard('Machines', _machineCount.toString(), Icons.settings, Colors.orange),
          _buildKpiCard('Warranty', _warrantyStatus, Icons.verified_user, Colors.green),
          _buildKpiCard('Duration', _expectedDuration, Icons.timer, Colors.purple),
          _buildKpiCard('Visit Date', _formatDateOnly(_visitDate), Icons.calendar_month, Colors.teal),
        ],
      ),
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

  Widget _buildRequestSelectionSection() {
    return _SectionBlock(
      title: 'Request Selection',
      subtitle: 'Link this visit to an open service request',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requestsRef.where('isDeleted', isEqualTo: false).snapshots(),
        builder: (context, snap) {
          List<DropdownMenuItem<String>> items = [];
          if (snap.hasData) {
            bool found = false;
            for (var doc in snap.data!.docs) {
              final status = _safeString(doc.data()['status']);
              final isExcluded = ['Completed', 'Closed', 'Cancelled', 'Resolved'].contains(status);

              if (doc.id == _selectedRequestId) found = true;

              if (isExcluded && doc.id != _selectedRequestId) continue;

              final no = doc.data()['requestNumber'] ?? 'Unknown';
              final cName = doc.data()['customerName'] ?? 'Unknown';
              items.add(DropdownMenuItem(value: doc.id, child: Text('$no - $cName')));
            }
            if (!found && _selectedRequestId != null) {
              items.add(DropdownMenuItem(value: _selectedRequestId, child: Text('${_selectedRequestNumber ?? 'Unknown'} (Legacy)')));
            }
          }

          return DropdownButtonFormField<String>(
            value: _selectedRequestId,
            decoration: _inputDecoration(label: 'Select Service Request *', icon: Icons.assignment_outlined),
            items: items,
            isExpanded: true,
            onChanged: widget.existingDocId != null ? null : (val) {
              if (val != null) {
                setState(() {
                  _selectedRequestId = val;
                });
                _fetchAndPopulateRequestDetails(val);
              }
            },
            validator: (v) => v == null ? 'Required' : null,
          );
        },
      ),
    );
  }

  Widget _buildRequestInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blueGrey.shade700),
              const SizedBox(width: 8),
              Text('Request Information', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          _buildResponsiveRow([
            _infoItem('Request Number', _selectedRequestNumber ?? '-'),
            _infoItem('Customer Name', _selectedCustomerName ?? '-'),
            _infoItem('Customer ID', _selectedCustomerId ?? '-'),
          ]),
          const SizedBox(height: 12),
          _buildResponsiveRow([
            _infoItem('Service Type', _requestServiceType),
            _infoItem('Priority', _requestPriority),
            _infoItem('Created Date', _formatDateOnly(_requestCreatedDate)),
          ]),
          const SizedBox(height: 12),
          _buildResponsiveRow([
            _infoItem('Machines Count', _machineCount.toString()),
            _infoItem('Warranty Status', _warrantyStatus),
            _infoItem('Machines', _machineNames.isEmpty ? '-' : _machineNames.join(", ")),
          ]),
          if (_complaintDescription.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoItem('Complaint Description', _complaintDescription),
          ]
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSchedulingSection() {
    return _SectionBlock(
      title: 'Visit Scheduling',
      subtitle: 'Set schedule dates, time, and priority parameters',
      child: Column(
        children: [
          _buildResponsiveRow([
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: _inputDecoration(label: 'Visit Date *', icon: Icons.calendar_today),
                child: Text('${_visitDate.day.toString().padLeft(2,'0')}/${_visitDate.month.toString().padLeft(2,'0')}/${_visitDate.year}', style: const TextStyle(fontSize: 14)),
              ),
            ),
            InkWell(
              onTap: _selectTime,
              child: InputDecorator(
                decoration: _inputDecoration(label: 'Visit Time *', icon: Icons.access_time),
                child: Text(_formatTimeOfDay(_visitTime), style: const TextStyle(fontSize: 14)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildResponsiveRow([
            _buildDropdown(label: 'Visit Type *', value: _visitType, items: _visitTypes, icon: Icons.category_outlined, onChanged: (v) => setState(() => _visitType = v!)),
            _buildDropdown(label: 'Expected Duration *', value: _expectedDuration, items: _durations, icon: Icons.timer_outlined, onChanged: (v) => setState(() => _expectedDuration = v!)),
            _buildDropdown(label: 'Priority *', value: _priority, items: _priorities, icon: Icons.priority_high, onChanged: (v) => setState(() => _priority = v!)),
          ]),
        ],
      ),
    );
  }

  Widget _buildTechnicianSection() {
    return _SectionBlock(
      title: 'Technician Assignment',
      subtitle: 'Assign an active service engineer or technician and view their workload',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersRef.where('isActive', isEqualTo: true).snapshots(),
        builder: (context, snap) {
          List<DropdownMenuItem<String>> items = [];
          Set<String> addedUids = {};

          if (snap.hasData) {
            for (var doc in snap.data!.docs) {
              final data = doc.data();
              if (_isServiceTechnician(data)) {
                final uid = doc.id;
                if (!addedUids.contains(uid)) {
                  addedUids.add(uid);
                  items.add(_buildTechnicianMenuItem(uid, data));
                }
              }
            }
          }

          final isEditMode = widget.existingDocId != null;
          if (isEditMode && _assignedTechnicianUid != null && !addedUids.contains(_assignedTechnicianUid)) {
            items.add(DropdownMenuItem(
                value: _assignedTechnicianUid,
                child: Text('${_assignedTechnicianName ?? 'Unknown User'} (Legacy/Inactive)')
            ));
            addedUids.add(_assignedTechnicianUid!);
          }

          if (items.isEmpty) {
            return TextFormField(
              enabled: false,
              decoration: _inputDecoration(label: 'Assigned Technician *', icon: Icons.engineering_outlined).copyWith(
                hintText: 'No Service Technicians Available',
                fillColor: Colors.grey.shade100,
              ),
            );
          }

          final safeUid = addedUids.contains(_assignedTechnicianUid) ? _assignedTechnicianUid : null;

          return DropdownButtonFormField<String>(
            value: safeUid,
            itemHeight: 72,
            decoration: _inputDecoration(label: 'Assigned Technician *', icon: Icons.engineering_outlined),
            items: items,
            isExpanded: true,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _assignedTechnicianUid = val;
                  if (snap.hasData) {
                    try {
                      final selectedDoc = snap.data!.docs.firstWhere((d) => d.id == val);
                      final data = selectedDoc.data();
                      _assignedTechnicianName = _getUserDisplayName(data);
                      _assignedTechnicianMobile = _getUserMobile(data);
                    } catch (_) {}
                  }
                });
              }
            },
            validator: (v) => v == null ? 'Required' : null,
          );
        },
      ),
    );
  }

  DropdownMenuItem<String> _buildTechnicianMenuItem(String uid, Map<String, dynamic> data) {
    final name = _getUserDisplayName(data);
    final desig = _getUserDesignation(data);
    final mobile = _getUserMobile(data);
    final workload = _technicianWorkload[uid] ?? 0;

    Color badgeColor = workload <= 3 ? Colors.green : (workload <= 6 ? Colors.orange : Colors.red);

    return DropdownMenuItem<String>(
      value: uid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(desig, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              if (mobile.isNotEmpty) ...[
                Text(' | ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                Text(mobile, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: badgeColor)),
                child: Text('Open Visits: $workload', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _SectionBlock(
      title: 'Notes & Remarks',
      subtitle: 'Information for the technician and internal tracking',
      child: Column(
        children: [
          _buildTextField(label: 'Remarks (Visible to Technician)', controller: _remarksCtrl, icon: Icons.notes, maxLines: 2),
          const SizedBox(height: 16),
          _buildTextField(label: 'Internal Notes (Hidden from Customer/Technician app)', controller: _internalNotesCtrl, icon: Icons.lock_outline, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildPartsRequiredSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parts Required', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Specify spare parts to be carried by the technician', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _addPartRequired,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Part'),
              ),
            ],
          ),
          if (_partsRequired.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
              child: Table(
                columnWidths: const { 0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(2), 3: IntrinsicColumnWidth() },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                    children: const [
                      Padding(padding: EdgeInsets.all(12), child: Text('Part Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Padding(padding: EdgeInsets.all(12), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Padding(padding: EdgeInsets.all(12), child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Padding(padding: EdgeInsets.all(12), child: Text('')),
                    ],
                  ),
                  ..._partsRequired.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return TableRow(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
                      children: [
                        Padding(padding: const EdgeInsets.all(12), child: Text(_safeString(item['partName']), style: const TextStyle(fontSize: 13))),
                        Padding(padding: const EdgeInsets.all(12), child: Text(item['quantity'].toString(), style: const TextStyle(fontSize: 13))),
                        Padding(padding: const EdgeInsets.all(12), child: Text(_safeString(item['remarks']), style: const TextStyle(fontSize: 13))),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => setState(() => _partsRequired.removeAt(idx))),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ]
        ],
      ),
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
              onPressed: _isLoading ? null : _saveVisit,
              icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(widget.existingDocId == null ? 'Schedule Visit' : 'Update Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList());
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: c))).toList(),
        );
      },
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade400)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, required void Function(String?) onChanged, required IconData icon}) {
    List<String> safeItems = items.toSet().toList();
    if (!safeItems.contains(value)) safeItems.add(value);

    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label: label, icon: icon),
      items: safeItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionBlock({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}