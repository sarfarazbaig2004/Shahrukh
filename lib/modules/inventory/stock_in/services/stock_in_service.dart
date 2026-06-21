import 'package:cloud_firestore/cloud_firestore.dart';

class StockInService {
  StockInService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _stockMovements =>
      _firestore.collection('stock_movements');

  Stream<QuerySnapshot<Map<String, dynamic>>> productsStream({
    required String companyId,
    String? productNature,
  }) {
    Query<Map<String, dynamic>> query = _products;

    if (companyId.trim().isNotEmpty) {
      query = query.where('companyId', isEqualTo: companyId);
    }

    if (productNature != null &&
        productNature.trim().isNotEmpty &&
        productNature != 'All') {
      query = query.where(
        'productNatureLower',
        isEqualTo: productNature.trim().toLowerCase(),
      );
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> stockInHistoryStream({
    required String companyId,
  }) {
    Query<Map<String, dynamic>> query = _stockMovements
        .where('movementType', isEqualTo: 'stock_in')
        .orderBy('createdAt', descending: true)
        .limit(100);

    if (companyId.trim().isNotEmpty) {
      query = _stockMovements
          .where('companyId', isEqualTo: companyId)
          .where('movementType', isEqualTo: 'stock_in')
          .orderBy('createdAt', descending: true)
          .limit(100);
    }

    return query.snapshots();
  }

  Future<void> saveStockIn({
    required String companyId,
    required String userUid,
    required String productId,
    required String productName,
    required String productNature,
    required String warehouseName,
    required double quantity,
    String vendorName = '',
    String referenceNo = '',
    String remarks = '',
  }) async {
    if (productId.trim().isEmpty) {
      throw Exception('Please select a product.');
    }

    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }

    final productRef = _products.doc(productId);
    final movementRef = _stockMovements.doc();

    await _firestore.runTransaction((transaction) async {
      final productSnap = await transaction.get(productRef);
      if (!productSnap.exists) {
        throw Exception('Selected product not found.');
      }

      final data = productSnap.data() ?? <String, dynamic>{};
      final currentStock = _toDouble(data['stockOnHand']);
      final newStock = currentStock + quantity;
      final now = FieldValue.serverTimestamp();

      transaction.update(productRef, {
        'stockOnHand': newStock,
        'lastStockInAt': now,
        'updatedAt': now,
      });

      transaction.set(movementRef, {
        'companyId': companyId,
        'movementType': 'stock_in',
        'productId': productId,
        'productName': productName,
        'productNature': productNature,
        'productNatureLower': productNature.toLowerCase(),
        'warehouseName': warehouseName,
        'quantity': quantity,
        'stockBefore': currentStock,
        'stockAfter': newStock,
        'vendorName': vendorName.trim(),
        'referenceNo': referenceNo.trim(),
        'remarks': remarks.trim(),
        'createdBy': userUid,
        'createdAt': now,
      });
    });
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
