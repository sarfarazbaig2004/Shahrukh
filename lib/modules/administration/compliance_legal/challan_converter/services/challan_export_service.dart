import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/challan_extraction_model.dart';

class ChallanExportService {
  Future<void> exportCsv(List<ChallanExtractionModel> records) async {
    final rows = <List<String>>[
      const <String>[
        'Status',
        'Challan Type',
        'ITNS/Form',
        'PAN',
        'TAN',
        'Name',
        'Assessment Year',
        'Financial Year',
        'BSR Code',
        'Challan Serial Number',
        'Deposit Date',
        'Major Head',
        'Minor Head',
        'Section',
        'Amount',
        'Interest',
        'Penalty',
        'Late Fee',
        'Total Amount',
        'Bank Name',
        'Branch',
        'Verification Status',
        'Confidence Score',
        'Source File',
      ],
      ...records.map((record) {
        return <String>[
          record.status,
          record.challanType,
          record.itnsForm,
          record.pan,
          record.tan,
          record.name,
          record.assessmentYear,
          record.financialYear,
          record.bsrCode,
          record.challanSerialNumber,
          record.depositDate?.toIso8601String() ?? '',
          record.majorHead,
          record.minorHead,
          record.section,
          record.amount.toStringAsFixed(2),
          record.interest.toStringAsFixed(2),
          record.penalty.toStringAsFixed(2),
          record.lateFee.toStringAsFixed(2),
          record.totalAmount.toStringAsFixed(2),
          record.bankName,
          record.branch,
          record.verificationStatus,
          record.confidenceScore.toStringAsFixed(1),
          record.sourceFileName,
        ];
      }),
    ];

    String escape(String value) {
      return '"${value.replaceAll('"', '""')}"';
    }

    final csv = rows.map((row) => row.map(escape).join(',')).join('\n');

    await FilePicker.platform.saveFile(
      dialogTitle: 'Export Challan Data',
      fileName: 'challan_extracted_data.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
  }

  Future<void> exportJson(List<ChallanExtractionModel> records) async {
    final content = const JsonEncoder.withIndent(
      '  ',
    ).convert(records.map((record) => record.toMap()).toList());

    await FilePicker.platform.saveFile(
      dialogTitle: 'Export Challan JSON',
      fileName: 'challan_extracted_data.json',
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
  }
}
