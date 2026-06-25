// FILE PATH: lib/modules/service/service_sales_orders/create_service_sales_order_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateServiceSalesOrderScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;

  // Prefill Optional Parameters for Auto-Population
  final String? prefillQuotationId;
  final String? prefillQuotationNumber;
  final String? prefillRequestId;
  final String? prefillRequestNumber;
  final String? prefillCustomerId;
  final String? prefillCustomerName;
  final String? prefillSiteAddress;
  final String? prefillContactPerson;
  final String? prefillComplaint;
  final String? prefillScopeOfWork;

  const CreateServiceSalesOrderScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    this.existingDocId,
    this.existingData,
    this.prefillQuotationId,
    this.prefillQuotationNumber,
    this.prefillRequestId,
    this.prefillRequestNumber,
    this.prefillCustomerId,
    this.prefillCustomerName,
    this.prefillSiteAddress,
    this.prefillContactPerson,
    this.prefillComplaint,
    this.prefillScopeOfWork,
  });

  @override
  State<CreateServiceSalesOrderScreen> createState() => _CreateServiceSalesOrderScreenState();
}

class _CreateServiceSalesOrderScreenState extends State<CreateServiceSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploading = false;

  // Form Fields
  DateTime _ssoDate = DateTime.now();
  String? _selectedRequestId;
  String? _selectedRequestNumber;
  String? _selectedQuotationId;
  String? _selectedQuotationNumber;

  String _customerId = '';
  String _customerName = '';
  String _siteAddress = '';
  String _contactPerson = '';

  final TextEditingController _complaintCtrl = TextEditingController();
  final TextEditingController _scopeOfWorkCtrl = TextEditingController();

  String _poDocumentType = 'Purchase Order';
  final TextEditingController _poNumberCtrl = TextEditingController();
  DateTime? _poDate;
  final TextEditingController _poRefContactCtrl = TextEditingController();
  final TextEditingController _poRemarksCtrl = TextEditingController();
  String? _poAttachmentUrl;
  String? _poAttachmentName;

  List<String> _assignedTechnicianUids = [];
  String _status = 'Draft';
  final TextEditingController _internalNotesCtrl = TextEditingController();

  final List<String> _docTypes = ['Purchase Order', 'Work Order', 'Service Contract', 'Email Approval', 'Other'];
  final List<String> _statuses = ['Draft', 'Awaiting PO', 'Approved', 'In Progress', 'Completed', 'Closed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _loadExistingData(widget.existingData!);
    } else {
      // Pre-fill mode exclusively for new documents integration
      _selectedQuotationId = widget.prefillQuotationId;
      _selectedQuotationNumber = widget.prefillQuotationNumber;
      _selectedRequestId = widget.prefillRequestId;
      _selectedRequestNumber = widget.prefillRequestNumber;
      _customerId = widget.prefillCustomerId ?? '';
      _customerName = widget.prefillCustomerName ?? '';
      _siteAddress = widget.prefillSiteAddress ?? '';
      _contactPerson = widget.prefillContactPerson ?? '';
      _complaintCtrl.text = widget.prefillComplaint ?? '';
      _scopeOfWorkCtrl.text = widget.prefillScopeOfWork ?? '';
    }
  }

  void _loadExistingData(Map<String, dynamic> data) {
    _ssoDate = (data['ssoDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    _selectedRequestId = data['serviceRequestId'];
    _selectedRequestNumber = data['serviceRequestNumber'];
    _selectedQuotationId = data['serviceQuotationId'];
    _selectedQuotationNumber = data['serviceQuotationNumber'];
    _customerId = data['customerId'] ?? '';
    _customerName = data['customerName'] ?? '';
    _siteAddress = data['siteAddress'] ?? '';
    _contactPerson = data['contactPerson'] ?? '';
    _complaintCtrl.text = data['complaint'] ?? '';
    _scopeOfWorkCtrl.text = data['scopeOfWork'] ?? '';

    _poDocumentType = data['poDocumentType'] ?? 'Purchase Order';
    _poNumberCtrl.text = data['poNumber'] ?? '';
    _poDate = (data['poDate'] as Timestamp?)?.toDate();
    _poRefContactCtrl.text = data['poReferenceContact'] ?? '';
    _poRemarksCtrl.text = data['poRemarks'] ?? '';
    _poAttachmentUrl = data['poAttachmentUrl'];
    _poAttachmentName = data['poAttachmentName'];

    if (data['assignedTechnicians'] != null) {
      _assignedTechnicianUids = List<String>.from(data['assignedTechnicians']);
    }
    _status = data['status'] ?? 'Draft';
    _internalNotesCtrl.text = data['internalNotes'] ?? '';
  }

  @override
  void dispose() {
    _complaintCtrl.dispose();
    _scopeOfWorkCtrl.dispose();
    _poNumberCtrl.dispose();
    _poRefContactCtrl.dispose();
    _poRemarksCtrl.dispose();
    _internalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchQuotationDetails(String quoteId) async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_quotations').doc(quoteId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _selectedQuotationNumber = data['quoteNumber'] ?? data['quotationNumber'];
          _customerId = data['customerId'] ?? '';
          _customerName = data['customerName'] ?? data['clientName'] ?? '';
          _siteAddress = data['clientAddress'] ?? data['addressLine'] ?? '';
          _contactPerson = data['contactPerson'] ?? '';

          if (_complaintCtrl.text.isEmpty) {
            _complaintCtrl.text = data['remarks'] ?? data['subject'] ?? '';
          }

          if (_scopeOfWorkCtrl.text.isEmpty && data['items'] != null) {
            List items = data['items'];
            _scopeOfWorkCtrl.text = items.map((i) => i['itemName']).join(', ');
          }

          // Auto-link SR if available in Quotation
          if (data['serviceRequestId'] != null) {
            _selectedRequestId = data['serviceRequestId'];
            _selectedRequestNumber = data['serviceRequestNumber'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching quote: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRequestDetails(String reqId) async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_requests').doc(reqId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _selectedRequestNumber = data['requestNumber'];
          if (_customerId.isEmpty) _customerId = data['customerId'] ?? '';
          if (_customerName.isEmpty) _customerName = data['customerName'] ?? '';
          if (_siteAddress.isEmpty) _siteAddress = data['address'] ?? '';
          if (_contactPerson.isEmpty) _contactPerson = data['contactPerson'] ?? '';
          if (_complaintCtrl.text.isEmpty) _complaintCtrl.text = data['complaintDescription'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching request: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'docx', 'xlsx'],
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isUploading = true);
      try {
        final fileName = result.files.single.name;
        final ref = FirebaseStorage.instance.ref().child('companies/${widget.companyId}/sso_attachments/${DateTime.now().millisecondsSinceEpoch}_$fileName');
        await ref.putData(result.files.single.bytes!);
        final url = await ref.getDownloadURL();
        setState(() {
          _poAttachmentUrl = url;
          _poAttachmentName = fileName;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  String _getFinancialYear() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return '${startYear.toString().substring(2)}-${endYear.toString().substring(2)}';
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Quotation or Request to bind a Customer.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((tx) async {
        String docId = widget.existingDocId ?? db.collection('companies').doc(widget.companyId).collection('service_sales_orders').doc().id;
        String ssoNo = widget.existingData?['ssoNumber'] ?? '';
        bool isNew = widget.existingDocId == null;

        if (isNew) {
          final fy = _getFinancialYear();
          final counterRef = db.collection('companies').doc(widget.companyId).collection('counters').doc('service_sales_order_$fy');
          final counterSnap = await tx.get(counterRef);
          int nextSeq = 1;

          if (counterSnap.exists) {
            nextSeq = (counterSnap.data()?['sequence'] ?? 0) + 1;
          }
          tx.set(counterRef, {'sequence': nextSeq}, SetOptions(merge: true));
          ssoNo = 'SSO/$fy/${nextSeq.toString().padLeft(4, '0')}';
        }

        final payload = {
          'id': docId,
          'companyId': widget.companyId,
          'ssoNumber': ssoNo,
          'ssoDate': Timestamp.fromDate(_ssoDate),

          'serviceRequestId': _selectedRequestId,
          'serviceRequestNumber': _selectedRequestNumber,
          'serviceQuotationId': _selectedQuotationId,
          'serviceQuotationNumber': _selectedQuotationNumber,

          'customerId': _customerId,
          'customerName': _customerName,
          'siteAddress': _siteAddress,
          'contactPerson': _contactPerson,
          'complaint': _complaintCtrl.text.trim(),
          'scopeOfWork': _scopeOfWorkCtrl.text.trim(),

          'poDocumentType': _poDocumentType,
          'poNumber': _poNumberCtrl.text.trim(),
          'poDate': _poDate != null ? Timestamp.fromDate(_poDate!) : null,
          'poReferenceContact': _poRefContactCtrl.text.trim(),
          'poRemarks': _poRemarksCtrl.text.trim(),
          'poAttachmentUrl': _poAttachmentUrl,
          'poAttachmentName': _poAttachmentName,

          'assignedTechnicians': _assignedTechnicianUids,
          'status': _status,
          'internalNotes': _internalNotesCtrl.text.trim(),

          'isDeleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': widget.currentUserUid,
        };

        if (isNew) {
          payload['createdAt'] = FieldValue.serverTimestamp();
          payload['createdBy'] = widget.currentUserUid;
          payload['createdByName'] = widget.currentUserName;
        }

        final docRef = db.collection('companies').doc(widget.companyId).collection('service_sales_orders').doc(docId);
        tx.set(docRef, payload, SetOptions(merge: true));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Sales Order Saved Successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(widget.existingDocId == null ? 'New Service Sales Order' : 'Edit Service Sales Order', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
                        _buildBasicInformationSection(),
                        const SizedBox(height: 16),
                        _buildPOSection(),
                        const SizedBox(height: 16),
                        _buildTechnicianSection(),
                        const SizedBox(height: 16),
                        _buildStatusAndNotesSection(),
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

  Widget _buildBasicInformationSection() {
    return _SectionBlock(
      title: 'Basic Information',
      subtitle: 'Link order to existing Quotation or Request',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _ssoDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setState(() => _ssoDate = d);
                  },
                  child: InputDecorator(
                    decoration: _inputDecoration(label: 'SSO Date *', icon: Icons.calendar_today),
                    child: Text(DateFormat('dd-MM-yyyy').format(_ssoDate), style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_quotations').where('isDeleted', isEqualTo: false).snapshots(),
                  builder: (context, snap) {
                    List<DropdownMenuItem<String>> items = [];
                    if (snap.hasData) {
                      for (var doc in snap.data!.docs) {
                        items.add(DropdownMenuItem(value: doc.id, child: Text(doc['quoteNumber'] ?? doc['quotationNumber'] ?? doc.id)));
                      }
                    }
                    if (_selectedQuotationId != null && !items.any((e) => e.value == _selectedQuotationId)) {
                      items.add(DropdownMenuItem(value: _selectedQuotationId, child: Text(_selectedQuotationNumber ?? 'Legacy Quote')));
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedQuotationId,
                      decoration: _inputDecoration(label: 'Link Quotation', icon: Icons.request_quote),
                      items: items,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedQuotationId = val);
                          _fetchQuotationDetails(val);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_requests').where('isDeleted', isEqualTo: false).snapshots(),
                  builder: (context, snap) {
                    List<DropdownMenuItem<String>> items = [];
                    if (snap.hasData) {
                      for (var doc in snap.data!.docs) {
                        items.add(DropdownMenuItem(value: doc.id, child: Text(doc['requestNumber'] ?? doc.id)));
                      }
                    }
                    if (_selectedRequestId != null && !items.any((e) => e.value == _selectedRequestId)) {
                      items.add(DropdownMenuItem(value: _selectedRequestId, child: Text(_selectedRequestNumber ?? 'Legacy Request')));
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedRequestId,
                      decoration: _inputDecoration(label: 'Link Service Request', icon: Icons.assignment),
                      items: items,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRequestId = val);
                          _fetchRequestDetails(val);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_customerName.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: $_customerName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Site: $_siteAddress', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('Contact: $_contactPerson', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _complaintCtrl,
            maxLines: 2,
            decoration: _inputDecoration(label: 'Complaint / Issue', icon: Icons.error_outline),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _scopeOfWorkCtrl,
            maxLines: 3,
            decoration: _inputDecoration(label: 'Scope Of Work', icon: Icons.build_circle_outlined),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPOSection() {
    return _SectionBlock(
      title: 'Customer PO / Work Order',
      subtitle: 'Reference document details from the customer',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _poDocumentType,
                  decoration: _inputDecoration(label: 'Document Type', icon: Icons.description),
                  items: _docTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _poDocumentType = val!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _poNumberCtrl,
                  decoration: _inputDecoration(label: 'PO / Ref Number', icon: Icons.numbers),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _poDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setState(() => _poDate = d);
                  },
                  child: InputDecorator(
                    decoration: _inputDecoration(label: 'PO Date', icon: Icons.calendar_month),
                    child: Text(_poDate != null ? DateFormat('dd-MM-yyyy').format(_poDate!) : 'Select Date', style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _poRefContactCtrl,
                  decoration: _inputDecoration(label: 'Reference Contact', icon: Icons.person_outline),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _poRemarksCtrl,
                  decoration: _inputDecoration(label: 'PO Remarks', icon: Icons.notes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _uploadAttachment,
                icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Attachment'),
              ),
              const SizedBox(width: 16),
              if (_poAttachmentName != null)
                Expanded(child: Text(_poAttachmentName!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTechnicianSection() {
    return _SectionBlock(
      title: 'Technician Assignment',
      subtitle: 'Select one or more technicians for this order',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users').where('isActive', isEqualTo: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const CircularProgressIndicator();

          final serviceUsers = snap.data!.docs.where((doc) {
            final dept = (doc['department'] ?? doc['departmentName'] ?? '').toString().toLowerCase();
            final desig = (doc['designation'] ?? doc['designationName'] ?? '').toString().toLowerCase();
            return dept.contains('service') && (desig.contains('engineer') || desig.contains('technician'));
          }).toList();

          if (serviceUsers.isEmpty) return const Text('No Service Technicians found.');

          return Wrap(
            spacing: 12, runSpacing: 12,
            children: serviceUsers.map((doc) {
              final uid = doc.id;
              final name = doc['name'] ?? doc['fullName'] ?? 'Unknown';
              final isSelected = _assignedTechnicianUids.contains(uid);

              return FilterChip(
                label: Text(name),
                selected: isSelected,
                selectedColor: Colors.indigo.shade100,
                checkmarkColor: Colors.indigo.shade800,
                onSelected: (val) {
                  setState(() {
                    if (val) _assignedTechnicianUids.add(uid);
                    else _assignedTechnicianUids.remove(uid);
                  });
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildStatusAndNotesSection() {
    return _SectionBlock(
      title: 'Status & Internal Notes',
      subtitle: 'Set order status and private instructions',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _status,
            decoration: _inputDecoration(label: 'Order Status', icon: Icons.flag),
            items: _statuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _status = val!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _internalNotesCtrl,
            maxLines: 3,
            decoration: _inputDecoration(label: 'Internal Notes', icon: Icons.security),
          ),
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
              onPressed: _isLoading ? null : _saveOrder,
              icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(widget.existingDocId == null ? 'Create Sales Order' : 'Update Order'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            ),
          ],
        ),
      ),
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.indigo.shade400)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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