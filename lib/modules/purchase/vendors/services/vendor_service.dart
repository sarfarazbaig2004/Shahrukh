import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vendor_model.dart';

class VendorService {
  VendorService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _vendors(String companyId) {
    return _db.collection('companies').doc(companyId).collection('vendors');
  }

  Stream<List<VendorModel>> watchVendors(String companyId) {
    return _vendors(companyId).snapshots().map((snapshot) {
      final vendors = snapshot.docs.map(VendorModel.fromDoc).toList()
        ..sort(
          (a, b) =>
              a.vendorName.toLowerCase().compareTo(b.vendorName.toLowerCase()),
        );
      return vendors;
    });
  }

  Future<String> nextVendorCode(String companyId) async {
    final counterRef = _db
        .collection('companies')
        .doc(companyId)
        .collection('counters')
        .doc('purchase_vendor');
    final next = await _db.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final value = current + 1;
      transaction.set(counterRef, {
        'value': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return value;
    });
    return 'VND-${next.toString().padLeft(4, '0')}';
  }

  Future<String> saveVendor({
    required VendorModel vendor,
    required String userUid,
  }) async {
    final creating = vendor.id.isEmpty;
    final ref = creating
        ? _vendors(vendor.companyId).doc()
        : _vendors(vendor.companyId).doc(vendor.id);
    final code = vendor.vendorCode.trim().isEmpty
        ? await nextVendorCode(vendor.companyId)
        : vendor.vendorCode.trim().toUpperCase();
    final duplicate = await _vendors(
      vendor.companyId,
    ).where('vendorCode', isEqualTo: code).limit(2).get();
    if (duplicate.docs.any((doc) => doc.id != ref.id)) {
      throw StateError('Vendor code $code already exists.');
    }

    await ref.set({
      ...vendor.toFirestore(),
      'vendorCode': code,
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
      if (creating) 'createdBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> setVendorActive({
    required String companyId,
    required String vendorId,
    required bool isActive,
    required String userUid,
  }) {
    return _vendors(companyId).doc(vendorId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    });
  }
}
