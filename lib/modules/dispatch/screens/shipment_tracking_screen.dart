import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/dispatch/services/dispatch_service.dart';

class ShipmentTrackingScreen extends StatefulWidget {
  const ShipmentTrackingScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<ShipmentTrackingScreen> createState() => _ShipmentTrackingScreenState();
}

class _ShipmentTrackingScreenState extends State<ShipmentTrackingScreen> {
  final DispatchService _service = DispatchService();

  bool _isActive(Map<String, dynamic> data) {
    final status = _text(data['status']).toLowerCase();
    return status == 'challan_created' ||
        status == 'ready' ||
        status == 'in_transit';
  }

  Future<void> _updateShipment(String id, Map<String, dynamic> data) async {
    final transporter = TextEditingController(
      text: _text(data['transporterName']),
    );
    final vehicle = TextEditingController(text: _text(data['vehicleNumber']));
    final lr = TextEditingController(text: _text(data['lrNumber']));
    final remarks = TextEditingController(text: _text(data['trackingRemarks']));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Shipment'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(transporter, 'Transporter Name'),
                    _field(vehicle, 'Vehicle Number'),
                    _field(lr, 'LR / Receipt No.'),
                    _field(remarks, 'Tracking Remarks', maxLines: 3),
                  ],
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
                            await _service.updateShipment(
                              companyId: widget.companyId,
                              challanId: id,
                              transporterName: transporter.text,
                              vehicleNumber: vehicle.text,
                              lrNumber: lr.text,
                              trackingRemarks: remarks.text,
                            );

                            if (!context.mounted) return;
                            Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  icon: const Icon(Icons.route_outlined),
                  label: Text(saving ? 'Saving...' : 'Update'),
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
    remarks.dispose();
  }

  Future<void> _markDelivered(String id) async {
    final deliveredTo = TextEditingController();
    final podRemarks = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Mark Delivered'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(deliveredTo, 'Delivered To'),
                    _field(podRemarks, 'POD / Delivery Remarks', maxLines: 3),
                  ],
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
                            await _service.markDelivered(
                              companyId: widget.companyId,
                              challanId: id,
                              deliveredTo: deliveredTo.text,
                              podRemarks: podRemarks.text,
                            );

                            if (!context.mounted) return;
                            Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  icon: const Icon(Icons.done_all_outlined),
                  label: Text(saving ? 'Saving...' : 'Delivered'),
                ),
              ],
            );
          },
        );
      },
    );

    deliveredTo.dispose();
    podRemarks.dispose();
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
      stream: _service.challansStream(companyId: widget.companyId),
      builder: (context, snapshot) {
        final docs =
            snapshot.data?.docs
                .where((doc) => _isActive(doc.data()))
                .toList() ??
            [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Shipment Tracking', '${docs.length} Active'),
            const SizedBox(height: 14),
            Expanded(
              child: Card(
                elevation: 0,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                    ? const Center(child: Text('No active shipments.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();

                          return ListTile(
                            leading: const Icon(
                              Icons.route_outlined,
                              color: Color(0xFFFF6A00),
                            ),
                            title: Text(
                              _text(
                                data['dispatchChallanNumber'],
                                fallback: 'Dispatch Challan',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${_text(data['customerName'], fallback: 'Customer')} • Vehicle: ${_text(data['vehicleNumber'], fallback: '-')}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _updateShipment(doc.id, data),
                                  icon: const Icon(Icons.edit_road_outlined),
                                  label: const Text('Update'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _markDelivered(doc.id),
                                  icon: const Icon(Icons.done_all_outlined),
                                  label: const Text('Delivered'),
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

  Widget _header(String title, String count) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: Color(0xFFFF6A00)),
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

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
