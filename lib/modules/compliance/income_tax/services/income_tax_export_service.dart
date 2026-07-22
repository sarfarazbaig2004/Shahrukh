import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/income_tax_models.dart';

class IncomeTaxExportService {
  const IncomeTaxExportService();

  Future<Uint8List> buildPdf({
    required IncomeTaxDraft draft,
    required RegimeComparison comparison,
  }) async {
    final document = pw.Document(
      title: 'Income Tax Computation - ${draft.profile.name}',
      author: 'MEMCO Quik ERP',
      creator: 'MEMCO Quik ERP Income Tax Calculator',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'MEMCO Quik ERP',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Income Tax Computation Sheet',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${draft.financialYear.label} • ${draft.financialYear.statutoryYearLabel}',
          ),
          pw.SizedBox(height: 18),
          _pdfSection('Taxpayer Information', [
            [
              'Taxpayer Name',
              draft.profile.name.isEmpty ? '-' : draft.profile.name,
            ],
            ['PAN', draft.profile.pan.isEmpty ? '-' : draft.profile.pan],
            [
              'Residential Status',
              _title(draft.profile.residentialStatus.name),
            ],
            ['Category', _title(draft.profile.category.name)],
            ['Suggested ITR', comparison.suggestedItr],
          ]),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _pdfTaxColumn('Old Regime', comparison.oldRegime),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _pdfTaxColumn('New Regime', comparison.newRegime),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Recommendation',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${comparison.recommendedRegime == TaxRegime.oldRegime ? 'Old' : 'New'} Regime',
                ),
                pw.Text('Computed tax saving: ${_money(comparison.taxSaving)}'),
              ],
            ),
          ),
          if (comparison.oldRegime.warnings.isNotEmpty ||
              comparison.newRegime.warnings.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Review Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...{
              ...comparison.oldRegime.warnings,
              ...comparison.newRegime.warnings,
            }.map((warning) => pw.Bullet(text: warning)),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'This computation is generated from configured tax rules. Validate supporting documents, special-rate income, treaty relief and statutory notifications before filing.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return document.save();
  }

  Uint8List buildCsv({
    required IncomeTaxDraft draft,
    required RegimeComparison comparison,
  }) {
    final rows = _reportRows(draft, comparison);
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Uint8List buildExcel({
    required IncomeTaxDraft draft,
    required RegimeComparison comparison,
  }) {
    final workbook = Excel.createExcel();
    final defaultName = workbook.getDefaultSheet();
    final sheet = workbook['Tax Computation'];
    if (defaultName != null && defaultName != 'Tax Computation') {
      workbook.delete(defaultName);
    }

    for (final row in _reportRows(draft, comparison)) {
      sheet.appendRow(
        row.map<CellValue?>((value) => TextCellValue(value)).toList(),
      );
    }
    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Unable to encode Excel workbook.');
    }
    return Uint8List.fromList(bytes);
  }

  Uint8List buildOds({
    required IncomeTaxDraft draft,
    required RegimeComparison comparison,
  }) {
    final rows = _reportRows(draft, comparison);
    final tableRows = rows.map((row) {
      final cells = row.map((cell) {
        final escaped = _xml(cell);
        return '<table:table-cell office:value-type="string">'
            '<text:p>$escaped</text:p>'
            '</table:table-cell>';
      }).join();
      return '<table:table-row>$cells</table:table-row>';
    }).join();

    final contentXml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
 xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
 xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
 xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
 office:version="1.2">
 <office:body>
  <office:spreadsheet>
   <table:table table:name="Tax Computation">$tableRows</table:table>
  </office:spreadsheet>
 </office:body>
</office:document-content>''';

    const manifestXml = '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest
 xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"
 manifest:version="1.2">
 <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>
 <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
</manifest:manifest>''';

    final archive = Archive();
    final mimetype = utf8.encode(
      'application/vnd.oasis.opendocument.spreadsheet',
    );
    final content = utf8.encode(contentXml);
    final manifest = utf8.encode(manifestXml);
    archive.addFile(ArchiveFile('mimetype', mimetype.length, mimetype));
    archive.addFile(ArchiveFile('content.xml', content.length, content));
    archive.addFile(
      ArchiveFile('META-INF/manifest.xml', manifest.length, manifest),
    );
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw StateError('Unable to encode ODS workbook.');
    return Uint8List.fromList(bytes);
  }

  pw.Widget _pdfSection(String title, List<List<String>> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: .5),
          children: rows
              .map(
                (row) => pw.TableRow(
                  children: row
                      .map(
                        (cell) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            cell,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  pw.Widget _pdfTaxColumn(String title, TaxComputationResult result) {
    return _pdfSection(title, [
      ['Gross Income', _money(result.grossIncome)],
      ['Total Deductions', _money(result.totalDeductions)],
      ['Taxable Income', _money(result.taxableIncome)],
      ['Slab Tax', _money(result.slabTax)],
      ['Special-rate Tax', _money(result.specialRateTax)],
      ['Surcharge', _money(result.surcharge)],
      ['Rebate', _money(result.rebate)],
      ['Cess', _money(result.cess)],
      [
        'Interest',
        _money(result.interest234A + result.interest234B + result.interest234C),
      ],
      ['Net Tax', _money(result.netTax)],
      ['Payable', _money(result.payable)],
      ['Refund', _money(result.refund)],
    ]);
  }

  List<List<String>> _reportRows(
    IncomeTaxDraft draft,
    RegimeComparison comparison,
  ) {
    return [
      ['MEMCO Quik ERP - Income Tax Computation'],
      ['Financial Year', draft.financialYear.label],
      ['Statutory Year', draft.financialYear.statutoryYearLabel],
      ['Taxpayer Name', draft.profile.name],
      ['PAN', draft.profile.pan],
      ['Suggested ITR', comparison.suggestedItr],
      [],
      ['Particular', 'Old Regime', 'New Regime'],
      [
        'Gross Income',
        '${comparison.oldRegime.grossIncome}',
        '${comparison.newRegime.grossIncome}',
      ],
      [
        'Total Deductions',
        '${comparison.oldRegime.totalDeductions}',
        '${comparison.newRegime.totalDeductions}',
      ],
      [
        'Taxable Income',
        '${comparison.oldRegime.taxableIncome}',
        '${comparison.newRegime.taxableIncome}',
      ],
      [
        'Slab Tax',
        '${comparison.oldRegime.slabTax}',
        '${comparison.newRegime.slabTax}',
      ],
      [
        'Special-rate Tax',
        '${comparison.oldRegime.specialRateTax}',
        '${comparison.newRegime.specialRateTax}',
      ],
      [
        'Surcharge',
        '${comparison.oldRegime.surcharge}',
        '${comparison.newRegime.surcharge}',
      ],
      [
        'Rebate',
        '${comparison.oldRegime.rebate}',
        '${comparison.newRegime.rebate}',
      ],
      ['Cess', '${comparison.oldRegime.cess}', '${comparison.newRegime.cess}'],
      [
        'Interest 234A',
        '${comparison.oldRegime.interest234A}',
        '${comparison.newRegime.interest234A}',
      ],
      [
        'Interest 234B',
        '${comparison.oldRegime.interest234B}',
        '${comparison.newRegime.interest234B}',
      ],
      [
        'Interest 234C',
        '${comparison.oldRegime.interest234C}',
        '${comparison.newRegime.interest234C}',
      ],
      [
        'Net Tax',
        '${comparison.oldRegime.netTax}',
        '${comparison.newRegime.netTax}',
      ],
      [
        'Payable',
        '${comparison.oldRegime.payable}',
        '${comparison.newRegime.payable}',
      ],
      [
        'Refund',
        '${comparison.oldRegime.refund}',
        '${comparison.newRegime.refund}',
      ],
      [],
      [
        'Recommended Regime',
        comparison.recommendedRegime == TaxRegime.oldRegime
            ? 'Old Regime'
            : 'New Regime',
      ],
      ['Computed Tax Saving', '${comparison.taxSaving}'],
    ];
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _money(int value) => 'INR $value';

  String _title(String value) => value
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .trim()
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
