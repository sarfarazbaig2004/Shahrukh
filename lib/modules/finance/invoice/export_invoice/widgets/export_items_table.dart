import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import '../models/export_invoice_item.dart';
import 'dialog_add_export_item.dart';

class ExportItemsTable extends StatelessWidget {
  final List<ExportInvoiceItem> items;
  final String currency;
  final bool isLut;
  final ValueChanged<List<ExportInvoiceItem>> onChanged;

  const ExportItemsTable({
    super.key,
    required this.items,
    required this.currency,
    required this.isLut,
    required this.onChanged,
  });

  void _removeItem(int index) {
    final newItems = List<ExportInvoiceItem>.from(items);
    newItems.removeAt(index);
    onChanged(newItems);
  }

  Future<void> _openItemDialog(BuildContext context,
      {ExportInvoiceItem? existingItem, int? index}) async {
    final result = await showDialog<ExportInvoiceItem>(
      context: context,
      builder: (_) => DialogAddExportItem(
        companyId: existingItem?.companyId ?? '',
        userUid: existingItem?.updatedBy ?? '',
        selectedCurrency: currency,
        existingItem: existingItem,
      ),
    );

    if (result != null) {
      final newItems = List<ExportInvoiceItem>.from(items);

      if (index != null) {
        newItems[index] = result;
      } else {
        newItems.add(result);
      }

      onChanged(newItems);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Row(
          children: [
            const Text(
              'Export Items',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: zText),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openItemDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: zBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // EMPTY STATE
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: zBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No items added'),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('HSN')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Rate')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Actions')),
              ],
              rows: items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;

                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(item.name)),
                  DataCell(Text(item.hsnCode)),
                  DataCell(Text('${item.quantity} ${item.unit}')),
                  DataCell(Text(
                      '$currency ${item.rate.toStringAsFixed(2)}')),

                  // ✅ FIXED → always correct
                  DataCell(Text(
                      '$currency ${(item.quantity * item.rate).toStringAsFixed(2)}')),

                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit,
                            size: 18, color: zBlue),
                        onPressed: () => _openItemDialog(context,
                            existingItem: item, index: i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        onPressed: () => _removeItem(i),
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }
}