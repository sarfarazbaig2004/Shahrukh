import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/compliance_models.dart';

class ComplianceRepositoryException implements Exception {
  const ComplianceRepositoryException(this.message, {this.code = 'unknown'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

class ComplianceReportsRepository {
  ComplianceReportsRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : assert(companyId != ''),
       _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;
  final String companyId;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  DocumentReference<Map<String, dynamic>> get _tenant =>
      _db.collection('companies').doc(companyId);
  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _tenant.collection(name);

  Future<List<ComplianceRecord>> loadRecords() async {
    const sources = <String, ComplianceRecordType>{
      'complianceCalendar': ComplianceRecordType.compliance,
      'compliance_reports': ComplianceRecordType.report,
      'compliance_queries': ComplianceRecordType.query,
      'government_notices': ComplianceRecordType.notice,
      'legal_cases': ComplianceRecordType.legalCase,
      'document_repository': ComplianceRecordType.document,
    };
    try {
      final snapshots = await Future.wait(
        sources.keys.map((name) => _collection(name).limit(500).get()),
      );
      final records = <ComplianceRecord>[];
      for (var i = 0; i < snapshots.length; i++) {
        final type = sources.values.elementAt(i);
        records.addAll(
          snapshots[i].docs
              .map((d) => ComplianceRecord.fromMap(d.id, d.data(), type))
              .where((r) => !r.isDeleted),
        );
      }
      records.sort(
        (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(1970)).compareTo(
          a.updatedAt ?? a.createdAt ?? DateTime(1970),
        ),
      );
      return records;
    } on FirebaseException catch (error) {
      throw ComplianceRepositoryException(
        error.code == 'permission-denied'
            ? 'You do not have permission to view compliance records.'
            : 'Compliance data could not be loaded.',
        code: error.code,
      );
    }
  }

  Stream<List<ComplianceQuery>> watchQueries({bool includeDeleted = false}) =>
      _collection('compliance_queries')
          .orderBy('updatedAt', descending: true)
          .limit(200)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => ComplianceQuery.fromMap(d.id, d.data()))
                .where((q) => includeDeleted || !q.isDeleted)
                .toList(),
          );

  Future<ComplianceQuery> saveQuery(
    ComplianceQuery query, {
    required String userId,
    required String userName,
  }) async {
    if (userId.trim().isEmpty) {
      throw const ComplianceRepositoryException(
        'A signed-in user is required.',
      );
    }
    try {
      if (query.id.isNotEmpty) {
        final ref = _collection('compliance_queries').doc(query.id);
        await _db.runTransaction((tx) async {
          final old = await tx.get(ref);
          tx.set(ref, {
            ...query.toMap(),
            'updatedBy': userId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          _audit(
            tx,
            'query',
            ref.id,
            'updated',
            userId,
            userName,
            old.data(),
            query.toMap(),
          );
        });
        return query;
      }
      final ref = _collection('compliance_queries').doc();
      final sequence = _tenant
          .collection('sequences')
          .doc('compliance_queries');
      late String number;
      await _db.runTransaction((tx) async {
        final snap = await tx.get(sequence);
        final next = ((snap.data()?['next'] as num?)?.toInt() ?? 1);
        number = 'CQ-${DateTime.now().year}-${next.toString().padLeft(6, '0')}';
        tx.set(sequence, {
          'next': next + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final value = query.copyWith(id: ref.id, queryNumber: number);
        tx.set(ref, {
          ...value.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _audit(
          tx,
          'query',
          ref.id,
          'created',
          userId,
          userName,
          null,
          value.toMap(),
        );
      });
      return query.copyWith(id: ref.id, queryNumber: number);
    } on FirebaseException catch (error) {
      throw ComplianceRepositoryException(
        error.code == 'permission-denied'
            ? 'You do not have permission to save this query.'
            : 'The query could not be saved.',
        code: error.code,
      );
    }
  }

  Future<void> softDeleteQuery(
    ComplianceQuery query, {
    required String userId,
    required String userName,
    bool restore = false,
  }) async {
    final ref = _collection('compliance_queries').doc(query.id);
    await _db.runTransaction((tx) async {
      final old = await tx.get(ref);
      final patch = {
        'isDeleted': !restore,
        'deletedAt': restore ? null : FieldValue.serverTimestamp(),
        'deletedBy': restore ? '' : userId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx.update(ref, patch);
      _audit(
        tx,
        'query',
        query.id,
        restore ? 'restored' : 'deleted',
        userId,
        userName,
        old.data(),
        patch,
      );
    });
  }

  Future<String> uploadDocument({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String userId,
    required String title,
    required String documentType,
    String sourceRecordId = '',
    void Function(double)? onProgress,
  }) async {
    const allowed = {
      'application/pdf',
      'text/csv',
      'application/zip',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg',
      'image/png',
    };
    if (!allowed.contains(mimeType)) {
      throw const ComplianceRepositoryException(
        'Unsupported file type. Use PDF, Excel, Word, image, CSV or ZIP.',
      );
    }
    if (bytes.length > 25 * 1024 * 1024) {
      throw const ComplianceRepositoryException(
        'Files must be 25 MB or smaller.',
      );
    }
    final id = _collection('document_repository').doc().id;
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'companies/$companyId/compliance_documents/$id/$safe';
    final task = _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: mimeType));
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) {
        onProgress?.call(s.bytesTransferred / s.totalBytes);
      }
    });
    final result = await task;
    final url = await result.ref.getDownloadURL();
    await _collection('document_repository').doc(id).set({
      'id': id,
      'title': title,
      'originalFileName': fileName,
      'storagePath': path,
      'downloadUrl': url,
      'mimeType': mimeType,
      'sizeBytes': bytes.length,
      'documentType': documentType,
      'sourceRecordId': sourceRecordId,
      'version': 1,
      'uploadedBy': userId,
      'uploadedAt': FieldValue.serverTimestamp(),
      'companyId': companyId,
      'isDeleted': false,
      'schemaVersion': 1,
    });
    return url;
  }

  void _audit(
    Transaction tx,
    String type,
    String id,
    String action,
    String uid,
    String name,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  ) {
    tx.set(_collection('audit_logs').doc(), {
      'recordType': type,
      'recordId': id,
      'action': action,
      'userId': uid,
      'userName': name,
      'companyId': companyId,
      'previousValues': before,
      'newValues': after,
      'ipAddress': null,
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
  }
}
