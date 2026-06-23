import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'service_quotation_pdf_generator.dart';
import 'models/service_quotation_models.dart';

class ServiceQuotationPdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> quotationData;
  final List<QuotationLineItem> items;

  const ServiceQuotationPdfPreviewScreen({
    super.key,
    required this.quotationData,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation PDF Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () {}, // Handled by PdfPreview widget internally
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () {}, // Handled by PdfPreview widget internally
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: () {}, // Handled by PdfPreview widget internally
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => ServiceQuotationPdfGenerator.generateServiceQuotationPdf(quotationData, items),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}