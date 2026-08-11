import 'package:cloud_firestore/cloud_firestore.dart';

class ComplianceCalendarModel {
  const ComplianceCalendarModel({
    required this.id,
    required this.title,
    required this.description,
    required this.act,
    required this.section,
    required this.authority,
    required this.category,
    required this.frequency,
    required this.financialYear,
    required this.assessmentYear,
    required this.dueDate,
    required this.reminderDates,
    required this.priority,
    required this.status,
    required this.assignedEmployee,
    required this.department,
    required this.branch,
    required this.company,
    required this.penalty,
    required this.lateFee,
    required this.documentUrls,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String title;
  final String description;
  final String act;
  final String section;
  final String authority;
  final String category;
  final String frequency;
  final String financialYear;
  final String assessmentYear;
  final DateTime dueDate;
  final List<DateTime> reminderDates;
  final String priority;
  final String status;
  final String assignedEmployee;
  final String department;
  final String branch;
  final String company;
  final double penalty;
  final double lateFee;
  final List<String> documentUrls;
  final String notes;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _requiredDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _optionalDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<DateTime> _dates(dynamic value) {
    if (value is! Iterable) return const <DateTime>[];

    return value.map(_optionalDate).whereType<DateTime>().toList();
  }

  static List<String> _strings(dynamic value) {
    if (value is! Iterable) return const <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  factory ComplianceCalendarModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return ComplianceCalendarModel(
      id: document.id,
      title: _string(data['title']),
      description: _string(data['description']),
      act: _string(data['act']),
      section: _string(data['section']),
      authority: _string(data['authority']),
      category: _string(data['category']),
      frequency: _string(data['frequency']),
      financialYear: _string(data['financialYear']),
      assessmentYear: _string(data['assessmentYear']),
      dueDate: _requiredDate(data['dueDate']),
      reminderDates: _dates(data['reminderDates']),
      priority: _string(data['priority']).isEmpty
          ? 'Medium'
          : _string(data['priority']),
      status: _string(data['status']).isEmpty
          ? 'Pending'
          : _string(data['status']),
      assignedEmployee: _string(data['assignedEmployee']),
      department: _string(data['department']),
      branch: _string(data['branch']),
      company: _string(data['company']),
      penalty: _double(data['penalty']),
      lateFee: _double(data['lateFee']),
      documentUrls: _strings(data['documentUrls']),
      notes: _string(data['notes']),
      createdBy: _string(data['createdBy']),
      createdAt: _optionalDate(data['createdAt']),
      updatedAt: _optionalDate(data['updatedAt']),
      isDeleted: data['isDeleted'] == true,
    );
  }

  Map<String, dynamic> toFirestore({
    required String userUid,
    required bool isCreate,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'act': act.trim(),
      'section': section.trim(),
      'authority': authority.trim(),
      'category': category,
      'frequency': frequency,
      'financialYear': financialYear,
      'assessmentYear': assessmentYear,
      'dueDate': Timestamp.fromDate(dueDate),
      'reminderDates': reminderDates.map(Timestamp.fromDate).toList(),
      'priority': priority,
      'status': status,
      'assignedEmployee': assignedEmployee.trim(),
      'department': department.trim(),
      'branch': branch.trim(),
      'company': company.trim(),
      'penalty': penalty,
      'lateFee': lateFee,
      'documentUrls': documentUrls,
      'notes': notes.trim(),
      'isDeleted': isDeleted,
      if (isCreate) 'createdBy': userUid,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ComplianceCalendarModel copyWith({
    String? id,
    String? title,
    String? description,
    String? act,
    String? section,
    String? authority,
    String? category,
    String? frequency,
    String? financialYear,
    String? assessmentYear,
    DateTime? dueDate,
    List<DateTime>? reminderDates,
    String? priority,
    String? status,
    String? assignedEmployee,
    String? department,
    String? branch,
    String? company,
    double? penalty,
    double? lateFee,
    List<String>? documentUrls,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ComplianceCalendarModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      act: act ?? this.act,
      section: section ?? this.section,
      authority: authority ?? this.authority,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      financialYear: financialYear ?? this.financialYear,
      assessmentYear: assessmentYear ?? this.assessmentYear,
      dueDate: dueDate ?? this.dueDate,
      reminderDates: reminderDates ?? this.reminderDates,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedEmployee: assignedEmployee ?? this.assignedEmployee,
      department: department ?? this.department,
      branch: branch ?? this.branch,
      company: company ?? this.company,
      penalty: penalty ?? this.penalty,
      lateFee: lateFee ?? this.lateFee,
      documentUrls: documentUrls ?? this.documentUrls,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
