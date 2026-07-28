import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'purchase_rfq_item_model.dart';
import 'purchase_rfq_vendor_model.dart';
import 'rfq_status.dart';

/// Request for Quotation (RFQ) model for the Purchase module.
class PurchaseRfq {
  const PurchaseRfq({
    this.id = '',
    required this.companyId,
    required this.rfqNumber,
    required this.title,
    this.description,
    required this.rfqDate,
    this.submissionDeadline,
    this.requiredDeliveryDate,
    this.purchaseRequisitionId,
    this.purchaseRequisitionNumber,
    this.departmentId,
    this.projectId,
    this.costCenterId,
    this.assignedBuyerId,
    this.assignedBuyerName,
    this.currency,
    this.deliveryLocation,
    this.deliveryAddress,
    this.items = const [],
    this.vendors = const [],
    this.status = RfqStatus.draft,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String companyId;
  final String rfqNumber;
  final String title;
  final String? description;
  final DateTime rfqDate;
  final DateTime? submissionDeadline;
  final DateTime? requiredDeliveryDate;
  final String? purchaseRequisitionId;
  final String? purchaseRequisitionNumber;
  final String? departmentId;
  final String? projectId;
  final String? costCenterId;
  final String? assignedBuyerId;
  final String? assignedBuyerName;
  final String? currency;
  final String? deliveryLocation;
  final String? deliveryAddress;
  final List<PurchaseRfqItem> items;
  final List<PurchaseRfqVendor> vendors;
  final RfqStatus status;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final bool isDeleted;

  PurchaseRfq copyWith({
    String? id,
    String? companyId,
    String? rfqNumber,
    String? title,
    String? description,
    DateTime? rfqDate,
    DateTime? submissionDeadline,
    DateTime? requiredDeliveryDate,
    String? purchaseRequisitionId,
    String? purchaseRequisitionNumber,
    String? departmentId,
    String? projectId,
    String? costCenterId,
    String? assignedBuyerId,
    String? assignedBuyerName,
    String? currency,
    String? deliveryLocation,
    String? deliveryAddress,
    List<PurchaseRfqItem>? items,
    List<PurchaseRfqVendor>? vendors,
    RfqStatus? status,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return PurchaseRfq(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      rfqNumber: rfqNumber ?? this.rfqNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      rfqDate: rfqDate ?? this.rfqDate,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      requiredDeliveryDate: requiredDeliveryDate ?? this.requiredDeliveryDate,
      purchaseRequisitionId:
          purchaseRequisitionId ?? this.purchaseRequisitionId,
      purchaseRequisitionNumber:
          purchaseRequisitionNumber ?? this.purchaseRequisitionNumber,
      departmentId: departmentId ?? this.departmentId,
      projectId: projectId ?? this.projectId,
      costCenterId: costCenterId ?? this.costCenterId,
      assignedBuyerId: assignedBuyerId ?? this.assignedBuyerId,
      assignedBuyerName: assignedBuyerName ?? this.assignedBuyerName,
      currency: currency ?? this.currency,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      vendors: vendors ?? this.vendors,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  factory PurchaseRfq.fromMap(Map<String, dynamic> data) {
    final items = _mapList(
      data['items'],
    ).map(PurchaseRfqItem.fromMap).toList(growable: false);
    final vendors = _mapList(
      data['vendors'],
    ).map(PurchaseRfqVendor.fromMap).toList(growable: false);

    return PurchaseRfq(
      id: _text(data['id']),
      companyId: _text(data['companyId']),
      rfqNumber: _firstText(data, ['rfqNumber', 'rfqNo', 'number']),
      title: _firstText(data, ['title', 'subject', 'name']),
      description: _nullableText(data['description']),
      rfqDate: _date(data['rfqDate']) ?? DateTime.now(),
      submissionDeadline: _date(data['submissionDeadline']),
      requiredDeliveryDate: _date(data['requiredDeliveryDate']),
      purchaseRequisitionId: _nullableText(data['purchaseRequisitionId']),
      purchaseRequisitionNumber: _nullableText(
        data['purchaseRequisitionNumber'],
      ),
      departmentId: _nullableText(data['departmentId']),
      projectId: _nullableText(data['projectId']),
      costCenterId: _nullableText(data['costCenterId']),
      assignedBuyerId: _nullableText(data['assignedBuyerId']),
      assignedBuyerName: _nullableText(data['assignedBuyerName']),
      currency: _nullableText(data['currency']),
      deliveryLocation: _nullableText(data['deliveryLocation']),
      deliveryAddress: _nullableText(data['deliveryAddress']),
      items: items,
      vendors: vendors,
      status: RfqStatusExtension.parse(data['status']?.toString()),
      createdBy: _text(data['createdBy']),
      createdByName: _nullableText(data['createdByName']),
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      updatedBy: _nullableText(data['updatedBy']),
      updatedAt: _date(data['updatedAt']),
      isDeleted: data['isDeleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'rfqNumber': rfqNumber.trim(),
      'title': title.trim(),
      'description': description,
      'rfqDate': Timestamp.fromDate(rfqDate),
      'submissionDeadline': submissionDeadline == null
          ? null
          : Timestamp.fromDate(submissionDeadline!),
      'requiredDeliveryDate': requiredDeliveryDate == null
          ? null
          : Timestamp.fromDate(requiredDeliveryDate!),
      'purchaseRequisitionId': purchaseRequisitionId,
      'purchaseRequisitionNumber': purchaseRequisitionNumber,
      'departmentId': departmentId,
      'projectId': projectId,
      'costCenterId': costCenterId,
      'assignedBuyerId': assignedBuyerId,
      'assignedBuyerName': assignedBuyerName,
      'currency': currency,
      'deliveryLocation': deliveryLocation,
      'deliveryAddress': deliveryAddress,
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'vendors': vendors
          .map((vendor) => vendor.toMap())
          .toList(growable: false),
      'status': status.firestoreValue,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedBy': updatedBy,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'isDeleted': isDeleted,
    };
  }

  factory PurchaseRfq.fromJson(String source) {
    return PurchaseRfq.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  String toJson() => jsonEncode(toMap(), toEncodable: _jsonEncodable);

  dynamic _jsonEncodable(dynamic object) {
    if (object is Timestamp) return object.toDate().toIso8601String();
    if (object is DateTime) return object.toIso8601String();
    throw UnsupportedError(
      'Cannot encode object of type ${object.runtimeType}',
    );
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String? _nullableText(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

String _firstText(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _text(data[key]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
