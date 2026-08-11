import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tds_tcs_section_model.dart';

class TdsTcsSectionRepository {
  TdsTcsSectionRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('tds_tcs_section_codes');

  Stream<List<TdsTcsSectionModel>> watchSections() {
    return _collection.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map(TdsTcsSectionModel.fromFirestore)
          .where((record) => !record.isDeleted)
          .toList();

      records.sort((a, b) {
        final left = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final right = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return right.compareTo(left);
      });

      return records;
    });
  }

  Future<void> create({
    required TdsTcsSectionModel section,
    required String userUid,
  }) async {
    final duplicate = await _collection
        .where('code', isEqualTo: section.code.trim())
        .limit(1)
        .get();

    final activeDuplicate = duplicate.docs.any(
      (document) => document.data()['is_deleted'] != true,
    );

    if (activeDuplicate) {
      throw StateError(
        'An active TDS/TCS section with code ${section.code} already exists.',
      );
    }

    await _collection.add(
      section.toFirestore(userUid: userUid, isCreate: true),
    );
  }

  Future<void> update({
    required TdsTcsSectionModel section,
    required String userUid,
  }) async {
    if (section.id.trim().isEmpty) {
      throw ArgumentError('Section document ID is required.');
    }

    await _collection
        .doc(section.id)
        .update(section.toFirestore(userUid: userUid, isCreate: false));
  }

  Future<void> archive({required String id, required String userUid}) async {
    await _collection.doc(id).update(<String, dynamic>{
      'is_deleted': true,
      'status': 'Inactive',
      'updated_by': userUid,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> bulkArchive({
    required Iterable<String> ids,
    required String userUid,
  }) async {
    final batch = _firestore.batch();

    for (final id in ids.where((value) => value.trim().isNotEmpty)) {
      batch.update(_collection.doc(id), <String, dynamic>{
        'is_deleted': true,
        'status': 'Inactive',
        'updated_by': userUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> bulkUpdateStatus({
    required Iterable<String> ids,
    required String status,
    required String userUid,
  }) async {
    final batch = _firestore.batch();

    for (final id in ids.where((value) => value.trim().isNotEmpty)) {
      batch.update(_collection.doc(id), <String, dynamic>{
        'status': status,
        'updated_by': userUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
