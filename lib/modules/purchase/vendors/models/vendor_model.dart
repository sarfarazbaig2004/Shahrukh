import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> purchaseVendorCategories = [
  'Machine Supplier',
  'Spare Supplier',
  'Accessory Supplier',
  'Raw Material Supplier',
  'Consumable Supplier',
  'Service Provider',
  'Transporter',
  'Contractor',
  'Other',
];

const List<String> vendorPaymentTermsOptions = [
  'Advance',
  'Immediate',
  '7 Days',
  '15 Days',
  '30 Days',
  '45 Days',
  '60 Days',
  '90 Days',
  'Custom',
];

class VendorModel {
  const VendorModel({
    this.id = '',
    required this.companyId,
    required this.vendorName,
    required this.vendorCode,
    required this.contactPerson,
    required this.mobile,
    required this.alternateMobile,
    required this.email,
    required this.website,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
    required this.gstNo,
    required this.panNo,
    required this.msmeStatus,
    required this.msmeNo,
    required this.vendorCategory,
    required this.itemsSupplied,
    required this.creditDays,
    required this.paymentTerms,
    required this.customPaymentTerms,
    required this.openingBalance,
    required this.isActive,
    required this.bankAccountName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.branchName,
    required this.remarks,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  final String id;
  final String companyId;
  final String vendorName;
  final String vendorCode;
  final String contactPerson;
  final String mobile;
  final String alternateMobile;
  final String email;
  final String website;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String gstNo;
  final String panNo;
  final String msmeStatus;
  final String msmeNo;
  final String vendorCategory;
  final String itemsSupplied;
  final int creditDays;
  final String paymentTerms;
  final String customPaymentTerms;
  final double openingBalance;
  final bool isActive;
  final String bankAccountName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String branchName;
  final String remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  String get effectivePaymentTerms => paymentTerms == 'Custom'
      ? customPaymentTerms.trim()
      : paymentTerms.trim();

  String get fullAddress {
    return [
      addressLine1,
      addressLine2,
      city,
      state,
      pincode,
      country,
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }

  factory VendorModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final creditDays = _integer(data['creditDays']);
    final storedTerms = _text(data['paymentTerms']);
    final derivedTerms = storedTerms.isNotEmpty
        ? storedTerms
        : _termsFromCreditDays(creditDays);

    return VendorModel(
      id: doc.id,
      companyId: _text(data['companyId']),
      vendorName: _firstText(data, ['vendorName', 'name', 'companyName']),
      vendorCode: _firstText(data, ['vendorCode', 'code']),
      contactPerson: _firstText(data, ['contactPerson', 'contactName']),
      mobile: _firstText(data, ['mobile', 'phone']),
      alternateMobile: _text(data['alternateMobile']),
      email: _text(data['email']),
      website: _text(data['website']),
      addressLine1: _firstText(data, ['addressLine1', 'address']),
      addressLine2: _text(data['addressLine2']),
      city: _text(data['city']),
      state: _text(data['state']),
      pincode: _firstText(data, ['pincode', 'postalCode']),
      country: _text(data['country'], fallback: 'India'),
      gstNo: _firstText(data, ['gstNo', 'gstin', 'GSTIN']),
      panNo: _firstText(data, ['panNo', 'pan']),
      msmeStatus: _text(data['msmeStatus'], fallback: 'Not Registered'),
      msmeNo: _text(data['msmeNo']),
      vendorCategory: _text(data['vendorCategory'], fallback: 'Other'),
      itemsSupplied: _text(data['itemsSupplied']),
      creditDays: creditDays,
      paymentTerms: vendorPaymentTermsOptions.contains(derivedTerms)
          ? derivedTerms
          : 'Custom',
      customPaymentTerms:
          storedTerms.isNotEmpty &&
              !vendorPaymentTermsOptions.contains(storedTerms)
          ? storedTerms
          : _text(
              data['customPaymentTerms'],
              fallback: derivedTerms == 'Custom' && creditDays > 0
                  ? '$creditDays Days'
                  : '',
            ),
      openingBalance: _number(data['openingBalance']),
      isActive: data['isActive'] != false,
      bankAccountName: _text(data['bankAccountName']),
      bankName: _text(data['bankName']),
      accountNumber: _text(data['accountNumber']),
      ifscCode: _text(data['ifscCode']),
      branchName: _text(data['branchName']),
      remarks: _text(data['remarks']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _text(data['createdBy']),
      updatedBy: _text(data['updatedBy']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'vendorName': vendorName.trim(),
      'vendorNameLower': vendorName.trim().toLowerCase(),
      'vendorCode': vendorCode.trim().toUpperCase(),
      'contactPerson': contactPerson.trim(),
      'mobile': mobile.trim(),
      'alternateMobile': alternateMobile.trim(),
      'email': email.trim().toLowerCase(),
      'website': website.trim(),
      'addressLine1': addressLine1.trim(),
      'addressLine2': addressLine2.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'pincode': pincode.trim(),
      'country': country.trim(),
      'gstNo': gstNo.trim().toUpperCase(),
      'gstin': gstNo.trim().toUpperCase(),
      'panNo': panNo.trim().toUpperCase(),
      'pan': panNo.trim().toUpperCase(),
      'msmeStatus': msmeStatus,
      'msmeNo': msmeNo.trim().toUpperCase(),
      'vendorCategory': vendorCategory,
      'itemsSupplied': itemsSupplied.trim(),
      'creditDays': creditDays,
      'paymentTerms': paymentTerms,
      'customPaymentTerms': customPaymentTerms.trim(),
      'openingBalance': openingBalance,
      'isActive': isActive,
      'bankAccountName': bankAccountName.trim(),
      'bankName': bankName.trim(),
      'accountNumber': accountNumber.trim(),
      'ifscCode': ifscCode.trim().toUpperCase(),
      'branchName': branchName.trim(),
      'remarks': remarks.trim(),
    };
  }
}

String _termsFromCreditDays(int creditDays) {
  if (creditDays <= 0) return 'Immediate';
  final option = '$creditDays Days';
  return vendorPaymentTermsOptions.contains(option) ? option : 'Custom';
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

int _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
