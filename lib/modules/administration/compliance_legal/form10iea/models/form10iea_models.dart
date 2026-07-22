import 'package:cloud_firestore/cloud_firestore.dart';

enum Form10IEAFinderMode { uploadBased, answerBased }

enum Form10IEAAssesseeMode { single, multiple }

enum Form10IEAResultStatus {
  formRequired,
  formNotRequired,
  optionAvailable,
  optionRestricted,
  insufficientInformation,
  conflictingInformation,
  needsReview,
}

enum Form10IEAExtractionStatus {
  idle,
  fileSelected,
  reading,
  extracted,
  awaitingConfirmation,
  confirmed,
  extractionFailed,
  needsReview,
}

enum Form10IEAConfirmationStatus { pending, confirmed }

enum Form10IEAItrType { itr1, itr2, itr3, itr4 }

extension Form10IEAItrTypeX on Form10IEAItrType {
  String get label {
    switch (this) {
      case Form10IEAItrType.itr1:
        return 'ITR-1';
      case Form10IEAItrType.itr2:
        return 'ITR-2';
      case Form10IEAItrType.itr3:
        return 'ITR-3';
      case Form10IEAItrType.itr4:
        return 'ITR-4';
    }
  }

  static Form10IEAItrType? fromString(String? value) {
    final normalized = value?.trim().toUpperCase();

    for (final type in Form10IEAItrType.values) {
      if (type.label == normalized) {
        return type;
      }
    }

    return null;
  }
}

extension Form10IEAResultStatusX on Form10IEAResultStatus {
  String get value => name;

  String get label {
    switch (this) {
      case Form10IEAResultStatus.formRequired:
        return 'Form 10-IEA Required';
      case Form10IEAResultStatus.formNotRequired:
        return 'Form 10-IEA Not Required';
      case Form10IEAResultStatus.optionAvailable:
        return 'Regime Option Available';
      case Form10IEAResultStatus.optionRestricted:
        return 'Regime Option Restricted';
      case Form10IEAResultStatus.insufficientInformation:
        return 'Insufficient Information';
      case Form10IEAResultStatus.conflictingInformation:
        return 'Conflicting Information';
      case Form10IEAResultStatus.needsReview:
        return 'Needs Professional Review';
    }
  }

  static Form10IEAResultStatus fromString(String? value) {
    return Form10IEAResultStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => Form10IEAResultStatus.needsReview,
    );
  }
}

class Form10IEAFinancialYearConfig {
  const Form10IEAFinancialYearConfig({
    required this.previousYears,
    required this.targetFinancialYear,
    required this.targetAssessmentYear,
  });

  final List<PreviousYearConfig> previousYears;
  final String targetFinancialYear;
  final String targetAssessmentYear;

  static const current = Form10IEAFinancialYearConfig(
    previousYears: <PreviousYearConfig>[
      PreviousYearConfig(
        label: 'YEAR 1',
        financialYear: 'FY 2023-24',
        assessmentYear: 'AY 2024-25',
      ),
      PreviousYearConfig(
        label: 'YEAR 2',
        financialYear: 'FY 2024-25',
        assessmentYear: 'AY 2025-26',
      ),
    ],
    targetFinancialYear: 'FY 2025-26',
    targetAssessmentYear: 'AY 2026-27',
  );

  String get flow {
    return <String>[
      ...previousYears.map((item) => item.financialYear),
      targetFinancialYear,
    ].join(' → ');
  }
}

class PreviousYearConfig {
  const PreviousYearConfig({
    required this.label,
    required this.financialYear,
    required this.assessmentYear,
  });

  final String label;
  final String financialYear;
  final String assessmentYear;
}

class PreviousYearFilingInput {
  const PreviousYearFilingInput({
    required this.financialYear,
    required this.assessmentYear,
    this.filed,
    this.panMasked = '',
    this.itrType,
    this.filingDate,
    this.filingStatus = '',
    this.selectedRegime = '',
    this.hasBusinessIncome,
    this.form10ieaFiled,
    this.acknowledgementMasked = '',
    this.extractionConfidence = 0,
    this.extractionStatus = Form10IEAExtractionStatus.idle,
    this.confirmationStatus = Form10IEAConfirmationStatus.pending,
    this.fileName = '',
    this.fileSize = 0,
    this.errorMessage = '',
  });

  final String financialYear;
  final String assessmentYear;
  final bool? filed;
  final String panMasked;
  final Form10IEAItrType? itrType;
  final DateTime? filingDate;
  final String filingStatus;
  final String selectedRegime;
  final bool? hasBusinessIncome;
  final bool? form10ieaFiled;
  final String acknowledgementMasked;
  final double extractionConfidence;
  final Form10IEAExtractionStatus extractionStatus;
  final Form10IEAConfirmationStatus confirmationStatus;
  final String fileName;
  final int fileSize;
  final String errorMessage;

  bool get isReady {
    if (filed == null) {
      return false;
    }

    if (filed == false) {
      return true;
    }

    return itrType != null &&
        selectedRegime.isNotEmpty &&
        hasBusinessIncome != null &&
        confirmationStatus == Form10IEAConfirmationStatus.confirmed;
  }

  PreviousYearFilingInput copyWith({
    bool? filed,
    bool clearFiled = false,
    String? panMasked,
    Form10IEAItrType? itrType,
    bool clearItrType = false,
    DateTime? filingDate,
    String? filingStatus,
    String? selectedRegime,
    bool? hasBusinessIncome,
    bool clearBusinessIncome = false,
    bool? form10ieaFiled,
    bool clearForm10ieaFiled = false,
    String? acknowledgementMasked,
    double? extractionConfidence,
    Form10IEAExtractionStatus? extractionStatus,
    Form10IEAConfirmationStatus? confirmationStatus,
    String? fileName,
    int? fileSize,
    String? errorMessage,
  }) {
    return PreviousYearFilingInput(
      financialYear: financialYear,
      assessmentYear: assessmentYear,
      filed: clearFiled ? null : (filed ?? this.filed),
      panMasked: panMasked ?? this.panMasked,
      itrType: clearItrType ? null : (itrType ?? this.itrType),
      filingDate: filingDate ?? this.filingDate,
      filingStatus: filingStatus ?? this.filingStatus,
      selectedRegime: selectedRegime ?? this.selectedRegime,
      hasBusinessIncome: clearBusinessIncome
          ? null
          : (hasBusinessIncome ?? this.hasBusinessIncome),
      form10ieaFiled: clearForm10ieaFiled
          ? null
          : (form10ieaFiled ?? this.form10ieaFiled),
      acknowledgementMasked:
          acknowledgementMasked ?? this.acknowledgementMasked,
      extractionConfidence: extractionConfidence ?? this.extractionConfidence,
      extractionStatus: extractionStatus ?? this.extractionStatus,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toSafeMap() {
    return <String, dynamic>{
      'financialYear': financialYear,
      'assessmentYear': assessmentYear,
      'filed': filed,
      'panMasked': panMasked,
      'itrType': itrType?.label,
      'filingDate': filingDate?.toIso8601String(),
      'filingStatus': filingStatus,
      'selectedRegime': selectedRegime,
      'hasBusinessIncome': hasBusinessIncome,
      'form10ieaFiled': form10ieaFiled,
      'acknowledgementMasked': acknowledgementMasked,
      'extractionConfidence': extractionConfidence,
      'confirmationStatus': confirmationStatus.name,
    };
  }
}

class Form10IEAAssessmentInput {
  const Form10IEAAssessmentInput({
    required this.temporaryId,
    required this.previousYears,
    this.proposedItr,
    this.isRevisedReturn,
  });

  final String temporaryId;
  final List<PreviousYearFilingInput> previousYears;
  final Form10IEAItrType? proposedItr;
  final bool? isRevisedReturn;

  bool get canAnalyse {
    return previousYears.every((item) => item.isReady) && proposedItr != null;
  }

  Form10IEAAssessmentInput copyWith({
    List<PreviousYearFilingInput>? previousYears,
    Form10IEAItrType? proposedItr,
    bool clearProposedItr = false,
    bool? isRevisedReturn,
  }) {
    return Form10IEAAssessmentInput(
      temporaryId: temporaryId,
      previousYears: previousYears ?? this.previousYears,
      proposedItr: clearProposedItr ? null : (proposedItr ?? this.proposedItr),
      isRevisedReturn: isRevisedReturn ?? this.isRevisedReturn,
    );
  }

  Map<String, dynamic> toSafeMap() {
    return <String, dynamic>{
      'temporaryId': temporaryId,
      'previousYears': previousYears.map((item) => item.toSafeMap()).toList(),
      'proposedItr': proposedItr?.label,
      'isRevisedReturn': isRevisedReturn,
    };
  }
}

class Form10IEAScenarioRule {
  const Form10IEAScenarioRule({
    required this.id,
    required this.active,
    required this.assesseType,
    required this.previousRegime,
    required this.businessIncome,
    required this.form10ieaFiled,
    required this.proposedItr,
    required this.resultStatus,
    required this.formRequirement,
    required this.legalReference,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.ruleVersion,
    required this.updatedBy,
    required this.updatedAt,
  });

  final String id;
  final bool active;
  final String assesseType;
  final String previousRegime;
  final bool? businessIncome;
  final bool? form10ieaFiled;
  final Form10IEAItrType? proposedItr;
  final Form10IEAResultStatus resultStatus;
  final String formRequirement;
  final String legalReference;
  final String effectiveFrom;
  final String effectiveTo;
  final String ruleVersion;
  final String updatedBy;
  final DateTime? updatedAt;

  factory Form10IEAScenarioRule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return Form10IEAScenarioRule(
      id: document.id,
      active: data['active'] == true,
      assesseType: data['assesseType']?.toString() ?? 'Individual',
      previousRegime: data['previousRegime']?.toString() ?? 'Any',
      businessIncome: data['businessIncome'] is bool
          ? data['businessIncome'] as bool
          : null,
      form10ieaFiled: data['form10ieaFiled'] is bool
          ? data['form10ieaFiled'] as bool
          : null,
      proposedItr: Form10IEAItrTypeX.fromString(
        data['proposedItr']?.toString(),
      ),
      resultStatus: Form10IEAResultStatusX.fromString(
        data['resultStatus']?.toString(),
      ),
      formRequirement: data['formRequirement']?.toString() ?? '',
      legalReference: data['legalReference']?.toString() ?? '',
      effectiveFrom: data['effectiveFrom']?.toString() ?? '',
      effectiveTo: data['effectiveTo']?.toString() ?? '',
      ruleVersion: data['ruleVersion']?.toString() ?? '1',
      updatedBy: data['updatedBy']?.toString() ?? '',
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore(String userUid) {
    return <String, dynamic>{
      'active': active,
      'assesseType': assesseType,
      'previousRegime': previousRegime,
      'businessIncome': businessIncome,
      'form10ieaFiled': form10ieaFiled,
      'proposedItr': proposedItr?.label,
      'resultStatus': resultStatus.name,
      'formRequirement': formRequirement,
      'legalReference': legalReference,
      'effectiveFrom': effectiveFrom,
      'effectiveTo': effectiveTo,
      'ruleVersion': ruleVersion,
      'updatedBy': userUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Form10IEAScenarioRule copyWith({
    String? id,
    bool? active,
    String? assesseType,
    String? previousRegime,
    bool? businessIncome,
    bool clearBusinessIncome = false,
    bool? form10ieaFiled,
    bool clearForm10ieaFiled = false,
    Form10IEAItrType? proposedItr,
    bool clearProposedItr = false,
    Form10IEAResultStatus? resultStatus,
    String? formRequirement,
    String? legalReference,
    String? effectiveFrom,
    String? effectiveTo,
    String? ruleVersion,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return Form10IEAScenarioRule(
      id: id ?? this.id,
      active: active ?? this.active,
      assesseType: assesseType ?? this.assesseType,
      previousRegime: previousRegime ?? this.previousRegime,
      businessIncome: clearBusinessIncome
          ? null
          : (businessIncome ?? this.businessIncome),
      form10ieaFiled: clearForm10ieaFiled
          ? null
          : (form10ieaFiled ?? this.form10ieaFiled),
      proposedItr: clearProposedItr ? null : (proposedItr ?? this.proposedItr),
      resultStatus: resultStatus ?? this.resultStatus,
      formRequirement: formRequirement ?? this.formRequirement,
      legalReference: legalReference ?? this.legalReference,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      ruleVersion: ruleVersion ?? this.ruleVersion,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Form10IEALegalNote {
  const Form10IEALegalNote({
    required this.id,
    required this.heading,
    required this.summary,
    required this.reference,
    required this.financialYears,
    required this.effectiveDate,
    required this.source,
    required this.lastReviewedDate,
    required this.reviewedBy,
    required this.version,
    required this.active,
  });

  final String id;
  final String heading;
  final String summary;
  final String reference;
  final List<String> financialYears;
  final DateTime? effectiveDate;
  final String source;
  final DateTime? lastReviewedDate;
  final String reviewedBy;
  final String version;
  final bool active;

  factory Form10IEALegalNote.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    return Form10IEALegalNote(
      id: document.id,
      heading: data['heading']?.toString() ?? '',
      summary: data['summary']?.toString() ?? '',
      reference: data['reference']?.toString() ?? '',
      financialYears: data['financialYears'] is Iterable
          ? (data['financialYears'] as Iterable)
                .map((item) => item.toString())
                .toList()
          : const <String>[],
      effectiveDate: readDate(data['effectiveDate']),
      source: data['source']?.toString() ?? '',
      lastReviewedDate: readDate(data['lastReviewedDate']),
      reviewedBy: data['reviewedBy']?.toString() ?? '',
      version: data['version']?.toString() ?? '1',
      active: data['active'] == true,
    );
  }
}

class Form10IEAResult {
  const Form10IEAResult({
    required this.status,
    required this.conclusion,
    required this.formRequired,
    required this.optionAvailable,
    required this.reasons,
    required this.missingInformation,
    required this.recommendedAction,
    required this.matchedRuleIds,
    required this.legalReferences,
  });

  final Form10IEAResultStatus status;
  final String conclusion;
  final bool? formRequired;
  final bool? optionAvailable;
  final List<String> reasons;
  final List<String> missingInformation;
  final String recommendedAction;
  final List<String> matchedRuleIds;
  final List<String> legalReferences;

  bool get needsProfessionalReview {
    return status == Form10IEAResultStatus.needsReview ||
        status == Form10IEAResultStatus.conflictingInformation ||
        status == Form10IEAResultStatus.insufficientInformation;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'status': status.name,
      'conclusion': conclusion,
      'formRequired': formRequired,
      'optionAvailable': optionAvailable,
      'reasons': reasons,
      'missingInformation': missingInformation,
      'recommendedAction': recommendedAction,
      'matchedRuleIds': matchedRuleIds,
      'legalReferences': legalReferences,
    };
  }
}
