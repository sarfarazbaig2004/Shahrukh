import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/dispatch/services/dispatch_service.dart';

class DeliveredOrdersScreen extends StatelessWidget {
  DeliveredOrdersScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;
  final DispatchService _service = DispatchService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.challansStream(companyId: companyId),
      builder: (context, snapshot) {
        final docs =
            snapshot.data?.docs.where((doc) {
              return _text(doc.data()['status']).toLowerCase() == 'delivered';
            }).toList() ??
            [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Delivered Orders', '${docs.length} Delivered'),
            const SizedBox(height: 14),
            Expanded(
              child: Card(
                elevation: 0,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                    ? const Center(child: Text('No delivered orders found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final deliveredAt = data['deliveredAt'];
                          String date = '-';
                          if (deliveredAt is Timestamp) {
                            date = DateFormat(
                              'dd/MM/yyyy hh:mm a',
                            ).format(deliveredAt.toDate());
                          }

                          return ListTile(
                            leading: const Icon(
                              Icons.verified_outlined,
                              color: Color(0xFF15803D),
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
                              '${_text(data['customerName'], fallback: 'Customer')} • Delivered: $date',
                            ),
                            trailing: const Chip(
                              label: Text('Delivered'),
                              backgroundColor: Color(0xFFDCFCE7),
                              labelStyle: TextStyle(
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w800,
                              ),
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
            const Icon(Icons.done_all_outlined, color: Color(0xFF15803D)),
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
