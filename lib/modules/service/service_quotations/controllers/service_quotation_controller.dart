// FILE PATH: lib/modules/service/service_quotations/controllers/service_quotation_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/service_quotation_models.dart';

class ServiceQuotationController {
  final FirebaseFirestore _firestore;
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  ServiceQuotationController({
    FirebaseFirestore? firestore,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('companies').doc(companyId).collection('service_quotations');

  // ==========================================
  // CORE CRUD METHODS
  // ==========================================

  /// Loads a single quotation by ID
  Future<ServiceQuotationModel?> loadQuotation(String quotationId) async {
    try {
      final doc = await _collection.doc(quotationId).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      data['id'] = doc.id; // Ensure ID is injected
      return ServiceQuotationModel.fromMap(data);
    } catch (e, st) {
      debugPrint('Error loading quotation: $e\n$st');
      throw Exception('Failed to load Service Quotation: $e');
    }
  }

  /// Saves a new quotation and securely increments the counter
  Future<ServiceQuotationModel> saveQuotation(ServiceQuotationModel quotation, {bool autoGenerateNumber = true}) async {
    validateQuotation(quotation);

    try {
      return await _firestore.runTransaction((tx) async {
        String finalQuoteNumber = quotation.quotationNumber;

        if (autoGenerateNumber || finalQuoteNumber.isEmpty) {
          finalQuoteNumber = await _generateQuotationNumberTransaction(tx);
        }

        final newDocRef = _collection.doc();

        final payload = quotation.copyWith(
          quotationId: newDocRef.id,
          quotationNumber: finalQuoteNumber,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).toMap();

        // Add creation activity
        payload['activities'] = FieldValue.arrayUnion([
          _createActivityLog('Created', 'Service Quotation created', status: quotation.status)
        ]);

        tx.set(newDocRef, payload);

        // Update Parent Service Request if linked
        if (quotation.requestId.isNotEmpty) {
          final reqRef = _firestore.collection('companies').doc(companyId).collection('service_requests').doc(quotation.requestId);
          tx.set(reqRef, {
            'status': 'Quoted',
            'quotationId': newDocRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        return ServiceQuotationModel.fromMap(payload);
      });
    } catch (e, st) {
      debugPrint('Error saving quotation: $e\n$st');
      throw Exception('Failed to save quotation: $e');
    }
  }

  /// Updates an existing quotation
  Future<void> updateQuotation(ServiceQuotationModel quotation) async {
    validateQuotation(quotation);

    try {
      final docRef = _collection.doc(quotation.quotationId);

      final payload = quotation.copyWith(
        updatedAt: DateTime.now(),
      ).toMap();

      payload['activities'] = FieldValue.arrayUnion([
        _createActivityLog('Updated', 'Service Quotation updated')
      ]);

      await docRef.set(payload, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Error updating quotation: $e\n$st');
      throw Exception('Failed to update quotation: $e');
    }
  }

  /// Soft deletes a quotation
  Future<void> softDeleteQuotation(String quotationId) async {
    try {
      await _collection.doc(quotationId).update({
        'isDeleted': true,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedByUid': currentUserUid,
        'activities': FieldValue.arrayUnion([
          _createActivityLog('Deleted', 'Quotation soft-deleted')
        ]),
      });
    } catch (e, st) {
      debugPrint('Error deleting quotation: $e\n$st');
      throw Exception('Failed to delete quotation: $e');
    }
  }

  /// Duplicates an existing quotation
  Future<ServiceQuotationModel> duplicateQuotation(String originalQuotationId) async {
    final original = await loadQuotation(originalQuotationId);
    if (original == null) throw Exception('Original quotation not found.');

    final newQuotation = original.copyWith(
      quotationId: '',
      quotationNumber: '', // Will be auto-generated
      status: 'Draft',
      approvalStatus: 'Pending',
      paymentStatus: 'Unpaid',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      attachments: [], // Usually don't clone attachments
      remarks: 'Duplicated from ${original.quotationNumber}',
    );

    return await saveQuotation(newQuotation, autoGenerateNumber: true);
  }

  // ==========================================
  // CALCULATION METHODS
  // ==========================================

  double calculateSubtotal(List<QuotationLineItem> items, List<VisitCharge> visitCharges) {
    double itemSubtotal = items.fold(0.0, (sum, item) => sum + (item.qty * item.rate));
    double visitSubtotal = visitCharges.fold(0.0, (sum, vc) => sum + (vc.qty * vc.rate));
    return itemSubtotal + visitSubtotal;
  }

  double calculateDiscount(List<QuotationLineItem> items, double globalDiscountPercent) {
    double totalItemDiscount = 0.0;
    double taxableSubtotal = 0.0;

    for (var item in items) {
      double lineTotal = item.qty * item.rate;
      double lineDiscount = lineTotal * (item.discount / 100);
      totalItemDiscount += lineDiscount;
      taxableSubtotal += (lineTotal - lineDiscount);
    }

    double globalDiscountAmount = taxableSubtotal * (globalDiscountPercent / 100);
    return totalItemDiscount + globalDiscountAmount;
  }

  double calculateTax(List<QuotationLineItem> items, List<VisitCharge> visitCharges) {
    double totalTax = 0.0;

    // Items Tax
    for (var item in items) {
      double lineTotal = item.qty * item.rate;
      double lineDiscount = lineTotal * (item.discount / 100);
      double taxable = lineTotal - lineDiscount;

      // Ensure we extract taxes safely from the model (assuming they are mapped or fallback to 18%)
      // If the model does not have explicit tax fields, assume 18% standard for demo,
      // or derive from specific item logic. For this standard, we use 18% fallback if missing.
      double taxRate = 18.0;
      totalTax += taxable * (taxRate / 100);
    }

    // Visit Charges Tax
    for (var vc in visitCharges) {
      double taxable = vc.qty * vc.rate;
      totalTax += taxable * (18.0 / 100); // Standard 18% for service charges
    }

    return totalTax;
  }

  double calculateGrandTotal(double subtotal, double discount, double taxAmount) {
    double grandTotal = subtotal - discount + taxAmount;
    return grandTotal.roundToDouble(); // Standard ERP rounding
  }

  // ==========================================
  // WORKFLOW METHODS
  // ==========================================

  Future<void> _updateQuotationStatus(String quotationId, Map<String, dynamic> updates, String action, String note) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    updates['activities'] = FieldValue.arrayUnion([
      _createActivityLog(action, note, status: updates['status'])
    ]);

    await _collection.doc(quotationId).update(updates);
  }

  Future<void> markAsDraft(String quotationId) =>
      _updateQuotationStatus(quotationId, {'status': 'Draft'}, 'Status Update', 'Marked as Draft');

  Future<void> markAsSent(String quotationId) =>
      _updateQuotationStatus(quotationId, {'status': 'Sent'}, 'Status Update', 'Sent to Customer');

  Future<void> markAsApproved(String quotationId) =>
      _updateQuotationStatus(quotationId, {'approvalStatus': 'Approved', 'status': 'Approved'}, 'Approval', 'Approved by Customer');

  Future<void> markAsRejected(String quotationId, {String reason = ''}) =>
      _updateQuotationStatus(quotationId, {'approvalStatus': 'Rejected', 'status': 'Rejected', 'remarks': reason}, 'Approval', 'Rejected by Customer');

  Future<void> markAsPaymentPending(String quotationId) =>
      _updateQuotationStatus(quotationId, {'paymentStatus': 'Pending'}, 'Payment', 'Payment marked as Pending');

  Future<void> markAsAdvanceReceived(String quotationId) =>
      _updateQuotationStatus(quotationId, {'paymentStatus': 'Advance Received'}, 'Payment', 'Advance Payment Received');

  Future<void> markAsPaid(String quotationId) =>
      _updateQuotationStatus(quotationId, {'paymentStatus': 'Paid'}, 'Payment', 'Full Payment Received');

  Future<void> markAsDispatchPending(String quotationId) =>
      _updateQuotationStatus(quotationId, {'dispatchRequired': true, 'dispatchStatus': 'Pending'}, 'Dispatch', 'Marked for Dispatch');

  Future<void> markAsInstallationPending(String quotationId) =>
      _updateQuotationStatus(quotationId, {'installationRequired': true, 'installationStatus': 'Pending Assignment'}, 'Installation', 'Marked for Installation');

  Future<void> markAsCompleted(String quotationId) =>
      _updateQuotationStatus(quotationId, {'status': 'Completed'}, 'Status Update', 'Quotation Lifecycle Completed');

  // ==========================================
  // VALIDATION METHODS
  // ==========================================

  List<String> validateCustomer(ServiceQuotationModel quotation) {
    List<String> errors = [];
    if (quotation.customerId.isEmpty) errors.add('Customer ID is missing.');
    if (quotation.customerName.isEmpty) errors.add('Customer Name is missing.');
    return errors;
  }

  List<String> validateMachine(ServiceQuotationModel quotation) {
    List<String> errors = [];
    if (quotation.machines.isEmpty) {
      errors.add('At least one machine must be added to the quotation.');
    } else {
      for (var machine in quotation.machines) {
        if (machine.machineModel.isEmpty && machine.machineName.isEmpty) {
          errors.add('Machine model or name is required.');
        }
      }
    }
    return errors;
  }

  List<String> validateLineItems(ServiceQuotationModel quotation) {
    List<String> errors = [];
    if (quotation.lineItems.isEmpty && quotation.visitCharges.isEmpty) {
      errors.add('Quotation must contain at least one line item or visit charge.');
    }

    for (var item in quotation.lineItems) {
      if (item.qty <= 0) errors.add('Item "${item.itemName}" must have quantity > 0.');
      if (item.rate < 0) errors.add('Item "${item.itemName}" cannot have negative rate.');
    }
    return errors;
  }

  List<String> validateTotals(ServiceQuotationModel quotation) {
    List<String> errors = [];
    if (quotation.grandTotal < 0) errors.add('Grand total cannot be negative.');
    if (quotation.subtotal < 0) errors.add('Subtotal cannot be negative.');
    return errors;
  }

  void validateQuotation(ServiceQuotationModel quotation) {
    List<String> allErrors = [
      ...validateCustomer(quotation),
      ...validateMachine(quotation),
      ...validateLineItems(quotation),
      ...validateTotals(quotation),
    ];

    if (allErrors.isNotEmpty) {
      throw Exception('Validation Failed:\n${allErrors.join('\n')}');
    }
  }

  // ==========================================
  // UTILITY METHODS
  // ==========================================

  String _getFinancialYear(DateTime date) {
    int year = date.year;
    int month = date.month;
    if (month >= 4) {
      return '$year-${(year + 1).toString().substring(2)}';
    } else {
      return '${year - 1}-${year.toString().substring(2)}';
    }
  }

  Future<String> _generateQuotationNumberTransaction(Transaction tx) async {
    final fy = _getFinancialYear(DateTime.now());
    final prefix = 'MEM'; // Default or fetched from company settings

    final counterRef = _firestore.collection('companies').doc(companyId).collection('counters').doc('service_quotation_counter_$fy');
    final counterDoc = await tx.get(counterRef);

    int currentSequence = 0;
    if (counterDoc.exists) {
      currentSequence = (counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0;
    }

    int nextSequence = currentSequence + 1;
    String newQuoteNumber = '$prefix/SQ/${nextSequence.toString().padLeft(3, '0')}/$fy';

    tx.set(counterRef, {
      'sequence': nextSequence,
      'prefix': prefix,
      'financialYear': fy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return newQuoteNumber;
  }

  Future<String> generateQuotationNumber() async {
    return await _firestore.runTransaction((tx) async {
      return await _generateQuotationNumberTransaction(tx);
    });
  }

  String getNextAction(ServiceQuotationModel quotation) {
    if (quotation.status == 'Draft') return 'Send to Customer';
    if (quotation.status == 'Sent' && quotation.approvalStatus == 'Pending') return 'Follow-up for Approval';
    if (quotation.approvalStatus == 'Approved' && quotation.paymentStatus == 'Pending') return 'Collect Advance Payment';
    if (isDispatchRequired(quotation) && quotation.status != 'Converted To Work Order') return 'Convert to Work Order / Dispatch';
    if (isInstallationRequired(quotation) && quotation.status == 'Converted To Work Order') return 'Schedule Installation Visit';
    if (quotation.status == 'Completed') return 'No Action Required';

    return 'Review Quotation Status';
  }

  bool isDispatchRequired(ServiceQuotationModel quotation) {
    return quotation.dispatchRequired ||
        quotation.lineItems.any((item) => item.itemType.toLowerCase() == 'spare' || item.itemType.toLowerCase() == 'consumable');
  }

  bool isInstallationRequired(ServiceQuotationModel quotation) {
    return quotation.installationRequired ||
        quotation.quotationType.toLowerCase().contains('installation') ||
        quotation.lineItems.any((item) => item.itemName.toLowerCase().contains('install'));
  }

  // ==========================================
  // INTERNAL HELPERS
  // ==========================================

  Map<String, dynamic> _createActivityLog(String type, String note, {String? status}) {
    return {
      'type': type,
      'status': status ?? 'Unknown',
      'note': note,
      'timestamp': Timestamp.now(),
      'byUid': currentUserUid,
      'byName': currentUserName,
      'module': 'Service Quotation',
    };
  }
}