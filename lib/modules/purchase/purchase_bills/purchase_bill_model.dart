import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> purchaseBillPaymentStatuses = [
  'Unpaid',
  'Partially Paid',
  'Paid',
];

class PurchaseBillModel {
  const PurchaseBillModel({
    this.id = '',
    required this.companyId,
    required this.purchaseBillNo,
    required this.purchaseBillDate,
    required this.vendorId,
    required this.vendorName,
    required this.salesOrderRef,
    required this.grnRef,
    required this.supplierInvoiceNo,
    required this.supplierInvoiceDate,
    required this.taxableAmount,
    required this.discountAmount,
    required this.freightAmount,
    required this.otherCharges,
    required this.gstAmount,
    required this.tdsAmount,
    required this.totalAmount,
    required this.paymentStatus,
    required this.remarks,
    this.pdfUrl = '',
    this.pdfPath = '',
    this.pdfFileName = '',
    this.pdfUploadedAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  final String id;
  final String companyId;
  final String purchaseBillNo;
  final DateTime purchaseBillDate;
  final String vendorId;
  final String vendorName;
  final String salesOrderRef;
  final String grnRef;
  final String supplierInvoiceNo;
  final DateTime? supplierInvoiceDate;
  final double taxableAmount;
  final double discountAmount;
  final double freightAmount;
  final double otherCharges;
  final double gstAmount;
  final double tdsAmount;
  final double totalAmount;
  final String paymentStatus;
  final String remarks;
  final String pdfUrl;
  final String pdfPath;
  final String pdfFileName;
  final DateTime? pdfUploadedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  bool get hasAttachment => pdfUrl.trim().isNotEmpty;

  factory PurchaseBillModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final legacyGst =
        _number(data['cgst']) + _number(data['sgst']) + _number(data['igst']);
    return PurchaseBillModel(
      id: doc.id,
      companyId: _text(data['companyId']),
      purchaseBillNo: _firstText(data, [
        'purchaseBillNo',
        'billNumber',
        'billNo',
      ]),
      purchaseBillDate:
          _date(data['purchaseBillDate'] ?? data['billDate']) ?? DateTime.now(),
      vendorId: _text(data['vendorId']),
      vendorName: _text(data['vendorName']),
      salesOrderRef: _firstText(data, [
        'salesOrderRef',
        'salesOrderEntry',
        'salesOrderReference',
      ]),
      grnRef: _firstText(data, ['grnRef', 'grnId']),
      supplierInvoiceNo: _firstText(data, [
        'supplierInvoiceNo',
        'vendorInvoiceNumber',
      ]),
      supplierInvoiceDate: _date(
        data['supplierInvoiceDate'] ?? data['vendorInvoiceDate'],
      ),
      taxableAmount: _number(data['taxableAmount'] ?? data['subTotal']),
      discountAmount: _number(data['discountAmount'] ?? data['discount']),
      freightAmount: _number(data['freightAmount'] ?? data['freight']),
      otherCharges: _number(data['otherCharges']),
      gstAmount: data.containsKey('gstAmount')
          ? _number(data['gstAmount'])
          : legacyGst,
      tdsAmount: _number(data['tdsAmount']),
      totalAmount: _number(data['totalAmount'] ?? data['grandTotal']),
      paymentStatus: _text(data['paymentStatus'], fallback: 'Unpaid'),
      remarks: _text(data['remarks']),
      pdfUrl: _firstText(data, ['pdfUrl', 'attachmentUrl']),
      pdfPath: _firstText(data, ['pdfPath', 'attachmentPath']),
      pdfFileName: _firstText(data, ['pdfFileName', 'attachmentName']),
      pdfUploadedAt: _date(
        data['pdfUploadedAt'] ?? data['attachmentUploadedAt'],
      ),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _text(data['createdBy']),
      updatedBy: _text(data['updatedBy']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'purchaseBillNo': purchaseBillNo.trim(),
      'purchaseBillDate': Timestamp.fromDate(purchaseBillDate),
      'vendorId': vendorId,
      'vendorName': vendorName.trim(),
      'salesOrderRef': salesOrderRef.trim(),
      'grnRef': grnRef.trim(),
      'supplierInvoiceNo': supplierInvoiceNo.trim(),
      'supplierInvoiceDate': supplierInvoiceDate == null
          ? null
          : Timestamp.fromDate(supplierInvoiceDate!),
      'taxableAmount': taxableAmount,
      'discountAmount': discountAmount,
      'freightAmount': freightAmount,
      'otherCharges': otherCharges,
      'gstAmount': gstAmount,
      'tdsAmount': tdsAmount,
      'totalAmount': totalAmount,
      'paymentStatus': paymentStatus,
      'remarks': remarks.trim(),
      'pdfUrl': pdfUrl,
      'pdfPath': pdfPath,
      'pdfFileName': pdfFileName,
      'pdfUploadedAt': pdfUploadedAt == null
          ? null
          : Timestamp.fromDate(pdfUploadedAt!),
    };
  }

  PurchaseBillModel copyWith({
    String? id,
    String? pdfUrl,
    String? pdfPath,
    String? pdfFileName,
    DateTime? pdfUploadedAt,
  }) {
    return PurchaseBillModel(
      id: id ?? this.id,
      companyId: companyId,
      purchaseBillNo: purchaseBillNo,
      purchaseBillDate: purchaseBillDate,
      vendorId: vendorId,
      vendorName: vendorName,
      salesOrderRef: salesOrderRef,
      grnRef: grnRef,
      supplierInvoiceNo: supplierInvoiceNo,
      supplierInvoiceDate: supplierInvoiceDate,
      taxableAmount: taxableAmount,
      discountAmount: discountAmount,
      freightAmount: freightAmount,
      otherCharges: otherCharges,
      gstAmount: gstAmount,
      tdsAmount: tdsAmount,
      totalAmount: totalAmount,
      paymentStatus: paymentStatus,
      remarks: remarks,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pdfUploadedAt: pdfUploadedAt ?? this.pdfUploadedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _text(data[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
