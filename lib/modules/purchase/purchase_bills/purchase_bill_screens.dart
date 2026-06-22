import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../vendors/models/vendor_model.dart';
import 'purchase_bill_model.dart';
import 'purchase_bill_service.dart';

class PurchaseBillListScreen extends StatefulWidget {
  const PurchaseBillListScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<PurchaseBillListScreen> createState() => _PurchaseBillListScreenState();
}

class _PurchaseBillListScreenState extends State<PurchaseBillListScreen> {
  final _service = PurchaseBillService();
  final _searchController = TextEditingController();
  String _paymentStatus = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<PurchaseBillModel>>(
        stream: _service.watchBills(widget.companyId),
        builder: (context, snapshot) {
          final bills = snapshot.data ?? const <PurchaseBillModel>[];
          final filtered = _filterBills(bills);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Bills',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${filtered.length} bill${filtered.length == 1 ? '' : 's'} in this view',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openEntry(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Purchase Bill'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 330,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText:
                                'Search bill, vendor, sales order, GRN...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: _paymentStatus,
                          decoration: const InputDecoration(
                            labelText: 'Payment Status',
                          ),
                          items: ['All', ...purchaseBillPaymentStatuses]
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _paymentStatus = value ?? 'All'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? _PurchaseBillEmptyState(noData: bills.isEmpty)
                    : LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 760
                            ? _mobileList(filtered)
                            : _desktopTable(filtered),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<PurchaseBillModel> _filterBills(List<PurchaseBillModel> bills) {
    final query = _searchController.text.trim().toLowerCase();
    return bills.where((bill) {
      final searchText = [
        bill.purchaseBillNo,
        bill.vendorName,
        bill.salesOrderRef,
        bill.grnRef,
        bill.supplierInvoiceNo,
      ].join(' ').toLowerCase();
      return (query.isEmpty || searchText.contains(query)) &&
          (_paymentStatus == 'All' || bill.paymentStatus == _paymentStatus);
    }).toList();
  }

  Widget _desktopTable(List<PurchaseBillModel> bills) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(zSurfaceSoft),
            columns: const [
              DataColumn(label: Text('Bill No')),
              DataColumn(label: Text('Bill Date')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Sales Order Ref')),
              DataColumn(label: Text('GRN Ref')),
              DataColumn(label: Text('Taxable Amount'), numeric: true),
              DataColumn(label: Text('Tax Amount'), numeric: true),
              DataColumn(label: Text('Total Amount'), numeric: true),
              DataColumn(label: Text('Payment Status')),
              DataColumn(label: Text('PDF / Attachment')),
              DataColumn(label: Text('Created Date')),
              DataColumn(label: Text('Actions')),
            ],
            rows: bills.map(_billRow).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _billRow(PurchaseBillModel bill) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            _dash(bill.purchaseBillNo),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(Text(_date(bill.purchaseBillDate))),
        DataCell(Text(_dash(bill.vendorName))),
        DataCell(Text(_dash(bill.salesOrderRef))),
        DataCell(Text(_dash(bill.grnRef))),
        DataCell(Text(_money(bill.taxableAmount))),
        DataCell(Text(_money(bill.gstAmount))),
        DataCell(
          Text(
            _money(bill.totalAmount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(_PaymentStatusChip(status: bill.paymentStatus)),
        DataCell(_attachmentButton(bill)),
        DataCell(Text(bill.createdAt == null ? '-' : _date(bill.createdAt!))),
        DataCell(_actions(bill)),
      ],
    );
  }

  Widget _mobileList(List<PurchaseBillModel> bills) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: bills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final bill = bills[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dash(bill.purchaseBillNo),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _PaymentStatusChip(status: bill.paymentStatus),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${_dash(bill.vendorName)} • ${_date(bill.purchaseBillDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 22),
                _mobileValue('Sales Order Ref', _dash(bill.salesOrderRef)),
                _mobileValue('GRN Ref', _dash(bill.grnRef)),
                _mobileValue('Tax', _money(bill.gstAmount)),
                _mobileValue('Total', _money(bill.totalAmount), bold: true),
                Row(
                  children: [
                    _attachmentButton(bill),
                    const Spacer(),
                    _actions(bill),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileValue(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentButton(PurchaseBillModel bill) {
    if (!bill.hasAttachment) {
      return const Tooltip(
        message: 'No PDF uploaded',
        child: Icon(Icons.attach_file, color: zMuted, size: 19),
      );
    }
    return TextButton.icon(
      onPressed: () => _openAttachment(bill.pdfUrl),
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: const Text('View PDF'),
    );
  }

  Widget _actions(PurchaseBillModel bill) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Preview',
          onPressed: () => _showPreview(bill),
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          tooltip: 'Edit',
          onPressed: () => _openEntry(bill),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: () => _deleteBill(bill),
          icon: const Icon(Icons.delete_outline, color: zDanger),
        ),
      ],
    );
  }

  Future<void> _openEntry([PurchaseBillModel? bill]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseBillEntryScreen(
          companyId: widget.companyId,
          userUid: widget.userUid,
          bill: bill,
        ),
      ),
    );
  }

  void _showPreview(PurchaseBillModel bill) {
    showDialog<void>(
      context: context,
      builder: (context) => _PurchaseBillPreviewDialog(
        bill: bill,
        companyLoader: () => _service.loadCompany(widget.companyId),
        onOpenAttachment: bill.hasAttachment
            ? () => _openAttachment(bill.pdfUrl)
            : null,
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the uploaded PDF.')),
      );
    }
  }

  Future<void> _deleteBill(PurchaseBillModel bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete purchase bill?'),
        content: Text(
          'This will permanently delete ${bill.purchaseBillNo} and its stored PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: zDanger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteBill(bill);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Purchase bill deleted.')));
  }
}

class PurchaseBillEntryScreen extends StatefulWidget {
  const PurchaseBillEntryScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.bill,
  });

  final String companyId;
  final String userUid;
  final PurchaseBillModel? bill;

  @override
  State<PurchaseBillEntryScreen> createState() =>
      _PurchaseBillEntryScreenState();
}

class _PurchaseBillEntryScreenState extends State<PurchaseBillEntryScreen> {
  final _service = PurchaseBillService();
  final _formKey = GlobalKey<FormState>();
  final _billNo = TextEditingController();
  final _salesOrderRef = TextEditingController();
  final _grnRef = TextEditingController();
  final _supplierInvoiceNo = TextEditingController();
  final _taxable = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _freight = TextEditingController(text: '0');
  final _otherCharges = TextEditingController(text: '0');
  final _gst = TextEditingController(text: '0');
  final _tds = TextEditingController(text: '0');
  final _remarks = TextEditingController();
  DateTime _billDate = DateTime.now();
  DateTime? _supplierInvoiceDate;
  String? _vendorId;
  String _vendorName = '';
  String _paymentStatus = 'Unpaid';
  Uint8List? _selectedPdfBytes;
  String? _selectedPdfName;
  bool _saving = false;

  List<TextEditingController> get _amountControllers => [
    _taxable,
    _discount,
    _freight,
    _otherCharges,
    _gst,
    _tds,
  ];

  double get _totalAmount =>
      (_value(_taxable) -
              _value(_discount) +
              _value(_freight) +
              _value(_otherCharges) +
              _value(_gst) -
              _value(_tds))
          .clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    for (final controller in _amountControllers) {
      controller.addListener(_rebuildTotals);
    }
    _seed();
  }

  Future<void> _seed() async {
    final bill = widget.bill;
    if (bill == null) {
      try {
        _billNo.text = await _service.nextBillNumber(widget.companyId);
        if (mounted) setState(() {});
      } catch (error) {
        if (mounted) _message('Unable to generate bill number: $error');
      }
      return;
    }
    _billNo.text = bill.purchaseBillNo;
    _billDate = bill.purchaseBillDate;
    _vendorId = bill.vendorId;
    _vendorName = bill.vendorName;
    _salesOrderRef.text = bill.salesOrderRef;
    _grnRef.text = bill.grnRef;
    _supplierInvoiceNo.text = bill.supplierInvoiceNo;
    _supplierInvoiceDate = bill.supplierInvoiceDate;
    _taxable.text = bill.taxableAmount.toStringAsFixed(2);
    _discount.text = bill.discountAmount.toStringAsFixed(2);
    _freight.text = bill.freightAmount.toStringAsFixed(2);
    _otherCharges.text = bill.otherCharges.toStringAsFixed(2);
    _gst.text = bill.gstAmount.toStringAsFixed(2);
    _tds.text = bill.tdsAmount.toStringAsFixed(2);
    _paymentStatus = purchaseBillPaymentStatuses.contains(bill.paymentStatus)
        ? bill.paymentStatus
        : 'Unpaid';
    _remarks.text = bill.remarks;
  }

  @override
  void dispose() {
    for (final controller in [
      _billNo,
      _salesOrderRef,
      _grnRef,
      _supplierInvoiceNo,
      ..._amountControllers,
      _remarks,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bill == null ? 'Add Purchase Bill' : 'Edit Purchase Bill',
        ),
        actions: [
          TextButton.icon(
            onPressed: _showCurrentPreview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview'),
          ),
          const SizedBox(width: 8),
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
              label: const Text('Save Bill'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<VendorModel>>(
        stream: _service.watchActiveVendors(widget.companyId),
        builder: (context, snapshot) {
          final vendors = snapshot.data ?? const <VendorModel>[];
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    children: [
                      _section('Bill header', Icons.receipt_long_outlined, [
                        _textField(_billNo, 'Purchase Bill No', required: true),
                        _dateField(
                          'Purchase Bill Date',
                          _billDate,
                          (date) => setState(() => _billDate = date),
                        ),
                        _vendorField(vendors),
                        _readOnlyField('Vendor Name', _vendorName),
                        _textField(
                          _salesOrderRef,
                          'Sales Order Entry / Reference',
                          required: true,
                        ),
                        _textField(_grnRef, 'GRN Reference'),
                        _textField(
                          _supplierInvoiceNo,
                          'Supplier Invoice No',
                          required: true,
                        ),
                        _dateField(
                          'Supplier Invoice Date',
                          _supplierInvoiceDate,
                          (date) => setState(() => _supplierInvoiceDate = date),
                        ),
                      ]),
                      _section('Amount and tax', Icons.calculate_outlined, [
                        _amountField(
                          _taxable,
                          'Taxable Amount',
                          required: true,
                        ),
                        _amountField(_discount, 'Discount Amount'),
                        _amountField(_freight, 'Freight Amount'),
                        _amountField(_otherCharges, 'Other Charges'),
                        _amountField(_gst, 'GST Amount'),
                        _amountField(_tds, 'TDS Amount (Optional)'),
                        _readOnlyField(
                          'Total Amount',
                          _money(_totalAmount),
                          emphasize: true,
                        ),
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<String>(
                            initialValue: _paymentStatus,
                            decoration: const InputDecoration(
                              labelText: 'Payment Status',
                            ),
                            items: purchaseBillPaymentStatuses
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(
                              () => _paymentStatus = value ?? 'Unpaid',
                            ),
                          ),
                        ),
                      ]),
                      _attachmentSection(),
                      _section('Internal notes', Icons.notes_outlined, [
                        SizedBox(
                          width: 1060,
                          child: TextFormField(
                            controller: _remarks,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Remarks',
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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

  Widget _vendorField(List<VendorModel> vendors) {
    final values = vendors.map((vendor) => vendor.id).toSet();
    final items = <DropdownMenuItem<String>>[
      if (_vendorId != null && !values.contains(_vendorId))
        DropdownMenuItem(value: _vendorId, child: Text(_vendorName)),
      ...vendors.map(
        (vendor) => DropdownMenuItem(
          value: vendor.id,
          child: Text(
            '${vendor.vendorName}${vendor.vendorCode.isEmpty ? '' : ' • ${vendor.vendorCode}'}',
          ),
        ),
      ),
    ];
    return SizedBox(
      width: 250,
      child: DropdownButtonFormField<String>(
        initialValue: _vendorId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Vendor'),
        items: items,
        validator: (value) =>
            value == null || value.isEmpty ? 'Required' : null,
        onChanged: (value) {
          final selected = vendors
              .where((vendor) => vendor.id == value)
              .firstOrNull;
          setState(() {
            _vendorId = value;
            if (selected != null) _vendorName = selected.vendorName;
          });
        },
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return SizedBox(
      width: 250,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _amountField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return SizedBox(
      width: 250,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '₹ '),
        validator: (value) {
          final parsed = double.tryParse(value?.trim() ?? '');
          if (required && (parsed == null || parsed <= 0)) {
            return 'Enter an amount greater than zero';
          }
          if (parsed != null && parsed < 0) return 'Cannot be negative';
          return null;
        },
      ),
    );
  }

  Widget _readOnlyField(String label, String value, {bool emphasize = false}) {
    return SizedBox(
      width: 250,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, filled: true),
        child: Text(
          value.trim().isEmpty ? '-' : value,
          style: TextStyle(
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
            fontSize: emphasize ? 17 : 14,
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime? date,
    ValueChanged<DateTime> onChanged,
  ) {
    return SizedBox(
      width: 250,
      child: InkWell(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Text(date == null ? 'Select date' : _date(date)),
        ),
      ),
    );
  }

  Widget _attachmentSection() {
    final existing = widget.bill;
    final hasExisting = existing?.hasAttachment == true;
    final statusText =
        _selectedPdfName ??
        (hasExisting ? existing!.pdfFileName : 'No PDF uploaded');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 20,
                  color: zBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Purchase Bill PDF',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: zSurfaceSoft,
                borderRadius: BorderRadius.circular(kAppRadiusMd),
                border: Border.all(color: zBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedPdfName != null || hasExisting
                        ? Icons.check_circle
                        : Icons.upload_file_outlined,
                    color: _selectedPdfName != null || hasExisting
                        ? zSuccess
                        : zMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _selectedPdfName != null
                              ? 'Ready to upload when the bill is saved'
                              : hasExisting
                              ? 'Uploaded attachment'
                              : 'PDF files only',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (hasExisting)
                    TextButton(
                      onPressed: () => _openAttachment(existing!.pdfUrl),
                      child: const Text('View Current'),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(hasExisting ? 'Replace PDF' : 'Upload PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      _message('Unable to read the selected PDF.');
      return;
    }
    setState(() {
      _selectedPdfBytes = file.bytes;
      _selectedPdfName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendorId == null || _vendorName.trim().isEmpty) {
      _message('Select a vendor.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveBill(
        bill: _currentBill(),
        userUid: widget.userUid,
        pdfBytes: _selectedPdfBytes,
        selectedPdfName: _selectedPdfName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.bill == null
                ? 'Purchase bill created successfully.'
                : 'Purchase bill updated successfully.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  PurchaseBillModel _currentBill() {
    final existing = widget.bill;
    return PurchaseBillModel(
      id: existing?.id ?? '',
      companyId: widget.companyId,
      purchaseBillNo: _billNo.text,
      purchaseBillDate: _billDate,
      vendorId: _vendorId ?? '',
      vendorName: _vendorName,
      salesOrderRef: _salesOrderRef.text,
      grnRef: _grnRef.text,
      supplierInvoiceNo: _supplierInvoiceNo.text,
      supplierInvoiceDate: _supplierInvoiceDate,
      taxableAmount: _value(_taxable),
      discountAmount: _value(_discount),
      freightAmount: _value(_freight),
      otherCharges: _value(_otherCharges),
      gstAmount: _value(_gst),
      tdsAmount: _value(_tds),
      totalAmount: _totalAmount,
      paymentStatus: _paymentStatus,
      remarks: _remarks.text,
      pdfUrl: existing?.pdfUrl ?? '',
      pdfPath: existing?.pdfPath ?? '',
      pdfFileName: existing?.pdfFileName ?? '',
      pdfUploadedAt: existing?.pdfUploadedAt,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
      createdBy: existing?.createdBy ?? '',
      updatedBy: existing?.updatedBy ?? '',
    );
  }

  void _showCurrentPreview() {
    showDialog<void>(
      context: context,
      builder: (context) => _PurchaseBillPreviewDialog(
        bill: _currentBill(),
        companyLoader: () => _service.loadCompany(widget.companyId),
        onOpenAttachment: widget.bill?.hasAttachment == true
            ? () => _openAttachment(widget.bill!.pdfUrl)
            : null,
        pendingAttachmentName: _selectedPdfName,
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri)) {
      _message('Unable to open the uploaded PDF.');
    }
  }

  void _rebuildTotals() {
    if (mounted) setState(() {});
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PurchaseBillPreviewDialog extends StatelessWidget {
  const _PurchaseBillPreviewDialog({
    required this.bill,
    required this.companyLoader,
    this.onOpenAttachment,
    this.pendingAttachmentName,
  });

  final PurchaseBillModel bill;
  final Future<Map<String, dynamic>> Function() companyLoader;
  final VoidCallback? onOpenAttachment;
  final String? pendingAttachmentName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: companyLoader(),
          builder: (context, snapshot) {
            final company = snapshot.data ?? const <String, dynamic>{};
            final companyName = _first(company, [
              'companyName',
              'entityName',
              'name',
            ], fallback: 'MEMCO ERP');
            final companyAddress = [
              _first(company, ['addressLine1', 'address']),
              _first(company, ['city']),
              _first(company, ['state']),
              _first(company, ['pincode']),
            ].where((part) => part.isNotEmpty).join(', ');
            final gstin = _first(company, ['gstin', 'gst', 'gstNo']);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: zBlue),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Purchase Bill Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: zBorder),
                        borderRadius: BorderRadius.circular(kAppRadiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: zBlueSoft,
                                  borderRadius: BorderRadius.circular(
                                    kAppRadiusSm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.apartment,
                                  color: zBlue,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      companyName,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (companyAddress.isNotEmpty)
                                      Text(companyAddress),
                                    if (gstin.isNotEmpty) Text('GSTIN: $gstin'),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'PURCHASE BILL',
                                    style: TextStyle(
                                      color: zBlue,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    _dash(bill.purchaseBillNo),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 34),
                          Wrap(
                            spacing: 30,
                            runSpacing: 18,
                            children: [
                              _previewBlock('Vendor details', [
                                ('Vendor', _dash(bill.vendorName)),
                                (
                                  'Supplier Invoice',
                                  _dash(bill.supplierInvoiceNo),
                                ),
                                (
                                  'Supplier Invoice Date',
                                  bill.supplierInvoiceDate == null
                                      ? '-'
                                      : _date(bill.supplierInvoiceDate!),
                                ),
                              ]),
                              _previewBlock('Document details', [
                                ('Bill Date', _date(bill.purchaseBillDate)),
                                ('Sales Order Ref', _dash(bill.salesOrderRef)),
                                ('GRN Ref', _dash(bill.grnRef)),
                                ('Payment Status', bill.paymentStatus),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: zSurfaceSoft,
                              borderRadius: BorderRadius.circular(kAppRadiusSm),
                            ),
                            child: Column(
                              children: [
                                _amountRow(
                                  'Taxable Amount',
                                  bill.taxableAmount,
                                ),
                                _amountRow('Discount', -bill.discountAmount),
                                _amountRow('Freight', bill.freightAmount),
                                _amountRow('Other Charges', bill.otherCharges),
                                _amountRow('GST Amount', bill.gstAmount),
                                _amountRow('TDS', -bill.tdsAmount),
                                const Divider(height: 22),
                                _amountRow(
                                  'Total Amount',
                                  bill.totalAmount,
                                  bold: true,
                                ),
                              ],
                            ),
                          ),
                          if (bill.remarks.trim().isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Remarks',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 5),
                            Text(bill.remarks),
                          ],
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: zBorder),
                              borderRadius: BorderRadius.circular(kAppRadiusSm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, color: zMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pendingAttachmentName ??
                                        (bill.hasAttachment
                                            ? bill.pdfFileName
                                            : 'No purchase bill PDF attached'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (onOpenAttachment != null)
                                  TextButton(
                                    onPressed: onOpenAttachment,
                                    child: const Text('Open PDF'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _previewBlock(String title, List<(String, String)> rows) {
    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: zMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 125,
                    child: Text(row.$1, style: const TextStyle(color: zMuted)),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Paid' => zSuccess,
      'Partially Paid' => zWarning,
      _ => zDanger,
    };
    final background = switch (status) {
      'Paid' => zSuccessSoft,
      'Partially Paid' => zWarningSoft,
      _ => zDangerSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PurchaseBillEmptyState extends StatelessWidget {
  const _PurchaseBillEmptyState({required this.noData});

  final bool noData;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 50, color: zMuted),
          const SizedBox(height: 12),
          Text(
            noData ? 'No purchase bills yet' : 'No matching purchase bills',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            noData
                ? 'Add a purchase bill to begin vendor invoice tracking.'
                : 'Try changing the search or payment filter.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

double _value(TextEditingController controller) {
  return double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;
}

String _money(double value) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}

String _date(DateTime date) => DateFormat('dd MMM yyyy').format(date);

String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

String _first(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}
