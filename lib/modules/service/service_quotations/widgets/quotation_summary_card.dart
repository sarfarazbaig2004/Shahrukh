// FILE PATH: lib/modules/service/service_quotations/widgets/quotation_summary_card.dart

import 'package:flutter/material.dart';

class QuotationSummaryCard extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final String status;
  final String paymentStatus;
  final String approvalStatus;
  final bool dispatchRequired;
  final bool installationRequired;
  final bool visitRequired;

  const QuotationSummaryCard({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.grandTotal,
    this.status = 'Draft',
    required this.paymentStatus,
    required this.approvalStatus,
    required this.dispatchRequired,
    required this.installationRequired,
    this.visitRequired = false,
  });

  String get _nextAction {
    final s = status.toLowerCase();
    final a = approvalStatus.toLowerCase();
    final p = paymentStatus.toLowerCase();

    if (s == 'draft') return 'Send Quote';
    if (a == 'rejected') return 'Review Rejection & Revise';
    if (s == 'sent' && a == 'pending') return 'Follow-up for Approval';
    if (a == 'approved' && (p == 'pending' || p == 'unpaid')) return 'Receive Payment';
    if (dispatchRequired && s != 'completed') return 'Dispatch Material';
    if ((installationRequired || visitRequired) && s != 'completed') return 'Schedule Installation / Visit';
    if (s == 'completed') return 'No Action Required';

    return 'Complete Request';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // NEXT ACTION BANNER
          // ==========================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
            ),
            child: Row(
              children: [
                Icon(Icons.next_plan_outlined, color: Colors.indigo.shade700, size: 20),
                const SizedBox(width: 10),
                Text(
                  'NEXT ACTION:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nextAction.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // MAIN CONTENT BODY
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile Layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFinancials(),
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 24),
                      _buildStatusesAndRequirements(),
                    ],
                  );
                } else {
                  // Desktop / Tablet Layout
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: _buildStatusesAndRequirements()),
                        VerticalDivider(width: 48, thickness: 1, color: Colors.grey.shade200),
                        Expanded(flex: 4, child: _buildFinancials()),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LEFT PANE: STATUSES & REQUIREMENTS
  // ==========================================

  Widget _buildStatusesAndRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DOCUMENT STATUS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _buildBadges(),
        ),
        const SizedBox(height: 28),
        Text(
          'EXECUTION REQUIREMENTS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _buildReq('Dispatch Required', dispatchRequired),
        _buildReq('Installation Required', installationRequired),
        _buildReq('Engineer Visit Required', visitRequired),
      ],
    );
  }

  List<Widget> _buildBadges() {
    List<Widget> badges = [];

    // General Document Status
    badges.add(_buildBadge(status.isEmpty ? 'Draft' : status, _getStatusColor(status)));

    // Approval Status
    if (approvalStatus.isNotEmpty) {
      badges.add(_buildBadge(approvalStatus, _getApprovalColor(approvalStatus)));
    }

    // Payment Status
    if (paymentStatus.isNotEmpty) {
      badges.add(_buildBadge(paymentStatus, _getPaymentColor(paymentStatus)));
    }

    return badges;
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildReq(String label, bool isRequired) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isRequired ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: isRequired ? Colors.green.shade600 : Colors.grey.shade300,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isRequired ? Colors.black87 : Colors.grey.shade500,
              fontWeight: isRequired ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RIGHT PANE: FINANCIAL SUMMARY
  // ==========================================

  Widget _buildFinancials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FINANCIAL SUMMARY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        _buildFinanceRow('Subtotal', subtotal),
        _buildFinanceRow('Discount', discount, isDiscount: true),
        _buildFinanceRow('Tax Amount', taxAmount),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
        _buildFinanceRow('Grand Total', grandTotal, isTotal: true),
      ],
    );
  }

  Widget _buildFinanceRow(String label, double amount, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: isTotal ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            isDiscount ? '- ₹${amount.toStringAsFixed(2)}' : '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 20 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              color: isDiscount ? Colors.red.shade600 : (isTotal ? Colors.green.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COLOR MAPPERS
  // ==========================================

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'draft': return Colors.orange.shade700;
      case 'sent': return Colors.blue.shade700;
      case 'converted to work order': return Colors.purple.shade700;
      case 'completed': return Colors.green.shade700;
      case 'cancelled': return Colors.red.shade700;
      default: return Colors.blueGrey.shade700;
    }
  }

  Color _getApprovalColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      case 'pending': return Colors.orange.shade700;
      default: return Colors.blueGrey.shade700;
    }
  }

  Color _getPaymentColor(String s) {
    final lower = s.toLowerCase();
    if (lower == 'paid') return Colors.green.shade700;
    if (lower == 'advance received' || lower == 'partial') return Colors.teal.shade700;
    if (lower == 'payment pending' || lower == 'pending' || lower == 'unpaid') return Colors.red.shade700;
    return Colors.blueGrey.shade700;
  }
}