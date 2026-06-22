import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> purchaseBillPaymentStatuses = [
  'Unpaid',
  'Partially Paid',
  'Paid',
];

const List<String> purchaseBillStatuses = ['Draft', 'Posted'];

class PurchaseBillLine {
  const PurchaseBillLine({
    required this.productId,
    required this.productName,
    required this.description,
    required this.hsnCode,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.discountPercent,
    required this.taxPercent,
    required this.taxAmount,
    required this.lineTotal,
    this.productNature = '',
    this.trackInventory = true,
  });

  final String productId;
  final String productName;
  final String description;
  final String hsnCode;
  final String unit;
  final double quantity;
  final double rate;
  final double discountPercent;
  final double taxPercent;
  final double taxAmount;
  final double lineTotal;
  final String productNature;
  final bool trackInventory;

  double get subtotal => quantity * rate;

  double get discountAmount => subtotal * discountPercent / 100;

  double get taxableValue => subtotal - discountAmount;

  double get effectivePurchaseRate =>
      quantity <= 0 ? 0 : taxableValue / quantity;

  factory PurchaseBillLine.fromMap(Map<String, dynamic> data) {
    final quantity = _number(data['quantity'] ?? data['qty']);
    final rate = _number(data['rate'] ?? data['unitPrice']);
    final discountPercent = _number(
      data['discountPercent'] ?? data['discountPercentage'],
    );
    final taxPercent = _number(
      data['taxPercent'] ??
          data['gstPercent'] ??
          data['gstPercentage'] ??
          data['taxPercentage'],
    );
    final subtotal = quantity * rate;
    final discount = subtotal * discountPercent / 100;
    final taxable = subtotal - discount;
    final taxAmount = data.containsKey('taxAmount')
        ? _number(data['taxAmount'])
        : data.containsKey('gstAmount')
        ? _number(data['gstAmount'])
        : taxable * taxPercent / 100;
    final lineTotal = data.containsKey('lineTotal')
        ? _number(data['lineTotal'])
        : data.containsKey('totalAmount')
        ? _number(data['totalAmount'])
        : taxable + taxAmount;

    return PurchaseBillLine(
      productId: _text(data['productId']),
      productName: _firstText(data, ['productName', 'name']),
      description: _text(data['description']),
      hsnCode: _firstText(data, ['hsnCode', 'hsn']),
      unit: _firstText(data, ['unit', 'uom']),
      quantity: quantity,
      rate: rate,
      discountPercent: discountPercent,
      taxPercent: taxPercent,
      taxAmount: taxAmount,
      lineTotal: lineTotal,
      productNature: _firstText(data, ['productNature', 'nature']),
      trackInventory: data['trackInventory'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName.trim(),
      'description': description.trim(),
      'hsnCode': hsnCode.trim(),
      'unit': unit.trim(),
      'quantity': quantity,
      'rate': rate,
      'discountPercent': discountPercent,
      'taxPercent': taxPercent,
      'taxAmount': taxAmount,
      'lineTotal': lineTotal,
      'productNature': productNature.trim(),
      'trackInventory': trackInventory,
      // Compatibility aliases used elsewhere in the ERP.
      'uom': unit.trim(),
      'taxableValue': taxableValue,
      'gstPercentage': taxPercent,
      'gstAmount': taxAmount,
      'totalAmount': lineTotal,
    };
  }
}

class PurchaseBillTotals {
  const PurchaseBillTotals({
    required this.subtotal,
    required this.discountTotal,
    required this.taxableValue,
    required this.taxAmount,
    required this.grandTotal,
  });

  final double subtotal;
  final double discountTotal;
  final double taxableValue;
  final double taxAmount;
  final double grandTotal;

  factory PurchaseBillTotals.fromLines(
    Iterable<PurchaseBillLine> lines, {
    double freightAmount = 0,
    double otherCharges = 0,
    double tdsAmount = 0,
  }) {
    var subtotal = 0.0;
    var discount = 0.0;
    var taxable = 0.0;
    var tax = 0.0;

    for (final line in lines) {
      subtotal += line.subtotal;
      discount += line.discountAmount;
      taxable += line.taxableValue;
      tax += line.taxAmount;
    }

    return PurchaseBillTotals(
      subtotal: subtotal,
      discountTotal: discount,
      taxableValue: taxable,
      taxAmount: tax,
      grandTotal: (taxable + tax + freightAmount + otherCharges - tdsAmount)
          .clamp(0, double.infinity),
    );
  }
}

class PurchaseBillAttachment {
  const PurchaseBillAttachment({
    required this.url,
    required this.path,
    required this.fileName,
    required this.contentType,
    required this.size,
    this.uploadedAt,
  });

  final String url;
  final String path;
  final String fileName;
  final String contentType;
  final int size;
  final DateTime? uploadedAt;

  bool get isPdf =>
      contentType == 'application/pdf' ||
      fileName.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      contentType.startsWith('image/') ||
      RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(fileName);

  factory PurchaseBillAttachment.fromMap(Map<String, dynamic> data) {
    return PurchaseBillAttachment(
      url: _text(data['url']),
      path: _text(data['path']),
      fileName: _firstText(data, ['fileName', 'name']),
      contentType: _text(data['contentType']),
      size: _integer(data['size']),
      uploadedAt: _date(data['uploadedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'path': path,
      'fileName': fileName,
      'contentType': contentType,
      'size': size,
      'uploadedAt': uploadedAt == null ? null : Timestamp.fromDate(uploadedAt!),
    };
  }
}

class PendingPurchaseBillAttachment {
  const PendingPurchaseBillAttachment({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final Uint8List bytes;

  int get size => bytes.lengthInBytes;
}

class PurchaseProductMasterItem {
  const PurchaseProductMasterItem({
    required this.id,
    required this.name,
    required this.description,
    required this.hsnCode,
    required this.unit,
    required this.defaultPurchaseRate,
    required this.taxPercent,
    required this.productNature,
    required this.trackInventory,
    required this.searchText,
  });

  final String id;
  final String name;
  final String description;
  final String hsnCode;
  final String unit;
  final double defaultPurchaseRate;
  final double taxPercent;
  final String productNature;
  final bool trackInventory;
  final String searchText;

  factory PurchaseProductMasterItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = _text(data['name']);
    final description = _text(data['description']);
    final hsnCode = _firstText(data, ['hsnCode', 'hsn']);
    final productNature = _firstText(data, [
      'productNature',
      'nature',
      'productNatureLower',
    ]);
    final type = _text(data['type']).toLowerCase();
    final rate = _firstNumber(data, [
      'purchaseRate',
      'lastPurchaseRate',
      'averagePurchaseRate',
      'valuationRate',
      'costPrice',
      'unitPrice',
    ]);
    final searchText = [
      name,
      data['itemCode'],
      data['sku'],
      data['barcode'],
      data['category'],
      data['subcategory'],
      data['make'],
      hsnCode,
      description,
    ].where((value) => value != null).join(' ').toLowerCase();

    return PurchaseProductMasterItem(
      id: doc.id,
      name: name,
      description: description,
      hsnCode: hsnCode,
      unit: _firstText(data, ['uom', 'unit'], fallback: 'Nos.'),
      defaultPurchaseRate: rate,
      taxPercent: _number(
        data['gstPercentage'] ?? data['taxPercent'] ?? data['gstPercent'],
      ),
      productNature: productNature,
      trackInventory:
          data['trackInventory'] != false &&
          type != 'service' &&
          type != 'non_stock',
      searchText: searchText,
    );
  }
}

class PurchaseBillModel {
  const PurchaseBillModel({
    this.id = '',
    required this.companyId,
    required this.purchaseBillNo,
    required this.purchaseBillDate,
    required this.vendorId,
    required this.vendorName,
    required this.paymentTerms,
    required this.customPaymentTerms,
    required this.products,
    required this.subtotal,
    required this.discountTotal,
    required this.taxableValue,
    required this.taxAmount,
    required this.grandTotal,
    required this.paymentStatus,
    required this.status,
    required this.salesOrderRef,
    required this.grnRef,
    required this.supplierInvoiceNo,
    required this.supplierInvoiceDate,
    required this.freightAmount,
    required this.otherCharges,
    required this.tdsAmount,
    required this.remarks,
    required this.warehouseId,
    required this.warehouseName,
    this.attachmentUrls = const [],
    this.attachments = const [],
    this.inventoryPosted = false,
    this.inventoryPostedAt,
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
  final String paymentTerms;
  final String customPaymentTerms;
  final List<PurchaseBillLine> products;
  final double subtotal;
  final double discountTotal;
  final double taxableValue;
  final double taxAmount;
  final double grandTotal;
  final String paymentStatus;
  final String status;
  final String salesOrderRef;
  final String grnRef;
  final String supplierInvoiceNo;
  final DateTime? supplierInvoiceDate;
  final double freightAmount;
  final double otherCharges;
  final double tdsAmount;
  final String remarks;
  final String warehouseId;
  final String warehouseName;
  final List<String> attachmentUrls;
  final List<PurchaseBillAttachment> attachments;
  final bool inventoryPosted;
  final DateTime? inventoryPostedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  bool get hasAttachment =>
      attachmentUrls.any((url) => url.trim().isNotEmpty) ||
      attachments.any((attachment) => attachment.url.trim().isNotEmpty);

  bool get isPosted => inventoryPosted || status == 'Posted';

  String get effectivePaymentTerms => paymentTerms == 'Custom'
      ? customPaymentTerms.trim()
      : paymentTerms.trim();

  String get pdfUrl {
    for (final attachment in attachments) {
      if (attachment.isPdf && attachment.url.isNotEmpty) return attachment.url;
    }
    return '';
  }

  factory PurchaseBillModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final legacyGst =
        _number(data['cgst']) + _number(data['sgst']) + _number(data['igst']);
    final products = _mapList(
      data['products'] ?? data['items'],
    ).map(PurchaseBillLine.fromMap).toList(growable: false);
    final calculated = PurchaseBillTotals.fromLines(
      products,
      freightAmount: _number(data['freightAmount'] ?? data['freight']),
      otherCharges: _number(data['otherCharges']),
      tdsAmount: _number(data['tdsAmount']),
    );
    final attachments = _mapList(data['attachments'])
        .map(PurchaseBillAttachment.fromMap)
        .where((attachment) => attachment.url.isNotEmpty)
        .toList();
    final legacyPdfUrl = _firstText(data, ['pdfUrl', 'attachmentUrl']);
    if (legacyPdfUrl.isNotEmpty &&
        !attachments.any((attachment) => attachment.url == legacyPdfUrl)) {
      attachments.add(
        PurchaseBillAttachment(
          url: legacyPdfUrl,
          path: _firstText(data, ['pdfPath', 'attachmentPath']),
          fileName: _firstText(data, ['pdfFileName', 'attachmentName']),
          contentType: 'application/pdf',
          size: 0,
          uploadedAt: _date(
            data['pdfUploadedAt'] ?? data['attachmentUploadedAt'],
          ),
        ),
      );
    }
    final attachmentUrls = _stringList(data['attachmentUrls']).toSet()
      ..addAll(attachments.map((attachment) => attachment.url));
    final inventoryPosted = data['inventoryPosted'] == true;

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
      paymentTerms: _text(data['paymentTerms']),
      customPaymentTerms: _text(data['customPaymentTerms']),
      products: products,
      subtotal: data.containsKey('subtotal')
          ? _number(data['subtotal'])
          : products.isEmpty
          ? _number(data['taxableAmount'] ?? data['subTotal'])
          : calculated.subtotal,
      discountTotal: data.containsKey('discountTotal')
          ? _number(data['discountTotal'])
          : data.containsKey('discountAmount')
          ? _number(data['discountAmount'])
          : calculated.discountTotal,
      taxableValue: data.containsKey('taxableValue')
          ? _number(data['taxableValue'])
          : data.containsKey('taxableAmount')
          ? _number(data['taxableAmount'])
          : calculated.taxableValue,
      taxAmount: data.containsKey('taxAmount')
          ? _number(data['taxAmount'])
          : data.containsKey('gstAmount')
          ? _number(data['gstAmount'])
          : legacyGst > 0
          ? legacyGst
          : calculated.taxAmount,
      grandTotal: data.containsKey('grandTotal')
          ? _number(data['grandTotal'])
          : data.containsKey('totalAmount')
          ? _number(data['totalAmount'])
          : calculated.grandTotal,
      paymentStatus: _text(data['paymentStatus'], fallback: 'Unpaid'),
      status: _text(
        data['status'],
        fallback: inventoryPosted ? 'Posted' : 'Draft',
      ),
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
      freightAmount: _number(data['freightAmount'] ?? data['freight']),
      otherCharges: _number(data['otherCharges']),
      tdsAmount: _number(data['tdsAmount']),
      remarks: _text(data['remarks']),
      warehouseId: _text(data['warehouseId']),
      warehouseName: _text(data['warehouseName']),
      attachmentUrls: attachmentUrls.toList(growable: false),
      attachments: attachments,
      inventoryPosted: inventoryPosted,
      inventoryPostedAt: _date(data['inventoryPostedAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _text(data['createdBy']),
      updatedBy: _text(data['updatedBy']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final firstPdf = attachments
        .where((attachment) => attachment.isPdf)
        .firstOrNull;
    return {
      'companyId': companyId,
      'purchaseBillNo': purchaseBillNo.trim(),
      'purchaseBillDate': Timestamp.fromDate(purchaseBillDate),
      'vendorId': vendorId,
      'vendorName': vendorName.trim(),
      'paymentTerms': paymentTerms,
      'customPaymentTerms': customPaymentTerms.trim(),
      'products': products.map((product) => product.toMap()).toList(),
      'subtotal': subtotal,
      'discountTotal': discountTotal,
      'taxableValue': taxableValue,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'attachmentUrls': attachmentUrls,
      'attachments': attachments
          .map((attachment) => attachment.toMap())
          .toList(),
      'paymentStatus': paymentStatus,
      'status': status,
      'salesOrderRef': salesOrderRef.trim(),
      'grnRef': grnRef.trim(),
      'supplierInvoiceNo': supplierInvoiceNo.trim(),
      'supplierInvoiceDate': supplierInvoiceDate == null
          ? null
          : Timestamp.fromDate(supplierInvoiceDate!),
      'freightAmount': freightAmount,
      'otherCharges': otherCharges,
      'tdsAmount': tdsAmount,
      'remarks': remarks.trim(),
      'warehouseId': warehouseId,
      'warehouseName': warehouseName,
      'inventoryPosted': inventoryPosted,
      'inventoryPostedAt': inventoryPostedAt == null
          ? null
          : Timestamp.fromDate(inventoryPostedAt!),
      // Compatibility fields retained for existing readers.
      'taxableAmount': taxableValue,
      'discountAmount': discountTotal,
      'gstAmount': taxAmount,
      'totalAmount': grandTotal,
      'pdfUrl': firstPdf?.url ?? '',
      'pdfPath': firstPdf?.path ?? '',
      'pdfFileName': firstPdf?.fileName ?? '',
      'pdfUploadedAt': firstPdf?.uploadedAt == null
          ? null
          : Timestamp.fromDate(firstPdf!.uploadedAt!),
    };
  }

  PurchaseBillModel copyWith({
    String? id,
    String? purchaseBillNo,
    String? status,
    List<String>? attachmentUrls,
    List<PurchaseBillAttachment>? attachments,
    bool? inventoryPosted,
    DateTime? inventoryPostedAt,
  }) {
    return PurchaseBillModel(
      id: id ?? this.id,
      companyId: companyId,
      purchaseBillNo: purchaseBillNo ?? this.purchaseBillNo,
      purchaseBillDate: purchaseBillDate,
      vendorId: vendorId,
      vendorName: vendorName,
      paymentTerms: paymentTerms,
      customPaymentTerms: customPaymentTerms,
      products: products,
      subtotal: subtotal,
      discountTotal: discountTotal,
      taxableValue: taxableValue,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      paymentStatus: paymentStatus,
      status: status ?? this.status,
      salesOrderRef: salesOrderRef,
      grnRef: grnRef,
      supplierInvoiceNo: supplierInvoiceNo,
      supplierInvoiceDate: supplierInvoiceDate,
      freightAmount: freightAmount,
      otherCharges: otherCharges,
      tdsAmount: tdsAmount,
      remarks: remarks,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      attachments: attachments ?? this.attachments,
      inventoryPosted: inventoryPosted ?? this.inventoryPosted,
      inventoryPostedAt: inventoryPostedAt ?? this.inventoryPostedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }
}

String purchaseFinancialYear(DateTime date) {
  final startYear = date.month >= DateTime.april ? date.year : date.year - 1;
  final endYear = (startYear + 1) % 100;
  return '$startYear-${endYear.toString().padLeft(2, '0')}';
}

double weightedAveragePurchaseRate({
  required double currentQuantity,
  required double currentRate,
  required double receivedQuantity,
  required double receivedTaxableValue,
}) {
  final newQuantity = currentQuantity + receivedQuantity;
  if (newQuantity <= 0) return 0;
  return ((currentQuantity * currentRate) + receivedTaxableValue) / newQuantity;
}

String _text(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
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

double _firstNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _number(data[key]);
    if (value > 0) return value;
  }
  return 0;
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

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
