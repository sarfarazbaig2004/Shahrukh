import 'dart:async';

import 'package:flutter/material.dart';

import 'package:QUIK/modules/crm/customers/customer_duplicate_search_service.dart';

typedef DuplicateLookupFieldBuilder =
    Widget Function(ValueChanged<String> onChanged);

class CustomerDuplicateLookupField extends StatefulWidget {
  const CustomerDuplicateLookupField({
    super.key,
    required this.lookupType,
    required this.searchService,
    required this.fieldBuilder,
    required this.onViewCustomer,
    this.excludedCustomerId,
  });

  final CustomerDuplicateLookupType lookupType;
  final CustomerDuplicateSearchService searchService;
  final DuplicateLookupFieldBuilder fieldBuilder;
  final ValueChanged<CustomerDuplicateSuggestion> onViewCustomer;
  final String? excludedCustomerId;

  @override
  State<CustomerDuplicateLookupField> createState() =>
      _CustomerDuplicateLookupFieldState();
}

class _CustomerDuplicateLookupFieldState
    extends State<CustomerDuplicateLookupField> {
  Timer? _debounce;
  int _searchGeneration = 0;
  List<CustomerDuplicateSuggestion> _suggestions = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchGeneration++;
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;

    if (_suggestions.isNotEmpty) {
      setState(() => _suggestions = const []);
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await widget.searchService.search(
        type: widget.lookupType,
        value: value,
        excludedCustomerId: widget.excludedCustomerId,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _suggestions = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.fieldBuilder(_onChanged),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _suggestions.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(
                    '${widget.lookupType.name}:${_suggestions.length}',
                  ),
                  padding: const EdgeInsets.only(top: 7),
                  child: CustomerDuplicateSuggestionPanel(
                    suggestions: _suggestions,
                    nameDropdown:
                        widget.lookupType == CustomerDuplicateLookupType.name,
                    onViewCustomer: widget.onViewCustomer,
                  ),
                ),
        ),
      ],
    );
  }
}

class CustomerDuplicateSuggestionPanel extends StatelessWidget {
  const CustomerDuplicateSuggestionPanel({
    super.key,
    required this.suggestions,
    required this.nameDropdown,
    required this.onViewCustomer,
  });

  final List<CustomerDuplicateSuggestion> suggestions;
  final bool nameDropdown;
  final ValueChanged<CustomerDuplicateSuggestion> onViewCustomer;

  @override
  Widget build(BuildContext context) {
    final warningColor = Colors.orange.shade800;
    return Material(
      color: Colors.white,
      elevation: nameDropdown ? 5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: nameDropdown
              ? Colors.white
              : Colors.orange.shade50.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.content_copy_outlined,
                    size: 17,
                    color: warningColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      nameDropdown
                          ? 'Possible existing customers'
                          : 'Customer already registered',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < suggestions.length; index++) ...[
              if (index > 0) Divider(height: 1, color: Colors.orange.shade100),
              _CustomerSuggestionTile(
                suggestion: suggestions[index],
                onViewCustomer: onViewCustomer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerSuggestionTile extends StatelessWidget {
  const _CustomerSuggestionTile({
    required this.suggestion,
    required this.onViewCustomer,
  });

  final CustomerDuplicateSuggestion suggestion;
  final ValueChanged<CustomerDuplicateSuggestion> onViewCustomer;

  @override
  Widget build(BuildContext context) {
    final statusColor = suggestion.isActive
        ? Colors.green.shade700
        : Colors.grey.shade700;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _detail('Customer Code', suggestion.customerCode),
              _detail('GST', suggestion.gstNumber),
              _detail('Mobile', suggestion.mobileNumber),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  suggestion.city.isEmpty
                      ? 'City not available'
                      : suggestion.city,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  suggestion.status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                'Already Registered',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onViewCustomer(suggestion),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('View Customer'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}
