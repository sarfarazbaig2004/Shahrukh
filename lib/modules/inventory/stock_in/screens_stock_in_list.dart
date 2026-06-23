import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/inventory/inventory_service.dart';

class ScreensStockInList extends StatefulWidget {
  const ScreensStockInList({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<ScreensStockInList> createState() => _ScreensStockInListState();
}

class _ScreensStockInListState extends State<ScreensStockInList> {
  final _service = InventoryService();
  final _formKey = GlobalKey<FormState>();
  final _stockInNoCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _items = <_StockInLine>[_StockInLine()];
  DateTime _date = DateTime.now();
  WarehouseRecord? _warehouse;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadNumber();
  }

  @override
  void dispose() {
    _stockInNoCtrl.dispose();
    _supplierCtrl.dispose();
    _invoiceCtrl.dispose();
    _remarksCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNumber() async {
    _stockInNoCtrl.text = await _service.nextNumber(widget.companyId, 'stock_in', 'SIN');
    if (mounted) setState(() {});
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
                  _Header(title: 'Stock In', subtitle: 'Receive Products into warehouse stock'),
                  const SizedBox(height: 12),
                  _Panel(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _text(_stockInNoCtrl, 'Stock In No', required: true),
                        _dateField(),
                        _warehouseField(warehouses),
                        _text(_supplierCtrl, 'Supplier'),
                        _text(_invoiceCtrl, 'Invoice No'),
                        SizedBox(
                          width: 480,
                          child: TextFormField(
                            controller: _remarksCtrl,
                            decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                              OutlinedButton.icon(
                                onPressed: products.isEmpty ? null : () => setState(() => _items.add(_StockInLine())),
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
                              child: Column(
                                children: [
                                  for (var i = 0; i < _items.length; i++) _itemRow(i, products),
                                ],
                              ),
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
                        label: const Text('Save Stock In'),
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
        onChanged: (id) => setState(() => _warehouse = _firstWhereOrNull(warehouses, (w) => w.id == id)),
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
                if (item.rateCtrl.text.trim().isEmpty && product != null && product.rate > 0) {
                  item.rateCtrl.text = product.rate.toStringAsFixed(2);
                }
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
          SizedBox(width: 120, child: _number(item.qtyCtrl, 'Quantity')),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: _number(item.rateCtrl, 'Rate')),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
              child: Text((item.qty * item.rate).toStringAsFixed(2), textAlign: TextAlign.right),
            ),
          ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _warehouse == null) return;
    final items = _items.map((line) => line.toItem()).toList();
    if (items.any((item) => item.quantity <= 0)) {
      _message('Quantity must be greater than zero.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveStockIn(
        companyId: widget.companyId,
        stockInNo: _stockInNoCtrl.text,
        date: _date,
        warehouse: _warehouse!,
        supplier: _supplierCtrl.text,
        invoiceNo: _invoiceCtrl.text,
        remarks: _remarksCtrl.text,
        items: items,
        userUid: widget.userUid,
      );
      _message('Stock In saved.');
      _reset();
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    _supplierCtrl.clear();
    _invoiceCtrl.clear();
    _remarksCtrl.clear();
    for (final item in _items) {
      item.dispose();
    }
    _items
      ..clear()
      ..add(_StockInLine());
    _date = DateTime.now();
    _loadNumber();
    setState(() {});
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _StockInLine {
  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  String productId = '';
  String productName = '';
  String nature = inventoryProductNatures.first;

  double get qty => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get rate => double.tryParse(rateCtrl.text.trim()) ?? 0;

  StockItem toItem() => StockItem(productId: productId, productName: productName, productNature: nature, quantity: qty, rate: rate);

  void dispose() {
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

Widget _text(TextEditingController controller, String label, {bool required = false, double width = 230}) {
  return SizedBox(
    width: width,
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    ),
  );
}

Widget _number(TextEditingController controller, String label) {
  return TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textAlign: TextAlign.right,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
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
        'No active products found. Add products in Inventory > Products before saving stock.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }
}