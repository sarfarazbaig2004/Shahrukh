import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/purchase_rfq_item_model.dart';
import '../models/purchase_rfq_model.dart';
import '../models/purchase_rfq_vendor_model.dart';
import '../models/rfq_status.dart';
import '../services/rfq_service.dart';

class RfqFormScreen extends StatefulWidget {
  const RfqFormScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.rfq,
  });

  final String companyId;
  final String userUid;
  final PurchaseRfq? rfq;

  @override
  State<RfqFormScreen> createState() => _RfqFormScreenState();
}

class _RfqFormScreenState extends State<RfqFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = RfqService();
  final _fields = <String, TextEditingController>{};
  final _dateFormat = DateFormat('yyyy-MM-dd');

  RfqStatus _status = RfqStatus.draft;
  DateTime _rfqDate = DateTime.now();
  DateTime? _submissionDeadline;
  DateTime? _requiredDeliveryDate;
  final List<_PurchaseRfqItemEditor> _items = [];
  final List<_PurchaseRfqVendorEditor> _vendors = [];

  bool _saving = false;

  TextEditingController _controller(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    final rfq = widget.rfq;
    if (rfq != null) {
      _controller('rfqNumber').text = rfq.rfqNumber;
      _controller('title').text = rfq.title;
      _controller('description').text = rfq.description ?? '';
      _controller('purchaseRequisitionNumber').text =
          rfq.purchaseRequisitionNumber ?? '';
      _controller('departmentId').text = rfq.departmentId ?? '';
      _controller('projectId').text = rfq.projectId ?? '';
      _controller('costCenterId').text = rfq.costCenterId ?? '';
      _controller('assignedBuyerName').text = rfq.assignedBuyerName ?? '';
      _controller('currency').text = rfq.currency ?? '';
      _controller('deliveryLocation').text = rfq.deliveryLocation ?? '';
      _controller('deliveryAddress').text = rfq.deliveryAddress ?? '';
      _status = rfq.status;
      _rfqDate = rfq.rfqDate;
      _submissionDeadline = rfq.submissionDeadline;
      _requiredDeliveryDate = rfq.requiredDeliveryDate;
      _items.addAll(rfq.items.map(_PurchaseRfqItemEditor.fromItem));
      _vendors.addAll(rfq.vendors.map(_PurchaseRfqVendorEditor.fromVendor));
    } else {
      _controller('currency').text = 'INR';
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    for (final vendor in _vendors) {
      vendor.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item.'),
          backgroundColor: zDanger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final rfq = PurchaseRfq(
        id: widget.rfq?.id ?? '',
        companyId: widget.companyId,
        rfqNumber: _controller('rfqNumber').text.trim(),
        title: _controller('title').text.trim(),
        description: _nullable(_controller('description').text),
        rfqDate: _rfqDate,
        submissionDeadline: _submissionDeadline,
        requiredDeliveryDate: _requiredDeliveryDate,
        purchaseRequisitionNumber: _nullable(
          _controller('purchaseRequisitionNumber').text,
        ),
        departmentId: _nullable(_controller('departmentId').text),
        projectId: _nullable(_controller('projectId').text),
        costCenterId: _nullable(_controller('costCenterId').text),
        assignedBuyerName: _nullable(_controller('assignedBuyerName').text),
        currency: _nullable(_controller('currency').text),
        deliveryLocation: _nullable(_controller('deliveryLocation').text),
        deliveryAddress: _nullable(_controller('deliveryAddress').text),
        items: _items.map((e) => e.toItem()).toList(growable: false),
        vendors: _vendors.map((e) => e.toVendor()).toList(growable: false),
        status: _status,
        createdBy: widget.rfq?.createdBy ?? widget.userUid,
        createdAt: widget.rfq?.createdAt ?? now,
        updatedAt: now,
        isDeleted: false,
      );

      await _service.saveRfq(rfq: rfq, userUid: widget.userUid);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: zDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime? initial, {
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _dateField(
    String label,
    DateTime? value, {
    required ValueChanged<DateTime?> onChanged,
  }) {
    return SizedBox(
      width: 250,
      child: InkWell(
        onTap: () => _pickDate(context, value, onPicked: onChanged),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            value == null ? '-' : _dateFormat.format(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rfq == null ? 'Create RFQ' : 'Edit RFQ'),
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
              label: const Text('Save RFQ'),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('Basic details', Icons.request_quote_outlined, [
                    _field('rfqNumber', 'RFQ Number', required: true),
                    _field('title', 'Title', width: 520, required: true),
                    _field(
                      'description',
                      'Description',
                      width: 520,
                      maxLines: 3,
                    ),
                    _dateField(
                      'RFQ Date',
                      _rfqDate,
                      onChanged: (value) =>
                          setState(() => _rfqDate = value ?? DateTime.now()),
                    ),
                    _dateField(
                      'Submission Deadline',
                      _submissionDeadline,
                      onChanged: (value) =>
                          setState(() => _submissionDeadline = value),
                    ),
                    _dateField(
                      'Required Delivery Date',
                      _requiredDeliveryDate,
                      onChanged: (value) =>
                          setState(() => _requiredDeliveryDate = value),
                    ),
                    _dropdown(
                      'Status',
                      _status.displayLabel,
                      RfqStatus.values.map((s) => s.displayLabel).toList(),
                      (value) => setState(
                        () => _status = RfqStatusExtension.parse(value),
                      ),
                    ),
                  ]),
                  _section('References', Icons.link_outlined, [
                    _field(
                      'purchaseRequisitionNumber',
                      'Purchase Requisition Number',
                    ),
                    _field('departmentId', 'Department'),
                    _field('projectId', 'Project'),
                    _field('costCenterId', 'Cost Center'),
                    _field('assignedBuyerName', 'Assigned Buyer'),
                  ]),
                  _section('Delivery', Icons.local_shipping_outlined, [
                    _field('currency', 'Currency'),
                    _field('deliveryLocation', 'Delivery Location', width: 520),
                    _field(
                      'deliveryAddress',
                      'Delivery Address',
                      width: 520,
                      maxLines: 2,
                    ),
                  ]),
                  _itemsSection(),
                  _vendorsSection(),
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
        value: values.contains(value) ? value : values.first,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _itemsSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt_outlined, size: 20, color: zBlue),
                const SizedBox(width: 8),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _items.add(_PurchaseRfqItemEditor())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              Text(
                'No items added. Add at least one item.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _itemCard(index, item);
              }),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(int index, _PurchaseRfqItemEditor item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: () => setState(() => _items.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: zDanger),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _editorField(
                  item.nameController,
                  'Item Name *',
                  required: true,
                ),
                _editorField(item.codeController, 'Item Code'),
                _editorField(
                  item.quantityController,
                  'Quantity *',
                  required: true,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _editorField(item.unitController, 'Unit *', required: true),
                _editorField(
                  item.descriptionController,
                  'Description',
                  width: 360,
                  maxLines: 2,
                ),
                _editorField(
                  item.specificationController,
                  'Specification',
                  width: 360,
                  maxLines: 2,
                ),
                _editorField(item.brandController, 'Preferred Brand'),
                _editorField(item.makeModelController, 'Make / Model'),
                _editorField(
                  item.deliveryLocationController,
                  'Delivery Location',
                  width: 360,
                ),
                _editorField(
                  item.remarksController,
                  'Remarks',
                  width: 360,
                  maxLines: 2,
                ),
                _editorDateField(
                  'Required Delivery Date',
                  item.requiredDeliveryDate,
                  (value) => setState(() => item.requiredDeliveryDate = value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vendorsSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business_outlined, size: 20, color: zBlue),
                const SizedBox(width: 8),
                Text('Vendors', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _vendors.add(_PurchaseRfqVendorEditor())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Vendor'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_vendors.isEmpty)
              Text(
                'No vendors invited yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ..._vendors.asMap().entries.map((entry) {
                final index = entry.key;
                final vendor = entry.value;
                return _vendorCard(index, vendor);
              }),
          ],
        ),
      ),
    );
  }

  Widget _vendorCard(int index, _PurchaseRfqVendorEditor vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Vendor ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                StatefulBuilder(
                  builder: (context, setLocalState) => Row(
                    children: [
                      Checkbox(
                        value: vendor.isSelected,
                        onChanged: (value) => setLocalState(
                          () => setState(
                            () => vendor.isSelected = value ?? false,
                          ),
                        ),
                      ),
                      const Text('Selected'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove vendor',
                  onPressed: () => setState(() => _vendors.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: zDanger),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _editorField(
                  vendor.nameController,
                  'Vendor Name *',
                  required: true,
                ),
                _editorField(vendor.codeController, 'Vendor Code'),
                _editorField(vendor.contactController, 'Contact Person'),
                _editorField(
                  vendor.emailController,
                  'Email',
                  keyboard: TextInputType.emailAddress,
                ),
                _editorField(
                  vendor.phoneController,
                  'Phone',
                  keyboard: TextInputType.phone,
                ),
                _editorField(vendor.taxController, 'Tax Number'),
                _editorField(
                  vendor.addressController,
                  'Address',
                  width: 520,
                  maxLines: 2,
                ),
                _editorField(
                  vendor.noteController,
                  'Note',
                  width: 520,
                  maxLines: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorField(
    TextEditingController controller,
    String label, {
    double width = 250,
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _editorDateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return SizedBox(
      width: 250,
      child: InkWell(
        onTap: () => _pickDate(context, value, onPicked: onChanged),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            value == null ? '-' : _dateFormat.format(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _PurchaseRfqItemEditor {
  _PurchaseRfqItemEditor();

  factory _PurchaseRfqItemEditor.fromItem(PurchaseRfqItem item) {
    final editor = _PurchaseRfqItemEditor();
    editor.nameController.text = item.itemName;
    editor.codeController.text = item.itemCode ?? '';
    editor.quantityController.text = item.quantity.toString();
    editor.unitController.text = item.unit;
    editor.descriptionController.text = item.description ?? '';
    editor.specificationController.text = item.specification ?? '';
    editor.brandController.text = item.preferredBrand ?? '';
    editor.makeModelController.text = item.makeOrModel ?? '';
    editor.deliveryLocationController.text = item.deliveryLocation ?? '';
    editor.remarksController.text = item.remarks ?? '';
    editor.requiredDeliveryDate = item.requiredDeliveryDate;
    return editor;
  }

  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final quantityController = TextEditingController(text: '0');
  final unitController = TextEditingController(text: 'Nos.');
  final descriptionController = TextEditingController();
  final specificationController = TextEditingController();
  final brandController = TextEditingController();
  final makeModelController = TextEditingController();
  final deliveryLocationController = TextEditingController();
  final remarksController = TextEditingController();
  DateTime? requiredDeliveryDate;

  PurchaseRfqItem toItem() {
    return PurchaseRfqItem(
      itemName: nameController.text.trim(),
      itemCode: _nullable(codeController.text),
      quantity:
          double.tryParse(quantityController.text.replaceAll(',', '')) ?? 0,
      unit: unitController.text.trim().isEmpty
          ? 'Nos.'
          : unitController.text.trim(),
      description: _nullable(descriptionController.text),
      specification: _nullable(specificationController.text),
      preferredBrand: _nullable(brandController.text),
      makeOrModel: _nullable(makeModelController.text),
      deliveryLocation: _nullable(deliveryLocationController.text),
      remarks: _nullable(remarksController.text),
      requiredDeliveryDate: requiredDeliveryDate,
    );
  }

  void dispose() {
    nameController.dispose();
    codeController.dispose();
    quantityController.dispose();
    unitController.dispose();
    descriptionController.dispose();
    specificationController.dispose();
    brandController.dispose();
    makeModelController.dispose();
    deliveryLocationController.dispose();
    remarksController.dispose();
  }

  static String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _PurchaseRfqVendorEditor {
  _PurchaseRfqVendorEditor();

  factory _PurchaseRfqVendorEditor.fromVendor(PurchaseRfqVendor vendor) {
    final editor = _PurchaseRfqVendorEditor();
    editor.nameController.text = vendor.vendorName;
    editor.codeController.text = vendor.vendorCode ?? '';
    editor.contactController.text = vendor.contactPerson ?? '';
    editor.emailController.text = vendor.email ?? '';
    editor.phoneController.text = vendor.phone ?? '';
    editor.taxController.text = vendor.taxNumber ?? '';
    editor.addressController.text = vendor.address ?? '';
    editor.noteController.text = vendor.note ?? '';
    editor.isSelected = vendor.isSelected;
    return editor;
  }

  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final contactController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final taxController = TextEditingController();
  final addressController = TextEditingController();
  final noteController = TextEditingController();
  bool isSelected = false;

  PurchaseRfqVendor toVendor() {
    return PurchaseRfqVendor(
      vendorId: '',
      vendorName: nameController.text.trim(),
      vendorCode: _nullable(codeController.text),
      contactPerson: _nullable(contactController.text),
      email: _nullable(emailController.text),
      phone: _nullable(phoneController.text),
      taxNumber: _nullable(taxController.text),
      address: _nullable(addressController.text),
      note: _nullable(noteController.text),
      isSelected: isSelected,
    );
  }

  void dispose() {
    nameController.dispose();
    codeController.dispose();
    contactController.dispose();
    emailController.dispose();
    phoneController.dispose();
    taxController.dispose();
    addressController.dispose();
    noteController.dispose();
  }

  static String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
