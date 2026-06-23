import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/inventory/inventory_service.dart';

class DispatchService {
  DispatchService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final InventoryService _inventory = InventoryService();

  CollectionReference<Map<String, dynamic>> _salesOrders(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('sales_orders');
  }

  CollectionReference<Map<String, dynamic>> _dispatchChallans(
    String companyId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('dispatch_challans');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> salesOrdersStream({
    required String companyId,
  }) {
    return _salesOrders(
      companyId,
    ).orderBy('createdAt', descending: true).limit(150).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> challansStream({
    required String companyId,
  }) {
    return _dispatchChallans(
      companyId,
    ).orderBy('createdAt', descending: true).limit(200).snapshots();
  }

  Future<List<WarehouseRecord>> loadWarehouses({
    required String companyId,
  }) async {
    final snap = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('warehouses')
        .orderBy('name')
        .get();

    final rows = snap.docs
        .map(WarehouseRecord.fromDoc)
        .where((w) => w.name.trim().isNotEmpty)
        .where((w) => w.status.toLowerCase() != 'inactive')
        .toList();

    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  Future<String> createDispatchChallan({
    required String companyId,
    required String salesOrderId,
    required String createdBy,
    required String warehouseId,
    required String warehouseName,
    required String transporterName,
    required String vehicleNumber,
    required String lrNumber,
    required String packingDetails,
    required String remarks,
  }) async {
    if (warehouseId.trim().isEmpty) {
      throw StateError('Please select a warehouse.');
    }

    final soRef = _salesOrders(companyId).doc(salesOrderId);
    final challanRef = _dispatchChallans(companyId).doc();
    final challanNo = _generateChallanNumber();

    await _firestore.runTransaction((transaction) async {
      final soSnap = await transaction.get(soRef);
      if (!soSnap.exists) {
        throw StateError('Sales Order not found.');
      }

      final soData = soSnap.data() ?? {};
      final dispatchStatus = _text(soData['dispatchStatus']).toLowerCase();

      if (dispatchStatus == 'packed' ||
          dispatchStatus == 'shipped' ||
          dispatchStatus == 'in_transit' ||
          dispatchStatus == 'delivered' ||
          dispatchStatus == 'challan_created') {
        throw StateError('Dispatch challan already exists for this order.');
      }

      final items = _readList(soData['items'] ?? soData['products']);

      transaction.set(challanRef, {
        'companyId': companyId,
        'dispatchChallanNumber': challanNo,
        'salesOrderId': salesOrderId,
        'salesOrderNumber':
            soData['salesOrderNumber'] ??
            soData['soNumber'] ??
            soData['orderNumber'] ??
            '',
        'customerId': soData['customerId'] ?? '',
        'customerName':
            soData['customerName'] ??
            soData['clientName'] ??
            soData['partyName'] ??
            '',
        'grandTotal': _toDouble(
          soData['grandTotal'] ?? soData['totalAmount'] ?? soData['amount'],
        ),
        'items': items,
        'warehouseId': warehouseId.trim(),
        'warehouseName': warehouseName.trim(),
        'transporterName': transporterName.trim(),
        'vehicleNumber': vehicleNumber.trim().toUpperCase(),
        'lrNumber': lrNumber.trim(),
        'packingDetails': packingDetails.trim(),
        'remarks': remarks.trim(),
        'stockOutCreated': false,
        'stockOutNo': '',
        'status': 'packed',
        'statusLabel': 'Packed / Challan Created',
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(soRef, {
        'dispatchStatus': 'packed',
        'dispatchChallanId': challanRef.id,
        'dispatchChallanNumber': challanNo,
        'warehouseId': warehouseId.trim(),
        'warehouseName': warehouseName.trim(),
        'transporterName': transporterName.trim(),
        'vehicleNumber': vehicleNumber.trim().toUpperCase(),
        'lrNumber': lrNumber.trim(),
        'dispatchUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return challanNo;
  }

  Future<void> updateShipment({
    required String companyId,
    required String challanId,
    required String transporterName,
    required String vehicleNumber,
    required String lrNumber,
    required String trackingRemarks,
    required String userUid,
  }) async {
    final challanRef = _dispatchChallans(companyId).doc(challanId);
    final challanSnap = await challanRef.get();

    if (!challanSnap.exists) {
      throw StateError('Dispatch challan not found.');
    }

    final data = challanSnap.data() ?? {};
    final salesOrderId = _text(data['salesOrderId']);
    final customerName = _text(data['customerName'], fallback: 'Customer');
    final challanNo = _text(data['dispatchChallanNumber']);
    final warehouseId = _text(data['warehouseId']);
    final warehouseName = _text(data['warehouseName'], fallback: 'Warehouse');
    final alreadyStockOut =
        data['stockOutCreated'] == true ||
        _text(data['stockOutNo']).trim().isNotEmpty;

    String stockOutNo = _text(data['stockOutNo']);

    if (!alreadyStockOut) {
      final stockItems = _dispatchItemsToStockItems(data);

      if (stockItems.isNotEmpty) {
        if (warehouseId.isEmpty) {
          throw StateError('Warehouse is missing in dispatch challan.');
        }

        stockOutNo = await _inventory.nextNumber(
          companyId,
          'stock_out',
          'SOUT',
        );

        await _inventory.saveStockOut(
          companyId: companyId,
          stockOutNo: stockOutNo,
          date: DateTime.now(),
          warehouse: WarehouseRecord(
            id: warehouseId,
            code: '',
            name: warehouseName,
            location: '',
            address: '',
            contactPerson: '',
            mobileNumber: '',
            email: '',
            status: 'Active',
          ),
          department: 'Dispatch',
          issuedTo: customerName,
          purpose: 'Sales',
          remarks:
              'Auto stock out against dispatch challan $challanNo. '
              '${trackingRemarks.trim()}',
          items: stockItems,
          availableByKey: const {},
          userUid: userUid,
        );
      }
    }

    final batch = _firestore.batch();

    batch.set(challanRef, {
      'transporterName': transporterName.trim(),
      'vehicleNumber': vehicleNumber.trim().toUpperCase(),
      'lrNumber': lrNumber.trim(),
      'trackingRemarks': trackingRemarks.trim(),
      'stockOutCreated': true,
      'stockOutNo': stockOutNo,
      'status': 'in_transit',
      'statusLabel': 'In Transit',
      'shippedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (salesOrderId.isNotEmpty) {
      batch.set(_salesOrders(companyId).doc(salesOrderId), {
        'dispatchStatus': 'shipped',
        'transporterName': transporterName.trim(),
        'vehicleNumber': vehicleNumber.trim().toUpperCase(),
        'lrNumber': lrNumber.trim(),
        'stockOutNo': stockOutNo,
        'dispatchUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> markDelivered({
    required String companyId,
    required String challanId,
    required String deliveredTo,
    required String podRemarks,
  }) async {
    final challanRef = _dispatchChallans(companyId).doc(challanId);
    final challanSnap = await challanRef.get();

    if (!challanSnap.exists) {
      throw StateError('Dispatch challan not found.');
    }

    final data = challanSnap.data() ?? {};
    final salesOrderId = _text(data['salesOrderId']);

    final batch = _firestore.batch();

    batch.set(challanRef, {
      'status': 'delivered',
      'statusLabel': 'Delivered',
      'deliveredTo': deliveredTo.trim(),
      'podRemarks': podRemarks.trim(),
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (salesOrderId.isNotEmpty) {
      batch.set(_salesOrders(companyId).doc(salesOrderId), {
        'dispatchStatus': 'delivered',
        'status': 'completed',
        'deliveredAt': FieldValue.serverTimestamp(),
        'dispatchUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  List<StockItem> _dispatchItemsToStockItems(Map<String, dynamic> data) {
    final rawItems = _readList(data['items']);
    final rows = <StockItem>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);

      final productId = _text(
        item['productId'] ?? item['id'] ?? item['productDocId'],
      );
      final productName = _text(
        item['productName'] ?? item['name'] ?? item['itemName'],
      );
      final productNature = _normalizeNature(
        _text(
          item['productNature'] ??
              item['nature'] ??
              item['productNatureLower'] ??
              item['category'],
          fallback: 'Machine',
        ),
      );
      final quantity = _toDouble(
        item['quantity'] ?? item['qty'] ?? item['orderQty'],
      );
      final rate = _toDouble(
        item['rate'] ?? item['unitPrice'] ?? item['price'],
      );

      if (productId.isEmpty || productName.isEmpty || quantity <= 0) continue;

      rows.add(
        StockItem(
          productId: productId,
          productName: productName,
          productNature: productNature,
          quantity: quantity,
          rate: rate,
        ),
      );
    }

    return rows;
  }

  String _generateChallanNumber() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'DC-$date-$time';
  }

  List<dynamic> _readList(Object? value) {
    if (value is List) return value;
    return const [];
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _normalizeNature(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return 'Machine';

    final lower = cleaned.toLowerCase();
    for (final nature in inventoryProductNatures) {
      if (nature.toLowerCase() == lower) return nature;
    }

    if (lower == 'spare' || lower == 'spares') return 'Spare Part';
    if (lower == 'rawmaterial' || lower == 'raw material') {
      return 'Raw Material';
    }

    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}
