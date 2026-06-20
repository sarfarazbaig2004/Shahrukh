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
    0xFF111827,
  ); // Charcoal black
  static final PdfColor _accentColor = PdfColor.fromInt(0xFFC8A951); // Gold
  static final PdfColor _bgColor = PdfColor.fromInt(
    0xFFF9FAFB,
  ); // Very light grey
  static final PdfColor _cardBgColor = PdfColors.white;
  static final PdfColor _borderColor = PdfColor.fromInt(
    0xFFE5E7EB,
  ); // Light grey border
  static final PdfColor _textMain = PdfColor.fromInt(
    0xFF111827,
  ); // Charcoal black
  static final PdfColor _textMuted = PdfColor.fromInt(0xFF6B7280); // Muted grey
  static final PdfColor _zebraColor = PdfColor.fromInt(
    0xFFF3F4F6,
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
          margin: const pw.EdgeInsets.all(36),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              color: _bgColor,
            ), // Clean soft background, no watermark
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
            ), // Thin MEMCO accent divider
            pw.SizedBox(height: 24),
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
            pw.SizedBox(height: 20),
            _buildTotalSummaryCard(quotation, isInterState, roundOff),
            pw.SizedBox(height: 28),
            _buildBottomSection(quotation),
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

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: _borderColor),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Image(
                    logoImage,
                    height: 50,
                    width: 50,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (companyName.isNotEmpty) ...[
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(
                          color: _primaryColor, // Bold charcoal
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                    if (companyAddress.isNotEmpty) ...[
                      pw.Text(
                        companyAddress,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: _textMuted,
                          lineSpacing:
                              1.4, // Essential for multi-line formatting
                        ),
                      ),
                      pw.SizedBox(height: 6),
                    ],
                    if (legalIds.isNotEmpty) ...[
                      pw.Text(
                        legalIds.join('  |  '),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _textMain,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                    if (contacts.isNotEmpty) ...[
                      pw.Text(
                        contacts.join('  |  '),
                        style: pw.TextStyle(fontSize: 9, color: _textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              if (isPreview)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFEF3C7),
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFF59E0B)),
                  ),
                  child: pw.Text(
                    'PREVIEW',
                    style: pw.TextStyle(
                      color: PdfColor.fromInt(0xFFD97706),
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              pw.Text(
                displayDocumentType.toUpperCase(),
                style: pw.TextStyle(
                  color: _accentColor, // Document type in MEMCO accent
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTwoColumnInfo(
    Map<String, dynamic> quotation,
    String soNumber,
    String quoteNumber,
    String docDateStr,
    bool isSO,
  ) {
    final clientName = _safeString(quotation['clientName']);
    final clientAddress = _safeString(quotation['clientAddress']);
    final customerState = _safeString(quotation['customerState']);
    final gstNo = _safeString(quotation['gstNo']);
    final contactPerson = _safeString(quotation['contactPerson']);
    final clientMobile = _safeString(quotation['clientMobile']);
    final inquiryRef = _safeString(quotation['inquiryRefNo']);
    final revision = _safeString(quotation['revisionNo']);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 11,
          child: _buildCard(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _textMuted,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (clientName.isNotEmpty) ...[
                  pw.Text(
                    clientName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _textMain,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                ],
                if (clientAddress.isNotEmpty)
                  pw.Text(
                    clientAddress,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _textMain,
                      lineSpacing: 1.5,
                    ),
                  ),
                if (customerState.isNotEmpty)
                  pw.Text(
                    'State: $customerState',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _textMain,
                      lineSpacing: 1.5,
                    ),
                  ),
                pw.SizedBox(height: 8),
                if (gstNo.isNotEmpty)
                  pw.Text(
                    'GSTIN: $gstNo',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _textMain,
                    ),
                  ),
                pw.SizedBox(height: 4),
                if (contactPerson.isNotEmpty)
                  pw.Text(
                    'Attn: $contactPerson',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _textMain,
                    ),
                  ),
                if (clientMobile.isNotEmpty)
                  pw.Text(
                    'Ph: $clientMobile',
                    style: pw.TextStyle(fontSize: 10, color: _textMain),
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 9,
          child: _buildCard(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'DOCUMENT DETAILS',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _textMuted,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 12),
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
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _textMuted)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: _cardBgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Subject: ',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _textMuted,
              ),
            ),
            pw.TextSpan(
              text: subject,
              style: pw.TextStyle(
                fontSize: 11,
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
            fontSize: 12,
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
          0: const pw.FixedColumnWidth(40),
          1: const pw.FlexColumnWidth(3.5),
          2: const pw.FixedColumnWidth(70),
          3: const pw.FixedColumnWidth(60),
          4: const pw.FixedColumnWidth(80),
          5: const pw.FixedColumnWidth(80),
          6: const pw.FixedColumnWidth(90),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: _primaryColor, // Charcoal background
              borderRadius: const pw.BorderRadius.vertical(
                top: pw.Radius.circular(9),
              ),
            ),
            children:
                [
                  'S.No',
                  'Item Description',
                  'HSN/SAC',
                  'Qty',
                  'Rate',
                  'Tax',
                  'Amount',
                ].map((text) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    alignment:
                        (text == 'S.No' ||
                            text == 'Qty' ||
                            text == 'HSN/SAC' ||
                            text == 'Tax')
                        ? pw.Alignment.center
                        : (text == 'Item Description'
                              ? pw.Alignment.centerLeft
                              : pw.Alignment.centerRight),
                    child: pw.Text(
                      text,
                      style: pw.TextStyle(
                        color: PdfColors.white, // White header text
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
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
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ];
            if (item.description.trim().isNotEmpty) {
              descWidgets.add(pw.SizedBox(height: 6));
              final lines = item.description.split('\n');
              for (var line in lines) {
                if (line.trim().isNotEmpty) {
                  descWidgets.add(
                    pw.Text(
                      line.trim(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: _textMuted,
                        lineSpacing: 1.4,
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
                    fontSize: 9,
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
                  vertical: 14,
                  horizontal: 10,
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
                    fontSize: 10,
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
                color: i % 2 == 1
                    ? _zebraColor
                    : _cardBgColor, // Subtle grey zebra
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
                textCell(
                  _currency(item.totalAmount),
                  bold: true,
                ), // Amount column bold
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
                fontSize: 11,
                color: bold ? _primaryColor : _textMuted,
                fontWeight: bold ? pw.FontWeight.bold : null,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
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
          width: 320,
          decoration: pw.BoxDecoration(
            color: _cardBgColor,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: _borderColor),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.SizedBox(height: 10),
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
                  color: _accentColor, // MEMCO accent background
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
                        fontSize: 15, // Bigger font
                        color: PdfColors.white, // White text
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.Text(
                      _currency(finalTotal),
                      style: pw.TextStyle(
                        fontSize: 18, // Bigger font
                        color: PdfColors.white, // White text
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

  static pw.Widget _buildBottomSection(Map<String, dynamic> quotation) {
    final terms = quotation['dynamicTerms'];
    final companyName = _safeString(quotation['companyName']);
    final sigName = _safeString(quotation['signatureName']);
    final sigDesignation = _safeString(quotation['signatureDesignation']);
    final sigPhone = _safeString(quotation['signaturePhone']);

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
                  'TERMS & CONDITIONS',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 14),
                if (terms is List && terms.isNotEmpty)
                  ...terms.map((term) {
                    if (term == null ||
                        term['value'] == null ||
                        _safeString(term['value']).isEmpty) {
                      return pw.SizedBox.shrink();
                    }
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            margin: const pw.EdgeInsets.only(top: 5, right: 10),
                            height: 4,
                            width: 4,
                            decoration: pw.BoxDecoration(
                              color: _accentColor, // MEMCO accent dots
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: '${_safeString(term['title'])}: ',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _textMain,
                                    ),
                                  ),
                                  pw.TextSpan(
                                    text: _safeString(term['value']),
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      color: _textMuted,
                                      lineSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        pw.SizedBox(width: 20),

        pw.Expanded(
          flex: 4,
          child: _buildCard(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (companyName.isNotEmpty)
                  pw.Text(
                    'For $companyName',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                pw.SizedBox(height: 54),

                if (sigName.isNotEmpty)
                  pw.Text(
                    sigName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _textMain,
                    ),
                  ),

                if (sigDesignation.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    sigDesignation,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _primaryColor,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],

                if (sigPhone.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Ph: $sigPhone',
                    style: pw.TextStyle(fontSize: 10, color: _textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: _textMuted,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
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
    const headerBgColor = Color(0xFF1E293B);

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
