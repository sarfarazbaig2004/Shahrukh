import 'package:cloud_firestore/cloud_firestore.dart';

/// A single line item inside a [PurchaseRfq].
class PurchaseRfqItem {
  const PurchaseRfqItem({
    this.id = '',
    this.itemId,
    this.itemCode,
    required this.itemName,
    this.description,
    this.specification,
    this.quantity = 0,
    this.unit = 'Nos.',
    this.requiredDeliveryDate,
    this.deliveryLocation,
    this.preferredBrand,
    this.makeOrModel,
    this.remarks,
    this.purchaseRequisitionLineId,
  });

  final String id;
  final String? itemId;
  final String? itemCode;
  final String itemName;
  final String? description;
  final String? specification;
  final double quantity;
  final String unit;
  final DateTime? requiredDeliveryDate;
  final String? deliveryLocation;
  final String? preferredBrand;
  final String? makeOrModel;
  final String? remarks;
  final String? purchaseRequisitionLineId;

  PurchaseRfqItem copyWith({
    String? id,
    String? itemId,
    String? itemCode,
    String? itemName,
    String? description,
    String? specification,
    double? quantity,
    String? unit,
    DateTime? requiredDeliveryDate,
    String? deliveryLocation,
    String? preferredBrand,
    String? makeOrModel,
    String? remarks,
    String? purchaseRequisitionLineId,
  }) {
    return PurchaseRfqItem(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      specification: specification ?? this.specification,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      requiredDeliveryDate: requiredDeliveryDate ?? this.requiredDeliveryDate,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      preferredBrand: preferredBrand ?? this.preferredBrand,
      makeOrModel: makeOrModel ?? this.makeOrModel,
      remarks: remarks ?? this.remarks,
      purchaseRequisitionLineId:
          purchaseRequisitionLineId ?? this.purchaseRequisitionLineId,
    );
  }

  factory PurchaseRfqItem.fromMap(Map<String, dynamic> data) {
    return PurchaseRfqItem(
      id: _text(data['id']),
      itemId: _nullableText(data['itemId']),
      itemCode: _nullableText(data['itemCode']),
      itemName: _firstText(data, ['itemName', 'name']),
      description: _nullableText(data['description']),
      specification: _nullableText(data['specification']),
      quantity: _number(data['quantity'] ?? data['qty']),
      unit: _firstText(data, ['unit', 'uom'], fallback: 'Nos.'),
      requiredDeliveryDate: _date(data['requiredDeliveryDate']),
      deliveryLocation: _nullableText(data['deliveryLocation']),
      preferredBrand: _nullableText(data['preferredBrand']),
      makeOrModel: _nullableText(data['makeOrModel']),
      remarks: _nullableText(data['remarks']),
      purchaseRequisitionLineId: _nullableText(
        data['purchaseRequisitionLineId'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'itemCode': itemCode,
      'itemName': itemName.trim(),
      'description': description,
      'specification': specification,
      'quantity': quantity,
      'unit': unit.trim(),
      'requiredDeliveryDate': requiredDeliveryDate == null
          ? null
          : Timestamp.fromDate(requiredDeliveryDate!),
      'deliveryLocation': deliveryLocation,
      'preferredBrand': preferredBrand,
      'makeOrModel': makeOrModel,
      'remarks': remarks,
      'purchaseRequisitionLineId': purchaseRequisitionLineId,
    };
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

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
