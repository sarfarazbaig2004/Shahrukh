import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/dispatch/services/dispatch_service.dart';

class DispatchChallansScreen extends StatelessWidget {
  DispatchChallansScreen({
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
        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Dispatch Challans', '${docs.length} Challans'),
            const SizedBox(height: 14),
            Expanded(
              child: Card(
                elevation: 0,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                    ? const Center(child: Text('No dispatch challans found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          return ListTile(
                            leading: const Icon(
                              Icons.receipt_long_outlined,
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
                              '${_text(data['customerName'], fallback: 'Customer')} • SO: ${_text(data['salesOrderNumber'], fallback: '-')}',
                            ),
                            trailing: Chip(
                              label: Text(
                                _text(data['statusLabel'], fallback: 'Pending'),
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
            const Icon(Icons.assignment_outlined, color: Color(0xFFFF6A00)),
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
