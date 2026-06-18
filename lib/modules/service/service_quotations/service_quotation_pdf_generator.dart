import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Import your models from the screen file
import 'package:QUIK/modules/service/service_quotations/create_service_quotation_screen.dart' show QuotationLineItem;

class ServiceQuotationPdfGenerator {
  static Future<Uint8List> generateServiceQuotationPdf(
      Map<String, dynamic> quotation,
      List<QuotationLineItem> items,
      ) async {
    final pdf = pw.Document();

    // Standard PDF Colors
    const primaryColor = PdfColor.fromInt(0xFF1E3A8A); // Blue-900
    const textDark = PdfColor.fromInt(0xFF0F172A);
    const textMuted = PdfColor.fromInt(0xFF64748B);
    const borderLight = PdfColor.fromInt(0xFFE2E8F0);

    // Font setup
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        header: (context) => _buildHeader(quotation, primaryColor, textMuted),
        footer: (context) => _buildFooter(context, textMuted),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildCustomerAndEquipmentSection(quotation, primaryColor, textDark, borderLight),
          pw.SizedBox(height: 20),

          if (quotation['subject']?.toString().isNotEmpty == true) ...[
            pw.Text(
              'Subject: ${quotation['subject']}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: textDark),
            ),
            pw.SizedBox(height: 10),
          ],

          _buildItemsTable(items, quotation, primaryColor, borderLight),

          if ((quotation['visitCharges'] as List?)?.isNotEmpty == true) ...[
            pw.SizedBox(height: 16),
            _buildVisitChargesTable(quotation['visitCharges'] as List, primaryColor, borderLight),
          ],

          pw.SizedBox(height: 16),
          _buildTotals(quotation, primaryColor, borderLight, textDark),

          pw.SizedBox(height: 24),
          _buildTerms(quotation, primaryColor, textDark, textMuted),

          pw.SizedBox(height: 40),
          _buildSignatures(quotation, textDark, borderLight),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(Map<String, dynamic> quotation, PdfColor primaryColor, PdfColor textMuted) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company Info
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    (quotation['companyName']?.toString().toUpperCase() ?? 'COMPANY NAME'),
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(quotation['companyAddress']?.toString() ?? '', style: const pw.TextStyle(fontSize: 10)),
                  if (quotation['companyPhone']?.toString().isNotEmpty == true || quotation['companyEmail']?.toString().isNotEmpty == true)
                    pw.Text('Ph: ${quotation['companyPhone'] ?? ''} | Email: ${quotation['companyEmail'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                  if (quotation['companyGst']?.toString().isNotEmpty == true)
                    pw.Text('GSTIN: ${quotation['companyGst']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            // Document Info
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('SERVICE QUOTATION', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Quote No: ${quotation['quoteNumber'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text('Date: ${quotation['quoteDateStr'] ?? _formatDate(quotation['quoteDate'])}', style: const pw.TextStyle(fontSize: 10)),
                          if (quotation['serviceRequestNumber']?.toString().isNotEmpty == true)
                            pw.Text('SR Ref: ${quotation['serviceRequestNumber']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      )
                  )
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: primaryColor, thickness: 2),
      ],
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

  static pw.Widget _buildCustomerAndEquipmentSection(Map<String, dynamic> quotation, PdfColor primaryColor, PdfColor textDark, PdfColor borderLight) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Billed To
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('QUOTATION TO:', style: pw.TextStyle(fontSize: 9, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(quotation['clientName']?.toString() ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark)),
                pw.Text(quotation['clientAddress']?.toString() ?? '', style: const pw.TextStyle(fontSize: 10)),
                if (quotation['contactPerson']?.toString().isNotEmpty == true)
                  pw.Text('Attn: ${quotation['contactPerson']}', style: const pw.TextStyle(fontSize: 10)),
                if (quotation['clientMobile']?.toString().isNotEmpty == true)
                  pw.Text('Ph: ${quotation['clientMobile']}', style: const pw.TextStyle(fontSize: 10)),
                if (quotation['gstNo']?.toString().isNotEmpty == true)
                  pw.Text('GSTIN: ${quotation['gstNo']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        // Equipment Details
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EQUIPMENT DETAILS:', style: pw.TextStyle(fontSize: 9, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Row(
                    children: [
                      pw.Text('Model: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Expanded(child: pw.Text(quotation['machineModel']?.toString().isNotEmpty == true ? quotation['machineModel'] : 'N/A', style: const pw.TextStyle(fontSize: 10))),
                    ]
                ),
                pw.Row(
                    children: [
                      pw.Text('Serial No: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Expanded(child: pw.Text(quotation['serialNumber']?.toString().isNotEmpty == true ? quotation['serialNumber'] : 'N/A', style: const pw.TextStyle(fontSize: 10))),
                    ]
                ),
                if (quotation['complaintDescription']?.toString().isNotEmpty == true) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Issue: ${quotation['complaintDescription']}', style: const pw.TextStyle(fontSize: 10), maxLines: 2, overflow: pw.TextOverflow.clip),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(List<QuotationLineItem> items, Map<String, dynamic> quotation, PdfColor primaryColor, PdfColor borderLight) {
    if (items.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SERVICE CHARGES & SPARES', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderLight),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),  // S.No
              1: const pw.FlexColumnWidth(5),  // Description
              2: const pw.FlexColumnWidth(2),  // HSN/SAC
              3: const pw.FlexColumnWidth(1.5),// Qty
              4: const pw.FlexColumnWidth(2),  // Rate
              5: const pw.FlexColumnWidth(1.5),// Tax%
              6: const pw.FlexColumnWidth(2.5),// Amount
            },
            headers: ['#', 'Description', 'HSN/SAC', 'Qty', 'Rate', 'Tax', 'Total (INR)'],
            data: List<List<String>>.generate(
              items.length,
                  (index) {
                final item = items[index];
                final totalTax = item.cgstPercent + item.sgstPercent + item.igstPercent;
                final amount = item.quantity * item.unitPrice;

                String desc = item.name;
                if (item.description.isNotEmpty) desc += '\n${item.description}';

                return [
                  '${index + 1}',
                  desc,
                  item.hsnCode,
                  '${item.quantity} ${item.uom}',
                  item.unitPrice.toStringAsFixed(2),
                  '${totalTax.toStringAsFixed(0)}%',
                  amount.toStringAsFixed(2),
                ];
              },
            ),
          ),
        ]
    );
  }

  static pw.Widget _buildVisitChargesTable(List<dynamic> visitCharges, PdfColor primaryColor, PdfColor borderLight) {
    if (visitCharges.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ENGINEER VISIT EXPENSES', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderLight),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),  // S.No
              1: const pw.FlexColumnWidth(7),  // Type
              2: const pw.FlexColumnWidth(1.5),// Qty
              3: const pw.FlexColumnWidth(2),  // Rate
              4: const pw.FlexColumnWidth(1.5),// Tax%
              5: const pw.FlexColumnWidth(2.5),// Amount
            },
            headers: ['#', 'Expense Type', 'Qty', 'Rate', 'Tax', 'Total (INR)'],
            data: List<List<String>>.generate(
              visitCharges.length,
                  (index) {
                final vc = visitCharges[index];
                double qty = double.tryParse(vc['quantity']?.toString() ?? '1') ?? 1.0;
                double rate = double.tryParse(vc['rate']?.toString() ?? '0') ?? 0.0;
                double gst = double.tryParse(vc['gstPercent']?.toString() ?? '18') ?? 18.0;
                double amount = qty * rate;

                return [
                  '${index + 1}',
                  vc['type']?.toString() ?? '',
                  qty.toStringAsFixed(1).replaceAll('.0', ''),
                  rate.toStringAsFixed(2),
                  '${gst.toStringAsFixed(0)}%',
                  amount.toStringAsFixed(2),
                ];
              },
            ),
          ),
        ]
    );
  }

  static pw.Widget _buildTotals(Map<String, dynamic> quotation, PdfColor primaryColor, PdfColor borderLight, PdfColor textDark) {
    final subtotal = double.tryParse(quotation['totalSubtotal']?.toString() ?? '0') ?? 0.0;
    final visitCharges = double.tryParse(quotation['totalVisitCharges']?.toString() ?? '0') ?? 0.0;
    final taxable = double.tryParse(quotation['totalTaxableAmount']?.toString() ?? '0') ?? 0.0;
    final cgst = double.tryParse(quotation['totalCgst']?.toString() ?? '0') ?? 0.0;
    final sgst = double.tryParse(quotation['totalSgst']?.toString() ?? '0') ?? 0.0;
    final igst = double.tryParse(quotation['totalIgst']?.toString() ?? '0') ?? 0.0;
    final roundOff = double.tryParse(quotation['roundOff']?.toString() ?? '0') ?? 0.0;
    final finalTotal = double.tryParse(quotation['finalTotal']?.toString() ?? '0') ?? 0.0;
    final isInterState = quotation['isInterState'] == true;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        padding: const pw.EdgeInsets.all(12),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildTotalRow('Subtotal (Items)', subtotal),
              if (visitCharges > 0)
                _buildTotalRow('Visit Charges', visitCharges),
              pw.Divider(color: borderLight),
              _buildTotalRow('Taxable Value', taxable, isBold: true),
              if (isInterState)
                _buildTotalRow('IGST', igst)
              else ...[
                _buildTotalRow('CGST', cgst),
                _buildTotalRow('SGST', sgst),
              ],
              if (roundOff != 0)
                _buildTotalRow('Round Off', roundOff),
              pw.Divider(color: primaryColor, thickness: 1.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: primaryColor)),
                  pw.Text('INR ${finalTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: textDark)),
                ],
              ),
            ]
        ),
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ]
        )
    );
  }

  static pw.Widget _buildTerms(Map<String, dynamic> quotation, PdfColor primaryColor, PdfColor textDark, PdfColor textMuted) {
    final terms = quotation['dynamicTerms'] as List? ?? [];
    if (terms.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('TERMS & CONDITIONS:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 6),
          ...terms.map((t) {
            final title = t['title']?.toString() ?? '';
            final val = t['value']?.toString() ?? '';
            if (title.isEmpty && val.isEmpty) return pw.SizedBox.shrink();

            return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 100,
                      child: pw.Text('$title :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                    ),
                    pw.Expanded(
                      child: pw.Text(val, style: pw.TextStyle(fontSize: 9, color: textMuted)),
                    ),
                  ],
                )
            );
          }),
        ]
    );
  }

  static pw.Widget _buildSignatures(Map<String, dynamic> quotation, PdfColor textDark, PdfColor borderLight) {
    final signName = quotation['signatureName']?.toString() ?? '';
    final signDesignation = quotation['signatureDesignation']?.toString() ?? '';

    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Container(
              width: 180,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 40),
                    pw.Divider(color: borderLight),
                    pw.Text('Customer Signature & Seal', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                  ]
              )
          ),
          pw.Container(
              width: 220,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('For ${quotation['companyName'] ?? ''}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                    pw.SizedBox(height: 40), // Space for sign
                    pw.Divider(color: borderLight),
                    pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                    if (signName.isNotEmpty)
                      pw.Text(signName, style: const pw.TextStyle(fontSize: 9)),
                    if (signDesignation.isNotEmpty)
                      pw.Text(signDesignation, style: const pw.TextStyle(fontSize: 9)),
                  ]
              )
          )
        ]
    );
  }

  static pw.Widget _buildFooter(pw.Context context, PdfColor textMuted) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount} | This is a computer generated document.',
        style: pw.TextStyle(fontSize: 8, color: textMuted),
      ),
    );
  }
}

// ===========================================================================
// STANDALONE PREVIEW SCREEN FOR LIST VIEW
// ===========================================================================
class ServiceQuotationPdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> quotationData;

  const ServiceQuotationPdfPreviewScreen({
    super.key,
    required this.quotationData,
  });

  @override
  Widget build(BuildContext context) {
    // Safely cast items from the raw Firestore data format
    // into the required List<QuotationLineItem> format.
    final rawItems = quotationData['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) => QuotationLineItem.fromMap(Map<String, dynamic>.from(e))).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: PdfPreview(
        build: (format) => ServiceQuotationPdfGenerator.generateServiceQuotationPdf(quotationData, items),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}