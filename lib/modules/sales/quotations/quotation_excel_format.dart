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
    final companyName = first(q, [
      'companyName',
      'workspaceName',
    ], 'Miraj Electrical & Mechanical Co. Pvt. Ltd.');

    final headOffice = first(
      q,
      ['headOffice', 'companyAddress', 'address'],
      'Head Office: 2, Swastik Chambers, Ground Floor, C. S. T. Road, Chembur, Mumbai - 400 071.',
    );

    final contact = first(q, [
      'companyPhone',
      'companyMobile',
      'phone',
      'mobile',
    ], '+91 9082907433');

    final email = first(q, ['companyEmail', 'email'], 'memcosales@memcoin.com');

    final website = first(q, ['website', 'companyWebsite'], 'www.memcoin.com');
    final gst = first(q, ['companyGstin', 'gstin', 'gstNo'], '27AAACM8022D1ZU');
    final pan = first(q, ['companyPan', 'panNo', 'pan'], 'AAACM8022D');
    final cin = first(q, [
      'companyCin',
      'cinNo',
      'cin',
    ], 'U31200MH1982PTC026005');
    final udyam = first(q, [
      'companyUdyam',
      'udyamNo',
      'udyamNumber',
      'msmeNo',
    ], 'UDYAM-MH-19-0022252');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: 52,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 0.45),
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.45),
            ),
          ),
          child: pw.Stack(
            children: [
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, right: 125),
                  child: pw.Text(
                    safe(companyName),
                    textAlign: pw.TextAlign.center,
                    style: style(size: 15.5, bold: true, color: darkBrown),
                  ),
                ),
              ),
              pw.Positioned(
                right: 8,
                top: 5,
                child: logoImage == null
                    ? pw.Text(
                        'MEMCO',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800,
                        ),
                      )
                    : pw.Image(
                        logoImage,
                        width: 108,
                        height: 42,
                        fit: pw.BoxFit.contain,
                      ),
              ),
            ],
          ),
        ),
        _centerLine(
          'AN ISO 45001:2018, 9001:2008 & 50001:2018 Certified Company',
          bold: true,
        ),
        _centerLine(headOffice),
        _centerLine('Contact No.: $contact I E-mail Id: $email'),
        _centerLine(
          'Registered as an Micro Small Medium Enterprises (MSME) I Udyam No.: $udyam',
          bold: true,
        ),
        _centerLine(website, bold: true),
        _centerLine('GSTIN: $gst I PAN No.: $pan I CIN: $cin', bold: true),
      ],
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
      'customerName',
      'clientName',
      'partyName',
      'companyName',
      'name',
    ], 'Customer Name Not Provided');

    final address = first(q, [
      'customerAddress',
      'billingAddress',
      'shippingAddress',
      'address',
    ], 'Customer Address Not Provided');

    final email = first(q, [
      'customerEmail',
      'clientEmail',
      'email',
    ], 'Not Provided');

    final phone = first(q, [
      'customerPhone',
      'clientPhone',
      'contactPhone',
      'phone',
      'mobile',
    ], 'Not Provided');

    final person = first(q, [
      'contactPerson',
      'customerContactPerson',
      'contactName',
    ], 'Not Provided');

    final gstin = first(q, [
      'customerGstin',
      'customerGSTIN',
      'customerGstNo',
      'customerGST',
      'gstin',
      'gstNo',
      'clientGstin',
      'clientGSTIN',
      'clientGstNo',
      'billingGstin',
      'billingGSTIN',
      'partyGstin',
      'partyGSTIN',
    ], 'Not Provided');

    final rawInquiry = first(q, [
      'inquiryReference',
      'enquiryReference',
      'inquiryNo',
      'enquiryNo',
      'referenceNo',
    ], 'Verbal');

    final inquiry = cleanInquiryReference(rawInquiry);

    final inquiryDate = displayDate(
      q['inquiryDate'] ??
          q['enquiryDate'] ??
          q['inquiryCreatedAt'] ??
          q['enquiryCreatedDate'],
      docDate,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(92),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(112),
        3: pw.FixedColumnWidth(170),
      },
      children: [
        _infoRow('M/s', customer, 'Quotation No.', docNo),
        _infoRow('Address:', address, 'Quotation Date', docDate),
        _infoRow('E-mail Id:', email, 'Inquiry Reference', inquiry),
        _infoRow('Contact No.:', phone, 'Inquiry Date', inquiryDate),
        _infoRow('Contact Person:', person, '', ''),
        _infoRow('Customer GSTIN:', gstin, '', ''),
      ],
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
    final scope = first(
      q,
      ['scopeOfSupply', 'scope', 'supplyScope', 'quotationScope'],
      'Supply of welding machine / equipment and standard accessories as per quotation items mentioned below.',
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(120),
        1: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          children: [
            _plainCell('Scope of Supply', bold: true, fill: peach),
            _plainCell(scope),
          ],
        ),
      ],
    );
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
    pw.Widget head(String text) {
      return pw.Container(
        height: 22,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(2),
        color: peach,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: style(size: productHeadSize, bold: true),
        ),
      );
    }

    pw.Widget cell(
      pw.Widget child, {
      pw.Alignment align = pw.Alignment.center,
      double minHeight = 24,
    }) {
      return pw.Container(
        constraints: pw.BoxConstraints(minHeight: minHeight),
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: child,
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          head('Sr. No.'),
          head('Product Description'),
          head('HSN Code'),
          head('UOM'),
          head('Qty.'),
          head('Unit Rate'),
          head('Amount'),
          head('Net Amount'),
        ],
      ),
    ];

    final count = items.isEmpty ? 5 : (items.length < 5 ? 5 : items.length);

    for (var i = 0; i < count; i++) {
      final hasItem = i < items.length;
      final item = hasItem ? items[i] : null;

      rows.add(
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.top,
          children: [
            cell(
              pw.Text(
                '${i + 1}',
                style: style(size: productTextSize, bold: true),
              ),
            ),
            hasItem
                ? productDescription(item)
                : cell(
                    pw.Text('-', style: style(size: productTextSize)),
                    minHeight: 24,
                  ),
            cell(
              pw.Text(
                hasItem ? filled(read(item, 'hsnCode'), '-') : '-',
                style: style(size: productTextSize),
              ),
            ),
            cell(
              pw.Text(
                hasItem
                    ? (read(item, 'uom').isEmpty ? 'Nos.' : read(item, 'uom'))
                    : 'Nos.',
                style: style(size: productTextSize),
              ),
            ),
            cell(
              pw.Text(
                hasItem ? qty(item) : '1',
                style: style(size: productTextSize),
              ),
            ),
            cell(
              pw.Text(
                hasItem ? filled(money(readNum(item, 'unitPrice')), '-') : '-',
                textAlign: pw.TextAlign.right,
                style: style(size: productTextSize, bold: true),
              ),
              align: pw.Alignment.centerRight,
            ),
            cell(
              pw.Text(
                hasItem ? filled(money(readNum(item, 'subtotal')), '-') : '-',
                textAlign: pw.TextAlign.right,
                style: style(size: productTextSize, bold: true),
              ),
              align: pw.Alignment.centerRight,
            ),
            cell(
              pw.Text(
                hasItem ? filled(money(readNum(item, 'subtotal')), '-') : '-',
                textAlign: pw.TextAlign.right,
                style: style(size: productTextSize, bold: true),
              ),
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(34),
        1: pw.FlexColumnWidth(5.6),
        2: pw.FixedColumnWidth(55),
        3: pw.FixedColumnWidth(38),
        4: pw.FixedColumnWidth(34),
        5: pw.FixedColumnWidth(66),
        6: pw.FixedColumnWidth(66),
        7: pw.FixedColumnWidth(76),
      },
      children: rows,
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
    final dynamicTerms = q['dynamicTerms'];
    final rows = <Map<String, String>>[];

    if (dynamicTerms is List && dynamicTerms.isNotEmpty) {
      for (final term in dynamicTerms) {
        if (term is Map) {
          final title = safe(term['title']);
          final value = safe(term['value']);
          if (title.isNotEmpty || value.isNotEmpty) {
            rows.add({'title': title, 'value': value});
          }
        }
      }
    }

    if (rows.isEmpty) {
      rows.addAll([
        {'title': 'Add', 'value': 'GST @18%'},
        {'title': 'Transportation', 'value': 'Extra-at actual.'},
        {
          'title': 'Delivery',
          'value':
              'Within 2 weeks from the date of receipt of your confirm order.',
        },
        {'title': 'Warranty', 'value': 'For 12 Months on Power Source Only.'},
        {'title': 'Prices', 'value': 'Ex-works Mumbai.'},
        {'title': 'Payment', 'value': '100% Advance'},
        {'title': 'Inspection', 'value': 'At our Mumbai Works.'},
        {'title': 'Validity', 'value': 'For 10 Days.'},
      ]);
    }

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
              style: style(size: 8.7, bold: true),
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
    final company = first(q, [
      'companyName',
      'workspaceName',
    ], 'Miraj Electrical & Mechanical Co. Pvt. Ltd.');

    final sigName = first(q, [
      'signatureName',
      'preparedByName',
      'createdByName',
    ], 'Faizan Khan');
    final sigDesignation = first(q, [
      'signatureDesignation',
      'preparedByDesignation',
    ], 'Marketing Executive');
    final sigPhone = first(q, [
      'signaturePhone',
      'preparedByPhone',
    ], '+91 7351248854');

    final factory = first(
      q,
      ['factoryAddress'],
      'Factory Address: Ansa A 1&2 , Ansa Industrial Estate, Sakivihar Road Sakinaka Mumbai 400 072.',
    );

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
              pw.Text(
                'For $company',
                style: style(size: productTextSize, bold: true),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$sigName ($sigDesignation)',
                style: style(size: productTextSize, bold: true),
              ),
              pw.Text(
                'Contact No. $sigPhone',
                style: style(size: productTextSize, bold: true),
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
            style: style(size: productTextSize, bold: true),
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
