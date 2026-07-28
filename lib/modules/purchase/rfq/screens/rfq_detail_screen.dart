import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/purchase_rfq_model.dart';
import '../models/rfq_status.dart';
import 'rfq_form_screen.dart';

class RfqDetailScreen extends StatelessWidget {
  const RfqDetailScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    required this.rfq,
  });

  final String companyId;
  final String userUid;
  final PurchaseRfq rfq;

  static final _dateFormat = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(rfq.rfqNumber),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RfqFormScreen(
                    companyId: companyId,
                    userUid: userUid,
                    rfq: rfq,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 16),
                _section(context, 'RFQ Details', [
                  _row('Title', rfq.title),
                  _row('Description', rfq.description),
                  _row('RFQ Date', _formatDate(rfq.rfqDate)),
                  _row(
                    'Submission Deadline',
                    _formatDate(rfq.submissionDeadline),
                  ),
                  _row(
                    'Required Delivery Date',
                    _formatDate(rfq.requiredDeliveryDate),
                  ),
                  _row('Status', rfq.status.displayLabel),
                  _row('Currency', rfq.currency),
                  _row('Purchase Requisition', rfq.purchaseRequisitionNumber),
                  _row('Department', rfq.departmentId),
                  _row('Project', rfq.projectId),
                  _row('Cost Center', rfq.costCenterId),
                  _row('Assigned Buyer', rfq.assignedBuyerName),
                  _row('Delivery Location', rfq.deliveryLocation),
                  _row('Delivery Address', rfq.deliveryAddress),
                ]),
                _section(context, 'Items', _itemRows(context)),
                _section(context, 'Vendors', _vendorRows(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: zBlueSoft,
                borderRadius: BorderRadius.circular(kAppRadiusMd),
              ),
              child: const Icon(
                Icons.request_quote_outlined,
                color: zBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rfq.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rfq.rfqNumber} • ${rfq.items.length} item${rfq.items.length == 1 ? '' : 's'} • ${rfq.vendors.length} vendor${rfq.vendors.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _StatusChip(status: rfq.status),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final effective = children.where((widget) {
      if (widget is _DetailRow) return widget.value.isNotEmpty;
      return true;
    }).toList();

    if (effective.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),
            Wrap(spacing: 24, runSpacing: 18, children: effective),
          ],
        ),
      ),
    );
  }

  List<Widget> _itemRows(BuildContext context) {
    return [
      for (final item in rfq.items)
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (item.itemCode != null && item.itemCode!.isNotEmpty)
                    'Code: ${item.itemCode}',
                  '${item.quantity} ${item.unit}',
                  if (item.requiredDeliveryDate != null)
                    'Required by: ${_formatDate(item.requiredDeliveryDate!)}',
                  if (item.deliveryLocation != null &&
                      item.deliveryLocation!.isNotEmpty)
                    'Location: ${item.deliveryLocation}',
                  if (item.preferredBrand != null &&
                      item.preferredBrand!.isNotEmpty)
                    'Brand: ${item.preferredBrand}',
                  if (item.makeOrModel != null && item.makeOrModel!.isNotEmpty)
                    'Make/Model: ${item.makeOrModel}',
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.description != null && item.description!.isNotEmpty)
                Text('Description: ${item.description}'),
              if (item.specification != null && item.specification!.isNotEmpty)
                Text('Specification: ${item.specification}'),
              if (item.remarks != null && item.remarks!.isNotEmpty)
                Text('Remarks: ${item.remarks}'),
            ],
          ),
        ),
    ];
  }

  List<Widget> _vendorRows(BuildContext context) {
    if (rfq.vendors.isEmpty) {
      return [
        Text(
          'No vendors invited yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }
    return [
      for (final vendor in rfq.vendors)
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendor.vendorName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (vendor.vendorCode != null &&
                      vendor.vendorCode!.isNotEmpty)
                    'Code: ${vendor.vendorCode}',
                  if (vendor.contactPerson != null &&
                      vendor.contactPerson!.isNotEmpty)
                    vendor.contactPerson!,
                  if (vendor.email != null && vendor.email!.isNotEmpty)
                    vendor.email!,
                  if (vendor.phone != null && vendor.phone!.isNotEmpty)
                    vendor.phone!,
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (vendor.isSelected)
                Text(
                  'Selected',
                  style: TextStyle(
                    color: zSuccess,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _row(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return _DetailRow(label: label, value: text);
  }

  static String _formatDate(DateTime? date) =>
      date == null ? '-' : _dateFormat.format(date);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RfqStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      RfqStatus.draft => (zSurfaceSoft, zText),
      RfqStatus.pendingApproval => (zWarningSoft, zWarning),
      RfqStatus.approved || RfqStatus.sent => (zSuccessSoft, zSuccess),
      RfqStatus.partiallyResponded ||
      RfqStatus.responded ||
      RfqStatus.underEvaluation => (zInfoSoft, zInfo),
      RfqStatus.vendorSelected ||
      RfqStatus.convertedToPO ||
      RfqStatus.closed => (zPurpleSoft, zPurple),
      RfqStatus.rejected || RfqStatus.cancelled => (zDangerSoft, zDanger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
