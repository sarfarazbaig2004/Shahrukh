// FILE PATH: lib/modules/sales/quotations/quotation_pdf_generator.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. MODELS (SINGLE SOURCE OF TRUTH)
// ==========================================

class QuotationLineItem {
  String id;
  String productId;
  String itemCode;
  String name;
  String description;
  String scopeOfSupply;
  String hsnCode;
  double quantity;
  String uom;
  double unitPrice;
  double discountPercent;
  double cgstPercent;
  double sgstPercent;
  double igstPercent;
  double availableStock;

  // Advanced Enterprise Parsing Fields
  bool isScopeItem;
  String? parentId;

  QuotationLineItem({
    required this.id,
    required this.productId,
    this.itemCode = '',
    required this.name,
    this.description = '',
    this.scopeOfSupply = '',
    this.hsnCode = '',
    this.quantity = 1,
    this.uom = 'Nos',
    this.unitPrice = 0.0,
    this.discountPercent = 0.0,
    this.cgstPercent = 0.0,
    this.sgstPercent = 0.0,
    this.igstPercent = 0.0,
    this.availableStock = 0.0,
    this.isScopeItem = false,
    this.parentId,
  });

  double get subtotal => quantity * unitPrice;
  double get discountAmount => subtotal * (discountPercent / 100);
  double get taxableAmount => subtotal - discountAmount;
  double get cgstAmount => taxableAmount * (cgstPercent / 100);
  double get sgstAmount => taxableAmount * (sgstPercent / 100);
  double get igstAmount => taxableAmount * (igstPercent / 100);
  double get taxAmount => cgstAmount + sgstAmount + igstAmount;
  double get totalAmount => taxableAmount + taxAmount;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) {
      final double result = value.toDouble();
      return result.isNaN ? 0.0 : result;
    }
    if (value is String) {
      if (value.trim().isEmpty) return 0.0;
      final parsed = double.tryParse(value.replaceAll(',', ''));
      if (parsed != null && !parsed.isNaN) return parsed;
    }
    return 0.0;
  }

  static String _safeString(dynamic value) {
    if (value == null) return '';
    final str = value.toString().trim();
    return str == 'null' ? '' : str;
  }

  static double _parseQty(Map<String, dynamic> map) {
    if (map['quantity'] != null && map['quantity'].toString().trim().isNotEmpty) {
      return _toDouble(map['quantity']);
    }
    if (map['qty'] != null && map['qty'].toString().trim().isNotEmpty) {
      return _toDouble(map['qty']);
    }
    return 1.0;
  }

  static String _parseUom(Map<String, dynamic> map) {
    String u = _safeString(map['uom']);
    if (u.isNotEmpty) return u;
    u = _safeString(map['unit']);
    if (u.isNotEmpty) return u;
    return 'Nos';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'itemCode': itemCode,
      'name': name,
      'description': description,
      'scopeOfSupply': scopeOfSupply,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'uom': uom,
      'unitPrice': unitPrice,
      'discountPercent': discountPercent,
      'cgstPercent': cgstPercent,
      'sgstPercent': sgstPercent,
      'igstPercent': igstPercent,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'availableStock': availableStock,
      'isScopeItem': isScopeItem,
      'parentId': parentId,
    };
  }

  factory QuotationLineItem.fromMap(Map<String, dynamic> map) {
    return QuotationLineItem(
      id: _safeString(map['id']),
      productId: _safeString(map['productId']),
      itemCode: _safeString(
        map['itemCode'] ??
            map['productCode'] ??
            map['item_code'] ??
            map['code'] ??
            map['materialCode'] ??
            map['partNo'] ??
            map['partNumber'] ??
            map['catalogNo'],
      ),
      name: _safeString(map['name']),
      description: _safeString(map['description']),
      scopeOfSupply: _safeString(
        map['scopeOfSupply'] ?? map['scope_of_supply'] ?? map['supplyScope'],
      ),
      hsnCode: _safeString(map['hsnCode']),
      quantity: _parseQty(map),
      uom: _parseUom(map),
      unitPrice: _toDouble(map['unitPrice']),
      discountPercent: _toDouble(map['discountPercent']),
      cgstPercent: _toDouble(map['cgstPercent']),
      sgstPercent: _toDouble(map['sgstPercent']),
      igstPercent: _toDouble(map['igstPercent']),
      availableStock: _toDouble(map['availableStock']),
      isScopeItem: map['isScopeItem'] == true,
      parentId: map['parentId']?.toString(),
    );
  }
}

class TermRow {
  late TextEditingController titleCtrl;
  late TextEditingController valueCtrl;

  TermRow({String title = '', String value = ''}) {
    titleCtrl = TextEditingController(text: title);
    valueCtrl = TextEditingController(text: value);
  }

  void dispose() {
    titleCtrl.dispose();
    valueCtrl.dispose();
  }
}

// ==========================================
// 2. DATA SERVICE (Workspace & User Data)
// ==========================================

class QuotationDataService {
  static Future<Map<String, dynamic>> fetchWorkspaceAndSignatureData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return <String, dynamic>{};

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return <String, dynamic>{};

      final rootData = userDoc.data() ?? <String, dynamic>{};

      final companyId =
      (rootData['activeCompanyId'] ?? rootData['companyId'] ?? '')
          .toString()
          .trim();
      if (companyId.isEmpty || companyId == 'null') return <String, dynamic>{};

      DocumentSnapshot compDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (!compDoc.exists) {
        compDoc = await FirebaseFirestore.instance
            .collection('workspaces')
            .doc(companyId)
            .get();
      }

      final Map<String, dynamic> workspaceData =
      compDoc.exists && compDoc.data() != null
          ? Map<String, dynamic>.from(compDoc.data() as Map)
          : <String, dynamic>{};

      Map<String, dynamic>? membershipData;
      if (rootData['memberships'] != null) {
        membershipData =
        rootData['memberships'][companyId] as Map<String, dynamic>?;
      }

      Map<String, dynamic> compUserData = <String, dynamic>{};
      final compUserDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(user.uid)
          .get();

      if (compUserDoc.exists && compUserDoc.data() != null) {
        compUserData = Map<String, dynamic>.from(compUserDoc.data() as Map);
      }

      final authName = user.displayName ?? '';
      final authPhone = user.phoneNumber ?? '';

      final sigName = (compUserData['name'] ??
          compUserData['fullName'] ??
          membershipData?['name'] ??
          rootData['name'] ??
          rootData['fullName'] ??
          authName)
          .toString()
          .trim();

      String sigDesignation = (compUserData['designation'] ??
          membershipData?['designation'] ??
          rootData['designation'] ??
          '')
          .toString()
          .trim();

      String userDepartment = (compUserData['department'] ??
          membershipData?['department'] ??
          rootData['department'] ??
          '')
          .toString()
          .trim();

      if (sigDesignation.isEmpty && userDepartment.isNotEmpty) {
        sigDesignation = userDepartment;
      }

      final sigPhone = (compUserData['phone'] ??
          compUserData['mobile'] ??
          membershipData?['phone'] ??
          membershipData?['mobile'] ??
          rootData['phone'] ??
          rootData['mobile'] ??
          authPhone)
          .toString()
          .trim();

      String buildCompleteAddress(Map<String, dynamic> data) {
        List<String> addressLines = [];

        final street = (data['streetAddress'] ?? data['address'] ?? '')
            .toString()
            .trim();
        if (street.isNotEmpty) addressLines.add(street);

        final city = (data['city'] ?? '').toString().trim();
        final state = (data['state'] ?? '').toString().trim();
        final zip = (data['postalCode'] ?? data['pincode'] ?? data['zip'] ?? '')
            .toString()
            .trim();

        List<String> localityParts = [];
        if (city.isNotEmpty) localityParts.add(city);
        if (state.isNotEmpty) localityParts.add(state);
        if (zip.isNotEmpty) localityParts.add(zip);

        if (localityParts.isNotEmpty) {
          addressLines.add(localityParts.join(', '));
        }

        final country = (data['country'] ?? '').toString().trim();
        if (country.isNotEmpty && country.toLowerCase() != 'india') {
          addressLines.add(country);
        }

        return addressLines.join('\n');
      }

      final fullAddress = buildCompleteAddress(workspaceData);

      return {
        'companyName': workspaceData['companyName'] ??
            workspaceData['name'] ??
            workspaceData['entityName'] ??
            '',
        'companyAddress': fullAddress,
        'companyGst': workspaceData['gstin'] ??
            workspaceData['gstNo'] ??
            workspaceData['gst'] ??
            '',
        'companyPan': workspaceData['pan']?.toString() ?? '',
        'companyIec': workspaceData['iec']?.toString() ?? '',
        'companyPhone': workspaceData['phone'] ?? workspaceData['mobile'] ?? '',
        'companyEmail': workspaceData['email']?.toString() ?? '',
        'companyWebsite': workspaceData['website']?.toString() ?? '',
        'companyLogoUrl': workspaceData['logoUrl']?.toString() ?? '',
        'signatureName': sigName,
        'signatureDesignation': sigDesignation,
        'signaturePhone': sigPhone,
      };
    } catch (e) {
      return <String, dynamic>{};
    }
  }
}

// ==========================================
// 3. PREMIUM PDF GENERATOR (Layout Engine)
// ==========================================

class QuotationPdfGenerator {
  // --- Premium Enterprise Theming ---
  static final PdfColor _primaryColor = PdfColor.fromInt(0xFF1E3A8A); // Deep Corporate Blue
  static final PdfColor _textMain = PdfColor.fromInt(0xFF222222); // Darker Gray for readability
  static final PdfColor _textMuted = PdfColor.fromInt(0xFF555555); // Muted Gray
  static final PdfColor _borderColor = PdfColor.fromInt(0xFFCCCCCC); // Clean Light Gray Border
  static final PdfColor _tableHeaderColor = PdfColor.fromInt(0xFFF3F4F6); // Very Soft Gray

  // --- Helpers ---
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble().isNaN ? 0.0 : value.toDouble();
    if (value is String) {
      if (value.trim().isEmpty) return 0.0;
      final parsed = double.tryParse(value.replaceAll(',', ''));
      if (parsed != null && !parsed.isNaN) return parsed;
    }
    return 0.0;
  }

  static String _cleanPdfText(String value) {
    var text = value;
    text = text
        .replaceAll('Ø', '')
        .replaceAll('ø', '')
        .replaceAll('⌀', '')
        .replaceAll('⏀', '')
        .replaceAll('∅', '')
        .replaceAll('Φ', '')
        .replaceAll('φ', '')
        .replaceAll('', '')
        .replaceAll('□', '');
    text = text
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('•', '-')
        .replaceAll('₹', 'Rs.');
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    text = text.replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), '');
    return text.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(' .', '.').replaceAll(' ,', ',').trim();
  }

  static String _safeString(dynamic value) {
    if (value == null) return '';
    final str = value.toString().trim();
    return str == 'null' ? '' : str;
  }

  static String _currency(double value) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    return format.format(value);
  }

  static String _amountInWords(double amount) {
    if (amount == 0) return 'Zero Rupees Only';

    final int integerPart = amount.floor();
    final int fractionalPart = ((amount - integerPart) * 100).round();

    String result = '${_convertNumberToWords(integerPart)} Rupees';
    if (fractionalPart > 0) {
      result += ' and ${_convertNumberToWords(fractionalPart)} Paise';
    }
    return '$result Only';
  }

  static String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';

    const units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String words = '';

    if ((number / 10000000).floor() > 0) {
      words += '${_convertNumberToWords((number / 10000000).floor())} Crore ';
      number %= 10000000;
    }
    if ((number / 100000).floor() > 0) {
      words += '${_convertNumberToWords((number / 100000).floor())} Lakh ';
      number %= 100000;
    }
    if ((number / 1000).floor() > 0) {
      words += '${_convertNumberToWords((number / 1000).floor())} Thousand ';
      number %= 1000;
    }
    if ((number / 100).floor() > 0) {
      words += '${_convertNumberToWords((number / 100).floor())} Hundred ';
      number %= 100;
    }
    if (number > 0) {
      if (number < 20) {
        words += units[number];
      } else {
        words += tens[(number / 10).floor()];
        if ((number % 10) > 0) words += ' ${units[number % 10]}';
      }
    }
    return words.trim();
  }

  static bool _isSalesOrder(String type) {
    final t = type.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    return t == 'salesorder' || t == 'so';
  }

  static String _normalizeQuotationType(dynamic value) {
    final text = _safeString(value).toLowerCase();
    return text.contains('export') ? 'export' : 'domestic';
  }

  static double _settingsDouble(Map<String, dynamic> settings, String key, double fallback) {
    final val = _toDouble(settings[key]);
    return val == 0.0 ? fallback : val;
  }

  static bool _hasUsableTerms(Map<String, dynamic> quotation) {
    for (final key in ['terms', 'dynamicTerms', 'termsAndConditions']) {
      final rawTerms = quotation[key];
      if (rawTerms is List) {
        for (final item in rawTerms) {
          if (item is Map) {
            final title = _safeString(item['title'] ?? item['name'] ?? item['label']);
            final value = _safeString(item['value'] ?? item['detail'] ?? item['description'] ?? item['text']);
            if (title.isNotEmpty || value.isNotEmpty) return true;
          } else if (_safeString(item).isNotEmpty) {
            return true;
          }
        }
      } else if (_safeString(rawTerms).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> _loadQuotationSettingsForPdf(Map<String, dynamic> quotation) async {
    var companyId = _safeString(quotation['companyId']);

    if (companyId.isEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final rootData = userDoc.data() ?? <String, dynamic>{};
          companyId = _safeString(rootData['activeCompanyId'] ?? rootData['companyId']);
        }
      } catch (_) {}
    }

    if (companyId.isEmpty) return <String, dynamic>{};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('letterhead_settings')
          .get();

      var data = snap.data() ?? <String, dynamic>{};

      if (data.isEmpty) {
        final oldSnap = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('settings')
            .doc('quotation_settings')
            .get();
        data = oldSnap.data() ?? <String, dynamic>{};
      }

      final quotationType = _normalizeQuotationType(quotation['quotationType']);

      final merged = <String, dynamic>{
        'companyId': companyId,
        'quotationType': quotationType
      };

      final selected = data[quotationType];
      if (selected is Map) {
        merged.addAll(Map<String, dynamic>.from(selected));
      }

      data.forEach((key, value) {
        if (value != null && value is! Map) {
          merged[key] = value;
        }
      });

      if (_safeString(merged['letterheadUrl']).isEmpty && data['domestic'] is Map) {
        final d = Map<String, dynamic>.from(data['domestic']);
        if (_safeString(d['letterheadUrl']).isNotEmpty) {
          merged['letterheadUrl'] = d['letterheadUrl'];
        }
      }

      return merged;
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  static Future<pw.ImageProvider?> _loadSettingsLetterheadImage(Map<String, dynamic> settings) async {
    String valueFrom(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = _safeString(source[key]);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final url = valueFrom(settings, ['letterheadUrl', 'url', 'fileUrl', 'downloadUrl']);
    final savedType = valueFrom(settings, ['letterheadType', 'letterheadFileType', 'fileType', 'type']).toLowerCase();
    final lowerUrl = url.toLowerCase();

    String type = savedType;
    if (lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg')) type = 'jpg';
    else if (lowerUrl.contains('.png')) type = 'png';
    else if (lowerUrl.contains('.webp')) type = 'webp';
    else if (lowerUrl.contains('.pdf')) type = 'pdf';

    if (url.isEmpty || type == 'pdf') return null;

    try {
      final bytes = await FirebaseStorage.instance.refFromURL(url).getData(10 * 1024 * 1024);
      if (bytes != null && bytes.isNotEmpty) return pw.MemoryImage(bytes);
    } catch (e) {}

    try {
      final cacheBusterUrl = url.contains('?')
          ? '$url&t=${DateTime.now().millisecondsSinceEpoch}'
          : '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      return await networkImage(cacheBusterUrl);
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // PDF WIDGET BUILDERS
  // ==========================================

  static pw.Widget _buildPageBackground(
      pw.Context context, {
        required pw.ImageProvider? letterheadImage,
      }) {
    if (letterheadImage == null) return pw.SizedBox.shrink();

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Image(letterheadImage, fit: pw.BoxFit.cover),
    );
  }

  static pw.Widget _buildFallbackHeader(Map<String, dynamic> quotation, pw.ImageProvider? logoImage, String docTypeStr) {
    final companyName = _safeString(quotation['companyName']);
    final companyAddress = _safeString(quotation['companyAddress']);
    final gst = _safeString(quotation['companyGst']);
    final phone = _safeString(quotation['companyPhone']);
    final email = _safeString(quotation['companyEmail']);
    final website = _safeString(quotation['companyWebsite']);

    List<String> meta = [];
    if (gst.isNotEmpty) meta.add('GSTIN: $gst');
    if (phone.isNotEmpty) meta.add('Ph: $phone');
    if (email.isNotEmpty) meta.add('Email: $email');
    if (website.isNotEmpty) meta.add('Web: $website');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.5))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoImage != null)
            pw.Container(
              width: 50,
              height: 50,
              margin: const pw.EdgeInsets.only(right: 10),
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName.isNotEmpty ? companyName.toUpperCase() : 'COMPANY NAME',
                  style: pw.TextStyle(color: _textMain, fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 3),
                if (companyAddress.isNotEmpty)
                  pw.Text(companyAddress, style: pw.TextStyle(color: _textMuted, fontSize: 7.5)),
                if (meta.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(meta.join('  |  '), style: pw.TextStyle(color: _textMain, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDocumentTitle(String docTypeStr) {
    return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        alignment: pw.Alignment.center,
        child: pw.Column(
            children: [
              pw.Text(
                docTypeStr.toUpperCase(),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _primaryColor, letterSpacing: 2.0),
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 0.5, width: 80, color: _borderColor),
            ]
        )
    );
  }

  static pw.Widget _buildCustomerAndMetaInfo(Map<String, dynamic> quotation, String docNumber, String docDate, bool isSO, String inquiryRef, String inquiryDate) {
    final clientName = _safeString(quotation['clientName'] ?? quotation['customerName'] ?? quotation['companyName']);
    final clientAddress = _cleanPdfText(_safeString(quotation['clientAddress'] ?? quotation['addressLine'] ?? quotation['address']));
    final customerState = _safeString(quotation['customerState'] ?? quotation['state']);
    final gstNo = _safeString(quotation['gstNo'] ?? quotation['customerGstin']);
    final contactPerson = _safeString(quotation['contactPerson']);
    final clientMobile = _safeString(quotation['clientMobile'] ?? quotation['mobile'] ?? quotation['contactMobile']);
    final clientEmail = _safeString(quotation['clientEmail'] ?? quotation['email'] ?? quotation['contactEmail']);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // LEFT: Customer Info (Clean, No borders)
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(isSO ? 'CUSTOMER DETAILS' : 'QUOTATION TO', style: pw.TextStyle(fontSize: 8, color: _primaryColor, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
                pw.SizedBox(height: 4),
                if (clientName.isNotEmpty)
                  pw.Text(clientName, style: pw.TextStyle(fontSize: 9.5, color: _textMain, fontWeight: pw.FontWeight.bold)),
                if (clientAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(clientAddress, style: pw.TextStyle(fontSize: 7.5, color: _textMuted, lineSpacing: 1.2)),
                ],
                if (customerState.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('State: $customerState', style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
                ],
                if (gstNo.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('GSTIN: $gstNo', style: pw.TextStyle(fontSize: 7.5, color: _textMain, fontWeight: pw.FontWeight.bold)),
                ],
                pw.SizedBox(height: 4),
                if (contactPerson.isNotEmpty || clientMobile.isNotEmpty || clientEmail.isNotEmpty)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (contactPerson.isNotEmpty) pw.Text('Attn: $contactPerson', style: pw.TextStyle(fontSize: 7.5, color: _textMain, fontWeight: pw.FontWeight.bold)),
                      if (clientMobile.isNotEmpty) pw.Text('Ph: $clientMobile', style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
                      if (clientEmail.isNotEmpty) pw.Text('Email: $clientEmail', style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
                    ],
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          // RIGHT: Document Info (Clean, No borders)
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DOCUMENT DETAILS', style: pw.TextStyle(fontSize: 8, color: _primaryColor, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
                pw.SizedBox(height: 4),
                _buildMetaRow(isSO ? 'Sales Order No.' : 'Quotation No.', docNumber),
                if (docDate.isNotEmpty) _buildMetaRow('Date', docDate),
                if (inquiryRef.isNotEmpty) _buildMetaRow('Inquiry No.', inquiryRef),
                if (inquiryDate.isNotEmpty) _buildMetaRow('Inquiry Date', inquiryDate),
                if (isSO && _safeString(quotation['poNumber']).isNotEmpty) ...[
                  _buildMetaRow('PO Number', _safeString(quotation['poNumber'])),
                  if (quotation['poDate'] != null)
                    _buildMetaRow('PO Date', DateFormat('dd/MM/yyyy').format((quotation['poDate'] as Timestamp).toDate())),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaRow(String label, String value) {
    if (value.trim().isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
          pw.Text(value, style: pw.TextStyle(fontSize: 7.5, color: _textMain, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(String text, {pw.Alignment align = pw.Alignment.center}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: align,
      child: pw.Text(
          text,
          textAlign: align == pw.Alignment.centerLeft ? pw.TextAlign.left : (align == pw.Alignment.centerRight ? pw.TextAlign.right : pw.TextAlign.center),
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMain)
      ),
    );
  }

  static pw.Widget _tableCell(String text, {pw.Alignment align = pw.Alignment.centerLeft, bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: align,
      child: pw.Text(
        text,
        textAlign: align == pw.Alignment.centerRight ? pw.TextAlign.right : (align == pw.Alignment.center ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(fontSize: 7.5, color: _textMain, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<QuotationLineItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FixedColumnWidth(55),
        5: const pw.FixedColumnWidth(60),
      },
      children: [
        // Table Header
        pw.TableRow(
            repeat: true,
            decoration: pw.BoxDecoration(color: _tableHeaderColor),
            children: [
              _tableHeaderCell('Sr. No.'),
              _tableHeaderCell('Product Details', align: pw.Alignment.centerLeft),
              _tableHeaderCell('HSN Code'),
              _tableHeaderCell('Qty'),
              _tableHeaderCell('Rate', align: pw.Alignment.centerRight),
              _tableHeaderCell('Amount', align: pw.Alignment.centerRight),
            ]
        ),
        // Table Rows
        ...items.asMap().entries.map((entry) {
          final int i = entry.key;
          final QuotationLineItem item = entry.value;

          String qtyStr = item.quantity == item.quantity.truncateToDouble() ? item.quantity.toInt().toString() : item.quantity.toString();
          String combinedQty = '$qtyStr ${item.uom}'.trim();

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.top,
            children: [
              _tableCell('${i + 1}', align: pw.Alignment.center),
              pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _textMain)),
                        if (item.itemCode.isNotEmpty)
                          pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 1, bottom: 1),
                              child: pw.Text('(${item.itemCode})', style: pw.TextStyle(fontSize: 7.5, color: _textMuted))
                          ),
                        if (item.description.trim().isNotEmpty)
                          pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 1, bottom: 1),
                              child: pw.Text(_cleanPdfText(item.description), style: pw.TextStyle(fontSize: 7.5, color: _textMuted, lineSpacing: 1.1))
                          ),
                        if (item.scopeOfSupply.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text('Scope of Supply:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _textMain)),
                          pw.SizedBox(height: 1),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 2),
                            child: pw.Text(_cleanPdfText(item.scopeOfSupply), style: pw.TextStyle(fontSize: 7.5, color: _textMuted, lineSpacing: 1.2)),
                          ),
                        ]
                      ]
                  )
              ),
              _tableCell(item.hsnCode, align: pw.Alignment.center),
              _tableCell(combinedQty, align: pw.Alignment.center),
              _tableCell(_currency(item.unitPrice), align: pw.Alignment.centerRight),
              // FIX: Display subtotal (Quantity * Unit Price) instead of totalAmount (which included tax)
              _tableCell(_currency(item.subtotal), align: pw.Alignment.centerRight, bold: true),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildFinancialSummary(Map<String, dynamic> quotation, bool isInterState, double roundOff) {
    final subtotal = _toDouble(quotation['totalSubtotal']);
    final itemDiscount = _toDouble(quotation['totalItemDiscount']);
    final globalDiscount = _toDouble(quotation['globalDiscountAmount']);
    final taxableValue = _toDouble(quotation['totalTaxableAmount']);
    final cgst = _toDouble(quotation['totalCgst']);
    final sgst = _toDouble(quotation['totalSgst']);
    final igst = _toDouble(quotation['totalIgst']);
    final finalTotal = _toDouble(quotation['finalTotal'] ?? quotation['grandTotal']);

    pw.Widget totalRow(String label, String value, {bool bold = false, bool isGrand = false, bool topBorder = false}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        decoration: topBorder ? pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.5))) : null,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: isGrand ? 9.5 : 7.5, color: isGrand ? _primaryColor : _textMuted, fontWeight: bold || isGrand ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value, style: pw.TextStyle(fontSize: isGrand ? 9.5 : 7.5, color: isGrand ? _primaryColor : _textMain, fontWeight: bold || isGrand ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Amount in Words
        pw.Expanded(
          flex: 6,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, right: 20),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Amount in Words', style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
                  pw.SizedBox(height: 2),
                  pw.Text(_amountInWords(finalTotal), style: pw.TextStyle(fontSize: 8.5, color: _textMain)),
                ]
            ),
          ),
        ),
        // Totals Calculation (Clean, No outer box borders)
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Column(
              children: [
                totalRow('Subtotal', _currency(subtotal)),
                if (itemDiscount > 0 || globalDiscount > 0) totalRow('Discount', '-${_currency(itemDiscount + globalDiscount)}'),
                totalRow('Taxable Amount', _currency(taxableValue), bold: true, topBorder: true),
                if (!isInterState) ...[
                  totalRow('CGST', _currency(cgst)),
                  totalRow('SGST', _currency(sgst)),
                ] else ...[
                  totalRow('IGST', _currency(igst)),
                ],
                if (roundOff != 0) totalRow('Round Off', _currency(roundOff)),
                totalRow('Grand Total', _currency(finalTotal), isGrand: true, topBorder: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTerms(Map<String, dynamic> quotation) {
    final terms = quotation['dynamicTerms'] ?? quotation['terms'];

    if (terms is! List || terms.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('TERMS & CONDITIONS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _primaryColor, letterSpacing: 0.5)),
          pw.SizedBox(height: 4),
          pw.Text('Standard commercial terms and conditions apply.', style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
        ],
      );
    }

    List<pw.Widget> termWidgets = [];
    for (final term in terms) {
      if (term == null || term['value'] == null || _safeString(term['value']).isEmpty) continue;
      final title = _safeString(term['title']);
      final value = _cleanPdfText(_safeString(term['value']));

      termWidgets.add(
        pw.Container(
          width: 260,
          padding: const pw.EdgeInsets.only(bottom: 2, right: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                pw.Container(
                  width: 60,
                  child: pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _textMain)),
                ),
              if (title.isNotEmpty)
                pw.Container(
                  width: 10,
                  child: pw.Text(':', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _textMain)),
                ),
              pw.Expanded(
                child: pw.Text(value, style: pw.TextStyle(fontSize: 7.5, color: _textMuted, lineSpacing: 1.2)),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('TERMS & CONDITIONS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _primaryColor, letterSpacing: 0.5)),
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 10,
          runSpacing: 2,
          children: termWidgets,
        ),
      ],
    );
  }

  static pw.Widget _buildSignature(Map<String, dynamic> quotation) {
    final companyName = _safeString(quotation['companyName']);
    final sigName = _safeString(quotation['signatureName']);
    final sigDesignation = _safeString(quotation['signatureDesignation']);
    final sigPhone = _safeString(quotation['signaturePhone']);

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (companyName.isNotEmpty)
            pw.Text('For $companyName', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _textMain)),
          pw.SizedBox(height: 30),
          if (sigName.isNotEmpty)
            pw.Text(sigName, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _textMain)),
          if (sigDesignation.isNotEmpty)
            pw.Text(sigDesignation, style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
          if (sigPhone.isNotEmpty)
            pw.Text(sigPhone, style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
        ],
      ),
    );
  }

  // ==========================================
  // MAIN PDF BUILDER
  // ==========================================

  static Future<Uint8List> buildPdf(
      PdfPageFormat format,
      Map<String, dynamic> quotation,
      List<QuotationLineItem> items,
      ) async {
    final quotationSettings = await _loadQuotationSettingsForPdf(quotation);

    // Fallback margins from settings (or safe defaults)
    double headerHeight = _settingsDouble(quotationSettings, 'headerHeight', 120);
    double footerHeight = _settingsDouble(quotationSettings, 'footerHeight', 80);
    double leftMargin = _settingsDouble(quotationSettings, 'leftMargin', 40);
    double rightMargin = _settingsDouble(quotationSettings, 'rightMargin', 40);

    final settingsLetterheadImage = await _loadSettingsLetterheadImage(quotationSettings);

    final doc = pw.Document();

    pw.ImageProvider? logoImage;
    final logoUrl = _safeString(quotation['companyLogoUrl']);
    if (logoUrl.isNotEmpty) {
      try {
        logoImage = await networkImage(logoUrl);
      } catch (_) {}
    }

    final isInterState = quotation['isInterState'] as bool? ?? false;
    final roundOff = _toDouble(quotation['roundOff']);

    final documentType = _safeString(quotation['documentType']);
    final isSO = _isSalesOrder(documentType);
    final displayDocumentType = documentType.isNotEmpty ? documentType : 'Quotation';

    String docNumber = isSO ? _safeString(quotation['salesOrderNumberDisplay'] ?? quotation['salesOrderNumber'] ?? quotation['poNumber'] ?? quotation['quoteNumber'])
        : _safeString(quotation['quoteNumber'] ?? quotation['quotationNumber']);

    if (docNumber.isEmpty) docNumber = 'DRAFT';

    String docDateStr = '';
    dynamic dateVal = isSO ? (quotation['soDate'] ?? quotation['date'] ?? quotation['createdAt']) : quotation['quoteDate'];
    if (dateVal != null) {
      try {
        if (dateVal is Timestamp) {
          docDateStr = DateFormat('dd/MM/yyyy').format(dateVal.toDate());
        } else if (dateVal is String) {
          docDateStr = dateVal.contains('/') ? dateVal : DateFormat('dd/MM/yyyy').format(DateTime.parse(dateVal));
        }
      } catch (e) {
        docDateStr = dateVal.toString();
      }
    }
    if (docDateStr.isEmpty) docDateStr = _safeString(quotation['quoteDateStr']);

    String inquiryRefStr = _safeString(quotation['inquiryRefNo'] ?? quotation['inquiryNumber']);
    String inquiryDateStr = '';
    dynamic inqDateVal = quotation['inquiryDate'];
    if (inqDateVal != null) {
      try {
        if (inqDateVal is Timestamp) {
          inquiryDateStr = DateFormat('dd/MM/yyyy').format(inqDateVal.toDate());
        } else if (inqDateVal is String) {
          inquiryDateStr = inqDateVal.contains('/') ? inqDateVal : DateFormat('dd/MM/yyyy').format(DateTime.parse(inqDateVal));
        }
      } catch (e) {
        inquiryDateStr = inqDateVal.toString();
      }
    }

    // Map terms properly
    final settingsTerms = quotationSettings['terms'];
    if (!_hasUsableTerms(quotation) && settingsTerms is List && settingsTerms.isNotEmpty) {
      quotation['terms'] = settingsTerms;
      quotation['dynamicTerms'] = settingsTerms;
    }

    // Identify Scope of Supply items generated by the UI parsing logic
    // and seamlessly merge them into their parent's scopeOfSupply string.
    List<QuotationLineItem> mergedItems = [];
    List<QuotationLineItem> clonedItems = items.map((e) => QuotationLineItem.fromMap(e.toMap())).toList();

    // Add all parent items first
    for (var item in clonedItems) {
      if (!item.isScopeItem || item.parentId == null) {
        mergedItems.add(item);
      }
    }

    // Merge children into their parents
    for (var item in clonedItems) {
      if (item.isScopeItem && item.parentId != null) {
        int parentIdx = mergedItems.indexWhere((i) => i.id == item.parentId);
        if (parentIdx != -1) {
          var parent = mergedItems[parentIdx];

          // Format quantity properly without .0 for integers
          String qtyStr = item.quantity == item.quantity.truncateToDouble() ? item.quantity.toInt().toString() : item.quantity.toString();
          String bullet = '• ${item.name} - $qtyStr ${item.uom}';

          // Prevent duplication of the same scope item
          if (!parent.scopeOfSupply.contains(item.name)) {
            if (parent.scopeOfSupply.isEmpty) {
              parent.scopeOfSupply = bullet;
            } else {
              parent.scopeOfSupply += '\n$bullet';
            }
          }

          // FIX: Do NOT merge scope item price into parent unit price.
          // Doing so recalculates the Rate and introduces tax multiplier bugs in the UI.
          // Scope items are effectively treated as bundled/inclusive.
          //
          // if (item.unitPrice > 0) {
          //   parent.unitPrice += (item.unitPrice * item.quantity) / (parent.quantity > 0 ? parent.quantity : 1);
          // }
        }
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format.copyWith(
            marginLeft: leftMargin,
            marginRight: rightMargin,
            marginTop: settingsLetterheadImage != null ? headerHeight : 30,
            marginBottom: settingsLetterheadImage != null ? footerHeight : 30,
          ),
          buildBackground: (context) => _buildPageBackground(
            context,
            letterheadImage: settingsLetterheadImage,
          ),
        ),
        header: (context) {
          return pw.SizedBox.shrink();
        },
        footer: (context) {
          if (settingsLetterheadImage != null) {
            return pw.SizedBox.shrink();
          }
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: _textMuted),
            ),
          );
        },
        build: (context) {
          return [
            if (settingsLetterheadImage == null) _buildFallbackHeader(quotation, logoImage, displayDocumentType),
            if (settingsLetterheadImage != null) _buildDocumentTitle(displayDocumentType),

            _buildCustomerAndMetaInfo(quotation, docNumber, docDateStr, isSO, inquiryRefStr, inquiryDateStr),
            _buildItemsTable(mergedItems),
            pw.SizedBox(height: 10),
            _buildFinancialSummary(quotation, isInterState, roundOff),
            pw.SizedBox(height: 20),

            // Keeps Terms and Signature safely grouped together on the same page
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildTerms(quotation),
                  pw.SizedBox(height: 20),
                  _buildSignature(quotation),
                ]
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}

// ==========================================
// 4. PREVIEW UI WIDGET
// ==========================================

class QuotationPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> quotation;
  final List<QuotationLineItem> items;
  final String? titleOverride;

  const QuotationPreviewScreen({
    super.key,
    required this.quotation,
    required this.items,
    this.titleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final String documentType = QuotationPdfGenerator._safeString(quotation['documentType']);
    final String displayDocumentType = documentType.isNotEmpty ? documentType : 'Quotation';
    final bool isSO = QuotationPdfGenerator._isSalesOrder(displayDocumentType);

    String docNumber = '';
    if (isSO) {
      docNumber = QuotationPdfGenerator._safeString(quotation['salesOrderNumberDisplay']);
      if (docNumber.isEmpty) docNumber = QuotationPdfGenerator._safeString(quotation['salesOrderNumber']);
      if (docNumber.isEmpty) docNumber = QuotationPdfGenerator._safeString(quotation['soNumber']);
      if (docNumber.isEmpty) docNumber = QuotationPdfGenerator._safeString(quotation['orderNumber']);
    }
    if (docNumber.isEmpty) {
      docNumber = QuotationPdfGenerator._safeString(quotation['quoteNumber']);
      if (docNumber.isEmpty) docNumber = QuotationPdfGenerator._safeString(quotation['quotationNumber']);
    }
    if (docNumber.isEmpty) docNumber = 'N/A';

    const headerBgColor = Color(0xFFE5E7EB);
    const headerBorderColor = Color(0xFFD1D5DB);
    const headerTextColor = Color(0xFF2B2B2B);
    const viewerBgColor = Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: viewerBgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            color: headerBgColor,
            border: Border(bottom: BorderSide(color: headerBorderColor, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      displayDocumentType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: headerTextColor,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back, color: headerTextColor),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final previewWidth = constraints.maxWidth >= 1500 ? 780.0 :
          constraints.maxWidth >= 1300 ? 720.0 :
          constraints.maxWidth >= 1100 ? 660.0 :
          constraints.maxWidth >= 900 ? 600.0 :
          constraints.maxWidth - 32;

          return Container(
            color: viewerBgColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Theme(
              data: Theme.of(context).copyWith(
                scaffoldBackgroundColor: viewerBgColor,
                primaryColor: headerBgColor,
                appBarTheme: const AppBarTheme(
                  backgroundColor: headerBgColor,
                  foregroundColor: headerTextColor,
                  elevation: 0,
                  centerTitle: true,
                  iconTheme: IconThemeData(color: headerTextColor),
                  actionsIconTheme: IconThemeData(color: headerTextColor),
                  titleTextStyle: TextStyle(color: headerTextColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                iconTheme: const IconThemeData(color: headerTextColor),
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: headerTextColor,
                  surface: headerBgColor,
                  onSurface: headerTextColor,
                ),
              ),
              child: PdfPreview(
                build: (format) => QuotationPdfGenerator.buildPdf(format, quotation, items),
                initialPageFormat: PdfPageFormat.a4,
                canChangeOrientation: false,
                canChangePageFormat: false,
                allowPrinting: true,
                allowSharing: true,
                pdfFileName: '${displayDocumentType}_$docNumber.pdf'.replaceAll(' ', '_'),
                scrollViewDecoration: const BoxDecoration(color: viewerBgColor),
                maxPageWidth: previewWidth,
              ),
            ),
          );
        },
      ),
    );
  }
}