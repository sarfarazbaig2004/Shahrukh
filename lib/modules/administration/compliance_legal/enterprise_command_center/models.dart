import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ComplianceStatus { pending, inProgress, completed, overdue, waived }

enum RiskLevel { low, medium, high, critical }

enum NoticeStatus {
  received,
  underReview,
  assigned,
  replyInProgress,
  replySubmitted,
  hearingScheduled,
  resolved,
  closed,
  overdue,
}

enum LegalCaseStatus {
  open,
  underReview,
  hearingScheduled,
  orderReserved,
  decided,
  appealed,
  closed,
}

enum PolicyStatus {
  draft,
  underReview,
  approved,
  published,
  superseded,
  archived,
}

enum AuditFindingStatus {
  open,
  actionInProgress,
  evidenceSubmitted,
  verified,
  closed,
}

enum SecurityControlType {
  twoFactorAuthentication,
  singleSignOn,
  passwordPolicy,
  sessionTimeout,
  deviceManagement,
  encryption,
  backup,
  disasterRecovery,
  loginHistory,
  securityAlerts,
}

DateTime? eccDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String eccEnum(Object value) => value.toString().split('.').last;

T eccParse<T>(Iterable<T> values, dynamic raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (eccEnum(value as Object) == name) {
      return value;
    }
  }
  return fallback;
}

@immutable
class CommandCenterFilter {
  const CommandCenterFilter({
    this.search = '',
    this.branchId,
    this.businessUnit,
    this.financialYear,
    this.department,
    this.status,
    this.riskLevel,
    this.dateFrom,
    this.dateTo,
  });

  final String search;
  final String? branchId;
  final String? businessUnit;
  final String? financialYear;
  final String? department;
  final String? status;
  final RiskLevel? riskLevel;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  int get count => [
    search.trim().isNotEmpty,
    branchId != null,
    businessUnit != null,
    financialYear != null,
    department != null,
    status != null,
    riskLevel != null,
    dateFrom != null || dateTo != null,
  ].where((v) => v).length;

  CommandCenterFilter copyWith({
    String? search,
    String? branchId,
    bool clearBranch = false,
    String? businessUnit,
    bool clearBusinessUnit = false,
    String? financialYear,
    bool clearFinancialYear = false,
    String? department,
    bool clearDepartment = false,
    String? status,
    bool clearStatus = false,
    RiskLevel? riskLevel,
    bool clearRiskLevel = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDates = false,
    bool clear = false,
  }) {
    if (clear) {
      return const CommandCenterFilter();
    }
    return CommandCenterFilter(
      search: search ?? this.search,
      branchId: clearBranch ? null : branchId ?? this.branchId,
      businessUnit: clearBusinessUnit
          ? null
          : businessUnit ?? this.businessUnit,
      financialYear: clearFinancialYear
          ? null
          : financialYear ?? this.financialYear,
      department: clearDepartment ? null : department ?? this.department,
      status: clearStatus ? null : status ?? this.status,
      riskLevel: clearRiskLevel ? null : riskLevel ?? this.riskLevel,
      dateFrom: clearDates ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDates ? null : dateTo ?? this.dateTo,
    );
  }
}

@immutable
class ComplianceRecord {
  const ComplianceRecord({
    required this.id,
    required this.referenceNumber,
    required this.title,
    required this.companyId,
    required this.financialYear,
    required this.department,
    required this.ownerId,
    required this.ownerName,
    required this.status,
    required this.riskLevel,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.branchId,
    this.businessUnit,
    this.category = '',
    this.progress = 0,
    this.financialExposure = 0,
    this.penaltyExposure = 0,
    this.isDeleted = false,
  });

  final String id;
  final String referenceNumber;
  final String title;
  final String companyId;
  final String? branchId;
  final String? businessUnit;
  final String financialYear;
  final String department;
  final String category;
  final String ownerId;
  final String ownerName;
  final ComplianceStatus status;
  final RiskLevel riskLevel;
  final DateTime dueDate;
  final double progress;
  final num financialExposure;
  final num penaltyExposure;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  bool get isOverdue =>
      status != ComplianceStatus.completed &&
      status != ComplianceStatus.waived &&
      dueDate.isBefore(DateTime.now());

  factory ComplianceRecord.fromMap(String id, Map<String, dynamic> m) =>
      ComplianceRecord(
        id: id,
        referenceNumber: m['referenceNumber']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        companyId: m['companyId']?.toString() ?? '',
        branchId: m['branchId']?.toString(),
        businessUnit: m['businessUnit']?.toString(),
        financialYear: m['financialYear']?.toString() ?? '',
        department: m['department']?.toString() ?? '',
        category: m['category']?.toString() ?? '',
        ownerId: m['ownerId']?.toString() ?? '',
        ownerName: m['ownerName']?.toString() ?? '',
        status: eccParse(
          ComplianceStatus.values,
          m['status'],
          ComplianceStatus.pending,
        ),
        riskLevel: eccParse(RiskLevel.values, m['riskLevel'], RiskLevel.medium),
        dueDate: eccDate(m['dueDate']) ?? DateTime.now(),
        progress: (m['progress'] as num? ?? 0).toDouble(),
        financialExposure: m['financialExposure'] as num? ?? 0,
        penaltyExposure: m['penaltyExposure'] as num? ?? 0,
        createdAt: eccDate(m['createdAt']) ?? DateTime.now(),
        updatedAt: eccDate(m['updatedAt']) ?? DateTime.now(),
        isDeleted: m['isDeleted'] == true,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'referenceNumber': referenceNumber,
    'title': title,
    'companyId': companyId,
    'branchId': branchId,
    'businessUnit': businessUnit,
    'financialYear': financialYear,
    'department': department,
    'category': category,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'status': eccEnum(status),
    'riskLevel': eccEnum(riskLevel),
    'dueDate': Timestamp.fromDate(dueDate),
    'progress': progress,
    'financialExposure': financialExposure,
    'penaltyExposure': penaltyExposure,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isDeleted': isDeleted,
    'schemaVersion': 1,
  };
}

@immutable
class RiskRegisterItem {
  const RiskRegisterItem({
    required this.id,
    required this.companyId,
    required this.title,
    required this.category,
    required this.department,
    required this.ownerName,
    required this.inherentLikelihood,
    required this.inherentImpact,
    required this.residualLikelihood,
    required this.residualImpact,
    required this.mitigationPlan,
    required this.reviewDate,
    required this.createdAt,
    required this.updatedAt,
    this.branchId,
    this.financialExposure = 0,
    this.penaltyExposure = 0,
    this.legalExposure = 0,
    this.isDeleted = false,
  });

  final String id;
  final String companyId;
  final String? branchId;
  final String title;
  final String category;
  final String department;
  final String ownerName;
  final int inherentLikelihood;
  final int inherentImpact;
  final int residualLikelihood;
  final int residualImpact;
  final String mitigationPlan;
  final DateTime reviewDate;
  final num financialExposure;
  final num penaltyExposure;
  final num legalExposure;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  int get inherentScore => inherentLikelihood * inherentImpact;
  int get residualScore => residualLikelihood * residualImpact;
  RiskLevel get residualLevel => levelFor(residualScore);

  static RiskLevel levelFor(int score) {
    if (score >= 20) {
      return RiskLevel.critical;
    }
    if (score >= 12) {
      return RiskLevel.high;
    }
    if (score >= 6) {
      return RiskLevel.medium;
    }
    return RiskLevel.low;
  }

  factory RiskRegisterItem.fromMap(String id, Map<String, dynamic> m) =>
      RiskRegisterItem(
        id: id,
        companyId: m['companyId']?.toString() ?? '',
        branchId: m['branchId']?.toString(),
        title: m['title']?.toString() ?? '',
        category: m['category']?.toString() ?? '',
        department: m['department']?.toString() ?? '',
        ownerName: m['ownerName']?.toString() ?? '',
        inherentLikelihood: m['inherentLikelihood'] as int? ?? 1,
        inherentImpact: m['inherentImpact'] as int? ?? 1,
        residualLikelihood: m['residualLikelihood'] as int? ?? 1,
        residualImpact: m['residualImpact'] as int? ?? 1,
        mitigationPlan: m['mitigationPlan']?.toString() ?? '',
        reviewDate: eccDate(m['reviewDate']) ?? DateTime.now(),
        financialExposure: m['financialExposure'] as num? ?? 0,
        penaltyExposure: m['penaltyExposure'] as num? ?? 0,
        legalExposure: m['legalExposure'] as num? ?? 0,
        createdAt: eccDate(m['createdAt']) ?? DateTime.now(),
        updatedAt: eccDate(m['updatedAt']) ?? DateTime.now(),
        isDeleted: m['isDeleted'] == true,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyId': companyId,
    'branchId': branchId,
    'title': title,
    'category': category,
    'department': department,
    'ownerName': ownerName,
    'inherentLikelihood': inherentLikelihood,
    'inherentImpact': inherentImpact,
    'residualLikelihood': residualLikelihood,
    'residualImpact': residualImpact,
    'mitigationPlan': mitigationPlan,
    'reviewDate': Timestamp.fromDate(reviewDate),
    'financialExposure': financialExposure,
    'penaltyExposure': penaltyExposure,
    'legalExposure': legalExposure,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isDeleted': isDeleted,
    'schemaVersion': 1,
  };
}

@immutable
class WorkflowLevel {
  const WorkflowLevel({
    required this.id,
    required this.name,
    required this.order,
    required this.approverRole,
    this.approverUserId,
    this.reminderHours = 24,
    this.escalationHours = 48,
  });

  final String id;
  final String name;
  final int order;
  final String approverRole;
  final String? approverUserId;
  final int reminderHours;
  final int escalationHours;

  factory WorkflowLevel.fromMap(Map<String, dynamic> m) => WorkflowLevel(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    order: m['order'] as int? ?? 0,
    approverRole: m['approverRole']?.toString() ?? '',
    approverUserId: m['approverUserId']?.toString(),
    reminderHours: m['reminderHours'] as int? ?? 24,
    escalationHours: m['escalationHours'] as int? ?? 48,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'order': order,
    'approverRole': approverRole,
    'approverUserId': approverUserId,
    'reminderHours': reminderHours,
    'escalationHours': escalationHours,
  };
}

@immutable
class ApprovalWorkflow {
  const ApprovalWorkflow({
    required this.id,
    required this.companyId,
    required this.name,
    required this.entityType,
    required this.levels,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.enabled = true,
    this.isDeleted = false,
  });

  final String id;
  final String companyId;
  final String name;
  final String entityType;
  final List<WorkflowLevel> levels;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool enabled;
  final bool isDeleted;

  factory ApprovalWorkflow.fromMap(String id, Map<String, dynamic> m) =>
      ApprovalWorkflow(
        id: id,
        companyId: m['companyId']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        entityType: m['entityType']?.toString() ?? '',
        levels: m['levels'] is List
            ? (m['levels'] as List)
                  .whereType<Map>()
                  .map(
                    (v) => WorkflowLevel.fromMap(Map<String, dynamic>.from(v)),
                  )
                  .toList()
            : const [],
        createdBy: m['createdBy']?.toString() ?? '',
        createdAt: eccDate(m['createdAt']) ?? DateTime.now(),
        updatedAt: eccDate(m['updatedAt']) ?? DateTime.now(),
        enabled: m['enabled'] != false,
        isDeleted: m['isDeleted'] == true,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyId': companyId,
    'name': name,
    'entityType': entityType,
    'levels': levels.map((e) => e.toMap()).toList(),
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'enabled': enabled,
    'isDeleted': isDeleted,
    'schemaVersion': 1,
  };
}

@immutable
class GovernmentNotice {
  const GovernmentNotice({
    required this.id,
    required this.companyId,
    required this.noticeNumber,
    required this.authority,
    required this.subject,
    required this.issueDate,
    required this.replyDueDate,
    required this.status,
    required this.assignedLawyer,
    required this.createdAt,
    required this.updatedAt,
    this.hearingDate,
    this.documents = const [],
    this.replies = const [],
    this.orders = const [],
    this.appeals = const [],
    this.isDeleted = false,
  });

  final String id;
  final String companyId;
  final String noticeNumber;
  final String authority;
  final String subject;
  final DateTime issueDate;
  final DateTime replyDueDate;
  final DateTime? hearingDate;
  final NoticeStatus status;
  final String assignedLawyer;
  final List<String> documents;
  final List<String> replies;
  final List<String> orders;
  final List<String> appeals;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  bool get isOverdue =>
      status != NoticeStatus.closed &&
      status != NoticeStatus.resolved &&
      replyDueDate.isBefore(DateTime.now());

  factory GovernmentNotice.fromMap(String id, Map<String, dynamic> m) =>
      GovernmentNotice(
        id: id,
        companyId: m['companyId']?.toString() ?? '',
        noticeNumber: m['noticeNumber']?.toString() ?? '',
        authority: m['authority']?.toString() ?? '',
        subject: m['subject']?.toString() ?? '',
        issueDate: eccDate(m['issueDate']) ?? DateTime.now(),
        replyDueDate: eccDate(m['replyDueDate']) ?? DateTime.now(),
        hearingDate: eccDate(m['hearingDate']),
        status: eccParse(
          NoticeStatus.values,
          m['status'],
          NoticeStatus.received,
        ),
        assignedLawyer: m['assignedLawyer']?.toString() ?? '',
        documents: m['documents'] is List
            ? (m['documents'] as List).map((e) => e.toString()).toList()
            : const [],
        replies: m['replies'] is List
            ? (m['replies'] as List).map((e) => e.toString()).toList()
            : const [],
        orders: m['orders'] is List
            ? (m['orders'] as List).map((e) => e.toString()).toList()
            : const [],
        appeals: m['appeals'] is List
            ? (m['appeals'] as List).map((e) => e.toString()).toList()
            : const [],
        createdAt: eccDate(m['createdAt']) ?? DateTime.now(),
        updatedAt: eccDate(m['updatedAt']) ?? DateTime.now(),
        isDeleted: m['isDeleted'] == true,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyId': companyId,
    'noticeNumber': noticeNumber,
    'authority': authority,
    'subject': subject,
    'issueDate': Timestamp.fromDate(issueDate),
    'replyDueDate': Timestamp.fromDate(replyDueDate),
    'hearingDate': hearingDate == null
        ? null
        : Timestamp.fromDate(hearingDate!),
    'status': eccEnum(status),
    'assignedLawyer': assignedLawyer,
    'documents': documents,
    'replies': replies,
    'orders': orders,
    'appeals': appeals,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isDeleted': isDeleted,
    'schemaVersion': 1,
  };
}

@immutable
class LegalCase {
  const LegalCase({
    required this.id,
    required this.companyId,
    required this.caseNumber,
    required this.court,
    required this.authority,
    required this.act,
    required this.section,
    required this.advocate,
    required this.caseType,
    required this.status,
    required this.hearingDate,
    required this.createdAt,
    required this.updatedAt,
    this.expenses = 0,
    this.remarks = '',
    this.isDeleted = false,
  });

  final String id;
  final String companyId;
  final String caseNumber;
  final String court;
  final String authority;
  final String act;
  final String section;
  final String advocate;
  final String caseType;
  final LegalCaseStatus status;
  final DateTime hearingDate;
  final num expenses;
  final String remarks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  factory LegalCase.fromMap(String id, Map<String, dynamic> m) => LegalCase(
    id: id,
    companyId: m['companyId']?.toString() ?? '',
    caseNumber: m['caseNumber']?.toString() ?? '',
    court: m['court']?.toString() ?? '',
    authority: m['authority']?.toString() ?? '',
    act: m['act']?.toString() ?? '',
    section: m['section']?.toString() ?? '',
    advocate: m['advocate']?.toString() ?? '',
    caseType: m['caseType']?.toString() ?? '',
    status: eccParse(LegalCaseStatus.values, m['status'], LegalCaseStatus.open),
    hearingDate: eccDate(m['hearingDate']) ?? DateTime.now(),
    expenses: m['expenses'] as num? ?? 0,
    remarks: m['remarks']?.toString() ?? '',
    createdAt: eccDate(m['createdAt']) ?? DateTime.now(),
    updatedAt: eccDate(m['updatedAt']) ?? DateTime.now(),
    isDeleted: m['isDeleted'] == true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyId': companyId,
    'caseNumber': caseNumber,
    'court': court,
    'authority': authority,
    'act': act,
    'section': section,
    'advocate': advocate,
    'caseType': caseType,
    'status': eccEnum(status),
    'hearingDate': Timestamp.fromDate(hearingDate),
    'expenses': expenses,
    'remarks': remarks,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isDeleted': isDeleted,
    'schemaVersion': 1,
  };
}

@immutable
class PolicyDocument {
  const PolicyDocument({
    required this.id,
    required this.companyId,
    required this.title,
    required this.category,
    required this.version,
    required this.reviewDate,
    required this.status,
    required this.ownerName,
    required this.createdAt,
    required this.updatedAt,
    this.acknowledgementRequired = false,
    this.acknowledgedUserIds = const [],
    this.isDeleted = false,
  });

  final String id;
  final String companyId;
  final String title;
  final String category;
  final String version;
  final DateTime reviewDate;
  final PolicyStatus status;
  final String ownerName;
  final bool acknowledgementRequired;
  final List<String> acknowledgedUserIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  factory PolicyDocument.fromMap(String id, Map<String, dynamic> m) =>
      PolicyDocument(
        id: id,
        companyId: m['companyId']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        category: m['category']?.toString() ?? '',
        version: m['version']?.toString() ?? '1.0',
        reviewDate: eccDate(m['reviewDate']) ?? DateTime.now(),
        status: eccParse(PolicyStatus.values, m['status'], PolicyStatus.draft),
        ownerName: m['ownerName']?.toString() ?? '',
        acknowledgementRequired: m['acknowledgementRequired'] == true,
        acknowledgedUserIds: m['acknowledgedUserIds'] is List
            ? (m['acknowledgedUserIds'] as List)
                  .map((e) => e.toString())
                  .toList()
            : const [],
        createdAt: eccDate(m['createdAt']) ?? DateTime.now(),
        updatedAt: eccDate(m['updatedAt']) ?? DateTime.now(),
        isDeleted: m['isDeleted'] == true,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyId': companyId,
    'title': title,
    'category': category,
    'version': version,
    'reviewDate': Timestamp.fromDate(reviewDate),
    'status': eccEnum(status),
    'ownerName': ownerName,
    'acknowledgementRequired': acknowledgementRequired,
    'acknowledgedUserIds': acknowledgedUserIds,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isDeleted': isDeleted,
    'schemaVersion': 1,
  };
}

@immutable
class AuditFinding {
  const AuditFinding({
    required this.id,
    required this.companyId,
    required this.observation,
    required this.riskLevel,
    required this.correctiveAction,
    required this.capa,
    required this.responsiblePersonName,
    required this.targetDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String companyId;
  final String observation;
  final RiskLevel riskLevel;
  final String correctiveAction;
  final String capa;
  final String responsiblePersonName;
  final DateTime targetDate;
  final AuditFindingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  factory AuditFinding.fromMap(String id, Map<String, dynamic> m) =>
      AuditFinding(
        id: id,
        companyId: m['companyId']?.toString() ?? '',
        observation: m['observation']?.toString() ?? '',
        riskLevel: eccParse(RiskLevel.values, m['riskLevel'], RiskLevel.medium),
        correctiveAction: m['correctiveAction']?.toString() ?? '',
        capa: m['capa']?.toString() ?? '',
        responsiblePersonName: m['responsiblePersonName']?.toString() ?? '',
        targetDate: eccDate(m['targetDate']) ?? DateTime.now(),
        status: eccParse(
          AuditFindingStatus.values,
          m['status'],
          AuditFindingStatus.open,
        ),
        createdAt: eccDate(m['createdAt']) ?? DateTime.now(),
        updatedAt: eccDate(m['updatedAt']) ?? DateTime.now(),
        isDeleted: m['isDeleted'] == true,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyId': companyId,
    'observation': observation,
    'riskLevel': eccEnum(riskLevel),
    'correctiveAction': correctiveAction,
    'capa': capa,
    'responsiblePersonName': responsiblePersonName,
    'targetDate': Timestamp.fromDate(targetDate),
    'status': eccEnum(status),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isDeleted': isDeleted,
    'schemaVersion': 1,
  };
}

@immutable
class SecurityControl {
  const SecurityControl({
    required this.id,
    required this.companyId,
    required this.type,
    required this.enabled,
    required this.enforcementMode,
    required this.updatedBy,
    required this.updatedAt,
    this.configuration = const <String, dynamic>{},
  });

  final String id;
  final String companyId;
  final SecurityControlType type;
  final bool enabled;
  final String enforcementMode;
  final Map<String, dynamic> configuration;
  final String updatedBy;
  final DateTime updatedAt;

  factory SecurityControl.fromMap(String id, Map<String, dynamic> map) {
    return SecurityControl(
      id: id,
      companyId: map['companyId']?.toString() ?? '',
      type: eccParse(
        SecurityControlType.values,
        map['type'],
        SecurityControlType.passwordPolicy,
      ),
      enabled: map['enabled'] == true,
      enforcementMode: map['enforcementMode']?.toString() ?? 'monitor',
      configuration: map['configuration'] is Map
          ? Map<String, dynamic>.from(map['configuration'] as Map)
          : const <String, dynamic>{},
      updatedBy: map['updatedBy']?.toString() ?? '',
      updatedAt: eccDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'companyId': companyId,
    'type': eccEnum(type),
    'enabled': enabled,
    'enforcementMode': enforcementMode,
    'configuration': configuration,
    'updatedBy': updatedBy,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'schemaVersion': 1,
  };
}

@immutable
class CommandCenterMetrics {
  const CommandCenterMetrics({
    this.totalCompliance = 0,
    this.completed = 0,
    this.pending = 0,
    this.overdue = 0,
    this.criticalRisks = 0,
    this.governmentNotices = 0,
    this.openLegalCases = 0,
    this.auditFindings = 0,
    this.policiesPendingReview = 0,
    this.financialExposure = 0,
    this.penaltyExposure = 0,
    this.legalExposure = 0,
  });

  final int totalCompliance;
  final int completed;
  final int pending;
  final int overdue;
  final int criticalRisks;
  final int governmentNotices;
  final int openLegalCases;
  final int auditFindings;
  final int policiesPendingReview;
  final num financialExposure;
  final num penaltyExposure;
  final num legalExposure;

  double get healthPercent =>
      totalCompliance == 0 ? 0 : completed * 100 / totalCompliance;
  double get score => (healthPercent - criticalRisks * 4 - overdue * 1.5)
      .clamp(0, 100)
      .toDouble();
}
