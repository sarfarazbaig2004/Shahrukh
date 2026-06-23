// FILE PATH: lib/modules/service/service_quotations/widgets/spare_parts_section.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/service_quotation_models.dart';

class SparePartsSection extends StatelessWidget {
  final List<QuotationLineItem> lineItems;
  final ValueChanged<List<QuotationLineItem>> onItemsChanged;
  final bool isReadOnly;

  const SparePartsSection({
    super.key,
    required this.lineItems,
    required this.onItemsChanged,
    this.isReadOnly = false,
  });

  // Filter items by type
  List<QuotationLineItem> get _spareParts => lineItems.where((item) => item.itemType.toLowerCase() == 'spare' || item.itemType.toLowerCase() == 'accessory').toList();
  List<QuotationLineItem> get _consumables => lineItems.where((item) => item.itemType.toLowerCase() == 'consumable').toList();

  // Calculate totals
  double get _spareTotal => _spareParts.fold(0.0, (sum, item) => sum + item.amount);
  double get _consumableTotal => _consumables.fold(0.0, (sum, item) => sum + item.amount);
  double get _grandTotal => _spareTotal + _consumableTotal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildItemCard(
          context: context,
          title: 'Spare Parts & Accessories',
          icon: Icons.settings_suggest_outlined,
          color: Colors.orange,
          items: _spareParts,
          defaultType: 'Spare',
          allowedTypes: ['Spare', 'Accessory'],
        ),
        const SizedBox(height: 24),
        _buildItemCard(
          context: context,
          title: 'Consumables & Hardware',
          icon: Icons.category_outlined,
          color: Colors.green,
          items: _consumables,
          defaultType: 'Consumable',
          allowedTypes: ['Consumable'],
        ),
        const SizedBox(height: 24),
        _buildSubtotalCard(context),
      ],
    );
  }

  // ==========================================
  // REUSABLE ITEM CARD
  // ==========================================

  Widget _buildItemCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required MaterialColor color,
    required List<QuotationLineItem> items,
    required String defaultType,
    required List<String> allowedTypes,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color.shade900),
                    ),
                  ],
                ),
                if (!isReadOnly)
                  FilledButton.icon(
                    onPressed: () => _showItemForm(context, defaultType, allowedTypes),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Part'),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),

          // Table
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text('No items added in this section.', style: TextStyle(color: Colors.grey.shade500)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('Part Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Disc %', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Billing Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: items.map((item) {
                  final originalIndex = lineItems.indexOf(item);
                  return DataRow(
                    cells: [
                      DataCell(Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(item.itemType, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                      DataCell(Text(item.qty.toStringAsFixed(2))),
                      DataCell(Text(item.rate.toStringAsFixed(2))),
                      DataCell(Text(item.discount.toStringAsFixed(2))),
                      DataCell(Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(_buildBillingBadge(item)),
                      DataCell(
                        isReadOnly
                            ? const SizedBox.shrink()
                            : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                              onPressed: () => _showItemForm(context, defaultType, allowedTypes, existingItem: item, originalIndex: originalIndex),
                              splashRadius: 20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () {
                                final updated = List<QuotationLineItem>.from(lineItems);
                                updated.removeAt(originalIndex);
                                onItemsChanged(updated);
                              },
                              splashRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SUBTOTAL CARD
  // ==========================================

  Widget _buildSubtotalCard(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            _buildSummaryRow('Total Spare Parts:', _spareTotal),
            const SizedBox(height: 12),
            _buildSummaryRow('Total Consumables:', _consumableTotal),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Material Subtotal:',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                ),
                Text(
                  '₹${_grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.indigo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 14)),
        Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildBillingBadge(QuotationLineItem item) {
    if (item.amount == 0 && item.rate == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
        child: Text('FOC / Warranty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
      );
    } else if (item.discount > 0 && item.discount < 100) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
        child: Text('Partial Chargeable', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
        child: Text('Chargeable', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
      );
    }
  }

  // ==========================================
  // DIALOG FORM
  // ==========================================

  void _showItemForm(BuildContext context, String defaultType, List<String> allowedTypes, {QuotationLineItem? existingItem, int? originalIndex}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingItem?.itemName ?? '');
    final qtyCtrl = TextEditingController(text: existingItem?.qty.toString() ?? '1');
    final rateCtrl = TextEditingController(text: existingItem?.rate.toString() ?? '0');
    final discCtrl = TextEditingController(text: existingItem?.discount.toString() ?? '0');

    String selectedType = allowedTypes.contains(existingItem?.itemType) ? (existingItem?.itemType ?? defaultType) : defaultType;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existingItem == null ? 'Add Material' : 'Edit Material', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                double q = double.tryParse(qtyCtrl.text) ?? 0;
                double r = double.tryParse(rateCtrl.text) ?? 0;
                double d = double.tryParse(discCtrl.text) ?? 0;
                double amount = (q * r) * (1 - (d / 100));

                void updateAmount() => setModalState(() {});

                // Shortcut buttons for FOC / 50%
                void setDiscount(double percentage) {
                  discCtrl.text = percentage.toString();
                  updateAmount();
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Part Name *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'Item Type', border: OutlineInputBorder()),
                        items: allowedTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setModalState(() => selectedType = v!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder()),
                              onChanged: (_) => updateAmount(),
                              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: rateCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              decoration: const InputDecoration(labelText: 'Rate (₹) *', border: OutlineInputBorder()),
                              onChanged: (_) => updateAmount(),
                              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: discCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: const InputDecoration(labelText: 'Discount (%)', border: OutlineInputBorder()),
                        onChanged: (_) => updateAmount(),
                        validator: (v) {
                          double val = double.tryParse(v ?? '') ?? -1;
                          if (val < 0 || val > 100) return '0-100 only';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Quick Disc: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          TextButton(onPressed: () => setDiscount(100), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('100% (FOC)')),
                          TextButton(onPressed: () => setDiscount(50), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('50%')),
                          TextButton(onPressed: () => setDiscount(0), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('0% (Chargeable)')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Calculated Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                double q = double.tryParse(qtyCtrl.text) ?? 0;
                double r = double.tryParse(rateCtrl.text) ?? 0;
                double d = double.tryParse(discCtrl.text) ?? 0;
                double amount = (q * r) * (1 - (d / 100));

                final newItem = QuotationLineItem(
                  itemId: existingItem?.itemId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  itemName: nameCtrl.text.trim(),
                  itemType: selectedType,
                  qty: q,
                  rate: r,
                  discount: d,
                  amount: amount,
                );

                final updated = List<QuotationLineItem>.from(lineItems);
                if (originalIndex != null) {
                  updated[originalIndex] = newItem;
                } else {
                  updated.add(newItem);
                }

                onItemsChanged(updated);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Material'),
          ),
        ],
      ),
    );
  }
}