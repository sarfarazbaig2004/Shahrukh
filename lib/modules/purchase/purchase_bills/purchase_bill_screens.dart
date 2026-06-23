import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../inventory/inventory_service.dart';
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
  String _billStatus = 'All';

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
                                'Search bill, vendor, supplier invoice...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      _filterDropdown(
                        label: 'Payment Status',
                        value: _paymentStatus,
                        values: ['All', ...purchaseBillPaymentStatuses],
                        onChanged: (value) =>
                            setState(() => _paymentStatus = value ?? 'All'),
                      ),
                      _filterDropdown(
                        label: 'Bill Status',
                        value: _billStatus,
                        values: const ['All', 'Draft', 'Posted'],
                        onChanged: (value) =>
                            setState(() => _billStatus = value ?? 'All'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                    ? Center(
                        child: Text('Unable to load bills: ${snapshot.error}'),
                      )
                    : filtered.isEmpty
                    ? _PurchaseBillEmptyState(noData: bills.isEmpty)
                    : LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 820
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

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
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
        ...bill.products.map((product) => product.productName),
      ].join(' ').toLowerCase();
      return (query.isEmpty || searchText.contains(query)) &&
          (_paymentStatus == 'All' || bill.paymentStatus == _paymentStatus) &&
          (_billStatus == 'All' || bill.status == _billStatus);
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
              DataColumn(label: Text('Vendor Name')),
              DataColumn(label: Text('Total Amount'), numeric: true),
              DataColumn(label: Text('Payment Status')),
              DataColumn(label: Text('Bill Status')),
              DataColumn(label: Text('Attachment')),
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
        DataCell(
          Text(
            _money(bill.grandTotal),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(_PaymentStatusChip(status: bill.paymentStatus)),
        DataCell(_BillStatusChip(posted: bill.isPosted)),
        DataCell(_attachmentIcon(bill)),
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
          child: InkWell(
            borderRadius: BorderRadius.circular(kAppRadiusMd),
            onTap: () => _openDetails(bill),
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
                      _BillStatusChip(posted: bill.isPosted),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_dash(bill.vendorName)} • ${_date(bill.purchaseBillDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 22),
                  _mobileValue('Total Amount', _money(bill.grandTotal)),
                  _mobileValue('Payment', bill.paymentStatus),
                  _mobileValue(
                    'Products',
                    bill.products.isEmpty
                        ? 'Legacy bill'
                        : '${bill.products.length}',
                  ),
                  Row(
                    children: [
                      _attachmentIcon(bill),
                      const Spacer(),
                      _actions(bill),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _attachmentIcon(PurchaseBillModel bill) {
    return Tooltip(
      message: bill.hasAttachment
          ? '${bill.attachments.length} attachment(s)'
          : 'No attachments',
      child: Icon(
        bill.hasAttachment ? Icons.attach_file : Icons.attach_file_outlined,
        color: bill.hasAttachment ? zBlue : zMuted,
        size: 20,
      ),
    );
  }

  Widget _actions(PurchaseBillModel bill) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View details',
          onPressed: () => _openDetails(bill),
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          tooltip: bill.isPosted
              ? 'Posted bills cannot be edited'
              : 'Edit purchase bill',
          onPressed: bill.isPosted ? null : () => _openEntry(bill),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: bill.isPosted
              ? 'Posted bills cannot be deleted'
              : 'Delete purchase bill',
          onPressed: bill.isPosted ? null : () => _deleteBill(bill),
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

  Future<void> _openDetails(PurchaseBillModel bill) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseBillDetailsScreen(
          companyId: widget.companyId,
          userUid: widget.userUid,
          bill: bill,
        ),
      ),
    );
  }

  Future<void> _deleteBill(PurchaseBillModel bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete purchase bill?'),
        content: Text(
          'This permanently deletes ${bill.purchaseBillNo} and its attachments.',
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
    try {
      await _service.deleteBill(bill);
      if (!mounted) return;
      _message('Purchase bill deleted.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error), error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? zDanger : null),
    );
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
  final _customPaymentTerms = TextEditingController();
  final _freight = TextEditingController(text: '0');
  final _otherCharges = TextEditingController(text: '0');
  final _tds = TextEditingController(text: '0');
  final _remarks = TextEditingController();
  final _lines = <_PurchaseBillLineEditor>[];
  final _pendingAttachments = <PendingPurchaseBillAttachment>[];

  late Future<_PurchaseBillFormData> _formDataFuture;
  DateTime _billDate = DateTime.now();
  DateTime? _supplierInvoiceDate;
  String? _vendorId;
  String _vendorName = '';
  String _paymentTerms = '30 Days';
  String _paymentStatus = 'Unpaid';
  String? _warehouseId;
  String _warehouseName = '';
  bool _saving = false;
  bool _numberLoading = false;

  List<TextEditingController> get _totalControllers => [
    _freight,
    _otherCharges,
    _tds,
  ];

  PurchaseBillTotals get _totals => PurchaseBillTotals.fromLines(
    _lines.map((line) => line.toModel()),
    freightAmount: _value(_freight),
    otherCharges: _value(_otherCharges),
    tdsAmount: _value(_tds),
  );

  @override
  void initState() {
    super.initState();
    for (final controller in _totalControllers) {
      controller.addListener(_rebuild);
    }
    _seed();
    _formDataFuture = _loadFormData();
  }

  void _seed() {
    final bill = widget.bill;
    if (bill == null) {
      _addLine(notify: false);
      _refreshBillNumber();
      return;
    }
    _billNo.text = bill.purchaseBillNo;
    _billDate = bill.purchaseBillDate;
    _vendorId = bill.vendorId;
    _vendorName = bill.vendorName;
    _paymentTerms = vendorPaymentTermsOptions.contains(bill.paymentTerms)
        ? bill.paymentTerms
        : bill.paymentTerms.trim().isEmpty
        ? '30 Days'
        : 'Custom';
    _customPaymentTerms.text = bill.customPaymentTerms;
    if (_paymentTerms == 'Custom' &&
        _customPaymentTerms.text.trim().isEmpty &&
        bill.paymentTerms.isNotEmpty &&
        !vendorPaymentTermsOptions.contains(bill.paymentTerms)) {
      _customPaymentTerms.text = bill.paymentTerms;
    }
    _paymentStatus = purchaseBillPaymentStatuses.contains(bill.paymentStatus)
        ? bill.paymentStatus
        : 'Unpaid';
    _warehouseId = bill.warehouseId.isEmpty ? null : bill.warehouseId;
    _warehouseName = bill.warehouseName;
    _salesOrderRef.text = bill.salesOrderRef;
    _grnRef.text = bill.grnRef;
    _supplierInvoiceNo.text = bill.supplierInvoiceNo;
    _supplierInvoiceDate = bill.supplierInvoiceDate;
    _freight.text = bill.freightAmount.toStringAsFixed(2);
    _otherCharges.text = bill.otherCharges.toStringAsFixed(2);
    _tds.text = bill.tdsAmount.toStringAsFixed(2);
    _remarks.text = bill.remarks;
    if (bill.products.isEmpty) {
      _addLine(notify: false);
    } else {
      for (final product in bill.products) {
        _lines.add(_PurchaseBillLineEditor(seed: product, onChanged: _rebuild));
      }
    }
  }

  Future<_PurchaseBillFormData> _loadFormData() async {
    final results = await Future.wait<Object>([
      _service.loadVendors(widget.companyId),
      _service.loadPurchaseProducts(widget.companyId),
      _service.loadWarehouses(widget.companyId),
    ]);
    final data = _PurchaseBillFormData(
      vendors: results[0] as List<VendorModel>,
      products: results[1] as List<PurchaseProductMasterItem>,
      warehouses: results[2] as List<WarehouseRecord>,
    );
    if (_warehouseId == null && data.warehouses.isNotEmpty) {
      _warehouseId = data.warehouses.first.id;
      _warehouseName = data.warehouses.first.name;
    }
    return data;
  }

  Future<void> _refreshBillNumber() async {
    if (widget.bill != null || _numberLoading) return;
    setState(() => _numberLoading = true);
    try {
      _billNo.text = await _service.nextBillNumber(
        widget.companyId,
        billDate: _billDate,
      );
    } catch (error) {
      if (mounted) _message('Unable to generate bill number: $error');
    } finally {
      if (mounted) setState(() => _numberLoading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _billNo,
      _salesOrderRef,
      _grnRef,
      _supplierInvoiceNo,
      _customPaymentTerms,
      ..._totalControllers,
      _remarks,
    ]) {
      controller.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bill?.isPosted == true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Purchase Bill')),
        body: const Center(child: Text('Posted purchase bills are read-only.')),
      );
    }
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
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(postInventory: false),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _save(postInventory: true),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              label: const Text('Save & Post'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_PurchaseBillFormData>(
        future: _formDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              message: 'Unable to load purchase masters: ${snapshot.error}',
              onRetry: () => setState(() {
                _formDataFuture = _loadFormData();
              }),
            );
          }
          final data = snapshot.data!;
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    children: [
                      _headerSection(data),
                      _productSection(data.products),
                      _chargesAndTotalsSection(),
                      _attachmentSection(),
                      _section(
                        title: 'Internal Notes',
                        icon: Icons.notes_outlined,
                        child: TextFormField(
                          controller: _remarks,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Remarks',
                          ),
                        ),
                      ),
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

  Widget _headerSection(_PurchaseBillFormData data) {
    return _section(
      title: 'Bill Header',
      icon: Icons.receipt_long_outlined,
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(
            width: 270,
            child: TextFormField(
              controller: _billNo,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Purchase Bill No',
                suffixIcon: _numberLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
          ),
          _dateField('Purchase Bill Date', _billDate, (date) {
            final oldYear = purchaseFinancialYear(_billDate);
            setState(() => _billDate = date);
            if (widget.bill == null && oldYear != purchaseFinancialYear(date)) {
              _refreshBillNumber();
            }
          }),
          _vendorField(data.vendors),
          _readOnlyField('Vendor Name', _vendorName),
          _dropdownField(
            label: 'Payment Terms',
            value: _paymentTerms,
            values: vendorPaymentTermsOptions,
            onChanged: (value) =>
                setState(() => _paymentTerms = value ?? '30 Days'),
          ),
          if (_paymentTerms == 'Custom')
            SizedBox(
              width: 554,
              child: TextFormField(
                controller: _customPaymentTerms,
                decoration: const InputDecoration(
                  labelText: 'Custom Payment Terms',
                  hintText: '20% Advance + 80% Before Dispatch',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            ),
          _warehouseField(data.warehouses),
          _textField(_salesOrderRef, 'Sales Order Reference'),
          _textField(_grnRef, 'GRN Reference'),
          _textField(_supplierInvoiceNo, 'Supplier Invoice No', required: true),
          _dateField(
            'Supplier Invoice Date',
            _supplierInvoiceDate,
            (date) => setState(() => _supplierInvoiceDate = date),
          ),
          _dropdownField(
            label: 'Payment Status',
            value: _paymentStatus,
            values: purchaseBillPaymentStatuses,
            onChanged: (value) =>
                setState(() => _paymentStatus = value ?? 'Unpaid'),
          ),
        ],
      ),
    );
  }

  Widget _productSection(List<PurchaseProductMasterItem> products) {
    return _section(
      title: 'Products',
      icon: Icons.inventory_2_outlined,
      trailing: OutlinedButton.icon(
        onPressed: products.isEmpty ? null : _addLine,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: products.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No active purchasable products are available in Inventory Product Master.',
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < _lines.length; index++)
                  _productLineCard(index, products),
              ],
            ),
    );
  }

  Widget _productLineCard(int index, List<PurchaseProductMasterItem> products) {
    final line = _lines[index];
    return Card(
      elevation: 0,
      color: zSurfaceSoft,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        side: const BorderSide(color: zBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: zBlueSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: zBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line.productController.text.trim().isEmpty
                        ? 'Select a product'
                        : line.productController.text.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove product',
                  onPressed: _lines.length == 1
                      ? null
                      : () => _removeLine(index),
                  icon: const Icon(Icons.delete_outline, color: zDanger),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1320,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 230,
                      child: _productAutocomplete(line, products),
                    ),
                    const SizedBox(width: 8),
                    _lineTextField(
                      line.descriptionController,
                      'Description',
                      width: 220,
                    ),
                    const SizedBox(width: 8),
                    _lineTextField(
                      line.hsnController,
                      'HSN Code',
                      width: 100,
                      required: true,
                    ),
                    const SizedBox(width: 8),
                    _lineTextField(
                      line.unitController,
                      'Unit',
                      width: 90,
                      required: true,
                    ),
                    const SizedBox(width: 8),
                    _lineNumberField(
                      line.quantityController,
                      'Quantity',
                      width: 95,
                      positive: true,
                    ),
                    const SizedBox(width: 8),
                    _lineNumberField(line.rateController, 'Rate', width: 105),
                    const SizedBox(width: 8),
                    _lineNumberField(
                      line.discountController,
                      'Discount %',
                      width: 100,
                      percentage: true,
                    ),
                    const SizedBox(width: 8),
                    _lineNumberField(
                      line.taxController,
                      'Tax %',
                      width: 90,
                      percentage: true,
                    ),
                    const SizedBox(width: 8),
                    _lineAmount('Tax Amount', line.taxAmount, width: 115),
                    const SizedBox(width: 8),
                    _lineAmount(
                      'Line Total',
                      line.lineTotal,
                      width: 125,
                      emphasize: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productAutocomplete(
    _PurchaseBillLineEditor line,
    List<PurchaseProductMasterItem> products,
  ) {
    return RawAutocomplete<PurchaseProductMasterItem>(
      textEditingController: line.productController,
      focusNode: line.productFocus,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (text) {
        final query = text.text.trim().toLowerCase();
        if (query.isEmpty) return products.take(20);
        return products
            .where((product) => product.searchText.contains(query))
            .take(20);
      },
      onSelected: (product) {
        line.applyProduct(product);
        setState(() {});
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Product',
            prefixIcon: Icon(Icons.search),
          ),
          validator: (_) =>
              line.productId.isEmpty ? 'Select from Product Master' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(kAppRadiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 320),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final product = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (product.hsnCode.isNotEmpty)
                          'HSN ${product.hsnCode}',
                        product.unit,
                        if (product.defaultPurchaseRate > 0)
                          _money(product.defaultPurchaseRate),
                      ].join(' • '),
                    ),
                    onTap: () => onSelected(product),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _lineTextField(
    TextEditingController controller,
    String label, {
    required double width,
    bool required = false,
  }) {
    return SizedBox(
      width: width,
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

  Widget _lineNumberField(
    TextEditingController controller,
    String label, {
    required double width,
    bool positive = false,
    bool percentage = false,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final number = double.tryParse(
            (value ?? '').replaceAll(',', '').trim(),
          );
          if (number == null) return 'Required';
          if (positive && number <= 0) return 'Must be > 0';
          if (!positive && number < 0) return 'Cannot be negative';
          if (percentage && number > 100) return 'Max 100';
          return null;
        },
      ),
    );
  }

  Widget _lineAmount(
    String label,
    double amount, {
    required double width,
    bool emphasize = false,
  }) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, filled: true),
        child: Text(
          _money(amount),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _chargesAndTotalsSection() {
    final totals = _totals;
    return _section(
      title: 'Charges & Totals',
      icon: Icons.calculate_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final charges = Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _amountField(_freight, 'Freight Amount'),
              _amountField(_otherCharges, 'Other Charges'),
              _amountField(_tds, 'TDS Amount'),
            ],
          );
          final summary = Container(
            width: 390,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: zSurfaceSoft,
              borderRadius: BorderRadius.circular(kAppRadiusMd),
              border: Border.all(color: zBorder),
            ),
            child: Column(
              children: [
                _summaryRow('Subtotal', totals.subtotal),
                _summaryRow('Discount Total', -totals.discountTotal),
                _summaryRow('Taxable Value', totals.taxableValue),
                _summaryRow('GST Amount', totals.taxAmount),
                _summaryRow('Freight', _value(_freight)),
                _summaryRow('Other Charges', _value(_otherCharges)),
                _summaryRow('TDS', -_value(_tds)),
                const Divider(height: 22),
                _summaryRow('Grand Total', totals.grandTotal, bold: true),
              ],
            ),
          );
          if (constraints.maxWidth < 850) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [charges, const SizedBox(height: 18), summary],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: charges),
              const SizedBox(width: 24),
              summary,
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool bold = false}) {
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
            _money(amount),
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentSection() {
    final existing = widget.bill?.attachments ?? const [];
    return _section(
      title: 'Supplier Bill Attachments',
      icon: Icons.attach_file,
      trailing: OutlinedButton.icon(
        onPressed: _pickAttachments,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload PDF / Images'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Accepted: PDF, JPG, JPEG, PNG and WEBP. Maximum 10 MB per file.',
            style: TextStyle(color: zMuted),
          ),
          if (existing.isEmpty && _pendingAttachments.isEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: zSurfaceSoft,
                borderRadius: BorderRadius.circular(kAppRadiusMd),
                border: Border.all(color: zBorder),
              ),
              child: const Text('No documents attached.'),
            ),
          ],
          if (existing.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: existing
                  .map(
                    (attachment) => ActionChip(
                      avatar: Icon(
                        attachment.isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                        size: 18,
                      ),
                      label: Text(
                        attachment.fileName.isEmpty
                            ? 'Attachment'
                            : attachment.fileName,
                      ),
                      onPressed: () => _openUrl(attachment.url),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_pendingAttachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var index = 0; index < _pendingAttachments.length; index++)
                  InputChip(
                    avatar: Icon(
                      _pendingAttachments[index].contentType ==
                              'application/pdf'
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      size: 18,
                    ),
                    label: Text(_pendingAttachments[index].fileName),
                    onDeleted: () =>
                        setState(() => _pendingAttachments.removeAt(index)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: zBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _vendorField(List<VendorModel> vendors) {
    final available = vendors
        .where((vendor) => vendor.isActive || vendor.id == _vendorId)
        .toList();
    return SizedBox(
      width: 270,
      child: DropdownButtonFormField<String>(
        initialValue: available.any((vendor) => vendor.id == _vendorId)
            ? _vendorId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Vendor'),
        items: available
            .map(
              (vendor) => DropdownMenuItem(
                value: vendor.id,
                child: Text(
                  '${vendor.vendorName}${vendor.vendorCode.isEmpty ? '' : ' • ${vendor.vendorCode}'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        validator: (value) =>
            value == null || value.isEmpty ? 'Required' : null,
        onChanged: (value) {
          final selected = available
              .where((vendor) => vendor.id == value)
              .firstOrNull;
          setState(() {
            _vendorId = value;
            if (selected != null) {
              _vendorName = selected.vendorName;
              _paymentTerms = selected.paymentTerms;
              _customPaymentTerms.text = selected.customPaymentTerms;
            }
          });
        },
      ),
    );
  }

  Widget _warehouseField(List<WarehouseRecord> warehouses) {
    return SizedBox(
      width: 270,
      child: DropdownButtonFormField<String>(
        initialValue:
            warehouses.any((warehouse) => warehouse.id == _warehouseId)
            ? _warehouseId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Receiving Warehouse',
          helperText: 'Required when posting stock',
        ),
        items: warehouses
            .map(
              (warehouse) => DropdownMenuItem(
                value: warehouse.id,
                child: Text(warehouse.name),
              ),
            )
            .toList(),
        onChanged: (value) {
          final selected = warehouses
              .where((warehouse) => warehouse.id == value)
              .firstOrNull;
          setState(() {
            _warehouseId = value;
            _warehouseName = selected?.name ?? '';
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
      width: 270,
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

  Widget _amountField(TextEditingController controller, String label) {
    return SizedBox(
      width: 210,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '₹ '),
        validator: (value) {
          final parsed = double.tryParse(
            (value ?? '').replaceAll(',', '').trim(),
          );
          if (parsed != null && parsed < 0) return 'Cannot be negative';
          return null;
        },
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return SizedBox(
      width: 270,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, filled: true),
        child: Text(
          value.trim().isEmpty ? '-' : value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 270,
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

  Widget _dateField(
    String label,
    DateTime? date,
    ValueChanged<DateTime> onChanged,
  ) {
    return SizedBox(
      width: 270,
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

  void _addLine({bool notify = true}) {
    _lines.add(_PurchaseBillLineEditor(onChanged: _rebuild));
    if (notify && mounted) setState(() {});
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    final accepted = <PendingPurchaseBillAttachment>[];
    for (final file in result.files) {
      if (file.size > 10 * 1024 * 1024) {
        _message('${file.name} exceeds the 10 MB limit.');
        continue;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        _message('Unable to read ${file.name}.');
        continue;
      }
      accepted.add(
        PendingPurchaseBillAttachment(
          fileName: file.name,
          contentType: _contentType(file.name),
          bytes: Uint8List.fromList(bytes),
        ),
      );
    }
    if (accepted.isNotEmpty) {
      setState(() => _pendingAttachments.addAll(accepted));
    }
  }

  Future<void> _save({required bool postInventory}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendorId == null || _vendorName.trim().isEmpty) {
      _message('Select a vendor.');
      return;
    }
    if (_lines.isEmpty || _lines.any((line) => line.productId.isEmpty)) {
      _message('Select every product from Inventory Product Master.');
      return;
    }
    if (postInventory &&
        _lines.any((line) => line.trackInventory) &&
        _warehouseId == null) {
      _message('Select a receiving warehouse before posting.');
      return;
    }
    if (postInventory) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Post purchase bill?'),
          content: const Text(
            'Posting will increase inventory and lock this bill against editing or deletion.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Post Bill'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      await _service.saveBill(
        bill: _currentBill(postInventory: postInventory),
        userUid: widget.userUid,
        pendingAttachments: _pendingAttachments,
        postInventory: postInventory,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            postInventory
                ? 'Purchase bill posted and inventory updated.'
                : 'Purchase bill saved as draft.',
          ),
          backgroundColor: zSuccess,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _message(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  PurchaseBillModel _currentBill({bool postInventory = false}) {
    final existing = widget.bill;
    final products = _lines.map((line) => line.toModel()).toList();
    final totals = PurchaseBillTotals.fromLines(
      products,
      freightAmount: _value(_freight),
      otherCharges: _value(_otherCharges),
      tdsAmount: _value(_tds),
    );
    return PurchaseBillModel(
      id: existing?.id ?? '',
      companyId: widget.companyId,
      purchaseBillNo: _billNo.text,
      purchaseBillDate: _billDate,
      vendorId: _vendorId ?? '',
      vendorName: _vendorName,
      paymentTerms: _paymentTerms,
      customPaymentTerms: _paymentTerms == 'Custom'
          ? _customPaymentTerms.text
          : '',
      products: products,
      subtotal: totals.subtotal,
      discountTotal: totals.discountTotal,
      taxableValue: totals.taxableValue,
      taxAmount: totals.taxAmount,
      grandTotal: totals.grandTotal,
      paymentStatus: _paymentStatus,
      status: postInventory ? 'Posted' : 'Draft',
      salesOrderRef: _salesOrderRef.text,
      grnRef: _grnRef.text,
      supplierInvoiceNo: _supplierInvoiceNo.text,
      supplierInvoiceDate: _supplierInvoiceDate,
      freightAmount: _value(_freight),
      otherCharges: _value(_otherCharges),
      tdsAmount: _value(_tds),
      remarks: _remarks.text,
      warehouseId: _warehouseId ?? '',
      warehouseName: _warehouseName,
      attachmentUrls: existing?.attachmentUrls ?? const [],
      attachments: existing?.attachments ?? const [],
      inventoryPosted: false,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
      createdBy: existing?.createdBy ?? '',
      updatedBy: existing?.updatedBy ?? '',
    );
  }

  void _showCurrentPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseBillDetailsScreen(
          companyId: widget.companyId,
          userUid: widget.userUid,
          bill: _currentBill(),
          isPreview: true,
          pendingAttachmentNames: _pendingAttachments
              .map((attachment) => attachment.fileName)
              .toList(),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _message('Unable to open the attachment.');
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? zDanger : null),
    );
  }
}

class PurchaseBillDetailsScreen extends StatefulWidget {
  const PurchaseBillDetailsScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    required this.bill,
    this.isPreview = false,
    this.pendingAttachmentNames = const [],
  });

  final String companyId;
  final String userUid;
  final PurchaseBillModel bill;
  final bool isPreview;
  final List<String> pendingAttachmentNames;

  @override
  State<PurchaseBillDetailsScreen> createState() =>
      _PurchaseBillDetailsScreenState();
}

class _PurchaseBillDetailsScreenState extends State<PurchaseBillDetailsScreen> {
  final _service = PurchaseBillService();
  bool _posting = false;

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPreview ? 'Purchase Bill Preview' : 'Bill Details',
        ),
        actions: [
          if (!widget.isPreview && !bill.isPosted)
            TextButton.icon(
              onPressed: _posting ? null : _postBill,
              icon: _posting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              label: const Text('Post to Inventory'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _documentHeader(bill),
                const SizedBox(height: 16),
                _informationSection(bill),
                const SizedBox(height: 16),
                _productsSection(bill),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        children: [
                          _gstSummary(bill),
                          const SizedBox(height: 16),
                          _totalsCard(bill),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _gstSummary(bill)),
                        const SizedBox(width: 16),
                        SizedBox(width: 420, child: _totalsCard(bill)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _attachmentsSection(bill),
                if (bill.remarks.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _detailCard(
                    title: 'Remarks',
                    icon: Icons.notes_outlined,
                    child: Text(bill.remarks),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _documentHeader(PurchaseBillModel bill) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: zBlueSoft,
                borderRadius: BorderRadius.circular(kAppRadiusMd),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: zBlue,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dash(bill.purchaseBillNo),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dash(bill.vendorName)} • ${_date(bill.purchaseBillDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _PaymentStatusChip(status: bill.paymentStatus),
            const SizedBox(width: 8),
            _BillStatusChip(posted: bill.isPosted),
          ],
        ),
      ),
    );
  }

  Widget _informationSection(PurchaseBillModel bill) {
    return _detailCard(
      title: 'Bill Information',
      icon: Icons.info_outline,
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        children: [
          _detail('Vendor', bill.vendorName),
          _detail('Payment Terms', bill.effectivePaymentTerms),
          _detail('Supplier Invoice No', bill.supplierInvoiceNo),
          _detail(
            'Supplier Invoice Date',
            bill.supplierInvoiceDate == null
                ? ''
                : _date(bill.supplierInvoiceDate!),
          ),
          _detail('Sales Order Reference', bill.salesOrderRef),
          _detail('GRN Reference', bill.grnRef),
          _detail('Receiving Warehouse', bill.warehouseName),
        ],
      ),
    );
  }

  Widget _productsSection(PurchaseBillModel bill) {
    return _detailCard(
      title: 'Product Details',
      icon: Icons.inventory_2_outlined,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      child: bill.products.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'This is a legacy purchase bill without product-level data.',
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('HSN')),
                  DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Qty'), numeric: true),
                  DataColumn(label: Text('Rate'), numeric: true),
                  DataColumn(label: Text('Discount %'), numeric: true),
                  DataColumn(label: Text('Tax %'), numeric: true),
                  DataColumn(label: Text('Tax Amount'), numeric: true),
                  DataColumn(label: Text('Line Total'), numeric: true),
                ],
                rows: bill.products
                    .map(
                      (line) => DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                line.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(_dash(line.description)),
                            ),
                          ),
                          DataCell(Text(_dash(line.hsnCode))),
                          DataCell(Text(_dash(line.unit))),
                          DataCell(Text(_quantity(line.quantity))),
                          DataCell(Text(_money(line.rate))),
                          DataCell(Text(_percent(line.discountPercent))),
                          DataCell(Text(_percent(line.taxPercent))),
                          DataCell(Text(_money(line.taxAmount))),
                          DataCell(
                            Text(
                              _money(line.lineTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _gstSummary(PurchaseBillModel bill) {
    final groups = <double, _GstSummaryRow>{};
    for (final line in bill.products) {
      final row = groups.putIfAbsent(
        line.taxPercent,
        () => _GstSummaryRow(line.taxPercent),
      );
      row.taxableValue += line.taxableValue;
      row.taxAmount += line.taxAmount;
    }
    return _detailCard(
      title: 'GST Summary',
      icon: Icons.account_balance_outlined,
      child: groups.isEmpty
          ? Text('GST Amount: ${_money(bill.taxAmount)}')
          : Table(
              columnWidths: const {
                0: FlexColumnWidth(),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: zSurfaceSoft),
                  children: [
                    _TableCellText('GST Rate', bold: true),
                    _TableCellText('Taxable Value', bold: true, right: true),
                    _TableCellText('GST Amount', bold: true, right: true),
                  ],
                ),
                ...groups.values.map(
                  (row) => TableRow(
                    children: [
                      _TableCellText(_percent(row.rate)),
                      _TableCellText(_money(row.taxableValue), right: true),
                      _TableCellText(_money(row.taxAmount), right: true),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _totalsCard(PurchaseBillModel bill) {
    return _detailCard(
      title: 'Bill Totals',
      icon: Icons.calculate_outlined,
      child: Column(
        children: [
          _amountRow('Subtotal', bill.subtotal),
          _amountRow('Discount Total', -bill.discountTotal),
          _amountRow('Taxable Value', bill.taxableValue),
          _amountRow('GST Amount', bill.taxAmount),
          _amountRow('Freight', bill.freightAmount),
          _amountRow('Other Charges', bill.otherCharges),
          _amountRow('TDS', -bill.tdsAmount),
          const Divider(height: 22),
          _amountRow('Grand Total', bill.grandTotal, bold: true),
        ],
      ),
    );
  }

  Widget _attachmentsSection(PurchaseBillModel bill) {
    final attachments = bill.attachments;
    final urlOnly = bill.attachmentUrls
        .where((url) => !attachments.any((attachment) => attachment.url == url))
        .toList();
    return _detailCard(
      title: 'Uploaded Documents',
      icon: Icons.attach_file,
      child:
          attachments.isEmpty &&
              urlOnly.isEmpty &&
              widget.pendingAttachmentNames.isEmpty
          ? const Text('No supplier bill documents uploaded.')
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ...attachments.map(_attachmentCard),
                ...urlOnly.map(
                  (url) =>
                      _genericAttachmentCard(label: 'Attachment', url: url),
                ),
                ...widget.pendingAttachmentNames.map(
                  (name) => _pendingAttachmentCard(name),
                ),
              ],
            ),
    );
  }

  Widget _attachmentCard(PurchaseBillAttachment attachment) {
    if (attachment.isImage) {
      return SizedBox(
        width: 220,
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kAppRadiusMd),
            side: const BorderSide(color: zBorder),
          ),
          child: InkWell(
            onTap: () => _openUrl(attachment.url),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 130,
                  child: Image.network(
                    attachment.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: zSurfaceSoft,
                      child: Icon(Icons.broken_image_outlined, color: zMuted),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    attachment.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _genericAttachmentCard(
      label: attachment.fileName.isEmpty
          ? 'Supplier Bill PDF'
          : attachment.fileName,
      url: attachment.url,
      pdf: attachment.isPdf,
    );
  }

  Widget _genericAttachmentCard({
    required String label,
    required String url,
    bool pdf = false,
  }) {
    return SizedBox(
      width: 260,
      child: OutlinedButton.icon(
        onPressed: () => _openUrl(url),
        icon: Icon(pdf ? Icons.picture_as_pdf_outlined : Icons.attach_file),
        label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _pendingAttachmentCard(String name) {
    return SizedBox(
      width: 260,
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.schedule_outlined),
          labelText: 'Pending Upload',
        ),
        child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _detailCard({
    required String title,
    required IconData icon,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: zBlue, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            _dash(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool bold = false}) {
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
            _money(amount),
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _postBill() async {
    if (widget.bill.products.isEmpty) {
      _message('Add product lines before posting.', error: true);
      return;
    }
    if (widget.bill.products.any((line) => line.trackInventory) &&
        widget.bill.warehouseId.isEmpty) {
      _message(
        'Edit the draft and select a receiving warehouse before posting.',
        error: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post purchase bill?'),
        content: const Text(
          'Inventory quantities and valuation will be updated. The bill will become read-only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post Bill'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _posting = true);
    try {
      await _service.postExistingBill(
        bill: widget.bill,
        userUid: widget.userUid,
      );
      if (!mounted) return;
      _message('Purchase bill posted and inventory updated.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _message(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _message('Unable to open the attachment.', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? zDanger : null),
    );
  }
}

class _PurchaseBillLineEditor {
  _PurchaseBillLineEditor({PurchaseBillLine? seed, required this.onChanged}) {
    if (seed != null) {
      productId = seed.productId;
      productName = seed.productName;
      productNature = seed.productNature;
      trackInventory = seed.trackInventory;
      productController.text = seed.productName;
      descriptionController.text = seed.description;
      hsnController.text = seed.hsnCode;
      unitController.text = seed.unit;
      quantityController.text = _plainNumber(seed.quantity);
      rateController.text = _plainNumber(seed.rate);
      discountController.text = _plainNumber(seed.discountPercent);
      taxController.text = _plainNumber(seed.taxPercent);
    }
    productController.addListener(_productTextChanged);
    for (final controller in [
      descriptionController,
      hsnController,
      unitController,
      quantityController,
      rateController,
      discountController,
      taxController,
    ]) {
      controller.addListener(onChanged);
    }
  }

  final VoidCallback onChanged;
  final productController = TextEditingController();
  final descriptionController = TextEditingController();
  final hsnController = TextEditingController();
  final unitController = TextEditingController(text: 'Nos.');
  final quantityController = TextEditingController(text: '1');
  final rateController = TextEditingController(text: '0');
  final discountController = TextEditingController(text: '0');
  final taxController = TextEditingController(text: '0');
  final productFocus = FocusNode();

  String productId = '';
  String productName = '';
  String productNature = '';
  bool trackInventory = true;
  bool _applyingProduct = false;

  double get quantity => _value(quantityController);
  double get rate => _value(rateController);
  double get discountPercent => _value(discountController);
  double get taxPercent => _value(taxController);
  double get subtotal => quantity * rate;
  double get discountAmount => subtotal * discountPercent / 100;
  double get taxableValue => subtotal - discountAmount;
  double get taxAmount => taxableValue * taxPercent / 100;
  double get lineTotal => taxableValue + taxAmount;

  void applyProduct(PurchaseProductMasterItem product) {
    _applyingProduct = true;
    productId = product.id;
    productName = product.name;
    productNature = product.productNature;
    trackInventory = product.trackInventory;
    productController.text = product.name;
    descriptionController.text = product.description;
    hsnController.text = product.hsnCode;
    unitController.text = product.unit;
    if (product.defaultPurchaseRate > 0) {
      rateController.text = _plainNumber(product.defaultPurchaseRate);
    }
    taxController.text = _plainNumber(product.taxPercent);
    _applyingProduct = false;
    onChanged();
  }

  void _productTextChanged() {
    if (!_applyingProduct && productController.text.trim() != productName) {
      productId = '';
      productName = '';
    }
    onChanged();
  }

  PurchaseBillLine toModel() {
    return PurchaseBillLine(
      productId: productId,
      productName: productController.text.trim(),
      description: descriptionController.text.trim(),
      hsnCode: hsnController.text.trim(),
      unit: unitController.text.trim(),
      quantity: quantity,
      rate: rate,
      discountPercent: discountPercent,
      taxPercent: taxPercent,
      taxAmount: taxAmount,
      lineTotal: lineTotal,
      productNature: productNature,
      trackInventory: trackInventory,
    );
  }

  void dispose() {
    productController.dispose();
    descriptionController.dispose();
    hsnController.dispose();
    unitController.dispose();
    quantityController.dispose();
    rateController.dispose();
    discountController.dispose();
    taxController.dispose();
    productFocus.dispose();
  }
}

class _PurchaseBillFormData {
  const _PurchaseBillFormData({
    required this.vendors,
    required this.products,
    required this.warehouses,
  });

  final List<VendorModel> vendors;
  final List<PurchaseProductMasterItem> products;
  final List<WarehouseRecord> warehouses;
}

class _GstSummaryRow {
  _GstSummaryRow(this.rate);

  final double rate;
  double taxableValue = 0;
  double taxAmount = 0;
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(this.text, {this.bold = false, this.right = false});

  final String text;
  final bool bold;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
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
    return _StatusChip(label: status, color: color, background: background);
  }
}

class _BillStatusChip extends StatelessWidget {
  const _BillStatusChip({required this.posted});

  final bool posted;

  @override
  Widget build(BuildContext context) {
    return _StatusChip(
      label: posted ? 'Posted' : 'Draft',
      color: posted ? zSuccess : zInfo,
      background: posted ? zSuccessSoft : zInfoSoft,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
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
                : 'Try changing the search or filters.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: zDanger, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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

String _quantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

String _percent(double value) => '${_plainNumber(value)}%';

String _plainNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

String _contentType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
