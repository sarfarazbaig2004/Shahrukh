import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/purchase_rfq_model.dart';

/// Firestore repository for Request for Quotation (RFQ) records.
///
/// RFQs are stored under:
///   companies/{companyId}/purchase_rfqs
///
/// Soft delete is implemented by setting [isDeleted] to true. New records are
/// saved with [isDeleted] == false so a simple equality query can filter them
/// without requiring a composite index.
///
/// Query strategy:
/// * We stream ALL documents for the company (no server-side orderBy or
///   equality filter on isDeleted). This avoids Firestore composite-index
///   requirements and gracefully tolerates legacy documents that may be
///   missing [isDeleted] or [updatedAt].
/// * Deleted documents are filtered in memory.
/// * Results are sorted in memory by updatedAt desc, then createdAt desc, then
///   rfqDate desc.
/// * Each document is parsed inside a try/catch so one corrupt record cannot
///   crash the whole list.
class RfqService {
  RfqService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _rfqs(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('purchase_rfqs');
  }

  /// Streams active RFQs ordered by recency.
  ///
  /// No server-side filters are used, so this does not require any composite
  /// index. Deleted records and corrupt documents are handled in memory.
  Stream<List<PurchaseRfq>> watchRfqs(String companyId) {
    final path = 'companies/$companyId/purchase_rfqs';
    developer.log(
      '[RFQ] watchRfqs started'
      ' | companyId: $companyId'
      ' | path: $path'
      ' | query: .snapshots() (no server-side filters/orderBy)',
      name: 'RfqService',
    );

    return _rfqs(companyId).snapshots().map((snapshot) {
      developer.log(
        '[RFQ] watchRfqs snapshot received'
        ' | path: $path'
        ' | docs: ${snapshot.docs.length}',
        name: 'RfqService',
      );
      final rfqs = _parseAndFilter(snapshot.docs, path);
      developer.log(
        '[RFQ] watchRfqs parsed'
        ' | path: $path'
        ' | active RFQs returned: ${rfqs.length}',
        name: 'RfqService',
      );
      return rfqs;
    }).handleError((Object error, StackTrace stackTrace) {
      developer.log(
        '[RFQ] watchRfqs stream error'
        ' | path: $path'
        ' | error: $error'
        ' | stackTrace: $stackTrace',
        name: 'RfqService',
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<List<PurchaseRfq>> loadRfqs(String companyId) async {
    final path = 'companies/$companyId/purchase_rfqs';
    developer.log(
      '[RFQ] loadRfqs started'
      ' | companyId: $companyId'
      ' | path: $path'
      ' | query: .get() (no server-side filters/orderBy)',
      name: 'RfqService',
    );
    try {
      final snapshot = await _rfqs(companyId).get();
      developer.log(
        '[RFQ] loadRfqs snapshot received'
        ' | path: $path'
        ' | docs: ${snapshot.docs.length}',
        name: 'RfqService',
      );
      final rfqs = _parseAndFilter(snapshot.docs, path);
      developer.log(
        '[RFQ] loadRfqs parsed'
        ' | path: $path'
        ' | active RFQs returned: ${rfqs.length}',
        name: 'RfqService',
      );
      return rfqs;
    } catch (error, stackTrace) {
      developer.log(
        '[RFQ] loadRfqs error'
        ' | path: $path'
        ' | error: $error'
        ' | stackTrace: $stackTrace',
        name: 'RfqService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<PurchaseRfq?> loadRfq(String companyId, String rfqId) async {
    final path = 'companies/$companyId/purchase_rfqs/$rfqId';
    developer.log('[RFQ] loadRfq | path: $path', name: 'RfqService');
    try {
      final doc = await _rfqs(companyId).doc(rfqId).get();
      if (!doc.exists || doc.data() == null) {
        developer.log('[RFQ] loadRfq not found | path: $path', name: 'RfqService');
        return null;
      }
      final rfq = PurchaseRfq.fromMap(doc.data()!);
      if (rfq.isDeleted) {
        developer.log(
          '[RFQ] loadRfq skipped (deleted) | path: $path',
          name: 'RfqService',
        );
        return null;
      }
      return rfq.copyWith(id: doc.id);
    } catch (error, stackTrace) {
      developer.log(
        '[RFQ] loadRfq error'
        ' | path: $path'
        ' | error: $error'
        ' | stackTrace: $stackTrace',
        name: 'RfqService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<String> saveRfq({
    required PurchaseRfq rfq,
    required String userUid,
  }) async {
    if (rfq.rfqNumber.trim().isEmpty) {
      throw StateError('RFQ number is required.');
    }
    if (rfq.title.trim().isEmpty) {
      throw StateError('Title is required.');
    }
    if (rfq.items.isEmpty) {
      throw StateError('Add at least one item.');
    }
    if (rfq.items.any((item) => item.itemName.trim().isEmpty)) {
      throw StateError('Each item must have a name.');
    }

    final creating = rfq.id.isEmpty;
    final ref = creating
        ? _rfqs(rfq.companyId).doc()
        : _rfqs(rfq.companyId).doc(rfq.id);

    final now = DateTime.now();
    final saved = rfq.copyWith(
      id: ref.id,
      isDeleted: false,
      updatedAt: now,
      createdAt: creating
          ? (rfq.createdAt.isBefore(now) ? rfq.createdAt : now)
          : rfq.createdAt,
    );

    developer.log(
      '[RFQ] saveRfq | creating: $creating | path: companies/${rfq.companyId}/purchase_rfqs/${ref.id}',
      name: 'RfqService',
    );

    await ref.set({
      ...saved.toMap(),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
      if (creating) 'createdBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    }, SetOptions(merge: true));

    return ref.id;
  }

  Future<void> softDeleteRfq({
    required String companyId,
    required String rfqId,
    required String userUid,
  }) async {
    final path = 'companies/$companyId/purchase_rfqs/$rfqId';
    developer.log('[RFQ] softDeleteRfq | path: $path', name: 'RfqService');
    await _rfqs(companyId).doc(rfqId).set({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
    }, SetOptions(merge: true));
  }

  /// Parses every document defensively, filters out deleted records, and sorts
  /// by recency so the UI always receives a clean list.
  List<PurchaseRfq> _parseAndFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String path,
  ) {
    final rfqs = <PurchaseRfq>[];
    for (final doc in docs) {
      final data = doc.data();
      try {
        final rfq = PurchaseRfq.fromMap(data).copyWith(id: doc.id);
        if (!rfq.isDeleted) {
          rfqs.add(rfq);
        }
      } catch (error, stackTrace) {
        developer.log(
          '[RFQ] Skipped corrupt document'
          ' | path: $path/${doc.id}'
          ' | data: $data'
          ' | error: $error'
          ' | stackTrace: $stackTrace',
          name: 'RfqService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    rfqs.sort((a, b) {
      final aUpdated = a.updatedAt ?? a.createdAt;
      final bUpdated = b.updatedAt ?? b.createdAt;
      final updatedCompare = bUpdated.compareTo(aUpdated);
      if (updatedCompare != 0) return updatedCompare;

      final createdCompare = b.createdAt.compareTo(a.createdAt);
      if (createdCompare != 0) return createdCompare;

      return b.rfqDate.compareTo(a.rfqDate);
    });

    return rfqs;
  }
}
