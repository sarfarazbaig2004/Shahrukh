import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:QUIK/modules/crm/customers/customer_duplicate_helper.dart';
import 'package:QUIK/modules/crm/customers/customer_duplicate_search_service.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_360.dart';
import 'package:QUIK/modules/crm/customers/widgets/customer_duplicate_lookup_field.dart';
import 'package:QUIK/modules/crm/customers/customer_country_currency_catalog.dart';

// --- PRODUCTION SAFE ID GENERATOR ---
String _generateSecureId() {
  final random = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rndStr = List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  return '${DateTime.now().millisecondsSinceEpoch}-$rndStr';
}

// --- ENTERPRISE GST LOGIC ---
const Map<String, String> _gstStateCodes = {
  '01': 'Jammu and Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab',
  '04': 'Chandigarh', '05': 'Uttarakhand', '06': 'Haryana', '07': 'Delhi',
  '08': 'Rajasthan', '09': 'Uttar Pradesh', '10': 'Bihar', '11': 'Sikkim',
  '12': 'Arunachal Pradesh', '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram',
  '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam', '19': 'West Bengal',
  '20': 'Jharkhand', '21': 'Odisha', '22': 'Chhattisgarh', '23': 'Madhya Pradesh',
  '24': 'Gujarat', '25': 'Daman and Diu', '26': 'Dadra and Nagar Haveli',
  '27': 'Maharashtra', '28': 'Andhra Pradesh', '29': 'Karnataka', '30': 'Goa',
  '31': 'Lakshadweep', '32': 'Kerala', '33': 'Tamil Nadu', '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands', '36': 'Telangana', '37': 'Andhra Pradesh',
  '38': 'Ladakh'
};

// --- SAFE BOOLEAN PARSER ---
bool _parseBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is int) return value == 1;
  final str = value.toString().trim().toLowerCase();
  if (str == 'true' || str == '1' || str == 'yes') return true;
  if (str == 'false' || str == '0' || str == 'no') return false;
  return fallback;
}

// --- ENTERPRISE VALIDATORS & NORMALIZERS ---
String _normalizePhone(String phone) {
  return normalizePhone(phone);
}

bool _isValidPan(String pan) {
  return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan);
}

bool _isValidGst(String gst) {
  if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(gst)) return false;
  final stateCode = gst.substring(0, 2);
  if (!_gstStateCodes.containsKey(stateCode)) return false;
  final panPart = gst.substring(2, 12);
  if (!_isValidPan(panPart)) return false;
  return true;
}

String _buildInternationalPhoneValue({
  required String countryCode,
  required String phone,
}) {
  final raw = phone.trim();
  if (raw.isEmpty) return '';
  if (raw.startsWith('+')) return raw.replaceAll(RegExp(r'[^0-9+]'), '');

  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  final country = CustomerCountryCurrencyCatalog.byCode(countryCode);
  final callingDigits = country.callingCode.replaceAll(RegExp(r'\D'), '');
  if (callingDigits.isEmpty) return digits;

  return '+$callingDigits$digits';
}

Future<T?> _showSearchPicker<T>({
  required BuildContext context,
  required String title,
  required String searchHint,
  required List<T> items,
  required String Function(T item) searchText,
  required Widget Function(T item) itemBuilder,
}) async {
  final searchController = TextEditingController();

  try {
    return await showDialog<T>(
      context: context,
      builder: (dialogContext) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalizedQuery = query.trim().toLowerCase();
            final filteredItems = normalizedQuery.isEmpty
                ? items
                : items.where((item) {
              return searchText(item).toLowerCase().contains(normalizedQuery);
            }).toList();

            final mediaSize = MediaQuery.sizeOf(context);
            final dialogHeight = (mediaSize.height * 0.72).clamp(320.0, 620.0).toDouble();
            final dialogWidth = min(mediaSize.width - 40, 520.0);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              title: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (value) => setDialogState(() => query = value),
                      decoration: _inputDecoration(
                        label: 'Search',
                        icon: Icons.search,
                        hint: searchHint,
                      ).copyWith(
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();
                            setDialogState(() => query = '');
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(
                        child: Text(
                          'No matching option found.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                          : ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: itemBuilder(item),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    searchController.dispose();
  }
}

Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
  final sanitized = <String, dynamic>{};
  payload.forEach((key, value) {
    if (value == null) return;
    if (value is String) {
      final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (trimmed.isNotEmpty) sanitized[key] = trimmed;
    } else if (value is num) {
      if (!value.isNaN && !value.isInfinite) sanitized[key] = value;
    } else if (value is List) {
      final cleanList = value.map((e) {
        if (e is Map<String, dynamic>) return _sanitizePayload(e);
        if (e is String) return e.trim().replaceAll(RegExp(r'\s+'), ' ');
        return e;
      }).where((e) => e != null && (e is! String || e.isNotEmpty)).toList();
      if (cleanList.isNotEmpty) sanitized[key] = cleanList;
    } else if (value is Map<String, dynamic>) {
      final cleanMap = _sanitizePayload(value);
      if (cleanMap.isNotEmpty) sanitized[key] = cleanMap;
    } else {
      sanitized[key] = value;
    }
  });
  return sanitized;
}

int _estimatePayloadSize(Map<String, dynamic> payload) {
  try {
    final testMap = <String, dynamic>{};
    payload.forEach((k, v) {
      if (v is Timestamp || v is FieldValue || v is DateTime) {
        testMap[k] = '';
      } else {
        testMap[k] = v;
      }
    });
    return utf8.encode(jsonEncode(testMap)).length;
  } catch (_) {
    return 0;
  }
}

// --- ENTERPRISE LOGGER ---
void _logError({
  required String module,
  required String method,
  required dynamic error,
  StackTrace? stack,
  required String uid,
}) {
  debugPrint('[$module] ERROR in $method: $error\n$stack');
  try {
    FirebaseFirestore.instance.collection('system_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'module': module,
      'method': method,
      'error': error.toString(),
      'stack': stack?.toString(),
      'uid': uid,
      'type': 'ERROR',
    });
  } catch (_) {}
}

// --- ENTERPRISE FORM UI SYSTEM ---
const Color _pageBackground = Color(0xFFF4F6F8);
const Color _surfaceColor = Colors.white;
const Color _borderColor = Color(0xFFD9E1EA);
const Color _dividerColor = Color(0xFFE8EDF3);
const Color _primaryColor = Color(0xFF2563EB);
const Color _textPrimary = Color(0xFF0F172A);
const Color _textSecondary = Color(0xFF64748B);

const TextStyle _formFieldTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: _textPrimary,
  height: 1.2,
);

String _cleanFieldLabel(String label) {
  return label.replaceAll('*', '').trim();
}

bool _isRequiredField(String label) => label.contains('*');

InputDecoration _inputDecoration({
  String? label,
  IconData? icon,
  String? hint,
  Widget? suffixIcon,
}) {
  const borderRadius = BorderRadius.all(Radius.circular(6));

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: Color(0xFF94A3B8),
    ),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 17, color: _textSecondary),
    prefixIconConstraints: icon == null
        ? null
        : const BoxConstraints(minWidth: 36, minHeight: 40),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 40),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    constraints: const BoxConstraints(minHeight: 40),
    border: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _borderColor, width: 1),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _borderColor, width: 1),
    ),
    disabledBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _dividerColor, width: 1),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _primaryColor, width: 1.25),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0xFFEF4444), width: 1),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0xFFDC2626), width: 1.25),
    ),
    errorStyle: const TextStyle(fontSize: 10.5, height: 1.1),
  );
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 1, bottom: 5),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            height: 1.1,
          ),
          children: [
            TextSpan(text: _cleanFieldLabel(label)),
            if (_isRequiredField(label))
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
          ],
        ),
      ),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledControl({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(label),
        child,
      ],
    );
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  IconData? icon,
  String? hint,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  int maxLines = 1,
  void Function(String)? onChanged,
  bool enabled = true,
  TextCapitalization textCapitalization = TextCapitalization.none,
}) {
  return _LabeledControl(
    label: label,
    child: TextFormField(
      controller: controller,
      decoration: _inputDecoration(hint: hint),
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: _formFieldTextStyle,
      cursorHeight: 17,
    ),
  );
}

Widget _buildDropdownField<T>({
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?>? onChanged,
  String? Function(T?)? validator,
}) {
  return _LabeledControl(
    label: label,
    child: DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      style: _formFieldTextStyle,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      decoration: _inputDecoration(),
      dropdownColor: Colors.white,
      items: items,
      onChanged: onChanged,
      validator: validator,
    ),
  );
}

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double minChildWidth;
  final double spacing;

  const _ResponsiveRow({
    super.key,
    required this.children,
    this.minChildWidth = 220,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final requiredWidth =
            (children.length * minChildWidth) +
                ((children.length - 1) * spacing);
        final isStacked = constraints.maxWidth < requiredWidth;

        if (isStacked) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1)
                SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool showDivider;

  const _SectionBlock({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
          if (showDivider) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
          ],
        ],
      ),
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  final String text;

  const _SubsectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: _textSecondary,
        ),
      ),
    );
  }
}

class _SectionNavigationItem {
  final String label;
  final VoidCallback onTap;

  const _SectionNavigationItem({
    required this.label,
    required this.onTap,
  });
}

class _SectionNavigation extends StatelessWidget {
  final List<_SectionNavigationItem> items;

  const _SectionNavigation({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _dividerColor, width: 1),
          bottom: BorderSide(color: _dividerColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              TextButton(
                onPressed: items[i].onTap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(items[i].label),
              ),
              if (i != items.length - 1)
                const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountryPickerField extends StatelessWidget {
  final CustomerCountryOption value;
  final String label;
  final ValueChanged<CustomerCountryOption> onChanged;

  const _CountryPickerField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey(value.isoCode),
      initialValue: value.isoCode,
      validator: (_) => value.isoCode.trim().isEmpty
          ? 'Please select a country'
          : null,
      builder: (field) {
        return _LabeledControl(
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () async {
              final selected =
              await _showSearchPicker<CustomerCountryOption>(
                context: context,
                title: 'Select Country',
                searchHint: 'Search country, ISO code or calling code',
                items: CustomerCountryCurrencyCatalog.countries,
                searchText: (country) =>
                '${country.name} ${country.isoCode} ${country.callingCode}',
                itemBuilder: (country) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Text(
                    country.flagEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    country.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${country.isoCode} • ${country.callingCode.isEmpty ? 'No calling code' : country.callingCode}',
                  ),
                  trailing: Text(
                    country.currencyCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              );
              if (selected == null) return;
              field.didChange(selected.isoCode);
              onChanged(selected);
            },
            child: InputDecorator(
              isEmpty: false,
              decoration: _inputDecoration(
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
              ).copyWith(errorText: field.errorText),
              child: Row(
                children: [
                  Text(value.flagEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${value.name} (${value.isoCode})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _formFieldTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyPickerField extends StatelessWidget {
  final CustomerCurrencyOption value;
  final ValueChanged<CustomerCurrencyOption> onChanged;

  const _CurrencyPickerField({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey(value.code),
      initialValue: value.code,
      validator: (_) => value.code.trim().isEmpty || value.code == 'XXX'
          ? 'Please select a valid currency'
          : null,
      builder: (field) {
        return _LabeledControl(
          label: 'Default Currency *',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () async {
              final selected =
              await _showSearchPicker<CustomerCurrencyOption>(
                context: context,
                title: 'Select Customer Currency',
                searchHint: 'Search currency name, code or symbol',
                items: CustomerCountryCurrencyCatalog.currencies
                    .where((currency) => currency.code != 'XXX')
                    .toList(),
                searchText: (currency) =>
                '${currency.name} ${currency.code} ${currency.symbol}',
                itemBuilder: (currency) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currency.symbol,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    currency.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(currency.code),
                ),
              );
              if (selected == null) return;
              field.didChange(selected.code);
              onChanged(selected);
            },
            child: InputDecorator(
              isEmpty: false,
              decoration: _inputDecoration(
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
              ).copyWith(errorText: field.errorText),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      value.symbol,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${value.code} • ${value.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _formFieldTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InternationalPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String countryCode;
  final ValueChanged<CustomerCountryOption> onCountryChanged;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _InternationalPhoneField({
    required this.controller,
    required this.label,
    required this.countryCode,
    required this.onCountryChanged,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final country = CustomerCountryCurrencyCatalog.byCode(countryCode);

    return _LabeledControl(
      label: label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                final selected =
                await _showSearchPicker<CustomerCountryOption>(
                  context: context,
                  title: 'Select Phone Country',
                  searchHint: 'Search country or calling code',
                  items: CustomerCountryCurrencyCatalog.countries,
                  searchText: (item) =>
                  '${item.name} ${item.isoCode} ${item.callingCode}',
                  itemBuilder: (item) => ListTile(
                    dense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8),
                    leading: Text(
                      item.flagEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      item.callingCode.isEmpty ? '—' : item.callingCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
                if (selected != null) onCountryChanged(selected);
              },
              child: InputDecorator(
                isEmpty: false,
                decoration: _inputDecoration(),
                child: Row(
                  children: [
                    Text(
                      country.flagEmoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        country.callingCode.isEmpty
                            ? country.isoCode
                            : country.callingCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.3,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: _inputDecoration(hint: 'Enter phone number'),
              keyboardType: TextInputType.phone,
              validator: validator,
              onChanged: onChanged,
              style: _formFieldTextStyle,
              cursorHeight: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressItem {
  final String id;
  DateTime createdAt;
  DateTime updatedAt;
  String createdByUid;
  String updatedByUid;

  String erpAddressCode;
  int version;

  String type;
  final TextEditingController customTypeController;
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController pincodeController;
  final TextEditingController countryController;
  String countryCode;

  final TextEditingController gstController;
  final TextEditingController contactPersonController;
  final TextEditingController contactPhoneController;
  String contactPhoneCountryCode;
  final TextEditingController contactEmailController;

  List<String> tags;
  bool isPrimary;
  bool isExpanded;
  bool isActive;

  bool isBillingAddress;
  bool isShippingAddress;
  bool isDispatchAddress;
  bool isServiceAddress;

  final ValueNotifier<String> summaryNotifier = ValueNotifier('');

  late final Map<String, dynamic> _originalState;
  bool _listenersAttached = false;

  _AddressItem({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdByUid = '',
    this.updatedByUid = '',
    this.erpAddressCode = '',
    this.version = 1,
    this.type = 'Head Office',
    String customType = '',
    String street = '',
    String city = '',
    String state = '',
    String pincode = '',
    String country = 'India',
    String countryCode = '',
    String gst = '',
    String contactPerson = '',
    String contactPhone = '',
    String contactPhoneCountryCode = '',
    String contactEmail = '',
    List<String>? tags,
    this.isPrimary = false,
    this.isExpanded = true,
    this.isActive = true,
    this.isBillingAddress = false,
    this.isShippingAddress = false,
    this.isDispatchAddress = false,
    this.isServiceAddress = false,
    bool isExisting = false,
  })  : id = id ?? _generateSecureId(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        countryCode = CustomerCountryCurrencyCatalog.resolve(
          code: countryCode,
          name: country,
        ).isoCode,
        contactPhoneCountryCode = CustomerCountryCurrencyCatalog.resolve(
          code: contactPhoneCountryCode,
          name: contactPhoneCountryCode.trim().isEmpty ? country : null,
          fallbackCode: CustomerCountryCurrencyCatalog.resolve(
            code: countryCode,
            name: country,
          ).isoCode,
        ).isoCode,
        tags = tags ?? [],
        customTypeController = TextEditingController(text: customType),
        streetController = TextEditingController(text: street),
        cityController = TextEditingController(text: city),
        stateController = TextEditingController(text: state),
        pincodeController = TextEditingController(text: pincode),
        countryController = TextEditingController(
          text: CustomerCountryCurrencyCatalog.resolve(code: countryCode, name: country).name,
        ),
        gstController = TextEditingController(text: gst),
        contactPersonController = TextEditingController(text: contactPerson),
        contactPhoneController = TextEditingController(text: contactPhone),
        contactEmailController = TextEditingController(text: contactEmail) {
    _originalState = _captureCurrentState();
    _initListeners();
  }

  Map<String, dynamic> _captureCurrentState() {
    return {
      'type': type,
      'customType': customTypeController.text.trim(),
      'street': streetController.text.trim(),
      'city': cityController.text.trim(),
      'state': stateController.text.trim(),
      'pincode': pincodeController.text.trim(),
      'country': countryController.text.trim(),
      'countryCode': countryCode,
      'gst': gstController.text.trim().toUpperCase(),
      'contactPerson': contactPersonController.text.trim(),
      'contactPhone': contactPhoneController.text.trim(),
      'contactPhoneCountryCode': contactPhoneCountryCode,
      'contactEmail': contactEmailController.text.trim(),
      'tags': tags.join(','),
      'isPrimary': isPrimary,
      'isActive': isActive,
      'isBillingAddress': isBillingAddress,
      'isShippingAddress': isShippingAddress,
      'isDispatchAddress': isDispatchAddress,
      'isServiceAddress': isServiceAddress,
    };
  }

  List<String> getModifiedFields() {
    final current = _captureCurrentState();
    final List<String> changed = [];
    current.forEach((key, value) {
      if (_originalState[key] != value) {
        changed.add(key);
      }
    });
    return changed;
  }

  void _initListeners() {
    if (_listenersAttached) return;
    customTypeController.addListener(updateSummary);
    cityController.addListener(updateSummary);
    stateController.addListener(updateSummary);
    countryController.addListener(updateSummary);

    gstController.addListener(_onGstChanged);

    streetController.addListener(_markUpdated);
    cityController.addListener(_markUpdated);
    stateController.addListener(_markUpdated);
    pincodeController.addListener(_markUpdated);
    countryController.addListener(_markUpdated);
    customTypeController.addListener(_markUpdated);
    gstController.addListener(_markUpdated);
    contactPersonController.addListener(_markUpdated);
    contactPhoneController.addListener(_markUpdated);
    contactEmailController.addListener(_markUpdated);

    _listenersAttached = true;
    updateSummary();
  }

  void _onGstChanged() {
    if (countryCode != 'IN') return;
    final gst = gstController.text.trim().toUpperCase();
    if (gst.length >= 2) {
      final code = gst.substring(0, 2);
      final state = _gstStateCodes[code];
      if (state != null && stateController.text.trim().isEmpty) {
        stateController.text = state;
        updateSummary(); // Lightweight refresh instead of setState
      }
    }
  }

  void _markUpdated() {
    updatedAt = DateTime.now();
  }

  void updateSummary() {
    final t = type == 'Other'
        ? (customTypeController.text.trim().isNotEmpty ? customTypeController.text.trim() : 'Custom Address')
        : type;
    final loc = [
      cityController.text.trim(),
      stateController.text.trim(),
      countryController.text.trim()
    ].where((e) => e.isNotEmpty).join(', ');

    summaryNotifier.value = loc.isEmpty ? t : '$t • $loc';
  }


  void dispose() {
    if (_listenersAttached) {
      customTypeController.removeListener(updateSummary);
      cityController.removeListener(updateSummary);
      stateController.removeListener(updateSummary);
      countryController.removeListener(updateSummary);
      gstController.removeListener(_onGstChanged);

      streetController.removeListener(_markUpdated);
      cityController.removeListener(_markUpdated);
      stateController.removeListener(_markUpdated);
      pincodeController.removeListener(_markUpdated);
      countryController.removeListener(_markUpdated);
      customTypeController.removeListener(_markUpdated);
      gstController.removeListener(_markUpdated);
      contactPersonController.removeListener(_markUpdated);
      contactPhoneController.removeListener(_markUpdated);
      contactEmailController.removeListener(_markUpdated);
      _listenersAttached = false;
    }

    summaryNotifier.dispose();
    customTypeController.dispose();
    streetController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    countryController.dispose();
    gstController.dispose();
    contactPersonController.dispose();
    contactPhoneController.dispose();
    contactEmailController.dispose();
  }
}

// --- STANDALONE ADDRESS CARD COMPONENT TO PREVENT GLOBAL REBUILDS ---
class _AddressCardWidget extends StatefulWidget {
  final int index;
  final _AddressItem address;
  final bool isDuplicateType;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback onSetPrimary;

  const _AddressCardWidget({
    Key? key,
    required this.index,
    required this.address,
    required this.isDuplicateType,
    required this.onDuplicate,
    required this.onRemove,
    required this.onSetPrimary,
  }) : super(key: key);

  @override
  State<_AddressCardWidget> createState() => _AddressCardWidgetState();
}

class _AddressCardWidgetState extends State<_AddressCardWidget> {
  CustomerCountryOption get _selectedCountry =>
      CustomerCountryCurrencyCatalog.resolve(
        code: widget.address.countryCode,
        name: widget.address.countryController.text,
      );

  String get _displayAddressType {
    final address = widget.address;
    if (address.type == 'Other') {
      final custom = address.customTypeController.text.trim();
      return custom.isEmpty ? 'Custom Address' : custom;
    }
    return address.type;
  }

  void _changeAddressCountry(CustomerCountryOption country) {
    final address = widget.address;
    final previousCountry = _selectedCountry;

    setState(() {
      address.countryCode = country.isoCode;
      address.countryController.text = country.name;

      if (address.contactPhoneCountryCode.isEmpty ||
          address.contactPhoneCountryCode == previousCountry.isoCode) {
        address.contactPhoneCountryCode = country.isoCode;
      }

      address._markUpdated();
      address.updateSummary();
    });
  }

  void _toggleActive() {
    setState(() {
      widget.address.isActive = !widget.address.isActive;
      widget.address._markUpdated();
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'primary':
        widget.onSetPrimary();
        break;
      case 'active':
        _toggleActive();
        break;
      case 'duplicate':
        widget.onDuplicate();
        break;
      case 'remove':
        widget.onRemove();
        break;
    }
  }

  Widget _buildStatusPill({
    required String label,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.address;
    final selectedCountry = _selectedCountry;

    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: address.isActive ? 1 : 0.68,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: address.isPrimary
                  ? const Color(0xFF93C5FD)
                  : _borderColor,
              width: address.isPrimary ? 1.2 : 1,
            ),
          ),
          child: Column(
            children: [
              Material(
                color: address.isExpanded
                    ? const Color(0xFFF8FAFC)
                    : Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(7),
                  bottom: address.isExpanded
                      ? Radius.zero
                      : const Radius.circular(7),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() => address.isExpanded = !address.isExpanded);
                  },
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(7),
                    bottom: address.isExpanded
                        ? Radius.zero
                        : const Radius.circular(7),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: widget.index,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${widget.index + 1}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _displayAddressType,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    address.erpAddressCode,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              ValueListenableBuilder<String>(
                                valueListenable: address.summaryNotifier,
                                builder: (context, summary, _) {
                                  return Text(
                                    summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: _textSecondary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (address.isPrimary) ...[
                          const SizedBox(width: 8),
                          _buildStatusPill(
                            label: 'PRIMARY',
                            foreground: const Color(0xFF1D4ED8),
                            background: const Color(0xFFDBEAFE),
                          ),
                        ],
                        if (!address.isActive) ...[
                          const SizedBox(width: 6),
                          _buildStatusPill(
                            label: 'INACTIVE',
                            foreground: const Color(0xFF475569),
                            background: const Color(0xFFE2E8F0),
                          ),
                        ],
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          tooltip: 'Address actions',
                          padding: EdgeInsets.zero,
                          splashRadius: 18,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 19,
                            color: _textSecondary,
                          ),
                          onSelected: _handleMenuAction,
                          itemBuilder: (context) => <PopupMenuEntry<String>>[
                            if (!address.isPrimary)
                              const PopupMenuItem<String>(
                                value: 'primary',
                                child: Text('Set as primary'),
                              ),
                            PopupMenuItem<String>(
                              value: 'active',
                              child: Text(
                                address.isActive
                                    ? 'Mark inactive'
                                    : 'Mark active',
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'duplicate',
                              child: Text('Duplicate address'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'remove',
                              child: Text(
                                'Remove address',
                                style: TextStyle(color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          address.isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 19,
                          color: _textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (address.isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _dividerColor, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isDuplicateType) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Multiple "${address.type}" addresses are configured.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _ResponsiveRow(
                        minChildWidth: 180,
                        children: [
                          _buildDropdownField<String>(
                            label: 'Address Type *',
                            value: address.type,
                            items: _addressTypeOptions
                                .map(
                                  (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                address.type = value;
                                if (value != 'Other') {
                                  address.customTypeController.clear();
                                }
                                address._markUpdated();
                                address.updateSummary();
                              });
                            },
                          ),
                          if (address.type == 'Other')
                            _buildTextField(
                              controller: address.customTypeController,
                              label: 'Custom Address Type *',
                              validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          _buildTextField(
                            controller: address.streetController,
                            label: 'Street Address',
                          ),
                          _buildTextField(
                            controller: address.cityController,
                            label: 'City *',
                            validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      _ResponsiveRow(
                        minChildWidth: 180,
                        children: [
                          _buildTextField(
                            controller: address.stateController,
                            label: selectedCountry.administrativeAreaLabel,
                          ),
                          _buildTextField(
                            controller: address.pincodeController,
                            label: selectedCountry.postalCodeLabel,
                            keyboardType: TextInputType.text,
                            validator: (value) =>
                                selectedCountry.validatePostalCode(value ?? ''),
                          ),
                          _CountryPickerField(
                            value: selectedCountry,
                            label: 'Country *',
                            onChanged: _changeAddressCountry,
                          ),
                          _buildTextField(
                            controller: address.gstController,
                            label: selectedCountry.taxRegistrationLabel,
                            textCapitalization:
                            TextCapitalization.characters,
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      _ResponsiveRow(
                        minChildWidth: 220,
                        children: [
                          _buildTextField(
                            controller: address.contactPersonController,
                            label: 'Site Contact',
                          ),
                          _InternationalPhoneField(
                            controller: address.contactPhoneController,
                            label: 'Contact Phone',
                            countryCode: address.contactPhoneCountryCode,
                            onCountryChanged: (country) {
                              setState(() {
                                address.contactPhoneCountryCode =
                                    country.isoCode;
                                address._markUpdated();
                              });
                            },
                          ),
                          _buildTextField(
                            controller: address.contactEmailController,
                            label: 'Contact Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty) return null;
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                                return 'Invalid email';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScreensAddCustomer extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? existingDoc;
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;

  const ScreensAddCustomer({
    super.key,
    this.existingDoc,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
  });

  @override
  State<ScreensAddCustomer> createState() => _ScreensAddCustomerState();
}

class _ScreensAddCustomerState extends State<ScreensAddCustomer> {
  final _scrollController = ScrollController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();

  final _contactNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();

  final _customerTypeCustomController = TextEditingController();
  final _industryCustomController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_AddressItem> _addresses = [];
  final ValueNotifier<int> _addressListNotifier = ValueNotifier<int>(0);

  final _formKey = GlobalKey<FormState>();

  final _generalSectionKey = GlobalKey();
  final _commercialSectionKey = GlobalKey();
  final _contactCrmSectionKey = GlobalKey();
  final _addressesSectionKey = GlobalKey();
  final _ownershipSectionKey = GlobalKey();

  bool _isSaving = false;
  bool _isLoadingExisting = false;
  Timer? _draftTimer;
  String _saveSessionId = '';
  String _lastSavedDraftHash = '';

  String? _customerCode;
  String? _customerType;
  String? _assignedToUid;
  String? _industry;
  String? _leadSource;
  String? _status;
  String? _priority;
  String? _customerStage;

  String _customerCountryCode = 'IN';
  String _currencyCode = 'INR';
  String _primaryPhoneCountryCode = 'IN';
  String _alternatePhoneCountryCode = 'IN';
  bool _currencyManuallySelected = false;

  String _existingCreatedByUid = '';
  Timestamp? _existingCreatedAt;

  String _currentUserName = '';
  final Map<String, String> _cachedUserNames = {};

  late Stream<QuerySnapshot<Map<String, dynamic>>> _activeUsersStream;
  late final CustomerDuplicateSearchService _liveDuplicateSearchService;

  Map<String, dynamic> _initialCustomerState = {};

  bool get _canAssignOthers {
    final role = widget.currentUserRole.trim().toLowerCase();
    return role == 'director' ||
        role == 'md' ||
        role == 'ceo' ||
        role == 'sales_manager' ||
        role == 'superadmin' ||
        role == 'admin';
  }

  bool get _isEdit => widget.existingDoc != null;

  CustomerCountryOption get _selectedCustomerCountry =>
      CustomerCountryCurrencyCatalog.byCode(_customerCountryCode);

  CustomerCurrencyOption get _selectedCurrency =>
      CustomerCountryCurrencyCatalog.currencyByCode(_currencyCode);

  CollectionReference<Map<String, dynamic>> get _customersCol =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers');

  CollectionReference<Map<String, dynamic>> get _companyUsersCol =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users');

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _notifyAddressChange() {
    _addressListNotifier.value++;
  }


  void _scrollToSection(GlobalKey sectionKey) {
    FocusScope.of(context).unfocus();
    final sectionContext = sectionKey.currentContext;
    if (sectionContext == null) return;

    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.03,
    );
  }

  void _applyCustomerCountryDefaults(
      CustomerCountryOption country, {
        bool primaryPhoneIsSource = false,
      }) {
    final previousCountry = _selectedCustomerCountry;

    _safeSetState(() {
      _customerCountryCode = country.isoCode;

      if (!_currencyManuallySelected ||
          _currencyCode == previousCountry.currencyCode) {
        if (country.currencyCode != 'XXX') {
          _currencyCode = country.currencyCode;
          _currencyManuallySelected = false;
        }
      } else if (_currencyCode == country.currencyCode) {
        _currencyManuallySelected = false;
      }

      final primaryPhoneIsBlank = _phoneController.text.trim().isEmpty;
      if (primaryPhoneIsSource ||
          primaryPhoneIsBlank ||
          _primaryPhoneCountryCode == previousCountry.isoCode) {
        _primaryPhoneCountryCode = country.isoCode;
      }

      final alternatePhoneIsBlank = _altPhoneController.text.trim().isEmpty;
      if (alternatePhoneIsBlank ||
          _alternatePhoneCountryCode == previousCountry.isoCode) {
        _alternatePhoneCountryCode = country.isoCode;
      }

      for (final address in _addresses) {
        final isBlankAddress = address.streetController.text.trim().isEmpty &&
            address.cityController.text.trim().isEmpty &&
            address.stateController.text.trim().isEmpty &&
            address.pincodeController.text.trim().isEmpty;
        bool addressChanged = false;

        if (isBlankAddress &&
            address.countryCode == previousCountry.isoCode) {
          address.countryCode = country.isoCode;
          address.countryController.text = country.name;
          addressChanged = true;
        }

        final addressPhoneIsBlank =
            address.contactPhoneController.text.trim().isEmpty;
        final addressUsesSelectedCountry =
            address.countryCode == country.isoCode;
        if (addressUsesSelectedCountry &&
            (addressPhoneIsBlank ||
                address.contactPhoneCountryCode == previousCountry.isoCode) &&
            address.contactPhoneCountryCode != country.isoCode) {
          address.contactPhoneCountryCode = country.isoCode;
          addressChanged = true;
        }

        if (addressChanged) {
          address._markUpdated();
          address.updateSummary();
        }
      }
    });

    _notifyAddressChange();
  }

  void _changeCustomerCountry(CustomerCountryOption country) {
    _applyCustomerCountryDefaults(country);
  }

  void _changePrimaryPhoneCountry(CustomerCountryOption country) {
    _applyCustomerCountryDefaults(
      country,
      primaryPhoneIsSource: true,
    );
  }

  void _changeCustomerCurrency(CustomerCurrencyOption currency) {
    _safeSetState(() {
      _currencyCode = currency.code;
      _currencyManuallySelected = currency.code != _selectedCustomerCountry.currencyCode;
    });
  }

  void _openDuplicateCustomer(CustomerDuplicateSuggestion suggestion) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreensCustomer360(
          customerRef: suggestion.reference,
          companyId: widget.companyId,
          currentUserRole: widget.currentUserRole,
          currentUserName: _currentUserName,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _liveDuplicateSearchService = CustomerDuplicateSearchService(_customersCol);
    _assignedToUid = widget.currentUserUid;
    _status = 'Active';
    _priority = 'Medium';
    _leadSource = 'Direct';
    _customerStage = 'Potential Customer';

    // Store stream reference safely to prevent massive re-renders
    _activeUsersStream = _companyUsersCol.where('isActive', isEqualTo: true).snapshots();

    if (!_isEdit) {
      _loadDraftLocally().then((loaded) {
        if (!loaded && _addresses.isEmpty) {
          _addresses.add(_AddressItem(
            isPrimary: true,
            isBillingAddress: true,
            createdByUid: widget.currentUserUid,
            updatedByUid: widget.currentUserUid,
            erpAddressCode: 'ADDR-001',
          ));
          _notifyAddressChange();
        }
      });
      _draftTimer = Timer.periodic(const Duration(seconds: 15), (_) => _saveDraftLocally());
    } else {
      _loadExistingCustomer();
    }

    _loadCurrentUserName();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _scrollController.dispose();

    _companyController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _businessEmailController.dispose();
    _websiteController.dispose();
    _gstController.dispose();
    _panController.dispose();

    _contactNameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();

    _customerTypeCustomController.dispose();
    _industryCustomController.dispose();
    _notesController.dispose();

    _addressListNotifier.dispose();

    for (final addr in _addresses) {
      addr.dispose();
    }

    super.dispose();
  }

  // --- SMART AUTOSAVE DRAFT LOGIC ---
  Future<void> _saveDraftLocally() async {
    if (_isEdit || _isLoadingExisting || _isSaving) return;
    if (_companyController.text.trim().isEmpty && _phoneController.text.trim().isEmpty && _addresses.length <= 1) return;

    try {
      final draftData = {
        'companyName': _companyController.text,
        'phone': _phoneController.text,
        'altPhone': _altPhoneController.text,
        'email': _businessEmailController.text,
        'website': _websiteController.text,
        'gst': _gstController.text,
        'pan': _panController.text,
        'contactName': _contactNameController.text,
        'designation': _designationController.text,
        'department': _departmentController.text,
        'customerType': _customerType,
        'industry': _industry,
        'leadSource': _leadSource,
        'status': _status,
        'priority': _priority,
        'customerStage': _customerStage,
        'customerCountryCode': _customerCountryCode,
        'currencyCode': _currencyCode,
        'currencyManuallySelected': _currencyManuallySelected,
        'primaryPhoneCountryCode': _primaryPhoneCountryCode,
        'alternatePhoneCountryCode': _alternatePhoneCountryCode,
        'notes': _notesController.text,
        'addresses': _addresses.map((a) => {
          'id': a.id,
          'erpAddressCode': a.erpAddressCode,
          'version': a.version,
          'type': a.type,
          'customType': a.customTypeController.text,
          'street': a.streetController.text,
          'city': a.cityController.text,
          'state': a.stateController.text,
          'pincode': a.pincodeController.text,
          'country': a.countryController.text,
          'countryCode': a.countryCode,
          'gst': a.gstController.text,
          'contactPerson': a.contactPersonController.text,
          'contactPhone': a.contactPhoneController.text,
          'contactPhoneCountryCode': a.contactPhoneCountryCode,
          'contactEmail': a.contactEmailController.text,
          'tags': a.tags,
          'isActive': a.isActive,
          'isPrimary': a.isPrimary,
          'isBillingAddress': a.isBillingAddress,
          'isShippingAddress': a.isShippingAddress,
          'isDispatchAddress': a.isDispatchAddress,
          'isServiceAddress': a.isServiceAddress,
        }).toList(),
      };

      final currentHash = jsonEncode(draftData);
      if (currentHash == _lastSavedDraftHash) return; // Completely prevents unnecessary disk IO stutters

      _lastSavedDraftHash = currentHash;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_customer_${widget.companyId}', currentHash);
    } catch (_) {}
  }

  Future<bool> _loadDraftLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('draft_customer_${widget.companyId}');
      if (draftStr != null) {
        final data = jsonDecode(draftStr);
        _lastSavedDraftHash = draftStr;

        _safeSetState(() {
          _companyController.text = data['companyName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _altPhoneController.text = data['altPhone'] ?? '';
          _businessEmailController.text = data['email'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _gstController.text = data['gst'] ?? '';
          _panController.text = data['pan'] ?? '';

          _contactNameController.text = data['contactName'] ?? '';
          _designationController.text = data['designation'] ?? '';
          _departmentController.text = data['department'] ?? '';

          _customerType = data['customerType'];
          _industry = data['industry'];
          _leadSource = data['leadSource'];
          _status = data['status'] ?? 'Active';
          _priority = data['priority'] ?? 'Medium';
          _customerStage = data['customerStage'] ?? 'Potential Customer';
          _customerCountryCode = CustomerCountryCurrencyCatalog.resolve(
            code: data['customerCountryCode']?.toString(),
            name: data['country']?.toString(),
          ).isoCode;
          _currencyCode = CustomerCountryCurrencyCatalog.currencyByCode(
            data['currencyCode']?.toString(),
            fallbackCode: _selectedCustomerCountry.currencyCode == 'XXX'
                ? 'INR'
                : _selectedCustomerCountry.currencyCode,
          ).code;
          _currencyManuallySelected = _parseBool(data['currencyManuallySelected']);
          _primaryPhoneCountryCode = CustomerCountryCurrencyCatalog.resolve(
            code: data['primaryPhoneCountryCode']?.toString(),
            fallbackCode: _customerCountryCode,
          ).isoCode;
          _alternatePhoneCountryCode = CustomerCountryCurrencyCatalog.resolve(
            code: data['alternatePhoneCountryCode']?.toString(),
            fallbackCode: _customerCountryCode,
          ).isoCode;
          _notesController.text = data['notes'] ?? '';

          if (data['addresses'] != null) {
            _addresses.clear();
            for (var a in data['addresses']) {
              _addresses.add(_AddressItem(
                id: a['id'],
                erpAddressCode: a['erpAddressCode'] ?? '',
                version: a['version'] ?? 1,
                type: a['type'] ?? 'Head Office',
                customType: a['customType'] ?? '',
                street: a['street'] ?? '',
                city: a['city'] ?? '',
                state: a['state'] ?? '',
                pincode: a['pincode'] ?? '',
                country: a['country'] ?? _selectedCustomerCountry.name,
                countryCode: a['countryCode'] ?? '',
                gst: a['gst'] ?? '',
                contactPerson: a['contactPerson'] ?? '',
                contactPhone: a['contactPhone'] ?? '',
                contactPhoneCountryCode: a['contactPhoneCountryCode'] ?? a['countryCode'] ?? CustomerCountryCurrencyCatalog.resolve(
                  name: a['country']?.toString(),
                  fallbackCode: _customerCountryCode,
                ).isoCode,
                contactEmail: a['contactEmail'] ?? '',
                tags: List<String>.from(a['tags'] ?? []),
                isActive: _parseBool(a['isActive'], fallback: true),
                isPrimary: _parseBool(a['isPrimary']),
                isBillingAddress: _parseBool(a['isBillingAddress']),
                isShippingAddress: _parseBool(a['isShippingAddress']),
                isDispatchAddress: _parseBool(a['isDispatchAddress']),
                isServiceAddress: _parseBool(a['isServiceAddress']),
                isExpanded: true,
                createdByUid: widget.currentUserUid,
                updatedByUid: widget.currentUserUid,
              ));
            }
            _notifyAddressChange();
          }
        });
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _clearDraftLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_customer_${widget.companyId}');
    } catch (_) {}
  }

  Future<bool> _onWillPop() async {
    if (_isSaving || _isLoadingExisting) return false;

    final hasChanges = _companyController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _addresses.any((a) => a.cityController.text.isNotEmpty);

    if (!hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final doc = await _companyUsersCol.doc(widget.currentUserUid).get();
      final data = doc.data() ?? {};
      _currentUserName = _extractUserName(data, fallbackUid: widget.currentUserUid);
      _safeSetState(() {});
    } catch (_) {}
  }

  String _extractUserName(Map<String, dynamic> data, {required String fallbackUid}) {
    final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? data['userName'] ?? data['email'] ?? '').toString().trim();
    return name.isEmpty ? fallbackUid : name;
  }

  Map<String, dynamic> _captureCustomerCoreState() {
    return {
      'companyName': _companyController.text.trim(),
      'phone': _phoneController.text.trim(),
      'altPhone': _altPhoneController.text.trim(),
      'email': _businessEmailController.text.trim(),
      'website': _websiteController.text.trim(),
      'gst': _gstController.text.trim(),
      'pan': _panController.text.trim(),
      'contactName': _contactNameController.text.trim(),
      'designation': _designationController.text.trim(),
      'department': _departmentController.text.trim(),
      'customerType': _customerType,
      'industry': _industry,
      'leadSource': _leadSource,
      'status': _status,
      'priority': _priority,
      'customerStage': _customerStage,
      'customerCountryCode': _customerCountryCode,
      'currencyCode': _currencyCode,
      'primaryPhoneCountryCode': _primaryPhoneCountryCode,
      'alternatePhoneCountryCode': _alternatePhoneCountryCode,
      'notes': _notesController.text.trim(),
    };
  }

  Future<void> _loadExistingCustomer() async {
    final docRef = widget.existingDoc;
    if (docRef == null) return;

    _safeSetState(() => _isLoadingExisting = true);

    try {
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};

      _customerCode = (data['customerCode'] ?? '').toString();
      _companyController.text = (data['companyName'] ?? data['name'] ?? '').toString();
      _phoneController.text = (data['companyPhone'] ?? data['phone'] ?? '').toString();
      _altPhoneController.text = (data['alternatePhone'] ?? '').toString();
      _businessEmailController.text = (data['businessEmail'] ?? data['email'] ?? '').toString();
      _websiteController.text = (data['website'] ?? '').toString();
      _gstController.text = (data['gst'] ?? data['taxRegistrationNumber'] ?? '').toString();
      _panController.text = (data['pan'] ?? data['businessRegistrationNumber'] ?? '').toString();

      final resolvedCustomerCountry = CustomerCountryCurrencyCatalog.resolve(
        code: (data['customerCountryCode'] ?? data['countryCode'])?.toString(),
        name: data['country']?.toString(),
      );
      _customerCountryCode = resolvedCustomerCountry.isoCode;

      final savedCurrencyCode = (data['currencyCode'] ?? '').toString().trim().toUpperCase();
      _currencyCode = CustomerCountryCurrencyCatalog.currencyByCode(
        savedCurrencyCode.isEmpty ? resolvedCustomerCountry.currencyCode : savedCurrencyCode,
        fallbackCode: resolvedCustomerCountry.currencyCode == 'XXX'
            ? 'INR'
            : resolvedCustomerCountry.currencyCode,
      ).code;
      final savedCurrencySource = (data['currencySource'] ?? '').toString().trim().toLowerCase();
      _currencyManuallySelected = savedCurrencySource == 'manual' ||
          (savedCurrencySource.isEmpty &&
              savedCurrencyCode.isNotEmpty &&
              savedCurrencyCode != resolvedCustomerCountry.currencyCode);

      _primaryPhoneCountryCode = CustomerCountryCurrencyCatalog.resolve(
        code: (data['phoneCountryCode'] ?? data['primaryPhoneCountryCode'])?.toString(),
        fallbackCode: _customerCountryCode,
      ).isoCode;
      _alternatePhoneCountryCode = CustomerCountryCurrencyCatalog.resolve(
        code: (data['alternatePhoneCountryCode'] ?? data['phoneCountryCode'])?.toString(),
        fallbackCode: _customerCountryCode,
      ).isoCode;

      _contactNameController.text = (data['contactName'] ?? '').toString();
      _designationController.text = (data['designation'] ?? '').toString();
      _departmentController.text = (data['department'] ?? '').toString();

      _addresses.clear();
      final savedAddresses = data['addresses'] as List<dynamic>?;

      if (savedAddresses != null && savedAddresses.isNotEmpty) {
        int index = 0;
        for (final addrData in savedAddresses) {
          index++;
          final map = Map<String, dynamic>.from(addrData as Map);

          final isCustomType = _parseBool(map['isCustomType']);
          final savedType = (map['type'] ?? 'Head Office').toString();

          String resolvedType = 'Other';
          String resolvedCustomType = '';

          if (isCustomType) {
            resolvedType = 'Other';
            resolvedCustomType = savedType;
          } else if (_addressTypeOptions.contains(savedType)) {
            resolvedType = savedType;
          } else {
            resolvedType = 'Other';
            resolvedCustomType = savedType;
          }

          final cAt = map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : DateTime.now();
          final uAt = map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now();

          _addresses.add(_AddressItem(
            id: map['id']?.toString() ?? _generateSecureId(),
            erpAddressCode: map['erpAddressCode']?.toString() ?? 'ADDR-${index.toString().padLeft(3, '0')}',
            version: map['version'] is int ? map['version'] : 1,
            createdAt: cAt,
            updatedAt: uAt,
            createdByUid: (map['createdByUid'] ?? '').toString(),
            updatedByUid: (map['updatedByUid'] ?? '').toString(),
            type: resolvedType,
            customType: resolvedCustomType,
            street: (map['street'] ?? '').toString(),
            city: (map['city'] ?? '').toString(),
            state: (map['state'] ?? '').toString(),
            pincode: (map['pincode'] ?? '').toString(),
            country: (map['country'] ?? _selectedCustomerCountry.name).toString(),
            countryCode: (map['countryCode'] ?? '').toString(),
            gst: (map['gst'] ?? map['taxRegistrationNumber'] ?? '').toString(),
            contactPerson: (map['contactPerson'] ?? '').toString(),
            contactPhone: (map['contactPhone'] ?? '').toString(),
            contactPhoneCountryCode: (map['contactPhoneCountryCode'] ?? map['countryCode'] ?? CustomerCountryCurrencyCatalog.resolve(
              name: map['country']?.toString(),
              fallbackCode: _customerCountryCode,
            ).isoCode).toString(),
            contactEmail: (map['contactEmail'] ?? '').toString(),
            tags: List<String>.from(map['tags'] ?? []),
            isActive: _parseBool(map['isActive'], fallback: true),
            isPrimary: _parseBool(map['isPrimary']),
            isBillingAddress: _parseBool(map['isBillingAddress']),
            isShippingAddress: _parseBool(map['isShippingAddress']),
            isDispatchAddress: _parseBool(map['isDispatchAddress']),
            isServiceAddress: _parseBool(map['isServiceAddress']),
            isExpanded: false,
            isExisting: true,
          ));
        }
      } else {
        _addresses.add(_AddressItem(
          erpAddressCode: 'ADDR-001',
          version: 1,
          type: 'Head Office',
          street: (data['street'] ?? '').toString(),
          city: (data['city'] ?? '').toString(),
          state: (data['state'] ?? '').toString(),
          pincode: (data['pincode'] ?? '').toString(),
          country: (data['country'] ?? _selectedCustomerCountry.name).toString(),
          countryCode: (data['countryCode'] ?? _customerCountryCode).toString(),
          contactPhoneCountryCode: _customerCountryCode,
          isPrimary: true,
          isBillingAddress: true,
          isExpanded: false,
          isExisting: true,
        ));
      }

      if (_addresses.isNotEmpty && !_addresses.any((a) => a.isPrimary)) {
        _addresses.first.isPrimary = true;
      }
      _notifyAddressChange();

      final savedCustomerType = (data['customerType'] ?? '').toString().trim();
      if (savedCustomerType.isEmpty) {
        _customerType = null;
        _customerTypeCustomController.clear();
      } else if (_customerTypeOptions.contains(savedCustomerType)) {
        _customerType = savedCustomerType;
        _customerTypeCustomController.clear();
      } else {
        _customerType = 'Other';
        _customerTypeCustomController.text = savedCustomerType;
      }

      final savedIndustry = (data['industry'] ?? '').toString().trim();
      if (savedIndustry.isEmpty) {
        _industry = null;
        _industryCustomController.clear();
      } else if (_industryOptions.contains(savedIndustry)) {
        _industry = savedIndustry;
        _industryCustomController.clear();
      } else {
        _industry = 'Other';
        _industryCustomController.text = savedIndustry;
      }

      final sourceValue = (data['leadSource'] ?? '').toString().trim();
      if (sourceValue.isNotEmpty && _leadSourceOptions.contains(sourceValue)) {
        _leadSource = sourceValue;
      }

      final statusValue = (data['status'] ?? '').toString().trim();
      if (statusValue.isNotEmpty && _statusOptions.contains(statusValue)) {
        _status = statusValue;
      }

      final priorityValue = (data['priority'] ?? '').toString().trim();
      if (priorityValue.isNotEmpty && _priorityOptions.contains(priorityValue)) {
        _priority = priorityValue;
      }

      final stageValue = (data['customerStage'] ?? 'Potential Customer').toString().trim();
      if (_customerStageOptions.contains(stageValue)) {
        _customerStage = stageValue;
      } else {
        _customerStage = 'Potential Customer';
      }

      _notesController.text = (data['notes'] ?? data['remarks'] ?? '').toString();

      final assigned = (data['assignedToUid'] ?? '').toString().trim();
      if (assigned.isNotEmpty) {
        _assignedToUid = assigned;
      }

      _existingCreatedByUid = (data['createdByUid'] ?? data['createdBy'] ?? '').toString();
      _existingCreatedAt = data['createdAt'] as Timestamp?;

      _initialCustomerState = _captureCustomerCoreState();
      _safeSetState(() {});
    } catch (e, stack) {
      _logError(module: 'CRM', method: '_loadExistingCustomer', error: e, stack: stack, uid: widget.currentUserUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load customer: $e'), backgroundColor: Colors.red),
      );
    } finally {
      _safeSetState(() => _isLoadingExisting = false);
    }
  }

  Future<String> _getUserNameByUid(String uid) async {
    if (uid.trim().isEmpty) return '';
    if (_cachedUserNames.containsKey(uid)) return _cachedUserNames[uid]!;
    try {
      final doc = await _companyUsersCol.doc(uid).get();
      final data = doc.data() ?? {};
      final name = _extractUserName(data, fallbackUid: uid);
      _cachedUserNames[uid] = name;
      return name;
    } catch (_) {
      return uid;
    }
  }

  // --- ADDRESS MANAGEMENT ACTIONS ---
  String _getNextAddressCode() {
    int maxCode = 0;
    for (var a in _addresses) {
      if (a.erpAddressCode.startsWith('ADDR-')) {
        final numPart = a.erpAddressCode.substring(5);
        final val = int.tryParse(numPart) ?? 0;
        if (val > maxCode) maxCode = val;
      }
    }
    return 'ADDR-${(maxCode + 1).toString().padLeft(3, '0')}';
  }

  void _addAddress() {
    for(var a in _addresses) { a.isExpanded = false; }
    _addresses.add(_AddressItem(
      isPrimary: _addresses.isEmpty,
      isBillingAddress: _addresses.isEmpty,
      isExpanded: true,
      country: _selectedCustomerCountry.name,
      countryCode: _customerCountryCode,
      contactPhoneCountryCode: _customerCountryCode,
      createdByUid: widget.currentUserUid,
      updatedByUid: widget.currentUserUid,
      erpAddressCode: _getNextAddressCode(),
    ));
    _notifyAddressChange();
  }

  void _duplicateAddress(int index) {
    final src = _addresses[index];
    for(var a in _addresses) { a.isExpanded = false; }
    _addresses.insert(
      index + 1,
      _AddressItem(
        erpAddressCode: _getNextAddressCode(),
        version: 1,
        type: src.type,
        customType: src.customTypeController.text,
        street: src.streetController.text,
        city: src.cityController.text,
        state: src.stateController.text,
        pincode: src.pincodeController.text,
        country: src.countryController.text,
        countryCode: src.countryCode,
        gst: src.gstController.text,
        contactPerson: src.contactPersonController.text,
        contactPhone: src.contactPhoneController.text,
        contactPhoneCountryCode: src.contactPhoneCountryCode,
        contactEmail: src.contactEmailController.text,
        tags: List.from(src.tags),
        isPrimary: false,
        isActive: true,
        isBillingAddress: false,
        isShippingAddress: false,
        isDispatchAddress: false,
        isServiceAddress: false,
        isExpanded: true,
        createdByUid: widget.currentUserUid,
        updatedByUid: widget.currentUserUid,
      ),
    );
    _notifyAddressChange();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address duplicated.'), duration: Duration(seconds: 2)),
    );
  }

  void _removeAddress(int index) {
    if (_addresses.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one address is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final removed = _addresses[index];
    _addresses.removeAt(index);
    removed.dispose();
    if (removed.isPrimary && _addresses.isNotEmpty) {
      _addresses.first.isPrimary = true;
    }
    _notifyAddressChange();
  }

  void _setPrimaryAddress(int index) {
    for (int i = 0; i < _addresses.length; i++) {
      _addresses[i].isPrimary = i == index;
    }
    _notifyAddressChange();
  }

  void _onReorderAddresses(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _addresses.removeAt(oldIndex);
    _addresses.insert(newIndex, item);
    _notifyAddressChange();
  }

  // --- 🚀 ENTERPRISE SEARCH KEYWORDS GENERATOR (N-GRAMS) ---
  List<String> _generateEnterpriseSearchKeywords(Map<String, dynamic> data, List<Map<String, dynamic>> addresses) {
    final Set<String> keywords = {};

    void addNgrams(String? text) {
      if (text == null || text.trim().isEmpty) return;

      final cleanText = text.toLowerCase().trim();
      keywords.add(cleanText);

      final parts = cleanText.split(RegExp(r'[\s\-_.\@]+'));

      for (final part in parts) {
        if (part.isEmpty) continue;

        // Never skip long words entirely. Cap prefixes at 30 to save index space, but allow full word match.
        String current = '';
        int limit = part.length > 30 ? 30 : part.length;

        for (int i = 0; i < limit; i++) {
          current += part[i];
          if (current.length >= 2) {
            keywords.add(current);
          }
        }
        if (part.length > 30) {
          keywords.add(part);
        }
      }
    }

    final normalizedName = normalizeCustomerName(data['companyName']);
    if (normalizedName.isNotEmpty) {
      addNgrams(normalizedName);
      keywords.add(normalizedName);
    }

    addNgrams(data['companyName']);
    addNgrams(data['customerCode']);
    addNgrams(data['phone']);
    addNgrams(data['phoneDigitsOnly']);
    addNgrams(data['alternatePhone']);
    addNgrams(data['businessEmail']);
    addNgrams(data['gst']);
    addNgrams(data['pan']);
    addNgrams(data['contactName']);
    addNgrams(data['customerCountryName']);
    addNgrams(data['customerCountryCode']);
    addNgrams(data['currencyCode']);
    addNgrams(data['taxRegistrationNumber']);
    addNgrams(data['businessRegistrationNumber']);

    for (final a in addresses) {
      addNgrams(a['city']);
      addNgrams(a['state']);
      addNgrams(a['country']);
      addNgrams(a['countryCode']);
      addNgrams(a['gst']);
      addNgrams(a['contactPerson']);
      addNgrams(a['contactPhone']);
      addNgrams(a['contactEmail']);

      final tagsList = a['tags'];
      if (tagsList is List) {
        for (var tag in tagsList) {
          addNgrams(tag.toString());
        }
      }
    }

    final list = keywords.toList();
    if (list.length > 1000) {
      return list.sublist(0, 1000);
    }
    return list;
  }

  String _buildExportAddress(Map<String, dynamic> addr) {
    final parts = [addr['street'], addr['city'], addr['state'], addr['pincode'], addr['country']]
        .where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
    String res = parts;
    if (addr['gst']?.toString().isNotEmpty == true) {
      final taxLabel = (addr['taxRegistrationType'] ?? 'Tax Registration').toString();
      res += '\n$taxLabel: ${addr['gst']}';
    }
    if (addr['contactPerson']?.toString().isNotEmpty == true) {
      res += '\nContact: ${addr['contactPerson']}';
      if (addr['contactPhone']?.toString().isNotEmpty == true) res += ' (${addr['contactPhone']})';
    }
    return res;
  }

  String _buildSearchIndex(Map<String, dynamic> addr) {
    return [
      addr['type'], addr['customType'], addr['street'], addr['city'],
      addr['state'], addr['pincode'], addr['country'], addr['countryCode'], addr['gst'],
      addr['contactPerson'], addr['contactPhone'], addr['contactEmail']
    ].where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(' ').toLowerCase();
  }

  // --- SECURE CUSTOMER CODE GENERATOR ---
  Future<String> _generateSecureCustomerCode() async {
    final counterRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('metadata')
        .doc('customer_counter');

    int retries = 3;
    int delayMs = 500;

    while (retries > 0) {
      try {
        return await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(counterRef);
          int currentCount = 0;
          if (snapshot.exists) {
            currentCount = snapshot.data()?['count'] ?? 0;
          }
          int nextCount = currentCount + 1;
          transaction.set(counterRef, {'count': nextCount}, SetOptions(merge: true));
          return 'CUST-${nextCount.toString().padLeft(4, '0')}';
        }, timeout: const Duration(seconds: 15));
      } catch (e) {
        retries--;
        if (retries == 0) break;
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      }
    }

    final fallbackSnap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customers')
        .get();

    int maxNumber = 0;
    final codeRegex = RegExp(r'^CUST[-\s]?(\d+)$', caseSensitive: false);

    for (final doc in fallbackSnap.docs) {
      final code = (doc.data()['customerCode'] ?? '').toString().trim();
      final match = codeRegex.firstMatch(code);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '') ?? 0;
        if (number > maxNumber) maxNumber = number;
      }
    }

    final fallbackNext = maxNumber + 1;

    await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('metadata')
        .doc('customer_counter')
        .set({'count': fallbackNext}, SetOptions(merge: true));

    return 'CUST-${fallbackNext.toString().padLeft(4, '0')}';
  }

  Future<String?> _checkCustomerDuplicate({
    String? name,
    String? gst,
    String? phone,
    String? email,
  }) async {
    final customerDocs = await _customersCol.get();
    final customerList = customerDocs.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    return findDuplicateMatch(
      customers: customerList,
      currentCustomerId: widget.existingDoc?.id,
      name: name,
      gst: gst,
      phone: phone,
      email: email,
    );
  }

  // --- DUPLICATE CHECK WARNINGS ---
  void _checkWarnings() {
    final Set<String> gsts = {};
    final Set<String> emails = {};
    final Set<String> phones = {};
    bool hasWarnings = false;

    if (_gstController.text.isNotEmpty) gsts.add(_gstController.text.trim().toLowerCase());
    if (_businessEmailController.text.isNotEmpty) emails.add(_businessEmailController.text.trim().toLowerCase());
    if (_phoneController.text.isNotEmpty) phones.add(_phoneController.text.trim().toLowerCase());

    for (var a in _addresses) {
      final g = a.gstController.text.trim().toLowerCase();
      final e = a.contactEmailController.text.trim().toLowerCase();
      final p = a.contactPhoneController.text.trim().toLowerCase();

      if (g.isNotEmpty && !gsts.add(g)) hasWarnings = true;
      if (e.isNotEmpty && !emails.add(e)) hasWarnings = true;
      if (p.isNotEmpty && !phones.add(p)) hasWarnings = true;
    }

    if (hasWarnings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warning: Duplicate tax registration number, phone, or email detected internally.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // --- DATA INTEGRITY VALIDATORS ---
  bool _runPreSaveValidations() {
    final mainGst = _gstController.text.trim().toUpperCase();
    final mainPan = _panController.text.trim().toUpperCase();

    if (_customerCountryCode == 'IN') {
      if (mainGst.isNotEmpty && !_isValidGst(mainGst)) {
        _scrollToTop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primary GSTIN is invalid. Check format and state code.'), backgroundColor: Colors.red),
        );
        return false;
      }

      if (mainPan.isNotEmpty && !_isValidPan(mainPan)) {
        _scrollToTop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PAN is invalid. Expected format: 5 letters, 4 numbers, 1 letter.'), backgroundColor: Colors.red),
        );
        return false;
      }
    } else {
      if (mainGst.length > 80 || mainPan.length > 80) {
        _scrollToTop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax or business registration number is too long.'), backgroundColor: Colors.red),
        );
        return false;
      }
    }

    for (var a in _addresses) {
      final aGst = a.gstController.text.trim().toUpperCase();
      if (a.countryCode == 'IN' && aGst.isNotEmpty && !_isValidGst(aGst)) {
        a.isExpanded = true;
        _safeSetState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Address "${a.erpAddressCode}" has an invalid GSTIN.'), backgroundColor: Colors.red),
        );
        return false;
      }

      final postalError = CustomerCountryCurrencyCatalog.byCode(a.countryCode)
          .validatePostalCode(a.pincodeController.text);
      if (postalError != null) {
        a.isExpanded = true;
        _safeSetState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${a.erpAddressCode}: $postalError'), backgroundColor: Colors.red),
        );
        return false;
      }
    }

    final primaryCount = _addresses.where((a) => a.isPrimary).length;
    if (primaryCount != 1) {
      for (var a in _addresses) { a.isPrimary = false; }
      _addresses.first.isPrimary = true;
    }

    final Set<String> codes = {};
    for (var a in _addresses) {
      if (!codes.add(a.erpAddressCode)) {
        a.erpAddressCode = _getNextAddressCode();
        codes.add(a.erpAddressCode);
      }
    }

    return true;
  }

  // --- CORE SAVE LOGIC ---
  Future<void> _saveCustomer() async {
    if (_isSaving) return;

    final currentSession = DateTime.now().millisecondsSinceEpoch.toString();
    _saveSessionId = currentSession;

    if (!_formKey.currentState!.validate()) {
      _scrollToTop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_addresses.isEmpty) {
      _scrollToTop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one address is required'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_runPreSaveValidations()) {
      return;
    }

    FocusScope.of(context).unfocus();
    _checkWarnings();

    final assignedTo = _canAssignOthers ? (_assignedToUid ?? '').trim() : widget.currentUserUid;

    if (assignedTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select assigned user'), backgroundColor: Colors.red),
      );
      return;
    }

    _safeSetState(() => _isSaving = true);

    try {
      final Set<String> allModifiedSections = {};
      final currentCoreState = _captureCustomerCoreState();

      if (_isEdit) {
        currentCoreState.forEach((k, v) {
          if (_initialCustomerState[k] != v) allModifiedSections.add('classification');
        });
      }

      final List<Map<String, dynamic>> addressesPayload = _addresses.map((addr) {
        final street = addr.streetController.text.trim();
        final city = addr.cityController.text.trim();
        final state = addr.stateController.text.trim();
        final pincode = addr.pincodeController.text.trim();
        final country = addr.countryController.text.trim();
        final resolvedAddressCountry = CustomerCountryCurrencyCatalog.resolve(
          code: addr.countryCode,
          name: country,
          fallbackCode: _customerCountryCode,
        );

        final addressParts = <String>[street, city, state, pincode, resolvedAddressCountry.name].where((e) => e.isNotEmpty).toList();
        final combinedAddress = addressParts.join(', ');

        final isCustom = addr.type == 'Other';
        final finalType = isCustom ? addr.customTypeController.text.trim() : addr.type;

        final modifiedFields = addr.getModifiedFields();
        if (modifiedFields.isNotEmpty) {
          allModifiedSections.add('addresses');
        }

        final payloadMap = <String, dynamic>{
          'id': addr.id,
          'erpAddressCode': addr.erpAddressCode,
          'version': _isEdit ? (addr.version + (modifiedFields.isNotEmpty ? 1 : 0)) : 1,
          'versionHistoryEnabled': true,
          'type': finalType,
          'isCustomType': isCustom,
          'street': street,
          'city': city,
          'state': state,
          'pincode': pincode,
          'country': resolvedAddressCountry.name,
          'countryCode': resolvedAddressCountry.isoCode,
          'countryCallingCode': resolvedAddressCountry.callingCode,
          'gst': addr.gstController.text.trim().toUpperCase(),
          'taxRegistrationNumber': addr.gstController.text.trim().toUpperCase(),
          'taxRegistrationType': resolvedAddressCountry.taxRegistrationLabel,
          'contactPerson': addr.contactPersonController.text.trim(),
          'contactPhone': addr.contactPhoneController.text.trim(),
          'contactPhoneCountryCode': addr.contactPhoneCountryCode,
          'contactPhoneCallingCode': CustomerCountryCurrencyCatalog.byCode(addr.contactPhoneCountryCode).callingCode,
          'contactPhoneWithCountryCode': _buildInternationalPhoneValue(
            countryCode: addr.contactPhoneCountryCode,
            phone: addr.contactPhoneController.text,
          ),
          'contactPhoneNormalized': normalizePhone(addr.contactPhoneController.text),
          'contactEmail': normalizeEmail(addr.contactEmailController.text),
          'tags': addr.tags,
          'isPrimary': addr.isPrimary,
          'isActive': addr.isActive,
          'isBillingAddress': addr.isBillingAddress,
          'isShippingAddress': addr.isShippingAddress,
          'isDispatchAddress': addr.isDispatchAddress,
          'isServiceAddress': addr.isServiceAddress,
          'combinedAddress': combinedAddress,
          'searchableAddress': combinedAddress.toLowerCase(),
          'createdAt': Timestamp.fromDate(addr.createdAt),
          'updatedAt': modifiedFields.isNotEmpty ? Timestamp.fromDate(DateTime.now()) : Timestamp.fromDate(addr.updatedAt),
          'createdByUid': addr.createdByUid.isEmpty ? widget.currentUserUid : addr.createdByUid,
          'updatedByUid': modifiedFields.isNotEmpty ? widget.currentUserUid : addr.updatedByUid,
          'lastModifiedFields': modifiedFields,
          'latitude': null,
          'longitude': null,
          'geoUpdatedAt': null,
        };

        payloadMap['fullExportAddress'] = _buildExportAddress(payloadMap);
        payloadMap['searchIndex'] = _buildSearchIndex(payloadMap);

        return payloadMap;
      }).toList();

      final primaryAddr = addressesPayload.firstWhere((a) => a['isPrimary'] == true, orElse: () => addressesPayload.first);

      final customType = _customerTypeCustomController.text.trim();
      final customIndustry = _industryCustomController.text.trim();

      final finalCustomerType = _customerType == 'Other' ? (customType.isNotEmpty ? customType : 'Other') : (_customerType ?? '').trim();
      final finalIndustry = _industry == 'Other' ? (customIndustry.isNotEmpty ? customIndustry : 'Other') : (_industry ?? '').trim();

      final name = _companyController.text.trim();
      final customerCountry = _selectedCustomerCountry;
      final customerCurrency = _selectedCurrency;
      final taxRegistrationNumber = _gstController.text.trim().toUpperCase();
      final businessRegistrationNumber = _panController.text.trim().toUpperCase();
      final gst = customerCountry.isoCode == 'IN'
          ? normalizeGST(_gstController.text)
          : taxRegistrationNumber;
      final phone = normalizePhone(_phoneController.text);
      final email = normalizeEmail(_businessEmailController.text);
      final phoneWithCountryCode = _buildInternationalPhoneValue(
        countryCode: _primaryPhoneCountryCode,
        phone: _phoneController.text,
      );
      final alternatePhoneWithCountryCode = _buildInternationalPhoneValue(
        countryCode: _alternatePhoneCountryCode,
        phone: _altPhoneController.text,
      );

      final duplicateField = await _checkCustomerDuplicate(
        name: name,
        gst: gst,
        phone: phone,
        email: email,
      );
      if (_saveSessionId != currentSession) return;

      if (duplicateField != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(duplicateValidationMessage(duplicateField)), backgroundColor: Colors.red),
        );
        _safeSetState(() => _isSaving = false);
        return;
      }

      final assignedToName = await _getUserNameByUid(assignedTo);
      final currentUserName = _currentUserName.isNotEmpty ? _currentUserName : await _getUserNameByUid(widget.currentUserUid);

      if (_saveSessionId != currentSession) return;

      final String finalCustomerCode = _isEdit ? (_customerCode ?? '') : await _generateSecureCustomerCode();

      final Map<String, dynamic> rawUpdateData = {
        'companyId': widget.companyId,
        'customerCode': finalCustomerCode,

        'name': name,
        'companyName': name,
        'companyNameLower': normalizeCustomerName(name),
        'companyNameNormalized': normalizeCustomerName(name),
        'customerNameNormalized': normalizeCustomerName(name),
        'phone': _phoneController.text.trim(),
        'phoneCountryCode': _primaryPhoneCountryCode,
        'primaryPhoneCountryCode': _primaryPhoneCountryCode,
        'phoneCallingCode': CustomerCountryCurrencyCatalog.byCode(_primaryPhoneCountryCode).callingCode,
        'phoneWithCountryCode': phoneWithCountryCode,
        'phoneNormalized': normalizePhone(_phoneController.text),
        'phoneNumberNormalized': normalizePhone(_phoneController.text),
        'phoneLast10': normalizeCustomerPhoneLast10(_phoneController.text),
        'phoneDigitsOnly': _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        'companyPhone': _phoneController.text.trim(),
        'alternatePhone': _altPhoneController.text.trim(),
        'alternatePhoneCountryCode': _alternatePhoneCountryCode,
        'alternatePhoneCallingCode': CustomerCountryCurrencyCatalog.byCode(_alternatePhoneCountryCode).callingCode,
        'alternatePhoneWithCountryCode': alternatePhoneWithCountryCode,
        'alternatePhoneNormalized': normalizePhone(_altPhoneController.text),
        'email': _businessEmailController.text.trim(),
        'emailNormalized': normalizeEmail(_businessEmailController.text),
        'emailLower': normalizeEmail(_businessEmailController.text),
        'businessEmail': _businessEmailController.text.trim(),
        'gst': gst,
        'gstNumberNormalized': customerCountry.isoCode == 'IN' ? normalizeGST(_gstController.text) : taxRegistrationNumber,
        'gstNormalized': customerCountry.isoCode == 'IN' ? normalizeGST(_gstController.text) : taxRegistrationNumber,
        'pan': businessRegistrationNumber,
        'taxRegistrationNumber': taxRegistrationNumber,
        'taxRegistrationType': customerCountry.taxRegistrationLabel,
        'businessRegistrationNumber': businessRegistrationNumber,
        'businessRegistrationType': customerCountry.businessRegistrationLabel,
        'taxCountryCode': customerCountry.isoCode,
        'customerCountryCode': customerCountry.isoCode,
        'customerCountryName': customerCountry.name,
        'customerCountryCallingCode': customerCountry.callingCode,
        'currencyCode': customerCurrency.code,
        'defaultCurrencyCode': customerCurrency.code,
        'currencyName': customerCurrency.name,
        'currencySymbol': customerCurrency.symbol,
        'currencySource': _currencyManuallySelected ? 'manual' : 'country_default',
        'isIndianCustomer': customerCountry.isoCode == 'IN',
        'internationalProfileVersion': 1,
        'website': _websiteController.text.trim(),

        'customerType': finalCustomerType,
        'industry': finalIndustry,
        'leadSource': (_leadSource ?? '').trim(),
        'status': (_status ?? 'Active').trim(),
        'priority': (_priority ?? 'Medium').trim(),
        'customerStage': (_customerStage ?? 'Potential Customer').trim(),

        'addresses': addressesPayload,

        'cityLower': (primaryAddr['city'] ?? '').toString().toLowerCase(),
        'stateLower': (primaryAddr['state'] ?? '').toString().toLowerCase(),
        'countryLower': (primaryAddr['country'] ?? '').toString().toLowerCase(),

        'address': primaryAddr['combinedAddress'],
        'street': primaryAddr['street'],
        'city': primaryAddr['city'],
        'state': primaryAddr['state'],
        'pincode': primaryAddr['pincode'],
        'country': primaryAddr['country'],
        'countryCode': primaryAddr['countryCode'],

        'contactName': _contactNameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),

        'notes': _notesController.text.trim(),
        'remarks': _notesController.text.trim(),

        'assignedToUid': assignedTo,
        'assignedToName': assignedToName,
        'assignedByUid': widget.currentUserUid,
        'assignedByName': currentUserName,

        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.currentUserUid,
        'updatedByUid': widget.currentUserUid,
        'updatedByName': currentUserName,

        'lastModifiedSection': allModifiedSections.isEmpty ? 'none' : allModifiedSections.join(','),
        'auditSummary': {
          'lastAction': _isEdit ? 'updated' : 'created',
          'addressCount': addressesPayload.length,
          'customerCountryCode': customerCountry.isoCode,
          'currencyCode': customerCurrency.code,
          'modifiedSections': allModifiedSections.toList(),
        }
      };

      rawUpdateData['searchKeywords'] = _generateEnterpriseSearchKeywords(rawUpdateData, addressesPayload);

      final nowUpdateData = _sanitizePayload(rawUpdateData);

      if (_estimatePayloadSize(nowUpdateData) > 950000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data size too large. Please reduce address count or notes.'), backgroundColor: Colors.red),
        );
        _safeSetState(() => _isSaving = false);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final DocumentReference customerRef = widget.existingDoc ?? _customersCol.doc();

      if (widget.existingDoc == null) {
        nowUpdateData.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserUid,
          'createdByUid': widget.currentUserUid,
          'createdByName': currentUserName,
          'recordOwnerUid': widget.currentUserUid,
          'recordOwnerName': currentUserName,
          'isActive': true,
          'contactsCount': 0,

          'isDeleted': false,
          'deletedAt': null,
          'deletedByUid': '',
          'isLocked': false,
          'lockedAt': null,
          'lockedByUid': '',

          'visibleToRoles': <String>[],
          'editableByRoles': <String>[],

          'quotationCount': 0,
          'inquiryCount': 0,
          'salesOrderCount': 0,
          'invoiceCount': 0,
          'totalBusinessValue': 0.0,
          'lastActivityAt': FieldValue.serverTimestamp(),

          'followUpCount': 0,
          'lastFollowUpAt': null,
          'lastFollowUpByUid': '',
          'lastFollowUpByName': '',
          'lastFollowUpMode': '',
          'lastFollowUpSummary': '',
          'lastFollowUpOutcome': '',
          'nextFollowUpDate': null,
        });

        batch.set(customerRef, nowUpdateData);

        final contactName = _contactNameController.text.trim();
        final contactPhone = _phoneController.text.trim();
        final contactEmail = _businessEmailController.text.trim();

        final hasContactData = contactName.isNotEmpty || _designationController.text.trim().isNotEmpty || _departmentController.text.trim().isNotEmpty || contactPhone.isNotEmpty || contactEmail.isNotEmpty;

        if (hasContactData) {
          final contactRef = customerRef.collection('contacts').doc();
          batch.set(contactRef, _sanitizePayload({
            'companyId': widget.companyId,
            'customerId': customerRef.id,
            'name': contactName,
            'designation': _designationController.text.trim(),
            'department': _departmentController.text.trim(),
            'phone': contactPhone,
            'phoneCountryCode': _primaryPhoneCountryCode,
            'phoneCallingCode': CustomerCountryCurrencyCatalog.byCode(_primaryPhoneCountryCode).callingCode,
            'phoneWithCountryCode': _buildInternationalPhoneValue(
              countryCode: _primaryPhoneCountryCode,
              phone: contactPhone,
            ),
            'phoneNormalized': normalizePhone(contactPhone),
            'email': normalizeEmail(contactEmail),
            'emailNormalized': normalizeEmail(contactEmail),
            'isPrimary': true,
            'isActive': true,
            'startDate': FieldValue.serverTimestamp(),
            'endDate': null,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': widget.currentUserUid,
            'createdByUid': widget.currentUserUid,
            'createdByName': currentUserName,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': widget.currentUserUid,
            'updatedByName': currentUserName,
          }));
          batch.update(customerRef, {'contactsCount': 1});
        }
      } else {
        nowUpdateData['createdBy'] = _existingCreatedByUid;
        nowUpdateData['createdByUid'] = _existingCreatedByUid;
        nowUpdateData['createdAt'] = _existingCreatedAt;
        batch.update(customerRef, nowUpdateData);
      }

      await batch.commit();

      if (_saveSessionId != currentSession) return;

      await _clearDraftLocally();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingDoc == null ? 'Customer created successfully' : 'Customer updated successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e, stack) {
      _logError(module: 'CRM', method: '_saveCustomer', error: e, stack: stack, uid: widget.currentUserUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save customer. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (_saveSessionId == currentSession) {
        _safeSetState(() => _isSaving = false);
      }
    }
  }

  // --- UI BUILDERS ---

  Widget _buildAssignUserDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activeUsersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const _LabeledControl(
            label: 'Account Owner *',
            child: SizedBox(
              height: 40,
              child: Center(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          );
        }

        if (snap.hasError) {
          return _LabeledControl(
            label: 'Account Owner *',
            child: Text(
              'Failed to load users: ${snap.error}',
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
              ),
            ),
          );
        }

        final docs = snap.data?.docs.toList() ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        docs.sort((a, b) {
          final an = _extractUserName(
            a.data(),
            fallbackUid: a.id,
          ).toLowerCase();
          final bn = _extractUserName(
            b.data(),
            fallbackUid: b.id,
          ).toLowerCase();
          return an.compareTo(bn);
        });

        for (final doc in docs) {
          _cachedUserNames[doc.id] = _extractUserName(
            doc.data(),
            fallbackUid: doc.id,
          );
        }

        if (docs.isEmpty) {
          return const _LabeledControl(
            label: 'Account Owner *',
            child: Text(
              'No active users found',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          );
        }

        String? safeAssignedValue;
        final hasAssignedUser =
        docs.any((doc) => doc.id == _assignedToUid);

        if (hasAssignedUser) {
          safeAssignedValue = _assignedToUid;
        } else if (_canAssignOthers) {
          safeAssignedValue = null;
        } else {
          final currentUserExists =
          docs.any((doc) => doc.id == widget.currentUserUid);
          safeAssignedValue =
          currentUserExists ? widget.currentUserUid : null;
        }

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return _buildDropdownField<String>(
              label: 'Account Owner *',
              value: safeAssignedValue,
              items: docs.map((doc) {
                final data = doc.data();
                final name = _extractUserName(
                  data,
                  fallbackUid: doc.id,
                );
                final role = (data['role'] ?? '').toString().trim();
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    role.isEmpty ? name : '$name • $role',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _canAssignOthers
                  ? (value) {
                _assignedToUid = value;
                setLocalState(() {});
              }
                  : null,
              validator: (value) {
                final finalValue = _canAssignOthers
                    ? value
                    : widget.currentUserUid;
                if (finalValue == null || finalValue.trim().isEmpty) {
                  return 'Please select assigned user';
                }
                return null;
              },
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget? _buildSectionNavigation(bool compact) {
    if (compact) return null;

    return PreferredSize(
      preferredSize: const Size.fromHeight(42),
      child: _SectionNavigation(
        items: [
          _SectionNavigationItem(
            label: 'General',
            onTap: () => _scrollToSection(_generalSectionKey),
          ),
          _SectionNavigationItem(
            label: 'Commercial & Tax',
            onTap: () => _scrollToSection(_commercialSectionKey),
          ),
          _SectionNavigationItem(
            label: 'Contact & CRM',
            onTap: () => _scrollToSection(_contactCrmSectionKey),
          ),
          _SectionNavigationItem(
            label: 'Addresses',
            onTap: () => _scrollToSection(_addressesSectionKey),
          ),
          _SectionNavigationItem(
            label: 'Ownership & Notes',
            onTap: () => _scrollToSection(_ownershipSectionKey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final isCompactHeader = mediaWidth < 720;
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        scaffoldBackgroundColor: _pageBackground,
      ),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: _pageBackground,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
            foregroundColor: _textPrimary,
            toolbarHeight: 58,
            titleSpacing: 10,
            title: Text(
              _isEdit ? 'Edit Customer' : 'Add Customer',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
            ),
            bottom: _buildSectionNavigation(isCompactHeader),
            actions: [
              if (!isCompactHeader && (_customerCode != null || !_isEdit))
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _isEdit ? '$_customerCode' : 'Auto code',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: isCompactHeader
                      ? IconButton(
                    tooltip: _isEdit
                        ? 'Update Customer'
                        : 'Save Customer',
                    onPressed: _isSaving ? null : _saveCustomer,
                    style: IconButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      const Color(0xFFCBD5E1),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.save_outlined,
                      size: 18,
                    ),
                  )
                      : FilledButton.icon(
                    onPressed: _isSaving ? null : _saveCustomer,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.save_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _isEdit ? 'Update Customer' : 'Save Customer',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: _isLoadingExisting
              ? const Center(child: CircularProgressIndicator())
              : Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, viewport) {
                final horizontalPadding = viewport.maxWidth >= 1000
                    ? 24.0
                    : 12.0;

                return Scrollbar(
                  controller: _scrollController,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      30,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                        const BoxConstraints(maxWidth: 1500),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _borderColor),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A0F172A),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildAccountSection(
                                key: _generalSectionKey,
                              ),
                              _buildInternationalProfileSection(
                                key: _commercialSectionKey,
                              ),
                              _buildContactAndCrmSection(
                                key: _contactCrmSectionKey,
                              ),
                              _buildAddressesSection(
                                key: _addressesSectionKey,
                              ),
                              _buildOwnershipAndNotesSection(
                                key: _ownershipSectionKey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection({Key? key}) {
    return _SectionBlock(
      key: key,
      title: 'General Information',
      child: Column(
        children: [
          _ResponsiveRow(
            minChildWidth: 230,
            children: [
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.name,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _buildTextField(
                  controller: _companyController,
                  label: 'Company / Firm Name *',
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Required'
                      : null,
                  onChanged: onChanged,
                ),
              ),
              _buildTextField(
                controller: _websiteController,
                label: 'Website',
                keyboardType: TextInputType.url,
              ),
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.email,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _buildTextField(
                  controller: _businessEmailController,
                  label: 'Business Email',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: onChanged,
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isEmpty) return null;
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email)) {
                      return 'Enter valid email';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsiveRow(
            minChildWidth: 300,
            children: [
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.phone,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _InternationalPhoneField(
                  controller: _phoneController,
                  label: 'Primary Phone *',
                  countryCode: _primaryPhoneCountryCode,
                  onCountryChanged: _changePrimaryPhoneCountry,
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Required'
                      : null,
                  onChanged: onChanged,
                ),
              ),
              _InternationalPhoneField(
                controller: _altPhoneController,
                label: 'Alternate Phone',
                countryCode: _alternatePhoneCountryCode,
                onCountryChanged: (country) {
                  _safeSetState(() {
                    _alternatePhoneCountryCode = country.isoCode;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInternationalProfileSection({Key? key}) {
    final country = _selectedCustomerCountry;
    final currency = _selectedCurrency;
    final countryDefaultCurrency =
    CustomerCountryCurrencyCatalog.currencyByCode(
      country.currencyCode,
      fallbackCode: currency.code,
    );

    return _SectionBlock(
      key: key,
      title: 'Commercial & Tax Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResponsiveRow(
            minChildWidth: 220,
            children: [
              _CountryPickerField(
                value: country,
                label: 'Customer Country *',
                onChanged: _changeCustomerCountry,
              ),
              _CurrencyPickerField(
                value: currency,
                onChanged: _changeCustomerCurrency,
              ),
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.gst,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _buildTextField(
                  controller: _gstController,
                  label: country.taxRegistrationLabel,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: onChanged,
                ),
              ),
              _buildTextField(
                controller: _panController,
                label: country.businessRegistrationLabel,
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          if (_currencyManuallySelected &&
              country.currencyCode != 'XXX' &&
              currency.code != country.currencyCode) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _safeSetState(() {
                    _currencyCode = countryDefaultCurrency.code;
                    _currencyManuallySelected = false;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: _primaryColor,
                  visualDensity: VisualDensity.compact,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Use ${countryDefaultCurrency.code}, the country default',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactAndCrmSection({Key? key}) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return _SectionBlock(
          key: key,
          title: 'Contact & CRM Profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SubsectionLabel('Primary contact'),
              _ResponsiveRow(
                minChildWidth: 210,
                children: [
                  _buildTextField(
                    controller: _contactNameController,
                    label: 'Contact Name',
                  ),
                  _buildTextField(
                    controller: _designationController,
                    label: 'Designation',
                  ),
                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SubsectionLabel('CRM classification'),
              _ResponsiveRow(
                minChildWidth: 190,
                children: [
                  _buildDropdownField<String>(
                    label: 'Customer Stage',
                    value: _customerStage,
                    items: _customerStageOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setLocalState(() => _customerStage = value);
                    },
                  ),
                  _buildDropdownField<String>(
                    label: 'Customer Type',
                    value: _customerType,
                    items: _customerTypeOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setLocalState(() {
                        _customerType = value;
                        if (value != 'Other') {
                          _customerTypeCustomController.clear();
                        }
                      });
                    },
                  ),
                  _buildDropdownField<String>(
                    label: 'Industry',
                    value: _industry,
                    items: _industryOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setLocalState(() {
                        _industry = value;
                        if (value != 'Other') {
                          _industryCustomController.clear();
                        }
                      });
                    },
                  ),
                  _buildDropdownField<String>(
                    label: 'Lead Source',
                    value: _leadSource,
                    items: _leadSourceOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setLocalState(() => _leadSource = value);
                    },
                  ),
                ],
              ),
              if (_customerType == 'Other' || _industry == 'Other') ...[
                const SizedBox(height: 12),
                _ResponsiveRow(
                  minChildWidth: 220,
                  children: [
                    if (_customerType == 'Other')
                      _buildTextField(
                        controller: _customerTypeCustomController,
                        label: 'Custom Customer Type',
                      ),
                    if (_industry == 'Other')
                      _buildTextField(
                        controller: _industryCustomController,
                        label: 'Custom Industry',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _ResponsiveRow(
                minChildWidth: 220,
                children: [
                  _buildDropdownField<String>(
                    label: 'Status',
                    value: _status,
                    items: _statusOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setLocalState(() => _status = value);
                    },
                  ),
                  _buildDropdownField<String>(
                    label: 'Priority',
                    value: _priority,
                    items: _priorityOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setLocalState(() => _priority = value);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyAddressState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _borderColor),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 19,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No address configured',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Add at least one address to complete the customer master.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _addAddress,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Address'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressesSection({Key? key}) {
    return _SectionBlock(
      key: key,
      title: 'Business Addresses',
      trailing: TextButton.icon(
        onPressed: _addAddress,
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add Address'),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _addressListNotifier,
        builder: (context, _, __) {
          if (_addresses.isEmpty) return _buildEmptyAddressState();

          return ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _addresses.length,
            buildDefaultDragHandles: false,
            onReorderStart: (_) => FocusScope.of(context).unfocus(),
            onReorder: _onReorderAddresses,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 2,
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final address = _addresses[index];
              return _AddressCardWidget(
                key: ValueKey(address.id),
                index: index,
                address: address,
                isDuplicateType: address.type != 'Other' &&
                    _addresses
                        .where((item) => item.type == address.type)
                        .length >
                        1,
                onDuplicate: () => _duplicateAddress(index),
                onRemove: () => _removeAddress(index),
                onSetPrimary: () => _setPrimaryAddress(index),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOwnershipAndNotesSection({Key? key}) {
    return _SectionBlock(
      key: key,
      title: 'Ownership & Notes',
      showDivider: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;

          final owner = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAssignUserDropdown(),
              if (!_canAssignOthers) ...[
                const SizedBox(height: 6),
                const Text(
                  'Your role can assign this customer only to your own account.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: _textSecondary,
                  ),
                ),
              ],
            ],
          );

          final notes = _buildTextField(
            controller: _notesController,
            label: 'Internal Notes',
            hint: 'Sales context, remarks or internal instructions',
            maxLines: 3,
          );

          if (!isWide) {
            return Column(
              children: [
                owner,
                const SizedBox(height: 14),
                notes,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: owner),
              const SizedBox(width: 14),
              Expanded(flex: 8, child: notes),
            ],
          );
        },
      ),
    );
  }
}

const List<String> _addressTypeOptions = [
  'Head Office', 'Corporate Office', 'Factory', 'Branch Office', 'Warehouse', 'Site Address', 'Billing Address', 'Shipping Address', 'Other',
];

const List<String> _customerStageOptions = ['Potential Customer', 'Existing Customer'];

const List<String> _customerTypeOptions = [
  'End Customer', 'Distributor', 'Dealer', 'Channel Partner', 'OEM', 'System Integrator', 'Contractor', 'Fabricator', 'Manufacturer', 'Consultant', 'Government', 'Public Sector', 'Educational Institution', 'Service Provider', 'Retailer', 'Trader', 'Other',
];

const List<String> _industryOptions = [
  'Automotive', 'Aerospace & Defense', 'Construction', 'Engineering', 'Energy & Power', 'EPC', 'Fabrication', 'Food & Beverage', 'Healthcare & Medical', 'Infrastructure', 'Manufacturing', 'Marine & Shipbuilding', 'Metal & Steel', 'Mining', 'Oil & Gas', 'Pharmaceuticals', 'Railways', 'Renewable Energy', 'Textiles', 'Trading', 'Utilities', 'Warehousing & Logistics', 'Other',
];

const List<String> _leadSourceOptions = [
  'Direct', 'Reference', 'Website', 'WhatsApp', 'Email Campaign', 'Phone Call', 'Sales Visit', 'Exhibition', 'Distributor', 'Digital Marketing', 'Marketplace', 'Tender', 'Other',
];

const List<String> _statusOptions = ['Active', 'Prospect', 'Lead', 'Dormant', 'Blocked'];

const List<String> _priorityOptions = ['Low', 'Medium', 'High', 'Critical'];

