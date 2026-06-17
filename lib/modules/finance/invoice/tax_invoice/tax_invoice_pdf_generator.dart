// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// ------------------------------------------------------------------------
/// ENTERPRISE TAX INVOICE PDF GENERATOR
/// Hardened for Production Scale (Null-safe, Date-safe, Num-safe, Overflow-safe)
/// ------------------------------------------------------------------------
class InvoicePdfGenerator {
  /// Helper to safely sanitize filenames across all OS platforms
  static String _safeFileName(String? invoiceNumber) {
    final raw = invoiceNumber?.toString().trim() ?? 'Draft';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  /// Opens the built-in PDF Preview screen
  static Future<void> showPreview(
      BuildContext context,
      Map<String, dynamic> invoiceData,
      Map<String, dynamic> companyData, {
        Uint8List? logoBytes,
      }) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaxInvoicePdfPreviewScreen(
          invoiceData: invoiceData,
          companyData: companyData,
          logoBytes: logoBytes,
        ),
      ),
    );
  }

  /// Direct Print
  static Future<void> printInvoice(
      Map<String, dynamic> invoiceData,
      Map<String, dynamic> companyData, {
        Uint8List? logoBytes,
      }) async {
    final pdfBytes = await generate(invoiceData, companyData, logoBytes: logoBytes);
    final safeName = _safeFileName(invoiceData['invoiceNumber']);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_$safeName',
    );
  }

  /// Share PDF
  static Future<void> share(
      Map<String, dynamic> invoiceData,
      Map<String, dynamic> companyData, {
        String? fileName,
        Uint8List? logoBytes,
      }) async {
    final pdfBytes = await generate(invoiceData, companyData, logoBytes: logoBytes);
    final safeName = fileName ?? 'Invoice_${_safeFileName(invoiceData['invoiceNumber'])}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: safeName);
  }

  /// Save PDF locally
  static Future<File> save(
      Map<String, dynamic> invoiceData,
      Map<String, dynamic> companyData, {
        String? fileName,
        Uint8List? logoBytes,
      }) async {
    final pdfBytes = await generate(invoiceData, companyData, logoBytes: logoBytes);
    final output = await getApplicationDocumentsDirectory();
    final safeName = fileName ?? 'Invoice_${_safeFileName(invoiceData['invoiceNumber'])}.pdf';
    final file = File('${output.path}/$safeName');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  /// Core Generation Logic
  static Future<Uint8List> generate(
      Map<String, dynamic> data,
      Map<String, dynamic> comp, {
        Uint8List? logoBytes,
      }) async {
    final pdf = pw.Document(
      title: 'Tax Invoice - ${data['invoiceNumber'] ?? 'Draft'}',
      author: comp['companyName']?.toString() ?? 'ERP System',
      creator: 'QUIK ERP',
    );

    // Load fonts for ₹ symbol support
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: theme,
        header: (context) => _buildHeader(context, data, comp, logoBytes),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildItemTable(data),
          _buildHsnSummary(data),
          pw.SizedBox(height: 10),
          _buildTotalsSection(data),
          pw.SizedBox(height: 10),
          _buildAmountInWords(data),
          pw.SizedBox(height: 10),
          _buildPackingTransport(data),
          pw.SizedBox(height: 10),
          _buildPaymentAndTerms(data, comp),
          pw.SizedBox(height: 20),
          _buildSignatures(comp),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );

    return pdf.save();
  }

  /// --- HEADER: Company, Invoice Info, Parties ---
  static pw.Widget _buildHeader(
      pw.Context context,
      Map<String, dynamic> data,
      Map<String, dynamic> comp,
      Uint8List? logoBytes,
      ) {
    // Generate QR Code data (E-Invoice IRN or fallback to UPI)
    pw.Widget? qrWidget;
    String qrData = (data['irnQrCode'] ?? data['qrCode'] ?? '').toString();
    if (qrData.isEmpty) {
      final pay = data['paymentDetails'] is Map ? data['paymentDetails'] as Map : {};
      String upiId = _firstValid([pay['upiId'], comp['upiId']]);
      if (upiId.isNotEmpty) {
        final totals = data['totals'] is Map ? data['totals'] as Map : {};
        double gTotal = _parseNum(totals['grandTotal']);
        qrData = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent((comp['companyName'] ?? '').toString())}&am=$gTotal&cu=INR';
      }
    }
    if (qrData.isNotEmpty) {
      qrWidget = pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: qrData,
        width: 60,
        height: 60,
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Title
        pw.Center(
          child: pw.Text('TAX INVOICE',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
        ),
        pw.SizedBox(height: 10),

        // Company Details, Logo, & QR
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoBytes != null) ...[
                pw.Image(pw.MemoryImage(logoBytes), width: 70, height: 70, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 15),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text((comp['companyName'] ?? '').toString(),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 4),
                    pw.Text((comp['address'] ?? comp['billingAddress'] ?? '').toString(), style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('State: ${(comp['state'] ?? '').toString()}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('GSTIN: ${(comp['gst'] ?? '').toString()}  |  PAN: ${(comp['pan'] ?? '').toString()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Email: ${(comp['email'] ?? '').toString()}  |  Ph: ${(comp['phone'] ?? '').toString()}', style: const pw.TextStyle(fontSize: 9)),
                    if (_hasValue(comp['website']))
                      pw.Text('Web: ${comp['website']}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              if (qrWidget != null) ...[
                pw.SizedBox(width: 15),
                qrWidget,
              ]
            ],
          ),
        ),

        // Invoice Meta Data Grid
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              right: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              bottom: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: _buildGridCell('Invoice No.', (data['invoiceNumber'] ?? '').toString(), isBold: true),
              ),
              pw.Expanded(
                child: _buildGridCell('Invoice Date', _formatDate(data['invoiceDate'])),
              ),
              pw.Expanded(
                child: _buildGridCell('Place of Supply', (data['placeOfSupply'] ?? '').toString()),
              ),
              pw.Expanded(
                child: _buildGridCell('Reverse Charge', (data['reverseCharge'] == true || data['reverseCharge'] == 'true') ? 'YES' : 'NO'),
              ),
            ],
          ),
        ),

        // Compliance & E-Way Bill
        if (_hasValue(data['ewayBillNumber']) || _hasValue(data['irn']))
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                right: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                bottom: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            child: pw.Row(
              children: [
                if (_hasValue(data['ewayBillNumber']))
                  pw.Expanded(child: _buildGridCell('E-Way Bill No.', data['ewayBillNumber'].toString())),
                if (_hasValue(data['ewayBillDate']))
                  pw.Expanded(child: _buildGridCell('E-Way Bill Date', _formatDate(data['ewayBillDate']))),
                if (_hasValue(data['irn']))
                  pw.Expanded(flex: 2, child: _buildGridCell('IRN', data['irn'].toString())),
              ],
            ),
          ),

        // References Section
        if (_hasSalesReferences(data))
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                right: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                bottom: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            child: pw.Row(
              children: [
                if (_hasValue(data['salesReferences']?['salesOrderNumber']))
                  pw.Expanded(child: _buildGridCell('Sales Order No.', data['salesReferences']['salesOrderNumber'].toString())),
                if (_hasValue(data['salesReferences']?['quotationNumber']))
                  pw.Expanded(child: _buildGridCell('Quotation No.', data['salesReferences']['quotationNumber'].toString())),
                if (_hasValue(data['salesReferences']?['customerReference']))
                  pw.Expanded(child: _buildGridCell('Customer Ref.', data['salesReferences']['customerReference'].toString())),
              ],
            ),
          ),

        // Bill To & Ship To
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                    right: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                    bottom: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Billed To:', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text((data['billToName'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text((data['billToAddress'] ?? '').toString(), style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('State: ${(data['billToState'] ?? '').toString()} (${(data['billToStateCode'] ?? '').toString()})', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('GSTIN: ${(data['billToGstin'] ?? '').toString()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    if (_hasValue(data['billToContactPerson']))
                      pw.Text('Contact: ${data['billToContactPerson']} | ${data['billToMobile'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    right: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                    bottom: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Shipped To:', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text((data['shipToName'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text((data['shipToAddress'] ?? '').toString(), style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('State: ${(data['shipToState'] ?? '').toString()} (${(data['shipToStateCode'] ?? '').toString()})', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('GSTIN: ${(data['shipToGstin'] ?? '').toString()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    if (_hasValue(data['shipToContactPerson']))
                      pw.Text('Contact: ${data['shipToContactPerson']} | ${data['shipToMobile'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// --- ITEM TABLE ---
  static pw.Widget _buildItemTable(Map<String, dynamic> data) {
    final List<dynamic> items = (data['items'] as List<dynamic>?) ?? [];
    final bool isInterState = data['isInterState'] == true || data['isInterState'] == 'true';

    final headers = [
      'Sr.',
      'Description of Goods',
      'HSN/SAC',
      'Qty',
      'UOM',
      'Rate',
      'Taxable Amt',
      'GST%',
      isInterState ? 'IGST Amt' : 'CGST+SGST',
      'Total Amt'
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.8),
        1: pw.FlexColumnWidth(4.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.5),
        6: pw.FlexColumnWidth(1.8),
        7: pw.FlexColumnWidth(1.0),
        8: pw.FlexColumnWidth(1.8),
        9: pw.FlexColumnWidth(2.0),
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          )).toList(),
        ),

        // Table Rows (Auto handles page breaks internally)
        for (int i = 0; i < items.length; i++)
          pw.TableRow(
            children: [
              _buildTableCell('${i + 1}', align: pw.TextAlign.center),
              _buildProductCell(items[i] is Map ? items[i] as Map<String, dynamic> : {}),
              _buildTableCell((items[i]['hsnCode'] ?? '').toString(), align: pw.TextAlign.center),
              _buildTableCell(_formatNum(items[i]['quantity']), align: pw.TextAlign.center),
              _buildTableCell((items[i]['uom'] ?? 'Nos.').toString(), align: pw.TextAlign.center),
              _buildTableCell(_formatNum(items[i]['rate']), align: pw.TextAlign.right),
              _buildTableCell(_formatNum(items[i]['taxableAmount']), align: pw.TextAlign.right),
              _buildTableCell('${_formatNum(items[i]['gstPercentage'])}%', align: pw.TextAlign.center),
              _buildTableCell(isInterState
                  ? _formatNum(items[i]['igstAmount'])
                  : '${_formatNum(items[i]['cgstAmount'])}\n${_formatNum(items[i]['sgstAmount'])}', align: pw.TextAlign.right),
              _buildTableCell(_formatNum(items[i]['totalAmount']), align: pw.TextAlign.right, isBold: true),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildProductCell(Map<String, dynamic> item) {
    // Hardened: Resolve Scope Of Supply and Included Products safely
    String scope = (item['scopeOfSupply'] ?? '').toString().trim();
    if (scope.isEmpty && item['includedProducts'] is List) {
      final List incl = item['includedProducts'] as List;
      scope = incl.map((e) {
        if (e is Map) return '${e['qty'] ?? 1} ${e['uom'] ?? ''} ${e['productName'] ?? ''}'.trim();
        return e.toString();
      }).where((e) => e.isNotEmpty).join('\n');
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text((item['productName'] ?? '').toString(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          if (_hasValue(item['description'])) ...[
            pw.SizedBox(height: 2),
            pw.Text(item['description'].toString(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800), softWrap: true),
          ],
          if (_hasValue(item['sku']) || _hasValue(item['itemCode'])) ...[
            pw.SizedBox(height: 4),
            pw.Text('SKU: ${item['sku'] ?? 'N/A'} | Code: ${item['itemCode'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          ],
          // Hardened: Display Machine Serial Number and Warranty on separate lines
          if (_hasValue(item['machineSerialNo'])) ...[
            pw.SizedBox(height: 4),
            pw.Text('S/N: ${item['machineSerialNo']}', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          ],
          if (_hasValue(item['warrantyPeriod'])) ...[
            pw.SizedBox(height: 2),
            pw.Text('Warranty: ${item['warrantyPeriod']}', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          ],
          if (scope.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Scope of Supply / Included:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            // Soft wrap ensures very long scopes don't overflow the table cell horizontally
            pw.Text(scope, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800), softWrap: true),
          ],
        ],
      ),
    );
  }

  /// --- HSN SUMMARY TABLE ---
  static pw.Widget _buildHsnSummary(Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>?) ?? [];
    if (items.isEmpty) return pw.SizedBox();

    Map<String, Map<String, double>> hsnMap = {};
    bool hasHsn = false;

    for (var rawItem in items) {
      if (rawItem is! Map) continue;
      String hsn = (rawItem['hsnCode'] ?? '').toString().trim();
      if (hsn.isEmpty) continue;
      hasHsn = true;

      if (!hsnMap.containsKey(hsn)) {
        hsnMap[hsn] = {'taxable': 0.0, 'cgst': 0.0, 'sgst': 0.0, 'igst': 0.0, 'totalTax': 0.0};
      }

      double c = _parseNum(rawItem['cgstAmount']);
      double s = _parseNum(rawItem['sgstAmount']);
      double i = _parseNum(rawItem['igstAmount']);

      // Hardened: GST Fallback calculation
      double totalGst = _parseNum(rawItem['gstAmount']);
      if (totalGst == 0) totalGst = c + s + i;

      hsnMap[hsn]!['taxable'] = hsnMap[hsn]!['taxable']! + _parseNum(rawItem['taxableAmount']);
      hsnMap[hsn]!['cgst'] = hsnMap[hsn]!['cgst']! + c;
      hsnMap[hsn]!['sgst'] = hsnMap[hsn]!['sgst']! + s;
      hsnMap[hsn]!['igst'] = hsnMap[hsn]!['igst']! + i;
      hsnMap[hsn]!['totalTax'] = hsnMap[hsn]!['totalTax']! + totalGst;
    }

    if (!hasHsn) return pw.SizedBox();

    final isInterState = data['isInterState'] == true || data['isInterState'] == 'true';

    return pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('HSN / SAC Summary', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.SizedBox(height: 4),
              pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _buildTableCell('HSN/SAC', align: pw.TextAlign.center, isBold: true),
                        _buildTableCell('Taxable Value', align: pw.TextAlign.right, isBold: true),
                        if (!isInterState) ...[
                          _buildTableCell('CGST', align: pw.TextAlign.right, isBold: true),
                          _buildTableCell('SGST', align: pw.TextAlign.right, isBold: true),
                        ],
                        if (isInterState)
                          _buildTableCell('IGST', align: pw.TextAlign.right, isBold: true),
                        _buildTableCell('Total Tax', align: pw.TextAlign.right, isBold: true),
                      ],
                    ),
                    ...hsnMap.entries.map((e) {
                      return pw.TableRow(
                          children: [
                            _buildTableCell(e.key, align: pw.TextAlign.center),
                            _buildTableCell(_formatNum(e.value['taxable']), align: pw.TextAlign.right),
                            if (!isInterState) ...[
                              _buildTableCell(_formatNum(e.value['cgst']), align: pw.TextAlign.right),
                              _buildTableCell(_formatNum(e.value['sgst']), align: pw.TextAlign.right),
                            ],
                            if (isInterState)
                              _buildTableCell(_formatNum(e.value['igst']), align: pw.TextAlign.right),
                            _buildTableCell(_formatNum(e.value['totalTax']), align: pw.TextAlign.right),
                          ]
                      );
                    }),
                  ]
              )
            ]
        )
    );
  }

  /// --- TOTALS SECTION ---
  static pw.Widget _buildTotalsSection(Map<String, dynamic> data) {
    final totals = (data['totals'] is Map) ? data['totals'] as Map<String, dynamic> : {};

    // Hardened: GST Fallback globally
    double computedGst = _parseNum(totals['totalGst']);
    if (computedGst == 0) {
      computedGst = _parseNum(totals['totalCgst']) + _parseNum(totals['totalSgst']) + _parseNum(totals['totalIgst']);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: GST Summary
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Tax Summary', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Divider(color: PdfColors.grey300),
                _buildSummaryRow('Total Taxable Value', _parseNum(totals['totalTaxable'])),
                if (_parseNum(totals['totalCgst']) > 0) _buildSummaryRow('Total CGST', _parseNum(totals['totalCgst'])),
                if (_parseNum(totals['totalSgst']) > 0) _buildSummaryRow('Total SGST', _parseNum(totals['totalSgst'])),
                if (_parseNum(totals['totalIgst']) > 0) _buildSummaryRow('Total IGST', _parseNum(totals['totalIgst'])),
                pw.Divider(color: PdfColors.grey300),
                _buildSummaryRow('Total Tax Amount', computedGst, isBold: true),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        // Right: Grand Totals
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5), color: PdfColors.grey50),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSummaryRow('Total Item Value', _parseNum(totals['totalTaxable']) + computedGst),
                if (_parseNum(totals['freight']) > 0) _buildSummaryRow('Freight Charges', _parseNum(totals['freight'])),
                if (_parseNum(totals['packing']) > 0) _buildSummaryRow('Packing Charges', _parseNum(totals['packing'])),
                if (_parseNum(totals['otherCharges']) > 0) _buildSummaryRow('Other Charges', _parseNum(totals['otherCharges'])),
                _buildSummaryRow('Round Off', _parseNum(totals['roundOff'])),
                pw.Divider(color: PdfColors.grey400),
                _buildSummaryRow('GRAND TOTAL', _parseNum(totals['grandTotal']), isBold: true, size: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildAmountInWords(Map<String, dynamic> data) {
    final totals = (data['totals'] is Map) ? data['totals'] as Map<String, dynamic> : {};
    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Row(
          children: [
            pw.Text('Amount in Words: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text((totals['amountInWords'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          ],
        )
    );
  }

  /// --- PACKING & TRANSPORT ---
  static pw.Widget _buildPackingTransport(Map<String, dynamic> data) {
    final pack = (data['packingDetails'] is Map) ? data['packingDetails'] as Map<String, dynamic> : {};
    final trans = (data['transportDetails'] is Map) ? data['transportDetails'] as Map<String, dynamic> : {};

    if (!_hasValue(pack['noOfPackages']) && !_hasValue(trans['transporterName']) && !_hasValue(trans['lrNumber'])) {
      return pw.SizedBox(); // Skip if empty
    }

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border(right: const pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Packing Details', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  _buildMiniRow('No of Packages:', pack['noOfPackages']),
                  _buildMiniRow('Package Type:', pack['packageType']),
                  _buildMiniRow('Gross Weight:', pack['grossWeight']),
                  _buildMiniRow('Net Weight:', pack['netWeight']),
                  _buildMiniRow('Dimensions:', pack['dimensions']),
                ],
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Transport Details', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  _buildMiniRow('Transporter:', trans['transporterName']),
                  _buildMiniRow('LR Number:', trans['lrNumber']),
                  _buildMiniRow('LR Date:', _formatDate(trans['lrDate'])),
                  _buildMiniRow('Vehicle No:', trans['vehicleNumber']),
                  _buildMiniRow('Transport Mode:', trans['transportMode']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// --- PAYMENT & TERMS ---
  static pw.Widget _buildPaymentAndTerms(Map<String, dynamic> data, Map<String, dynamic> comp) {
    final pay = (data['paymentDetails'] is Map) ? data['paymentDetails'] as Map<String, dynamic> : {};
    String tnc = (data['termsAndConditions'] ?? '').toString();

    // Auto-numbering for terms if needed
    if (tnc.isNotEmpty && !tnc.trim().startsWith(RegExp(r'\d+\.'))) {
      final lines = tnc.split('\n').where((l) => l.trim().isNotEmpty).toList();
      tnc = List.generate(lines.length, (i) => "${i + 1}. ${lines[i].trim()}").join('\n');
    }

    // Hardened: Bank Details Fallbacks
    String bankName = _firstValid([pay['bankName'], comp['bankName']]);
    String accNo = _firstValid([pay['accountNumber'], comp['accountNumber']]);
    String ifsc = _firstValid([pay['ifsc'], comp['ifscCode'], comp['ifsc']]);
    String branch = _firstValid([pay['branch'], comp['branch']]);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Terms & Conditions', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(tnc.isEmpty ? 'As per standard company policy.' : tnc, style: const pw.TextStyle(fontSize: 8)),
                if (_hasValue(data['remarks'])) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('Remarks:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(data['remarks'].toString(), style: const pw.TextStyle(fontSize: 8)),
                ]
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bank & Payment Details', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                _buildMiniRow('Bank Name:', bankName),
                _buildMiniRow('A/C Number:', accNo),
                _buildMiniRow('IFSC Code:', ifsc),
                _buildMiniRow('Branch:', branch),
                pw.SizedBox(height: 4),
                _buildMiniRow('Payment Terms:', pay['terms']),
                _buildMiniRow('Payment Mode:', pay['mode']),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// --- SIGNATURES ---
  static pw.Widget _buildSignatures(Map<String, dynamic> comp) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 40),
              pw.Text('_________________________', style: const pw.TextStyle(color: PdfColors.grey500)),
              pw.SizedBox(height: 4),
              pw.Text('Receiver\'s Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]
        ),
        pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('For ${(comp['companyName'] ?? '').toString()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 40),
              pw.Text('_________________________', style: const pw.TextStyle(color: PdfColors.grey500)),
              pw.SizedBox(height: 4),
              pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]
        ),
      ],
    );
  }

  /// --- FOOTER ---
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by QUIK ERP', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  /// --- HELPERS & NUM/DATE PARSERS ---

  static String _firstValid(List<dynamic> values) {
    for (var v in values) {
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  static pw.Widget _buildGridCell(String label, String value, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border(right: const pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(value.isEmpty ? '-' : value, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, double amount, {bool isBold = false, double size = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: size, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('₹${_formatNum(amount)}', style: pw.TextStyle(fontSize: size, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static pw.Widget _buildMiniRow(String label, dynamic value) {
    if (!_hasValue(value)) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 70, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))),
          pw.Expanded(child: pw.Text(value.toString(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }

  static bool _hasValue(dynamic value) => value != null && value.toString().trim().isNotEmpty && value.toString() != 'null';

  static bool _hasSalesReferences(Map<String, dynamic> data) {
    final ref = (data['salesReferences'] is Map) ? data['salesReferences'] as Map<String, dynamic> : {};
    return _hasValue(ref['quotationNumber']) || _hasValue(ref['salesOrderNumber']) || _hasValue(ref['customerReference']);
  }

  // Hardened: Handles Strings, DateTimes, and Firestore Timestamps natively
  static String _formatDate(dynamic dateVal) {
    if (!_hasValue(dateVal)) return '';
    try {
      DateTime? date;
      if (dateVal is DateTime) {
        date = dateVal;
      } else if (dateVal.runtimeType.toString() == 'Timestamp') {
        date = (dateVal as dynamic).toDate();
      } else if (dateVal is Map && dateVal.containsKey('_seconds')) {
        date = DateTime.fromMillisecondsSinceEpoch(dateVal['_seconds'] * 1000);
      } else {
        date = DateTime.tryParse(dateVal.toString());
      }
      if (date != null) return DateFormat('dd-MM-yyyy').format(date);
      return dateVal.toString();
    } catch (_) {
      return dateVal.toString();
    }
  }

  // Hardened: Total num safety
  static double _parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
    return 0.0;
  }

  static String _formatNum(dynamic number) {
    final numVal = _parseNum(number);
    return NumberFormat('#,##0.00', 'en_IN').format(numVal);
  }
}

/// ------------------------------------------------------------------------
/// PDF PREVIEW SCREEN WIDGET
/// ------------------------------------------------------------------------
class TaxInvoicePdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  final Map<String, dynamic> companyData;
  final Uint8List? logoBytes;

  const TaxInvoicePdfPreviewScreen({
    super.key,
    required this.invoiceData,
    required this.companyData,
    this.logoBytes,
  });

  @override
  Widget build(BuildContext context) {
    final invNumber = InvoicePdfGenerator._safeFileName(invoiceData['invoiceNumber']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Preview - $invNumber'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share PDF',
            onPressed: () => InvoicePdfGenerator.share(invoiceData, companyData, logoBytes: logoBytes),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (format) => InvoicePdfGenerator.generate(invoiceData, companyData, logoBytes: logoBytes),
        pdfFileName: 'Invoice_$invNumber.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: PdfPageFormat.a4,
        previewPageMargin: const EdgeInsets.all(12),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
        ),
      ),
    );
  }
}