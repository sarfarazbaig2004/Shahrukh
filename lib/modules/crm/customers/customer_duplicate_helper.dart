import 'package:unorm_dart/unorm_dart.dart' as unorm;

String normalizeCustomerName(String? value) {
  if (value == null) return '';

  var text = value.toString();
  text = text.replaceAll(RegExp(r'[\u200B-\u200D\u2060\uFEFF\u00AD]'), '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  final normalized = unorm.nfkc(text);
  final buffer = StringBuffer();
  bool lastWasSpace = false;
  for (final rune in normalized.runes) {
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) {
      if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
      continue;
    }

    buffer.write(char);
    lastWasSpace = false;
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

String normalizeGST(String? value) {
  if (value == null) return '';
  return value
      .toString()
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('-', '');
}

String normalizePhone(String? value) {
  if (value == null) return '';
  final digits = value.toString().replaceAll(RegExp(r'\D'), '');
  return digits;
}

/// Normalization used only by the real-time duplicate warning layer.
///
/// The save-time duplicate validation intentionally continues to use
/// [normalizePhone]. Keeping this separate prevents the early-warning feature
/// from changing the final validation contract.
String normalizeCustomerPhoneLast10(String? value) {
  final digits = normalizePhone(value);
  if (digits.isEmpty) return '';

  final withoutLeadingZeroes = digits.replaceFirst(RegExp(r'^0+'), '');
  if (withoutLeadingZeroes.length <= 10) return withoutLeadingZeroes;
  return withoutLeadingZeroes.substring(withoutLeadingZeroes.length - 10);
}

String normalizeEmail(String? value) {
  if (value == null) return '';
  return value.toString().trim().toLowerCase();
}

String? findDuplicateMatch({
  required List<Map<String, dynamic>> customers,
  String? currentCustomerId,
  String? name,
  String? gst,
  String? phone,
  String? email,
}) {
  final normalizedName = normalizeCustomerName(name);
  final normalizedGst = normalizeGST(gst);
  final normalizedPhone = normalizePhone(phone);
  final normalizedEmail = normalizeEmail(email);

  for (final customer in customers) {
    final id = customer['id']?.toString() ?? '';
    if (currentCustomerId != null && id == currentCustomerId) {
      continue;
    }

    final existingName = normalizeCustomerName(
      customer['customerNameNormalized'] ??
          customer['companyNameNormalized'] ??
          customer['name'] ??
          customer['companyName'],
    );
    final existingGst = normalizeGST(
      customer['gstNumberNormalized'] ??
          customer['gstNormalized'] ??
          customer['gst'],
    );
    final existingPhone = normalizePhone(
      customer['phoneNumberNormalized'] ??
          customer['phoneNormalized'] ??
          customer['phone'] ??
          customer['companyPhone'],
    );
    final existingEmail = normalizeEmail(
      customer['emailNormalized'] ??
          customer['emailLower'] ??
          customer['email'] ??
          customer['businessEmail'],
    );

    if (normalizedName.isNotEmpty &&
        existingName.isNotEmpty &&
        normalizedName == existingName) {
      return 'customerName';
    }
    if (normalizedGst.isNotEmpty &&
        existingGst.isNotEmpty &&
        normalizedGst == existingGst) {
      return 'gst';
    }
    if (normalizedPhone.isNotEmpty &&
        existingPhone.isNotEmpty &&
        normalizedPhone == existingPhone) {
      return 'phone';
    }
    if (normalizedEmail.isNotEmpty &&
        existingEmail.isNotEmpty &&
        normalizedEmail == existingEmail) {
      return 'email';
    }
  }

  return null;
}

String duplicateValidationMessage(String? matchType) {
  switch (matchType) {
    case 'customerName':
      return 'This customer already exists.';
    case 'gst':
      return 'GST Number already registered.';
    case 'phone':
      return 'Phone Number already registered.';
    case 'email':
      return 'Email ID already registered.';
    default:
      return 'This customer already exists.';
  }
}
