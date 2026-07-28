import 'package:cloud_firestore/cloud_firestore.dart';

/// A vendor invited to respond to a [PurchaseRfq].
class PurchaseRfqVendor {
  const PurchaseRfqVendor({
    required this.vendorId,
    required this.vendorName,
    this.vendorCode,
    this.contactPerson,
    this.email,
    this.phone,
    this.taxNumber,
    this.address,
    this.note,
    this.isSelected = false,
    this.sentAt,
    this.respondedAt,
  });

  final String vendorId;
  final String vendorName;
  final String? vendorCode;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? taxNumber;
  final String? address;
  final String? note;
  final bool isSelected;
  final DateTime? sentAt;
  final DateTime? respondedAt;

  PurchaseRfqVendor copyWith({
    String? vendorId,
    String? vendorName,
    String? vendorCode,
    String? contactPerson,
    String? email,
    String? phone,
    String? taxNumber,
    String? address,
    String? note,
    bool? isSelected,
    DateTime? sentAt,
    DateTime? respondedAt,
  }) {
    return PurchaseRfqVendor(
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorCode: vendorCode ?? this.vendorCode,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      taxNumber: taxNumber ?? this.taxNumber,
      address: address ?? this.address,
      note: note ?? this.note,
      isSelected: isSelected ?? this.isSelected,
      sentAt: sentAt ?? this.sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  factory PurchaseRfqVendor.fromMap(Map<String, dynamic> data) {
    return PurchaseRfqVendor(
      vendorId: _text(data['vendorId']),
      vendorName: _firstText(data, ['vendorName', 'name']),
      vendorCode: _nullableText(data['vendorCode']),
      contactPerson: _nullableText(data['contactPerson']),
      email: _nullableText(data['email']),
      phone: _nullableText(data['phone']),
      taxNumber: _nullableText(data['taxNumber']),
      address: _nullableText(data['address']),
      note: _nullableText(data['note']),
      isSelected: data['isSelected'] == true,
      sentAt: _date(data['sentAt']),
      respondedAt: _date(data['respondedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName.trim(),
      'vendorCode': vendorCode,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'taxNumber': taxNumber,
      'address': address,
      'note': note,
      'isSelected': isSelected,
      'sentAt': sentAt == null ? null : Timestamp.fromDate(sentAt!),
      'respondedAt': respondedAt == null
          ? null
          : Timestamp.fromDate(respondedAt!),
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

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
