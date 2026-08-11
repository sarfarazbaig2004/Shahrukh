import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/form10iea_models.dart';
import '../services/form10iea_rule_engine.dart';

class Form10IEARepository {
  Form10IEARepository({required this.companyId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rules => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('form10iea_rules');

  CollectionReference<Map<String, dynamic>> get _notes => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('form10iea_legal_notes');

  CollectionReference<Map<String, dynamic>> get _assessments => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('form10iea_assessments');

  CollectionReference<Map<String, dynamic>> get _audit => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('form10iea_audit');

  Stream<List<Form10IEAScenarioRule>> watchRules() {
    return _rules.snapshots().map((snapshot) {
      final values = snapshot.docs
          .map(Form10IEAScenarioRule.fromFirestore)
          .toList();

      values.sort((a, b) => a.id.compareTo(b.id));
      return values;
    });
  }

  Stream<List<Form10IEALegalNote>> watchLegalNotes() {
    return _notes.snapshots().map((snapshot) {
      return snapshot.docs
          .map(Form10IEALegalNote.fromFirestore)
          .where((item) => item.active)
          .toList();
    });
  }

  Future<void> saveRule({
    required Form10IEAScenarioRule rule,
    required String userUid,
  }) async {
    final document = rule.id.trim().isEmpty
        ? _rules.doc()
        : _rules.doc(rule.id);

    await document.set(
      rule.copyWith(id: document.id).toFirestore(userUid),
      SetOptions(merge: true),
    );
  }

  Future<String> saveAssessment({
    required Form10IEAAssessmentInput input,
    required Form10IEAResult clientResult,
    required List<Form10IEAScenarioRule> rules,
    required String userUid,
    required String idempotencyKey,
  }) async {
    final safeKey = idempotencyKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final assessmentRef = _assessments.doc(safeKey);
    final auditRef = _audit.doc('assessment_$safeKey');

    return _firestore.runTransaction<String>((transaction) async {
      final existing = await transaction.get(assessmentRef);

      if (existing.exists) {
        return assessmentRef.id;
      }

      if (!input.canAnalyse) {
        throw StateError('Unconfirmed assessment input cannot be saved.');
      }

      final serverResult = const Form10IEARuleEngine().evaluate(
        input: input,
        rules: rules,
        yearConfig: Form10IEAFinancialYearConfig.current,
      );

      if (serverResult.status != clientResult.status ||
          serverResult.matchedRuleIds.join('|') !=
              clientResult.matchedRuleIds.join('|')) {
        throw StateError('The assessment result changed during validation.');
      }

      transaction.set(assessmentRef, <String, dynamic>{
        'companyId': companyId,
        'userId': userUid,
        'input': input.toSafeMap(),
        'result': serverResult.toMap(),
        'ruleVersion': rules
            .where((rule) => serverResult.matchedRuleIds.contains(rule.id))
            .map((rule) => rule.ruleVersion)
            .join(','),
        'idempotencyKey': safeKey,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(auditRef, <String, dynamic>{
        'event': 'form10iea_assessment_saved',
        'assessmentId': assessmentRef.id,
        'companyId': companyId,
        'userId': userUid,
        'resultStatus': serverResult.status.name,
        'matchedRuleIds': serverResult.matchedRuleIds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return assessmentRef.id;
    });
  }
}
