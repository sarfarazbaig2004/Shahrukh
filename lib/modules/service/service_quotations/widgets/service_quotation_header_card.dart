// FILE PATH: lib/modules/service/service_quotations/widgets/service_quotation_header_card.dart

import 'package:flutter/material.dart';
import '../models/service_quotation_models.dart';

class ServiceQuotationHeaderCard extends StatelessWidget {
  final ServiceQuotationModel quotation;
  final VoidCallback onOpenRequest;
  final VoidCallback onOpenVisit;

  const ServiceQuotationHeaderCard({
    super.key,
    required this.quotation,
    required this.onOpenRequest,
    required this.onOpenVisit,
  });

  @override
  Widget build(BuildContext context) {
    final firstMachine = quotation.machines.isNotEmpty ? quotation.machines.first : null;
    String machineDisplay = firstMachine?.machineModel ?? 'Unknown Machine';
    if (quotation.machines.length > 1) {
      machineDisplay += ' (+${quotation.machines.length - 1} more)';
    }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Identifiers and Badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            quotation.quotationNumber.isNotEmpty ? quotation.quotationNumber : 'DRAFT QUOTATION',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(quotation.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (quotation.requestNumber.isNotEmpty) ...[
                            _buildReferencePill('Request:', quotation.requestNumber, Icons.assignment, onOpenRequest),
                            const SizedBox(width: 8),
                          ],
                          if (quotation.visitNumber.isNotEmpty) ...[
                            _buildReferencePill('Visit:', quotation.visitNumber, Icons.directions_car, onOpenVisit),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Grand Total', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    Text(
                      '₹${quotation.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMiniBadge(quotation.approvalStatus.isEmpty ? 'Pending' : quotation.approvalStatus, _getApprovalColor(quotation.approvalStatus)),
                        const SizedBox(width: 8),
                        _buildMiniBadge(quotation.paymentStatus.isEmpty ? 'Unpaid' : quotation.paymentStatus, _getPaymentColor(quotation.paymentStatus)),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),

          // Body Row with Customer & Machine Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Details
                Expanded(
                  flex: 3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blueGrey.shade50,
                        child: const Icon(Icons.business, color: Colors.blueGrey, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(
                              quotation.customerName.isNotEmpty ? quotation.customerName : 'Unknown Customer',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.label_important_outline, 'Type:', quotation.quotationType.isNotEmpty ? quotation.quotationType : 'Service'),
                            const SizedBox(height: 4),
                            _buildInfoRow(Icons.receipt_long, 'Billing:', quotation.billingType.isNotEmpty ? quotation.billingType : 'Standard'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(width: 1, height: 80, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 20)),

                // Machine Details
                Expanded(
                  flex: 4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.orange.shade50,
                        child: Icon(Icons.precision_manufacturing, color: Colors.orange.shade800, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EQUIPMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(
                              machineDisplay,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.tag, 'Serial No:', firstMachine?.serialNumber ?? 'N/A'),
                            const SizedBox(height: 4),
                            _buildInfoRow(Icons.verified_user, 'Warranty:', firstMachine?.warrantyStatus ?? 'N/A',
                                valueColor: (firstMachine?.warrantyStatus ?? '').toLowerCase().contains('under') ? Colors.green.shade700 : Colors.red.shade700
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildReferencePill(String prefix, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.indigo.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.indigo.shade700),
            const SizedBox(width: 4),
            Text(prefix, style: TextStyle(fontSize: 11, color: Colors.indigo.shade400)),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;

    switch (status) {
      case 'Draft': bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Sent': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'Approved': bg = Colors.green.shade50; fg = Colors.green.shade800; break;
      case 'Rejected': bg = Colors.red.shade50; fg = Colors.red.shade800; break;
      case 'Converted To Work Order': bg = Colors.purple.shade50; fg = Colors.purple.shade800; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.3))
      ),
      child: Text(
          status.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.5)
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Color _getApprovalColor(String status) {
    if (status == 'Approved') return Colors.green.shade700;
    if (status == 'Rejected') return Colors.red.shade700;
    return Colors.orange.shade700;
  }

  Color _getPaymentColor(String status) {
    if (status == 'Paid') return Colors.green.shade700;
    if (status == 'Partial Payment' || status == 'Advance Received') return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}