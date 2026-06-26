import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExcelQuotationFormat {
  static String safe(dynamic value, [String fallback = '']) {
    var text = (value ?? '').toString().trim();
    if (text.isEmpty) return fallback;

    text = text
        .replaceAll('Ø', '')
        .replaceAll('ø', '')
        .replaceAll('⌀', '')
        .replaceAll('∅', '')
        .replaceAll('�', '')
        .replaceAll('□', '')
        .replaceAll('₹', 'Rs.');

    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    text = text.replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), '');

    return text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
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
    double size = 8.5,
    bool bold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );
  }

  static pw.Widget watermark() {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(
        children: [
          pw.Container(color: PdfColors.white),
          pw.Center(
            child: pw.Opacity(
              opacity: 0.075,
              child: pw.Transform.rotate(
                angle: -0.45,
                child: pw.Text(
                  'MEMCO',
                  style: pw.TextStyle(
                    fontSize: 96,
                    color: PdfColors.red800,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget scopeOfSupply(Map<String, dynamic> q) {
    final customerGstin = first(q, [
      'customerGstin',
      'customerGSTIN',
      'customerGstNo',
      'customerGST',
      'clientGstin',
      'clientGSTIN',
      'clientGstNo',
      'billingGstin',
      'billingGSTIN',
      'partyGstin',
      'partyGSTIN',
    ], 'Not Provided');

    final companyPan = first(q, ['companyPan', 'panNo', 'pan'], 'AAACM8022D');

    final udyamNo = first(q, [
      'companyUdyam',
      'udyamNo',
      'udyamNumber',
      'msmeNo',
    ], 'UDYAM NO. TO BE UPDATED');

    final scope = first(
      q,
      ['scopeOfSupply', 'scope', 'supplyScope', 'quotationScope'],
      'Supply of welding machine / equipment and standard accessories as per quotation items mentioned below.',
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(105),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(105),
        3: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          children: [
            _labelCell('PAN No.'),
            _valueCell(companyPan),
            _labelCell('Udyam No.'),
            _valueCell(udyamNo),
          ],
        ),
        pw.TableRow(
          children: [
            _labelCell('Customer GSTIN'),
            _valueCell(customerGstin),
            _labelCell('Scope of Supply'),
            _valueCell(scope),
          ],
        ),
      ],
    );
  }

  static pw.Widget _labelCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      color: PdfColors.grey200,
      child: pw.Text(text, style: style(size: 8.4, bold: true)),
    );
  }

  static pw.Widget _valueCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(safe(text), style: style(size: 8.4)),
    );
  }
}
