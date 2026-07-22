import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/compliance_calendar_model.dart';

class ComplianceCalendarRepository {
  ComplianceCalendarRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('complianceCalendar');

  Stream<List<ComplianceCalendarModel>> watchCompliance() {
    return _collection.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map(ComplianceCalendarModel.fromFirestore)
          .where((item) => !item.isDeleted)
          .toList();

      records.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return records;
    });
  }

  Future<void> create({
    required ComplianceCalendarModel item,
    required String userUid,
  }) async {
    await _collection.add(item.toFirestore(userUid: userUid, isCreate: true));
  }

  Future<void> update({
    required ComplianceCalendarModel item,
    required String userUid,
  }) async {
    await _collection
        .doc(item.id)
        .update(item.toFirestore(userUid: userUid, isCreate: false));
  }

  Future<void> updateStatus({
    required String id,
    required String status,
    required String userUid,
  }) async {
    await _collection.doc(id).update(<String, dynamic>{
      'status': status,
      'updatedBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archive({required String id, required String userUid}) async {
    await _collection.doc(id).update(<String, dynamic>{
      'isDeleted': true,
      'updatedBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
