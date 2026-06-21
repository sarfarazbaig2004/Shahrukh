import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final _searchCtrl = TextEditingController();
  String _vendorFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  int _page = 0;
  static const _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PurchaseBill>>(
      stream: _service.watchBills(widget.companyId),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final bills = snapshot.data ?? [];
        final vendors = ['All', ...{for (final bill in bills) bill.vendorName}.where((v) => v.isNotEmpty)];
        final filtered = _filterBills(bills);
        final maxPage = filtered.isEmpty ? 0 : ((filtered.length - 1) / _pageSize).floor();
        if (_page > maxPage) _page = maxPage;
        final visible = filtered.skip(_page * _pageSize).take(_pageSize).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEntry(),
            icon: const Icon(Icons.add),
            label: const Text('Create Purchase Bill'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: 'Purchase Bills',
                subtitle: '${filtered.length} bill${filtered.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() => _page = 0),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Search bill, vendor, invoice',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    _drop(
                      label: 'Vendor',
                      value: vendors.contains(_vendorFilter) ? _vendorFilter : 'All',
                      values: vendors,
                      onChanged: (v) => setState(() {
                        _vendorFilter = v ?? 'All';
                        _page = 0;
                      }),
                    ),
                    _drop(
                      label: 'Status',
                      value: _statusFilter,
                      values: const ['All', 'Draft', 'Approved', 'Cancelled'],
                      onChanged: (v) => setState(() {
                        _statusFilter = v ?? 'All';
                        _page = 0;
                      }),
                    ),
                    _dateButton('From', _fromDate, (date) => setState(() {
                          _fromDate = date;
                          _page = 0;
                        })),
                    _dateButton('To', _toDate, (date) => setState(() {
                          _toDate = date;
                          _page = 0;
                        })),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _vendorFilter = 'All';
                        _statusFilter = 'All';
                        _fromDate = null;
                        _toDate = null;
                        _page = 0;
                      }),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _Panel(
                  padding: EdgeInsets.zero,
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? const _EmptyState()
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                      columns: const [
                                        DataColumn(label: Text('Bill Number')),
                                        DataColumn(label: Text('Bill Date')),
                                        DataColumn(label: Text('Vendor')),
                                        DataColumn(label: Text('Warehouse')),
                                        DataColumn(label: Text('Amount'), numeric: true),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: visible.map(_row).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(filtered.isEmpty ? 'No records' : 'Page ${_page + 1} of ${maxPage + 1}', style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(width: 12),
                    OutlinedButton(onPressed: _page == 0 ? null : () => setState(() => _page--), child: const Text('Previous')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _page >= maxPage ? null : () => setState(() => _page++), child: const Text('Next')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<PurchaseBill> _filterBills(List<PurchaseBill> bills) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return bills.where((bill) {
      final haystack = '${bill.billNumber} ${bill.vendorName} ${bill.vendorInvoiceNumber} ${bill.warehouseName}'.toLowerCase();
      final matchesSearch = query.isEmpty || haystack.contains(query);
      final matchesVendor = _vendorFilter == 'All' || bill.vendorName == _vendorFilter;
      final matchesStatus = _statusFilter == 'All' || bill.status == _statusFilter;
      final billDay = DateTime(bill.billDate.year, bill.billDate.month, bill.billDate.day);
      final afterFrom = _fromDate == null || !billDay.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day));
      final beforeTo = _toDate == null || !billDay.isAfter(DateTime(_toDate!.year, _toDate!.month, _toDate!.day));
      return matchesSearch && matchesVendor && matchesStatus && afterFrom && beforeTo;
    }).toList();
  }

  DataRow _row(PurchaseBill bill) {
    return DataRow(cells: [
      DataCell(Text(bill.billNumber)),
      DataCell(Text(DateFormat('dd MMM yyyy').format(bill.billDate))),
      DataCell(Text(bill.vendorName)),
      DataCell(Text(bill.warehouseName)),
      DataCell(Text(_money(bill.grandTotal))),
      DataCell(_StatusPill(status: bill.status)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined), onPressed: () => _viewBill(bill)),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: bill.status == 'Approved' ? null : () => _openEntry(bill: bill),
          ),
          IconButton(tooltip: 'Print', icon: const Icon(Icons.print_outlined), onPressed: () => _printBill(bill)),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            onPressed: bill.status == 'Approved' ? null : () => _deleteBill(bill),
          ),
          IconButton(
            tooltip: 'Convert To Stock Entry',
            icon: const Icon(Icons.move_to_inbox_outlined),
            onPressed: bill.status == 'Draft' ? () => _approveBill(bill) : null,
          ),
        ],
      )),
    ]);
  }

  Future<void> _openEntry({PurchaseBill? bill}) async {
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

  void _viewBill(PurchaseBill bill) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bill.billNumber),
        content: SizedBox(width: 720, child: _BillPreview(bill: bill)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _printBill(PurchaseBill bill) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Print Preview')),
            IconButton(tooltip: 'Print', icon: const Icon(Icons.print_outlined), onPressed: () {}),
          ],
        ),
        content: SizedBox(width: 760, child: _BillPreview(bill: bill)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _deleteBill(PurchaseBill bill) async {
    final ok = await _confirm('Delete purchase bill?', 'This will delete ${bill.billNumber}.');
    if (ok != true) return;
    try {
      await _service.deleteBill(companyId: widget.companyId, billId: bill.id);
      _message('Purchase bill deleted.');
    } catch (e) {
      _message(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _approveBill(PurchaseBill bill) async {
    final ok = await _confirm('Approve and convert to stock?', 'This will create purchase stock movements and update product stock.');
    if (ok != true) return;
    await _service.approveBill(companyId: widget.companyId, billId: bill.id, userUid: widget.userUid);
    _message('Stock entry created from purchase bill.');
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
  final PurchaseBill? bill;

  @override
  State<PurchaseBillEntryScreen> createState() => _PurchaseBillEntryScreenState();
}

class _PurchaseBillEntryScreenState extends State<PurchaseBillEntryScreen> {
  final _service = PurchaseBillService();
  final _formKey = GlobalKey<FormState>();
  final _billNoCtrl = TextEditingController();
  final _vendorInvoiceCtrl = TextEditingController();
  final _grnCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _freightCtrl = TextEditingController(text: '0');
  final _otherCtrl = TextEditingController(text: '0');
  final _lines = <_BillLine>[_BillLine()];
  DateTime _billDate = DateTime.now();
  DateTime? _vendorInvoiceDate;
  String _status = 'Draft';
  PurchaseVendor? _vendor;
  PurchaseWarehouse? _warehouse;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _seed();
    _discountCtrl.addListener(_recalculate);
    _freightCtrl.addListener(_recalculate);
    _otherCtrl.addListener(_recalculate);
  }

  Future<void> _seed() async {
    final bill = widget.bill;
    if (bill == null) {
      _billNoCtrl.text = await _service.nextBillNumber(widget.companyId);
      if (mounted) setState(() {});
      return;
    }
    _billNoCtrl.text = bill.billNumber;
    _billDate = bill.billDate;
    _vendorInvoiceCtrl.text = bill.vendorInvoiceNumber;
    _vendorInvoiceDate = bill.vendorInvoiceDate;
    _grnCtrl.text = bill.grnId;
    _remarksCtrl.text = bill.remarks;
    _discountCtrl.text = bill.discount.toStringAsFixed(2);
    _freightCtrl.text = bill.freight.toStringAsFixed(2);
    _otherCtrl.text = bill.otherCharges.toStringAsFixed(2);
    _status = bill.status;
    _vendor = PurchaseVendor(id: bill.vendorId, name: bill.vendorName, gstin: bill.vendorGSTIN);
    _warehouse = PurchaseWarehouse(id: bill.warehouseId, name: bill.warehouseName);
    for (final line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..addAll(bill.items.map(_BillLine.fromBillItem));
    setState(() {});
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _vendorInvoiceCtrl.dispose();
    _grnCtrl.dispose();
    _remarksCtrl.dispose();
    _discountCtrl.dispose();
    _freightCtrl.dispose();
    _otherCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bill == null ? 'Create Purchase Bill' : 'Edit Purchase Bill'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : () => _save('Draft'),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save('Approved'),
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
            label: const Text('Approve'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<List<PurchaseVendor>>(
        stream: _service.watchVendors(widget.companyId),
        builder: (context, vendorSnap) {
          return StreamBuilder<List<PurchaseWarehouse>>(
            stream: _service.watchWarehouses(widget.companyId),
            builder: (context, warehouseSnap) {
              return StreamBuilder<List<PurchaseProduct>>(
                stream: _service.watchProducts(widget.companyId),
                builder: (context, productSnap) {
                  final vendors = vendorSnap.data ?? [];
                  final warehouses = warehouseSnap.data ?? [];
                  final products = productSnap.data ?? [];
                  _vendor = _matchVendor(vendors) ?? _vendor;
                  _warehouse = _matchWarehouse(warehouses) ?? _warehouse;
                  final totals = _totals();
                  return Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Panel(
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                _vendorField(vendors),
                                _readonly('Vendor GSTIN', _vendor?.gstin ?? ''),
                                _text(_billNoCtrl, 'Bill Number', required: true),
                                _dateBox('Bill Date', _billDate, (d) => setState(() => _billDate = d)),
                                _text(_vendorInvoiceCtrl, 'Vendor Invoice Number'),
                                _dateBox('Vendor Invoice Date', _vendorInvoiceDate, (d) => setState(() => _vendorInvoiceDate = d)),
                                _warehouseField(warehouses),
                                _text(_grnCtrl, 'GRN ID'),
                                SizedBox(
                                  width: 470,
                                  child: TextFormField(
                                    controller: _remarksCtrl,
                                    decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(child: Text('Product Grid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                                    OutlinedButton.icon(
                                      onPressed: products.isEmpty ? null : () => setState(() => _lines.add(_BillLine())),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Item'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (products.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text('No active products found. Add products before creating purchase bills.', textAlign: TextAlign.center),
                                  )
                                else
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Column(
                                      children: [
                                        _gridHeader(),
                                        for (var i = 0; i < _lines.length; i++) _gridRow(i, products),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 520,
                              child: _Panel(
                                child: Column(
                                  children: [
                                    _totalRow('Sub Total', totals.subTotal),
                                    _totalInput(_discountCtrl, 'Discount'),
                                    _totalInput(_freightCtrl, 'Freight'),
                                    _totalInput(_otherCtrl, 'Other Charges'),
                                    _totalRow('CGST', totals.cgst),
                                    _totalRow('SGST', totals.sgst),
                                    _totalRow('IGST', totals.igst),
                                    const Divider(),
                                    _totalRow('Grand Total', totals.grandTotal, bold: true),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _vendorField(List<PurchaseVendor> vendors) {
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<String>(
        initialValue: _vendor?.id,
        decoration: const InputDecoration(labelText: 'Vendor', border: OutlineInputBorder()),
        items: vendors.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.name}${v.gstin.isEmpty ? '' : ' • ${v.gstin}'}'))).toList(),
        validator: (value) => value == null ? 'Required' : null,
        onChanged: (id) => setState(() => _vendor = vendors.where((v) => v.id == id).firstOrNull),
      ),
    );
  }

  Widget _warehouseField(List<PurchaseWarehouse> warehouses) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: _warehouse?.id,
        decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
        items: warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
        validator: (value) => value == null ? 'Required' : null,
        onChanged: (id) => setState(() => _warehouse = warehouses.where((w) => w.id == id).firstOrNull),
      ),
    );
  }

  Widget _gridHeader() {
    const style = TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569));
    return Container(
      width: 1180,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: const Row(
        children: [
          SizedBox(width: 260, child: Text('Product', style: style)),
          SizedBox(width: 120, child: Text('Code', style: style)),
          SizedBox(width: 150, child: Text('Nature', style: style)),
          SizedBox(width: 90, child: Text('Unit', style: style)),
          SizedBox(width: 120, child: Text('Current Stock', style: style)),
          SizedBox(width: 110, child: Text('Quantity', style: style)),
          SizedBox(width: 110, child: Text('Rate', style: style)),
          SizedBox(width: 90, child: Text('GST %', style: style)),
          SizedBox(width: 120, child: Text('Line Total', style: style)),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _gridRow(int index, List<PurchaseProduct> products) {
    final line = _lines[index];
    final selected = products.where((p) => p.id == line.productId).firstOrNull;
    return Container(
      width: 1180,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: selected?.id,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name}${p.code.isEmpty ? '' : ' • ${p.code}'}'))).toList(),
              validator: (value) => value == null ? 'Required' : null,
              onChanged: (id) => setState(() {
                final product = products.where((p) => p.id == id).firstOrNull;
                if (product == null) return;
                line.productId = product.id;
                line.productCode = product.code;
                line.productName = product.name;
                line.productNature = product.productNature;
                line.unit = product.unit;
                line.currentStock = product.currentStock;
                if (line.rateCtrl.text.trim().isEmpty && product.rate > 0) {
                  line.rateCtrl.text = product.rate.toStringAsFixed(2);
                }
              }),
            ),
          ),
          _cell(line.productCode),
          _cell(line.productNature),
          _cell(line.unit, width: 90),
          _cell(_qty(line.currentStock), width: 120, alignRight: true),
          _numberCell(line.qtyCtrl, width: 110),
          _numberCell(line.rateCtrl, width: 110),
          _numberCell(line.gstCtrl, width: 90),
          _cell(_money(line.toItem().lineTotal), width: 120, alignRight: true),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: _lines.length == 1 ? null : () => setState(() => _lines.removeAt(index).dispose()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {double width = 120, bool alignRight = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(text.isEmpty ? '-' : text, textAlign: alignRight ? TextAlign.right : TextAlign.left),
      ),
    );
  }

  Widget _numberCell(TextEditingController controller, {required double width}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0 ? 'Invalid' : null,
        ),
      ),
    );
  }

  PurchaseBillTotals _totals() {
    final subTotal = _lines.fold<double>(0, (sum, line) => sum + line.toItem().taxableAmount);
    final gst = _lines.fold<double>(0, (sum, line) => sum + line.toItem().gstAmount);
    final discount = _num(_discountCtrl);
    final freight = _num(_freightCtrl);
    final other = _num(_otherCtrl);
    final halfGst = gst / 2;
    return PurchaseBillTotals(
      subTotal: subTotal,
      cgst: halfGst,
      sgst: halfGst,
      igst: 0,
      discount: discount,
      freight: freight,
      otherCharges: other,
      grandTotal: subTotal + gst - discount + freight + other,
    );
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendor == null) {
      _message('Select vendor.');
      return;
    }
    if (_warehouse == null) {
      _message('Select warehouse.');
      return;
    }
    final items = _lines.map((line) => line.toItem()).toList();
    if (items.isEmpty || items.any((item) => item.productId.isEmpty)) {
      _message('Add at least one product.');
      return;
    }
    if (items.any((item) => item.quantity <= 0 || item.rate <= 0)) {
      _message('Quantity and rate must be greater than zero.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveBill(
        companyId: widget.companyId,
        userUid: widget.userUid,
        billId: widget.bill?.id,
        payload: PurchaseBillPayload(
          billNumber: _billNoCtrl.text,
          billDate: _billDate,
          vendor: _vendor!,
          vendorInvoiceNumber: _vendorInvoiceCtrl.text,
          vendorInvoiceDate: _vendorInvoiceDate,
          warehouse: _warehouse!,
          grnId: _grnCtrl.text,
          remarks: _remarksCtrl.text,
          totals: _totals(),
          status: status,
          items: items,
        ),
      );
      _message(status == 'Approved' ? 'Purchase bill approved and stock updated.' : 'Purchase bill saved.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _message(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  PurchaseVendor? _matchVendor(List<PurchaseVendor> vendors) {
    final id = _vendor?.id;
    if (id == null) return null;
    return vendors.where((v) => v.id == id).firstOrNull;
  }

  PurchaseWarehouse? _matchWarehouse(List<PurchaseWarehouse> warehouses) {
    final id = _warehouse?.id;
    if (id == null) return null;
    return warehouses.where((w) => w.id == id).firstOrNull;
  }

  void _recalculate() {
    if (mounted) setState(() {});
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BillLine {
  _BillLine() {
    qtyCtrl.addListener(_notify);
    rateCtrl.addListener(_notify);
    gstCtrl.addListener(_notify);
  }

  factory _BillLine.fromBillItem(PurchaseBillItem item) {
    final line = _BillLine();
    line.productId = item.productId;
    line.productCode = item.productCode;
    line.productName = item.productName;
    line.productNature = item.productNature;
    line.unit = item.unit;
    line.qtyCtrl.text = item.quantity.toStringAsFixed(2);
    line.rateCtrl.text = item.rate.toStringAsFixed(2);
    line.gstCtrl.text = item.gstPercent.toStringAsFixed(2);
    return line;
  }

  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final gstCtrl = TextEditingController(text: '18');
  String productId = '';
  String productCode = '';
  String productName = '';
  String productNature = '';
  String unit = 'Nos';
  double currentStock = 0;

  PurchaseBillItem toItem() {
    return PurchaseBillItem(
      productId: productId,
      productCode: productCode,
      productName: productName,
      productNature: productNature,
      unit: unit,
      quantity: _num(qtyCtrl),
      rate: _num(rateCtrl),
      gstPercent: _num(gstCtrl),
    );
  }

  void _notify() {}

  void dispose() {
    qtyCtrl.dispose();
    rateCtrl.dispose();
    gstCtrl.dispose();
  }
}

class _BillPreview extends StatelessWidget {
  const _BillPreview({required this.bill});

  final PurchaseBill bill;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _kv('Bill Date', DateFormat('dd MMM yyyy').format(bill.billDate)),
              _kv('Vendor', bill.vendorName),
              _kv('GSTIN', bill.vendorGSTIN),
              _kv('Invoice', bill.vendorInvoiceNumber),
              _kv('Warehouse', bill.warehouseName),
              _kv('Status', bill.status),
            ],
          ),
          const SizedBox(height: 16),
          DataTable(
            columns: const [
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('Code')),
              DataColumn(label: Text('Qty'), numeric: true),
              DataColumn(label: Text('Rate'), numeric: true),
              DataColumn(label: Text('GST %'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: bill.items
                .map(
                  (item) => DataRow(cells: [
                    DataCell(Text(item.productName)),
                    DataCell(Text(item.productCode)),
                    DataCell(Text(_qty(item.quantity))),
                    DataCell(Text(_money(item.rate))),
                    DataCell(Text(_qty(item.gstPercent))),
                    DataCell(Text(_money(item.lineTotal))),
                  ]),
                )
                .toList(),
          ),
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 280,
              child: Column(
                children: [
                  _previewTotal('Sub Total', bill.subTotal),
                  _previewTotal('CGST', bill.cgst),
                  _previewTotal('SGST', bill.sgst),
                  _previewTotal('Discount', bill.discount),
                  _previewTotal('Freight', bill.freight),
                  _previewTotal('Other Charges', bill.otherCharges),
                  const Divider(),
                  _previewTotal('Grand Total', bill.grandTotal, bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _kv(String label, String value) {
  return SizedBox(
    width: 210,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

Widget _previewTotal(String label, double value, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
        Text(_money(value), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ],
    ),
  );
}

Widget _drop({
  required String label,
  required String value,
  required List<String> values,
  required ValueChanged<String?> onChanged,
}) {
  return SizedBox(
    width: 210,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: onChanged,
    ),
  );
}

Widget _dateButton(String label, DateTime? date, ValueChanged<DateTime?> onChanged) {
  return Builder(
    builder: (context) => OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: date ?? DateTime.now(),
        );
        onChanged(picked);
      },
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text(date == null ? label : '$label ${DateFormat('dd MMM yyyy').format(date)}'),
    ),
  );
}

Widget _dateBox(String label, DateTime? date, ValueChanged<DateTime> onChanged) {
  return Builder(
    builder: (context) => SizedBox(
      width: 210,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            initialDate: date ?? DateTime.now(),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          child: Text(date == null ? 'Select date' : DateFormat('dd MMM yyyy').format(date)),
        ),
      ),
    ),
  );
}

Widget _text(TextEditingController controller, String label, {bool required = false}) {
  return SizedBox(
    width: 220,
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (value) => (value == null || value.trim().isEmpty) ? 'Required' : null : null,
    ),
  );
}

Widget _readonly(String label, String value) {
  return SizedBox(
    width: 220,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: Text(value.isEmpty ? '-' : value),
    ),
  );
}

Widget _totalInput(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    ),
  );
}

Widget _totalRow(String label, double value, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
        Text(_money(value), style: TextStyle(fontSize: bold ? 18 : 14, fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Approved' => const Color(0xFF166534),
      'Cancelled' => const Color(0xFF991B1B),
      _ => const Color(0xFF92400E),
    };
    final bg = switch (status) {
      'Approved' => const Color(0xFFDCFCE7),
      'Cancelled' => const Color(0xFFFEE2E2),
      _ => const Color(0xFFFEF3C7),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text('No purchase bills found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Create a purchase bill to start vendor billing and stock posting.', style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

double _num(TextEditingController controller) {
  return double.tryParse(controller.text.trim()) ?? 0;
}

String _money(double value) {
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(value);
}

String _qty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

