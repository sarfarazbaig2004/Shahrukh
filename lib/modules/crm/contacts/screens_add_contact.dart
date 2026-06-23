import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScreensAddContact extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentSnapshot<Map<String, dynamic>>? contactDoc;

  const ScreensAddContact({
    super.key,
    required this.companyRef,
    this.contactDoc,
  });

  @override
  State<ScreensAddContact> createState() => _ScreensAddContactState();
}

class _ScreensAddContactState extends State<ScreensAddContact> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _designation = TextEditingController();
  final _department = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _remarks = TextEditingController();

  String _status = 'Active';
  String _category = 'General';
  bool _isPrimary = false;
  bool _saving = false;

  bool get _isEdit => widget.contactDoc != null;

  @override
  void initState() {
    super.initState();
    final data = widget.contactDoc?.data();
    if (data == null) return;
    _name.text = _read(data, ['name', 'contactName', 'personName']);
    _designation.text = _read(data, ['designation', 'position']);
    _department.text = _read(data, ['department']);
    _phone.text = _read(data, ['phone', 'mobile', 'contactNo', 'contactNumber']);
    _email.text = _read(data, ['email', 'mail']);
    _remarks.text = _read(data, ['remarks', 'notes']);
    _status = _read(data, ['status']).isEmpty ? 'Active' : _read(data, ['status']);
    _category = _read(data, ['category', 'type']).isEmpty ? 'General' : _read(data, ['category', 'type']);
    _isPrimary = _readBool(data['isPrimary'] ?? data['primary']);
  }

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    _department.dispose();
    _phone.dispose();
    _email.dispose();
    _remarks.dispose();
    super.dispose();
  }

  String _read(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().toLowerCase().trim();
    return text == 'true' || text == 'yes' || text == '1';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'designation': _designation.text.trim(),
      'department': _department.text.trim(),
      'phone': _phone.text.trim(),
      'mobile': _phone.text.trim(),
      'email': _email.text.trim(),
      'status': _status,
      'category': _category,
      'type': _category,
      'isPrimary': _isPrimary,
      'remarks': _remarks.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEdit) {
        await widget.contactDoc!.reference.set(payload, SetOptions(merge: true));
      } else {
        await widget.companyRef.collection('contacts').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save contact: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xff0f172a),
        title: Text(_isEdit ? 'Edit Contact' : 'Add Contact'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save Contact'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Card(
            margin: const EdgeInsets.all(24),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contact_page_outlined),
                        const SizedBox(width: 10),
                        Text(
                          _isEdit ? 'Update contact details' : 'Create customer contact',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      runSpacing: 16,
                      spacing: 16,
                      children: [
                        _field(_name, 'Contact Name *', Icons.person_outline, requiredField: true),
                        _field(_designation, 'Designation', Icons.badge_outlined),
                        _field(_department, 'Department', Icons.apartment_outlined),
                        _field(_phone, 'Phone / Mobile', Icons.phone_outlined),
                        _field(_email, 'Email', Icons.email_outlined, email: true),
                        _dropdown('Status', _status, ['Active', 'Inactive'], (v) => setState(() => _status = v!)),
                        _dropdown('Category', _category, ['General', 'Decision Maker', 'Purchase', 'Stores', 'Technical', 'Accounts'], (v) => setState(() => _category = v!)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isPrimary,
                      onChanged: (value) => setState(() => _isPrimary = value),
                      title: const Text('Primary Contact'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _remarks,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _decoration('Remarks', Icons.notes_outlined),
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

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool requiredField = false,
    bool email = false,
  }) {
    return SizedBox(
      width: 420,
      child: TextFormField(
        controller: controller,
        decoration: _decoration(label, icon),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (requiredField && text.isEmpty) return 'Required';
          if (email && text.isNotEmpty && !text.contains('@')) return 'Enter valid email';
          return null;
        },
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final currentValue = items.contains(value) ? value : items.first;
    return SizedBox(
      width: 420,
      child: DropdownButtonFormField<String>(
        value: currentValue,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: _decoration(label, Icons.arrow_drop_down_circle_outlined),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
