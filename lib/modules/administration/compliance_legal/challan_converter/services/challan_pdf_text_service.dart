import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class ChallanPdfTextService {
  Future<String> extractText(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('The selected PDF is empty.');
    }

    PdfDocument? document;

    try {
      document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText().trim();

      if (text.isEmpty) {
        throw const FormatException(
          'No embedded text was found. This may be a scanned PDF.',
        );
      }

      return text;
    } on ArgumentError catch (error) {
      throw FormatException('The PDF is corrupt or password protected: $error');
    } finally {
      document?.dispose();
    }
  }
}
