import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class ScreensAddComplianceLegal extends StatefulWidget {
  final String companyId;
  final String? docId;
  final Map<String, dynamic>? existingData;

  const ScreensAddComplianceLegal({
    Key? key,
    required this.companyId,
    this.docId,
    this.existingData,
  }) : super(key: key);

  @override
  State<ScreensAddComplianceLegal> createState() => _ScreensAddComplianceLegalState();
}

class _ScreensAddComplianceLegalState extends State<ScreensAddComplianceLegal> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _authorityController = TextEditingController();
  final TextEditingController _attachmentController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedCategory = 'Policy';
  DateTime? _issueDate;
  DateTime? _expiryDate;

  final List<String> _categories = ['Policy', 'Contract', 'Registration', 'License', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final d = widget.existingData!;
      _nameController.text = d['complianceName'] ?? '';
      _selectedCategory = d['category'] ?? 'Policy';
      _regNumberController.text = d['registrationNumber'] ?? '';
      _authorityController.text = d['authority'] ?? '';
      _attachmentController.text = d['attachmentUrl'] ?? '';
      _descriptionController.text = d['description'] ?? '';
      _notesController.text = d['notes'] ?? '';

      if (d['issueDate'] != null && d['issueDate'] is Timestamp) {
        _issueDate = (d['issueDate'] as Timestamp).toDate();
      }
      if (d['expiryDate'] != null && d['expiryDate'] is Timestamp) {
        _expiryDate = (d['expiryDate'] as Timestamp).toDate();
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isIssue) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isIssue ? (_issueDate ?? DateTime.now()) : (_expiryDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: zBlue)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isIssue) {
          _issueDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final collection = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('compliance_legal');

      // Status is omitted intentionally as it is dynamically calculated by UI
      final payload = {
        'complianceName': _nameController.text.trim(),
        'category': _selectedCategory,
        'registrationNumber': _regNumberController.text.trim(),
        'authority': _authorityController.text.trim(),
        'issueDate': _issueDate != null ? Timestamp.fromDate(_issueDate!) : null,
        'expiryDate': _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
        'attachmentUrl': _attachmentController.text.trim(),
        'description': _descriptionController.text.trim(),
        'notes': _notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(payload);
      } else {
        await collection.doc(widget.docId).update(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.docId == null ? 'Record saved successfully' : 'Record updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving record: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: zText),
      ),
    );
  }

  InputDecoration _denseInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(fontSize: 13, color: zMuted),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: zBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: zBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: zBlue)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.docId != null;

    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Compliance Record' : 'Add Compliance Record', style: TextStyle(color: zText, fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: zText, size: 20),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: zBorder, height: 1),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            margin: const EdgeInsets.all(16), // Reduced spacing
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: zBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0), // Compact padding
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildSectionTitle('General Information'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 13),
                            decoration: _denseInputDecoration('Compliance Name *'),
                            validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            style: TextStyle(fontSize: 13, color: zText),
                            decoration: _denseInputDecoration('Category *'),
                            value: _selectedCategory,
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val!),
                          ),
                        ),
                      ],
                    ),

                    _buildSectionTitle('Registration Details'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _regNumberController,
                            style: const TextStyle(fontSize: 13),
                            decoration: _denseInputDecoration('Registration Number'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _authorityController,
                            style: const TextStyle(fontSize: 13),
                            decoration: _denseInputDecoration('Authority / Governing Body'),
                          ),
                        ),
                      ],
                    ),

                    _buildSectionTitle('Validity Dates'),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: _denseInputDecoration('Issue Date'),
                              child: Text(
                                _issueDate == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_issueDate!),
                                style: TextStyle(fontSize: 13, color: _issueDate == null ? zMuted : zText),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: _denseInputDecoration('Expiry Date *'),
                              child: Text(
                                _expiryDate == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_expiryDate!),
                                style: TextStyle(fontSize: 13, color: _expiryDate == null ? zMuted : zText),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    _buildSectionTitle('Document & Additional Notes'),
                    TextFormField(
                      controller: _attachmentController,
                      style: const TextStyle(fontSize: 13),
                      decoration: _denseInputDecoration('Attachment URL', hint: 'Link to internal document / drive'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      decoration: _denseInputDecoration('Description'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      decoration: _denseInputDecoration('Internal Notes'),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(fontSize: 13, color: zMuted, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: zBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: _isLoading ? null : _saveRecord,
                          child: _isLoading
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(isEdit ? 'Update Record' : 'Save Record', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}