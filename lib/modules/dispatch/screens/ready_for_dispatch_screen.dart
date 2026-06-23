import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/dispatch/services/dispatch_service.dart';

class ReadyForDispatchScreen extends StatefulWidget {
  const ReadyForDispatchScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<ReadyForDispatchScreen> createState() => _ReadyForDispatchScreenState();
}

class _ReadyForDispatchScreenState extends State<ReadyForDispatchScreen> {
  final DispatchService _service = DispatchService();
  final NumberFormat _currency = NumberFormat.currency(
    symbol: '₹',
    locale: 'en_IN',
    decimalDigits: 0,
  );

  bool _isReady(Map<String, dynamic> data) {
    final status = _text(data['status']).toLowerCase();
    final approvalStatus = _text(data['approvalStatus']).toLowerCase();
    final dispatchStatus = _text(
      data['dispatchStatus'],
      fallback: 'pending',
    ).toLowerCase();

    if (dispatchStatus == 'packed' ||
        dispatchStatus == 'challan_created' ||
        dispatchStatus == 'shipped' ||
        dispatchStatus == 'in_transit' ||
        dispatchStatus == 'delivered') {
      return false;
    }

    return approvalStatus == 'approved' && status == 'confirmed';
  }

  Future<void> _createChallan(
    QueryDocumentSnapshot<Map<String, dynamic>> order,
  ) async {
    final warehouses = await _service.loadWarehouses(
      companyId: widget.companyId,
    );

    if (!mounted) return;

    if (warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create at least one active warehouse first.'),
        ),
      );
      return;
    }

    var selectedWarehouse = warehouses.first;
    final transporter = TextEditingController();
    final vehicle = TextEditingController();
    final lr = TextEditingController();
    final packing = TextEditingController();
    final remarks = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Dispatch Challan'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedWarehouse.id,
                        decoration: const InputDecoration(
                          labelText: 'Warehouse',
                          border: OutlineInputBorder(),
                        ),
                        items: warehouses
                            .map(
                              (warehouse) => DropdownMenuItem<String>(
                                value: warehouse.id,
                                child: Text(warehouse.name),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (id) {
                                if (id == null) return;
                                final matched = warehouses.firstWhere(
                                  (warehouse) => warehouse.id == id,
                                  orElse: () => selectedWarehouse,
                                );
                                setDialogState(() {
                                  selectedWarehouse = matched;
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      _field(transporter, 'Transporter Name'),
                      _field(vehicle, 'Vehicle Number'),
                      _field(lr, 'LR / Receipt No.'),
                      _field(packing, 'Packing Details', maxLines: 2),
                      _field(remarks, 'Remarks', maxLines: 2),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            final challanNo = await _service
                                .createDispatchChallan(
                                  companyId: widget.companyId,
                                  salesOrderId: order.id,
                                  createdBy: widget.userUid,
                                  warehouseId: selectedWarehouse.id,
                                  warehouseName: selectedWarehouse.name,
                                  transporterName: transporter.text,
                                  vehicleNumber: vehicle.text,
                                  lrNumber: lr.text,
                                  packingDetails: packing.text,
                                  remarks: remarks.text,
                                );

                            if (!context.mounted) return;
                            Navigator.pop(context);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Dispatch challan created: $challanNo',
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Bad state: ', ''),
                                ),
                              ),
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_shipping_outlined),
                  label: Text(saving ? 'Creating...' : 'Create Challan'),
                ),
              ],
            );
          },
        );
      },
    );

    transporter.dispose();
    vehicle.dispose();
    lr.dispose();
    packing.dispose();
    remarks.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.salesOrdersStream(companyId: widget.companyId),
      builder: (context, snapshot) {
        final orders =
            snapshot.data?.docs.where((doc) => _isReady(doc.data())).toList() ??
            [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(
              'Ready for Dispatch',
              '${orders.length} Orders',
              Icons.outbox_outlined,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Card(
                elevation: 0,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : orders.isEmpty
                    ? const Center(
                        child: Text('No confirmed orders ready for dispatch.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final doc = orders[index];
                          final data = doc.data();
                          final soNo = _text(
                            data['salesOrderNumber'] ??
                                data['soNumber'] ??
                                data['orderNumber'],
                            fallback: 'Sales Order',
                          );
                          final customer = _text(
                            data['customerName'] ??
                                data['clientName'] ??
                                data['partyName'],
                            fallback: 'Customer',
                          );
                          final amount = _toDouble(
                            data['grandTotal'] ?? data['totalAmount'],
                          );
                          final itemCount = _itemCount(data);

                          return ListTile(
                            leading: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFFFF6A00),
                            ),
                            title: Text(
                              soNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '$customer • $itemCount item${itemCount == 1 ? '' : 's'}',
                            ),
                            trailing: Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _currency.format(amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _createChallan(doc),
                                  icon: const Icon(
                                    Icons.local_shipping_outlined,
                                  ),
                                  label: const Text('Create Challan'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(String title, String count, IconData icon) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6A00)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Chip(label: Text(count)),
          ],
        ),
      ),
    );
  }

  int _itemCount(Map<String, dynamic> data) {
    final items = data['items'] ?? data['products'];
    if (items is List) return items.length;
    return 0;
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
