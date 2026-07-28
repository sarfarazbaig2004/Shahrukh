import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/purchase_rfq_model.dart';
import '../models/rfq_status.dart';
import '../services/rfq_search_service.dart';

/// Reusable RFQ search field that displays ranked suggestions while typing.
///
/// The caller owns the RFQ list and is notified via [onSelected] and
/// [onQueryChanged]. This widget does not fetch Firestore data.
class RfqSearchField extends StatefulWidget {
  const RfqSearchField({
    super.key,
    required this.rfqs,
    this.selectedRfq,
    required this.onSelected,
    this.onQueryChanged,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.suggestionLimit = 10,
  });

  final List<PurchaseRfq> rfqs;
  final PurchaseRfq? selectedRfq;
  final ValueChanged<PurchaseRfq> onSelected;
  final ValueChanged<String>? onQueryChanged;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final int suggestionLimit;

  @override
  State<RfqSearchField> createState() => _RfqSearchFieldState();
}

class _RfqSearchFieldState extends State<RfqSearchField> {
  static final _dateFormat = DateFormat('d MMM yyyy');
  final _searchService = const RfqSearchService();

  String _displayString(PurchaseRfq? rfq) {
    if (rfq == null) return '';
    return '${rfq.rfqNumber} — ${rfq.title}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<PurchaseRfq>(
      initialValue: TextEditingValue(text: _displayString(widget.selectedRfq)),
      displayStringForOption: (rfq) => rfq.rfqNumber,
      optionsBuilder: (textEditingValue) {
        return _searchService.getSuggestions(
          rfqs: widget.rfqs,
          query: textEditingValue.text,
          limit: widget.suggestionLimit,
        );
      },
      onSelected: widget.onSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  focusNode.unfocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                enabled: widget.enabled,
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) => widget.onQueryChanged?.call(value),
                onFieldSubmitted: (_) => onFieldSubmitted(),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(kAppRadiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 320),
              child: options.isEmpty
                  ? _NoResults(theme: theme)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final rfq = options.elementAt(index);
                        return _SuggestionTile(
                          rfq: rfq,
                          dateFormat: _dateFormat,
                          onSelected: () => onSelected(rfq),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.rfq,
    required this.dateFormat,
    required this.onSelected,
  });

  final PurchaseRfq rfq;
  final DateFormat dateFormat;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ListTile(
      dense: true,
      onTap: onSelected,
      title: Text(
        rfq.rfqNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rfq.title.isNotEmpty)
            Text(
              rfq.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          _buildMetaLine(textTheme),
          if (rfq.requiredDeliveryDate != null)
            Text(
              'Required by: ${dateFormat.format(rfq.requiredDeliveryDate!)}',
              style: textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildMetaLine(TextTheme textTheme) {
    final parts = <String>[
      if (rfq.purchaseRequisitionNumber != null &&
          rfq.purchaseRequisitionNumber!.trim().isNotEmpty)
        'PR: ${rfq.purchaseRequisitionNumber!.trim()}',
      rfq.status.displayLabel,
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodySmall,
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: [
          Icon(
            Icons.search_off,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No RFQ found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
