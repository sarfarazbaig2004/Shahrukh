// lib/modules/finance/invoice/widgets/export_invoice_header_card.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExportInvoiceHeaderCard extends StatelessWidget {
  final TextEditingController invoiceNoController;
  final DateTime invoiceDate;

  final String exportType;
  final String natureOfSupply;
  final String currency;

  final TextEditingController exchangeRateController;
  final TextEditingController placeOfSupplyController;

  final bool isLut;

  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String?> onExportTypeChanged;
  final ValueChanged<String?> onNatureOfSupplyChanged;
  final ValueChanged<String?> onCurrencyChanged;

  const ExportInvoiceHeaderCard({
    super.key,
    required this.invoiceNoController,
    required this.invoiceDate,
    required this.exportType,
    required this.natureOfSupply,
    required this.currency,
    required this.exchangeRateController,
    required this.placeOfSupplyController,
    required this.isLut,
    required this.onDateChanged,
    required this.onExportTypeChanged,
    required this.onNatureOfSupplyChanged,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 HEADER TITLE
          const Text(
            'Invoice Header Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: zText,
            ),
          ),

          const SizedBox(height: 16),

          // ROW 1
          Row(
            children: [
              Expanded(
                child: _field(
                  'Invoice No',
                  invoiceNoController,
                  readOnly: true, // ✅ ERP RULE: cannot edit
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _dateField(context)),
            ],
          ),

          const SizedBox(height: 12),

          // ROW 2
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Export Type',
                  exportType,
                  const {
                    'WITH_LUT': 'With LUT (No IGST)',
                    'WITH_IGST': 'With IGST Payment',
                  },
                  onExportTypeChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  'Nature of Supply',
                  natureOfSupply,
                  const {
                    'GOODS': 'Goods',
                    'SERVICES': 'Services',
                  },
                  onNatureOfSupplyChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ROW 3
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Currency',
                  currency,
                  const {
                    'USD': 'USD - US Dollar',
                    'EUR': 'EUR - Euro',
                    'INR': 'INR - Indian Rupee',
                  },
                  onCurrencyChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  'Exchange Rate',
                  exchangeRateController,
                  isNumber: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ROW 4
          _field(
            'Place of Supply',
            placeOfSupplyController,
            readOnly: true, // ✅ Always Out of India
          ),

          const SizedBox(height: 10),

          // 🔥 INFO NOTE
          if (isLut)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Export under LUT/Bond → IGST not applicable',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Export with IGST → Tax will be applied',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }

  // ================= COMMON FIELD =================
  Widget _field(String label, TextEditingController controller,
      {bool isNumber = false, bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ================= DROPDOWN =================
  Widget _dropdown(String label, String value,
      Map<String, String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.entries
          .map((e) => DropdownMenuItem(
        value: e.key,
        child: Text(e.value),
      ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ================= DATE =================
  Widget _dateField(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: invoiceDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onDateChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Invoice Date',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          DateFormat('dd-MMM-yyyy').format(invoiceDate),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}