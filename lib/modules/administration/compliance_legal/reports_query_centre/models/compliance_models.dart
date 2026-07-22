import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? complianceDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value?.toString() ?? '');
}

enum ComplianceRecordType {
  compliance,
  report,
  query,
  notice,
  legalCase,
  document,
}

class ComplianceRecord {
  const ComplianceRecord({
    required this.id,
    required this.type,
    required this.referenceNumber,
    required this.title,
    required this.status,
    required this.priority,
    required this.companyId,
    this.description = '',
    this.branchId = '',
    this.department = '',
    this.category = '',
    this.authority = '',
    this.assignedTo = '',
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.penalty = 0,
    this.isDeleted = false,
    this.sourceModule = '',
    this.sourceRecordId = '',
  });
  final String id,
      referenceNumber,
      title,
      status,
      priority,
      companyId,
      description,
      branchId,
      department,
      category,
      authority,
      assignedTo,
      sourceModule,
      sourceRecordId;
  final ComplianceRecordType type;
  final DateTime? dueDate, createdAt, updatedAt;
  final double penalty;
  final bool isDeleted;

  bool get isCompleted => const {
    'completed',
    'resolved',
    'closed',
    'reply submitted',
  }.contains(status.toLowerCase());
  bool get isOverdue =>
      !isCompleted && dueDate != null && dueDate!.isBefore(DateTime.now());
  bool get isCritical => priority.toLowerCase() == 'critical';
  factory ComplianceRecord.fromMap(
    String id,
    Map<String, dynamic> map,
    ComplianceRecordType type,
  ) => ComplianceRecord(
    id: id,
    type: type,
    referenceNumber:
        (map['referenceNumber'] ??
                map['queryNumber'] ??
                map['noticeNumber'] ??
                map['caseNumber'] ??
                id)
            .toString(),
    title: (map['title'] ?? map['subject'] ?? map['reportName'] ?? 'Untitled')
        .toString(),
    status: (map['status'] ?? map['currentStatus'] ?? 'Pending').toString(),
    priority: (map['priority'] ?? 'Medium').toString(),
    companyId: (map['companyId'] ?? '').toString(),
    description: (map['description'] ?? '').toString(),
    branchId: (map['branchId'] ?? '').toString(),
    department: (map['departmentName'] ?? map['department'] ?? '').toString(),
    category: (map['category'] ?? map['complianceCategory'] ?? '').toString(),
    authority: (map['authority'] ?? '').toString(),
    assignedTo:
        (map['assignedToName'] ??
                map['assignedEmployeeName'] ??
                map['assignedEmployee'] ??
                '')
            .toString(),
    dueDate: complianceDate(map['dueDate']),
    createdAt: complianceDate(map['createdAt'] ?? map['createdAtTimestamp']),
    updatedAt: complianceDate(map['updatedAt'] ?? map['updatedAtTimestamp']),
    penalty: (map['penalty'] as num?)?.toDouble() ?? 0,
    isDeleted: map['isDeleted'] == true,
    sourceModule: (map['sourceModule'] ?? '').toString(),
    sourceRecordId: (map['sourceRecordId'] ?? '').toString(),
  );
}

class ComplianceQuery {
  const ComplianceQuery({
    required this.id,
    required this.queryNumber,
    required this.subject,
    required this.description,
    required this.companyId,
    required this.createdByUserId,
    required this.createdByName,
    this.branchId = '',
    this.departmentId = '',
    this.complianceCategory = '',
    this.priority = 'Medium',
    this.assignedToUserId = '',
    this.assignedToName = '',
    this.status = 'Open',
    this.dueDate,
    this.resolutionDate,
    this.remarks = const [],
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy = '',
  });
  static const statuses = [
    'Open',
    'Assigned',
    'In Progress',
    'Waiting for Client',
    'Resolved',
    'Closed',
    'Rejected',
  ];
  static const priorities = ['Critical', 'High', 'Medium', 'Low'];
  final String id,
      queryNumber,
      subject,
      description,
      companyId,
      branchId,
      departmentId,
      complianceCategory,
      priority,
      assignedToUserId,
      assignedToName,
      createdByUserId,
      createdByName,
      status,
      deletedBy;
  final DateTime? dueDate, resolutionDate, createdAt, updatedAt, deletedAt;
  final List<String> remarks, attachments;
  final bool isDeleted;
  bool canTransitionTo(String next) =>
      status == next ||
      <String, List<String>>{
            'Open': ['Assigned', 'In Progress', 'Rejected'],
            'Assigned': ['In Progress', 'Waiting for Client', 'Rejected'],
            'In Progress': ['Waiting for Client', 'Resolved', 'Rejected'],
            'Waiting for Client': ['In Progress', 'Resolved'],
            'Resolved': ['Closed', 'In Progress'],
            'Closed': ['In Progress'],
            'Rejected': ['Open'],
          }[status]?.contains(next) ==
          true;
  factory ComplianceQuery.fromMap(String id, Map<String, dynamic> map) =>
      ComplianceQuery(
        id: id,
        queryNumber: (map['queryNumber'] ?? '').toString(),
        subject: (map['subject'] ?? '').toString(),
        description: (map['description'] ?? '').toString(),
        companyId: (map['companyId'] ?? '').toString(),
        branchId: (map['branchId'] ?? '').toString(),
        departmentId: (map['departmentId'] ?? '').toString(),
        complianceCategory: (map['complianceCategory'] ?? '').toString(),
        priority: (map['priority'] ?? 'Medium').toString(),
        assignedToUserId: (map['assignedToUserId'] ?? '').toString(),
        assignedToName: (map['assignedToName'] ?? '').toString(),
        createdByUserId: (map['createdByUserId'] ?? '').toString(),
        createdByName: (map['createdByName'] ?? '').toString(),
        status: (map['status'] ?? 'Open').toString(),
        dueDate: complianceDate(map['dueDate']),
        resolutionDate: complianceDate(map['resolutionDate']),
        remarks: List<String>.from(map['remarks'] ?? const []),
        attachments: List<String>.from(map['attachments'] ?? const []),
        createdAt: complianceDate(map['createdAt']),
        updatedAt: complianceDate(map['updatedAt']),
        isDeleted: map['isDeleted'] == true,
        deletedAt: complianceDate(map['deletedAt']),
        deletedBy: (map['deletedBy'] ?? '').toString(),
      );
  Map<String, dynamic> toMap() => {
    'id': id,
    'queryNumber': queryNumber,
    'subject': subject.trim(),
    'description': description.trim(),
    'companyId': companyId,
    'branchId': branchId,
    'departmentId': departmentId,
    'complianceCategory': complianceCategory,
    'priority': priority,
    'assignedToUserId': assignedToUserId,
    'assignedToName': assignedToName,
    'createdByUserId': createdByUserId,
    'createdByName': createdByName,
    'status': status,
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'resolutionDate': resolutionDate == null
        ? null
        : Timestamp.fromDate(resolutionDate!),
    'remarks': remarks,
    'attachments': attachments,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    'deletedBy': deletedBy,
    'schemaVersion': 1,
  };
  ComplianceQuery copyWith({
    String? id,
    String? queryNumber,
    String? subject,
    String? description,
    String? priority,
    String? status,
    String? assignedToUserId,
    String? assignedToName,
    DateTime? dueDate,
    DateTime? resolutionDate,
    List<String>? remarks,
    List<String>? attachments,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
  }) => ComplianceQuery(
    id: id ?? this.id,
    queryNumber: queryNumber ?? this.queryNumber,
    subject: subject ?? this.subject,
    description: description ?? this.description,
    companyId: companyId,
    branchId: branchId,
    departmentId: departmentId,
    complianceCategory: complianceCategory,
    priority: priority ?? this.priority,
    assignedToUserId: assignedToUserId ?? this.assignedToUserId,
    assignedToName: assignedToName ?? this.assignedToName,
    createdByUserId: createdByUserId,
    createdByName: createdByName,
    status: status ?? this.status,
    dueDate: dueDate ?? this.dueDate,
    resolutionDate: resolutionDate ?? this.resolutionDate,
    remarks: remarks ?? this.remarks,
    attachments: attachments ?? this.attachments,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt ?? this.deletedAt,
    deletedBy: deletedBy ?? this.deletedBy,
  );
}

class ReportFilters {
  const ReportFilters({
    this.search = '',
    this.financialYear = '',
    this.branch = '',
    this.department = '',
    this.category = '',
    this.authority = '',
    this.status = '',
    this.priority = '',
    this.from,
    this.to,
  });
  final String search,
      financialYear,
      branch,
      department,
      category,
      authority,
      status,
      priority;
  final DateTime? from, to;
  int get count =>
      [
        search,
        financialYear,
        branch,
        department,
        category,
        authority,
        status,
        priority,
      ].where((e) => e.isNotEmpty).length +
      (from == null ? 0 : 1) +
      (to == null ? 0 : 1);
  bool matches(ComplianceRecord r) {
    final q = search.toLowerCase();
    return (q.isEmpty ||
            r.title.toLowerCase().contains(q) ||
            r.referenceNumber.toLowerCase().contains(q)) &&
        (branch.isEmpty || r.branchId == branch) &&
        (department.isEmpty || r.department == department) &&
        (category.isEmpty || r.category == category) &&
        (authority.isEmpty || r.authority == authority) &&
        (status.isEmpty || r.status == status) &&
        (priority.isEmpty || r.priority == priority) &&
        (from == null || r.dueDate == null || !r.dueDate!.isBefore(from!)) &&
        (to == null || r.dueDate == null || !r.dueDate!.isAfter(to!));
  }

  ReportFilters copyWith({
    String? search,
    String? financialYear,
    String? branch,
    String? department,
    String? category,
    String? authority,
    String? status,
    String? priority,
    DateTime? from,
    DateTime? to,
  }) => ReportFilters(
    search: search ?? this.search,
    financialYear: financialYear ?? this.financialYear,
    branch: branch ?? this.branch,
    department: department ?? this.department,
    category: category ?? this.category,
    authority: authority ?? this.authority,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    from: from ?? this.from,
    to: to ?? this.to,
  );
}

class ReportSchedule {
  const ReportSchedule({
    required this.id,
    required this.recurrence,
    required this.nextRunAt,
    this.enabled = false,
  });
  final String id, recurrence;
  final DateTime nextRunAt;
  final bool enabled;
  DateTime followingRun() => switch (recurrence.toLowerCase()) {
    'daily' => nextRunAt.add(const Duration(days: 1)),
    'weekly' => nextRunAt.add(const Duration(days: 7)),
    'monthly' => DateTime(nextRunAt.year, nextRunAt.month + 1, nextRunAt.day),
    'quarterly' => DateTime(nextRunAt.year, nextRunAt.month + 3, nextRunAt.day),
    _ => nextRunAt,
  };
}
