import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/challan_extraction_model.dart';
import 'challan_validation_service.dart';

class ChallanExtractionService {
  ChallanExtractionService({ChallanValidationService? validationService})
    : _validationService = validationService ?? ChallanValidationService();

  final ChallanValidationService _validationService;

  static final RegExp _panPattern = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b');
  static final RegExp _tanPattern = RegExp(r'\b[A-Z]{4}[0-9]{5}[A-Z]\b');
  static final RegExp _bsrPattern = RegExp(
    r'(?:BSR\s*(?:CODE)?\s*[:\-]?\s*)([0-9]{7})',
    caseSensitive: false,
  );
  static final RegExp _yearPattern = RegExp(r'\b(20[0-9]{2}-[0-9]{2})\b');
  static final RegExp _datePattern = RegExp(
    r'\b([0-3]?[0-9][\/\-][01]?[0-9][\/\-]20[0-9]{2})\b',
  );

  ChallanExtractionModel extract({
    required String id,
    required String fileName,
    required Uint8List bytes,
    required String text,
    required int processingTimeMilliseconds,
  }) {
    final normalized = text
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n+'), '\n')
        .trim();

    final upper = normalized.toUpperCase();

    final pan = _firstMatch(_panPattern, upper);
    final tan = _firstMatch(_tanPattern, upper);
    final bsr = _groupMatch(_bsrPattern, upper);
    final years = _yearPattern
        .allMatches(upper)
        .map((match) => match.group(1) ?? '')
        .where((value) => value.isNotEmpty)
        .toList();

    final assessmentYear =
        _labelValue(upper, const <String>[
          'ASSESSMENT YEAR',
          'A.Y.',
          'AY',
        ], RegExp(r'20[0-9]{2}-[0-9]{2}')) ??
        (years.isNotEmpty ? years.first : '');

    final financialYear =
        _labelValue(upper, const <String>[
          'FINANCIAL YEAR',
          'F.Y.',
          'FY',
        ], RegExp(r'20[0-9]{2}-[0-9]{2}')) ??
        (years.length > 1 ? years[1] : '');

    final challanSerialNumber =
        _labelValue(upper, const <String>[
          'CHALLAN SERIAL NUMBER',
          'CHALLAN NO',
          'SERIAL NUMBER',
        ], RegExp(r'[0-9]{3,10}')) ??
        '';

    final majorHead =
        _labelValue(upper, const <String>['MAJOR HEAD'], RegExp(r'[0-9]{4}')) ??
        '';

    final minorHead =
        _labelValue(upper, const <String>[
          'MINOR HEAD',
        ], RegExp(r'[0-9]{3,4}')) ??
        '';

    final section =
        _labelValue(upper, const <String>[
          'SECTION',
          'SECTION CODE',
        ], RegExp(r'[0-9]{3}[A-Z]*(?:\([0-9A-Z]+\))?')) ??
        '';

    final amount = _extractAmount(upper, const <String>[
      'INCOME TAX',
      'TAX AMOUNT',
      'BASIC TAX',
      'AMOUNT',
    ]);

    final interest = _extractAmount(upper, const <String>['INTEREST']);

    final penalty = _extractAmount(upper, const <String>['PENALTY']);

    final lateFee = _extractAmount(upper, const <String>[
      'LATE FEE',
      'FEE U/S 234E',
    ]);

    var totalAmount = _extractAmount(upper, const <String>[
      'TOTAL AMOUNT',
      'TOTAL TAX',
      'TOTAL',
    ]);

    if (totalAmount == 0) {
      totalAmount = amount + interest + penalty + lateFee;
    }

    final depositDate = _parseDate(
      _labelValue(upper, const <String>[
            'DEPOSIT DATE',
            'DATE OF DEPOSIT',
            'TENDER DATE',
            'DATE',
          ], _datePattern) ??
          '',
    );

    final itnsForm = _detectForm(upper);
    final challanType = _detectChallanType(upper, itnsForm);

    final name = _extractLineAfterLabel(normalized, const <String>[
      'Name',
      'Taxpayer Name',
      'Deductor Name',
      'Collector Name',
    ]);

    final bankName = _extractLineAfterLabel(normalized, const <String>[
      'Bank Name',
      'Name of Bank',
    ]);

    final branch = _extractLineAfterLabel(normalized, const <String>[
      'Branch',
      'Bank Branch',
    ]);

    final validation = _validationService.validate(
      pan: pan,
      tan: tan,
      bsrCode: bsr,
      assessmentYear: assessmentYear,
      financialYear: financialYear,
      amount: amount,
      interest: interest,
      penalty: penalty,
      lateFee: lateFee,
      totalAmount: totalAmount,
    );

    final extractedCount = <Object?>[
      pan,
      tan,
      bsr,
      assessmentYear,
      financialYear,
      challanSerialNumber,
      majorHead,
      minorHead,
      totalAmount > 0 ? totalAmount : null,
      itnsForm,
    ].where((value) => value != null && value.toString().isNotEmpty).length;

    final confidence = (extractedCount / 9 * 100).clamp(0, 100).toDouble();

    final now = DateTime.now();

    return ChallanExtractionModel(
      id: id,
      sourceFileName: fileName,
      sourceFileSize: bytes.length,
      sourceFileHash: sha256.convert(bytes).toString(),
      challanType: challanType,
      itnsForm: itnsForm,
      pan: pan,
      tan: tan,
      name: name,
      assessmentYear: assessmentYear,
      financialYear: financialYear,
      bsrCode: bsr,
      challanSerialNumber: challanSerialNumber,
      depositDate: depositDate,
      majorHead: majorHead,
      minorHead: minorHead,
      section: section,
      amount: amount,
      interest: interest,
      penalty: penalty,
      lateFee: lateFee,
      totalAmount: totalAmount,
      bankName: bankName,
      branch: branch,
      extractedText: normalized,
      confidenceScore: confidence,
      verificationStatus: validation.status,
      status: validation.errors.isEmpty ? 'Processed' : 'Needs Review',
      warnings: validation.warnings,
      errors: validation.errors,
      processingTimeMilliseconds: processingTimeMilliseconds,
      createdAt: now,
      updatedAt: now,
    );
  }

  String _firstMatch(RegExp pattern, String text) {
    return pattern.firstMatch(text)?.group(0) ?? '';
  }

  String _groupMatch(RegExp pattern, String text) {
    return pattern.firstMatch(text)?.group(1) ?? '';
  }

  String? _labelValue(String text, List<String> labels, RegExp valuePattern) {
    for (final label in labels) {
      final escaped = RegExp.escape(label);
      final pattern = RegExp(
        '$escaped\\s*[:\\-]?\\s*(${valuePattern.pattern})',
        caseSensitive: false,
      );

      final match = pattern.firstMatch(text);

      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  double _extractAmount(String text, List<String> labels) {
    for (final label in labels) {
      final pattern = RegExp(
        '${RegExp.escape(label)}\\s*[:\\-]?\\s*(?:₹|INR|RS\\.?)*\\s*([0-9,]+(?:\\.[0-9]{1,2})?)',
        caseSensitive: false,
      );

      final match = pattern.firstMatch(text);
      final value = match?.group(1)?.replaceAll(',', '');

      if (value != null) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) {
      return null;
    }

    final parts = value.split(RegExp(r'[\/\-]'));

    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) {
      return null;
    }

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _detectForm(String text) {
    const forms = <String>[
      'ITNS 280',
      'ITNS 281',
      'ITNS 282',
      'ITNS 283',
      'FORM 26QB',
      'FORM 26QC',
      'FORM 26QD',
      'FORM 27EQ',
    ];

    for (final form in forms) {
      if (text.contains(form)) {
        return form;
      }
    }

    return '';
  }

  String _detectChallanType(String text, String form) {
    if (form == 'ITNS 281' ||
        text.contains('TDS') ||
        text.contains('TAX DEDUCTED AT SOURCE')) {
      return 'TDS';
    }

    if (form == 'FORM 27EQ' ||
        text.contains('TCS') ||
        text.contains('TAX COLLECTED AT SOURCE')) {
      return 'TCS';
    }

    if (text.contains('ADVANCE TAX')) {
      return 'Advance Tax';
    }

    if (text.contains('SELF ASSESSMENT')) {
      return 'Self Assessment Tax';
    }

    if (text.contains('REGULAR ASSESSMENT')) {
      return 'Regular Assessment Tax';
    }

    return 'Income Tax';
  }

  String _extractLineAfterLabel(String text, List<String> labels) {
    final lines = text.split('\n');

    for (final line in lines) {
      for (final label in labels) {
        final pattern = RegExp(
          '^\\s*${RegExp.escape(label)}\\s*[:\\-]\\s*(.+)\$',
          caseSensitive: false,
        );

        final match = pattern.firstMatch(line);

        if (match != null) {
          return match.group(1)?.trim() ?? '';
        }
      }
    }

    return '';
  }
}
