// FILE PATH: lib/modules/service/service_quotations/models/service_quotation_models.dart

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

String _safeString(dynamic value) => (value ?? '').toString().trim();

double _safeDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

bool _safeBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toString().trim().toLowerCase() == 'true';
  if (value is int) return value == 1;
  return false;
}

DateTime? _safeDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    // Attempt dynamic invocation for Firestore Timestamp without importing it
    try {
      return (value as dynamic).toDate();
    } catch (_) {}

    // Fallback to standard ISO 8601 parsing
    return DateTime.tryParse(value.toString());
  } catch (_) {
    return null;
  }
}

// ==========================================
// QUOTATION ATTACHMENT MODEL
// ==========================================

class QuotationAttachment {
  final String fileName;
  final String fileUrl;
  final String fileType;

  const QuotationAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
  });

  factory QuotationAttachment.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const QuotationAttachment(fileName: '', fileUrl: '', fileType: '');
    return QuotationAttachment(
      fileName: _safeString(map['fileName']),
      fileUrl: _safeString(map['fileUrl']),
      fileType: _safeString(map['fileType']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
    };
  }

  QuotationAttachment copyWith({
    String? fileName,
    String? fileUrl,
    String? fileType,
  }) {
    return QuotationAttachment(
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
    );
  }
}

// ==========================================
// VISIT CHARGE MODEL
// ==========================================

class VisitCharge {
  final String description;
  final double qty;
  final double rate;
  final double amount;

  const VisitCharge({
    required this.description,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  factory VisitCharge.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const VisitCharge(description: '', qty: 0.0, rate: 0.0, amount: 0.0);
    return VisitCharge(
      description: _safeString(map['description'] ?? map['type']),
      qty: _safeDouble(map['qty'] ?? map['quantity']),
      rate: _safeDouble(map['rate']),
      amount: _safeDouble(map['amount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'qty': qty,
      'rate': rate,
      'amount': amount,
    };
  }

  VisitCharge copyWith({
    String? description,
    double? qty,
    double? rate,
    double? amount,
  }) {
    return VisitCharge(
      description: description ?? this.description,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
    );
  }
}

// ==========================================
// QUOTATION LINE ITEM MODEL
// ==========================================

class QuotationLineItem {
  final String itemId;
  final String itemName;
  final String itemType;
  final double qty;
  final double rate;
  final double discount;
  final double amount;
  final String? partNo;
  final String? hsnCode;
  final String? uom;

  const QuotationLineItem({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.qty,
    required this.rate,
    required this.discount,
    required this.amount,
    this.partNo,
    this.hsnCode,
    this.uom,
  });

  factory QuotationLineItem.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const QuotationLineItem(
        itemId: '',
        itemName: '',
        itemType: '',
        qty: 0.0,
        rate: 0.0,
        discount: 0.0,
        amount: 0.0,
        partNo: '-',
        hsnCode: '-',
        uom: 'Nos',
      );
    }
    return QuotationLineItem(
      itemId: _safeString(map['itemId'] ?? map['id'] ?? map['productId']),
      itemName: _safeString(map['itemName'] ?? map['name']),
      itemType: _safeString(map['itemType'] ?? map['productNature']),
      qty: _safeDouble(map['qty'] ?? map['quantity']),
      rate: _safeDouble(map['rate'] ?? map['unitPrice']),
      discount: _safeDouble(map['discount'] ?? map['discountPercent']),
      amount: _safeDouble(map['amount'] ?? map['total']),
      partNo: map['partNo']?.toString() ?? map['sku']?.toString() ?? '-',
      hsnCode: map['hsnCode']?.toString() ?? '-',
      uom: map['uom']?.toString() ?? 'Nos',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemType': itemType,
      'qty': qty,
      'rate': rate,
      'discount': discount,
      'amount': amount,
      'partNo': partNo,
      'hsnCode': hsnCode,
      'uom': uom,
    };
  }

  QuotationLineItem copyWith({
    String? itemId,
    String? itemName,
    String? itemType,
    double? qty,
    double? rate,
    double? discount,
    double? amount,
    String? partNo,
    String? hsnCode,
    String? uom,
  }) {
    return QuotationLineItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemType: itemType ?? this.itemType,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      discount: discount ?? this.discount,
      amount: amount ?? this.amount,
      partNo: partNo ?? this.partNo,
      hsnCode: hsnCode ?? this.hsnCode,
      uom: uom ?? this.uom,
    );
  }
}

// ==========================================
// QUOTATION MACHINE MODEL
// ==========================================

class QuotationMachine {
  final String machineId;
  final String machineName;
  final String machineModel;
  final String serialNumber;
  final String warrantyStatus;

  const QuotationMachine({
    required this.machineId,
    required this.machineName,
    required this.machineModel,
    required this.serialNumber,
    required this.warrantyStatus,
  });

  factory QuotationMachine.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const QuotationMachine(machineId: '', machineName: '', machineModel: '', serialNumber: '', warrantyStatus: '');
    }
    return QuotationMachine(
      machineId: _safeString(map['machineId'] ?? map['machineUid'] ?? map['id']),
      machineName: _safeString(map['machineName'] ?? map['name']),
      machineModel: _safeString(map['machineModel'] ?? map['model']),
      serialNumber: _safeString(map['serialNumber'] ?? map['serial']),
      warrantyStatus: _safeString(map['warrantyStatus']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'machineId': machineId,
      'machineName': machineName,
      'machineModel': machineModel,
      'serialNumber': serialNumber,
      'warrantyStatus': warrantyStatus,
    };
  }

  QuotationMachine copyWith({
    String? machineId,
    String? machineName,
    String? machineModel,
    String? serialNumber,
    String? warrantyStatus,
  }) {
    return QuotationMachine(
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      machineModel: machineModel ?? this.machineModel,
      serialNumber: serialNumber ?? this.serialNumber,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
    );
  }
}

// ==========================================
// SERVICE QUOTATION MODEL
// ==========================================

class ServiceQuotationModel {
  final String quotationId;
  final String quotationNumber;

  final String requestId;
  final String requestNumber;

  final String visitId;
  final String visitNumber;

  final String customerId;
  final String customerName;

  final String quotationType;
  final String quotationSource;
  final String billingType;
  final String followUpAction;

  final bool dispatchRequired;
  final bool installationRequired;
  final bool visitRequired;

  final String status;
  final String paymentStatus;
  final String approvalStatus;

  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;

  final String remarks;

  final List<QuotationMachine> machines;
  final List<QuotationLineItem> lineItems;
  final List<VisitCharge> visitCharges;
  final List<QuotationAttachment> attachments;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceQuotationModel({
    required this.quotationId,
    required this.quotationNumber,
    required this.requestId,
    required this.requestNumber,
    required this.visitId,
    required this.visitNumber,
    required this.customerId,
    required this.customerName,
    required this.quotationType,
    required this.quotationSource,
    required this.billingType,
    required this.followUpAction,
    required this.dispatchRequired,
    required this.installationRequired,
    required this.visitRequired,
    required this.status,
    required this.paymentStatus,
    required this.approvalStatus,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.grandTotal,
    required this.remarks,
    required this.machines,
    required this.lineItems,
    required this.visitCharges,
    required this.attachments,
    this.createdAt,
    this.updatedAt,
  });

  factory ServiceQuotationModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return ServiceQuotationModel(
        quotationId: '', quotationNumber: '', requestId: '', requestNumber: '',
        visitId: '', visitNumber: '', customerId: '', customerName: '',
        quotationType: '', quotationSource: '', billingType: '', followUpAction: '',
        dispatchRequired: false, installationRequired: false, visitRequired: false,
        status: '', paymentStatus: '', approvalStatus: '',
        subtotal: 0.0, discount: 0.0, taxAmount: 0.0, grandTotal: 0.0,
        remarks: '', machines: [], lineItems: [], visitCharges: [], attachments: [],
      );
    }

    return ServiceQuotationModel(
      quotationId: _safeString(map['quotationId'] ?? map['id']),
      quotationNumber: _safeString(map['quotationNumber'] ?? map['quoteNumber'] ?? map['quotationNo']),

      requestId: _safeString(map['requestId'] ?? map['serviceRequestId']),
      requestNumber: _safeString(map['requestNumber'] ?? map['serviceRequestNumber']),

      visitId: _safeString(map['visitId'] ?? map['serviceVisitId']),
      visitNumber: _safeString(map['visitNumber'] ?? map['serviceVisitNumber']),

      customerId: _safeString(map['customerId']),
      customerName: _safeString(map['customerName'] ?? map['clientName']),

      quotationType: _safeString(map['quotationType']),
      quotationSource: _safeString(map['quotationSource'] ?? map['source']),
      billingType: _safeString(map['billingType']),
      followUpAction: _safeString(map['followUpAction']),

      dispatchRequired: _safeBool(map['dispatchRequired']),
      installationRequired: _safeBool(map['installationRequired']),
      visitRequired: _safeBool(map['visitRequired']),

      status: _safeString(map['status']),
      paymentStatus: _safeString(map['paymentStatus']),
      approvalStatus: _safeString(map['approvalStatus']),

      subtotal: _safeDouble(map['subtotal'] ?? map['totalSubtotal']),
      discount: _safeDouble(map['discount'] ?? map['totalItemDiscount']),
      taxAmount: _safeDouble(map['taxAmount'] ?? map['totalTax']),
      grandTotal: _safeDouble(map['grandTotal'] ?? map['finalTotal']),

      remarks: _safeString(map['remarks'] ?? map['internalNotes']),

      machines: (map['machines'] as List?)?.map((e) => QuotationMachine.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      lineItems: (map['lineItems'] ?? map['items'] as List?)?.map((e) => QuotationLineItem.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      visitCharges: (map['visitCharges'] as List?)?.map((e) => VisitCharge.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      attachments: (map['attachments'] as List?)?.map((e) => QuotationAttachment.fromMap(e as Map<String, dynamic>)).toList() ?? [],

      createdAt: _safeDateTime(map['createdAt']),
      updatedAt: _safeDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quotationId': quotationId,
      'quotationNumber': quotationNumber,
      'requestId': requestId,
      'requestNumber': requestNumber,
      'visitId': visitId,
      'visitNumber': visitNumber,
      'customerId': customerId,
      'customerName': customerName,
      'quotationType': quotationType,
      'quotationSource': quotationSource,
      'billingType': billingType,
      'followUpAction': followUpAction,
      'dispatchRequired': dispatchRequired,
      'installationRequired': installationRequired,
      'visitRequired': visitRequired,
      'status': status,
      'paymentStatus': paymentStatus,
      'approvalStatus': approvalStatus,
      'subtotal': subtotal,
      'discount': discount,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'remarks': remarks,
      'machines': machines.map((x) => x.toMap()).toList(),
      'lineItems': lineItems.map((x) => x.toMap()).toList(),
      'visitCharges': visitCharges.map((x) => x.toMap()).toList(),
      'attachments': attachments.map((x) => x.toMap()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  ServiceQuotationModel copyWith({
    String? quotationId,
    String? quotationNumber,
    String? requestId,
    String? requestNumber,
    String? visitId,
    String? visitNumber,
    String? customerId,
    String? customerName,
    String? quotationType,
    String? quotationSource,
    String? billingType,
    String? followUpAction,
    bool? dispatchRequired,
    bool? installationRequired,
    bool? visitRequired,
    String? status,
    String? paymentStatus,
    String? approvalStatus,
    double? subtotal,
    double? discount,
    double? taxAmount,
    double? grandTotal,
    String? remarks,
    List<QuotationMachine>? machines,
    List<QuotationLineItem>? lineItems,
    List<VisitCharge>? visitCharges,
    List<QuotationAttachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceQuotationModel(
      quotationId: quotationId ?? this.quotationId,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      requestId: requestId ?? this.requestId,
      requestNumber: requestNumber ?? this.requestNumber,
      visitId: visitId ?? this.visitId,
      visitNumber: visitNumber ?? this.visitNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      quotationType: quotationType ?? this.quotationType,
      quotationSource: quotationSource ?? this.quotationSource,
      billingType: billingType ?? this.billingType,
      followUpAction: followUpAction ?? this.followUpAction,
      dispatchRequired: dispatchRequired ?? this.dispatchRequired,
      installationRequired: installationRequired ?? this.installationRequired,
      visitRequired: visitRequired ?? this.visitRequired,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      remarks: remarks ?? this.remarks,
      machines: machines ?? this.machines,
      lineItems: lineItems ?? this.lineItems,
      visitCharges: visitCharges ?? this.visitCharges,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}