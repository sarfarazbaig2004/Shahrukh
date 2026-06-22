import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('vendors')
        .snapshots()
        .map((snapshot) {
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

  Future<String> nextBillNumber(String companyId) async {
    final counterRef = _db
        .collection('companies')
        .doc(companyId)
        .collection('counters')
        .doc('purchase_bill_${DateTime.now().year}');
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
    return 'PB-${DateTime.now().year}-${next.toString().padLeft(4, '0')}';
  }

  Future<String> saveBill({
    required PurchaseBillModel bill,
    required String userUid,
    Uint8List? pdfBytes,
    String? selectedPdfName,
  }) async {
    final creating = bill.id.isEmpty;
    final ref = creating
        ? _bills(bill.companyId).doc()
        : _bills(bill.companyId).doc(bill.id);
    var savedBill = bill.copyWith(id: ref.id);

    if (pdfBytes != null && selectedPdfName != null) {
      final attachment = await _uploadPdf(
        companyId: bill.companyId,
        billId: ref.id,
        userUid: userUid,
        fileName: selectedPdfName,
        bytes: pdfBytes,
      );
      savedBill = savedBill.copyWith(
        pdfUrl: attachment.url,
        pdfPath: attachment.path,
        pdfFileName: attachment.fileName,
        pdfUploadedAt: attachment.uploadedAt,
      );
    }

    await ref.set({
      ...savedBill.toFirestore(),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
      if (creating) 'createdBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteBill(PurchaseBillModel bill) async {
    await _bills(bill.companyId).doc(bill.id).delete();
    if (bill.pdfPath.isNotEmpty) {
      try {
        await _storage.ref(bill.pdfPath).delete();
      } catch (_) {
        // The Firestore record is authoritative; a missing old object is safe.
      }
    }
  }

  Future<Map<String, dynamic>> loadCompany(String companyId) async {
    final snapshot = await _db.collection('companies').doc(companyId).get();
    return snapshot.data() ?? <String, dynamic>{};
  }

  Future<_UploadedAttachment> _uploadPdf({
    required String companyId,
    required String billId,
    required String userUid,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final path =
        'companies/$companyId/purchase_bills/$billId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref().child(path);
    final task = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'companyId': companyId,
          'purchaseBillId': billId,
          'uploadedBy': userUid,
          'module': 'purchase_bills',
        },
      ),
    );
    if (task.state != TaskState.success) {
      throw StateError('Purchase bill PDF upload failed.');
    }
    return _UploadedAttachment(
      url: await ref.getDownloadURL(),
      path: path,
      fileName: fileName,
      uploadedAt: DateTime.now(),
    );
  }
}

class _UploadedAttachment {
  const _UploadedAttachment({
    required this.url,
    required this.path,
    required this.fileName,
    required this.uploadedAt,
  });

  final String url;
  final String path;
  final String fileName;
  final DateTime uploadedAt;
}
