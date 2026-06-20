import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. MODELS (SINGLE SOURCE OF TRUTH)
// ==========================================

class QuotationLineItem {
  String id;
  String productId;
  String name;
  String description;
  String hsnCode;
  double quantity;
  String uom;
  double unitPrice;
  double discountPercent;
  double cgstPercent;
  double sgstPercent;
  double igstPercent;
  double availableStock;

  QuotationLineItem({
    required this.id,
    required this.productId,
    required this.name,
    this.description = '',
    this.hsnCode = '',
    this.quantity = 1,
    this.uom = 'Nos',
    this.unitPrice = 0.0,
    this.discountPercent = 0.0,
    this.cgstPercent = 0.0,
    this.sgstPercent = 0.0,
    this.igstPercent = 0.0,
    this.availableStock = 0.0,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'description': description,
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
    };
  }

  factory QuotationLineItem.fromMap(Map<String, dynamic> map) {
    return QuotationLineItem(
      id: _safeString(map['id']),
      productId: _safeString(map['productId']),
      name: _safeString(map['name']),
      description: _safeString(map['description']),
      hsnCode: _safeString(map['hsnCode']),
      quantity: _toDouble(
        map['quantity'] != null && map['quantity'].toString().isNotEmpty
            ? map['quantity']
            : 1,
      ),
      uom: _safeString(map['uom']).isEmpty ? 'Nos' : _safeString(map['uom']),
      unitPrice: _toDouble(map['unitPrice']),
      discountPercent: _toDouble(map['discountPercent']),
      cgstPercent: _toDouble(map['cgstPercent']),
      sgstPercent: _toDouble(map['sgstPercent']),
      igstPercent: _toDouble(map['igstPercent']),
      availableStock: _toDouble(map['availableStock']),
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

      final sigName =
          (compUserData['name'] ??
                  compUserData['fullName'] ??
                  membershipData?['name'] ??
                  rootData['name'] ??
                  rootData['fullName'] ??
                  authName)
              .toString()
              .trim();

      String sigDesignation =
          (compUserData['designation'] ??
                  membershipData?['designation'] ??
                  rootData['designation'] ??
                  '')
              .toString()
              .trim();

      String userDepartment =
          (compUserData['department'] ??
                  membershipData?['department'] ??
                  rootData['department'] ??
                  '')
              .toString()
              .trim();

      String userRole = (membershipData?['role'] ?? rootData['role'] ?? 'Sales')
          .toString()
          .trim();

      if (sigDesignation.isEmpty) {
        sigDesignation = userDepartment.isNotEmpty
            ? userDepartment
            : userRole.toUpperCase();
      }

      final sigPhone =
          (compUserData['phone'] ??
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
        'companyName':
            workspaceData['companyName'] ??
            workspaceData['name'] ??
            workspaceData['entityName'] ??
            '',
        'companyAddress': fullAddress,
        'companyGst':
            workspaceData['gstin'] ??
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

  static String _cleanPdfText(String value) {
    return value
        .replaceAll('☒', '-')
        .replaceAll('☑', '-')
        .replaceAll('✅', '-')
        .replaceAll('✔', '-')
        .replaceAll('✓', '-')
        .replaceAll('■', '-')
        .replaceAll('▪', '-')
        .replaceAll('●', '-')
        .replaceAll('◦', '-')
        .replaceAll('•', '-')
        .replaceAll('\r\n', '\n');
  }

  static String _safeString(dynamic value) {
    if (value == null) return '';
    final str = value.toString().trim();
    return str == 'null' ? '' : str;
  }

  static String _currency(double value) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 2,
    );
    return format.format(value);
  }

  static bool _isSalesOrder(String type) {
    final t = type.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    return t == 'salesorder' || t == 'so';
  }

  // Premium Corporate Gold Theme
  static final PdfColor _primaryColor = PdfColor.fromInt(
    0xFF111111,
  ); // Charcoal black
  static final PdfColor _accentColor = PdfColor.fromInt(0xFFE31E24); // Gold
  static final PdfColor _bgColor = PdfColor.fromInt(
    0xFFFFFFFF,
  ); // Very light grey
  static final PdfColor _cardBgColor = PdfColor.fromInt(0xFFFFFFFF);
  static final PdfColor _borderColor = PdfColor.fromInt(
    0xFFD7DCE2,
  ); // Light grey border
  static final PdfColor _textMain = PdfColor.fromInt(
    0xFF111827,
  ); // Charcoal black
  static final PdfColor _textMuted = PdfColor.fromInt(0xFF5F6673); // Muted grey
  static final PdfColor _zebraColor = PdfColor.fromInt(
    0xFFFAFAFA,
  ); // Very subtle grey

  static pw.Widget _buildCard({required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _cardBgColor,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: child,
    );
  }

  static Future<Uint8List> buildPdf(
    PdfPageFormat format,
    Map<String, dynamic> quotation,
    List<QuotationLineItem> items,
  ) async {
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
    final displayDocumentType = documentType.isNotEmpty
        ? documentType
        : 'Quotation';

    // Determine Document Numbers securely
    String soNumber = _safeString(quotation['salesOrderNumberDisplay']);
    if (soNumber.isEmpty) soNumber = _safeString(quotation['salesOrderNumber']);
    if (soNumber.isEmpty) soNumber = _safeString(quotation['soNumber']);
    if (soNumber.isEmpty) soNumber = _safeString(quotation['orderNumber']);

    String quoteNumber = _safeString(quotation['quoteNumber']);
    if (quoteNumber.isEmpty) {
      quoteNumber = _safeString(quotation['quotationNumber']);
    }

    // Determine the correct date
    String docDateStr = '';
    dynamic dateVal;
    if (isSO) {
      dateVal =
          quotation['soDate'] ?? quotation['date'] ?? quotation['createdAt'];
    }

    dateVal ??= quotation['quoteDate'];

    if (dateVal != null) {
      try {
        if (dateVal is Timestamp) {
          docDateStr = DateFormat('dd/MM/yyyy').format(dateVal.toDate());
        } else if (dateVal is String && dateVal.isNotEmpty) {
          if (dateVal.contains('/')) {
            docDateStr = dateVal;
          } else {
            docDateStr = DateFormat(
              'dd/MM/yyyy',
            ).format(DateTime.parse(dateVal));
          }
        }
      } catch (e) {
        docDateStr = dateVal.toString();
      }
    }

    if (docDateStr.isEmpty) {
      docDateStr = _safeString(quotation['quoteDateStr']);
    }

    // For Preview Check logic
    final checkNum = isSO && soNumber.isNotEmpty ? soNumber : quoteNumber;
    final isPreview =
        checkNum.toUpperCase().contains('PREVIEW') ||
        checkNum.toUpperCase().contains('AUTO-GENERATED');

    String subjectStr = _safeString(quotation['subject']);
    if (subjectStr.isEmpty) {
      subjectStr = isSO
          ? 'Sales Order for supplied items'
          : 'Quotation for your requirement';
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              color: _bgColor,
              child: pw.Center(
                child: logoImage != null
                    ? pw.Opacity(
                        opacity: 0.045,
                        child: pw.Image(
                          logoImage,
                          width: 260,
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    : pw.Text(
                        'memco',
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFFFAEEEE),
                          fontSize: 54.6,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
              ),
            ),
          ),
        ),
        build: (context) {
          return [
            _buildEnterpriseHeader(
              quotation,
              logoImage,
              isPreview,
              displayDocumentType,
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              height: 1.5,
              width: double.infinity,
              color: _accentColor,
            ),
            pw.SizedBox(height: 18),
            _buildTwoColumnInfo(
              quotation,
              soNumber,
              quoteNumber,
              docDateStr,
              isSO,
            ),
            pw.SizedBox(height: 20),

            _buildSubjectBar(subjectStr),
            pw.SizedBox(height: 20),

            _buildProductsTable(items, isInterState),
            pw.SizedBox(height: 18),
            _buildBottomSection(quotation, isInterState, roundOff),
          ];
        },
        footer: (context) => _buildPageFooter(context, isSO),
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildEnterpriseHeader(
    Map<String, dynamic> quotation,
    pw.ImageProvider? logoImage,
    bool isPreview,
    String displayDocumentType,
  ) {
    List<String> legalIds = [];
    final gst = _safeString(quotation['companyGst']);
    final pan = _safeString(quotation['companyPan']);
    final iec = _safeString(quotation['companyIec']);

    if (gst.isNotEmpty) legalIds.add('GSTIN: $gst');
    if (pan.isNotEmpty) legalIds.add('PAN: $pan');
    if (iec.isNotEmpty) legalIds.add('IEC: $iec');

    List<String> contacts = [];
    final phone = _safeString(quotation['companyPhone']);
    final email = _safeString(quotation['companyEmail']);
    final website = _safeString(quotation['companyWebsite']);

    if (phone.isNotEmpty) contacts.add('Ph: $phone');
    if (email.isNotEmpty) contacts.add('Email: $email');
    if (website.isNotEmpty) contacts.add('Web: $website');

    final companyName = _safeString(quotation['companyName']);
    final companyAddress = _safeString(quotation['companyAddress']);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borderColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 20,
            decoration: pw.BoxDecoration(
              color: _accentColor,
              borderRadius: const pw.BorderRadius.vertical(
                top: pw.Radius.circular(8),
              ),
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 14),
                child: pw.Text(
                  'synonymous with welding',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null) ...[
                  pw.Container(
                    height: 54,
                    width: 58,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: _borderColor),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 24),
                ],
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.isNotEmpty
                            ? companyName.toUpperCase()
                            : 'MIRAJ ELECTRICAL AND MECHANICAL COMPANY PRIVATE LIMITED',
                        style: pw.TextStyle(
                          color: _primaryColor,
                          fontSize: 14.1,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.35,
                          lineSpacing: 1.1,
                        ),
                      ),
                      pw.SizedBox(height: 7),
                      if (companyAddress.isNotEmpty)
                        pw.Text(
                          companyAddress,
                          style: pw.TextStyle(
                            fontSize: 7.7,
                            color: _textMuted,
                            lineSpacing: 1.35,
                          ),
                        ),
                      if (legalIds.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          legalIds.join('  |  '),
                          style: pw.TextStyle(
                            fontSize: 7.7,
                            color: _textMain,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                      if (contacts.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          contacts.join('  |  '),
                          style: pw.TextStyle(fontSize: 7.7, color: _textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Container(
                  width: 132,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _primaryColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (isPreview) ...[
                        pw.Text(
                          'PREVIEW',
                          style: pw.TextStyle(
                            color: _accentColor,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                      ],
                      pw.Text(
                        displayDocumentType.toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14.1,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'MEMCO ERP DOCUMENT',
                        style: pw.TextStyle(
                          color: _accentColor,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTwoColumnInfo(
    Map<String, dynamic> quotation,
    String soNumber,
    String quoteNumber,
    String docDateStr,
    bool isSO,
  ) {
    final clientName = _safeString(
      quotation['clientName'] ??
          quotation['customerName'] ??
          quotation['partyName'] ??
          quotation['companyName'],
    );

    final clientAddress = _cleanPdfText(
      _safeString(
        quotation['clientAddress'] ??
            quotation['customerAddress'] ??
            quotation['billingAddress'] ??
            quotation['address'],
      ),
    );

    final customerState = _safeString(
      quotation['customerState'] ??
          quotation['state'] ??
          quotation['placeOfSupply'],
    );

    final gstNo = _safeString(
      quotation['gstNo'] ?? quotation['gstin'] ?? quotation['customerGstin'],
    );

    final contactPerson = _safeString(
      quotation['contactPerson'] ??
          quotation['contactPersonName'] ??
          quotation['customerContactPerson'],
    );

    final clientMobile = _safeString(
      quotation['clientMobile'] ??
          quotation['mobile'] ??
          quotation['phone'] ??
          quotation['contactNumber'],
    );

    final inquiryRef = _safeString(
      quotation['inquiryRefNo'] ??
          quotation['inquiryRef'] ??
          quotation['referenceNo'],
    );

    final revision = _safeString(quotation['revisionNo']);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: _buildCard(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isSO ? 'CUSTOMER DETAILS' : 'QUOTATION TO',
                  style: pw.TextStyle(
                    fontSize: 8.8,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                    letterSpacing: 0.4,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (clientName.isNotEmpty)
                  pw.Text(
                    clientName,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _textMain,
                    ),
                  ),
                if (clientAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    clientAddress,
                    style: pw.TextStyle(
                      fontSize: 8.2,
                      color: _textMuted,
                      lineSpacing: 1.15,
                    ),
                  ),
                ],
                if (customerState.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'State: $customerState',
                    style: pw.TextStyle(fontSize: 8.2, color: _textMuted),
                  ),
                ],
                if (gstNo.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'GSTIN: $gstNo',
                    style: pw.TextStyle(
                      fontSize: 8.2,
                      color: _textMain,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
                if (contactPerson.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Kind Attn: $contactPerson',
                    style: pw.TextStyle(fontSize: 8.2, color: _textMuted),
                  ),
                ],
                if (clientMobile.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Mobile: $clientMobile',
                    style: pw.TextStyle(fontSize: 8.2, color: _textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          flex: 4,
          child: _buildCard(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DOCUMENT DETAILS',
                  style: pw.TextStyle(
                    fontSize: 8.8,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                    letterSpacing: 0.4,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (isSO && soNumber.isNotEmpty)
                  _buildMetaRow('Sales Order No.', soNumber),
                if (quoteNumber.isNotEmpty)
                  _buildMetaRow('Quotation No.', quoteNumber),
                _buildMetaRow('Date', docDateStr),
                if (revision.isNotEmpty && revision != '1')
                  _buildMetaRow('Revision No.', revision),
                if (inquiryRef.isNotEmpty)
                  _buildMetaRow('Inquiry Ref.', inquiryRef),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaRow(String label, String value) {
    if (value.trim().isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.8, color: _textMuted)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.8,
              fontWeight: pw.FontWeight.bold,
              color: _textMain,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSubjectBar(String subject) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Subject: ',
              style: pw.TextStyle(
                fontSize: 9.2,
                fontWeight: pw.FontWeight.bold,
                color: _textMuted,
              ),
            ),
            pw.TextSpan(
              text: subject,
              style: pw.TextStyle(
                fontSize: 9.2,
                fontWeight: pw.FontWeight.bold,
                color: _textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildProductsTable(
    List<QuotationLineItem> items,
    bool isInterState,
  ) {
    if (items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(32),
        decoration: pw.BoxDecoration(
          color: _cardBgColor,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: _borderColor),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'No items added',
          style: pw.TextStyle(
            fontSize: 10.6,
            color: _textMuted,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _cardBgColor,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(32),
          1: const pw.FlexColumnWidth(6.2),
          2: const pw.FixedColumnWidth(52),
          3: const pw.FixedColumnWidth(42),
          4: const pw.FixedColumnWidth(62),
          5: const pw.FixedColumnWidth(56),
          6: const pw.FixedColumnWidth(68),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: _primaryColor,
              borderRadius: const pw.BorderRadius.vertical(
                top: pw.Radius.circular(9),
              ),
            ),
            children:
                [
                  'No.',
                  'Description',
                  'HSN',
                  'Qty',
                  'Rate',
                  'Tax',
                  'Amount',
                ].map((text) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 5,
                    ),
                    alignment:
                        (text == 'No.' ||
                            text == 'Qty' ||
                            text == 'HSN' ||
                            text == 'Tax')
                        ? pw.Alignment.center
                        : (text == 'Description'
                              ? pw.Alignment.centerLeft
                              : pw.Alignment.centerRight),
                    child: pw.Text(
                      text,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 7.7,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.25,
                      ),
                    ),
                  );
                }).toList(),
          ),

          ...List.generate(items.length, (i) {
            final item = items[i];
            final totalTaxPercent = isInterState
                ? item.igstPercent
                : (item.cgstPercent + item.sgstPercent);
            final taxLabel = isInterState ? 'IGST' : 'GST';
            final taxStr =
                '$taxLabel $totalTaxPercent%\n${_currency(item.taxAmount)}';

            List<pw.Widget> descWidgets = [
              pw.Text(
                item.name,
                style: pw.TextStyle(
                  fontSize: 8.1,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ];
            final cleanedDescription = _cleanPdfText(item.description);
            if (cleanedDescription.trim().isNotEmpty) {
              descWidgets.add(pw.SizedBox(height: 6));
              final lines = cleanedDescription.split('\n');
              for (var line in lines) {
                if (line.trim().isNotEmpty) {
                  descWidgets.add(
                    pw.Text(
                      line.trim(),
                      style: pw.TextStyle(
                        fontSize: 7.2,
                        color: _textMuted,
                        lineSpacing: 1.15,
                      ),
                    ),
                  );
                }
              }
            }
            if (item.discountPercent > 0) {
              descWidgets.add(pw.SizedBox(height: 6));
              descWidgets.add(
                pw.Text(
                  'Discount: ${item.discountPercent}% applied',
                  style: pw.TextStyle(
                    fontSize: 7.9,
                    fontStyle: pw.FontStyle.italic,
                    color: _accentColor,
                  ),
                ),
              );
            }

            pw.Widget cell(
              pw.Widget child, {
              pw.Alignment align = pw.Alignment.centerRight,
            }) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 5,
                ),
                alignment: align,
                child: child,
              );
            }

            pw.Widget textCell(
              String text, {
              pw.Alignment align = pw.Alignment.centerRight,
              bool bold = false,
            }) {
              return cell(
                pw.Text(
                  text,
                  style: pw.TextStyle(
                    fontSize: 7.7,
                    color: _textMain,
                    fontWeight: bold ? pw.FontWeight.bold : null,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
                align: align,
              );
            }

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: i % 2 == 1 ? _zebraColor : _cardBgColor,
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: i == items.length - 1
                        ? pw.BorderSide.none.color
                        : _borderColor,
                    width: i == items.length - 1 ? 0 : 0.5,
                  ),
                ),
              ),
              children: [
                textCell('${i + 1}', align: pw.Alignment.center),
                cell(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: descWidgets,
                  ),
                  align: pw.Alignment.centerLeft,
                ),
                textCell(item.hsnCode, align: pw.Alignment.center),
                textCell(
                  '${item.quantity} ${item.uom}',
                  align: pw.Alignment.center,
                ),
                textCell(_currency(item.unitPrice)),
                textCell(taxStr, align: pw.Alignment.centerRight),
                textCell(_currency(item.totalAmount), bold: true),
              ],
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalSummaryCard(
    Map<String, dynamic> quotation,
    bool isInterState,
    double roundOff,
  ) {
    pw.Widget calcRow(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9.7,
                color: bold ? _primaryColor : _textMuted,
                fontWeight: bold ? pw.FontWeight.bold : null,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9.7,
                color: bold ? _primaryColor : _textMain,
                fontWeight: bold ? pw.FontWeight.bold : null,
              ),
            ),
          ],
        ),
      );
    }

    final subtotal = _toDouble(quotation['totalSubtotal']);
    final itemDiscount = _toDouble(quotation['totalItemDiscount']);
    final taxableValue = _toDouble(quotation['totalTaxableAmount']);
    final cgst = _toDouble(quotation['totalCgst']);
    final sgst = _toDouble(quotation['totalSgst']);
    final igst = _toDouble(quotation['totalIgst']);
    final finalTotal = _toDouble(
      quotation['finalTotal'] ?? quotation['grandTotal'],
    );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          decoration: pw.BoxDecoration(
            color: _cardBgColor,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: _borderColor),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              calcRow('Subtotal', _currency(subtotal)),
              if (itemDiscount > 0)
                calcRow('Discount', '-${_currency(itemDiscount)}'),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                child: pw.Divider(color: _borderColor, thickness: 1),
              ),
              calcRow('Taxable Value', _currency(taxableValue), bold: true),
              pw.SizedBox(height: 6),

              if (!isInterState) ...[
                calcRow('CGST', _currency(cgst)),
                calcRow('SGST', _currency(sgst)),
              ] else ...[
                calcRow('IGST', _currency(igst)),
              ],

              if (roundOff != 0) calcRow('Round Off', _currency(roundOff)),
              pw.SizedBox(height: 12),

              pw.Container(
                decoration: pw.BoxDecoration(
                  color: _primaryColor, // Dark total background
                  borderRadius: const pw.BorderRadius.vertical(
                    bottom: pw.Radius.circular(9),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 16,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRAND TOTAL',
                      style: pw.TextStyle(
                        fontSize: 13.2,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.Text(
                      _currency(finalTotal),
                      style: pw.TextStyle(
                        fontSize: 15.8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBottomSection(
    Map<String, dynamic> quotation,
    bool isInterState,
    double roundOff,
  ) {
    final terms = quotation['dynamicTerms'];
    final companyName = _safeString(quotation['companyName']);
    final sigName = _safeString(quotation['signatureName']);
    final sigDesignation = _safeString(quotation['signatureDesignation']);
    final sigPhone = _safeString(quotation['signaturePhone']);

    final termsCard = _buildCard(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(left: 4, right: 4, bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TERMS & CONDITIONS',
              style: pw.TextStyle(
                fontSize: 8.8,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
                letterSpacing: 0.4,
              ),
            ),
            pw.SizedBox(height: 10),
            if (terms is List && terms.isNotEmpty)
              ...terms.map((term) {
                if (term == null ||
                    term['value'] == null ||
                    _safeString(term['value']).isEmpty) {
                  return pw.SizedBox.shrink();
                }

                final title = _safeString(term['title']);
                final value = _cleanPdfText(_safeString(term['value']));

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4.5, right: 8),
                        height: 3,
                        width: 3,
                        decoration: pw.BoxDecoration(
                          color: _accentColor,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              if (title.isNotEmpty)
                                pw.TextSpan(
                                  text: '$title: ',
                                  style: pw.TextStyle(
                                    fontSize: 8.2,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _textMain,
                                  ),
                                ),
                              pw.TextSpan(
                                text: value,
                                style: pw.TextStyle(
                                  fontSize: 8.2,
                                  color: _textMuted,
                                  lineSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
            else
              pw.Text(
                'Standard commercial terms and conditions apply.',
                style: pw.TextStyle(
                  fontSize: 8.2,
                  color: _textMuted,
                  lineSpacing: 1.2,
                ),
              ),
          ],
        ),
      ),
    );

    final signatureCard = _buildCard(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (companyName.isNotEmpty)
              pw.Text(
                'For $companyName',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
                textAlign: pw.TextAlign.right,
              ),
            pw.SizedBox(height: 46),
            pw.Container(width: 145, height: 1, color: _borderColor),
            pw.SizedBox(height: 6),
            if (sigName.isNotEmpty)
              pw.Text(
                sigName,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _textMain,
                ),
              )
            else
              pw.Text(
                'Authorised Signatory',
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: _textMain,
                ),
              ),
            if (sigDesignation.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                sigDesignation,
                style: pw.TextStyle(
                  fontSize: 8.2,
                  color: _textMuted,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
            if (sigPhone.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'Ph: $sigPhone',
                style: pw.TextStyle(fontSize: 8, color: _textMuted),
              ),
            ],
          ],
        ),
      ),
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 6, right: 6, bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 6, child: termsCard),
              pw.SizedBox(width: 30),
              pw.Expanded(
                flex: 4,
                child: _buildTotalSummaryCard(
                  quotation,
                  isInterState,
                  roundOff,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [pw.Container(width: 305, child: signatureCard)],
          ),
          pw.SizedBox(height: 18),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(pw.Context context, bool isSO) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            isSO
                ? 'This is a system generated Sales Order.'
                : 'This is a computer generated document.',
            style: pw.TextStyle(
              fontSize: 7.9,
              fontStyle: pw.FontStyle.italic,
              color: _textMuted,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 7.9,
              fontWeight: pw.FontWeight.bold,
              color: _textMuted,
            ),
          ),
        ],
      ),
    );
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
    final String documentType = QuotationPdfGenerator._safeString(
      quotation['documentType'],
    );
    final String displayDocumentType = documentType.isNotEmpty
        ? documentType
        : 'Quotation';
    final bool isSO = QuotationPdfGenerator._isSalesOrder(displayDocumentType);

    String docNumber = '';
    if (isSO) {
      docNumber = QuotationPdfGenerator._safeString(
        quotation['salesOrderNumberDisplay'],
      );
      if (docNumber.isEmpty) {
        docNumber = QuotationPdfGenerator._safeString(
          quotation['salesOrderNumber'],
        );
      }
      if (docNumber.isEmpty) {
        docNumber = QuotationPdfGenerator._safeString(quotation['soNumber']);
      }
      if (docNumber.isEmpty) {
        docNumber = QuotationPdfGenerator._safeString(quotation['orderNumber']);
      }
    }
    if (docNumber.isEmpty) {
      docNumber = QuotationPdfGenerator._safeString(quotation['quoteNumber']);
      if (docNumber.isEmpty) {
        docNumber = QuotationPdfGenerator._safeString(
          quotation['quotationNumber'],
        );
      }
    }
    if (docNumber.isEmpty) docNumber = 'N/A';

    final displayTitle = titleOverride ?? '$displayDocumentType Preview';

    // Premium Corporate Color for the Unified Header
    const headerBgColor = Color(0xFF111111);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: headerBgColor,
        // 🔥 FIX: Explicitly set the Back Button and Action Icons to pure white
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          displayTitle,
          // 🔥 FIX: Explicitly set the Title Text to pure white
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      // Wrapping in a Theme forces the internal PdfPreview toolbar to blend flawlessly with the AppBar
      body: Theme(
        data: Theme.of(context).copyWith(
          primaryColor:
              headerBgColor, // Matches the internal toolbar to the AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: headerBgColor,
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            actionsIconTheme: IconThemeData(color: Colors.white),
          ),
          iconTheme: const IconThemeData(
            color: Colors.white,
          ), // Forces toolbar buttons to be visible
        ),
        child: PdfPreview(
          build: (format) =>
              QuotationPdfGenerator.buildPdf(format, quotation, items),
          initialPageFormat: PdfPageFormat.a4,
          canChangeOrientation: false,
          canChangePageFormat: false,
          allowPrinting: true,
          allowSharing: true,
          pdfFileName: '${displayDocumentType}_$docNumber.pdf'.replaceAll(
            ' ',
            '_',
          ),
          scrollViewDecoration: const BoxDecoration(
            color: Color(
              0xFFF1F5F9,
            ), // Subtle grey background so the white paper pops
          ),
          // maxPageWidth prevents the PDF from rendering too huge on desktop, forcing it to fit nicely
          maxPageWidth: 800,
        ),
      ),
    );
  }
}
