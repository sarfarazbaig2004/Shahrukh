import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_quotation_models.dart';

class ServiceItemsSection extends StatefulWidget {
  final List<QuotationLineItem> lineItems;
  final List<VisitCharge> visitCharges;
  final ValueChanged<List<QuotationLineItem>> onItemsChanged;
  final ValueChanged<List<VisitCharge>> onVisitChargesChanged;
  final bool isReadOnly;

  // Context Parameters for Inventory Compatibility
  final String? companyId;
  final String? categoryId; // Preserved for constructor compatibility
  final String? subcategoryId; // Preserved for constructor compatibility
  final String? selectedMachineModel;
  final String? machineSerialNumber;
  final String? machineWarrantyStatus;

  const ServiceItemsSection({
    super.key,
    required this.lineItems,
    required this.visitCharges,
    required this.onItemsChanged,
    required this.onVisitChargesChanged,
    this.isReadOnly = false,
    this.companyId,
    this.categoryId,
    this.subcategoryId,
    this.selectedMachineModel,
    this.machineSerialNumber,
    this.machineWarrantyStatus,
  });

  @override
  State<ServiceItemsSection> createState() => _ServiceItemsSectionState();
}

class _ServiceItemsSectionState extends State<ServiceItemsSection> {
  String? _resolvedCompanyId;
  bool _showChargeForm = false;

  // Inline Charge Form State
  String _chargeType = 'Service Charge';
  final _chargeDescCtrl = TextEditingController();
  final _chargeAmtCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCompanyId();
  }

  @override
  void dispose() {
    _chargeDescCtrl.dispose();
    _chargeAmtCtrl.dispose();
    super.dispose();
  }

  Future<void> _initCompanyId() async {
    if (widget.companyId != null) {
      _resolvedCompanyId = widget.companyId;
      if (mounted) setState(() {});
      return;
    }
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
        if (mounted) {
          setState(() {
            _resolvedCompanyId = doc.data()?['companyId']?.toString();
          });
        }
      } catch (_) {}
    }
  }

  double get _itemsSubtotal => widget.lineItems.where((i) => !['Service Charge', 'Other Charge'].contains(i.itemType)).fold(0.0, (sum, item) => sum + item.amount);
  double get _chargesTotal => widget.lineItems.where((i) => ['Service Charge', 'Other Charge'].contains(i.itemType)).fold(0.0, (sum, item) => sum + item.amount);
  double get _visitsTotal => widget.visitCharges.fold(0.0, (sum, charge) => sum + charge.amount);
  double get _totalBeforeTax => _itemsSubtotal + _chargesTotal + _visitsTotal;
  int get _totalItemsCount => widget.lineItems.length + widget.visitCharges.length;

  void _addInlineCharge() {
    final desc = _chargeDescCtrl.text.trim();
    final amt = double.tryParse(_chargeAmtCtrl.text) ?? 0.0;

    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a description.')));
      return;
    }
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
      return;
    }

    if (_chargeType == 'Visit Charge') {
      final updated = List<VisitCharge>.from(widget.visitCharges);
      updated.add(VisitCharge(description: desc, qty: 1.0, rate: amt, amount: amt));
      widget.onVisitChargesChanged(updated);
    } else {
      final updated = List<QuotationLineItem>.from(widget.lineItems);
      updated.add(QuotationLineItem(
        itemId: DateTime.now().millisecondsSinceEpoch.toString(),
        itemName: desc,
        itemType: _chargeType,
        partNo: '-',
        qty: 1.0,
        rate: amt,
        amount: amt,
        discount: 0.0,
        hsnCode: '-',
        uom: '-',
      ));
      widget.onItemsChanged(updated);
    }

    _chargeDescCtrl.clear();
    _chargeAmtCtrl.clear();

    // Auto-collapse charge form after adding
    setState(() {
      _showChargeForm = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMachineHeader(),
        _buildLineItemsCard(context),
      ],
    );
  }

  Widget _buildMachineHeader() {
    if (widget.selectedMachineModel == null || widget.selectedMachineModel!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.precision_manufacturing, color: Colors.blueGrey.shade700, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _machineDetailItem('Machine Model', widget.selectedMachineModel!),
                _machineDetailItem('Serial Number', widget.machineSerialNumber?.isNotEmpty == true ? widget.machineSerialNumber! : '-'),
                _machineDetailItem('Warranty Status', widget.machineWarrantyStatus?.isNotEmpty == true ? widget.machineWarrantyStatus! : '-'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _machineDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildLineItemsCard(BuildContext context) {
    final hasMachine = widget.selectedMachineModel != null && widget.selectedMachineModel!.trim().isNotEmpty;

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
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_list_bulleted, color: Colors.indigo.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Items ($_totalItemsCount)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo.shade900),
                    ),
                  ],
                ),
                if (!widget.isReadOnly)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showChargeForm = !_showChargeForm;
                          });
                        },
                        icon: Icon(_showChargeForm ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 16),
                        label: const Text('Charges'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          side: BorderSide(color: Colors.indigo.shade200),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!hasMachine)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            'Please select machine model first',
                            style: TextStyle(color: Colors.red.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: hasMachine ? () => _showAddItemDialog(context) : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('Add Item'),
                        style: FilledButton.styleFrom(
                          backgroundColor: hasMachine ? Colors.indigo : Colors.grey.shade400,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Inline Charge Form (Collapsed by Default)
          if (_showChargeForm && !widget.isReadOnly)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _chargeType,
                      decoration: const InputDecoration(
                        labelText: 'Charge Type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ['Service Charge', 'Visit Charge', 'Other Charge']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _chargeType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _chargeDescCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _chargeAmtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _addInlineCharge,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Table
          if (widget.lineItems.isEmpty && widget.visitCharges.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No items or charges added yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade50),
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columns: const [
                  DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _buildAllRows(context),
              ),
            ),

          // Summary Row (Footer)
          if (widget.lineItems.isNotEmpty || widget.visitCharges.isNotEmpty)
            _buildSummaryRow(),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'spare': return Colors.orange.shade700;
      case 'accessory': return Colors.teal.shade700;
      case 'consumable': return Colors.green.shade700;
      case 'service charge': return Colors.blue.shade700;
      case 'visit charge': return Colors.purple.shade700;
      case 'other charge': return Colors.pink.shade700;
      default: return Colors.blueGrey.shade700;
    }
  }

  WidgetStateProperty<Color?> _getRowColor(String type) {
    return WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (type == 'Service Charge') return Colors.blue.shade50;
      if (type == 'Visit Charge') return Colors.purple.shade50;
      if (type == 'Other Charge') return Colors.pink.shade50;
      return null;
    });
  }

  Widget _wrapDoubleTap(Widget child, VoidCallback onDoubleTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.isReadOnly ? null : onDoubleTap,
      child: Container(
        alignment: Alignment.centerLeft,
        height: double.infinity,
        width: double.infinity,
        child: child,
      ),
    );
  }

  List<DataRow> _buildAllRows(BuildContext context) {
    List<DataRow> rows = [];

    // 1. Products & Service Line Items
    for (int i = 0; i < widget.lineItems.length; i++) {
      final item = widget.lineItems[i];
      final isCharge = ['Service Charge', 'Other Charge'].contains(item.itemType);

      final hasHsn = item.hsnCode != null && item.hsnCode!.isNotEmpty && item.hsnCode != '-';
      final hasPartNo = item.partNo != null && item.partNo!.isNotEmpty && item.partNo != '-';

      final onDoubleTap = () {
        if (isCharge) {
          _showAddChargeDialog(context, existingItem: item, index: i);
        } else {
          _showAddItemDialog(context, existingItem: item, index: i);
        }
      };

      rows.add(DataRow(
        color: _getRowColor(item.itemType),
        cells: [
          DataCell(_wrapDoubleTap(_buildTypeChip(item.itemType), onDoubleTap)),
          DataCell(
              _wrapDoubleTap(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (!isCharge && hasPartNo)
                      Text('PN: ${item.partNo}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    if (!isCharge && hasHsn)
                      Text('HSN: ${item.hsnCode}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                onDoubleTap,
              )
          ),
          DataCell(_wrapDoubleTap(Text(isCharge ? '-' : item.qty.toStringAsFixed(0)), onDoubleTap)),
          DataCell(_wrapDoubleTap(Text(item.rate.toStringAsFixed(2)), onDoubleTap)),
          DataCell(_wrapDoubleTap(Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)), onDoubleTap)),
          DataCell(
            widget.isReadOnly
                ? const SizedBox.shrink()
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                  onPressed: onDoubleTap,
                  splashRadius: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () {
                    final updated = List<QuotationLineItem>.from(widget.lineItems);
                    updated.removeAt(i);
                    widget.onItemsChanged(updated);
                  },
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ],
      ));
    }

    // 2. Visit Charges
    for (int i = 0; i < widget.visitCharges.length; i++) {
      final charge = widget.visitCharges[i];
      final onDoubleTap = () => _showAddChargeDialog(context, existingVisit: charge, index: i);

      rows.add(DataRow(
        color: _getRowColor('Visit Charge'),
        cells: [
          DataCell(_wrapDoubleTap(_buildTypeChip('Visit Charge'), onDoubleTap)),
          DataCell(_wrapDoubleTap(Text(charge.description, style: const TextStyle(fontWeight: FontWeight.w600)), onDoubleTap)),
          DataCell(_wrapDoubleTap(const Text('-'), onDoubleTap)),
          DataCell(_wrapDoubleTap(const Text('-'), onDoubleTap)),
          DataCell(_wrapDoubleTap(Text(charge.amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)), onDoubleTap)),
          DataCell(
            widget.isReadOnly
                ? const SizedBox.shrink()
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                  onPressed: onDoubleTap,
                  splashRadius: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () {
                    final updated = List<VisitCharge>.from(widget.visitCharges);
                    updated.removeAt(i);
                    widget.onVisitChargesChanged(updated);
                  },
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ],
      ));
    }

    return rows;
  }

  Widget _buildSummaryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildSummaryMetric('Items Total', _itemsSubtotal),
          const SizedBox(width: 32),
          _buildSummaryMetric('Charges Total', _chargesTotal),
          const SizedBox(width: 32),
          _buildSummaryMetric('Visit Total', _visitsTotal),
          const SizedBox(width: 32),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          const SizedBox(width: 32),
          _buildSummaryMetric('Grand Total Before GST', _totalBeforeTax, isGrand: true),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, double amount, {bool isGrand = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: isGrand ? 16 : 14, fontWeight: FontWeight.bold, color: isGrand ? Colors.indigo.shade900 : Colors.black87)),
      ],
    );
  }

  Widget _buildTypeChip(String type) {
    final color = _getTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2))
      ),
      child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _showAddItemDialog(BuildContext context, {QuotationLineItem? existingItem, int? index}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddItemDialog(
        companyId: _resolvedCompanyId,
        selectedMachineModel: widget.selectedMachineModel,
        lineItems: widget.lineItems,
        onItemsChanged: widget.onItemsChanged,
        existingItem: existingItem,
        index: index,
        getTypeColor: _getTypeColor,
      ),
    );
  }

  void _showAddChargeDialog(BuildContext context, {QuotationLineItem? existingItem, VisitCharge? existingVisit, int? index}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddChargeDialog(
        lineItems: widget.lineItems,
        visitCharges: widget.visitCharges,
        onItemsChanged: widget.onItemsChanged,
        onVisitChargesChanged: widget.onVisitChargesChanged,
        existingItem: existingItem,
        existingVisit: existingVisit,
        index: index,
      ),
    );
  }
}

// ==========================================
// 1. ADD / EDIT ITEM DIALOG (Strict Products)
// ==========================================

class _AddItemDialog extends StatefulWidget {
  final String? companyId;
  final String? selectedMachineModel;
  final List<QuotationLineItem> lineItems;
  final ValueChanged<List<QuotationLineItem>> onItemsChanged;
  final QuotationLineItem? existingItem;
  final int? index;
  final Color Function(String) getTypeColor;

  const _AddItemDialog({
    required this.companyId,
    required this.selectedMachineModel,
    required this.lineItems,
    required this.onItemsChanged,
    required this.getTypeColor,
    this.existingItem,
    this.index,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();

  String _selectedType = 'Spare';
  String _searchQuery = '';
  String? _selectedProductId;
  Map<String, dynamic>? _selectedProductData;
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoadingProducts = false;

  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController(text: '0');

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _selectedType = item.itemType;
      _qtyCtrl.text = item.qty.toString();
      _rateCtrl.text = item.rate.toString();

      _selectedProductData = {
        'id': item.itemId,
        'name': item.itemName,
        'partNo': item.partNo,
        'hsnCode': item.hsnCode,
        'uom': item.uom,
        'unitPrice': item.rate,
      };
      _selectedProductId = item.itemId;
    }

    _fetchCompatibleProducts();
  }

  Future<void> _fetchCompatibleProducts() async {
    if (widget.companyId == null) return;
    setState(() => _isLoadingProducts = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('productNatureLower', isEqualTo: _selectedType.toLowerCase());

      // Consumables have no compatibility mapping in Product Master schema.
      // Spares and Accessories use compatibleProductNames array.
      if ((_selectedType == 'Spare' || _selectedType == 'Accessory') &&
          widget.selectedMachineModel != null &&
          widget.selectedMachineModel!.isNotEmpty) {
        query = query.where('compatibleProductNames', arrayContains: widget.selectedMachineModel);
      }

      final snap = await query.get();

      List<Map<String, dynamic>> results = [];

      for (var doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        d['id'] = doc.id;
        results.add(d);
      }

      if (mounted) {
        setState(() {
          _filteredProducts = results;
          _isLoadingProducts = false;

          // Preserve selected item if editing and it's not in the filtered list
          if (_isEditing && _selectedProductId != null && !_filteredProducts.any((p) => p['id'] == _selectedProductId)) {
            if (_selectedProductData != null) {
              _filteredProducts.insert(0, _selectedProductData!);
            }
          }

          // AUTO SELECT SINGLE PRODUCT
          if (!_isEditing && _filteredProducts.length == 1 && _selectedProductId == null) {
            _onProductSelected(_filteredProducts.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _onProductSelected(Map<String, dynamic> p) {
    setState(() {
      _selectedProductId = p['id'];
      _selectedProductData = p;
      _rateCtrl.text = (p['unitPrice'] ?? p['sellingPrice'] ?? 0).toString();
    });
  }

  void _changeQty(double delta) {
    double current = double.tryParse(_qtyCtrl.text) ?? 1.0;
    current += delta;
    if (current < 1) current = 1;
    _qtyCtrl.text = current.toStringAsFixed(0);
    setState(() {});
  }

  double get _calculatedAmount {
    double q = double.tryParse(_qtyCtrl.text) ?? 0.0;
    double r = double.tryParse(_rateCtrl.text) ?? 0.0;
    return q * r;
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a product.'), backgroundColor: Colors.red));
      return;
    }

    final q = double.tryParse(_qtyCtrl.text) ?? 1.0;
    final r = double.tryParse(_rateCtrl.text) ?? 0.0;
    final amt = q * r;
    final partNo = _selectedProductData!['partNo'] ?? _selectedProductData!['sku'] ?? _selectedProductData!['itemCode'] ?? '-';
    final hsnCode = _selectedProductData!['hsnCode']?.toString() ?? '-';
    final uom = _selectedProductData!['uom']?.toString() ?? '-';

    final updated = List<QuotationLineItem>.from(widget.lineItems);

    // Exact duplicate protection using both ID and Type
    final existingIdx = updated.indexWhere((i) => i.itemId == _selectedProductData!['id'] && i.itemType == _selectedType);

    if (existingIdx >= 0 && (!_isEditing || existingIdx != widget.index)) {
      // Merge with existing row to prevent duplicates
      final existing = updated[existingIdx];
      final newQty = existing.qty + q;
      final newAmt = newQty * r;

      updated[existingIdx] = QuotationLineItem(
        itemId: existing.itemId,
        itemName: existing.itemName,
        itemType: existing.itemType,
        partNo: existing.partNo,
        qty: newQty,
        rate: r,
        amount: newAmt,
        discount: existing.discount,
        hsnCode: existing.hsnCode,
        uom: existing.uom,
      );

      if (_isEditing && widget.index != null) {
        updated.removeAt(widget.index!);
      }
    } else if (_isEditing) {
      // Update existing item safely
      updated[widget.index!] = QuotationLineItem(
        itemId: _selectedProductData!['id'],
        itemName: _selectedProductData!['name'] ?? '',
        itemType: _selectedType,
        partNo: partNo,
        qty: q,
        rate: r,
        amount: amt,
        discount: widget.existingItem!.discount,
        hsnCode: hsnCode,
        uom: uom,
      );
    } else {
      // Add brand new item
      updated.add(QuotationLineItem(
        itemId: _selectedProductData!['id'],
        itemName: _selectedProductData!['name'] ?? '',
        itemType: _selectedType,
        partNo: partNo,
        qty: q,
        rate: r,
        amount: amt,
        discount: 0.0,
        hsnCode: hsnCode,
        uom: uom,
      ));
    }

    widget.onItemsChanged(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = widget.getTypeColor(_selectedType);
    final displayedProducts = _filteredProducts.where((p) {
      if (p['id'] == _selectedProductId) return true; // Ensure selected item remains in list
      if (_searchQuery.isEmpty) return true;
      final name = (p['name'] ?? '').toString().toLowerCase();
      final partNo = (p['partNo'] ?? p['sku'] ?? p['itemCode'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || partNo.contains(_searchQuery);
    }).toList();

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Item' : 'Add Item'),
      content: SizedBox(
        width: 600,
        height: 600,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Type Selection Cards
              Row(
                children: ['Spare', 'Accessory', 'Consumable'].map((type) {
                  final isSelected = _selectedType == type;
                  final color = widget.getTypeColor(type);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                          _selectedProductId = null;
                          _selectedProductData = null;
                          _rateCtrl.text = '0';
                          _searchQuery = '';
                          _fetchCompatibleProducts();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
                          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            type,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? color : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              if (_isLoadingProducts)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_filteredProducts.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No compatible $_selectedType products found for ${widget.selectedMachineModel}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text('Please check Inventory -> Product Master\nand ensure products are mapped to this machine model.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Search Compatible Product',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: displayedProducts.length,
                        itemBuilder: (ctx, idx) {
                          final p = displayedProducts[idx];
                          final isSelected = p['id'] == _selectedProductId;
                          final price = double.tryParse(p['unitPrice']?.toString() ?? p['sellingPrice']?.toString() ?? '0') ?? 0.0;
                          final imageUrl = p['imageUrl']?.toString();
                          final stock = double.tryParse(p['stockOnHand']?.toString() ?? p['qty']?.toString() ?? '0') ?? 0.0;

                          return InkWell(
                            onTap: () => _onProductSelected(p),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                color: isSelected ? typeColor.withValues(alpha: 0.1) : Colors.white,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  imageUrl != null && imageUrl.isNotEmpty
                                      ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey.shade100, child: const Icon(Icons.image_not_supported, color: Colors.grey))),
                                  )
                                      : Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Text('Part No: ${p['partNo'] ?? p['sku'] ?? p['itemCode'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                            Text('HSN: ${p['hsnCode'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                            Text(
                                                stock > 0 ? 'Stock: ${stock.toStringAsFixed(0)}' : 'Stock: 0 (Out of Stock)',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: stock > 0 ? Colors.blueGrey.shade700 : Colors.red.shade600
                                                )
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                      if (isSelected) ...[
                                        const SizedBox(height: 8),
                                        Icon(Icons.check_circle, color: typeColor, size: 20),
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

              if (_selectedProductData != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected Product', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_selectedProductData!['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Part No: ${_selectedProductData!['partNo'] ?? _selectedProductData!['sku'] ?? _selectedProductData!['itemCode'] ?? '-'} | HSN: ${_selectedProductData!['hsnCode'] ?? '-'} | UOM: ${_selectedProductData!['uom'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: typeColor,
                            onPressed: () => _changeQty(-1)
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _qtyCtrl,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => setState((){}),
                            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: typeColor,
                            onPressed: () => _changeQty(1)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      readOnly: true,
                      decoration: InputDecoration(labelText: 'Rate (₹)', border: const OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.grey.shade100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calculated Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('₹${_calculatedAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
            onPressed: _selectedProductData == null ? null : _saveItem,
            child: const Text('Save Item')
        ),
      ],
    );
  }
}

// ==========================================
// 2. ADD / EDIT CHARGE DIALOG (Preserved for existing edits)
// ==========================================

class _AddChargeDialog extends StatefulWidget {
  final List<QuotationLineItem> lineItems;
  final List<VisitCharge> visitCharges;
  final ValueChanged<List<QuotationLineItem>> onItemsChanged;
  final ValueChanged<List<VisitCharge>> onVisitChargesChanged;
  final QuotationLineItem? existingItem;
  final VisitCharge? existingVisit;
  final int? index;

  const _AddChargeDialog({
    required this.lineItems,
    required this.visitCharges,
    required this.onItemsChanged,
    required this.onVisitChargesChanged,
    this.existingItem,
    this.existingVisit,
    this.index,
  });

  @override
  State<_AddChargeDialog> createState() => _AddChargeDialogState();
}

class _AddChargeDialogState extends State<_AddChargeDialog> {
  final _formKey = GlobalKey<FormState>();

  String _selectedType = 'Service Charge';
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool get _isEditing => widget.existingItem != null || widget.existingVisit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      if (widget.existingVisit != null) {
        _selectedType = 'Visit Charge';
        _descCtrl.text = widget.existingVisit!.description;
        _amountCtrl.text = widget.existingVisit!.amount.toString();
      } else {
        _selectedType = widget.existingItem!.itemType;
        _descCtrl.text = widget.existingItem!.itemName;
        _amountCtrl.text = widget.existingItem!.amount.toString();
      }
    }
  }

  void _saveCharge() {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    final desc = _descCtrl.text.trim();

    if (_selectedType == 'Visit Charge') {
      final updated = List<VisitCharge>.from(widget.visitCharges);
      if (_isEditing) updated.removeAt(widget.index!);
      updated.add(VisitCharge(description: desc, qty: 1.0, rate: amt, amount: amt));
      widget.onVisitChargesChanged(updated);
    } else {
      final updated = List<QuotationLineItem>.from(widget.lineItems);
      if (_isEditing) updated.removeAt(widget.index!);
      updated.add(QuotationLineItem(
        itemId: _isEditing ? widget.existingItem!.itemId : DateTime.now().millisecondsSinceEpoch.toString(),
        itemName: desc,
        itemType: _selectedType,
        partNo: '-',
        qty: 1.0,
        rate: amt,
        amount: amt,
        discount: 0.0,
        hsnCode: '-',
        uom: '-',
      ));
      widget.onItemsChanged(updated);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Charge' : 'Add Charge'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Charge Type', border: OutlineInputBorder()),
                items: ['Service Charge', 'Visit Charge', 'Other Charge'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: _isEditing ? null : (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Amount (₹) *', border: OutlineInputBorder()),
                validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid Amount' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saveCharge, child: const Text('Save Charge')),
      ],
    );
  }
}