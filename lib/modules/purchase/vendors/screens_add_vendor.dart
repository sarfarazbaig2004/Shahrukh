import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'models/vendor_model.dart';
import 'services/vendor_service.dart';

class AddVendorScreen extends StatefulWidget {
  const AddVendorScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.vendor,
  });

  final String companyId;
  final String userUid;
  final VendorModel? vendor;

  @override
  State<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends State<AddVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = VendorService();
  final Map<String, TextEditingController> _fields = {};
  String _category = purchaseVendorCategories.first;
  String _msmeStatus = 'Not Registered';
  bool _isActive = true;
  bool _saving = false;

  TextEditingController _controller(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    if (vendor == null) return;
    final values = <String, String>{
      'vendorName': vendor.vendorName,
      'vendorCode': vendor.vendorCode,
      'contactPerson': vendor.contactPerson,
      'mobile': vendor.mobile,
      'alternateMobile': vendor.alternateMobile,
      'email': vendor.email,
      'website': vendor.website,
      'addressLine1': vendor.addressLine1,
      'addressLine2': vendor.addressLine2,
      'city': vendor.city,
      'state': vendor.state,
      'pincode': vendor.pincode,
      'country': vendor.country,
      'gstNo': vendor.gstNo,
      'panNo': vendor.panNo,
      'msmeNo': vendor.msmeNo,
      'itemsSupplied': vendor.itemsSupplied,
      'creditDays': vendor.creditDays.toString(),
      'openingBalance': vendor.openingBalance.toStringAsFixed(2),
      'bankAccountName': vendor.bankAccountName,
      'bankName': vendor.bankName,
      'accountNumber': vendor.accountNumber,
      'ifscCode': vendor.ifscCode,
      'branchName': vendor.branchName,
      'remarks': vendor.remarks,
    };
    for (final entry in values.entries) {
      _controller(entry.key).text = entry.value;
    }
    _category = purchaseVendorCategories.contains(vendor.vendorCategory)
        ? vendor.vendorCategory
        : 'Other';
    _msmeStatus = vendor.msmeStatus;
    _isActive = vendor.isActive;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendor == null ? 'Add Vendor' : 'Edit Vendor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Vendor'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                children: [
                  _section('Basic details', Icons.business_outlined, [
                    _field('vendorName', 'Vendor Name', required: true),
                    _field(
                      'vendorCode',
                      'Vendor Code',
                      hint: 'Auto-generated if blank',
                    ),
                    _field('contactPerson', 'Contact Person'),
                    _field(
                      'mobile',
                      'Mobile',
                      required: true,
                      keyboard: TextInputType.phone,
                    ),
                    _field(
                      'alternateMobile',
                      'Alternate Mobile',
                      keyboard: TextInputType.phone,
                    ),
                    _field(
                      'email',
                      'Email',
                      keyboard: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),
                    _field('website', 'Website'),
                  ]),
                  _section('Address', Icons.location_on_outlined, [
                    _field('addressLine1', 'Address Line 1', width: 520),
                    _field('addressLine2', 'Address Line 2', width: 520),
                    _field('city', 'City'),
                    _field('state', 'State'),
                    _field(
                      'pincode',
                      'Pincode',
                      keyboard: TextInputType.number,
                    ),
                    _field('country', 'Country', hint: 'India'),
                  ]),
                  _section('Tax and business', Icons.receipt_long_outlined, [
                    _field('gstNo', 'GST No'),
                    _field('panNo', 'PAN No'),
                    _dropdown(
                      'MSME Status',
                      _msmeStatus,
                      const ['Not Registered', 'Registered'],
                      (value) => setState(
                        () => _msmeStatus = value ?? 'Not Registered',
                      ),
                    ),
                    _field('msmeNo', 'MSME No'),
                    _dropdown(
                      'Vendor Category',
                      _category,
                      purchaseVendorCategories,
                      (value) => setState(() => _category = value ?? 'Other'),
                    ),
                    _field('itemsSupplied', 'Items Supplied', width: 520),
                    _field(
                      'creditDays',
                      'Credit Days',
                      keyboard: TextInputType.number,
                    ),
                    _field(
                      'openingBalance',
                      'Opening Balance',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        title: const Text('Active vendor'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ),
                  ]),
                  _section('Bank details', Icons.account_balance_outlined, [
                    _field('bankAccountName', 'Account Name'),
                    _field('bankName', 'Bank Name'),
                    _field('accountNumber', 'Account Number'),
                    _field('ifscCode', 'IFSC Code'),
                    _field('branchName', 'Branch Name'),
                  ]),
                  _section('Internal notes', Icons.notes_outlined, [
                    _field('remarks', 'Remarks', width: 1060, maxLines: 4),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: zBlue),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 14, runSpacing: 14, children: children),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    double width = 250,
    bool required = false,
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: _controller(key),
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator:
            validator ??
            (required
                ? (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null
                : null),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 250,
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : values.first,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Enter a valid email';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final vendor = VendorModel(
        id: widget.vendor?.id ?? '',
        companyId: widget.companyId,
        vendorName: _controller('vendorName').text,
        vendorCode: _controller('vendorCode').text,
        contactPerson: _controller('contactPerson').text,
        mobile: _controller('mobile').text,
        alternateMobile: _controller('alternateMobile').text,
        email: _controller('email').text,
        website: _controller('website').text,
        addressLine1: _controller('addressLine1').text,
        addressLine2: _controller('addressLine2').text,
        city: _controller('city').text,
        state: _controller('state').text,
        pincode: _controller('pincode').text,
        country: _controller('country').text.trim().isEmpty
            ? 'India'
            : _controller('country').text,
        gstNo: _controller('gstNo').text,
        panNo: _controller('panNo').text,
        msmeStatus: _msmeStatus,
        msmeNo: _controller('msmeNo').text,
        vendorCategory: _category,
        itemsSupplied: _controller('itemsSupplied').text,
        creditDays: int.tryParse(_controller('creditDays').text) ?? 0,
        openingBalance:
            double.tryParse(_controller('openingBalance').text) ?? 0,
        isActive: _isActive,
        bankAccountName: _controller('bankAccountName').text,
        bankName: _controller('bankName').text,
        accountNumber: _controller('accountNumber').text,
        ifscCode: _controller('ifscCode').text,
        branchName: _controller('branchName').text,
        remarks: _controller('remarks').text,
      );
      await _service.saveVendor(vendor: vendor, userUid: widget.userUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.vendor == null
                ? 'Vendor created successfully.'
                : 'Vendor updated successfully.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: zDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
