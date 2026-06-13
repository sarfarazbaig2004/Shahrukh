import 'package:flutter/material.dart';
import '../models/export_invoice_item.dart';

class DialogAddExportItem extends StatefulWidget {
  final String companyId;
  final String userUid;
  final String selectedCurrency;
  final ExportInvoiceItem? existingItem;

  const DialogAddExportItem({
    super.key,
    required this.companyId,
    required this.userUid,
    required this.selectedCurrency,
    this.existingItem,
  });

  @override
  State<DialogAddExportItem> createState() => _DialogAddExportItemState();
}

class _DialogAddExportItemState extends State<DialogAddExportItem> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _hsnController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  final List<String> _uomList = [
    'NOS', 'KGS', 'MTRS', 'PCS', 'BOX', 'LTRS', 'DOZ', 'PACKS', 'SET', 'TONS', 'SQM'
  ];

  String _selectedUnit = 'NOS';
  double _calculatedAmount = 0.0;

  @override
  void initState() {
    super.initState();

    if (widget.existingItem != null) {
      final item = widget.existingItem!;

      _nameController.text = item.name;
      _descController.text = item.description;
      _hsnController.text = item.hsnCode;
      _qtyController.text = item.quantity.toString();
      _rateController.text = item.rate.toString();

      // ✅ IMPORTANT FIX → always compute instead of trusting stored amount
      _calculatedAmount = item.quantity * item.rate;

      String unit = item.unit.toUpperCase();
      if (!_uomList.contains(unit) && unit.isNotEmpty) {
        _uomList.add(unit);
      }
      _selectedUnit = unit.isNotEmpty ? unit : 'NOS';
    }

    _qtyController.addListener(_calculateAmount);
    _rateController.addListener(_calculateAmount);
  }

  void _calculateAmount() {
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    setState(() {
      _calculatedAmount = qty * rate;
    });
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();

    final qty = double.parse(_qtyController.text);
    final rate = double.parse(_rateController.text);

    final item = ExportInvoiceItem(
      id: widget.existingItem?.id ?? now.millisecondsSinceEpoch.toString(),
      companyId: widget.companyId,
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      hsnCode: _hsnController.text.trim(),
      quantity: qty,
      unit: _selectedUnit,
      rate: rate,

      // ✅ STRICT ERP LOGIC (no mismatch ever)
      amount: qty * rate,

      createdAt: widget.existingItem?.createdAt ?? now,
      createdBy: widget.existingItem?.createdBy ?? widget.userUid,
      updatedAt: now,
      updatedBy: widget.userUid,
    );

    Navigator.pop(context, item);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _hsnController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( // ✅ FIX OVERFLOW
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingItem == null
                          ? 'Add Export Item'
                          : 'Edit Export Item',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A3A52),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 16),

                // PRODUCT NAME
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // DESCRIPTION
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description of Goods',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                // HSN + UOM
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hsnController,
                        decoration: InputDecoration(
                          labelText: 'HSN Code',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Unit / UOM *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _uomList
                            .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedUnit = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // QTY + RATE
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantity *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) =>
                        val == null || double.tryParse(val) == null
                            ? 'Invalid qty'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText:
                          'Price (${widget.selectedCurrency}) *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) =>
                        val == null || double.tryParse(val) == null
                            ? 'Invalid rate'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // AMOUNT BOX
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Line Amount:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${widget.selectedCurrency} ${_calculatedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3A52),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveItem,
                    child: Text(
                      widget.existingItem == null
                          ? 'Add Item'
                          : 'Update Item',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}