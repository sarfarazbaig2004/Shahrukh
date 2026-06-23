// FILE PATH: lib/modules/service/service_quotations/widgets/quotation_bottom_action_bar.dart

import 'package:flutter/material.dart';
import '../models/service_quotation_models.dart';

class QuotationBottomActionBar extends StatelessWidget {
  final ServiceQuotationModel quotation;
  final VoidCallback onSaveDraft;
  final VoidCallback onSendQuote;
  final VoidCallback onPreviewPdf;
  final VoidCallback onRefresh;
  final VoidCallback onOpenRequest;
  final VoidCallback onOpenVisit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const QuotationBottomActionBar({
    super.key,
    required this.quotation,
    required this.onSaveDraft,
    required this.onSendQuote,
    required this.onPreviewPdf,
    required this.onRefresh,
    required this.onOpenRequest,
    required this.onOpenVisit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final String status = quotation.status.toLowerCase();
    final bool isDraft = status == 'draft' || status.isEmpty;
    final bool isCancelled = status == 'cancelled';

    final bool hasRequest = quotation.requestId.isNotEmpty;
    final bool hasVisit = quotation.visitId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // Ensures primary actions are visible on smaller screens
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionBtn(
                icon: Icons.refresh_outlined,
                label: 'Refresh',
                onTap: onRefresh,
                isOutlined: true,
              ),
              const SizedBox(width: 12),
              _buildActionBtn(
                icon: Icons.file_copy_outlined,
                label: 'Duplicate',
                onTap: onDuplicate,
                isOutlined: true,
              ),
              const SizedBox(width: 12),

              if (hasRequest) ...[
                _buildActionBtn(
                  icon: Icons.assignment_outlined,
                  label: 'Open Request',
                  onTap: onOpenRequest,
                  isOutlined: true,
                ),
                const SizedBox(width: 12),
              ],

              if (hasVisit) ...[
                _buildActionBtn(
                  icon: Icons.directions_car_outlined,
                  label: 'Open Visit',
                  onTap: onOpenVisit,
                  isOutlined: true,
                ),
                const SizedBox(width: 12),
              ],

              if (isDraft || isCancelled) ...[
                _buildActionBtn(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onTap: onDelete,
                  isOutlined: true,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 12),
              ],

              _buildActionBtn(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Preview PDF',
                onTap: onPreviewPdf,
                isOutlined: true,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 12),

              if (isDraft) ...[
                _buildActionBtn(
                  icon: Icons.save_outlined,
                  label: 'Save Draft',
                  onTap: onSaveDraft,
                  isFilledTonal: true,
                ),
                const SizedBox(width: 12),
                _buildActionBtn(
                  icon: Icons.send_outlined,
                  label: 'Send Quote',
                  onTap: onSendQuote,
                  isFilled: true,
                  color: Colors.indigo,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isOutlined = false,
    bool isFilled = false,
    bool isFilledTonal = false,
    Color? color,
  }) {
    if (isFilled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    if (isFilledTonal) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color?.withOpacity(0.5) ?? Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        foregroundColor: color ?? Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}