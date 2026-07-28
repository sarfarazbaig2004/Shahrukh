import '../models/purchase_rfq_model.dart';
import '../models/rfq_status.dart';

/// Lightweight, reusable filtering and suggestion logic for RFQ records.
///
/// This service does not access Firestore directly. The caller is responsible
/// for loading the [PurchaseRfq] list and passing it here.
class RfqSearchService {
  const RfqSearchService();

  /// Returns matching RFQs ranked for use as search suggestions.
  ///
  /// * [query] is trimmed and matched case-insensitively.
  /// * Deleted RFQs are excluded.
  /// * An empty [query] returns the most recently updated/created RFQs.
  /// * The original [rfqs] list is not mutated.
  /// * Results are limited to [limit].
  List<PurchaseRfq> getSuggestions({
    required List<PurchaseRfq> rfqs,
    required String query,
    int limit = 10,
  }) {
    final trimmed = query.trim();
    final candidates = rfqs.where((rfq) => !rfq.isDeleted);

    if (trimmed.isEmpty) {
      final recent = candidates.toList(growable: false);
      recent.sort(_recencyComparator);
      return recent.take(limit).toList(growable: false);
    }

    final normalized = trimmed.toLowerCase();
    final ranked = <_RankedRfq>[];

    for (final rfq in candidates) {
      final rank = _matchRank(rfq, normalized);
      if (rank != null) {
        ranked.add(_RankedRfq(rfq, rank));
      }
    }

    ranked.sort((a, b) {
      final rankCompare = a.rank.compareTo(b.rank);
      if (rankCompare != 0) return rankCompare;
      return _recencyComparator(a.rfq, b.rfq);
    });

    return ranked
        .map((ranked) => ranked.rfq)
        .take(limit)
        .toList(growable: false);
  }

  /// Rank assignment for non-empty queries.
  ///
  /// Lower numbers mean stronger matches. Returns null when the RFQ does not
  /// match the query in any supported field.
  int? _matchRank(PurchaseRfq rfq, String query) {
    final number = rfq.rfqNumber.toLowerCase();
    if (number == query) return 1;
    if (number.startsWith(query)) return 2;

    final title = rfq.title.toLowerCase();
    if (title.startsWith(query)) return 3;

    final prNumber = rfq.purchaseRequisitionNumber?.toLowerCase() ?? '';
    if (prNumber.startsWith(query)) return 4;

    for (final vendor in rfq.vendors) {
      final vendorName = vendor.vendorName.toLowerCase();
      if (vendorName.startsWith(query)) return 5;
    }

    for (final item in rfq.items) {
      final itemCode = item.itemCode?.toLowerCase() ?? '';
      if (itemCode.startsWith(query)) return 6;
    }

    if (_containsQuery(rfq, query)) return 7;

    return null;
  }

  /// Checks whether the query appears anywhere in the searchable text of [rfq].
  bool _containsQuery(PurchaseRfq rfq, String query) {
    final searchable = <String>[
      rfq.rfqNumber.toLowerCase(),
      rfq.title.toLowerCase(),
      rfq.description?.toLowerCase() ?? '',
      rfq.purchaseRequisitionNumber?.toLowerCase() ?? '',
      rfq.assignedBuyerName?.toLowerCase() ?? '',
      rfq.deliveryLocation?.toLowerCase() ?? '',
      rfq.deliveryAddress?.toLowerCase() ?? '',
      rfq.status.displayLabel.toLowerCase(),
      ...rfq.items.expand(
        (item) => [
          item.itemName.toLowerCase(),
          item.itemCode?.toLowerCase() ?? '',
          item.description?.toLowerCase() ?? '',
          item.specification?.toLowerCase() ?? '',
          item.deliveryLocation?.toLowerCase() ?? '',
        ],
      ),
      ...rfq.vendors.map((vendor) => vendor.vendorName.toLowerCase()),
    ];

    return searchable.any((text) => text.contains(query));
  }

  /// Recency comparator: updatedAt desc, then createdAt desc, then rfqDate desc.
  int _recencyComparator(PurchaseRfq a, PurchaseRfq b) {
    final aUpdated = a.updatedAt ?? a.createdAt;
    final bUpdated = b.updatedAt ?? b.createdAt;
    final updatedCompare = bUpdated.compareTo(aUpdated);
    if (updatedCompare != 0) return updatedCompare;

    final createdCompare = b.createdAt.compareTo(a.createdAt);
    if (createdCompare != 0) return createdCompare;

    return b.rfqDate.compareTo(a.rfqDate);
  }
}

class _RankedRfq {
  const _RankedRfq(this.rfq, this.rank);

  final PurchaseRfq rfq;
  final int rank;
}
