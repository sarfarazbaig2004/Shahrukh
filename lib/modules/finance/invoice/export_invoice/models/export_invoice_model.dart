import 'package:cloud_firestore/cloud_firestore.dart';
import 'export_invoice_item.dart';

// ============================================================================
// 🛡️ STRICT ERP PARSING HELPERS (Null-Safe & Crash-Proof)
// ============================================================================

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

// ============================================================================
// 🔁 REUSABLE PARTY MODEL
// ============================================================================

class Party {
  final String name;
  final String address;
  final String country;
  final String state;
  final String stateCode;
  final String gstin;
  final String pan;
  final String iec;
  final String contactPerson;
  final String email;
  final String phone;

  Party({
    required this.name,
    required this.address,
    required this.country,
    this.state = '',
    this.stateCode = '',
    this.gstin = '',
    this.pan = '',
    this.iec = '',
    this.contactPerson = '',
    this.email = '',
    this.phone = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'country': country,
      'state': state,
      'stateCode': stateCode,
      'gstin': gstin,
      'pan': pan,
      'iec': iec,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
    };
  }

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      stateCode: map['stateCode'] ?? '',
      gstin: map['gstin'] ?? '',
      pan: map['pan'] ?? '',
      iec: map['iec'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}

// ============================================================================
// 📦 EXPORT DETAILS
// ============================================================================

class ExportDetails {
  final String exportType;
  final String lutNumber;
  final String adCode;
  final String portCode;
  final String portOfLoading;
  final String portOfDischarge;
  final String countryOfOrigin;
  final String countryOfDestination;
  final String incoterm;

  ExportDetails({
    required this.exportType,
    this.lutNumber = '',
    this.adCode = '',
    required this.portCode,
    required this.portOfLoading,
    required this.portOfDischarge,
    required this.countryOfOrigin,
    required this.countryOfDestination,
    this.incoterm = 'FOB',
  });

  Map<String, dynamic> toMap() {
    return {
      'exportType': exportType,
      'lutNumber': lutNumber,
      'adCode': adCode,
      'portCode': portCode,
      'portOfLoading': portOfLoading,
      'portOfDischarge': portOfDischarge,
      'countryOfOrigin': countryOfOrigin,
      'countryOfDestination': countryOfDestination,
      'incoterm': incoterm,
    };
  }

  factory ExportDetails.fromMap(Map<String, dynamic> map) {
    return ExportDetails(
      exportType: map['exportType'] ?? 'WITH_LUT',
      lutNumber: map['lutNumber'] ?? '',
      adCode: map['adCode'] ?? '',
      portCode: map['portCode'] ?? '',
      portOfLoading: map['portOfLoading'] ?? '',
      portOfDischarge: map['portOfDischarge'] ?? '',
      countryOfOrigin: map['countryOfOrigin'] ?? '',
      countryOfDestination: map['countryOfDestination'] ?? '',
      incoterm: map['incoterm'] ?? 'FOB',
    );
  }
}

// ============================================================================
// 🚚 LOGISTICS & PACKING
// ============================================================================

class Logistics {
  final String preCarriageBy;
  final String modeOfTransport;
  final String vesselOrFlight;
  final String shippingBillNo;
  final DateTime? shippingBillDate;
  final String marksAndNos;
  final int numberOfPackages;
  final double grossWeight;
  final double netWeight;

  Logistics({
    this.preCarriageBy = '',
    this.modeOfTransport = '',
    this.vesselOrFlight = '',
    this.shippingBillNo = '',
    this.shippingBillDate,
    this.marksAndNos = '',
    this.numberOfPackages = 0,
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
  });

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'preCarriageBy': preCarriageBy,
      'modeOfTransport': modeOfTransport,
      'vesselOrFlight': vesselOrFlight,
      'shippingBillNo': shippingBillNo,
      'marksAndNos': marksAndNos,
      'numberOfPackages': numberOfPackages,
      'grossWeight': grossWeight,
      'netWeight': netWeight,
    };

    if (shippingBillDate != null) {
      data['shippingBillDate'] = Timestamp.fromDate(shippingBillDate!);
    }

    return data;
  }

  factory Logistics.fromMap(Map<String, dynamic> map) {
    return Logistics(
      preCarriageBy: map['preCarriageBy'] ?? '',
      modeOfTransport: map['modeOfTransport'] ?? '',
      vesselOrFlight: map['vesselOrFlight'] ?? '',
      shippingBillNo: map['shippingBillNo'] ?? '',
      shippingBillDate: map['shippingBillDate'] != null ? (map['shippingBillDate'] as Timestamp).toDate() : null,
      marksAndNos: map['marksAndNos'] ?? '',
      numberOfPackages: _parseInt(map['numberOfPackages']),
      grossWeight: _parseDouble(map['grossWeight']),
      netWeight: _parseDouble(map['netWeight']),
    );
  }
}

// ============================================================================
// 💰 TAX DETAILS
// ============================================================================

class TaxDetails {
  final double taxableValue;
  final double igstRate;
  final double igstAmount;
  final bool reverseCharge;

  TaxDetails({
    required this.taxableValue,
    required this.igstRate,
    required this.igstAmount,
    this.reverseCharge = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'taxableValue': taxableValue,
      'igstRate': igstRate,
      'igstAmount': igstAmount,
      'reverseCharge': reverseCharge,
    };
  }

  factory TaxDetails.fromMap(Map<String, dynamic> map) {
    return TaxDetails(
      taxableValue: _parseDouble(map['taxableValue']),
      igstRate: _parseDouble(map['igstRate']),
      igstAmount: _parseDouble(map['igstAmount']),
      reverseCharge: map['reverseCharge'] ?? false,
    );
  }
}

// ============================================================================
// 💳 PAYMENT DETAILS & BANK
// ============================================================================

class PaymentDetails {
  final String paymentMode;
  final String paymentReference;
  final String deliveryTerms;
  final String beneficiaryName;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String swiftCode;
  final String bankAddress;

  PaymentDetails({
    required this.paymentMode,
    this.paymentReference = '',
    this.deliveryTerms = '',
    this.beneficiaryName = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.swiftCode = '',
    this.bankAddress = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentMode': paymentMode,
      'paymentReference': paymentReference,
      'deliveryTerms': deliveryTerms,
      'beneficiaryName': beneficiaryName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifsc': ifsc,
      'swiftCode': swiftCode,
      'bankAddress': bankAddress,
    };
  }

  factory PaymentDetails.fromMap(Map<String, dynamic> map) {
    return PaymentDetails(
      paymentMode: map['paymentMode'] ?? '',
      paymentReference: map['paymentReference'] ?? '',
      deliveryTerms: map['deliveryTerms'] ?? map['terms'] ?? '',
      beneficiaryName: map['beneficiaryName'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifsc: map['ifsc'] ?? '',
      swiftCode: map['swiftCode'] ?? '',
      bankAddress: map['bankAddress'] ?? '',
    );
  }
}

// ============================================================================
// 📊 TOTALS
// ============================================================================

class Totals {
  final double subTotal;
  final double freight;
  final double insurance;
  final double tax;
  final double grandTotal;
  final double grandTotalInr;

  Totals({
    required this.subTotal,
    this.freight = 0,
    this.insurance = 0,
    required this.tax,
    required this.grandTotal,
    required this.grandTotalInr,
  });

  Map<String, dynamic> toMap() {
    return {
      'subTotal': subTotal,
      'freight': freight,
      'insurance': insurance,
      'tax': tax,
      'grandTotal': grandTotal,
      'grandTotalInr': grandTotalInr,
    };
  }

  factory Totals.fromMap(Map<String, dynamic> map) {
    return Totals(
      subTotal: _parseDouble(map['subTotal']),
      freight: _parseDouble(map['freight']),
      insurance: _parseDouble(map['insurance']),
      tax: _parseDouble(map['tax']),
      grandTotal: _parseDouble(map['grandTotal']),
      grandTotalInr: _parseDouble(map['grandTotalInr']),
    );
  }
}

// ============================================================================
// 🧾 MAIN EXPORT INVOICE MODEL (Strict ERP Compliance)
// ============================================================================

class ExportInvoiceModel {
  final String id;
  final String companyId;
  final String customerId;
  final String invoiceNumber;
  final String exportReference;
  final DateTime invoiceDate;
  final DateTime? buyerOrderDate;
  final DateTime dueDate;
  final String paymentTerms;
  final String baseCurrency;
  final double baseAmount;
  final String currency;
  final double exchangeRate;
  final String placeOfSupply;
  final String status;
  final String createdBy;

  final Party supplier;
  final Party buyer;
  final Party consignee;

  final ExportDetails exportDetails;
  final Logistics logistics;
  final List<ExportInvoiceItem> items;
  final TaxDetails taxDetails;
  final Totals totals;
  final PaymentDetails paymentDetails;

  final String declaration;
  final String notes;
  final String authorizedSignatory;

  final DateTime createdAt;
  final DateTime updatedAt;

  final int version;
  final bool isActive;

  final double receivedAmount;
  final double advanceAmount;
  final double advancePercentage;
  final double amountReceived;
  final double amountOutstanding;
  final double baseAmountOutstanding;
  final String paymentStatus;

  ExportInvoiceModel({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.invoiceNumber,
    this.exportReference = '',
    required this.invoiceDate,
    this.buyerOrderDate,
    required this.dueDate,
    required this.paymentTerms,
    this.baseCurrency = 'INR',
    required this.baseAmount,
    required this.currency,
    required this.exchangeRate,
    required this.placeOfSupply,
    required this.status,
    required this.createdBy,
    required this.supplier,
    required this.buyer,
    required this.consignee,
    required this.exportDetails,
    required this.logistics,
    required this.items,
    required this.taxDetails,
    required this.totals,
    required this.paymentDetails,
    required this.declaration,
    this.notes = '',
    this.authorizedSignatory = '',
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.isActive = true,
    this.receivedAmount = 0.0,
    this.advanceAmount = 0.0,
    this.advancePercentage = 0.0,
    required this.amountReceived,
    required this.amountOutstanding,
    required this.baseAmountOutstanding,
    this.paymentStatus = 'UNPAID',
  });

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'companyId': companyId,
      'customerId': customerId,
      'invoiceNumber': invoiceNumber,
      'exportReference': exportReference,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'paymentTerms': paymentTerms,
      'baseCurrency': baseCurrency,
      'baseAmount': baseAmount,
      'currency': currency,
      'exchangeRate': exchangeRate,
      'placeOfSupply': placeOfSupply,
      'status': status,
      'createdBy': createdBy,
      'supplier': supplier.toMap(),
      'buyer': buyer.toMap(),
      'consignee': consignee.toMap(),
      'exportDetails': exportDetails.toMap(),
      'logistics': logistics.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      'taxDetails': taxDetails.toMap(),
      'totals': totals.toMap(),
      'paymentDetails': paymentDetails.toMap(),
      'declaration': declaration,
      'notes': notes,
      'authorizedSignatory': authorizedSignatory,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'version': version,
      'isActive': isActive,
      'receivedAmount': receivedAmount,
      'advanceAmount': advanceAmount,
      'advancePercentage': advancePercentage,
      'amountReceived': amountReceived,
      'amountOutstanding': amountOutstanding,
      'baseAmountOutstanding': baseAmountOutstanding,
      'paymentStatus': paymentStatus,
    };

    if (buyerOrderDate != null) {
      data['buyerOrderDate'] = Timestamp.fromDate(buyerOrderDate!);
    }

    return data;
  }

  factory ExportInvoiceModel.fromMap(Map<String, dynamic> map, String docId) {
    double grandTotal = _parseDouble(map['totals']?['grandTotal']);
    double exchangeRate = _parseDouble(map['exchangeRate']);
    if (exchangeRate <= 0) exchangeRate = 1.0;

    double parsedAmountReceived = _parseDouble(map['amountReceived']);
    double parsedAdvanceAmount = _parseDouble(map['advanceAmount']);
    double legacyReceivedAmount = _parseDouble(map['receivedAmount']);

    double finalReceived = parsedAmountReceived > 0
        ? parsedAmountReceived
        : (parsedAdvanceAmount + legacyReceivedAmount);

    double outstanding = map.containsKey('amountOutstanding')
        ? _parseDouble(map['amountOutstanding'])
        : (grandTotal - finalReceived);

    double baseOutstanding = map.containsKey('baseAmountOutstanding')
        ? _parseDouble(map['baseAmountOutstanding'])
        : (outstanding * exchangeRate);

    double advancePctRaw = map.containsKey('advancePercentage')
        ? _parseDouble(map['advancePercentage'])
        : (grandTotal > 0 ? (parsedAdvanceAmount / grandTotal) * 100 : 0.0);

    double advancePct = double.parse(advancePctRaw.toStringAsFixed(2));

    String computedStatus;
    if (grandTotal <= 0) {
      computedStatus = 'DRAFT';
    } else if (finalReceived <= 0) {
      computedStatus = 'UNPAID';
    } else if (finalReceived >= grandTotal - 0.01) {
      computedStatus = 'PAID';
    } else {
      computedStatus = 'PARTIALLY PAID';
    }

    return ExportInvoiceModel(
      id: docId,
      companyId: map['companyId'] ?? '',
      customerId: map['customerId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      exportReference: map['exportReference'] ?? '',
      invoiceDate: (map['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      buyerOrderDate: (map['buyerOrderDate'] as Timestamp?)?.toDate(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentTerms: map['paymentTerms'] ?? 'Due on Receipt',
      baseCurrency: map['baseCurrency'] ?? 'INR',
      baseAmount: _parseDouble(map['baseAmount']),
      currency: map['currency'] ?? 'USD',
      exchangeRate: exchangeRate,
      placeOfSupply: map['placeOfSupply'] ?? '',
      status: map['status'] ?? 'Draft',
      createdBy: map['createdBy'] ?? '',
      supplier: Party.fromMap(map['supplier'] ?? {}),
      buyer: Party.fromMap(map['buyer'] ?? {}),
      consignee: Party.fromMap(map['consignee'] ?? {}),
      exportDetails: ExportDetails.fromMap(map['exportDetails'] ?? {}),
      logistics: Logistics.fromMap(map['logistics'] ?? {}),
      items: List<ExportInvoiceItem>.from(
        (map['items'] ?? []).map((x) => ExportInvoiceItem.fromMap(x, x['id'] ?? docId)),
      ),
      taxDetails: TaxDetails.fromMap(map['taxDetails'] ?? {}),
      totals: Totals.fromMap(map['totals'] ?? {}),
      paymentDetails: PaymentDetails.fromMap(map['paymentDetails'] ?? {}),
      declaration: map['declaration'] ?? '',
      notes: map['notes'] ?? '',
      authorizedSignatory: map['authorizedSignatory'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      version: _parseInt(map['version'] ?? 1),
      isActive: map['isActive'] as bool? ?? true,
      receivedAmount: legacyReceivedAmount,
      advanceAmount: parsedAdvanceAmount,
      advancePercentage: advancePct,
      amountReceived: finalReceived,
      amountOutstanding: outstanding,
      baseAmountOutstanding: baseOutstanding,
      paymentStatus: map['paymentStatus'] ?? computedStatus,
    );
  }
}