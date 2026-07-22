import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/form10iea_models.dart';

class Form10IEAPdfExtraction {
  const Form10IEAPdfExtraction({
    required this.itrType,
    required this.assessmentYear,
    required this.panMasked,
    required this.acknowledgementMasked,
    required this.selectedRegime,
    required this.hasBusinessIncome,
    required this.form10ieaFiled,
    required this.confidence,
    required this.needsManualReview,
  });

  final Form10IEAItrType? itrType;
  final String assessmentYear;
  final String panMasked;
  final String acknowledgementMasked;
  final String selectedRegime;
  final bool? hasBusinessIncome;
  final bool? form10ieaFiled;
  final double confidence;
  final bool needsManualReview;
}

class Form10IEAPdfExtractor {
  Future<Form10IEAPdfExtraction> extract(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('The selected PDF is empty.');
    }

    PdfDocument? document;

    try {
      document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText().trim();

      if (text.isEmpty) {
        throw const FormatException(
          'No readable embedded text was found. Use manual confirmation.',
        );
      }

      final upper = text.toUpperCase();

      final pan = RegExp(
        r'\b[A-Z]{5}[0-9]{4}[A-Z]\b',
      ).firstMatch(upper)?.group(0);

      final acknowledgement = RegExp(
        r'(?:ACKNOWLEDGEMENT|ACKNOWLEDGMENT|ACK\.?\s*NO\.?)\s*[:\-]?\s*([0-9]{8,20})',
      ).firstMatch(upper)?.group(1);

      final assessmentYear = RegExp(
        r'(?:ASSESSMENT YEAR|A\.?Y\.?)\s*[:\-]?\s*(20[0-9]{2}-[0-9]{2})',
      ).firstMatch(upper)?.group(1);

      final itrType = RegExp(
        r'\bITR[-\s]?[1-4]\b',
      ).firstMatch(upper)?.group(0)?.replaceAll(' ', '-');

      final oldRegime =
          upper.contains('OLD TAX REGIME') ||
          upper.contains('OPT OUT OF NEW TAX REGIME');

      final newRegime =
          upper.contains('NEW TAX REGIME') || upper.contains('SECTION 115BAC');

      final businessIncome =
          upper.contains('PROFITS AND GAINS OF BUSINESS') ||
          upper.contains('BUSINESS OR PROFESSION');

      final form10iea =
          upper.contains('FORM 10-IEA') || upper.contains('FORM 10IEA');

      final extractedFields = <Object?>[
        pan,
        acknowledgement,
        assessmentYear,
        itrType,
        oldRegime || newRegime ? true : null,
      ].whereType<Object>().length;

      final confidence = (extractedFields / 5 * 100).clamp(0, 100).toDouble();

      return Form10IEAPdfExtraction(
        itrType: Form10IEAItrTypeX.fromString(itrType),
        assessmentYear: assessmentYear ?? '',
        panMasked: _maskPan(pan ?? ''),
        acknowledgementMasked: _maskAcknowledgement(acknowledgement ?? ''),
        selectedRegime: oldRegime
            ? 'Old Regime'
            : newRegime
            ? 'New Regime'
            : '',
        hasBusinessIncome: businessIncome,
        form10ieaFiled: form10iea,
        confidence: confidence,
        needsManualReview: confidence < 70,
      );
    } on ArgumentError {
      throw const FormatException(
        'The PDF is corrupt or password protected. Use manual confirmation.',
      );
    } finally {
      document?.dispose();
    }
  }

  String _maskPan(String value) {
    if (value.length != 10) {
      return '';
    }

    return '${value.substring(0, 2)}*****${value.substring(7)}';
  }

  String _maskAcknowledgement(String value) {
    if (value.length < 6) {
      return '';
    }

    return '${value.substring(0, 2)}******${value.substring(value.length - 4)}';
  }
}
