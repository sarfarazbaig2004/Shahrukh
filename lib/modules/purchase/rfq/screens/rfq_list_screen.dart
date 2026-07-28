import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/purchase_rfq_model.dart';
import '../models/rfq_status.dart';
import '../services/rfq_search_service.dart';
import '../services/rfq_service.dart';
import '../widgets/rfq_search_field.dart';
import 'rfq_detail_screen.dart';
import 'rfq_form_screen.dart';

class RfqListScreen extends StatefulWidget {
  const RfqListScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<RfqListScreen> createState() => _RfqListScreenState();
}

class _RfqListScreenState extends State<RfqListScreen> {
  final _service = RfqService();
  final _searchService = const RfqSearchService();
  final _dateFormat = DateFormat('d MMM yyyy');
  StreamSubscription<List<PurchaseRfq>>? _rfqsSubscription;

  List<PurchaseRfq> _rfqs = const [];
  List<PurchaseRfq> _filtered = const [];
  String _statusFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRfqs();
  }

  @override
  void dispose() {
    _rfqsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRfqs() async {
    final companyId = widget.companyId;
    final userUid = widget.userUid;
    final path = 'companies/$companyId/purchase_rfqs';

    debugPrint('=== RFQ List Load Started ===');
    debugPrint('RFQ companyId: ${companyId.isEmpty ? '[EMPTY]' : companyId}');
    debugPrint('RFQ userUid: ${userUid.isEmpty ? '[EMPTY]' : userUid}');
    debugPrint('RFQ Firestore collection path: $path');
    debugPrint('RFQ query: .snapshots() (client-side filter + sort)');

    if (companyId.isEmpty) {
      debugPrint('RFQ ERROR: companyId is empty. RFQs cannot be loaded without a company scope.');
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load RFQs. Company is not selected.';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      _rfqsSubscription?.cancel();
      _rfqsSubscription = _service
          .watchRfqs(companyId)
          .listen(
            (rfqs) {
              debugPrint('RFQ snapshot received: ${rfqs.length} active RFQ(s)');
              if (!mounted) return;
              setState(() {
                _rfqs = rfqs;
                _applyFilters();
                _isLoading = false;
              });
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('RFQ stream error: $error');
              debugPrint('RFQ stackTrace: $stackTrace');
              if (!mounted) return;
              setState(() {
                _errorMessage = _friendlyError(error);
                _isLoading = false;
              });
            },
          );
    } catch (error, stackTrace) {
      debugPrint('RFQ load catch error: $error');
      debugPrint('RFQ load catch stackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyError(error);
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final suggestions = _searchService.getSuggestions(
      rfqs: _rfqs,
      query: _searchQuery,
      limit: _rfqs.length,
    );
    if (_statusFilter == 'All') {
      _filtered = suggestions;
      return;
    }
    final statusValue = _statusFilter.toLowerCase().replaceAll(' ', '');
    _filtered = suggestions
        .where((rfq) {
          return rfq.status.firestoreValue.toLowerCase() == statusValue ||
              rfq.status.displayLabel.toLowerCase() ==
                  _statusFilter.toLowerCase();
        })
        .toList(growable: false);
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      debugPrint('RFQ friendly error: permission-denied');
      return 'Access denied. You do not have permission to view RFQs.';
    }
    if (message.contains('failed-precondition')) {
      debugPrint('RFQ friendly error: failed-precondition (missing Firestore index?)');
      return 'Unable to load RFQs. A required Firestore index may be missing.';
    }
    if (message.contains('unavailable') ||
        message.contains('network-request-failed')) {
      debugPrint('RFQ friendly error: network');
      return 'Network error. Please check your connection.';
    }
    return 'Unable to load RFQs. Please try again.';
  }

  Future<void> _openForm([PurchaseRfq? rfq]) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RfqFormScreen(
          companyId: widget.companyId,
          userUid: widget.userUid,
          rfq: rfq,
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rfq == null
                ? 'RFQ created successfully.'
                : 'RFQ updated successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _viewRfq(PurchaseRfq rfq) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RfqDetailScreen(
          companyId: widget.companyId,
          userUid: widget.userUid,
          rfq: rfq,
        ),
      ),
    );
  }

  Future<void> _softDelete(PurchaseRfq rfq) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete RFQ?'),
        content: Text('This will delete RFQ ${rfq.rfqNumber}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.softDeleteRfq(
        companyId: widget.companyId,
        rfqId: rfq.id,
        userUid: widget.userUid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RFQ ${rfq.rfqNumber} deleted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            backgroundColor: zDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _rfqs.isEmpty && !_isLoading) {
      return _errorView();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(_filtered.length),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    child: RfqSearchField(
                      rfqs: _rfqs,
                      onSelected: _viewRfq,
                      onQueryChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilters();
                        });
                      },
                      labelText: 'Search RFQs',
                      hintText: 'Number, title, PR, vendor, item...',
                    ),
                  ),
                  _statusDropdown(),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadRfqs,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading && _rfqs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? _empty(_rfqs.isEmpty)
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 800
                        ? _mobileList(_filtered)
                        : _desktopTable(_filtered),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RFQ', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 3),
              Text(
                '$count RFQ${count == 1 ? '' : 's'} in this view',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Create RFQ'),
        ),
      ],
    );
  }

  Widget _statusDropdown() {
    final statuses = [
      'All',
      ...RfqStatus.values.map((status) => status.displayLabel),
    ];
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        value: statuses.contains(_statusFilter) ? _statusFilter : 'All',
        decoration: const InputDecoration(labelText: 'Status'),
        items: statuses
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) {
          setState(() {
            _statusFilter = value ?? 'All';
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: zDanger),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadRfqs,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _empty(bool noData) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.request_quote_outlined, size: 48, color: zMuted),
          const SizedBox(height: 12),
          Text(
            noData ? 'No RFQs created yet' : 'No RFQs match the filters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            noData
                ? 'Create your first RFQ to start collecting vendor quotes.'
                : 'Try changing the search or filter values.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (noData) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Create RFQ'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopTable(List<PurchaseRfq> rfqs) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(zSurfaceSoft),
          columns: const [
            DataColumn(label: Text('RFQ Number')),
            DataColumn(label: Text('Title')),
            DataColumn(label: Text('RFQ Date')),
            DataColumn(label: Text('Submission Deadline')),
            DataColumn(label: Text('Required Delivery')),
            DataColumn(label: Text('PR Number')),
            DataColumn(label: Text('Assigned Buyer')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Vendors')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Last Updated')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rfqs
              .map(
                (rfq) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        rfq.rfqNumber,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataCell(Text(_dash(rfq.title))),
                    DataCell(Text(_formatDate(rfq.rfqDate))),
                    DataCell(Text(_formatDate(rfq.submissionDeadline))),
                    DataCell(Text(_formatDate(rfq.requiredDeliveryDate))),
                    DataCell(Text(_dash(rfq.purchaseRequisitionNumber))),
                    DataCell(Text(_dash(rfq.assignedBuyerName))),
                    DataCell(Text(rfq.items.length.toString())),
                    DataCell(Text(rfq.vendors.length.toString())),
                    DataCell(_statusChip(rfq.status)),
                    DataCell(Text(_formatDate(rfq.updatedAt ?? rfq.createdAt))),
                    DataCell(_actions(rfq)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _mobileList(List<PurchaseRfq> rfqs) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rfqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rfq = rfqs[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rfq.rfqNumber,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _statusChip(rfq.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rfq.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Divider(height: 22),
                _mobileRow('RFQ Date', _formatDate(rfq.rfqDate)),
                _mobileRow(
                  'Submission Deadline',
                  _formatDate(rfq.submissionDeadline),
                ),
                _mobileRow(
                  'Required Delivery',
                  _formatDate(rfq.requiredDeliveryDate),
                ),
                _mobileRow('PR Number', _dash(rfq.purchaseRequisitionNumber)),
                _mobileRow('Assigned Buyer', _dash(rfq.assignedBuyerName)),
                _mobileRow(
                  'Items / Vendors',
                  '${rfq.items.length} / ${rfq.vendors.length}',
                ),
                _mobileRow(
                  'Last Updated',
                  _formatDate(rfq.updatedAt ?? rfq.createdAt),
                ),
                Align(alignment: Alignment.centerRight, child: _actions(rfq)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(PurchaseRfq rfq) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View',
          onPressed: () => _viewRfq(rfq),
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          tooltip: 'Edit',
          onPressed: () => _openForm(rfq),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: () => _softDelete(rfq),
          icon: const Icon(Icons.delete_outline, color: zDanger),
        ),
      ],
    );
  }

  Widget _statusChip(RfqStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(
          color: _statusForeground(status),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _statusBackground(RfqStatus status) {
    switch (status) {
      case RfqStatus.draft:
        return zSurfaceSoft;
      case RfqStatus.pendingApproval:
        return zWarningSoft;
      case RfqStatus.approved:
      case RfqStatus.sent:
        return zSuccessSoft;
      case RfqStatus.partiallyResponded:
      case RfqStatus.responded:
      case RfqStatus.underEvaluation:
        return zInfoSoft;
      case RfqStatus.vendorSelected:
      case RfqStatus.convertedToPO:
      case RfqStatus.closed:
        return zPurpleSoft;
      case RfqStatus.rejected:
      case RfqStatus.cancelled:
        return zDangerSoft;
    }
  }

  Color _statusForeground(RfqStatus status) {
    switch (status) {
      case RfqStatus.draft:
        return zText;
      case RfqStatus.pendingApproval:
        return zWarning;
      case RfqStatus.approved:
      case RfqStatus.sent:
        return zSuccess;
      case RfqStatus.partiallyResponded:
      case RfqStatus.responded:
      case RfqStatus.underEvaluation:
        return zInfo;
      case RfqStatus.vendorSelected:
      case RfqStatus.convertedToPO:
      case RfqStatus.closed:
        return zPurple;
      case RfqStatus.rejected:
      case RfqStatus.cancelled:
        return zDanger;
    }
  }

  String _formatDate(DateTime? date) =>
      date == null ? '-' : _dateFormat.format(date);

  String _dash(String? value) => (value ?? '').trim().isEmpty ? '-' : value!;
}
