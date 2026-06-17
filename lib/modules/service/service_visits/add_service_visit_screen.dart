import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddServiceVisitScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;
  final String? prefillRequestId; // Optional: If opening directly from a Service Request

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

  // --- RELATIONSHIP STATE ---
  String? _selectedRequestId;
  String? _selectedRequestNumber;
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  String? _engineerUid;
  String? _engineerName;

  // --- FORM STATE ---
  String _visitType = 'Inspection';
  String _visitStatus = 'Scheduled';
  String _workflowStage = 'VISIT_SCHEDULED';
  DateTime _visitDate = DateTime.now();

  final TextEditingController _observationCtrl = TextEditingController();
  final TextEditingController _workDoneCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _nextActionCtrl = TextEditingController();

  List<Map<String, dynamic>> _partsRequired = [];

  // --- CONSTANTS ---
  final List<String> _visitTypes = [
    'Inspection', 'Repair', 'Installation', 'Preventive Maintenance', 'Training'
  ];

  final List<String> _visitStatuses = [
    'Scheduled', 'In Progress', 'Completed', 'Cancelled'
  ];

  final List<String> _workflowStages = [
    'VISIT_SCHEDULED', 'VISIT_IN_PROGRESS', 'WAITING_CUSTOMER_APPROVAL',
    'WAITING_VISIT_APPROVAL', 'WAITING_SPARE_PARTS', 'WAITING_SPARE_APPROVAL',
    'WORK_COMPLETED', 'CUSTOMER_SIGNOFF', 'CLOSED'
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
  }

  void _initData() {
    if (widget.existingData != null) {
      final d = widget.existingData!;
      _selectedRequestId = d['requestId'];
      _selectedRequestNumber = d['requestNumber'];
      _selectedCustomerId = d['customerId'];
      _selectedCustomerName = d['customerName'];

      _engineerUid = d['engineerUid'];
      _engineerName = d['engineerName'];

      _visitType = d['visitType'] ?? 'Inspection';
      _visitStatus = d['visitStatus'] ?? 'Scheduled';
      _workflowStage = d['workflowStage'] ?? 'VISIT_SCHEDULED';

      if (d['visitDate'] != null) {
        _visitDate = (d['visitDate'] as Timestamp).toDate();
      }

      _observationCtrl.text = d['observation'] ?? '';
      _workDoneCtrl.text = d['workDone'] ?? '';
      _remarksCtrl.text = d['remarks'] ?? '';
      _nextActionCtrl.text = d['nextAction'] ?? '';

      if (d['partsRequired'] is List) {
        _partsRequired = List<Map<String, dynamic>>.from(
            (d['partsRequired'] as List).map((x) => Map<String, dynamic>.from(x))
        );
      }
    } else {
      // Set defaults for new visit
      _engineerUid = widget.currentUserUid;
      _engineerName = widget.currentUserName;

      if (widget.prefillRequestId != null) {
        _selectedRequestId = widget.prefillRequestId;
        _fetchAndPopulateRequestDetails(widget.prefillRequestId!);
      }
    }
  }

  @override
  void dispose() {
    _observationCtrl.dispose();
    _workDoneCtrl.dispose();
    _remarksCtrl.dispose();
    _nextActionCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // ENTERPRISE USER HELPERS
  // ==========================================

  String _getUserDisplayName(Map<String, dynamic>? userData) {
    if (userData == null) return 'Unknown User';
    final name = userData['name'] ?? userData['fullName'] ?? userData['employeeName'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }
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

  bool _isServiceEngineer(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    final dept = _getUserDepartment(userData).toLowerCase();
    final desig = _getUserDesignation(userData).toLowerCase();

    // Strict exact match for Department
    final isServiceDept = dept == 'service';

    // Contains match for Designation
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
        setState(() {
          _selectedRequestNumber = doc.data()?['requestNumber'];
          _selectedCustomerId = doc.data()?['customerId'];
          _selectedCustomerName = doc.data()?['customerName'];
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

  void _addPartRequired() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

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
          'engineerUid': _engineerUid,
          'engineerName': _engineerName ?? 'Unassigned',
          'visitType': _visitType,
          'visitStatus': _visitStatus,
          'workflowStage': _workflowStage,
          'visitDate': Timestamp.fromDate(_visitDate),
          'observation': _observationCtrl.text.trim(),
          'workDone': _workDoneCtrl.text.trim(),
          'remarks': _remarksCtrl.text.trim(),
          'nextAction': _nextActionCtrl.text.trim(),
          'partsRequired': _partsRequired,
          'isDeleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isNew) {
          visitData['createdAt'] = FieldValue.serverTimestamp();
          visitData['createdBy'] = widget.currentUserUid;
          visitData['createdByName'] = widget.currentUserName;
          transaction.set(_visitsRef.doc(docId), visitData);
        } else {
          transaction.update(_visitsRef.doc(docId), visitData);
        }

        // 🛡️ CRITICAL ERP REQUIREMENT: UPDATE PARENT SERVICE REQUEST
        final srRef = _requestsRef.doc(_selectedRequestId);
        final srUpdates = <String, dynamic>{
          'lastVisitDate': Timestamp.fromDate(_visitDate),
          'lastVisitEngineer': _engineerName ?? 'Unassigned',
          'lastVisitRemarks': _remarksCtrl.text.trim(),
          'lastActivity': 'Visit $visitNo (${_visitStatus.toUpperCase()})',
          'lastActivityAt': FieldValue.serverTimestamp(),
          'currentWorkflowStage': _workflowStage,
          'workflowUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isNew) {
          srUpdates['visitCount'] = FieldValue.increment(1);
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
        title: Text(widget.existingDocId == null ? 'Record Service Visit' : 'Edit Service Visit', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRequestLinkSection(),
                        const SizedBox(height: 16),
                        _buildVisitDetailsSection(),
                        const SizedBox(height: 16),
                        _buildExecutionSection(),
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

  Widget _buildRequestLinkSection() {
    return _SectionBlock(
      title: 'Parent Service Request',
      subtitle: 'Link this visit to an open service request',
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _requestsRef.where('isDeleted', isEqualTo: false).snapshots(),
            builder: (context, snap) {
              List<DropdownMenuItem<String>> items = [];
              if (snap.hasData) {
                // Ensure current selected exists in list (even if closed/deleted later)
                bool found = false;
                for (var doc in snap.data!.docs) {
                  if (doc.id == _selectedRequestId) found = true;
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
                  if (val != null && snap.hasData) {
                    final doc = snap.data!.docs.firstWhere((d) => d.id == val);
                    setState(() {
                      _selectedRequestId = val;
                      _selectedRequestNumber = doc.data()['requestNumber'];
                      _selectedCustomerId = doc.data()['customerId'];
                      _selectedCustomerName = doc.data()['customerName'];
                    });
                  }
                },
                validator: (v) => v == null ? 'Required' : null,
              );
            },
          ),
          if (_selectedCustomerName != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
              child: Row(
                children: [
                  Icon(Icons.business, size: 20, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Customer: $_selectedCustomerName', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade900))),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildVisitDetailsSection() {
    return _SectionBlock(
      title: 'Visit Scheduling & Workflow',
      subtitle: 'Define the nature of this visit and its current status',
      child: Column(
        children: [
          _buildResponsiveRow([
            // 🛡️ ENHANCED: Only load active Service Engineers/Technicians
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersRef.where('isActive', isEqualTo: true).snapshots(),
              builder: (context, snap) {
                List<DropdownMenuItem<String>> items = [];
                Set<String> addedUids = {};

                if (snap.hasData) {
                  for (var doc in snap.data!.docs) {
                    final data = doc.data();

                    final name = _getUserDisplayName(data);
                    final dept = _getUserDepartment(data);
                    final desig = _getUserDesignation(data);

                    // Strict filter evaluation
                    final isAllowed = _isServiceEngineer(data);

                    assert(() {
                      debugPrint(
                          'Engineer Filter -> '
                              'Name: $name | '
                              'Dept: $dept | '
                              'Designation: $desig | '
                              'Allowed: $isAllowed'
                      );
                      return true;
                    }());

                    if (isAllowed) {
                      final uid = doc.id;
                      if (!addedUids.contains(uid)) {
                        addedUids.add(uid);
                        final display = desig.isNotEmpty ? '$name - $desig' : name;
                        items.add(DropdownMenuItem(value: uid, child: Text(display)));
                      }
                    }
                  }
                }

                // 🛡️ STRICT LEGACY FALLBACK: Only inject if EDITING an existing record
                final isEditMode = widget.existingDocId != null;
                if (isEditMode && _engineerUid != null && !addedUids.contains(_engineerUid)) {
                  items.add(DropdownMenuItem(
                      value: _engineerUid,
                      child: Text('${_engineerName ?? 'Unknown User'} (Legacy User)')
                  ));
                  addedUids.add(_engineerUid!);
                }

                // 🛡️ EMPTY STATE HANDLING: Prevent Dropdown Crash
                if (items.isEmpty) {
                  return TextFormField(
                    enabled: false,
                    decoration: _inputDecoration(label: 'Assigned Engineer *', icon: Icons.engineering_outlined).copyWith(
                      hintText: 'No Service Engineers Available',
                      fillColor: Colors.grey.shade100,
                    ),
                  );
                }

                final safeEngineerUid = addedUids.contains(_engineerUid) ? _engineerUid : null;

                return DropdownButtonFormField<String>(
                  value: safeEngineerUid,
                  decoration: _inputDecoration(label: 'Assigned Engineer *', icon: Icons.engineering_outlined),
                  items: items,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _engineerUid = val;
                        if (snap.hasData) {
                          try {
                            final selectedDoc = snap.data!.docs.firstWhere((d) => d.id == val);
                            final data = selectedDoc.data();
                            _engineerName = _getUserDisplayName(data);
                          } catch (_) {
                            // If user selected legacy fallback, retain the current name
                          }
                        }
                      });
                    }
                  },
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
            ),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: _inputDecoration(label: 'Visit Date *', icon: Icons.calendar_today),
                child: Text('${_visitDate.day}/${_visitDate.month}/${_visitDate.year}', style: const TextStyle(fontSize: 15)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _buildResponsiveRow([
            _buildDropdown(label: 'Visit Type *', value: _visitType, items: _visitTypes, icon: Icons.category_outlined, onChanged: (v) => setState(() => _visitType = v!)),
            _buildDropdown(label: 'Visit Status *', value: _visitStatus, items: _visitStatuses, icon: Icons.flag_outlined, onChanged: (v) => setState(() => _visitStatus = v!)),
          ]),
          const SizedBox(height: 12),
          _buildDropdown(label: 'Workflow Stage (Syncs to Request) *', value: _workflowStage, items: _workflowStages, icon: Icons.account_tree_outlined, onChanged: (v) => setState(() => _workflowStage = v!)),
        ],
      ),
    );
  }

  Widget _buildExecutionSection() {
    return _SectionBlock(
      title: 'Execution Details',
      subtitle: 'Log observations, work performed, and next steps',
      child: Column(
        children: [
          _buildTextField(label: 'Observations / Findings', controller: _observationCtrl, icon: Icons.visibility_outlined, maxLines: 3),
          const SizedBox(height: 12),
          _buildTextField(label: 'Work Done / Actions Taken', controller: _workDoneCtrl, icon: Icons.build_circle_outlined, maxLines: 3),
          const SizedBox(height: 12),
          _buildResponsiveRow([
            _buildTextField(label: 'Next Action', controller: _nextActionCtrl, icon: Icons.next_plan_outlined),
            _buildTextField(label: 'Internal Remarks', controller: _remarksCtrl, icon: Icons.notes),
          ]),
        ],
      ),
    );
  }

  Widget _buildPartsRequiredSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parts Required (If Any)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              OutlinedButton.icon(
                onPressed: _addPartRequired,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Part'),
              ),
            ],
          ),
          if (_partsRequired.isNotEmpty) ...[
            const SizedBox(height: 16),
            Table(
              columnWidths: const { 0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: IntrinsicColumnWidth() },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('Part Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Padding(padding: EdgeInsets.all(8), child: Text('')),
                  ],
                ),
                ..._partsRequired.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return TableRow(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(item['partName'] ?? '', style: const TextStyle(fontSize: 13))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(item['quantity'].toString(), style: const TextStyle(fontSize: 13))),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => setState(() => _partsRequired.removeAt(idx))),
                    ],
                  );
                }),
              ],
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)]
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
              label: Text(widget.existingDocId == null ? 'Save Visit' : 'Update Visit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList(),
        );
      },
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}