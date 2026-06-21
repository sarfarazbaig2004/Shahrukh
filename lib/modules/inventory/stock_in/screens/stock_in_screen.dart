import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/inventory/stock_in/services/stock_in_service.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final StockInService _service = StockInService();
  final _formKey = GlobalKey<FormState>();

  final _qtyController = TextEditingController();
  final _vendorController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();

  String _productNature = 'Machine';
  String _warehouseName = 'Main Warehouse';
  String _selectedProductId = '';
  String _selectedProductName = '';
  bool _isSaving = false;

  final List<String> _productNatures = const [
    'Machine',
    'Spare',
    'Accessory',
    'Raw Material',
    'Consumable',
  ];

  final List<String> _warehouses = const [
    'Main Warehouse',
    'Factory',
    'Store',
    'Service Store',
    'Dispatch Area',
  ];

  @override
  void dispose() {
    _qtyController.dispose();
    _vendorController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _saveStockIn() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductId.isEmpty) {
      _showSnack('Please select a product.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _service.saveStockIn(
        companyId: widget.companyId,
        userUid: widget.userUid,
        productId: _selectedProductId,
        productName: _selectedProductName,
        productNature: _productNature,
        warehouseName: _warehouseName,
        quantity: double.tryParse(_qtyController.text.trim()) ?? 0,
        vendorName: _vendorController.text,
        referenceNo: _referenceController.text,
        remarks: _remarksController.text,
      );

      if (!mounted) return;

      _qtyController.clear();
      _vendorController.clear();
      _referenceController.clear();
      _remarksController.clear();

      setState(() {
        _selectedProductId = '';
        _selectedProductName = '';
      });

      _showSnack('Stock In saved successfully.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _safe(dynamic value) => value?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF7A00,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.move_to_inbox_outlined,
                              color: Color(0xFFFF7A00),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stock In',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Receive purchased or opening stock into warehouse.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      DropdownButtonFormField<String>(
                        initialValue: _productNature,
                        decoration: const InputDecoration(
                          labelText: 'Product Nature *',
                          border: OutlineInputBorder(),
                        ),
                        items: _productNatures
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _productNature = value ?? 'Machine';
                            _selectedProductId = '';
                            _selectedProductName = '';
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _service.productsStream(
                          companyId: widget.companyId,
                          productNature: _productNature,
                        ),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];

                          return DropdownButtonFormField<String>(
                            initialValue: _selectedProductId.isEmpty
                                ? null
                                : _selectedProductId,
                            decoration: const InputDecoration(
                              labelText: 'Product *',
                              border: OutlineInputBorder(),
                            ),
                            items: docs.map((doc) {
                              final data = doc.data();
                              final name = _safe(
                                data['productName'] ??
                                    data['name'] ??
                                    data['itemName'] ??
                                    data['model'],
                              );
                              final stock = _toDouble(data['stockOnHand']);

                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(
                                  '$name  |  Stock: ${stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 2)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              final selected = docs
                                  .where((doc) => doc.id == value)
                                  .cast<
                                    QueryDocumentSnapshot<Map<String, dynamic>>
                                  >()
                                  .toList();

                              if (selected.isEmpty) return;

                              final data = selected.first.data();
                              final name = _safe(
                                data['productName'] ??
                                    data['name'] ??
                                    data['itemName'] ??
                                    data['model'],
                              );

                              setState(() {
                                _selectedProductId = selected.first.id;
                                _selectedProductName = name;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select product';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: _warehouseName,
                        decoration: const InputDecoration(
                          labelText: 'Warehouse *',
                          border: OutlineInputBorder(),
                        ),
                        items: _warehouses
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(
                            () => _warehouseName = value ?? 'Main Warehouse',
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity Received *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final qty = double.tryParse(value?.trim() ?? '');
                          if (qty == null || qty <= 0) {
                            return 'Enter valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Supplier / Vendor',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _referenceController,
                        decoration: const InputDecoration(
                          labelText: 'GRN / Purchase Bill / Reference No.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _remarksController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveStockIn,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Stock In',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Stock In History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _service.stockInHistoryStream(
                          companyId: widget.companyId,
                        ),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];

                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              docs.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (docs.isEmpty) {
                            return Center(
                              child: Text(
                                'No stock-in entries yet.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final qty = _toDouble(data['quantity']);
                              final productName = _safe(data['productName']);
                              final nature = _safe(data['productNature']);
                              final warehouse = _safe(data['warehouseName']);
                              final vendor = _safe(data['vendorName']);
                              final ref = _safe(data['referenceNo']);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: const Color(
                                    0xFFFF7A00,
                                  ).withValues(alpha: 0.12),
                                  child: const Icon(
                                    Icons.add_box_outlined,
                                    color: Color(0xFFFF7A00),
                                  ),
                                ),
                                title: Text(
                                  productName.isEmpty
                                      ? 'Unnamed Product'
                                      : productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    nature,
                                    warehouse,
                                    if (vendor.isNotEmpty) vendor,
                                    if (ref.isNotEmpty) ref,
                                  ].where((e) => e.isNotEmpty).join(' • '),
                                ),
                                trailing: Text(
                                  '+${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
