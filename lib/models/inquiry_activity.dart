import 'package:cloud_firestore/cloud_firestore.dart';

enum InquiryActivityType {
  inquiryCreated('inquiry_created'),
  inquiryAssigned('inquiry_assigned'),
  inquiryStatusChanged('inquiry_status_changed'),
  followUpAdded('follow_up_added'),
  quotationCreated('quotation_created'),
  quotationSent('quotation_sent'),
  quotationRevised('quotation_revised'),
  quotationApproved('quotation_approved'),
  quotationRejected('quotation_rejected'),
  proformaCreated('proforma_created'),
  proformaSent('proforma_sent'),
  salesOrderCreated('sales_order_created'),
  inquiryConverted('inquiry_converted'),
  inquiryClosed('inquiry_closed'),
  inquiryLost('inquiry_lost');

  const InquiryActivityType(this.value);
  final String value;
}

class InquiryActivity {
  const InquiryActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.inquiryId,
    required this.inquiryNumber,
    required this.createdByUid,
    required this.createdByName,
    required this.companyId,
    required this.metadata,
    this.description,
    this.status,
    this.previousStatus,
    this.newStatus,
    this.relatedDocumentType,
    this.relatedDocumentId,
    this.relatedDocumentNumber,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String inquiryId;
  final String inquiryNumber;
  final String createdByUid;
  final String createdByName;
  final String companyId;
  final Map<String, dynamic> metadata;
  final String? description;
  final String? status;
  final String? previousStatus;
  final String? newStatus;
  final String? relatedDocumentType;
  final String? relatedDocumentId;
  final String? relatedDocumentNumber;
  final DateTime? createdAt;

  factory InquiryActivity.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    String text(String key) => (data[key] ?? '').toString().trim();
    String? optional(String key) {
      final value = text(key);
      return value.isEmpty ? null : value;
    }

    final rawMetadata = data['metadata'];
    return InquiryActivity(
      id: snapshot.id,
      type: text('type'),
      title: text('title').isEmpty ? 'Inquiry activity' : text('title'),
      inquiryId: text('inquiryId'),
      inquiryNumber: text('inquiryNumber'),
      createdByUid: text('createdByUid'),
      createdByName: text('createdByName'),
      companyId: text('companyId'),
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
      description: optional('description'),
      status: optional('status'),
      previousStatus: optional('previousStatus'),
      newStatus: optional('newStatus'),
      relatedDocumentType: optional('relatedDocumentType'),
      relatedDocumentId: optional('relatedDocumentId'),
      relatedDocumentNumber: optional('relatedDocumentNumber'),
      createdAt: _date(data['createdAt']),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
