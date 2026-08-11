class ChallanExtractionModel {
  const ChallanExtractionModel({
    required this.id,
    required this.sourceFileName,
    required this.sourceFileSize,
    required this.sourceFileHash,
    required this.challanType,
    required this.itnsForm,
    required this.pan,
    required this.tan,
    required this.name,
    required this.assessmentYear,
    required this.financialYear,
    required this.bsrCode,
    required this.challanSerialNumber,
    required this.depositDate,
    required this.majorHead,
    required this.minorHead,
    required this.section,
    required this.amount,
    required this.interest,
    required this.penalty,
    required this.lateFee,
    required this.totalAmount,
    required this.bankName,
    required this.branch,
    required this.extractedText,
    required this.confidenceScore,
    required this.verificationStatus,
    required this.status,
    required this.warnings,
    required this.errors,
    required this.processingTimeMilliseconds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sourceFileName;
  final int sourceFileSize;
  final String sourceFileHash;
  final String challanType;
  final String itnsForm;
  final String pan;
  final String tan;
  final String name;
  final String assessmentYear;
  final String financialYear;
  final String bsrCode;
  final String challanSerialNumber;
  final DateTime? depositDate;
  final String majorHead;
  final String minorHead;
  final String section;
  final double amount;
  final double interest;
  final double penalty;
  final double lateFee;
  final double totalAmount;
  final String bankName;
  final String branch;
  final String extractedText;
  final double confidenceScore;
  final String verificationStatus;
  final String status;
  final List<String> warnings;
  final List<String> errors;
  final int processingTimeMilliseconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'sourceFileName': sourceFileName,
      'sourceFileSize': sourceFileSize,
      'sourceFileHash': sourceFileHash,
      'challanType': challanType,
      'itnsForm': itnsForm,
      'pan': pan,
      'tan': tan,
      'name': name,
      'assessmentYear': assessmentYear,
      'financialYear': financialYear,
      'bsrCode': bsrCode,
      'challanSerialNumber': challanSerialNumber,
      'depositDate': depositDate?.toIso8601String(),
      'majorHead': majorHead,
      'minorHead': minorHead,
      'section': section,
      'amount': amount,
      'interest': interest,
      'penalty': penalty,
      'lateFee': lateFee,
      'totalAmount': totalAmount,
      'bankName': bankName,
      'branch': branch,
      'extractedText': extractedText,
      'confidenceScore': confidenceScore,
      'verificationStatus': verificationStatus,
      'status': status,
      'warnings': warnings,
      'errors': errors,
      'processingTimeMilliseconds': processingTimeMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ChallanExtractionModel copyWith({
    String? pan,
    String? tan,
    String? name,
    String? assessmentYear,
    String? financialYear,
    String? bsrCode,
    String? challanSerialNumber,
    DateTime? depositDate,
    String? majorHead,
    String? minorHead,
    String? section,
    double? amount,
    double? interest,
    double? penalty,
    double? lateFee,
    double? totalAmount,
    String? bankName,
    String? branch,
    double? confidenceScore,
    String? verificationStatus,
    String? status,
    List<String>? warnings,
    List<String>? errors,
    DateTime? updatedAt,
  }) {
    return ChallanExtractionModel(
      id: id,
      sourceFileName: sourceFileName,
      sourceFileSize: sourceFileSize,
      sourceFileHash: sourceFileHash,
      challanType: challanType,
      itnsForm: itnsForm,
      pan: pan ?? this.pan,
      tan: tan ?? this.tan,
      name: name ?? this.name,
      assessmentYear: assessmentYear ?? this.assessmentYear,
      financialYear: financialYear ?? this.financialYear,
      bsrCode: bsrCode ?? this.bsrCode,
      challanSerialNumber: challanSerialNumber ?? this.challanSerialNumber,
      depositDate: depositDate ?? this.depositDate,
      majorHead: majorHead ?? this.majorHead,
      minorHead: minorHead ?? this.minorHead,
      section: section ?? this.section,
      amount: amount ?? this.amount,
      interest: interest ?? this.interest,
      penalty: penalty ?? this.penalty,
      lateFee: lateFee ?? this.lateFee,
      totalAmount: totalAmount ?? this.totalAmount,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      extractedText: extractedText,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      status: status ?? this.status,
      warnings: warnings ?? this.warnings,
      errors: errors ?? this.errors,
      processingTimeMilliseconds: processingTimeMilliseconds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
