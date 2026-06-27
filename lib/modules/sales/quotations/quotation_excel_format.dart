import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExcelQuotationFormat {
  static final PdfColor peach = PdfColor(1.0, 0.82, 0.70);
  static final PdfColor darkBrown = PdfColor(0.27, 0.16, 0.09);

  // Same text size used across quotation body, customer details, item table and terms.
  static const double bodySize = 8.2;
  static const double smallSize = 8.0;
  static const double productTextSize = 6.8;
  static const double productHeadSize = 7.0;
  static const double titleSize = 17.5;

  static String safe(dynamic value, [String fallback = '']) {
    var text = (value ?? '').toString().trim();
    if (text.isEmpty) return fallback;

    text = text
        .replaceAll('Ø', '')
        .replaceAll('ø', '')
        .replaceAll('⌀', '')
        .replaceAll('⏀', '')
        .replaceAll('∅', '')
        .replaceAll('Φ', '')
        .replaceAll('φ', '')
        .replaceAll('�', '')
        .replaceAll('□', '')
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

    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(' .', '.')
        .replaceAll(' ,', ',')
        .trim();
  }

  static String filled(String value, [String fallback = 'Not Provided']) {
    final text = safe(value);
    return text.isEmpty ? fallback : text;
  }

  static String displayDate(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    try {
      final dynamic d = value;
      final DateTime dt = d.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {}

    if (value is DateTime) {
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    }

    final text = safe(value);
    if (text.isEmpty) return fallback;

    final timestampMatch = RegExp(
      r'Timestamp\(seconds=([0-9]+)',
    ).firstMatch(text);
    if (timestampMatch != null) {
      final seconds = int.tryParse(timestampMatch.group(1) ?? '');
      if (seconds != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }

    if (text.toLowerCase().contains('timestamp')) return fallback;
    return text;
  }

  static String cleanInquiryReference(String value) {
    final text = safe(value);
    if (text.isEmpty) return 'Verbal';
    final lower = text.toLowerCase().trim();

    // Do not print customer/site location as inquiry reference.
    if (lower.startsWith('location:') || lower == 'location') return 'Verbal';
    if (lower.contains('timestamp(')) return 'Verbal';

    return text;
  }

  static String first(
    Map<String, dynamic> data,
    List<String> keys, [
    String fallback = '',
  ]) {
    for (final key in keys) {
      final value = safe(data[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static pw.TextStyle style({
    double size = bodySize,
    bool bold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );
  }

  static pw.Widget watermarkImage(pw.ImageProvider? image) {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Container(
        color: PdfColors.white,
        child: pw.Center(
          child: image == null
              ? pw.Opacity(
                  opacity: 0.07,
                  child: pw.Text(
                    'memco',
                    style: pw.TextStyle(
                      fontSize: 96,
                      color: PdfColors.red800,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                )
              : pw.Opacity(
                  opacity: 0.16,
                  child: pw.Image(image, width: 430, fit: pw.BoxFit.contain),
                ),
        ),
      ),
    );
  }

  static pw.Widget watermark() => watermarkImage(null);

  static pw.Widget logoWatermark() => watermarkImage(null);

  static pw.Widget header(Map<String, dynamic> q, pw.ImageProvider? logoImage) {
    const companyName = 'Miraj Electrical & Mechanical Co. Pvt. Ltd.';
    const address =
        'Head Office: 2, Swastik Chambers, Ground Floor, C. S. T. Road, Chembur, Mumbai - 400 071.';
    const contact = '+91 9082907433';
    const email = 'memcosales@memcoin.com';
    const website = 'www.memcoin.com';
    const gst = '27AAACM8022D1ZU';
    const pan = 'AAACM8022D';
    const cin = 'U31200MH1982PTC026005';
    const udyam = 'UDYAM-MH-19-0022252';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.9),
      ),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Text(
                  companyName,
                  textAlign: pw.TextAlign.center,
                  style: style(size: 16, bold: true, color: darkBrown),
                ),
              ),
              pw.SizedBox(width: 10),
              logoImage == null
                  ? pw.Text(
                      'MEMCO',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    )
                  : pw.Container(
                      width: 94,
                      height: 40,
                      alignment: pw.Alignment.center,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'AN ISO 45001:2018, 9001:2008 & 50001:2018 Certified Company',
            textAlign: pw.TextAlign.center,
            style: style(size: 7.5, bold: true),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            address,
            textAlign: pw.TextAlign.center,
            style: style(size: 7.3),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Contact: $contact  |  Email: $email  |  Web: $website',
            textAlign: pw.TextAlign.center,
            style: style(size: 7.3),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'GSTIN: $gst  |  PAN: $pan  |  CIN: $cin  |  Udyam: $udyam',
            textAlign: pw.TextAlign.center,
            style: style(size: 7.2, bold: true),
          ),
        ],
      ),
    );
  }

  static pw.Widget _centerLine(
    String text, {
    double size = 8.4,
    bool bold = false,
    double height = 17,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Container(
      height: height,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 0.45),
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.45),
        ),
      ),
      child: pw.Text(
        safe(text),
        textAlign: pw.TextAlign.center,
        style: style(size: size, bold: bold, color: color),
      ),
    );
  }

  static pw.Widget titleBar() {
    return pw.Container(
      height: 31,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: peach,
        border: pw.Border.all(color: PdfColors.black, width: 0.55),
      ),
      child: pw.Text(
        'QUOTATION',
        style: pw.TextStyle(
          fontSize: titleSize,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  static pw.Widget infoBox(
    Map<String, dynamic> q,
    String docNo,
    String docDate,
  ) {
    final customer = first(q, [
      'clientName',
      'customerName',
      'partyName',
      'companyName',
      'name',
    ], 'Customer Name Not Provided');

    final address = first(q, [
      'clientAddress',
      'customerAddress',
      'addressLine',
      'billingAddress',
      'shippingAddress',
      'address',
    ], 'Customer Address Not Provided');

    final email = first(q, [
      'clientEmail',
      'customerEmail',
      'contactEmail',
      'email',
    ], 'Not Provided');

    final phone = first(q, [
      'clientMobile',
      'customerMobile',
      'customerPhone',
      'contactMobile',
      'contactPhone',
      'mobile',
      'phone',
    ], 'Not Provided');

    final person = first(q, [
      'contactPerson',
      'customerContactPerson',
      'contactName',
      'personName',
    ], 'Not Provided');

    final gstin = first(q, [
      'customerGstin',
      'customerGSTIN',
      'customerGstNo',
      'customerGST',
      'clientGstin',
      'clientGSTIN',
      'clientGstNo',
      'billingGstin',
      'partyGstin',
      'gstNo',
      'gstin',
    ], 'Not Provided');

    final inquiryReference = cleanInquiryReference(
      first(q, [
        'inquiryRefNo',
        'inquiryReference',
        'enquiryReference',
        'inquiryNo',
        'enquiryNo',
        'referenceNo',
      ], 'Verbal'),
    );

    final inquiryDate = displayDate(
      q['inquiryDate'] ??
          q['enquiryDate'] ??
          q['inquiryCreatedAt'] ??
          q['enquiryCreatedDate'],
      docDate,
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.9),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.45),
        columnWidths: const {
          0: pw.FixedColumnWidth(90),
          1: pw.FlexColumnWidth(2.5),
          2: pw.FixedColumnWidth(110),
          3: pw.FlexColumnWidth(1.35),
        },
        children: [
          _infoRow('M/s', customer, 'Quotation No.', docNo),
          _infoRow('Address', address, 'Quotation Date', docDate),
          _infoRow('E-mail', email, 'Inquiry Ref.', inquiryReference),
          _infoRow('Contact No.', phone, 'Inquiry Date', inquiryDate),
          _infoRow('Contact Person', person, 'Customer GSTIN', gstin),
        ],
      ),
    );
  }

  static pw.TableRow _infoRow(String a, String b, String c, String d) {
    return pw.TableRow(
      children: [
        _plainCell(a, bold: true),
        _plainCell(b),
        _plainCell(c, bold: true),
        _plainCell(d, bold: d.isNotEmpty),
      ],
    );
  }

  static pw.Widget _plainCell(
    String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    double size = 8.4,
    PdfColor? fill,
  }) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 19),
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      color: fill,
      child: pw.Text(
        safe(text),
        style: style(size: size, bold: bold),
      ),
    );
  }

  static pw.Widget scopeOfSupply(Map<String, dynamic> q) {
    return pw.SizedBox(height: 0);
  }

  static String read(dynamic item, String field) {
    try {
      if (field == 'name') return safe(item.name);
      if (field == 'description') return safe(item.description);
      if (field == 'uom') return safe(item.uom);
      if (field == 'productId') return safe(item.productId);
      if (field == 'hsnCode') return safe(item.hsnCode);
    } catch (_) {}

    if (item is Map) return safe(item[field]);
    return '';
  }

  static double readNum(dynamic item, String field) {
    try {
      final value = field == 'quantity'
          ? item.quantity
          : field == 'unitPrice'
          ? item.unitPrice
          : field == 'subtotal'
          ? item.subtotal
          : null;
      return numValue(value);
    } catch (_) {}

    if (item is Map) return numValue(item[field]);
    return 0;
  }

  static double numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String qty(dynamic item) {
    final q = readNum(item, 'quantity');
    if (q == 0) return '';
    if (q == q.roundToDouble()) return q.round().toString();
    return q.toStringAsFixed(2);
  }

  static String indian(num value) {
    final neg = value < 0;
    var digits = value.abs().round().toString();
    if (digits.length <= 3) return '${neg ? '-' : ''}$digits';

    final last = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];

    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }

    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${neg ? '-' : ''}${parts.join(',')},$last';
  }

  static String money(dynamic value) {
    final n = value is num ? value.toDouble() : numValue(value);
    if (n == 0) return '';
    return 'Rs.${indian(n)}=00';
  }

  static pw.Widget productDescription(dynamic item) {
    final title = read(item, 'name');
    final desc = read(item, 'description');

    final lines = desc
        .split(RegExp(r'\r?\n'))
        .map((e) => safe(e))
        .where((e) => e.isNotEmpty)
        .where((e) => e.toLowerCase() != title.toLowerCase())
        .toList();

    final compactDescription = lines.join(' | ');

    return pw.Container(
      alignment: pw.Alignment.topLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.isEmpty ? 'Product / Service' : title,
            style: style(size: productTextSize, bold: true),
          ),
          if (compactDescription.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                compactDescription,
                textAlign: pw.TextAlign.left,
                style: style(size: productTextSize),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget productTable(List<dynamic> items) {
    String itemDesc(dynamic item) {
      final productName = read(item, 'productName').isNotEmpty
          ? read(item, 'productName')
          : read(item, 'name');

      final description = read(item, 'description');
      final model = read(item, 'model');
      final capacity = read(item, 'capacity');

      final parts = <String>[
        productName,
        description,
        if (model.isNotEmpty) 'Model: $model',
        if (capacity.isNotEmpty) 'Capacity: $capacity',
      ].where((e) => e.trim().isNotEmpty).toList();

      return parts.join('\n');
    }

    double itemNumber(dynamic item, String key) {
      return numValue(read(item, key));
    }

    pw.Widget cell(
      String text, {
      bool bold = false,
      PdfColor? fill,
      double size = 6.9,
      pw.TextAlign align = pw.TextAlign.left,
      double minHeight = 54,
    }) {
      return pw.Container(
        constraints: pw.BoxConstraints(minHeight: minHeight),
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        color: fill,
        alignment: align == pw.TextAlign.center
            ? pw.Alignment.center
            : align == pw.TextAlign.right
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          safe(text),
          textAlign: align,
          style: style(size: size, bold: bold),
          maxLines: 8,
          overflow: pw.TextOverflow.clip,
        ),
      );
    }

    final cleanItems = items.where((item) {
      final desc = itemDesc(item).trim();
      final rate = read(item, 'unitRate').trim();
      final amount = read(item, 'amount').trim();
      final netAmount = read(item, 'netAmount').trim();
      return desc.isNotEmpty ||
          rate.isNotEmpty ||
          amount.isNotEmpty ||
          netAmount.isNotEmpty;
    }).toList();

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: peach),
        children: [
          cell(
            'Sr.',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
          cell(
            'Product Description',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
          cell(
            'HSN',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
          cell(
            'UOM',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
          cell(
            'Qty.',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
          cell(
            'Unit Rate',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
          cell(
            'Amount',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
          cell(
            'Net Amount',
            bold: true,
            size: 7.0,
            align: pw.TextAlign.center,
            minHeight: 24,
          ),
        ],
      ),
    ];

    for (var i = 0; i < cleanItems.length; i++) {
      final item = cleanItems[i];
      final net = itemNumber(item, 'netAmount') == 0
          ? itemNumber(item, 'amount')
          : itemNumber(item, 'netAmount');

      rows.add(
        pw.TableRow(
          children: [
            cell('${i + 1}', align: pw.TextAlign.center),
            cell(itemDesc(item), size: 6.4, minHeight: 64),
            cell(
              read(item, 'hsnCode').isNotEmpty
                  ? read(item, 'hsnCode')
                  : read(item, 'hsn'),
              align: pw.TextAlign.center,
              size: 6.4,
              minHeight: 64,
            ),
            cell(
              read(item, 'uom').isNotEmpty ? read(item, 'uom') : 'Nos',
              align: pw.TextAlign.center,
              size: 6.4,
              minHeight: 64,
            ),
            cell(
              qty(item),
              align: pw.TextAlign.center,
              size: 6.4,
              minHeight: 64,
            ),
            cell(
              money(itemNumber(item, 'unitRate')),
              align: pw.TextAlign.right,
              size: 6.4,
              minHeight: 64,
            ),
            cell(
              money(itemNumber(item, 'amount')),
              align: pw.TextAlign.right,
              size: 6.4,
              minHeight: 64,
            ),
            cell(
              money(net),
              align: pw.TextAlign.right,
              size: 6.4,
              minHeight: 64,
            ),
          ],
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.9),
      ),
      child: pw.Table(
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColors.black, width: 0.45),
        ),
        columnWidths: const {
          0: pw.FixedColumnWidth(34),
          1: pw.FlexColumnWidth(3.7),
          2: pw.FixedColumnWidth(58),
          3: pw.FixedColumnWidth(42),
          4: pw.FixedColumnWidth(38),
          5: pw.FixedColumnWidth(72),
          6: pw.FixedColumnWidth(72),
          7: pw.FixedColumnWidth(82),
        },
        children: rows,
      ),
    );
  }

  static pw.Widget amountSummary(
    Map<String, dynamic> q,
    bool isInterState,
    double roundOff,
    List<dynamic> items,
  ) {
    final itemsSubtotal = items.fold<double>(
      0,
      (sum, item) => sum + readNum(item, 'subtotal'),
    );
    final subtotal = numValue(q['totalSubtotal']);
    final taxable = numValue(q['totalTaxableAmount']);
    final cgst = numValue(q['totalCgst']);
    final sgst = numValue(q['totalSgst']);
    final igst = numValue(q['totalIgst']);
    final grand = numValue(q['finalTotal'] ?? q['grandTotal']);

    final effectiveSubtotal = subtotal > 0 ? subtotal : itemsSubtotal;
    final effectiveTaxable = taxable > 0 ? taxable : effectiveSubtotal;
    final tax = isInterState ? igst : (cgst + sgst);
    final effectiveGrand = grand > 0
        ? grand
        : effectiveTaxable + tax + roundOff;

    pw.TableRow row(String label, String value, {bool grandTotal = false}) {
      return pw.TableRow(
        children: [
          pw.Container(
            height: 21,
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(right: 5),
            child: pw.Text(
              label,
              style: style(size: productTextSize, bold: true),
            ),
          ),
          pw.Container(
            height: 21,
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(right: 5),
            color: grandTotal ? PdfColors.yellow : PdfColors.white,
            child: pw.Text(
              value,
              style: style(size: productTextSize, bold: true),
            ),
          ),
        ],
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FixedColumnWidth(122),
      },
      children: [
        row('Sub Total', money(effectiveSubtotal)),
        row(isInterState ? 'IGST @18%' : 'CGST + SGST', money(tax)),
        row('Grand Total', money(effectiveGrand), grandTotal: true),
      ],
    );
  }

  static pw.Widget terms(Map<String, dynamic> q) {
    final rows = <Map<String, String>>[
      {'title': 'Add', 'value': 'GST @18% extra as applicable.'},
      {'title': 'Transportation', 'value': 'Extra at actual.'},
      {
        'title': 'Delivery',
        'value':
            'Within 2 weeks from the date of receipt of confirmed purchase order.',
      },
      {'title': 'Warranty', 'value': 'For 12 months on power source only.'},
      {'title': 'Prices', 'value': 'Ex-works Mumbai.'},
      {
        'title': 'Payment',
        'value': '100% advance against proforma invoice before dispatch.',
      },
      {'title': 'Inspection', 'value': 'At our Mumbai works.'},
      {'title': 'Validity', 'value': 'This quotation is valid for 10 days.'},
    ];

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        children: [
          pw.Container(
            color: peach,
            height: 21,
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.only(left: 4),
            child: pw.Text(
              'Terms & Conditions',
              style: style(size: bodySize, bold: true),
            ),
          ),
          pw.Container(color: peach, height: 21),
        ],
      ),
      ...rows.map(
        (row) => pw.TableRow(
          children: [
            _plainCell(row['title'] ?? '', size: bodySize),
            _plainCell(row['value'] ?? '', size: bodySize),
          ],
        ),
      ),
      pw.TableRow(
        children: [
          _plainCell('Comments:', bold: true, size: bodySize),
          _plainCell('', size: bodySize),
        ],
      ),
      pw.TableRow(
        children: [
          _plainCell('Remarks:', bold: true, size: bodySize),
          _plainCell('', size: bodySize),
        ],
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(115),
        1: pw.FlexColumnWidth(),
      },
      children: tableRows,
    );
  }

  static pw.Widget signature(Map<String, dynamic> q) {
    const company = 'Miraj Electrical & Mechanical Co. Pvt. Ltd.';
    const sigName = 'Faizan Khan';
    const sigDesignation = 'Marketing Executive';
    const sigPhone = '+91 7351248854';
    const factory =
        'Factory Address: Ansa A 1&2, Ansa Industrial Estate, Sakivihar Road, Sakinaka, Mumbai - 400 072.';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: 80,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.55),
          ),
          alignment: pw.Alignment.bottomRight,
          padding: const pw.EdgeInsets.only(right: 5, bottom: 5),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('For $company', style: style(size: bodySize, bold: true)),
              pw.SizedBox(height: 4),
              pw.Text(
                '$sigName ($sigDesignation)',
                style: style(size: bodySize, bold: true),
              ),
              pw.Text(
                'Contact No. $sigPhone',
                style: style(size: bodySize, bold: true),
              ),
            ],
          ),
        ),
        pw.Container(
          height: 31,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.55),
          ),
          child: pw.Text(
            factory,
            textAlign: pw.TextAlign.center,
            style: style(size: bodySize, bold: true),
          ),
        ),
        pw.Container(
          height: 18,
          decoration: pw.BoxDecoration(
            color: peach,
            border: pw.Border.all(color: PdfColors.black, width: 0.55),
          ),
        ),
        pw.Container(
          height: 31,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.55),
          ),
          child: pw.Text('MAKE IN INDIA', style: style(size: 10.5, bold: true)),
        ),
      ],
    );
  }
}
