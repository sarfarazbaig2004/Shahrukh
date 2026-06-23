import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReadyForDispatchScreen extends StatefulWidget {
  final String companyId;
  final String userUid;

  const ReadyForDispatchScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  @override
  State<ReadyForDispatchScreen> createState() => _ReadyForDispatchScreenState();
}

class _ReadyForDispatchScreenState extends State<ReadyForDispatchScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _dispatching = false;
  String _search = '';
  List<_ReadySalesOrder> _orders = [];

  CollectionReference<Map<String, dynamic>> get _salesOrdersRef => _db
      .collection('companies')
      .doc(widget.companyId)
      .collection('sales_orders');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _db.collection('companies').doc(widget.companyId).collection('products');

  CollectionReference<Map<String, dynamic>> get _stockOutRef =>
      _db.collection('companies').doc(widget.companyId).collection('stock_out');

  @override
  void initState() {
    super.initState();
    _loadReadyOrders();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  String _str(dynamic value) => (value ?? '').toString().trim();

  String _orderNo(Map<String, dynamic> data) {
    return _str(
      data['salesOrderNumberDisplay'] ??
          data['salesOrderNumber'] ??
          data['soNumber'] ??
          data['orderNumber'],
    );
  }

  String _customerName(Map<String, dynamic> data) {
    return _str(
      data['customerName'] ??
          data['customer'] ??
          data['clientName'] ??
          data['partyName'],
    );
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  bool _isAlreadyDispatched(Map<String, dynamic> data) {
    final dispatchStatus = _str(data['dispatchStatus']).toLowerCase();
    final status = _str(data['status']).toLowerCase();

    return dispatchStatus == 'shipped' ||
        dispatchStatus == 'delivered' ||
        dispatchStatus == 'dispatched' ||
        status == 'shipped' ||
        status == 'delivered' ||
        status == 'dispatched';
  }

  List<Map<String, dynamic>> _rawItems(Map<String, dynamic> data) {
    final raw = data['items'] ?? data['products'] ?? data['lineItems'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, _ProductStock>> _loadProductStockMap() async {
    final snap = await _productsRef.get();
    final map = <String, _ProductStock>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final name = _str(
        data['name'] ??
            data['productName'] ??
            data['itemName'] ??
            data['description'],
      );
      final sku = _str(data['sku'] ?? data['productCode'] ?? data['code']);
      final stock = _toDouble(
        data['stockOnHand'] ??
            data['availableStock'] ??
            data['stockQuantity'] ??
            data['qty'] ??
            data['stock'],
      );

      final product = _ProductStock(
        productId: doc.id,
        productName: name,
        sku: sku,
        stockOnHand: stock,
      );

      map[doc.id] = product;
      if (name.isNotEmpty) map[name.toLowerCase()] = product;
      if (sku.isNotEmpty) map[sku.toLowerCase()] = product;
    }

    return map;
  }

  _ProductStock? _matchProduct(
    Map<String, _ProductStock> stockMap,
    Map<String, dynamic> item,
  ) {
    final productId = _str(item['productId'] ?? item['itemId']);
    final productName = _str(
      item['productName'] ??
          item['name'] ??
          item['itemName'] ??
          item['description'],
    );
    final sku = _str(item['sku'] ?? item['productCode'] ?? item['code']);

    if (productId.isNotEmpty && stockMap.containsKey(productId)) {
      return stockMap[productId];
    }
    if (sku.isNotEmpty && stockMap.containsKey(sku.toLowerCase())) {
      return stockMap[sku.toLowerCase()];
    }
    if (productName.isNotEmpty &&
        stockMap.containsKey(productName.toLowerCase())) {
      return stockMap[productName.toLowerCase()];
    }

    return null;
  }

  Future<void> _loadReadyOrders() async {
    setState(() => _loading = true);

    try {
      final productStockMap = await _loadProductStockMap();
      final salesSnap = await _salesOrdersRef.get();

      final list = <_ReadySalesOrder>[];

      for (final doc in salesSnap.docs) {
        final data = doc.data();
        if (_isAlreadyDispatched(data)) continue;

        final items = <_ReadyLine>[];
        for (final rawItem in _rawItems(data)) {
          final qty = _toDouble(
            rawItem['quantity'] ??
                rawItem['qty'] ??
                rawItem['orderQty'] ??
                rawItem['orderedQty'],
          );
          if (qty <= 0) continue;

          final itemName = _str(
            rawItem['productName'] ??
                rawItem['name'] ??
                rawItem['itemName'] ??
                rawItem['description'],
          );
          final rawProductId = _str(rawItem['productId'] ?? rawItem['itemId']);
          final matchedProduct = _matchProduct(productStockMap, rawItem);
          final available = matchedProduct?.stockOnHand ?? 0;

          items.add(
            _ReadyLine(
              productId: matchedProduct?.productId ?? rawProductId,
              productName: matchedProduct?.productName.isNotEmpty == true
                  ? matchedProduct!.productName
                  : itemName,
              orderedQty: qty,
              availableQty: available,
            ),
          );
        }

        if (items.isEmpty) continue;

        final ready = items.every(
          (line) => line.availableQty >= line.orderedQty,
        );

        list.add(
          _ReadySalesOrder(
            id: doc.id,
            ref: doc.reference,
            orderNo: _orderNo(data).isEmpty ? doc.id : _orderNo(data),
            customerName: _customerName(data),
            orderDate: _date(
              data['orderDate'] ?? data['createdAt'] ?? data['date'],
            ),
            dispatchStatus: _str(data['dispatchStatus']).isEmpty
                ? 'Pending'
                : _str(data['dispatchStatus']),
            items: items,
            isReady: ready,
          ),
        );
      }

      list.sort((a, b) {
        if (a.isReady != b.isReady) return a.isReady ? -1 : 1;
        return (b.orderDate ?? DateTime(1900)).compareTo(
          a.orderDate ?? DateTime(1900),
        );
      });

      if (mounted) {
        setState(() {
          _orders = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _message('Failed to load ready dispatch: $e');
      }
    }
  }

  String _nextStockOutNo() {
    final now = DateTime.now();
    return 'SOUT-${DateFormat('yyyyMMdd-HHmmss').format(now)}';
  }

  Future<void> _dispatchSalesOrder(_ReadySalesOrder order) async {
    if (!order.isReady) {
      _message('Stock shortage. This sales order is not ready for dispatch.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dispatch ${order.orderNo}?'),
        content: const Text(
          'This will create Stock Out and reduce product stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Dispatch / Stock Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _dispatching = true);

    try {
      final stockOutNo = _nextStockOutNo();
      final batch = _db.batch();
      final stockOutDoc = _stockOutRef.doc();

      batch.set(stockOutDoc, {
        'stockOutNo': stockOutNo,
        'date': Timestamp.fromDate(DateTime.now()),
        'purpose': 'Sales Dispatch',
        'department': 'Dispatch',
        'issuedTo': order.customerName,
        'salesOrderId': order.id,
        'salesOrderNumber': order.orderNo,
        'createdByUid': widget.userUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'items': order.items.map((line) {
          return {
            'productId': line.productId,
            'productName': line.productName,
            'productNature': 'Finished Goods',
            'quantity': line.orderedQty,
            'issueQty': line.orderedQty,
            'availableQty': line.availableQty,
            'warehouseId': '',
            'warehouseName': '',
          };
        }).toList(),
      });

      for (final line in order.items) {
        if (line.productId.isEmpty) continue;
        batch.update(_productsRef.doc(line.productId), {
          'stockOnHand': FieldValue.increment(-line.orderedQty),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.update(order.ref, {
        'dispatchStatus': 'Shipped',
        'status': 'Shipped',
        'stockOutNo': stockOutNo,
        'dispatchedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _message('Dispatched and stock reduced: $stockOutNo');
      await _loadReadyOrders();
    } catch (e) {
      _message('Dispatch failed: $e');
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<_ReadySalesOrder> get _filteredOrders {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _orders;

    return _orders.where((order) {
      final text = [
        order.orderNo,
        order.customerName,
        order.dispatchStatus,
        ...order.items.map((e) => e.productName),
      ].join(' ').toLowerCase();

      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final readyCount = _orders.where((e) => e.isReady).length;
    final shortageCount = _orders.where((e) => !e.isReady).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ready for Dispatch',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _loadReadyOrders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: const InputDecoration(
                        labelText: 'Search sales order / product',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _SummaryPill(label: 'Orders', value: _orders.length),
                  _SummaryPill(label: 'Ready', value: readyCount),
                  _SummaryPill(label: 'Shortage', value: shortageCount),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No pending sales orders found for dispatch.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        return _ReadyOrderCard(
                          order: order,
                          dispatching: _dispatching,
                          onDispatch: () => _dispatchSalesOrder(order),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyOrderCard extends StatelessWidget {
  final _ReadySalesOrder order;
  final bool dispatching;
  final VoidCallback onDispatch;

  const _ReadyOrderCard({
    required this.order,
    required this.dispatching,
    required this.onDispatch,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = order.orderDate == null
        ? 'No date'
        : DateFormat('dd/MM/yyyy').format(order.orderDate!);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(
                  label: order.isReady ? 'READY' : 'SHORTAGE',
                  color: order.isReady
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.orderNo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: order.isReady && !dispatching ? onDispatch : null,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Dispatch / Stock Out'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (order.customerName.isNotEmpty) order.customerName,
                'Date: $dateText',
                'Status: ${order.dispatchStatus}',
              ].join('  •  '),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ...order.items.map((line) => _ReadyLineRow(line: line)),
          ],
        ),
      ),
    );
  }
}

class _ReadyLineRow extends StatelessWidget {
  final _ReadyLine line;

  const _ReadyLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final ok = line.availableQty >= line.orderedQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.productName.isEmpty ? 'Unnamed Product' : line.productName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            'SO Qty: ${_fmt(line.orderedQty)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 14),
          Text(
            'Stock: ${_fmt(line.availableQty)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: ok ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(width: 14),
          _Badge(
            label: ok ? 'Available' : 'Short ${_fmt(line.shortage)}',
            color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int value;

  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      label: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProductStock {
  final String productId;
  final String productName;
  final String sku;
  final double stockOnHand;

  const _ProductStock({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.stockOnHand,
  });
}

class _ReadySalesOrder {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String orderNo;
  final String customerName;
  final DateTime? orderDate;
  final String dispatchStatus;
  final List<_ReadyLine> items;
  final bool isReady;

  const _ReadySalesOrder({
    required this.id,
    required this.ref,
    required this.orderNo,
    required this.customerName,
    required this.orderDate,
    required this.dispatchStatus,
    required this.items,
    required this.isReady,
  });
}

class _ReadyLine {
  final String productId;
  final String productName;
  final double orderedQty;
  final double availableQty;

  const _ReadyLine({
    required this.productId,
    required this.productName,
    required this.orderedQty,
    required this.availableQty,
  });

  double get shortage =>
      availableQty >= orderedQty ? 0 : orderedQty - availableQty;
}
