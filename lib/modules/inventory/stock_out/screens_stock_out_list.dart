import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/inventory/inventory_service.dart';

class ScreensStockOutList extends StatefulWidget {
  const ScreensStockOutList({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<ScreensStockOutList> createState() => _ScreensStockOutListState();
}

class _ScreensStockOutListState extends State<ScreensStockOutList> {
  final _service = InventoryService();
  final _formKey = GlobalKey<FormState>();
  final _stockOutNoCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _issuedToCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _items = <_StockOutLine>[_StockOutLine()];
  final _availableByKey = <String, double>{};
  DateTime _date = DateTime.now();
  WarehouseRecord? _warehouse;
  String _purpose = stockOutPurposes.first;
  bool _saving = false;
  bool _loadingStock = true;

  @override
  void initState() {
    super.initState();
    _loadNumber();
    _loadAvailability();
  }

  @override
  void dispose() {
    _stockOutNoCtrl.dispose();
    _departmentCtrl.dispose();
    _issuedToCtrl.dispose();
    _remarksCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNumber() async {
    _stockOutNoCtrl.text = await _service.nextNumber(widget.companyId, 'stock_out', 'SOUT');
    if (mounted) setState(() {});
  }

  Future<void> _loadAvailability() async {
    setState(() => _loadingStock = true);
    final summary = await _service.loadSummary(widget.companyId);
    _availableByKey
      ..clear()
      ..addEntries(summary.map((r) => MapEntry(summaryKey(r.productId, r.productName, r.productNature, r.warehouseId), r.availableQty)));
    if (mounted) setState(() => _loadingStock = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WarehouseRecord>>(
      stream: _service.warehousesStream(widget.companyId),
      builder: (context, snapshot) {
        final warehouses = snapshot.data ?? [];
        if (_warehouse == null && warehouses.isNotEmpty) _warehouse = warehouses.first;
        return StreamBuilder<List<InventoryProduct>>(
          stream: _service.productsStream(widget.companyId),
          builder: (context, productSnapshot) {
            final products = productSnapshot.data ?? [];
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: _Header(title: 'Stock Out', subtitle: 'Issue Products to production, service, sales, or internal use')),
                      IconButton(tooltip: 'Refresh stock', onPressed: _loadAvailability, icon: const Icon(Icons.refresh)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Panel(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _text(_stockOutNoCtrl, 'Stock Out No', required: true),
                        _dateField(),
                        _warehouseField(warehouses),
                        _text(_departmentCtrl, 'Department'),
                        _text(_issuedToCtrl, 'Issued To'),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: _purpose,
                            decoration: const InputDecoration(labelText: 'Purpose', border: OutlineInputBorder()),
                            items: stockOutPurposes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (value) => setState(() => _purpose = value ?? stockOutPurposes.first),
                          ),
                        ),
                        SizedBox(
                          width: 420,
                          child: TextFormField(
                            controller: _remarksCtrl,
                            decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _Panel(
                      child: _loadingStock
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(child: Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                                    OutlinedButton.icon(
                                      onPressed: products.isEmpty ? null : () => setState(() => _items.add(_StockOutLine())),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Product'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: products.isEmpty
                                      ? const _EmptyProductsState()
                                      : SingleChildScrollView(
                                          child: Column(children: [for (var i = 0; i < _items.length; i++) _itemRow(i, products)]),
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(onPressed: _saving ? null : _reset, child: const Text('Clear')),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _saving || products.isEmpty ? null : _save,
                        icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                        label: const Text('Save Stock Out'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _warehouseField(List<WarehouseRecord> warehouses) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: _warehouse?.id,
        decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
        items: warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
        validator: (v) => v == null ? 'Required' : null,
        onChanged: (id) => setState(() {
          _warehouse = _firstWhereOrNull(warehouses, (w) => w.id == id);
        }),
      ),
    );
  }

  Widget _dateField() {
    return SizedBox(
      width: 190,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
          if (picked != null) setState(() => _date = picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
          child: Text(DateFormat('dd MMM yyyy').format(_date)),
        ),
      ),
    );
  }

  Widget _itemRow(int index, List<InventoryProduct> products) {
    final item = _items[index];
    final selected = _firstWhereOrNull(products, (product) => product.id == item.productId);
    final available = _available(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: selected?.id,
              decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
              items: products.map((product) => DropdownMenuItem(value: product.id, child: Text(product.name))).toList(),
              validator: (value) => value == null ? 'Required' : null,
              onChanged: (id) => setState(() {
                final product = _firstWhereOrNull(products, (p) => p.id == id);
                item.productId = product?.id ?? '';
                item.productName = product?.name ?? '';
                item.nature = product?.productNature ?? inventoryProductNatures.first;
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: item.nature,
              decoration: const InputDecoration(labelText: 'Product Nature', border: OutlineInputBorder()),
              items: inventoryProductNatures.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (value) => setState(() => item.nature = value ?? inventoryProductNatures.first),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Available Qty', border: OutlineInputBorder()),
              child: Text(formatQty(available), textAlign: TextAlign.right),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 130, child: _number(item.issueCtrl, 'Issue Qty', available, onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove',
            onPressed: _items.length == 1 ? null : () => setState(() => _items.removeAt(index).dispose()),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  double _available(_StockOutLine item) {
    if (_warehouse == null) return 0;
    return _availableByKey[summaryKey(item.productId, item.productName, item.nature, _warehouse!.id)] ?? 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _warehouse == null) return;
    final items = _items.map((line) => line.toItem()).toList();
    for (var i = 0; i < _items.length; i++) {
      final available = _available(_items[i]);
      if (items[i].quantity > available) {
        _message('${items[i].productName} has only ${formatQty(available)} available.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await _service.saveStockOut(
        companyId: widget.companyId,
        stockOutNo: _stockOutNoCtrl.text,
        date: _date,
        warehouse: _warehouse!,
        department: _departmentCtrl.text,
        issuedTo: _issuedToCtrl.text,
        purpose: _purpose,
        remarks: _remarksCtrl.text,
        items: items,
        availableByKey: _availableByKey,
        userUid: widget.userUid,
      );
      _message('Stock Out saved.');
      _reset();
      await _loadAvailability();
    } catch (e) {
      _message(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    _departmentCtrl.clear();
    _issuedToCtrl.clear();
    _remarksCtrl.clear();
    for (final item in _items) {
      item.dispose();
    }
    _items
      ..clear()
      ..add(_StockOutLine());
    _date = DateTime.now();
    _purpose = stockOutPurposes.first;
    _loadNumber();
    setState(() {});
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _StockOutLine {
  final issueCtrl = TextEditingController();
  String productId = '';
  String productName = '';
  String nature = inventoryProductNatures.first;

  double get issueQty => double.tryParse(issueCtrl.text.trim()) ?? 0;

  StockItem toItem() => StockItem(productId: productId, productName: productName, productNature: nature, quantity: issueQty);

  void dispose() {
    issueCtrl.dispose();
  }
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

Widget _text(TextEditingController controller, String label, {bool required = false, double width = 230, ValueChanged<String>? onChanged}) {
  return SizedBox(
    width: width,
    child: TextFormField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    ),
  );
}

Widget _number(TextEditingController controller, String label, double available, {ValueChanged<String>? onChanged}) {
  return TextFormField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textAlign: TextAlign.right,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    validator: (v) {
      final qty = double.tryParse(v ?? '') ?? 0;
      if (qty <= 0) return 'Invalid';
      if (qty > available) return 'Exceeds';
      return null;
    },
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
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No active products found. Add products in Inventory > Products before issuing stock.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }
}
