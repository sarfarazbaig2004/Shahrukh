import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'proforma_screen.dart';

// =========================================================
// 1. PROFORMA PREVIEW SCREEN
// =========================================================
class ProformaPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<ProformaLocalItem> items;

  const ProformaPreviewScreen({
    super.key,
    required this.data,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final String proformaNumber =
    ProformaPdfGenerator.safeString(data['proformaNumber']).isNotEmpty
        ? ProformaPdfGenerator.safeString(data['proformaNumber'])
        : 'N/A';

    final String fileName = 'Proforma_Invoice_$proformaNumber.pdf'
        .replaceAll('/', '_')
        .replaceAll(' ', '_');

    const Color headerBgColor = Color(0xFFE5E7EB);
    const Color headerBorderColor = Color(0xFFD1D5DB);
    const Color headerTextColor = Color(0xFF2B2B2B);
    const Color viewerBgColor = Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: viewerBgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            color: headerBgColor,
            border: Border(
              bottom: BorderSide(color: headerBorderColor, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text(
                      'PROFORMA INVOICE',
                      style: TextStyle(
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
                      icon: const Icon(
                        Icons.arrow_back,
                        color: headerTextColor,
                      ),
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
          final double previewWidth = constraints.maxWidth >= 1500
              ? 780.0
              : constraints.maxWidth >= 1300
              ? 720.0
              : constraints.maxWidth >= 1100
              ? 660.0
              : constraints.maxWidth >= 900
              ? 600.0
              : constraints.maxWidth - 32;

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
                  titleTextStyle: TextStyle(
                    color: headerTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                iconTheme: const IconThemeData(color: headerTextColor),
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: headerTextColor,
                  surface: headerBgColor,
                  onSurface: headerTextColor,
                ),
              ),
              child: PdfPreview(
                build: (format) =>
                    ProformaPdfGenerator.buildPdf(format, data, items),
                initialPageFormat: PdfPageFormat.a4,
                canChangeOrientation: false,
                canChangePageFormat: false,
                allowPrinting: true,
                allowSharing: true,
                pdfFileName: fileName,
                scrollViewDecoration: const BoxDecoration(
                  color: viewerBgColor,
                ),
                maxPageWidth: previewWidth,
              ),
            ),
          );
        },
      ),
    );
  }
}

// =========================================================
// 2. BACKWARD-COMPATIBLE PDF GENERATOR ENTRY POINT
// =========================================================
Future<Uint8List> generateProformaPdf(
    Map<String, dynamic> data,
    List<ProformaLocalItem> items,
    ) {
  return ProformaPdfGenerator.buildPdf(PdfPageFormat.a4, data, items);
}

// =========================================================
// 3. PROFORMA PDF GENERATOR
// =========================================================
class ProformaPdfGenerator {
  static final PdfColor _primaryColor = PdfColor.fromInt(0xFF1E3A8A);
  static final PdfColor _textMain = PdfColor.fromInt(0xFF222222);
  static final PdfColor _textMuted = PdfColor.fromInt(0xFF555555);
  static final PdfColor _borderColor = PdfColor.fromInt(0xFFCCCCCC);
  static final PdfColor _tableHeaderColor = PdfColor.fromInt(0xFFF3F4F6);

  static String safeString(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    return text == 'null' ? '' : text;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) {
      final double result = value.toDouble();
      return result.isNaN ? 0.0 : result;
    }
    if (value is String) {
      final String normalized = value.trim().replaceAll(',', '');
      if (normalized.isEmpty) return 0.0;
      final double? parsed = double.tryParse(normalized);
      if (parsed != null && !parsed.isNaN) return parsed;
    }
    return 0.0;
  }

  static String _cleanPdfText(dynamic value) {
    String text = safeString(value);
    text = text
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('•', '-')
        .replaceAll('₹', 'Rs. ');
    text = text.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );
    return text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static String _currency(double value) {
    final NumberFormat format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 2,
    );
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

    const List<String> units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];

    const List<String> tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String words = '';

    if ((number / 10000000).floor() > 0) {
      words +=
      '${_convertNumberToWords((number / 10000000).floor())} Crore ';
      number %= 10000000;
    }
    if ((number / 100000).floor() > 0) {
      words += '${_convertNumberToWords((number / 100000).floor())} Lakh ';
      number %= 100000;
    }
    if ((number / 1000).floor() > 0) {
      words +=
      '${_convertNumberToWords((number / 1000).floor())} Thousand ';
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
        if ((number % 10) > 0) {
          words += ' ${units[number % 10]}';
        }
      }
    }

    return words.trim();
  }

  static double _settingsDouble(
      Map<String, dynamic> settings,
      String key,
      double fallback,
      ) {
    final double value = _toDouble(settings[key]);
    return value == 0.0 ? fallback : value;
  }

  static String _normalizeDocumentType(dynamic value) {
    final String text = safeString(value).toLowerCase();
    return text.contains('export') ? 'export' : 'domestic';
  }

  static bool _hasUsableTerms(Map<String, dynamic> data) {
    for (final String key in <String>[
      'dynamicTerms',
      'terms',
      'termsAndConditions',
    ]) {
      final dynamic rawTerms = data[key];
      if (rawTerms is List) {
        for (final dynamic item in rawTerms) {
          if (item is Map) {
            final String title = safeString(
              item['title'] ?? item['name'] ?? item['label'],
            );
            final String value = safeString(
              item['value'] ??
                  item['detail'] ??
                  item['description'] ??
                  item['text'],
            );
            if (title.isNotEmpty || value.isNotEmpty) return true;
          } else if (safeString(item).isNotEmpty) {
            return true;
          }
        }
      } else if (safeString(rawTerms).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> _loadLetterheadSettings(
      Map<String, dynamic> data,
      ) async {
    String companyId = safeString(data['companyId']);

    if (companyId.isEmpty) {
      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final Map<String, dynamic> rootData =
              userDoc.data() ?? <String, dynamic>{};
          companyId = safeString(
            rootData['activeCompanyId'] ?? rootData['companyId'],
          );
        }
      } catch (_) {}
    }

    if (companyId.isEmpty) return <String, dynamic>{};

    try {
      final DocumentSnapshot<Map<String, dynamic>> settingsSnapshot =
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('letterhead_settings')
          .get();

      Map<String, dynamic> settings =
          settingsSnapshot.data() ?? <String, dynamic>{};

      if (settings.isEmpty) {
        final DocumentSnapshot<Map<String, dynamic>> legacySnapshot =
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('settings')
            .doc('quotation_settings')
            .get();
        settings = legacySnapshot.data() ?? <String, dynamic>{};
      }

      final String documentType = _normalizeDocumentType(
        data['proformaType'] ??
            data['quotationType'] ??
            data['invoiceType'] ??
            data['documentType'],
      );

      final Map<String, dynamic> merged = <String, dynamic>{
        'companyId': companyId,
        'documentType': documentType,
      };

      final dynamic selectedSettings = settings[documentType];
      if (selectedSettings is Map) {
        merged.addAll(Map<String, dynamic>.from(selectedSettings));
      }

      settings.forEach((String key, dynamic value) {
        if (value != null && value is! Map) {
          merged[key] = value;
        }
      });

      if (safeString(merged['letterheadUrl']).isEmpty &&
          settings['domestic'] is Map) {
        final Map<String, dynamic> domesticSettings =
        Map<String, dynamic>.from(settings['domestic'] as Map);
        if (safeString(domesticSettings['letterheadUrl']).isNotEmpty) {
          merged['letterheadUrl'] = domesticSettings['letterheadUrl'];
        }
      }

      return merged;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<pw.ImageProvider?> _loadImageFromUrl(
      String url, {
        int maxBytes = 10 * 1024 * 1024,
      }) async {
    if (url.isEmpty) return null;

    try {
      final Uint8List? bytes =
      await FirebaseStorage.instance.refFromURL(url).getData(maxBytes);
      if (bytes != null && bytes.isNotEmpty) {
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}

    try {
      final String cacheBusterUrl = url.contains('?')
          ? '$url&t=${DateTime.now().millisecondsSinceEpoch}'
          : '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      return await networkImage(cacheBusterUrl);
    } catch (_) {
      return null;
    }
  }

  static Future<pw.ImageProvider?> _loadSettingsLetterheadImage(
      Map<String, dynamic> settings,
      ) async {
    String valueFrom(List<String> keys) {
      for (final String key in keys) {
        final String value = safeString(settings[key]);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final String url = valueFrom(<String>[
      'letterheadUrl',
      'url',
      'fileUrl',
      'downloadUrl',
    ]);

    final String savedType = valueFrom(<String>[
      'letterheadType',
      'letterheadFileType',
      'fileType',
      'type',
    ]).toLowerCase();

    final String lowerUrl = url.toLowerCase();
    String fileType = savedType;

    if (lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg')) {
      fileType = 'jpg';
    } else if (lowerUrl.contains('.png')) {
      fileType = 'png';
    } else if (lowerUrl.contains('.webp')) {
      fileType = 'webp';
    } else if (lowerUrl.contains('.pdf')) {
      fileType = 'pdf';
    }

    if (url.isEmpty || fileType == 'pdf') return null;
    return _loadImageFromUrl(url);
  }

  static pw.Widget _buildPageBackground({
    required pw.ImageProvider? letterheadImage,
  }) {
    if (letterheadImage == null) return pw.SizedBox.shrink();

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Image(letterheadImage, fit: pw.BoxFit.cover),
    );
  }

  static pw.Widget _buildFallbackHeader(
      Map<String, dynamic> data,
      pw.ImageProvider? logoImage,
      ) {
    final String companyName = safeString(data['companyName']);
    final String companyAddress = _cleanPdfText(data['companyAddress']);
    final String gst = safeString(data['companyGst']);
    final String pan = safeString(data['companyPan']);
    final String phone = safeString(data['companyPhone']);
    final String email = safeString(data['companyEmail']);
    final String website = safeString(data['companyWebsite']);

    final List<String> companyMeta = <String>[];
    if (gst.isNotEmpty) companyMeta.add('GSTIN: $gst');
    if (pan.isNotEmpty) companyMeta.add('PAN: $pan');
    if (phone.isNotEmpty) companyMeta.add('Ph: $phone');
    if (email.isNotEmpty) companyMeta.add('Email: $email');
    if (website.isNotEmpty) companyMeta.add('Web: $website');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderColor, width: 0.5),
        ),
      ),
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
                  companyName.isNotEmpty
                      ? companyName.toUpperCase()
                      : 'COMPANY NAME',
                  style: pw.TextStyle(
                    color: _textMain,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (companyAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    companyAddress,
                    style: pw.TextStyle(
                      color: _textMuted,
                      fontSize: 7.5,
                    ),
                  ),
                ],
                if (companyMeta.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    companyMeta.join('  |  '),
                    style: pw.TextStyle(
                      color: _textMain,
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            'PROFORMA\nINVOICE',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
              letterSpacing: 1.2,
              lineSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDocumentTitle() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      alignment: pw.Alignment.center,
      child: pw.Column(
        children: [
          pw.Text(
            'PROFORMA INVOICE',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(height: 0.5, width: 90, color: _borderColor),
        ],
      ),
    );
  }

  static pw.Widget _buildPartyAndDocumentInfo(Map<String, dynamic> data) {
    final String clientName = safeString(data['clientName']);
    final String clientAddress = _cleanPdfText(data['clientAddress']);
    final String customerState = safeString(data['customerState']);
    final String customerGst = safeString(data['gstNo']);
    final String contactPerson = safeString(data['contactPerson']);
    final String clientMobile = safeString(data['clientMobile']);

    final String shippingName = safeString(data['shippingName']);
    final String shippingAddress = _cleanPdfText(data['shippingAddress']);
    final String shippingState = safeString(data['shippingState']);
    final String shippingGst = safeString(data['shippingGst']);
    final String shippingContactPerson =
    safeString(data['shippingContactPerson']);
    final String shippingMobile = safeString(data['shippingMobile']);

    final String proformaNumber = safeString(data['proformaNumber']);
    final String proformaDate = _resolveDateString(data);
    final String inquiryNumber = safeString(data['inquiryNumber']);
    final String quotationNumber = safeString(data['quotationNumber']);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 4,
            child: _buildPartyColumn(
              title: 'BILL TO',
              name: clientName,
              address: clientAddress,
              state: customerState,
              gst: customerGst,
              contactPerson: contactPerson,
              mobile: clientMobile,
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 4,
            child: _buildPartyColumn(
              title: 'SHIP TO',
              name: shippingName,
              address: shippingAddress,
              state: shippingState,
              gst: shippingGst,
              contactPerson: shippingContactPerson,
              mobile: shippingMobile,
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('DOCUMENT DETAILS'),
                pw.SizedBox(height: 4),
                _buildMetaRow('PI Number', proformaNumber),
                _buildMetaRow('Date', proformaDate),
                _buildMetaRow('Inquiry Ref.', inquiryNumber),
                if (quotationNumber.isNotEmpty &&
                    quotationNumber != proformaNumber)
                  _buildMetaRow('Quotation No.', quotationNumber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _resolveDateString(Map<String, dynamic> data) {
    final String directDate = safeString(data['proformaDateStr']);
    if (directDate.isNotEmpty) return directDate;

    final dynamic dateValue =
        data['proformaDate'] ?? data['date'] ?? data['createdAt'];
    if (dateValue == null) return '';

    try {
      if (dateValue is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(dateValue.toDate());
      }
      if (dateValue is DateTime) {
        return DateFormat('dd/MM/yyyy').format(dateValue);
      }
      if (dateValue is String) {
        final String value = dateValue.trim();
        if (value.isEmpty) return '';
        if (value.contains('/')) return value;
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(value));
      }
    } catch (_) {}

    return safeString(dateValue);
  }

  static pw.Widget _buildPartyColumn({
    required String title,
    required String name,
    required String address,
    required String state,
    required String gst,
    required String contactPerson,
    required String mobile,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        pw.SizedBox(height: 4),
        if (name.isNotEmpty)
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: _textMain,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        if (address.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            address,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: _textMuted,
              lineSpacing: 1.2,
            ),
          ),
        ],
        if (state.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'State: $state',
            style: pw.TextStyle(fontSize: 7.5, color: _textMuted),
          ),
        ],
        if (gst.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'GSTIN: $gst',
            style: pw.TextStyle(
              fontSize: 7.5,
              color: _textMain,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
        if (contactPerson.isNotEmpty || mobile.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          if (contactPerson.isNotEmpty)
            pw.Text(
              'Attn: $contactPerson',
              style: pw.TextStyle(
                fontSize: 7.5,
                color: _textMain,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          if (mobile.isNotEmpty)
            pw.Text(
              'Ph: $mobile',
              style: pw.TextStyle(fontSize: 7.5, color: _textMuted),
            ),
        ],
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 8,
        color: _primaryColor,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  static pw.Widget _buildMetaRow(String label, String value) {
    if (value.trim().isEmpty) return pw.SizedBox.shrink();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, color: _textMuted),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 7.5,
                color: _textMain,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(
      String text, {
        pw.Alignment align = pw.Alignment.center,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      alignment: align,
      child: pw.Text(
        text,
        textAlign: align == pw.Alignment.centerLeft
            ? pw.TextAlign.left
            : align == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7.2,
          fontWeight: pw.FontWeight.bold,
          color: _textMain,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(
      String text, {
        pw.Alignment align = pw.Alignment.centerLeft,
        bool bold = false,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      alignment: align,
      child: pw.Text(
        text,
        textAlign: align == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : align == pw.Alignment.center
            ? pw.TextAlign.center
            : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7,
          color: _textMain,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<ProformaLocalItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(42),
        3: const pw.FixedColumnWidth(34),
        4: const pw.FixedColumnWidth(30),
        5: const pw.FixedColumnWidth(51),
        6: const pw.FixedColumnWidth(34),
        7: const pw.FixedColumnWidth(34),
        8: const pw.FixedColumnWidth(61),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _tableHeaderColor),
          children: [
            _tableHeaderCell('Sr.'),
            _tableHeaderCell(
              'Item & Description',
              align: pw.Alignment.centerLeft,
            ),
            _tableHeaderCell('HSN'),
            _tableHeaderCell('Qty'),
            _tableHeaderCell('UOM'),
            _tableHeaderCell('Rate', align: pw.Alignment.centerRight),
            _tableHeaderCell('Disc %', align: pw.Alignment.centerRight),
            _tableHeaderCell('Tax %', align: pw.Alignment.centerRight),
            _tableHeaderCell('Total', align: pw.Alignment.centerRight),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final int index = entry.key;
          final ProformaLocalItem item = entry.value;
          final double totalTaxPercent =
              item.cgstPercent + item.sgstPercent + item.igstPercent;

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.top,
            children: [
              _tableCell('${index + 1}', align: pw.Alignment.center),
              pw.Container(
                padding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _cleanPdfText(item.name),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _textMain,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (item.description.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        _cleanPdfText(item.description),
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: _textMuted,
                          lineSpacing: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _tableCell(item.hsnCode, align: pw.Alignment.center),
              _tableCell(
                item.quantity.toStringAsFixed(2),
                align: pw.Alignment.center,
              ),
              _tableCell(item.uom, align: pw.Alignment.center),
              _tableCell(
                item.unitPrice.toStringAsFixed(2),
                align: pw.Alignment.centerRight,
              ),
              _tableCell(
                item.discountPercent.toStringAsFixed(2),
                align: pw.Alignment.centerRight,
              ),
              _tableCell(
                totalTaxPercent.toStringAsFixed(2),
                align: pw.Alignment.centerRight,
              ),
              _tableCell(
                item.totalAmount.toStringAsFixed(2),
                align: pw.Alignment.centerRight,
                bold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildFinancialSummary(
      Map<String, dynamic> data,
      bool isInterState,
      ) {
    final double subtotal = _toDouble(data['totalSubtotal']);
    final double itemDiscount = _toDouble(data['totalItemDiscount']);
    final double globalDiscount = _toDouble(data['globalDiscountAmount']);
    final double taxableAmount = _toDouble(data['totalTaxableAmount']);
    final double cgst = _toDouble(data['totalCgst']);
    final double sgst = _toDouble(data['totalSgst']);
    final double igst = _toDouble(data['totalIgst']);
    final double roundOff = _toDouble(data['roundOff']);
    final double finalTotal = _toDouble(data['finalTotal']);
    final double advanceAmount = _toDouble(data['advanceAmount']);
    final double balanceAmount = _toDouble(data['balanceAmount']);
    final String advancePercent = safeString(data['advancePercent']);
    final String balancePercent = safeString(data['balancePercent']);

    pw.Widget totalRow(
        String label,
        String value, {
          bool bold = false,
          bool isGrand = false,
          bool topBorder = false,
        }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        decoration: topBorder
            ? pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: _borderColor, width: 0.5),
          ),
        )
            : null,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: isGrand ? 9.5 : 7.5,
                color: isGrand ? _primaryColor : _textMuted,
                fontWeight: bold || isGrand
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: isGrand ? 9.5 : 7.5,
                color: isGrand ? _primaryColor : _textMain,
                fontWeight: bold || isGrand
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, right: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Amount in Words',
                  style: pw.TextStyle(fontSize: 7.5, color: _textMuted),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _amountInWords(finalTotal),
                  style: pw.TextStyle(fontSize: 8.5, color: _textMain),
                ),
              ],
            ),
          ),
        ),
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Column(
              children: [
                totalRow('Subtotal', _currency(subtotal)),
                if (itemDiscount > 0)
                  totalRow('Item Discounts', '-${_currency(itemDiscount)}'),
                if (globalDiscount > 0)
                  totalRow(
                    'Global Discount',
                    '-${_currency(globalDiscount)}',
                  ),
                totalRow(
                  'Taxable Amount',
                  _currency(taxableAmount),
                  bold: true,
                  topBorder: true,
                ),
                if (!isInterState) ...[
                  totalRow('CGST', _currency(cgst)),
                  totalRow('SGST', _currency(sgst)),
                ] else ...[
                  totalRow('IGST', _currency(igst)),
                ],
                if (roundOff != 0)
                  totalRow('Round Off', _currency(roundOff)),
                totalRow(
                  'Grand Total',
                  _currency(finalTotal),
                  isGrand: true,
                  topBorder: true,
                ),
                if (advanceAmount > 0) ...[
                  totalRow(
                    advancePercent.isNotEmpty
                        ? 'Advance ($advancePercent%)'
                        : 'Advance',
                    _currency(advanceAmount),
                    bold: true,
                    topBorder: true,
                  ),
                  totalRow(
                    balancePercent.isNotEmpty
                        ? 'Balance ($balancePercent%)'
                        : 'Balance',
                    _currency(balanceAmount),
                    bold: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Map<String, dynamic> _bankMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static bool _hasBankDetails(Map<String, dynamic> bank) {
    return <String>[
      'accountHolderName',
      'bankName',
      'accountNumber',
      'ifsc',
      'branch',
      'branchAddress',
      'micr',
      'swift',
    ].any((String key) => safeString(bank[key]).isNotEmpty);
  }

  static pw.Widget _buildBankDetails(Map<String, dynamic> bank) {
    if (!_hasBankDetails(bank)) return pw.SizedBox.shrink();

    final String accountName = safeString(bank['accountHolderName']);
    final String bankName = safeString(bank['bankName']);
    final String accountNumber = safeString(bank['accountNumber']);
    final String ifsc = safeString(bank['ifsc']);
    final String branch = safeString(bank['branch']);
    final String branchAddress = _cleanPdfText(bank['branchAddress']);
    final String micr = safeString(bank['micr']);
    final String swift = safeString(bank['swift']);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('BANK DETAILS'),
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            if (accountName.isNotEmpty)
              _buildInfoPair('Account Name', accountName),
            if (bankName.isNotEmpty) _buildInfoPair('Bank Name', bankName),
            if (branch.isNotEmpty) _buildInfoPair('Branch', branch),
            if (branchAddress.isNotEmpty)
              _buildInfoPair('Branch Address', branchAddress),
            if (accountNumber.isNotEmpty)
              _buildInfoPair('Account No.', accountNumber),
            if (ifsc.isNotEmpty) _buildInfoPair('IFSC / RTGS', ifsc),
            if (micr.isNotEmpty) _buildInfoPair('MICR', micr),
            if (swift.isNotEmpty) _buildInfoPair('SWIFT', swift),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfoPair(String label, String value) {
    return pw.Container(
      width: 250,
      padding: const pw.EdgeInsets.only(bottom: 2, right: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _textMain,
              ),
            ),
          ),
          pw.Container(
            width: 8,
            child: pw.Text(
              ':',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _textMain,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 7.5,
                color: _textMuted,
                lineSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<dynamic> _resolveTerms(Map<String, dynamic> data) {
    final dynamic dynamicTerms = data['dynamicTerms'];
    if (dynamicTerms is List && dynamicTerms.isNotEmpty) return dynamicTerms;

    final dynamic terms = data['terms'];
    if (terms is List && terms.isNotEmpty) return terms;

    final dynamic termsAndConditions = data['termsAndConditions'];
    if (termsAndConditions is List && termsAndConditions.isNotEmpty) {
      return termsAndConditions;
    }

    return <dynamic>[];
  }

  static pw.Widget _buildTerms(Map<String, dynamic> data) {
    final List<dynamic> terms = _resolveTerms(data);
    if (terms.isEmpty) return pw.SizedBox.shrink();

    final List<pw.Widget> termWidgets = <pw.Widget>[];

    for (final dynamic rawTerm in terms) {
      String title = '';
      String value = '';

      if (rawTerm is Map) {
        title = safeString(
          rawTerm['title'] ?? rawTerm['name'] ?? rawTerm['label'],
        );
        value = _cleanPdfText(
          rawTerm['value'] ??
              rawTerm['detail'] ??
              rawTerm['description'] ??
              rawTerm['text'],
        );
      } else {
        value = _cleanPdfText(rawTerm);
      }

      if (title.isEmpty && value.isEmpty) continue;

      termWidgets.add(
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.only(bottom: 2, right: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                pw.Container(
                  width: 62,
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _textMain,
                    ),
                  ),
                ),
              if (title.isNotEmpty)
                pw.Container(
                  width: 8,
                  child: pw.Text(
                    ':',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _textMain,
                    ),
                  ),
                ),
              pw.Expanded(
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    color: _textMuted,
                    lineSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (termWidgets.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('TERMS & CONDITIONS'),
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 10,
          runSpacing: 2,
          children: termWidgets,
        ),
      ],
    );
  }

  static pw.Widget _buildSignature(Map<String, dynamic> data) {
    final String companyName = safeString(data['companyName']);
    final String signatureName = safeString(data['signatureName']);
    final String signatureDesignation =
    safeString(data['signatureDesignation']);
    final String signaturePhone = safeString(data['signaturePhone']);

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (companyName.isNotEmpty)
            pw.Text(
              'For $companyName',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _textMain,
              ),
            ),
          pw.SizedBox(height: 30),
          if (signatureName.isNotEmpty)
            pw.Text(
              signatureName,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _textMain,
              ),
            ),
          if (signatureDesignation.isNotEmpty)
            pw.Text(
              signatureDesignation,
              style: pw.TextStyle(fontSize: 7.5, color: _textMuted),
            ),
          if (signaturePhone.isNotEmpty)
            pw.Text(
              signaturePhone,
              style: pw.TextStyle(fontSize: 7.5, color: _textMuted),
            ),
        ],
      ),
    );
  }

  static Future<Uint8List> buildPdf(
      PdfPageFormat format,
      Map<String, dynamic> data,
      List<ProformaLocalItem> items,
      ) async {
    debugPrint(
      'Proforma Number (FINAL): ${safeString(data['proformaNumber'])}',
    );

    final Map<String, dynamic> pdfData = Map<String, dynamic>.from(data);
    final Map<String, dynamic> letterheadSettings =
    await _loadLetterheadSettings(pdfData);

    final double headerHeight =
    _settingsDouble(letterheadSettings, 'headerHeight', 120);
    final double footerHeight =
    _settingsDouble(letterheadSettings, 'footerHeight', 80);
    final double leftMargin =
    _settingsDouble(letterheadSettings, 'leftMargin', 40);
    final double rightMargin =
    _settingsDouble(letterheadSettings, 'rightMargin', 40);

    final pw.ImageProvider? letterheadImage =
    await _loadSettingsLetterheadImage(letterheadSettings);

    pw.ImageProvider? logoImage;
    final String logoUrl = safeString(pdfData['companyLogoUrl']);
    if (logoUrl.isNotEmpty) {
      logoImage = await _loadImageFromUrl(logoUrl, maxBytes: 5 * 1024 * 1024);
    }

    final dynamic settingsTerms = letterheadSettings['terms'];
    if (!_hasUsableTerms(pdfData) &&
        settingsTerms is List &&
        settingsTerms.isNotEmpty) {
      pdfData['terms'] = settingsTerms;
      pdfData['dynamicTerms'] = settingsTerms;
    }

    final bool isInterState = pdfData['isInterState'] == true;
    final Map<String, dynamic> bankDetails =
    _bankMap(pdfData['bankDetails']);

    final pw.Document document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format.copyWith(
            marginLeft: leftMargin,
            marginRight: rightMargin,
            marginTop: letterheadImage != null ? headerHeight : 30,
            marginBottom: letterheadImage != null ? footerHeight : 30,
          ),
          buildBackground: (context) => _buildPageBackground(
            letterheadImage: letterheadImage,
          ),
        ),
        header: (context) => pw.SizedBox.shrink(),
        footer: (context) {
          if (letterheadImage != null) return pw.SizedBox.shrink();

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
            if (letterheadImage == null)
              _buildFallbackHeader(pdfData, logoImage),
            if (letterheadImage != null) _buildDocumentTitle(),
            _buildPartyAndDocumentInfo(pdfData),
            _buildItemsTable(items),
            pw.SizedBox(height: 10),
            _buildFinancialSummary(pdfData, isInterState),
            if (_hasBankDetails(bankDetails)) ...[
              pw.SizedBox(height: 18),
              _buildBankDetails(bankDetails),
            ],
            if (_resolveTerms(pdfData).isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTerms(pdfData),
            ],
            pw.SizedBox(height: 20),
            _buildSignature(pdfData),
          ];
        },
      ),
    );

    return document.save();
  }
}
