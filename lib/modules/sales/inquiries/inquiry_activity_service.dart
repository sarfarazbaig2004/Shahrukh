import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:QUIK/models/inquiry_activity.dart';

class InquiryActivityService {
  InquiryActivityService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> activities({
    required String companyId,
    required String inquiryId,
  }) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('inquiries')
        .doc(inquiryId)
        .collection('activities');
  }

  Stream<List<InquiryActivity>> watchActivities({
    required String companyId,
    required String inquiryId,
  }) {
    return activities(companyId: companyId, inquiryId: inquiryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(InquiryActivity.fromSnapshot).toList(),
        );
  }

  Future<void> recordActivity({
    required String companyId,
    required String inquiryId,
    required String inquiryNumber,
    required InquiryActivityType type,
    required String title,
    String? description,
    String? status,
    String? previousStatus,
    String? newStatus,
    String? relatedDocumentType,
    String? relatedDocumentId,
    String? relatedDocumentNumber,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    final user = _auth.currentUser;
    Map<String, dynamic>? userData;
    if (user != null) {
      try {
        userData =
            (await _firestore
                    .collection('companies')
                    .doc(companyId)
                    .collection('users')
                    .doc(user.uid)
                    .get())
                .data();
      } on FirebaseException {
        // Profile lookup is optional. The authenticated UID and Auth profile
        // remain available if this tenant-scoped lookup is denied/offline.
      }
    }
    final userName = _firstText([
      userData?['name'],
      userData?['fullName'],
      user?.displayName,
      user?.email?.split('@').first,
    ]);
    final key = (idempotencyKey?.trim().isNotEmpty ?? false)
        ? _safeDocumentId(idempotencyKey!)
        : null;
    final ref = key == null
        ? activities(companyId: companyId, inquiryId: inquiryId).doc()
        : activities(companyId: companyId, inquiryId: inquiryId).doc(key);
    final data = buildActivityData(
      companyId: companyId,
      inquiryId: inquiryId,
      inquiryNumber: inquiryNumber,
      type: type,
      title: title,
      createdByUid: user?.uid ?? '',
      createdByName: userName,
      description: description,
      status: status,
      previousStatus: previousStatus,
      newStatus: newStatus,
      relatedDocumentType: relatedDocumentType,
      relatedDocumentId: relatedDocumentId,
      relatedDocumentNumber: relatedDocumentNumber,
      metadata: metadata,
    );
    await _firestore.runTransaction((transaction) async {
      if ((await transaction.get(ref)).exists) return;
      transaction.set(ref, data);
    });
  }

  static Map<String, dynamic> buildActivityData({
    required String companyId,
    required String inquiryId,
    required String inquiryNumber,
    required InquiryActivityType type,
    required String title,
    required String createdByUid,
    required String createdByName,
    String? description,
    String? status,
    String? previousStatus,
    String? newStatus,
    String? relatedDocumentType,
    String? relatedDocumentId,
    String? relatedDocumentNumber,
    Map<String, dynamic>? metadata,
  }) {
    return <String, dynamic>{
      'type': type.value,
      'title': title,
      'inquiryId': inquiryId,
      'inquiryNumber': inquiryNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'companyId': companyId,
      'metadata': _firestoreSafeMap(metadata ?? const <String, dynamic>{}),
      if (_notBlank(description)) 'description': description!.trim(),
      if (_notBlank(status)) 'status': status!.trim(),
      if (_notBlank(previousStatus)) 'previousStatus': previousStatus!.trim(),
      if (_notBlank(newStatus)) 'newStatus': newStatus!.trim(),
      if (_notBlank(relatedDocumentType))
        'relatedDocumentType': relatedDocumentType!.trim(),
      if (_notBlank(relatedDocumentId))
        'relatedDocumentId': relatedDocumentId!.trim(),
      if (_notBlank(relatedDocumentNumber))
        'relatedDocumentNumber': relatedDocumentNumber!.trim(),
    };
  }

  static bool _notBlank(String? value) => value?.trim().isNotEmpty ?? false;

  static String _safeDocumentId(String value) =>
      value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return 'Unknown user';
  }

  static Map<String, dynamic> _firestoreSafeMap(Map<String, dynamic> source) {
    dynamic safe(dynamic value) {
      if (value == null ||
          value is String ||
          value is num ||
          value is bool ||
          value is Timestamp ||
          value is DateTime ||
          value is GeoPoint ||
          value is DocumentReference) {
        return value;
      }
      if (value is Iterable) return value.map(safe).toList();
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), safe(item)));
      }
      return value.toString();
    }

    return source.map((key, value) => MapEntry(key, safe(value)));
  }
}
