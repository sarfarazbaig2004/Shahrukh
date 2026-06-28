import 'dart:typed_data';
import 'package:flutter/material.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Import models
import 'models/service_quotation_models.dart';

class ServiceQuotationPdfGenerator {
  // Brand Colors
  static const colorPrimary = PdfColor.fromInt(0xFF1E3A8A); // Blue-900
  static const textDark = PdfColor.fromInt(0xFF0F172A);
  static const textMuted = PdfColor.fromInt(0xFF64748B);
  static const borderLight = PdfColor.fromInt(0xFFE2E8F0);
  static const grandTotalBg = PdfColor.fromInt(0xFFEFF6FF);

  // Added Missing Constants
  static const rowEven = PdfColor.fromInt(0xFFF8FAFC);
  static const bgLight = PdfColor.fromInt(0xFFF8FAFC);

  // Section Colors
  static const colorIndigo = PdfColor.fromInt(0xFF3F51B5);
  static const colorOrange = PdfColor.fromInt(0xFFFF9800);
  static const colorTeal = PdfColor.fromInt(0xFF009688);
  static const colorGreen = PdfColor.fromInt(0xFF4CAF50);
  static const colorBlue = PdfColor.fromInt(0xFF2196F3);
  static const colorPurple = PdfColor.fromInt(0xFF9C27B0);
  static const colorPink = PdfColor.fromInt(0xFFE91E63);

  static Future<Uint8List> generateServiceQuotationPdf(
    Map<String, dynamic> quotation,
    List<QuotationLineItem> items,
  ) async {
    final pdf = pw.Document();

    // Font setup
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // Watermark logic
    final String status =
        quotation['status']?.toString().toUpperCase() ?? 'DRAFT';
    final String approvalStatus =
        quotation['approvalStatus']?.toString().toUpperCase() ?? '';
    final String watermarkText = approvalStatus == 'APPROVED'
        ? 'APPROVED'
        : (status == 'DRAFT' ? 'DRAFT' : '');

    pw.MemoryImage? logoImage;
    // Smart logo fallback
    final logoUrl =
        quotation['companyLogo']?.toString() ??
        quotation['companyLogoUrl']?.toString() ??
        quotation['logoUrl']?.toString();

    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Failed to load company logo: $e');
      }
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      buildBackground: (context) {
        if (watermarkText.isEmpty) return pw.SizedBox();
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.10,
              child: pw.Transform.rotate(
                angle: 0.785, // 45 degrees
                child: pw.Text(
                  watermarkText,
                  style: pw.TextStyle(
                    color: PdfColors.grey500,
                    fontSize: 90,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildHeader(quotation, logoImage),
        footer: (context) => _buildFooter(context, quotation),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildCustomerSection(quotation),
          pw.SizedBox(height: 12),

          if (quotation['subject']?.toString().isNotEmpty == true) ...[
            pw.Text(
              'Subject: ${quotation['subject']}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: textDark,
              ),
            ),
            pw.SizedBox(height: 12),
          ],

          _buildMachineSection(quotation),
          pw.SizedBox(height: 12),

          _buildUnifiedItemsTable(quotation, items),
          pw.SizedBox(height: 16),

          // Using MultiPage-safe Table layout instead of Row+Expanded
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FixedColumnWidth(16),
              2: const pw.FlexColumnWidth(4),
            },
            children: [
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.top,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [_buildAmountInWords(quotation)],
                  ),
                  pw.SizedBox(width: 16),
                  _buildGrandSummary(quotation),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          _buildTermsBoxes(quotation),
          pw.SizedBox(height: 20),

          _buildBankDetails(quotation),
          pw.SizedBox(height: 30),

          _buildSignatures(quotation),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    Map<String, dynamic> quotation,
    pw.MemoryImage? logoImage,
  ) {
    final companyDetails = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          (quotation['companyName']?.toString().toUpperCase() ??
              'COMPANY NAME'),
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: colorPrimary,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          quotation['companyAddress']?.toString() ?? '',
          style: const pw.TextStyle(fontSize: 8, color: textDark),
        ),
        pw.SizedBox(height: 2),
        pw.Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            if (quotation['companyPhone']?.toString().isNotEmpty == true)
              pw.Text(
                'Ph: ${quotation['companyPhone']}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            if (quotation['companyEmail']?.toString().isNotEmpty == true)
              pw.Text(
                'Email: ${quotation['companyEmail']}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            if (quotation['companyWebsite']?.toString().isNotEmpty == true)
              pw.Text(
                'Web: ${quotation['companyWebsite']}',
                style: const pw.TextStyle(fontSize: 8),
              ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            if (quotation['companyGst']?.toString().isNotEmpty == true)
              pw.Text(
                'GSTIN: ${quotation['companyGst']}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            if (quotation['companyPan']?.toString().isNotEmpty == true)
              pw.Text(
                'PAN: ${quotation['companyPan']}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            if (quotation['companyCin']?.toString().isNotEmpty == true)
              pw.Text(
                'CIN: ${quotation['companyCin']}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
          ],
        ),
      ],
    );

    final leftSide = logoImage != null
        ? pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(72),
              1: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    height: 60,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12),
                    child: companyDetails,
                  ),
                ],
              ),
            ],
          )
        : companyDetails;

    final rightSide = pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: borderLight),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'Quote No: ${quotation['quoteNumber'] ?? '-'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Rev No: ${quotation['version'] ?? '1'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Date: ${quotation['quoteDateStr'] ?? _formatDate(quotation['quoteDate'])}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Validity: ${_formatDate(quotation['nextFollowUpDate'] ?? quotation['quoteDate'])}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Replaced Row+Expanded with Table to prevent intrinsic sizing layout constraints violation inside MultiPage Header
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(7),
            1: const pw.FixedColumnWidth(16),
            2: const pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.top,
              children: [leftSide, pw.SizedBox(width: 16), rightSide],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text(
            'SERVICE QUOTATION',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: colorPrimary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: colorPrimary, thickness: 2),
      ],
    );
  }

  static pw.Widget _buildCustomerSection(Map<String, dynamic> quotation) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: borderLight),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      // Replaced Row+Expanded with Table
      child: pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FixedColumnWidth(16),
          2: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.top,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CUSTOMER DETAILS',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: colorPrimary,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    quotation['clientName']?.toString() ?? '',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    quotation['clientAddress']?.toString() ?? '',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(width: 16),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CONTACT INFO',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: colorPrimary,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (quotation['contactPerson']?.toString().isNotEmpty == true)
                    pw.Text(
                      'Attn: ${quotation['contactPerson']}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (quotation['clientMobile']?.toString().isNotEmpty == true)
                    pw.Text(
                      'Ph: ${quotation['clientMobile']}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (quotation['clientEmail']?.toString().isNotEmpty == true)
                    pw.Text(
                      'Email: ${quotation['clientEmail']}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (quotation['gstNo']?.toString().isNotEmpty == true)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        'GSTIN: ${quotation['gstNo']}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMachineSection(Map<String, dynamic> quotation) {
    final machines = quotation['machines'] as List? ?? [];
    if (machines.isEmpty) {
      machines.add({
        'model': quotation['machineModel'],
        'serial': quotation['serialNumber'],
        'warrantyStatus': quotation['warrantyStatus'],
      });
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: machines.map((m) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: bgLight,
            border: pw.Border.all(color: borderLight),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          // Replaced Row+Expanded with Table
          child: pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  _machineInfoBlock(
                    'Machine Model',
                    m['model'] ?? m['machineModel'] ?? '-',
                  ),
                  _machineInfoBlock(
                    'Serial Number',
                    m['serial'] ?? m['serialNumber'] ?? '-',
                  ),
                  _machineInfoBlock(
                    'Warranty Status',
                    m['warrantyStatus'] ?? '-',
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _machineInfoBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: textMuted,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.isNotEmpty ? value : '-',
          style: pw.TextStyle(
            fontSize: 10,
            color: textDark,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static PdfColor _getRowColor(String type) {
    switch (type.toLowerCase()) {
      case 'spare':
        return PdfColor.fromHex('#FFF7ED'); // Orange
      case 'accessory':
        return PdfColor.fromHex('#F0FDFA'); // Teal
      case 'consumable':
        return PdfColor.fromHex('#F0FDF4'); // Green
      case 'service charge':
        return PdfColor.fromHex('#EFF6FF'); // Blue
      case 'visit charge':
        return PdfColor.fromHex('#FAF5FF'); // Purple
      case 'other charge':
        return PdfColor.fromHex('#FDF2F8'); // Pink
      default:
        return PdfColors.white;
    }
  }

  static PdfColor _getTextColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'spare':
        return colorOrange;
      case 'accessory':
        return colorTeal;
      case 'consumable':
        return colorGreen;
      case 'service charge':
        return colorBlue;
      case 'visit charge':
        return colorPurple;
      case 'other charge':
        return colorPink;
      default:
        return textDark;
    }
  }

  static String _formatCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  static pw.Widget _buildUnifiedItemsTable(
    Map<String, dynamic> quotation,
    List<QuotationLineItem> items,
  ) {
    final headers = [
      '#',
      'Machine',
      'Type',
      'Description',
      'Qty',
      'Rate',
      'Amount',
    ];

    final rows = <pw.TableRow>[];
    int index = 1;

    pw.Widget getMachineColumn(dynamic itemJsonOrObject, bool isCharge) {
      if (isCharge) {
        return pw.Text(
          'General',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: textDark,
          ),
        );
      }

      String machineVal = '';
      String snVal = '';

      // Safe evaluation bypassing strict class limits if properties exist contextually
      try {
        machineVal =
            (itemJsonOrObject as dynamic).machineModel?.toString() ?? '';
      } catch (_) {}
      try {
        snVal = (itemJsonOrObject as dynamic).serialNumber?.toString() ?? '';
      } catch (_) {}

      // Fallback
      if (machineVal.isEmpty)
        machineVal = quotation['machineModel']?.toString() ?? 'General';
      if (snVal.isEmpty) snVal = quotation['serialNumber']?.toString() ?? '';

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            machineVal,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: textDark,
            ),
          ),
          if (snVal.isNotEmpty)
            pw.Text(
              'SN: $snVal',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
        ],
      );
    }

    // Process Line Items
    for (var item in items) {
      final isCharge = [
        'Service Charge',
        'Visit Charge',
        'Other Charge',
      ].contains(item.itemType);
      final qtyStr = item.qty
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.00$'), '');

      final isEven = index % 2 == 0;
      final bgColor = isCharge
          ? _getRowColor(item.itemType)
          : (isEven ? rowEven : PdfColors.white);

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(
                (index++).toString(),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: getMachineColumn(item, isCharge),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(
                item.itemType,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _getTextColorForType(item.itemType),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.itemName,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  if (item.partNo != null &&
                      item.partNo != '-' &&
                      item.partNo!.isNotEmpty)
                    pw.Text(
                      'PN : ${item.partNo}',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey700,
                      ),
                    ),
                  if (item.hsnCode != null &&
                      item.hsnCode != '-' &&
                      item.hsnCode!.isNotEmpty)
                    pw.Text(
                      'HSN : ${item.hsnCode}',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(qtyStr, style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  _formatCurrency(item.rate),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  _formatCurrency(item.amount),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Process Visit Charges
    final visitCharges = quotation['visitCharges'] as List? ?? [];
    for (var vc in visitCharges) {
      final desc = vc['description'] ?? vc['type'] ?? 'Visit Charge';
      final qtyStr = _parseDouble(
        vc['qty'] ?? vc['quantity'] ?? 1,
      ).toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
      final rateVal = _parseDouble(vc['rate'] ?? 0);
      final amtVal = _parseDouble(vc['amount'] ?? 0);

      final bgColor = _getRowColor('Visit Charge');

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(
                (index++).toString(),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(
                'General',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(
                'Visit Charge',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: colorPurple,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(
                desc.toString(),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Text(qtyStr, style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  _formatCurrency(rateVal),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  _formatCurrency(amtVal),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (rows.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'REQUIREMENT DETAILS',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: colorPrimary,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderLight),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.4), // #
            1: const pw.FlexColumnWidth(2.0), // Machine + SN
            2: const pw.FlexColumnWidth(1.5), // Type
            3: const pw.FlexColumnWidth(4.5), // Description
            4: const pw.FlexColumnWidth(0.6), // Qty
            5: const pw.FlexColumnWidth(1.4), // Rate
            6: const pw.FlexColumnWidth(1.6), // Amount
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: colorPrimary),
              children: headers.map((h) {
                final isRight = h == 'Rate' || h == 'Amount';
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: pw.Align(
                    alignment: isRight
                        ? pw.Alignment.centerRight
                        : pw.Alignment.centerLeft,
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            ...rows,
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAmountInWords(Map<String, dynamic> quotation) {
    final finalTotal = _parseDouble(
      quotation['finalTotal'] ?? quotation['grandTotal'],
    );
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bgLight,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: borderLight),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'AMOUNT IN WORDS',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: colorPrimary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Rupees ${_numberToWords(finalTotal.round())} Only',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildGrandSummary(Map<String, dynamic> quotation) {
    final subtotal = _parseDouble(
      quotation['subtotal'] ?? quotation['totalSubtotal'],
    );
    final discount = _parseDouble(
      quotation['discount'] ?? quotation['totalItemDiscount'],
    );
    final visitTotal = _parseDouble(quotation['totalVisitCharges']);
    final cgst = _parseDouble(quotation['totalCgst']);
    final sgst = _parseDouble(quotation['totalSgst']);
    final igst = _parseDouble(quotation['totalIgst']);
    final roundOff = _parseDouble(quotation['roundOff']);
    final finalTotal = _parseDouble(
      quotation['finalTotal'] ?? quotation['grandTotal'],
    );

    final taxableValue = _parseDouble(
      quotation['totalTaxableAmount'] ?? (subtotal + visitTotal - discount),
    );
    final isInterState = quotation['isInterState'] == true;

    final itemsTotal = subtotal;
    final chargesTotal = 0.0; // Covered in subtotal for this model

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderLight),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildTotalRow('Items Total', itemsTotal),
                if (chargesTotal > 0)
                  _buildTotalRow('Charges Total', chargesTotal),
                if (visitTotal > 0) _buildTotalRow('Visit Total', visitTotal),
                _buildTotalRow('Subtotal', subtotal + visitTotal),
                if (discount > 0) _buildTotalRow('Discount', -discount),
                pw.Divider(color: borderLight),
                _buildTotalRow('Taxable Amount', taxableValue, isBold: true),
                if (isInterState)
                  _buildTotalRow('IGST', igst)
                else ...[
                  _buildTotalRow('CGST', cgst),
                  _buildTotalRow('SGST', sgst),
                ],
                if (roundOff != 0) _buildTotalRow('Round Off', roundOff),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: const pw.BoxDecoration(color: colorPrimary),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GRAND TOTAL',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  _formatCurrency(finalTotal),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 15,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            _formatCurrency(amount),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermsBoxes(Map<String, dynamic> quotation) {
    final terms = quotation['dynamicTerms'] as List? ?? [];
    if (terms.isEmpty) return pw.SizedBox.shrink();

    final termRows = <pw.TableRow>[];
    for (int i = 0; i < terms.length; i += 2) {
      final t1 = terms[i];
      final t2 = (i + 1 < terms.length) ? terms[i + 1] : null;

      termRows.add(
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.top,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: _termBox(t1['title'], t1['value']),
            ),
            pw.SizedBox(width: 12),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: t2 != null
                  ? _termBox(t2['title'], t2['value'])
                  : pw.SizedBox(),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TERMS & CONDITIONS',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: colorPrimary,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FixedColumnWidth(12),
            2: const pw.FlexColumnWidth(1),
          },
          children: termRows,
        ),
      ],
    );
  }

  static pw.Widget _termBox(dynamic title, dynamic value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderLight),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title?.toString().toUpperCase() ?? 'TERM',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: textMuted,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value?.toString() ?? '',
            style: const pw.TextStyle(fontSize: 9, color: textDark),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBankDetails(Map<String, dynamic> quotation) {
    final bankDetails = quotation['companyBankDetails']?.toString() ?? '';
    if (bankDetails.isEmpty) return pw.SizedBox.shrink();

    final lines = bankDetails
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderLight),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BANK DETAILS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: colorPrimary,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 16,
            runSpacing: 4,
            children: lines.map((l) {
              final parts = l.split(':');
              if (parts.length < 2)
                return pw.Text(
                  l.trim(),
                  style: const pw.TextStyle(fontSize: 9),
                );
              return pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    '${parts[0].trim()}: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: textMuted,
                    ),
                  ),
                  pw.Text(
                    parts.sublist(1).join(':').trim(),
                    style: const pw.TextStyle(fontSize: 9, color: textDark),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatures(Map<String, dynamic> quotation) {
    final signName = quotation['signatureName']?.toString() ?? '';
    final signDesignation =
        quotation['signatureDesignation']?.toString() ??
        quotation['createdByRole']?.toString() ??
        '';
    final signMobile =
        quotation['signaturePhone']?.toString() ??
        quotation['signatureMobile']?.toString() ??
        quotation['createdByPhone']?.toString() ??
        '';
    final companyName = quotation['companyName']?.toString() ?? '';

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'For ${companyName.toUpperCase()}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textDark,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 50), // Space for physical signature
            if (signName.isNotEmpty)
              pw.Text(
                signName,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
                textAlign: pw.TextAlign.center,
              ),
            if (signDesignation.isNotEmpty)
              pw.Text(
                signDesignation,
                style: const pw.TextStyle(fontSize: 9, color: textMuted),
                textAlign: pw.TextAlign.center,
              ),
            if (signMobile.isNotEmpty)
              pw.Text(
                'Mob : $signMobile',
                style: const pw.TextStyle(fontSize: 9, color: textMuted),
                textAlign: pw.TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(
    pw.Context context,
    Map<String, dynamic> quotation,
  ) {
    final web = quotation['companyWebsite']?.toString() ?? '';
    final email = quotation['companyEmail']?.toString() ?? '';

    List<String> footerParts = [];
    if (web.isNotEmpty) footerParts.add(web);
    if (email.isNotEmpty) footerParts.add(email);
    footerParts.add('Page ${context.pageNumber} of ${context.pagesCount}');

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderLight)),
      ),
      child: pw.Center(
        child: pw.Text(
          footerParts.join('  |  '),
          style: const pw.TextStyle(fontSize: 8, color: textMuted),
        ),
      ),
    );
  }

  static String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as dynamic).toDate();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  // Helper to convert number to words for INR
  static String _numberToWords(int number) {
    if (number == 0) return 'Zero';
    final units = [
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
    final tens = [
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

    String res = '';

    if ((number / 10000000).floor() > 0) {
      res += '${_numberToWords((number / 10000000).floor())} Crore ';
      number %= 10000000;
    }
    if ((number / 100000).floor() > 0) {
      res += '${_numberToWords((number / 100000).floor())} Lakh ';
      number %= 100000;
    }
    if ((number / 1000).floor() > 0) {
      res += '${_numberToWords((number / 1000).floor())} Thousand ';
      number %= 1000;
    }
    if ((number / 100).floor() > 0) {
      res += '${_numberToWords((number / 100).floor())} Hundred ';
      number %= 100;
    }
    if (number > 0) {
      if (res.isNotEmpty) res += 'and ';
      if (number < 20) {
        res += units[number];
      } else {
        res += tens[(number / 10).floor()];
        if ((number % 10) > 0) res += ' ${units[number % 10]}';
      }
    }
    return res.trim();
  }
}
