// lib/modules/finance/invoice/widgets/export_shipping_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExportShippingCard extends StatelessWidget {
  final String modeOfTransport;
  final TextEditingController portOfLoadingCtrl;
  final TextEditingController portOfDischargeCtrl;
  final TextEditingController countryOfOriginCtrl;
  final TextEditingController countryOfDestinationCtrl;
  final TextEditingController vesselFlightNoCtrl;
  final TextEditingController shippingBillNoCtrl;
  final DateTime? shippingBillDate;

  final ValueChanged<String?> onModeChanged;
  final ValueChanged<DateTime> onDateChanged;

  const ExportShippingCard({
    super.key,
    required this.modeOfTransport,
    required this.portOfLoadingCtrl,
    required this.portOfDischargeCtrl,
    required this.countryOfOriginCtrl,
    required this.countryOfDestinationCtrl,
    required this.vesselFlightNoCtrl,
    required this.shippingBillNoCtrl,
    required this.shippingBillDate,
    required this.onModeChanged,
    required this.onDateChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: shippingBillDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: zBlue,
              onPrimary: Colors.white,
              onSurface: zText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. DYNAMIC MODE LABEL LOGIC
    final String vesselFlightLabel = modeOfTransport == 'AIR' ? 'Flight No.' : 'Vessel Name';
    final String vesselFlightHint = modeOfTransport == 'AIR' ? 'e.g. EK 123' : 'e.g. MSC ALINA v.42';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zOrangeSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_outlined, size: 20, color: zOrange),
              ),
              const SizedBox(width: 12),
              const Text(
                'Shipping & Logistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: zText,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 600;
              final halfWidth = isDesktop ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
              final thirdWidth = isDesktop ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 20,
                children: [
                  _buildDropdown(
                    label: 'Mode of Transport',
                    value: modeOfTransport,
                    items: const ['SEA', 'AIR', 'ROAD', 'RAIL'],
                    labels: const ['Sea / Ocean', 'Air Freight', 'Road Transport', 'Rail'],
                    onChanged: onModeChanged,
                    width: thirdWidth,
                  ),
                  _buildTextField(
                    label: vesselFlightLabel,
                    controller: vesselFlightNoCtrl,
                    width: thirdWidth,
                    hint: vesselFlightHint,
                  ),
                  _buildTextField(
                    label: 'Shipping Bill No.',
                    controller: shippingBillNoCtrl,
                    width: thirdWidth,
                    hint: 'Will be updated after shipment',
                  ),
                  // Real-time disable logic for the date picker
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: shippingBillNoCtrl,
                    builder: (context, value, child) {
                      final bool hasShippingBill = value.text.trim().isNotEmpty;
                      return _buildDateField(
                        label: 'Shipping Bill Date',
                        date: shippingBillDate,
                        onTap: hasShippingBill ? () => _pickDate(context) : null,
                        width: thirdWidth,
                        isDisabled: !hasShippingBill,
                      );
                    },
                  ),
                  const SizedBox(width: double.infinity, height: 4), // Line break
                  _buildTextField(
                    label: 'Port of Loading',
                    controller: portOfLoadingCtrl,
                    width: halfWidth,
                    hint: 'e.g. INNSA1 (Nhava Sheva)',
                    isUpperCase: true, // 4. AUTO UPPERCASE
                  ),
                  _buildTextField(
                    label: 'Port of Discharge',
                    controller: portOfDischargeCtrl,
                    width: halfWidth,
                    hint: 'e.g. USNYC (New York)',
                    isUpperCase: true, // 4. AUTO UPPERCASE
                  ),
                  _buildTextField(
                    label: 'Country of Origin',
                    controller: countryOfOriginCtrl,
                    width: halfWidth,
                    hint: 'e.g. India',
                    errorChecker: (val) {
                      if (val.trim().isNotEmpty && val.trim().toLowerCase() != 'india') {
                        return 'Origin must be India';
                      }
                      return null;
                    },
                  ),
                  _buildTextField(
                    label: 'Country of Destination',
                    controller: countryOfDestinationCtrl,
                    width: halfWidth,
                    hint: 'e.g. United States',
                    errorChecker: (val) {
                      if (val.trim().isNotEmpty && val.trim().toLowerCase() == 'india') {
                        return 'Destination cannot be India';
                      }
                      return null;
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required double width,
    String? hint,
    bool isUpperCase = false,
    String? Function(String)? errorChecker,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: zText,
            ),
          ),
          const SizedBox(height: 8),
          // ValueListenableBuilder ensures real-time UI updates for errors without breaking standard form structure
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return TextFormField(
                  controller: controller,
                  inputFormatters: isUpperCase ? [UpperCaseTextFormatter()] : [],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: zText),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: zMuted, fontWeight: FontWeight.w400),
                    errorText: errorChecker?.call(value.text),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: zBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: zBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: zBlue, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red, width: 1.0),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                );
              }
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: zText,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: items.contains(value) ? value : null,
            icon: const Icon(Icons.keyboard_arrow_down, color: zMuted),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: zText),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBlue, width: 1.5),
              ),
            ),
            items: List.generate(items.length, (index) {
              return DropdownMenuItem(
                value: items[index],
                child: Text(labels[index]),
              );
            }),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback? onTap, // ✅ ALLOWS NULL FOR PROPER DISABLED BEHAVIOR
    required double width,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDisabled ? zMuted : zText,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: isDisabled ? Colors.grey.shade300 : zBorder),
                borderRadius: BorderRadius.circular(8),
                color: isDisabled ? Colors.grey.shade100 : Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date != null && !isDisabled ? DateFormat('dd MMM yyyy').format(date) : 'Select Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: date != null && !isDisabled ? FontWeight.w600 : FontWeight.w400,
                      color: date != null && !isDisabled ? zText : zMuted,
                    ),
                  ),
                  Icon(Icons.calendar_month_outlined, size: 18, color: isDisabled ? Colors.grey.shade400 : zMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Formatter for Uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}