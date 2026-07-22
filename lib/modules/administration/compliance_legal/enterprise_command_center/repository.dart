import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

abstract interface class CommandCenterRepository {
  Stream<List<ComplianceRecord>> watchCompliance(
    String companyId,
    CommandCenterFilter filter,
  );
  Stream<List<RiskRegisterItem>> watchRisks(
    String companyId,
    CommandCenterFilter filter,
  );
  Stream<List<GovernmentNotice>> watchNotices(
    String companyId,
    CommandCenterFilter filter,
  );
  Stream<List<LegalCase>> watchCases(
    String companyId,
    CommandCenterFilter filter,
  );
  Stream<List<PolicyDocument>> watchPolicies(
    String companyId,
    CommandCenterFilter filter,
  );
  Stream<List<AuditFinding>> watchFindings(
    String companyId,
    CommandCenterFilter filter,
  );
  Stream<List<ApprovalWorkflow>> watchWorkflows(String companyId);
  Stream<List<Map<String, dynamic>>> watchDocuments(
    String companyId,
    CommandCenterFilter filter,
  );
  Stream<List<Map<String, dynamic>>> watchAudit(String companyId);
  Stream<List<SecurityControl>> watchSecurityControls(String companyId);

  Future<void> saveRisk(RiskRegisterItem value);
  Future<void> saveWorkflow(ApprovalWorkflow value);
  Future<void> saveNotice(GovernmentNotice value);
  Future<void> saveCase(LegalCase value);
  Future<void> savePolicy(PolicyDocument value);
  Future<void> saveFinding(AuditFinding value);
  Future<void> saveSecurityControl(SecurityControl value);
  Future<void> writeAudit({
    required String companyId,
    required String userId,
    required String userName,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic> oldValues,
    Map<String, dynamic> newValues,
  });
  Future<CommandCenterMetrics> metrics(
    String companyId,
    CommandCenterFilter filter,
  );
}

class FirestoreCommandCenterRepository implements CommandCenterRepository {
  FirestoreCommandCenterRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _c(String companyId, String name) =>
      _db.collection('companies').doc(companyId).collection(name);

  Query<Map<String, dynamic>> _query(
    String companyId,
    String name,
    CommandCenterFilter filter,
  ) {
    Query<Map<String, dynamic>> q = _c(companyId, name);
    if (filter.branchId != null) {
      q = q.where('branchId', isEqualTo: filter.branchId);
    }
    if (filter.financialYear != null) {
      q = q.where('financialYear', isEqualTo: filter.financialYear);
    }
    if (filter.department != null) {
      q = q.where('department', isEqualTo: filter.department);
    }
    if (filter.status != null && filter.status != 'overdue') {
      q = q.where('status', isEqualTo: filter.status);
    }
    return q;
  }

  bool _search(String term, Iterable<String> values) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) {
      return true;
    }
    return values.any((v) => v.toLowerCase().contains(t));
  }

  @override
  Stream<List<ComplianceRecord>> watchCompliance(
    String companyId,
    CommandCenterFilter filter,
  ) => _query(companyId, 'compliance', filter)
      .orderBy('dueDate')
      .limit(1000)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => ComplianceRecord.fromMap(d.id, d.data()))
            .where((v) => !v.isDeleted)
            .where((v) => filter.status != 'overdue' || v.isOverdue)
            .where(
              (v) =>
                  filter.riskLevel == null || v.riskLevel == filter.riskLevel,
            )
            .where(
              (v) => _search(filter.search, [
                v.referenceNumber,
                v.title,
                v.category,
                v.department,
                v.ownerName,
              ]),
            )
            .toList(),
      );

  @override
  Stream<List<RiskRegisterItem>> watchRisks(
    String companyId,
    CommandCenterFilter filter,
  ) => _query(companyId, 'risk_register', filter)
      .orderBy('updatedAt', descending: true)
      .limit(500)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => RiskRegisterItem.fromMap(d.id, d.data()))
            .where((v) => !v.isDeleted)
            .where(
              (v) =>
                  filter.riskLevel == null ||
                  v.residualLevel == filter.riskLevel,
            )
            .where(
              (v) => _search(filter.search, [
                v.title,
                v.category,
                v.department,
                v.ownerName,
                v.mitigationPlan,
              ]),
            )
            .toList(),
      );

  @override
  Stream<List<GovernmentNotice>> watchNotices(
    String companyId,
    CommandCenterFilter filter,
  ) => _query(companyId, 'government_notices', filter)
      .orderBy('replyDueDate')
      .limit(500)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => GovernmentNotice.fromMap(d.id, d.data()))
            .where((v) => !v.isDeleted)
            .where(
              (v) => _search(filter.search, [
                v.noticeNumber,
                v.authority,
                v.subject,
                v.assignedLawyer,
              ]),
            )
            .toList(),
      );

  @override
  Stream<List<LegalCase>> watchCases(
    String companyId,
    CommandCenterFilter filter,
  ) => _query(companyId, 'legal_cases', filter)
      .orderBy('hearingDate')
      .limit(500)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => LegalCase.fromMap(d.id, d.data()))
            .where((v) => !v.isDeleted)
            .where(
              (v) => _search(filter.search, [
                v.caseNumber,
                v.court,
                v.authority,
                v.act,
                v.section,
                v.advocate,
              ]),
            )
            .toList(),
      );

  @override
  Stream<List<PolicyDocument>> watchPolicies(
    String companyId,
    CommandCenterFilter filter,
  ) => _query(companyId, 'policy_documents', filter)
      .orderBy('reviewDate')
      .limit(500)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => PolicyDocument.fromMap(d.id, d.data()))
            .where((v) => !v.isDeleted)
            .where(
              (v) => _search(filter.search, [
                v.title,
                v.category,
                v.version,
                v.ownerName,
              ]),
            )
            .toList(),
      );

  @override
  Stream<List<AuditFinding>> watchFindings(
    String companyId,
    CommandCenterFilter filter,
  ) => _query(companyId, 'audit_findings', filter)
      .orderBy('targetDate')
      .limit(500)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => AuditFinding.fromMap(d.id, d.data()))
            .where((v) => !v.isDeleted)
            .where(
              (v) =>
                  filter.riskLevel == null || v.riskLevel == filter.riskLevel,
            )
            .where(
              (v) => _search(filter.search, [
                v.observation,
                v.correctiveAction,
                v.capa,
                v.responsiblePersonName,
              ]),
            )
            .toList(),
      );

  @override
  Stream<List<ApprovalWorkflow>> watchWorkflows(String companyId) =>
      _c(companyId, 'approval_workflow')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => ApprovalWorkflow.fromMap(d.id, d.data()))
                .where((v) => !v.isDeleted)
                .toList(),
          );

  @override
  Stream<List<Map<String, dynamic>>> watchDocuments(
    String companyId,
    CommandCenterFilter filter,
  ) => _query(companyId, 'document_repository', filter)
      .orderBy('uploadedAt', descending: true)
      .limit(500)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((v) => v['isDeleted'] != true)
            .where(
              (v) => _search(filter.search, [
                v['title']?.toString() ?? '',
                v['originalFileName']?.toString() ?? '',
                v['category']?.toString() ?? '',
                v['ocrText']?.toString() ?? '',
              ]),
            )
            .toList(),
      );

  @override
  Stream<List<Map<String, dynamic>>> watchAudit(String companyId) =>
      _c(companyId, 'audit_trail')
          .orderBy('timestamp', descending: true)
          .limit(300)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  @override
  Stream<List<SecurityControl>> watchSecurityControls(String companyId) =>
      _c(companyId, 'security_controls')
          .orderBy('type')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => SecurityControl.fromMap(doc.id, doc.data()))
                .toList(),
          );

  Future<void> _save(
    String companyId,
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final doc = id.isEmpty
        ? _c(companyId, collection).doc()
        : _c(companyId, collection).doc(id);
    await doc.set({...data, 'id': doc.id}, SetOptions(merge: true));
  }

  @override
  Future<void> saveRisk(RiskRegisterItem value) =>
      _save(value.companyId, 'risk_register', value.id, value.toMap());

  @override
  Future<void> saveWorkflow(ApprovalWorkflow value) =>
      _save(value.companyId, 'approval_workflow', value.id, value.toMap());

  @override
  Future<void> saveNotice(GovernmentNotice value) =>
      _save(value.companyId, 'government_notices', value.id, value.toMap());

  @override
  Future<void> saveCase(LegalCase value) =>
      _save(value.companyId, 'legal_cases', value.id, value.toMap());

  @override
  Future<void> savePolicy(PolicyDocument value) =>
      _save(value.companyId, 'policy_documents', value.id, value.toMap());

  @override
  Future<void> saveFinding(AuditFinding value) =>
      _save(value.companyId, 'audit_findings', value.id, value.toMap());

  @override
  Future<void> saveSecurityControl(SecurityControl value) =>
      _save(value.companyId, 'security_controls', value.id, value.toMap());

  @override
  Future<void> writeAudit({
    required String companyId,
    required String userId,
    required String userName,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic> oldValues = const {},
    Map<String, dynamic> newValues = const {},
  }) async {
    final doc = _c(companyId, 'audit_trail').doc();
    await doc.set({
      'id': doc.id,
      'companyId': companyId,
      'userId': userId,
      'userName': userName,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'oldValues': oldValues,
      'newValues': newValues,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': null,
      'schemaVersion': 1,
    });
  }

  @override
  Future<CommandCenterMetrics> metrics(
    String companyId,
    CommandCenterFilter filter,
  ) async {
    final values = await Future.wait([
      watchCompliance(companyId, filter).first,
      watchRisks(companyId, filter).first,
      watchNotices(companyId, filter).first,
      watchCases(companyId, filter).first,
      watchPolicies(companyId, filter).first,
      watchFindings(companyId, filter).first,
    ]);
    final compliance = values[0] as List<ComplianceRecord>;
    final risks = values[1] as List<RiskRegisterItem>;
    final notices = values[2] as List<GovernmentNotice>;
    final cases = values[3] as List<LegalCase>;
    final policies = values[4] as List<PolicyDocument>;
    final findings = values[5] as List<AuditFinding>;
    final next30 = DateTime.now().add(const Duration(days: 30));

    return CommandCenterMetrics(
      totalCompliance: compliance.length,
      completed: compliance
          .where((v) => v.status == ComplianceStatus.completed)
          .length,
      pending: compliance
          .where(
            (v) =>
                v.status != ComplianceStatus.completed &&
                v.status != ComplianceStatus.waived,
          )
          .length,
      overdue: compliance.where((v) => v.isOverdue).length,
      criticalRisks: risks
          .where((v) => v.residualLevel == RiskLevel.critical)
          .length,
      governmentNotices: notices.length,
      openLegalCases: cases
          .where(
            (v) =>
                v.status != LegalCaseStatus.closed &&
                v.status != LegalCaseStatus.decided,
          )
          .length,
      auditFindings: findings
          .where((v) => v.status != AuditFindingStatus.closed)
          .length,
      policiesPendingReview: policies
          .where((v) => v.reviewDate.isBefore(next30))
          .length,
      financialExposure: risks.fold<num>(0, (a, b) => a + b.financialExposure),
      penaltyExposure: risks.fold<num>(0, (a, b) => a + b.penaltyExposure),
      legalExposure: risks.fold<num>(0, (a, b) => a + b.legalExposure),
    );
  }
}
