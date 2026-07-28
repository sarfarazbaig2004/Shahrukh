/// Status lifecycle of a Request for Quotation (RFQ).
enum RfqStatus {
  draft,
  pendingApproval,
  approved,
  sent,
  partiallyResponded,
  responded,
  underEvaluation,
  vendorSelected,
  convertedToPO,
  closed,
  rejected,
  cancelled,
}

extension RfqStatusExtension on RfqStatus {
  /// Value stored in Firestore.
  String get firestoreValue {
    switch (this) {
      case RfqStatus.draft:
        return 'draft';
      case RfqStatus.pendingApproval:
        return 'pendingApproval';
      case RfqStatus.approved:
        return 'approved';
      case RfqStatus.sent:
        return 'sent';
      case RfqStatus.partiallyResponded:
        return 'partiallyResponded';
      case RfqStatus.responded:
        return 'responded';
      case RfqStatus.underEvaluation:
        return 'underEvaluation';
      case RfqStatus.vendorSelected:
        return 'vendorSelected';
      case RfqStatus.convertedToPO:
        return 'convertedToPO';
      case RfqStatus.closed:
        return 'closed';
      case RfqStatus.rejected:
        return 'rejected';
      case RfqStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Human-readable label shown in UI.
  String get displayLabel {
    switch (this) {
      case RfqStatus.draft:
        return 'Draft';
      case RfqStatus.pendingApproval:
        return 'Pending Approval';
      case RfqStatus.approved:
        return 'Approved';
      case RfqStatus.sent:
        return 'Sent';
      case RfqStatus.partiallyResponded:
        return 'Partially Responded';
      case RfqStatus.responded:
        return 'Responded';
      case RfqStatus.underEvaluation:
        return 'Under Evaluation';
      case RfqStatus.vendorSelected:
        return 'Vendor Selected';
      case RfqStatus.convertedToPO:
        return 'Converted to PO';
      case RfqStatus.closed:
        return 'Closed';
      case RfqStatus.rejected:
        return 'Rejected';
      case RfqStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Parses a raw Firestore/UI value into an [RfqStatus].
  /// Returns [fallback] when the value is null, empty or unknown.
  static RfqStatus parse(
    String? value, {
    RfqStatus fallback = RfqStatus.draft,
  }) {
    return tryParse(value) ?? fallback;
  }

  /// Parses a raw value into an [RfqStatus] or returns null if unknown.
  static RfqStatus? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    for (final status in RfqStatus.values) {
      if (status.firestoreValue == normalized ||
          status.displayLabel.toLowerCase() == normalized.toLowerCase()) {
        return status;
      }
    }
    return null;
  }
}
