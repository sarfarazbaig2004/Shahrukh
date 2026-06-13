import 'package:cloud_firestore/cloud_firestore.dart';

class ExportInvoiceItem {
  final String id;
  final String companyId;
  final String name;
  final String description;
  final String hsnCode;
  final double quantity;
  final String unit;
  final double rate;

  // 🔴 Stored only for backward compatibility (NOT trusted)
  final double amount;

  // Standard ERP Fields
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;
  final bool isActive;
  final bool isDeleted;

  ExportInvoiceItem({
    required this.id,
    required this.companyId,
    required this.name,
    required this.description,
    required this.hsnCode,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.amount,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
    this.isActive = true,
    this.isDeleted = false,
  });

  // ✅ ERP SOURCE OF TRUTH
  double get computedAmount => quantity * rate;

  // ✅ Detect mismatch (for audit/debug)
  bool get isAmountMismatch =>
      (amount - computedAmount).abs() > 0.01;

  // ✅ CLEAN & PRODUCTION SAFE MAP
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'description': description,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,

      // ✅ Rounded value (avoid floating issues)
      'amount': double.parse(computedAmount.toStringAsFixed(2)),

      // ✅ Proper timestamp handling
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,

      // 🚨 CRITICAL ARCHITECTURE FIX: Never use FieldValue inside a nested list/array
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,

      'isActive': isActive,
      'isDeleted': isDeleted,
    };
  }

  // ✅ DEFENSIVE & STABLE PARSING
  factory ExportInvoiceItem.fromMap(Map<String, dynamic> map, String docId) {
    final qty = (map['quantity'] is num)
        ? map['quantity'].toDouble()
        : double.tryParse(map['quantity'].toString()) ?? 0.0;

    final rateVal = (map['rate'] is num)
        ? map['rate'].toDouble()
        : double.tryParse(map['rate'].toString()) ?? 0.0;

    final computed = qty * rateVal;

    return ExportInvoiceItem(
      id: docId,
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      hsnCode: map['hsnCode'] ?? '',
      quantity: qty,
      unit: map['unit'] ?? '',
      rate: rateVal,

      // ✅ Always trust computed value
      amount: computed,

      createdAt:
      (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      updatedAt:
      (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
      isActive: map['isActive'] ?? true,
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}