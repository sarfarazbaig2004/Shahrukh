import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/models/inquiry_activity.dart';
import '../inquiry_activity_service.dart';

class InquiryActivityTimeline extends StatefulWidget {
  const InquiryActivityTimeline({
    super.key,
    required this.companyId,
    required this.inquiryId,
    required this.legacyStatus,
    this.onViewRelatedDocument,
  });

  final String companyId;
  final String inquiryId;
  final String legacyStatus;
  final ValueChanged<InquiryActivity>? onViewRelatedDocument;

  @override
  State<InquiryActivityTimeline> createState() =>
      _InquiryActivityTimelineState();
}

class _InquiryActivityTimelineState extends State<InquiryActivityTimeline> {
  late final InquiryActivityService _service;
  late final Stream<List<InquiryActivity>> _activities;

  @override
  void initState() {
    super.initState();
    _service = InquiryActivityService();
    _activities = _service.watchActivities(
      companyId: widget.companyId,
      inquiryId: widget.inquiryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InquiryActivity>>(
      stream: _activities,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message(
            Icons.error_outline,
            'Activity timeline is temporarily unavailable.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final activities = snapshot.data!;
        if (activities.isEmpty) {
          return _message(
            Icons.timeline_outlined,
            'No activity recorded yet. Current status: '
            '${widget.legacyStatus.trim().isEmpty ? 'Open' : widget.legacyStatus}.',
          );
        }
        return Column(
          children: activities.map((activity) {
            final canView =
                (activity.relatedDocumentId?.isNotEmpty ?? false) &&
                const {
                  'quotation',
                  'proforma',
                }.contains(activity.relatedDocumentType) &&
                widget.onViewRelatedDocument != null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        _icon(activity.type),
                        size: 17,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (activity.relatedDocumentNumber?.isNotEmpty ??
                              false)
                            Text(
                              '${_documentLabel(activity.relatedDocumentType)}: '
                              '${activity.relatedDocumentNumber}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (activity.previousStatus != null ||
                              activity.newStatus != null)
                            Text(
                              '${activity.previousStatus ?? '-'} → '
                              '${activity.newStatus ?? '-'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (activity.description?.isNotEmpty ?? false)
                            Text(
                              activity.description!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${activity.createdByName.isEmpty ? 'Unknown user' : activity.createdByName}'
                            ' • ${activity.createdAt == null ? 'Time pending' : DateFormat('dd MMM yyyy, h:mm a').format(activity.createdAt!.toLocal())}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (canView)
                            TextButton.icon(
                              onPressed: () =>
                                  widget.onViewRelatedDocument!(activity),
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: Text(
                                'View ${_documentLabel(activity.relatedDocumentType)}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _message(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    ),
  );

  static String _documentLabel(String? type) {
    switch (type) {
      case 'quotation':
        return 'Quotation';
      case 'proforma':
        return 'Proforma';
      case 'sales_order':
        return 'Sales Order';
      default:
        return 'Document';
    }
  }

  static IconData _icon(String type) {
    if (type.contains('quotation')) return Icons.request_quote_outlined;
    if (type.contains('proforma')) return Icons.receipt_long_outlined;
    if (type.contains('sales_order') || type == 'inquiry_converted') {
      return Icons.shopping_bag_outlined;
    }
    if (type == 'follow_up_added') return Icons.event_repeat_outlined;
    if (type == 'inquiry_assigned') return Icons.person_add_alt_outlined;
    if (type.contains('status') ||
        type == 'inquiry_closed' ||
        type == 'inquiry_lost') {
      return Icons.sync_alt;
    }
    return Icons.info_outline;
  }
}
