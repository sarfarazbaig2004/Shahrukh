import 'package:cloud_firestore/cloud_firestore.dart';

const inventoryProductNatures = <String>[
  'Machine',
  'Spare Part',
  'Accessory',
  'Raw Material',
  'Consumable',
  'PCB',
  'Transformer',
  'Electrical Component',
  'Mechanical Component',
  'Service Spare',
];

const stockOutPurposes = <String>[
  'Production',
  'Service',
  'Sales',
  'Internal Use',
  'Sample',
  'Scrap',
];

class WarehouseRecord {
  WarehouseRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.location,
    required this.address,
    required this.contactPerson,
    required this.mobileNumber,
    required this.email,
    required this.status,
  });

  final String id;
  final String code;
  final String name;
  final String location;
  final String address;
  final String contactPerson;
  final String mobileNumber;
  final String email;
  final String status;

  factory WarehouseRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WarehouseRecord(
      id: doc.id,
      code: _readString(data, 'code'),
      name: _readString(data, 'name'),
      location: _readString(data, 'location'),
      address: _readString(data, 'address'),
      contactPerson: _readString(data, 'contactPerson'),
      mobileNumber: _readString(data, 'mobileNumber'),
      email: _readString(data, 'email'),
      status: _readString(data, 'status', fallback: 'Active'),
    );
  }

  Map<String, dynamic> toMap({required String userUid}) {
    return {
      'code': code.trim(),
      'name': name.trim(),
      'location': location.trim(),
      'address': address.trim(),
      'contactPerson': contactPerson.trim(),
      'mobileNumber': mobileNumber.trim(),
      'email': email.trim(),
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    };
  }
}

class StockItem {
  StockItem({
    required this.productId,
    required this.productName,
    required this.productNature,
    required this.quantity,
    this.rate = 0,
  });

  final String productId;
  final String productName;
  final String productNature;
  final double quantity;
  final double rate;

  double get amount => quantity * rate;

  Map<String, dynamic> toStockInMap() {
    return {
      'productId': productId,
      'productName': productName.trim(),
      'productNature': productNature,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
    };
  }

  Map<String, dynamic> toStockOutMap({required double availableQty}) {
    return {
      'productId': productId,
      'productName': productName.trim(),
      'productNature': productNature,
      'availableQty': availableQty,
      'issueQty': quantity,
    };
  }
}

class InventoryProduct {
  InventoryProduct({
    required this.id,
    required this.name,
    required this.productNature,
    required this.rate,
  });

  final String id;
  final String name;
  final String productNature;
  final double rate;

  factory InventoryProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return InventoryProduct(
      id: doc.id,
      name: _readString(data, 'name'),
      productNature: _normalizeNature(
        _readString(
          data,
          'productNature',
          fallback: _readString(data, 'nature', fallback: _readString(data, 'productNatureLower')),
        ),
      ),
      rate: _readDouble(data, 'unitPrice'),
    );
  }
}

class StockSummaryRow {
  StockSummaryRow({
    required this.productId,
    required this.productName,
    required this.productNature,
    required this.warehouseId,
    required this.warehouseName,
    required this.stockInQty,
    required this.stockOutQty,
  });

  final String productId;
  final String productName;
  final String productNature;
  final String warehouseId;
  final String warehouseName;
  final double stockInQty;
  final double stockOutQty;

  double get availableQty => stockInQty - stockOutQty;
}

class InventoryService {
  InventoryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(
    String companyId,
    String name,
  ) {
    return _db.collection('companies').doc(companyId).collection(name);
  }

  Stream<List<WarehouseRecord>> warehousesStream(String companyId) {
    return _collection(companyId, 'warehouses')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(WarehouseRecord.fromDoc).toList());
  }

  Stream<List<InventoryProduct>> productsStream(String companyId) {
    return _collection(companyId, 'products')
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final products = snap.docs.map(InventoryProduct.fromDoc).where((p) => p.name.isNotEmpty).toList();
      products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return products;
    });
  }

  Future<List<InventoryProduct>> loadProducts(String companyId) async {
    final snap = await _collection(companyId, 'products')
        .where('isDeleted', isEqualTo: false)
        .get();
    final products = snap.docs.map(InventoryProduct.fromDoc).where((p) => p.name.isNotEmpty).toList();
    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return products;
  }

  Future<void> saveWarehouse({
    required String companyId,
    required WarehouseRecord warehouse,
    required String userUid,
  }) async {
    final data = warehouse.toMap(userUid: userUid);
    if (warehouse.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['createdBy'] = userUid;
      await _collection(companyId, 'warehouses').add(data);
    } else {
      await _collection(companyId, 'warehouses').doc(warehouse.id).update(data);
    }
  }

  Future<void> deleteWarehouse(String companyId, String warehouseId) {
    return _collection(companyId, 'warehouses').doc(warehouseId).delete();
  }

  Future<String> nextNumber(String companyId, String collection, String prefix) async {
    final snap = await _collection(companyId, collection)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    var next = 1;
    if (snap.docs.isNotEmpty) {
      final current = _readString(snap.docs.first.data(), collection == 'stock_in' ? 'stockInNo' : 'stockOutNo');
      final matches = RegExp(r'\d+').allMatches(current).toList();
      final digits = matches.isEmpty ? null : matches.last.group(0);
      next = (int.tryParse(digits ?? '') ?? 0) + 1;
    }
    return '$prefix-${DateTime.now().year}-${next.toString().padLeft(4, '0')}';
  }

  Future<void> saveStockIn({
    required String companyId,
    required String stockInNo,
    required DateTime date,
    required WarehouseRecord warehouse,
    required String supplier,
    required String invoiceNo,
    required String remarks,
    required List<StockItem> items,
    required String userUid,
  }) async {
    await _collection(companyId, 'stock_in').add({
      'stockInNo': stockInNo.trim(),
      'date': Timestamp.fromDate(date),
      'warehouseId': warehouse.id,
      'warehouseName': warehouse.name,
      'supplier': supplier.trim(),
      'invoiceNo': invoiceNo.trim(),
      'remarks': remarks.trim(),
      'items': items.map((item) => item.toStockInMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userUid,
    });
  }

  Future<void> saveStockOut({
    required String companyId,
    required String stockOutNo,
    required DateTime date,
    required WarehouseRecord warehouse,
    required String department,
    required String issuedTo,
    required String purpose,
    required String remarks,
    required List<StockItem> items,
    required Map<String, double> availableByKey,
    required String userUid,
  }) async {
    final latest = await loadSummary(companyId);
    final latestAvailable = {
      for (final row in latest) summaryKey(row.productId, row.productName, row.productNature, row.warehouseId): row.availableQty,
    };
    for (final item in items) {
      final key = summaryKey(item.productId, item.productName, item.productNature, warehouse.id);
      final available = latestAvailable[key] ?? 0;
      if (item.quantity > available) {
        throw StateError('${item.productName} has only ${formatQty(available)} available.');
      }
    }

    await _collection(companyId, 'stock_out').add({
      'stockOutNo': stockOutNo.trim(),
      'date': Timestamp.fromDate(date),
      'warehouseId': warehouse.id,
      'warehouseName': warehouse.name,
      'department': department.trim(),
      'issuedTo': issuedTo.trim(),
      'purpose': purpose,
      'remarks': remarks.trim(),
      'items': items.map((item) {
        final key = summaryKey(item.productId, item.productName, item.productNature, warehouse.id);
        return item.toStockOutMap(availableQty: availableByKey[key] ?? latestAvailable[key] ?? 0);
      }).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userUid,
    });
  }

  Future<List<StockSummaryRow>> loadSummary(String companyId) async {
    final products = await loadProducts(companyId);
    final stockInSnap = await _collection(companyId, 'stock_in').get();
    final stockOutSnap = await _collection(companyId, 'stock_out').get();
    final rows = <String, _SummaryAccumulator>{};

    for (final doc in stockInSnap.docs) {
      final data = doc.data();
      final warehouseId = _readString(data, 'warehouseId');
      final warehouseName = _readString(data, 'warehouseName');
      for (final item in _readItems(data)) {
        final productId = _readString(item, 'productId');
        final productName = _readString(item, 'productName');
        final nature = _readString(item, 'productNature');
        if (productName.isEmpty || nature.isEmpty || warehouseId.isEmpty) continue;
        final key = summaryKey(productId, productName, nature, warehouseId);
        rows.putIfAbsent(
          key,
          () => _SummaryAccumulator(productId, productName, nature, warehouseId, warehouseName),
        ).stockInQty += _readDouble(item, 'quantity');
      }
    }

    for (final doc in stockOutSnap.docs) {
      final data = doc.data();
      final warehouseId = _readString(data, 'warehouseId');
      final warehouseName = _readString(data, 'warehouseName');
      for (final item in _readItems(data)) {
        final productId = _readString(item, 'productId');
        final productName = _readString(item, 'productName');
        final nature = _readString(item, 'productNature');
        if (productName.isEmpty || nature.isEmpty || warehouseId.isEmpty) continue;
        final key = summaryKey(productId, productName, nature, warehouseId);
        rows.putIfAbsent(
          key,
          () => _SummaryAccumulator(productId, productName, nature, warehouseId, warehouseName),
        ).stockOutQty += _readDouble(item, 'issueQty');
      }
    }

    for (final product in products) {
      final key = summaryKey(product.id, product.name, product.productNature, '');
      rows.putIfAbsent(
        key,
        () => _SummaryAccumulator(product.id, product.name, product.productNature, '', '-'),
      );
    }

    final result = rows.values
        .map(
          (row) => StockSummaryRow(
            productId: row.productId,
            productName: row.productName,
            productNature: row.productNature,
            warehouseId: row.warehouseId,
            warehouseName: row.warehouseName,
            stockInQty: row.stockInQty,
            stockOutQty: row.stockOutQty,
          ),
        )
        .toList();
    result.sort((a, b) {
      final byProduct = a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
      return byProduct != 0 ? byProduct : a.warehouseName.compareTo(b.warehouseName);
    });
    return result;
  }
}

class _SummaryAccumulator {
  _SummaryAccumulator(
    this.productId,
    this.productName,
    this.productNature,
    this.warehouseId,
    this.warehouseName,
  );

  final String productId;
  final String productName;
  final String productNature;
  final String warehouseId;
  final String warehouseName;
  double stockInQty = 0;
  double stockOutQty = 0;
}

String summaryKey(String productId, String productName, String productNature, String warehouseId) {
  final productPart = productId.trim().isNotEmpty ? productId.trim() : productName.trim().toLowerCase();
  return '$productPart|${productNature.trim().toLowerCase()}|$warehouseId';
}

String formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _readString(Map<String, dynamic> data, String key, {String fallback = ''}) {
  final value = data[key];
  return value == null ? fallback : value.toString();
}

double _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _readItems(Map<String, dynamic> data) {
  final raw = data['items'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

String _normalizeNature(String value) {
  final lower = value.trim().toLowerCase();
  if (lower == 'spare') return 'Spare Part';
  for (final nature in inventoryProductNatures) {
    if (nature.toLowerCase() == lower) return nature;
  }
  if (value.trim().isEmpty) return inventoryProductNatures.first;
  return value.trim();
}
