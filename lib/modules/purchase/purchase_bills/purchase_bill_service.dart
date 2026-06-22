import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../inventory/inventory_service.dart';
import '../vendors/models/vendor_model.dart';
import 'purchase_bill_model.dart';

class PurchaseBillService {
  PurchaseBillService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _bills(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('purchase_bills');
  }

  CollectionReference<Map<String, dynamic>> _companyCollection(
    String companyId,
    String collection,
  ) {
    return _db.collection('companies').doc(companyId).collection(collection);
  }

  Stream<List<PurchaseBillModel>> watchBills(String companyId) {
    return _bills(companyId).snapshots().map((snapshot) {
      final bills = snapshot.docs.map(PurchaseBillModel.fromDoc).toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? a.purchaseBillDate;
          final bDate = b.createdAt ?? b.purchaseBillDate;
          return bDate.compareTo(aDate);
        });
      return bills;
    });
  }

  Stream<List<VendorModel>> watchActiveVendors(String companyId) {
    return _companyCollection(companyId, 'vendors').snapshots().map((snapshot) {
      final vendors =
          snapshot.docs
              .map(VendorModel.fromDoc)
              .where(
                (vendor) => vendor.isActive && vendor.vendorName.isNotEmpty,
              )
              .toList()
            ..sort(
              (a, b) => a.vendorName.toLowerCase().compareTo(
                b.vendorName.toLowerCase(),
              ),
            );
      return vendors;
    });
  }

  Future<List<VendorModel>> loadVendors(String companyId) async {
    final snapshot = await _companyCollection(companyId, 'vendors').get();
    final vendors =
        snapshot.docs
            .map(VendorModel.fromDoc)
            .where((vendor) => vendor.vendorName.isNotEmpty)
            .toList()
          ..sort(
            (a, b) => a.vendorName.toLowerCase().compareTo(
              b.vendorName.toLowerCase(),
            ),
          );
    return vendors;
  }

  Future<List<PurchaseProductMasterItem>> loadPurchaseProducts(
    String companyId,
  ) async {
    final snapshot = await _companyCollection(companyId, 'products').get();
    final products =
        snapshot.docs
            .where((doc) {
              final data = doc.data();
              return data['isDeleted'] != true &&
                  data['isActive'] != false &&
                  data['isPurchasable'] != false;
            })
            .map(PurchaseProductMasterItem.fromDoc)
            .where((product) => product.name.isNotEmpty)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return products;
  }

  Future<List<WarehouseRecord>> loadWarehouses(String companyId) async {
    final snapshot = await _companyCollection(companyId, 'warehouses').get();
    final warehouses =
        snapshot.docs
            .map(WarehouseRecord.fromDoc)
            .where(
              (warehouse) =>
                  warehouse.status.toLowerCase() != 'inactive' &&
                  warehouse.name.isNotEmpty,
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return warehouses;
  }

  Future<String> nextBillNumber(String companyId, {DateTime? billDate}) async {
    final date = billDate ?? DateTime.now();
    final financialYear = purchaseFinancialYear(date);
    final counterRef = _companyCollection(
      companyId,
      'counters',
    ).doc('purchase_bill_${financialYear.replaceAll('-', '_')}');
    final next = await _db.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final current =
          (data['sequence'] as num?)?.toInt() ??
          (data['value'] as num?)?.toInt() ??
          0;
      final value = current + 1;
      transaction.set(counterRef, {
        'sequence': value,
        'value': value,
        'financialYear': financialYear,
        'prefix': 'PB',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return value;
    });
    return 'PB/$financialYear/${next.toString().padLeft(5, '0')}';
  }

  Future<String> saveBill({
    required PurchaseBillModel bill,
    required String userUid,
    List<PendingPurchaseBillAttachment> pendingAttachments = const [],
    bool postInventory = false,
  }) async {
    if (bill.products.isEmpty) {
      throw StateError('Add at least one product.');
    }
    if (bill.products.any(
      (line) =>
          line.productId.isEmpty ||
          line.productName.isEmpty ||
          line.quantity <= 0 ||
          line.rate < 0 ||
          line.discountPercent < 0 ||
          line.discountPercent > 100 ||
          line.taxPercent < 0,
    )) {
      throw StateError('One or more product rows are invalid.');
    }
    if (postInventory &&
        bill.products.any((line) => line.trackInventory) &&
        bill.warehouseId.isEmpty) {
      throw StateError('Select a receiving warehouse before posting.');
    }

    final creating = bill.id.isEmpty;
    final ref = creating
        ? _bills(bill.companyId).doc()
        : _bills(bill.companyId).doc(bill.id);
    final number = bill.purchaseBillNo.trim().isEmpty
        ? await nextBillNumber(bill.companyId, billDate: bill.purchaseBillDate)
        : bill.purchaseBillNo.trim();

    final uploaded = <PurchaseBillAttachment>[];
    try {
      for (final attachment in pendingAttachments) {
        uploaded.add(
          await _uploadAttachment(
            companyId: bill.companyId,
            billId: ref.id,
            userUid: userUid,
            attachment: attachment,
          ),
        );
      }

      final allAttachments = [...bill.attachments, ...uploaded];
      final allUrls = {
        ...bill.attachmentUrls.where((url) => url.trim().isNotEmpty),
        ...allAttachments
            .map((attachment) => attachment.url)
            .where((url) => url.trim().isNotEmpty),
      }.toList(growable: false);
      final savedBill = bill.copyWith(
        id: ref.id,
        purchaseBillNo: number,
        status: postInventory ? 'Posted' : 'Draft',
        attachmentUrls: allUrls,
        attachments: allAttachments,
        inventoryPosted: postInventory,
        inventoryPostedAt: postInventory ? DateTime.now() : null,
      );

      if (postInventory) {
        await _saveAndPost(
          bill: savedBill,
          userUid: userUid,
          creating: creating,
        );
      } else {
        await _saveDraft(bill: savedBill, userUid: userUid, creating: creating);
      }
      return ref.id;
    } catch (_) {
      for (final attachment in uploaded) {
        if (attachment.path.isEmpty) continue;
        try {
          await _storage.ref(attachment.path).delete();
        } catch (_) {
          // Best-effort cleanup of files uploaded before a failed save.
        }
      }
      rethrow;
    }
  }

  Future<void> postExistingBill({
    required PurchaseBillModel bill,
    required String userUid,
  }) async {
    if (bill.id.isEmpty) throw StateError('Save the purchase bill first.');
    if (bill.isPosted) {
      throw StateError('This purchase bill is already posted.');
    }
    await _saveAndPost(bill: bill, userUid: userUid, creating: false);
  }

  Future<void> _saveDraft({
    required PurchaseBillModel bill,
    required String userUid,
    required bool creating,
  }) async {
    final billRef = _bills(bill.companyId).doc(bill.id);
    final lockRef = _billNumberLock(bill);

    await _db.runTransaction((transaction) async {
      final billSnapshot = await transaction.get(billRef);
      final lockSnapshot = await transaction.get(lockRef);
      if (billSnapshot.data()?['inventoryPosted'] == true) {
        throw StateError('Posted purchase bills cannot be edited.');
      }
      if (lockSnapshot.exists &&
          lockSnapshot.data()?['purchaseBillId'] != billRef.id) {
        throw StateError(
          'Purchase bill number ${bill.purchaseBillNo} already exists.',
        );
      }

      transaction.set(lockRef, {
        'purchaseBillId': billRef.id,
        'purchaseBillNo': bill.purchaseBillNo,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userUid,
      }, SetOptions(merge: true));
      transaction.set(billRef, {
        ...bill.toFirestore(),
        'status': 'Draft',
        'inventoryPosted': false,
        if (creating || !billSnapshot.exists)
          'createdAt': FieldValue.serverTimestamp(),
        if (creating || !billSnapshot.exists) 'createdBy': userUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userUid,
      }, SetOptions(merge: true));
    });
  }

  Future<void> _saveAndPost({
    required PurchaseBillModel bill,
    required String userUid,
    required bool creating,
  }) async {
    final billRef = _bills(bill.companyId).doc(bill.id);
    final lockRef = _billNumberLock(bill);
    final stockInRef = _companyCollection(
      bill.companyId,
      'stock_in',
    ).doc('purchase_bill_${bill.id}');
    final trackedLines = bill.products
        .where((line) => line.trackInventory)
        .toList(growable: false);
    final productRefs = <String, DocumentReference<Map<String, dynamic>>>{
      for (final line in trackedLines)
        line.productId: _companyCollection(
          bill.companyId,
          'products',
        ).doc(line.productId),
    };

    await _db.runTransaction((transaction) async {
      final billSnapshot = await transaction.get(billRef);
      final lockSnapshot = await transaction.get(lockRef);
      final productSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{
        for (final entry in productRefs.entries)
          entry.key: await transaction.get(entry.value),
      };

      if (billSnapshot.data()?['inventoryPosted'] == true) {
        throw StateError('This purchase bill has already been posted.');
      }
      if (lockSnapshot.exists &&
          lockSnapshot.data()?['purchaseBillId'] != billRef.id) {
        throw StateError(
          'Purchase bill number ${bill.purchaseBillNo} already exists.',
        );
      }

      final receipts = <String, _ProductReceipt>{};
      for (final line in trackedLines) {
        final snapshot = productSnapshots[line.productId];
        if (snapshot == null || !snapshot.exists) {
          throw StateError(
            'Product ${line.productName} no longer exists in Product Master.',
          );
        }
        receipts.putIfAbsent(line.productId, _ProductReceipt.new).add(line);
      }

      final productState = <String, _ProductStockState>{};
      for (final entry in receipts.entries) {
        final snapshot = productSnapshots[entry.key]!;
        final data = snapshot.data() ?? const <String, dynamic>{};
        final currentQuantity = _firstNumber(data, [
          'stockOnHand',
          'quantity',
          'qty',
          'openingStock',
        ]);
        final currentRate = _firstNumber(data, [
          'valuationRate',
          'averagePurchaseRate',
          'averageCost',
          'costPrice',
          'purchaseRate',
        ]);
        final receipt = entry.value;
        final newQuantity = currentQuantity + receipt.quantity;
        final newRate = weightedAveragePurchaseRate(
          currentQuantity: currentQuantity,
          currentRate: currentRate,
          receivedQuantity: receipt.quantity,
          receivedTaxableValue: receipt.taxableValue,
        );
        productState[entry.key] = _ProductStockState(
          beforeQuantity: currentQuantity,
          afterQuantity: newQuantity,
          beforeRate: currentRate,
          afterRate: newRate,
        );

        transaction.set(snapshot.reference, {
          'stockOnHand': newQuantity,
          'quantity': newQuantity,
          'purchaseRate': receipt.lastRate,
          'lastPurchaseRate': receipt.lastRate,
          'valuationRate': newRate,
          'averagePurchaseRate': newRate,
          'averageCost': newRate,
          'costPrice': newRate,
          'stockValue': newQuantity * newRate,
          'lastPurchaseBillId': bill.id,
          'lastPurchaseBillNo': bill.purchaseBillNo,
          'lastPurchaseDate': Timestamp.fromDate(bill.purchaseBillDate),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userUid,
        }, SetOptions(merge: true));
      }

      transaction.set(lockRef, {
        'purchaseBillId': billRef.id,
        'purchaseBillNo': bill.purchaseBillNo,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userUid,
      }, SetOptions(merge: true));

      transaction.set(stockInRef, {
        'stockInNo': 'SIN-${bill.purchaseBillNo.replaceAll('/', '-')}',
        'date': Timestamp.fromDate(bill.purchaseBillDate),
        'warehouseId': bill.warehouseId,
        'warehouseName': bill.warehouseName,
        'supplier': bill.vendorName,
        'vendorId': bill.vendorId,
        'invoiceNo': bill.supplierInvoiceNo,
        'purchaseBillId': bill.id,
        'purchaseBillNo': bill.purchaseBillNo,
        'source': 'PURCHASE_BILL',
        'remarks': bill.remarks,
        'items': trackedLines
            .map(
              (line) => {
                'productId': line.productId,
                'productName': line.productName,
                'productNature': line.productNature.isEmpty
                    ? _text(
                        productSnapshots[line.productId]
                                ?.data()?['productNature'] ??
                            productSnapshots[line.productId]
                                ?.data()?['nature'] ??
                            productSnapshots[line.productId]
                                ?.data()?['productNatureLower'],
                      )
                    : line.productNature,
                'quantity': line.quantity,
                'rate': line.effectivePurchaseRate,
                'amount': line.taxableValue,
              },
            )
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userUid,
      }, SetOptions(merge: true));

      final runningQuantity = {
        for (final entry in productState.entries)
          entry.key: entry.value.beforeQuantity,
      };
      final runningRate = {
        for (final entry in productState.entries)
          entry.key: entry.value.beforeRate,
      };
      for (var index = 0; index < trackedLines.length; index++) {
        final line = trackedLines[index];
        final beforeQuantity = runningQuantity[line.productId] ?? 0;
        final beforeRate = runningRate[line.productId] ?? 0;
        final afterQuantity = beforeQuantity + line.quantity;
        final afterRate = weightedAveragePurchaseRate(
          currentQuantity: beforeQuantity,
          currentRate: beforeRate,
          receivedQuantity: line.quantity,
          receivedTaxableValue: line.taxableValue,
        );
        runningQuantity[line.productId] = afterQuantity;
        runningRate[line.productId] = afterRate;
        final transactionRef = _companyCollection(
          bill.companyId,
          'inventory_transactions',
        ).doc('purchase_bill_${bill.id}_$index');
        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'companyId': bill.companyId,
          'transactionType': 'PURCHASE_BILL',
          'direction': 'IN',
          'purchaseBillId': bill.id,
          'purchaseBillNo': bill.purchaseBillNo,
          'vendorId': bill.vendorId,
          'vendorName': bill.vendorName,
          'warehouseId': bill.warehouseId,
          'warehouseName': bill.warehouseName,
          'productId': line.productId,
          'productName': line.productName,
          'quantity': line.quantity,
          'unitPrice': line.rate,
          'effectivePurchaseRate': line.effectivePurchaseRate,
          'taxableAmount': line.taxableValue,
          'gstAmount': line.taxAmount,
          'totalAmount': line.lineTotal,
          'beforeStock': beforeQuantity,
          'afterStock': afterQuantity,
          'beforeValuationRate': beforeRate,
          'afterValuationRate': afterRate,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userUid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userUid,
          'isActive': true,
          'isDeleted': false,
        }, SetOptions(merge: true));
      }

      transaction.set(billRef, {
        ...bill.toFirestore(),
        'status': 'Posted',
        'inventoryPosted': true,
        'inventoryPostedAt': FieldValue.serverTimestamp(),
        'stockInId': stockInRef.id,
        if (creating || !billSnapshot.exists)
          'createdAt': FieldValue.serverTimestamp(),
        if (creating || !billSnapshot.exists) 'createdBy': userUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userUid,
      }, SetOptions(merge: true));
    });
  }

  DocumentReference<Map<String, dynamic>> _billNumberLock(
    PurchaseBillModel bill,
  ) {
    return _companyCollection(
      bill.companyId,
      'purchase_bill_number_locks',
    ).doc(bill.purchaseBillNo.replaceAll('/', '_'));
  }

  Future<void> deleteBill(PurchaseBillModel bill) async {
    final ref = _bills(bill.companyId).doc(bill.id);
    final snapshot = await ref.get();
    if (snapshot.data()?['inventoryPosted'] == true || bill.isPosted) {
      throw StateError(
        'Posted purchase bills cannot be deleted because stock is already updated.',
      );
    }
    await ref.delete();
    for (final attachment in bill.attachments) {
      if (attachment.path.isEmpty) continue;
      try {
        await _storage.ref(attachment.path).delete();
      } catch (_) {
        // The Firestore record is authoritative; a missing object is safe.
      }
    }
  }

  Future<Map<String, dynamic>> loadCompany(String companyId) async {
    final snapshot = await _db.collection('companies').doc(companyId).get();
    return snapshot.data() ?? <String, dynamic>{};
  }

  Future<PurchaseBillAttachment> _uploadAttachment({
    required String companyId,
    required String billId,
    required String userUid,
    required PendingPurchaseBillAttachment attachment,
  }) async {
    final safeName = attachment.fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final path =
        'companies/$companyId/purchase_bills/$billId/'
        '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final ref = _storage.ref().child(path);
    final task = await ref.putData(
      attachment.bytes,
      SettableMetadata(
        contentType: attachment.contentType,
        customMetadata: {
          'companyId': companyId,
          'purchaseBillId': billId,
          'uploadedBy': userUid,
          'module': 'purchase_bills',
        },
      ),
    );
    if (task.state != TaskState.success) {
      throw StateError('Purchase bill attachment upload failed.');
    }
    return PurchaseBillAttachment(
      url: await ref.getDownloadURL(),
      path: path,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      size: attachment.size,
      uploadedAt: DateTime.now(),
    );
  }
}

class _ProductReceipt {
  double quantity = 0;
  double taxableValue = 0;
  double lastRate = 0;

  double get effectiveRate => quantity <= 0 ? 0 : taxableValue / quantity;

  void add(PurchaseBillLine line) {
    quantity += line.quantity;
    taxableValue += line.taxableValue;
    lastRate = line.rate;
  }
}

class _ProductStockState {
  const _ProductStockState({
    required this.beforeQuantity,
    required this.afterQuantity,
    required this.beforeRate,
    required this.afterRate,
  });

  final double beforeQuantity;
  final double afterQuantity;
  final double beforeRate;
  final double afterRate;
}

String _text(dynamic value) => value?.toString().trim() ?? '';

double _firstNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}
