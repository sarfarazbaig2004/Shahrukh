class ChallanValidationResult {
  const ChallanValidationResult({
    required this.status,
    required this.warnings,
    required this.errors,
  });

  final String status;
  final List<String> warnings;
  final List<String> errors;
}

class ChallanValidationService {
  static final RegExp _panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final RegExp _tanPattern = RegExp(r'^[A-Z]{4}[0-9]{5}[A-Z]$');
  static final RegExp _bsrPattern = RegExp(r'^[0-9]{7}$');
  static final RegExp _yearPattern = RegExp(r'^(19|20)[0-9]{2}-[0-9]{2}$');

  bool isValidPan(String value) {
    return value.isEmpty || _panPattern.hasMatch(value);
  }

  bool isValidTan(String value) {
    return value.isEmpty || _tanPattern.hasMatch(value);
  }

  bool isValidBsr(String value) {
    return value.isEmpty || _bsrPattern.hasMatch(value);
  }

  bool isValidYear(String value) {
    if (value.isEmpty || !_yearPattern.hasMatch(value)) {
      return value.isEmpty;
    }

    final first = int.parse(value.substring(0, 4));
    final second = int.parse(value.substring(5, 7));
    return (first + 1) % 100 == second;
  }

  ChallanValidationResult validate({
    required String pan,
    required String tan,
    required String bsrCode,
    required String assessmentYear,
    required String financialYear,
    required double amount,
    required double interest,
    required double penalty,
    required double lateFee,
    required double totalAmount,
  }) {
    final warnings = <String>[];
    final errors = <String>[];

    if (!isValidPan(pan)) {
      errors.add('PAN format is invalid.');
    }

    if (!isValidTan(tan)) {
      errors.add('TAN format is invalid.');
    }

    if (!isValidBsr(bsrCode)) {
      errors.add('BSR code must contain exactly seven digits.');
    }

    if (!isValidYear(assessmentYear)) {
      warnings.add('Assessment Year could not be validated.');
    }

    if (!isValidYear(financialYear)) {
      warnings.add('Financial Year could not be validated.');
    }

    if (<double>[
      amount,
      interest,
      penalty,
      lateFee,
      totalAmount,
    ].any((value) => value < 0)) {
      errors.add('Amounts cannot be negative.');
    }

    final components = amount + interest + penalty + lateFee;

    if (totalAmount > 0 && (components - totalAmount).abs() > 1) {
      warnings.add(
        'Total amount does not match amount, interest, penalty and late fee.',
      );
    }

    if (pan.isEmpty && tan.isEmpty) {
      warnings.add('Neither PAN nor TAN was extracted.');
    }

    if (bsrCode.isEmpty) {
      warnings.add('BSR code was not extracted.');
    }

    final status = errors.isNotEmpty
        ? 'Error'
        : warnings.isNotEmpty
        ? 'Warning'
        : 'Valid';

    return ChallanValidationResult(
      status: status,
      warnings: warnings,
      errors: errors,
    );
  }
}
