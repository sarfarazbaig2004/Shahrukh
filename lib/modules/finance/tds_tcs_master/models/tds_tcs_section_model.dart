import 'package:cloud_firestore/cloud_firestore.dart';

class TdsTcsSectionModel {
  const TdsTcsSectionModel({
    required this.id,
    required this.code,
    required this.nature,
    required this.deductor,
    required this.deductorCategory,
    required this.residency,
    required this.oldSection,
    required this.newSection,
    required this.rate,
    required this.threshold,
    required this.payee,
    required this.applicableForms,
    required this.category,
    required this.financialYear,
    required this.effectiveDate,
    required this.legalNote,
    required this.cbdtCirculars,
    required this.amendments,
    required this.examples,
    required this.caseLaws,
    required this.notifications,
    required this.historicalChanges,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.isDeleted = false,
  });

  final String id;
  final String code;
  final String nature;
  final String deductor;
  final String deductorCategory;
  final String residency;
  final String oldSection;
  final String newSection;
  final double rate;
  final double threshold;
  final String payee;
  final List<String> applicableForms;
  final String category;
  final String financialYear;
  final DateTime? effectiveDate;
  final String legalNote;
  final List<String> cbdtCirculars;
  final List<String> amendments;
  final List<String> examples;
  final List<String> caseLaws;
  final List<String> notifications;
  final List<String> historicalChanges;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;
  final bool isDeleted;

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(dynamic value) => value == true;

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _strings(dynamic value) {
    if (value is! Iterable) return const <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  factory TdsTcsSectionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return TdsTcsSectionModel(
      id: document.id,
      code: _string(data['code']),
      nature: _string(data['nature']),
      deductor: _string(data['deductor']),
      deductorCategory: _string(data['deductor_category']),
      residency: _string(data['residency']),
      oldSection: _string(data['old_section']),
      newSection: _string(data['new_section']),
      rate: _double(data['rate']),
      threshold: _double(data['threshold']),
      payee: _string(data['payee']),
      applicableForms: _strings(data['applicable_forms']),
      category: _string(data['category']).isEmpty
          ? 'Both'
          : _string(data['category']),
      financialYear: _string(data['financial_year']).isEmpty
          ? 'FY 2026–27'
          : _string(data['financial_year']),
      effectiveDate: _date(data['effective_date']),
      legalNote: _string(data['legal_note']),
      cbdtCirculars: _strings(data['cbdt_circulars']),
      amendments: _strings(data['amendments']),
      examples: _strings(data['examples']),
      caseLaws: _strings(data['case_laws']),
      notifications: _strings(data['notifications']),
      historicalChanges: _strings(data['historical_changes']),
      status: _string(data['status']).isEmpty
          ? 'Active'
          : _string(data['status']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
      createdBy: _string(data['created_by']),
      updatedBy: _string(data['updated_by']),
      isDeleted: _bool(data['is_deleted']),
    );
  }

  Map<String, dynamic> toFirestore({
    required String userUid,
    required bool isCreate,
  }) {
    return <String, dynamic>{
      'code': code.trim(),
      'nature': nature.trim(),
      'deductor': deductor.trim(),
      'deductor_category': deductorCategory.trim(),
      'residency': residency.trim(),
      'old_section': oldSection.trim(),
      'new_section': newSection.trim(),
      'rate': rate,
      'threshold': threshold,
      'payee': payee.trim(),
      'applicable_forms': applicableForms,
      'category': category,
      'financial_year': financialYear,
      'effective_date': effectiveDate == null
          ? null
          : Timestamp.fromDate(effectiveDate!),
      'legal_note': legalNote.trim(),
      'cbdt_circulars': cbdtCirculars,
      'amendments': amendments,
      'examples': examples,
      'case_laws': caseLaws,
      'notifications': notifications,
      'historical_changes': historicalChanges,
      'status': status,
      'is_deleted': isDeleted,
      if (isCreate) 'created_by': userUid,
      if (isCreate) 'created_at': FieldValue.serverTimestamp(),
      'updated_by': userUid,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  TdsTcsSectionModel copyWith({
    String? id,
    String? code,
    String? nature,
    String? deductor,
    String? deductorCategory,
    String? residency,
    String? oldSection,
    String? newSection,
    double? rate,
    double? threshold,
    String? payee,
    List<String>? applicableForms,
    String? category,
    String? financialYear,
    DateTime? effectiveDate,
    String? legalNote,
    List<String>? cbdtCirculars,
    List<String>? amendments,
    List<String>? examples,
    List<String>? caseLaws,
    List<String>? notifications,
    List<String>? historicalChanges,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool? isDeleted,
  }) {
    return TdsTcsSectionModel(
      id: id ?? this.id,
      code: code ?? this.code,
      nature: nature ?? this.nature,
      deductor: deductor ?? this.deductor,
      deductorCategory: deductorCategory ?? this.deductorCategory,
      residency: residency ?? this.residency,
      oldSection: oldSection ?? this.oldSection,
      newSection: newSection ?? this.newSection,
      rate: rate ?? this.rate,
      threshold: threshold ?? this.threshold,
      payee: payee ?? this.payee,
      applicableForms: applicableForms ?? this.applicableForms,
      category: category ?? this.category,
      financialYear: financialYear ?? this.financialYear,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      legalNote: legalNote ?? this.legalNote,
      cbdtCirculars: cbdtCirculars ?? this.cbdtCirculars,
      amendments: amendments ?? this.amendments,
      examples: examples ?? this.examples,
      caseLaws: caseLaws ?? this.caseLaws,
      notifications: notifications ?? this.notifications,
      historicalChanges: historicalChanges ?? this.historicalChanges,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
