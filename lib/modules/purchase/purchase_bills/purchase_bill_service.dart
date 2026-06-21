import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseVendor {
  const PurchaseVendor({
    required this.id,
    required this.name,
    required this.gstin,
  });

  final String id;
  final String name;
  final String gstin;

  factory PurchaseVendor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PurchaseVendor(
      id: doc.id,
      name: _readString(data, ['vendorName', 'name', 'companyName', 'displayName']),
      gstin: _readString(data, ['gstin', 'GSTIN', 'gstNumber', 'vendorGSTIN']),
    );
  }
}

class PurchaseProduct {
  const PurchaseProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.productNature,
    required this.unit,
    required this.currentStock,
    required this.rate,
  });

  final String id;
  final String code;
  final String name;
  final String productNature;
  final String unit;
  final double currentStock;
  final double rate;

  factory PurchaseProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PurchaseProduct(
      id: doc.id,
      code: _readString(data, ['productCode', 'code', 'sku', 'itemCode']),
      name: _readString(data, ['name', 'productName', 'itemName']),
      productNature: _readString(
        data,
        ['productNature', 'nature', 'productNatureLower'],
        fallback: 'Machine',
      ),
      unit: _readString(data, ['unit', 'uom', 'unitName'], fallback: 'Nos'),
      currentStock: _readDouble(data, ['stockOnHand', 'quantity', 'currentStock', 'qty']),
      rate: _readDouble(data, ['unitPrice', 'purchaseRate', 'rate', 'costPrice']),
    );
  }
}

class PurchaseWarehouse {
  const PurchaseWarehouse({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory PurchaseWarehouse.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PurchaseWarehouse(
      id: doc.id,
      name: _readString(data, ['name', 'warehouseName'], fallback: 'Warehouse'),
    );
  }
}

class PurchaseBillItem {
  PurchaseBillItem({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.productNature,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.gstPercent,
  });

  final String productId;
  final String productCode;
  final String productName;
  final String productNature;
  final String unit;
  final double quantity;
  final double rate;
  final double gstPercent;

  double get taxableAmount => quantity * rate;
  double get gstAmount => taxableAmount * gstPercent / 100;
  double get lineTotal => taxableAmount + gstAmount;

  factory PurchaseBillItem.fromMap(Map<String, dynamic> data) {
    return PurchaseBillItem(
      productId: _readString(data, ['productId']),
      productCode: _readString(data, ['productCode']),
      productName: _readString(data, ['productName']),
      productNature: _readString(data, ['productNature']),
      unit: _readString(data, ['unit'], fallback: 'Nos'),
      quantity: _readDouble(data, ['quantity']),
      rate: _readDouble(data, ['rate']),
      gstPercent: _readDouble(data, ['gstPercent']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productCode': productCode,
      'productName': productName,
      'productNature': productNature,
      'unit': unit,
      'quantity': quantity,
      'rate': rate,
      'gstPercent': gstPercent,
      'lineTotal': lineTotal,
    };
  }
}

class PurchaseBill {
  PurchaseBill({
    required this.id,
    required this.billNumber,
    required this.billDate,
    required this.vendorId,
    required this.vendorName,
    required this.vendorGSTIN,
    required this.vendorInvoiceNumber,
    required this.vendorInvoiceDate,
    required this.warehouseId,
    required this.warehouseName,
    required this.grnId,
    required this.remarks,
    required this.subTotal,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.discount,
    required this.freight,
    required this.otherCharges,
    required this.grandTotal,
    required this.status,
    required this.items,
    required this.stockPosted,
  });

  final String id;
  final String billNumber;
  final DateTime billDate;
  final String vendorId;
  final String vendorName;
  final String vendorGSTIN;
  final String vendorInvoiceNumber;
  final DateTime? vendorInvoiceDate;
  final String warehouseId;
  final String warehouseName;
  final String grnId;
  final String remarks;
  final double subTotal;
  final double cgst;
  final double sgst;
  final double igst;
  final double discount;
  final double freight;
  final double otherCharges;
  final double grandTotal;
  final String status;
  final List<PurchaseBillItem> items;
  final bool stockPosted;

  factory PurchaseBill.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawItems = data['items'];
    return PurchaseBill(
      id: doc.id,
      billNumber: _readString(data, ['billNumber']),
      billDate: _readDate(data['billDate']) ?? DateTime.now(),
      vendorId: _readString(data, ['vendorId']),
      vendorName: _readString(data, ['vendorName']),
      vendorGSTIN: _readString(data, ['vendorGSTIN']),
      vendorInvoiceNumber: _readString(data, ['vendorInvoiceNumber']),
      vendorInvoiceDate: _readDate(data['vendorInvoiceDate']),
      warehouseId: _readString(data, ['warehouseId']),
      warehouseName: _readString(data, ['warehouseName']),
      grnId: _readString(data, ['grnId']),
      remarks: _readString(data, ['remarks']),
      subTotal: _readDouble(data, ['subTotal']),
      cgst: _readDouble(data, ['cgst']),
      sgst: _readDouble(data, ['sgst']),
      igst: _readDouble(data, ['igst']),
      discount: _readDouble(data, ['discount']),
      freight: _readDouble(data, ['freight']),
      otherCharges: _readDouble(data, ['otherCharges']),
      grandTotal: _readDouble(data, ['grandTotal']),
      status: _readString(data, ['status'], fallback: 'Draft'),
      stockPosted: data['stockPosted'] == true,
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => PurchaseBillItem.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }
}

class PurchaseBillTotals {
  const PurchaseBillTotals({
    required this.subTotal,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.discount,
    required this.freight,
    required this.otherCharges,
    required this.grandTotal,
  });

  final double subTotal;
  final double cgst;
  final double sgst;
  final double igst;
  final double discount;
  final double freight;
  final double otherCharges;
  final double grandTotal;
}

class PurchaseBillPayload {
  const PurchaseBillPayload({
    required this.billNumber,
    required this.billDate,
    required this.vendor,
    required this.vendorInvoiceNumber,
    required this.vendorInvoiceDate,
    required this.warehouse,
    required this.grnId,
    required this.remarks,
    required this.totals,
    required this.status,
    required this.items,
  });

  final String billNumber;
  final DateTime billDate;
  final PurchaseVendor vendor;
  final String vendorInvoiceNumber;
  final DateTime? vendorInvoiceDate;
  final PurchaseWarehouse warehouse;
  final String grnId;
  final String remarks;
  final PurchaseBillTotals totals;
  final String status;
  final List<PurchaseBillItem> items;
}

class PurchaseBillService {
  PurchaseBillService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String companyId, String name) {
    return _db.collection('companies').doc(companyId).collection(name);
  }

  Stream<List<PurchaseBill>> watchBills(String companyId) {
    return _col(companyId, 'purchase_bills')
        .orderBy('billDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PurchaseBill.fromDoc).toList());
  }

  Stream<List<PurchaseVendor>> watchVendors(String companyId) {
    return _col(companyId, 'vendors').snapshots().map((snap) {
      final vendors = snap.docs.map(PurchaseVendor.fromDoc).where((v) => v.name.isNotEmpty).toList();
      vendors.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    });
  }

  Stream<List<PurchaseProduct>> watchProducts(String companyId) {
    return _col(companyId, 'products')
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final products = snap.docs.map(PurchaseProduct.fromDoc).where((p) => p.name.isNotEmpty).toList();
      products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return products;
    });
  }

  Stream<List<PurchaseWarehouse>> watchWarehouses(String companyId) {
    return _col(companyId, 'warehouses').snapshots().map((snap) {
      final warehouses = snap.docs.map(PurchaseWarehouse.fromDoc).where((w) => w.name.isNotEmpty).toList();
      warehouses.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return warehouses;
    });
  }

  Future<String> nextBillNumber(String companyId) async {
    final snap = await _col(companyId, 'purchase_bills')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    var next = 1;
    if (snap.docs.isNotEmpty) {
      final number = _readString(snap.docs.first.data(), ['billNumber']);
      final matches = RegExp(r'\d+').allMatches(number).toList();
      if (matches.isNotEmpty) {
        next = (int.tryParse(matches.last.group(0) ?? '') ?? 0) + 1;
      }
    }
    return 'PB-${DateTime.now().year}-${next.toString().padLeft(4, '0')}';
  }

  Future<String> saveBill({
    required String companyId,
    required String userUid,
    required PurchaseBillPayload payload,
    String? billId,
  }) async {
    final ref = billId == null || billId.isEmpty
        ? _col(companyId, 'purchase_bills').doc()
        : _col(companyId, 'purchase_bills').doc(billId);

    final existing = await ref.get();
    final existingStatus = existing.data()?['status']?.toString() ?? 'Draft';
    if (existing.exists && existingStatus == 'Approved' && payload.status != 'Cancelled') {
      throw StateError('Approved bills cannot be edited. Cancel and recreate if a correction is required.');
    }

    final data = _billMap(
      id: ref.id,
      payload: payload,
      userUid: userUid,
      creating: !existing.exists,
    );

    await ref.set(data, SetOptions(merge: true));
    if (payload.status == 'Approved') {
      await approveBill(companyId: companyId, billId: ref.id, userUid: userUid);
    }
    return ref.id;
  }

  Future<void> deleteBill({
    required String companyId,
    required String billId,
  }) async {
    final doc = await _col(companyId, 'purchase_bills').doc(billId).get();
    final bill = PurchaseBill.fromDoc(doc);
    if (bill.stockPosted) {
      throw StateError('Approved purchase bills cannot be deleted. Cancel the bill to reverse stock.');
    }
    await doc.reference.delete();
  }

  Future<void> approveBill({
    required String companyId,
    required String billId,
    required String userUid,
  }) async {
    final billRef = _col(companyId, 'purchase_bills').doc(billId);
    final billDoc = await billRef.get();
    if (!billDoc.exists) return;
    final bill = PurchaseBill.fromDoc(billDoc);
    if (bill.stockPosted) {
      await billRef.update({
        'status': 'Approved',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userUid,
      });
      return;
    }

    final batch = _db.batch();
    for (final item in bill.items) {
      final movementRef = _col(companyId, 'stock_transactions').doc();
      batch.set(movementRef, {
        'transactionType': 'PURCHASE',
        'referenceType': 'PURCHASE_BILL',
        'referenceId': bill.id,
        'productId': item.productId,
        'productName': item.productName,
        'productNature': item.productNature,
        'warehouseId': bill.warehouseId,
        'warehouseName': bill.warehouseName,
        'quantity': item.quantity,
        'stockDirection': 'IN',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userUid,
      });

      batch.set(
        _col(companyId, 'products').doc(item.productId),
        {
          'quantity': FieldValue.increment(item.quantity),
          'stockOnHand': FieldValue.increment(item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userUid,
        },
        SetOptions(merge: true),
      );

      final warehouseStockId = '${bill.warehouseId}_${item.productId}';
      batch.set(
        _col(companyId, 'warehouse_stock').doc(warehouseStockId),
        {
          'warehouseId': bill.warehouseId,
          'warehouseName': bill.warehouseName,
          'productId': item.productId,
          'productCode': item.productCode,
          'productName': item.productName,
          'productNature': item.productNature,
          'unit': item.unit,
          'quantity': FieldValue.increment(item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userUid,
        },
        SetOptions(merge: true),
      );
    }
    batch.update(billRef, {
      'status': 'Approved',
      'stockPosted': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    });
    await batch.commit();
  }

  Future<void> cancelBill({
    required String companyId,
    required String billId,
    required String userUid,
  }) async {
    final billRef = _col(companyId, 'purchase_bills').doc(billId);
    final billDoc = await billRef.get();
    if (!billDoc.exists) return;
    final bill = PurchaseBill.fromDoc(billDoc);
    final batch = _db.batch();
    if (bill.stockPosted) {
      for (final item in bill.items) {
        final movementRef = _col(companyId, 'stock_transactions').doc();
        batch.set(movementRef, {
          'transactionType': 'PURCHASE',
          'referenceType': 'PURCHASE_BILL',
          'referenceId': bill.id,
          'productId': item.productId,
          'productName': item.productName,
          'productNature': item.productNature,
          'warehouseId': bill.warehouseId,
          'warehouseName': bill.warehouseName,
          'quantity': item.quantity,
          'stockDirection': 'OUT',
          'isReversal': true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userUid,
        });
        batch.set(
          _col(companyId, 'products').doc(item.productId),
          {
            'quantity': FieldValue.increment(-item.quantity),
            'stockOnHand': FieldValue.increment(-item.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': userUid,
          },
          SetOptions(merge: true),
        );
        batch.set(
          _col(companyId, 'warehouse_stock').doc('${bill.warehouseId}_${item.productId}'),
          {
            'warehouseId': bill.warehouseId,
            'warehouseName': bill.warehouseName,
            'productId': item.productId,
            'productCode': item.productCode,
            'productName': item.productName,
            'productNature': item.productNature,
            'unit': item.unit,
            'quantity': FieldValue.increment(-item.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': userUid,
          },
          SetOptions(merge: true),
        );
      }
    }
    batch.update(billRef, {
      'status': 'Cancelled',
      'stockPosted': false,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    });
    await batch.commit();
  }

  Map<String, dynamic> _billMap({
    required String id,
    required PurchaseBillPayload payload,
    required String userUid,
    required bool creating,
  }) {
    return {
      'id': id,
      'billNumber': payload.billNumber.trim(),
      'billDate': Timestamp.fromDate(payload.billDate),
      'vendorId': payload.vendor.id,
      'vendorName': payload.vendor.name,
      'vendorGSTIN': payload.vendor.gstin,
      'vendorInvoiceNumber': payload.vendorInvoiceNumber.trim(),
      'vendorInvoiceDate': payload.vendorInvoiceDate == null
          ? null
          : Timestamp.fromDate(payload.vendorInvoiceDate!),
      'warehouseId': payload.warehouse.id,
      'warehouseName': payload.warehouse.name,
      'grnId': payload.grnId.trim(),
      'remarks': payload.remarks.trim(),
      'subTotal': payload.totals.subTotal,
      'cgst': payload.totals.cgst,
      'sgst': payload.totals.sgst,
      'igst': payload.totals.igst,
      'discount': payload.totals.discount,
      'freight': payload.totals.freight,
      'otherCharges': payload.totals.otherCharges,
      'grandTotal': payload.totals.grandTotal,
      'status': payload.status,
      'items': payload.items.map((item) => item.toMap()).toList(),
      if (creating) 'stockPosted': false,
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
      if (creating) 'createdBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    };
  }
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return fallback;
}

double _readDouble(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

