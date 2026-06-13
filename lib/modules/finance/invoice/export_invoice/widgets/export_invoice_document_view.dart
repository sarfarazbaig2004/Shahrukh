import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/export_invoice_model.dart';

class ExportInvoiceDocumentView extends StatelessWidget {
  final ExportInvoiceModel invoice;

  const ExportInvoiceDocumentView({super.key, required this.invoice});

  // ================= MEMORY CACHE =================

  // Cache to prevent redundant network calls and endless retries on failed URLs
  static final Map<String, pw.ImageProvider?> _logoCache = {};

  // Cache to prevent redundant Firestore document reads for company data
  static final Map<String, Map<String, dynamic>?> _companyCache = {};

  // Shared formatter to prevent continuous reallocation during layout rendering
  static final NumberFormat _numFormatter = NumberFormat('#,##0.00', 'en_US');

  // ================= TYPOGRAPHY & COLORS =================

  static const _primaryColor = PdfColor.fromInt(0xFF1A3A52);
  static const _textDark = PdfColor.fromInt(0xFF111827);
  static const _textLight = PdfColor.fromInt(0xFF4B5563);
  static const _borderColor = PdfColor.fromInt(0xFFD1D5DB);
  static const _bgLight = PdfColor.fromInt(0xFFF3F4F6);

  // ================= UTILITIES & VALIDATION =================

  String _currency(double value) {
    String code = invoice.currency.toUpperCase();
    String symbol = code;

    if (code == 'USD') {
      symbol = '\$';
    } else if (code == 'INR') {
      symbol = '₹';
    } else if (code == 'EUR') {
      symbol = '€';
    } else if (code == 'GBP') {
      symbol = '£';
    }

    return '$symbol ${_numFormatter.format(value)}';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Not Available';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  String _formatQty(double qty, String unit) {
    String formattedQty = qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
    return '$formattedQty ${unit.toUpperCase()}';
  }

  String _validateDestination(String country) {
    if (country.trim().isEmpty) return 'Not Available';
    if (country.trim().toLowerCase() == 'india') {
      return 'INVALID (Must be outside India)';
    }
    return country;
  }

  String _validatePort(String port) {
    if (port.trim().isEmpty) return 'Not Available';
    return port;
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';
    const units = [
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
    const tens = [
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

    String convertDigit(int n) {
      if (n < 20) {
        return units[n];
      }
      if (n < 100) {
        return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${units[n % 10]}' : ''}';
      }
      if (n < 1000) {
        return '${units[n ~/ 100]} Hundred${n % 100 != 0 ? ' and ${convertDigit(n % 100)}' : ''}';
      }
      if (n < 1000000) {
        return '${convertDigit(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${convertDigit(n % 1000)}' : ''}';
      }
      if (n < 1000000000) {
        return '${convertDigit(n ~/ 1000000)} Million${n % 1000000 != 0 ? ' ${convertDigit(n % 1000000)}' : ''}';
      }
      return '${convertDigit(n ~/ 1000000000)} Billion${n % 1000000000 != 0 ? ' ${convertDigit(n % 1000000000)}' : ''}';
    }

    return convertDigit(number).trim();
  }

  String _amountInWordsWithCents(double amount, String currencyCode) {
    int integerPart = amount.floor();
    int fractionalPart = ((amount - integerPart) * 100).round();
    String intWords = _convertNumberToWords(integerPart);

    String currencyName = currencyCode.toUpperCase();
    if (currencyName == 'USD') {
      currencyName = 'US Dollars';
    } else if (currencyName == 'INR') {
      currencyName = 'Indian Rupees';
    } else if (currencyName == 'EUR') {
      currencyName = 'Euros';
    } else if (currencyName == 'GBP') {
      currencyName = 'Pounds Sterling';
    }

    String fractionStr = fractionalPart.toString().padLeft(2, '0');
    return '$currencyName $intWords and $fractionStr/100 Only';
  }

  bool _isSameParty(Party a, Party b) {
    return a.name.trim().toLowerCase() == b.name.trim().toLowerCase() &&
        a.address.trim().toLowerCase() == b.address.trim().toLowerCase();
  }

  // ================= DATA FETCHERS =================

  Future<Map<String, dynamic>?> _fetchCompanyData() async {
    if (_companyCache.containsKey(invoice.companyId)) {
      return _companyCache[invoice.companyId];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(invoice.companyId)
          .get();

      final data = doc.data();
      _companyCache[invoice.companyId] = data;
      return data;
    } catch (e) {
      debugPrint('Company fetch error: $e');
      _companyCache[invoice.companyId] =
          null; // Cache failure to prevent endless loops
      return null;
    }
  }

  Future<pw.ImageProvider?> _fetchAndCacheLogo() async {
    if (_logoCache.containsKey(invoice.companyId)) {
      return _logoCache[invoice.companyId];
    }

    try {
      final data = await _fetchCompanyData(); // Reusing the centralized fetcher
      if (data != null) {
        final logoUrl = data['logoUrl'] ?? data['logo'];
        if (logoUrl != null && logoUrl.toString().trim().isNotEmpty) {
          final provider = await networkImage(logoUrl.toString().trim());
          _logoCache[invoice.companyId] = provider;
          return provider;
        }
      }
      _logoCache[invoice.companyId] = null; // Explicitly cache missing state
    } catch (e) {
      debugPrint('Export Invoice PDF: Logo fetch safely ignored - $e');
      _logoCache[invoice.companyId] = null;
    }
    return null;
  }

  // ================= PDF COMPACT WIDGET HELPERS =================

  pw.Widget _metaRow(String label, String value, {bool boldValue = true}) {
    if (value.isEmpty || value == '0' || value == '0.0') {
      value = 'Not Available';
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7.5, color: _textLight),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                color: _textDark,
                fontWeight: boldValue
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoBlock(String title, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 7.5, color: _textLight)),
        pw.SizedBox(height: 1),
        pw.Text(
          value.isEmpty ? 'Not Available' : value,
          style: pw.TextStyle(
            fontSize: 8,
            color: _textDark,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPartyBlock(String title, Party party) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          party.name.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _textDark,
          ),
        ),
        pw.SizedBox(height: 1),
        if (party.address.isNotEmpty)
          pw.Text(
            party.address,
            style: const pw.TextStyle(
              fontSize: 8,
              lineSpacing: 1.1,
              color: _textDark,
            ),
          ),
        if (party.country.isNotEmpty)
          pw.Text(
            party.country,
            style: const pw.TextStyle(fontSize: 8, color: _textDark),
          ),
        pw.SizedBox(height: 2),
        if (party.contactPerson.isNotEmpty)
          pw.Text(
            'Attn: ${party.contactPerson}',
            style: const pw.TextStyle(fontSize: 8, color: _textDark),
          ),
        if (party.email.isNotEmpty)
          pw.Text(
            'Email: ${party.email}',
            style: const pw.TextStyle(fontSize: 8, color: _textDark),
          ),
        if (party.phone.isNotEmpty)
          pw.Text(
            'Phone: ${party.phone}',
            style: const pw.TextStyle(fontSize: 8, color: _textDark),
          ),
      ],
    );
  }

  pw.Widget _buildSummaryLine(
    String label,
    double amount, {
    String? customValue,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: _textDark),
          ),
          pw.Text(
            customValue ?? _currency(amount),
            style: const pw.TextStyle(fontSize: 8, color: _textDark),
          ),
        ],
      ),
    );
  }

  // ================= COMPACT PDF SECTIONS =================

  pw.Widget _buildHeader(
    pw.ImageProvider? logoProvider,
    Map<String, dynamic>? companyData,
  ) {
    final isLUT = invoice.exportDetails.exportType == 'WITH_LUT';

    // Safely resolve company details with fallbacks to the invoice supplier
    final String gstin = companyData?['gstin']?.toString().isNotEmpty == true
        ? companyData!['gstin']
        : invoice.supplier.gstin;

    final String rawPan = companyData?['pan']?.toString().isNotEmpty == true
        ? companyData!['pan']
        : invoice.supplier.pan;
    final String pan = rawPan.isNotEmpty ? rawPan : 'Not Available';

    final String iec = companyData?['iec']?.toString().isNotEmpty == true
        ? companyData!['iec']
        : (companyData?['iecCode']?.toString().isNotEmpty == true
              ? companyData!['iecCode']
              : invoice.supplier.iec);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoProvider != null) ...[
                pw.Container(
                  height: 40,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 8),
              ],
              pw.Text(
                invoice.supplier.name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                invoice.supplier.address,
                style: const pw.TextStyle(
                  fontSize: 8,
                  lineSpacing: 1.1,
                  color: _textDark,
                ),
              ),
              pw.Text(
                '${invoice.supplier.state} ${invoice.supplier.country}',
                style: const pw.TextStyle(fontSize: 8, color: _textDark),
              ),
              pw.SizedBox(height: 4),
              _metaRow('GSTIN:', gstin),
              _metaRow('PAN:', pan),
              _metaRow('IEC:', iec),
              _metaRow('AD Code:', invoice.exportDetails.adCode),
            ],
          ),
        ),

        pw.SizedBox(width: 16),

        pw.Expanded(
          flex: 4,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _bgLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: _borderColor, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EXPORT INVOICE',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                _metaRow('Invoice Number:', invoice.invoiceNumber),
                _metaRow('Invoice Date:', _formatDate(invoice.invoiceDate)),
                _metaRow('Due Date:', _formatDate(invoice.dueDate)),

                // Export Type Highlighted Badge
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 75,
                        child: pw.Text(
                          'Export Type:',
                          style: pw.TextStyle(fontSize: 7.5, color: _textLight),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: pw.BoxDecoration(
                              color: isLUT
                                  ? PdfColors.green100
                                  : PdfColors.blue100,
                              borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(2),
                              ),
                            ),
                            child: pw.Text(
                              isLUT ? 'LUT (No IGST)' : 'IGST Applied',
                              style: pw.TextStyle(
                                fontSize: 7,
                                color: isLUT
                                    ? PdfColors.green800
                                    : PdfColors.blue800,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isLUT)
                  _metaRow(
                    'LUT ARN:',
                    invoice.exportDetails.lutNumber.isNotEmpty
                        ? 'ARN - ${invoice.exportDetails.lutNumber}'
                        : 'Not Available',
                  ),
                _metaRow('Place of Supply:', invoice.placeOfSupply),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildParties() {
    bool sameParty = _isSameParty(invoice.buyer, invoice.consignee);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _buildPartyBlock(
              sameParty ? 'BUYER & CONSIGNEE (SAME)' : 'BUYER (BILL TO)',
              invoice.buyer,
            ),
          ),
          if (!sameParty) ...[
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _buildPartyBlock('CONSIGNEE (SHIP TO)', invoice.consignee),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildShippingDetails() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildInfoBlock(
                  'Pre-Carriage By',
                  invoice.logistics.preCarriageBy,
                ),
              ),
              pw.Expanded(
                child: _buildInfoBlock(
                  'Vessel / Flight No.',
                  invoice.logistics.vesselOrFlight,
                ),
              ),
              pw.Expanded(
                child: _buildInfoBlock(
                  'Port of Loading',
                  _validatePort(invoice.exportDetails.portOfLoading),
                ),
              ),
              pw.Expanded(
                child: _buildInfoBlock(
                  'Port of Discharge',
                  _validatePort(invoice.exportDetails.portOfDischarge),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildInfoBlock(
                  'Country of Origin',
                  invoice.exportDetails.countryOfOrigin,
                ),
              ),
              pw.Expanded(
                child: _buildInfoBlock(
                  'Final Destination',
                  _validateDestination(
                    invoice.exportDetails.countryOfDestination,
                  ),
                ),
              ),
              pw.Expanded(
                child: _buildInfoBlock(
                  'Shipping Bill No.',
                  invoice.logistics.shippingBillNo,
                ),
              ),
              pw.Expanded(
                child: _buildInfoBlock(
                  'Shipping Bill Date',
                  _formatDate(invoice.logistics.shippingBillDate),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: _borderColor, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: _buildInfoBlock(
                  'Marks & Nos / Container No.',
                  invoice.logistics.marksAndNos,
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: _buildInfoBlock(
                  'Packages',
                  '${invoice.logistics.numberOfPackages} Pkgs',
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: _buildInfoBlock(
                  'Gross Weight',
                  '${invoice.logistics.grossWeight} Kgs',
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: _buildInfoBlock(
                  'Net Weight',
                  '${invoice.logistics.netWeight} Kgs',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable() {
    final headers = const [
      'S.No.',
      'Description of Goods',
      'HSN',
      'Qty',
      'Rate',
      'Amount',
    ];

    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: _bgLight,
            border: pw.Border(
              bottom: pw.BorderSide(color: _primaryColor, width: 1),
            ),
          ),
          children: headers.map((h) {
            bool isFinancial = h == 'Rate' || h == 'Amount';
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 4,
              ),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _textDark,
                ),
                textAlign: isFinancial
                    ? pw.TextAlign.right
                    : (h == 'Qty' || h == 'HSN' || h == 'S.No.'
                          ? pw.TextAlign.center
                          : pw.TextAlign.left),
              ),
            );
          }).toList(),
        ),

        ...invoice.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderColor, width: 0.5),
              ),
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Text(
                  '${index + 1}',
                  style: const pw.TextStyle(fontSize: 8, color: _textDark),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.name,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        item.description,
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: _textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Text(
                  item.hsnCode,
                  style: const pw.TextStyle(fontSize: 8, color: _textDark),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Text(
                  _formatQty(item.quantity, item.unit),
                  style: const pw.TextStyle(fontSize: 8, color: _textDark),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Text(
                  _currency(item.rate),
                  style: const pw.TextStyle(fontSize: 8, color: _textDark),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Text(
                  _currency(item.computedAmount),
                  style: const pw.TextStyle(fontSize: 8, color: _textDark),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildFinancialSummary() {
    final isLUT = invoice.exportDetails.exportType == 'WITH_LUT';
    final double totalReceived = invoice.amountReceived;

    final bool isOverpaid = invoice.amountOutstanding < -0.01;
    final double displayOutstanding = isOverpaid
        ? 0.0
        : invoice.amountOutstanding;
    final double excessAmount = isOverpaid
        ? invoice.amountOutstanding.abs()
        : 0.0;

    // Payment Status Logic
    PdfColor badgeBg = PdfColors.red100;
    PdfColor badgeText = PdfColors.red800;
    String statusStr = 'UNPAID';

    if (totalReceived >= invoice.totals.grandTotal - 0.01) {
      statusStr = 'PAID';
      badgeBg = PdfColors.green100;
      badgeText = PdfColors.green800;
    } else if (totalReceived > 0.01) {
      statusStr = 'PARTIALLY PAID';
      badgeBg = PdfColors.orange100;
      badgeText = PdfColors.orange800;
    }

    // Incoterm Freight & Insurance Logic
    final String incoterm = invoice.exportDetails.incoterm.toUpperCase();
    final bool hideFreight = incoterm == 'FOB';
    final bool hideInsurance = incoterm == 'FOB' || incoterm == 'CFR';

    // Safe Round-Off Calculation
    final double rawTotal =
        invoice.totals.subTotal +
        invoice.totals.freight +
        invoice.totals.insurance +
        invoice.totals.tax;
    final double computedRoundOff = invoice.totals.grandTotal - rawTotal;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Amount in Words & Exchange Rate Info
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Amount in Words:',
                  style: pw.TextStyle(fontSize: 7.5, color: _textLight),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  _amountInWordsWithCents(
                    invoice.totals.grandTotal,
                    invoice.currency,
                  ),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _textDark,
                  ),
                ),

                pw.SizedBox(height: 8),
                pw.Text(
                  'Exchange Rate: 1 ${invoice.currency.toUpperCase()} = INR ${invoice.exchangeRate.toStringAsFixed(2)}  |  Total Value: INR ${invoice.totals.grandTotalInr.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 7.5, color: _textDark),
                ),

                // Highlighted Reverse Charge compliance
                if (invoice.taxDetails.reverseCharge) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FFF7ED'),
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#F97316'),
                        width: 0.5,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Tax payable under Reverse Charge',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#C2410C'),
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          pw.SizedBox(width: 16),

          // Right: Totals Breakdown
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Payment Status',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _textLight,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        color: badgeBg,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Text(
                        statusStr,
                        style: pw.TextStyle(
                          color: badgeText,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                _buildSummaryLine('Subtotal', invoice.totals.subTotal),

                if (!hideFreight && invoice.totals.freight > 0)
                  _buildSummaryLine('Freight', invoice.totals.freight),

                if (!hideInsurance && invoice.totals.insurance > 0)
                  _buildSummaryLine('Insurance', invoice.totals.insurance),

                if (!isLUT && invoice.totals.tax > 0)
                  _buildSummaryLine('IGST', invoice.totals.tax),

                if (computedRoundOff.abs() > 0.001) ...[
                  _buildSummaryLine(
                    'Round Off',
                    computedRoundOff,
                    customValue:
                        '${computedRoundOff > 0 ? '+' : ''}${_currency(computedRoundOff.abs())}',
                  ),
                ],

                pw.SizedBox(height: 4),
                pw.Divider(color: _primaryColor, thickness: 0.5),
                pw.SizedBox(height: 4),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Grand Total',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    pw.Text(
                      _currency(invoice.totals.grandTotal),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),

                // Payments Breakdown Cleaned
                if (totalReceived > 0) ...[
                  pw.SizedBox(height: 4),
                  pw.Divider(color: _borderColor, thickness: 0.5),
                  pw.SizedBox(height: 4),

                  if (invoice.advanceAmount > 0)
                    _buildSummaryLine(
                      'Advance Received',
                      invoice.advanceAmount,
                    ),

                  if (totalReceived > invoice.advanceAmount)
                    _buildSummaryLine(
                      'Remaining Payment Received',
                      totalReceived - invoice.advanceAmount,
                    ),

                  _buildSummaryLine('Total Payments Received', totalReceived),

                  pw.SizedBox(height: 4),
                  pw.Divider(color: _borderColor, thickness: 0.5),
                  pw.SizedBox(height: 4),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Balance Due',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      pw.Text(
                        _currency(displayOutstanding),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),

                  if (isOverpaid) ...[
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Excess Received',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: _textLight,
                          ),
                        ),
                        pw.Text(
                          _currency(excessAmount),
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: _textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  pw.SizedBox(height: 4),
                  pw.Divider(color: _borderColor, thickness: 0.5),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Balance Due',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      pw.Text(
                        _currency(invoice.totals.grandTotal),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooterAndSignatures() {
    final isLUT = invoice.exportDetails.exportType == 'WITH_LUT';
    final declarationText = invoice.declaration.isNotEmpty
        ? invoice.declaration
        : 'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct. ${isLUT ? 'Export under LUT - IGST not applicable.' : 'Export on payment of IGST.'}';

    final String qrData = jsonEncode({
      "invoiceNo": invoice.invoiceNumber,
      "date": _formatDate(invoice.invoiceDate),
      "amount": invoice.totals.grandTotal,
      "currency": invoice.currency,
      "companyName": invoice.supplier.name,
      "customerName": invoice.buyer.name,
    });

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left Column (Details & Declarations)
          pw.Expanded(
            flex: 7,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Col 1: Terms
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Payment & Delivery',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _metaRow(
                            'Terms:',
                            invoice.paymentTerms.isNotEmpty
                                ? invoice.paymentTerms
                                : invoice.paymentDetails.deliveryTerms,
                          ),
                          _metaRow(
                            'Mode:',
                            '${invoice.paymentDetails.paymentMode} (${invoice.currency})',
                          ),
                          if (invoice
                              .paymentDetails
                              .paymentReference
                              .isNotEmpty)
                            _metaRow(
                              'Ref:',
                              invoice.paymentDetails.paymentReference,
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    // Col 2: Bank
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Bank Details',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _metaRow('Bank:', invoice.paymentDetails.bankName),
                          _metaRow(
                            'A/C No:',
                            invoice.paymentDetails.accountNumber,
                          ),
                          _metaRow(
                            'IFSC / SWIFT:',
                            '${invoice.paymentDetails.ifsc} / ${invoice.paymentDetails.swiftCode}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Declaration:',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                pw.Text(
                  declarationText,
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: _textLight,
                    lineSpacing: 1.1,
                  ),
                ),
                if (invoice.notes.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Notes: ${invoice.notes}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: _textDark,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),

          pw.SizedBox(width: 16),

          // Right Column (Signature & QR)
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'For ${invoice.supplier.name.toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _textDark,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
                pw.SizedBox(height: 35),
                pw.Container(width: 130, height: 0.5, color: _textDark),
                pw.SizedBox(height: 2),
                pw.Text(
                  invoice.authorizedSignatory.isNotEmpty
                      ? invoice.authorizedSignatory
                      : 'Authorised Signatory',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: _textDark,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'This is a digitally generated document',
                  style: const pw.TextStyle(fontSize: 5, color: _textLight),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Scan to verify\ninvoice details',
                      style: const pw.TextStyle(fontSize: 6, color: _textLight),
                      textAlign: pw.TextAlign.right,
                    ),
                    pw.SizedBox(width: 4),
                    pw.SizedBox(
                      height: 35,
                      width: 35,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        drawText: false,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= MAIN PDF GENERATOR =================

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    // Both are fetched and cached at the top level
    final companyData = await _fetchCompanyData();
    final logoProvider = await _fetchAndCacheLogo();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topCenter,
            child: pw.Container(
              width: format.availableWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  _buildHeader(logoProvider, companyData),
                  pw.Divider(color: _borderColor, thickness: 0.5, height: 12),
                  _buildParties(),
                  _buildShippingDetails(),
                  _buildItemsTable(),
                  _buildFinancialSummary(),
                  _buildFooterAndSignatures(),
                ],
              ),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2A3D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Export Invoice Preview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: PdfPreview(
        build: _buildPdf,
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName:
            'Export_Invoice_${invoice.invoiceNumber.replaceAll('/', '_')}.pdf',
      ),
    );
  }
}
