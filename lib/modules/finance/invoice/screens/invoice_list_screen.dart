import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

import '../export_invoice/models/export_invoice_model.dart';
import '../export_invoice/widgets/export_invoice_document_view.dart';
import '../export_invoice/screens/export_invoice_screen.dart';
import '../../payments_received/screens/record_payment_screen.dart';

String _formatCurrency(double amount) {
  return NumberFormat('#,##0.00', 'en_US').format(amount);
}

class InvoiceListScreen extends StatefulWidget {
  final String companyId;
  final String userUid;
  final VoidCallback onSelectTax;
  final VoidCallback onSelectExport;

  const InvoiceListScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    required this.onSelectTax,
    required this.onSelectExport,
  });

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortOption = 'date_desc';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Invoice',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: zText),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the type of invoice you want to generate.',
                style: TextStyle(fontSize: 14, color: zMuted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              _CreateOptionCard(
                title: 'Tax Invoice',
                subtitle: 'Standard invoice for domestic sales with GST/VAT.',
                icon: Icons.receipt_long_outlined,
                color: zBlue,
                bgColor: zBlueSoft,
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelectTax();
                },
              ),
              const SizedBox(height: 12),
              _CreateOptionCard(
                title: 'Export Invoice',
                subtitle: 'Specialized invoice for international shipping & customs.',
                icon: Icons.public_outlined,
                color: zPurple,
                bgColor: zPurpleSoft,
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelectExport();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _handleInvoiceAction(String action, ExportInvoiceModel invoice) {
    if (action == 'payment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordPaymentScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
            customerName: invoice.buyer.name,
            prefillInvoiceId: invoice.id,
          ),
        ),
      );
    } else if (action == 'view') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportInvoiceDocumentView(invoice: invoice),
        ),
      );
    } else if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportInvoiceScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
            invoiceId: invoice.id,
            onBack: () {
              if (mounted) Navigator.pop(context);
            },
          ),
        ),
      );
    } else if (action == 'cancel') {
      _confirmCancel(invoice.id);
    }
  }

  void _confirmCancel(String docId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;
        String errorMsg = '';
        bool obscurePwd = true;
        final pwdController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text('Confirm Cancellation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: zText)),
                    const SizedBox(height: 12),
                    const Text(
                      'This will cancel the invoice and clear outstanding ledgers. Please enter your password to confirm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: zMuted, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Secure Password Field
                    TextField(
                      controller: pwdController,
                      obscureText: obscurePwd,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        hintText: 'Account Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: zMuted),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePwd ? Icons.visibility_off : Icons.visibility, size: 18, color: zMuted),
                          onPressed: () => setState(() => obscurePwd = !obscurePwd),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                      ),
                    ),

                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(child: Text(errorMsg, style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            onPressed: isLoading ? null : () => Navigator.pop(ctx),
                            child: const Text('Close', style: TextStyle(color: zText, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isLoading ? null : () async {
                              final pwd = pwdController.text.trim();
                              if (pwd.isEmpty) {
                                setState(() => errorMsg = 'Please enter your password.');
                                return;
                              }

                              setState(() {
                                isLoading = true;
                                errorMsg = '';
                              });

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null || user.email == null) {
                                  throw FirebaseAuthException(code: 'user-not-found', message: 'No active user found.');
                                }

                                // 🔥 RE-AUTHENTICATE USER
                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: pwd,
                                );
                                await user.reauthenticateWithCredential(credential);

                                // If success, close dialog and cancel invoice
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  _cancelInvoice(docId);
                                }
                              } on FirebaseAuthException catch (e) {
                                setState(() {
                                  isLoading = false;
                                  if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                                    errorMsg = 'Incorrect password. Action denied.';
                                  } else {
                                    errorMsg = e.message ?? 'Authentication failed.';
                                  }
                                });
                              } catch (e) {
                                setState(() {
                                  isLoading = false;
                                  errorMsg = 'An unexpected error occurred.';
                                });
                              }
                            },
                            child: isLoading
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelInvoice(String docId) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. UPDATE: Change invoice status to CANCELLED (Keeps document for compliance)
      final invoiceRef = db.collection('companies').doc(widget.companyId).collection('export_invoices').doc(docId);
      batch.update(invoiceRef, {
        'status': 'CANCELLED',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. HARD DELETE: Remove the associated outstanding ledger document to clear accounts
      final outstandingRef = db.collection('companies').doc(widget.companyId).collection('outstanding').doc(docId);
      batch.delete(outstandingRef);

      // 3. ACTIVITY LOG: Create an immutable audit log entry
      final logRef = db.collection('companies').doc(widget.companyId).collection('invoice_activity_logs').doc();
      batch.set(logRef, {
        'invoiceId': docId,
        'action': 'CANCELLED',
        'timestamp': FieldValue.serverTimestamp(),
        'uid': widget.userUid,
      });

      // 4. COMMIT ATOMIC TRANSACTION
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice cancelled successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exportInvoicesRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('export_invoices');

    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        backgroundColor: zCanvasBg,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: zBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _showCreateOptions(context),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: exportInvoicesRef
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SkeletonListLoader();
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const _EmptyInvoiceState(hasSearch: false);
          }

          final allDocs = snapshot.data!.docs;
          final query = _searchQuery.trim().toLowerCase();

          // Parse to Models
          List<ExportInvoiceModel> invoices = [];
          for (var doc in allDocs) {
            try {
              final data = doc.data();
              if (data.isEmpty) continue;

              invoices.add(ExportInvoiceModel.fromMap(data, doc.id));
            } catch (e) {
              debugPrint('Parse error: $e');
            }
          }

          // Apply Search & Filters
          var filteredInvoices = invoices.where((inv) {
            final invNum = inv.invoiceNumber.toLowerCase();
            final buyerName = inv.buyer.name.toLowerCase();
            final docStatus = inv.status.toLowerCase();

            final matchesSearch = query.isEmpty || invNum.contains(query) || buyerName.contains(query);
            final matchesStatus = _statusFilter == 'all' || docStatus == _statusFilter.toLowerCase();

            return matchesSearch && matchesStatus;
          }).toList();

          // Apply Sorting
          if (_sortOption == 'amount_desc') {
            filteredInvoices.sort((a, b) => b.totals.grandTotal.compareTo(a.totals.grandTotal));
          } else if (_sortOption == 'customer_asc') {
            filteredInvoices.sort((a, b) => a.buyer.name.toLowerCase().compareTo(b.buyer.name.toLowerCase()));
          } else {
            filteredInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          // Quick Stats
          final totalCount = filteredInvoices.length;
          final draftCount = filteredInvoices.where((inv) => inv.status.toLowerCase() == 'draft').length;
          final finalCount = filteredInvoices.where((inv) => inv.status.toLowerCase() == 'submitted').length;

          return Column(
            children: [
              // HEADER & FILTERS
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search by Invoice No or Customer',
                            prefixIcon: const Icon(Icons.search, size: 18, color: zMuted),
                            suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300)
                            ),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300)
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: zBlue, width: 1.5)
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      value: _statusFilter,
                      onChanged: (val) => setState(() => _statusFilter = val!),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.sort, size: 18, color: zText),
                        tooltip: 'Sort Invoices',
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (val) => setState(() => _sortOption = val),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'date_desc', child: Text('Date (Latest First)', style: TextStyle(fontSize: 13, fontWeight: _sortOption == 'date_desc' ? FontWeight.bold : FontWeight.normal))),
                          PopupMenuItem(value: 'amount_desc', child: Text('Amount (High to Low)', style: TextStyle(fontSize: 13, fontWeight: _sortOption == 'amount_desc' ? FontWeight.bold : FontWeight.normal))),
                          PopupMenuItem(value: 'customer_asc', child: Text('Customer (A-Z)', style: TextStyle(fontSize: 13, fontWeight: _sortOption == 'customer_asc' ? FontWeight.bold : FontWeight.normal))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // QUICK STATS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _MiniStatText(label: 'Total', value: totalCount.toString()),
                    const SizedBox(width: 12),
                    _MiniStatText(label: 'Drafts', value: draftCount.toString(), color: zOrange),
                    const SizedBox(width: 12),
                    _MiniStatText(label: 'Finalized', value: finalCount.toString(), color: Colors.green.shade700),
                  ],
                ),
              ),

              // LIST VIEW
              Expanded(
                child: filteredInvoices.isEmpty
                    ? _EmptyInvoiceState(hasSearch: _searchQuery.isNotEmpty || _statusFilter != 'all')
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: filteredInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = filteredInvoices[index];
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 400)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _InvoiceCard(
                        invoice: invoice,
                        onView: () {
                          if (!mounted) return;
                          _handleInvoiceAction('view', invoice);
                        },
                        onEdit: () {
                          if (!mounted) return;
                          _handleInvoiceAction('edit', invoice);
                        },
                        onRecordPayment: () {
                          if (!mounted) return;
                          _handleInvoiceAction('payment', invoice);
                        },
                        onCancel: () {
                          if (!mounted) return;
                          _confirmCancel(invoice.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// INVOICE CARD (SAAS GRADE)
// ---------------------------------------------------------

class _InvoiceCard extends StatefulWidget {
  final ExportInvoiceModel invoice;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onRecordPayment;
  final VoidCallback onCancel;

  const _InvoiceCard({
    required this.invoice,
    required this.onView,
    required this.onEdit,
    required this.onRecordPayment,
    required this.onCancel,
  });

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final isDraft = invoice.status.toLowerCase() == 'draft';
    final isCancelled = invoice.status.toLowerCase() == 'cancelled';

    final displayStatus = isCancelled
        ? 'CANCELLED'
        : isDraft
        ? 'DRAFT'
        : (invoice.paymentStatus.isEmpty
        ? 'UNPAID'
        : invoice.paymentStatus.toUpperCase());

    double safeOutstanding = invoice.amountOutstanding;
    if (safeOutstanding < 0) safeOutstanding = 0;

    double paidPct = 0.0;
    if (invoice.totals.grandTotal > 0) {
      paidPct = (invoice.amountReceived / invoice.totals.grandTotal).clamp(0.0, 1.0);
    }

    Color chipBg;
    Color chipText;
    Color chipBorder;
    if (displayStatus == 'PAID') {
      chipBg = Colors.green.shade50;
      chipText = Colors.green.shade800;
      chipBorder = Colors.green.shade200;
    } else if (displayStatus == 'PARTIALLY PAID') {
      chipBg = Colors.orange.shade50;
      chipText = Colors.orange.shade900;
      chipBorder = Colors.orange.shade200;
    } else if (displayStatus == 'DRAFT') {
      chipBg = Colors.grey.shade100;
      chipText = Colors.grey.shade800;
      chipBorder = Colors.grey.shade300;
    } else if (displayStatus == 'CANCELLED') {
      chipBg = Colors.red.shade50;
      chipText = Colors.red.shade800;
      chipBorder = Colors.red.shade200;
    } else { // UNPAID
      chipBg = Colors.amber.shade50;
      chipText = Colors.amber.shade900;
      chipBorder = Colors.amber.shade300;
    }

    final dateStr = '${DateFormat('dd MMM yyyy').format(invoice.invoiceDate)} • Due ${DateFormat('dd MMM yyyy').format(invoice.dueDate)}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isCancelled ? const Color(0xFFF9FAFB) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isHovered ? zBlue.withValues(alpha: 0.4) : Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.02),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: const Offset(0, 4)
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Info & Amounts
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                                invoice.invoiceNumber.isEmpty ? 'Pending Number' : invoice.invoiceNumber,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: zMuted,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null
                                ),
                              ),
                              const SizedBox(width: 12),
                              _InfoChip(label: displayStatus, bgColor: chipBg, textColor: chipText, borderColor: chipBorder),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            invoice.buyer.name.isEmpty ? 'Unknown Customer' : invoice.buyer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17,
                                color: isCancelled ? zMuted : zText,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 13, color: zMuted.withValues(alpha: 0.7)),
                              const SizedBox(width: 6),
                              Text(dateStr, style: const TextStyle(fontSize: 13, color: zMuted, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Fixed width container for strict vertical alignment
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${invoice.currency} ${_formatCurrency(invoice.totals.grandTotal)}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isCancelled ? zMuted : zText,
                                letterSpacing: -0.5,
                                decoration: isCancelled ? TextDecoration.lineThrough : null
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!isDraft && !isCancelled) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Balance:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: zMuted.withValues(alpha: 0.8)),
                                ),
                                Text(
                                  _formatCurrency(safeOutstanding),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: safeOutstanding > 0 ? Colors.red.shade600 : zMuted
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                tween: Tween(begin: 0.0, end: paidPct),
                                builder: (context, value, child) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: value,
                                            minHeight: 5,
                                            backgroundColor: Colors.grey.shade100,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                value == 1.0 ? Colors.green.shade500 : zBlue.withValues(alpha: 0.8)
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(value * 100).toInt()}% Paid',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: zMuted.withValues(alpha: 0.8)),
                                      ),
                                    ],
                                  );
                                }
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF3F4F6)),

              // Bottom Section: Actions
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onView,
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: const Text('View', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: zText,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    const Spacer(),
                    if (!isDraft && !isCancelled && invoice.paymentStatus.toUpperCase() != 'PAID')
                      FilledButton.icon(
                        onPressed: widget.onRecordPayment,
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        style: FilledButton.styleFrom(
                          backgroundColor: zBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),

                    // Only show dropdown if it's not cancelled
                    if (!isCancelled) ...[
                      const SizedBox(width: 8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, color: zMuted, size: 20),
                          tooltip: 'Options',
                          offset: const Offset(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          onSelected: (val) {
                            if (val == 'edit') widget.onEdit();
                            if (val == 'cancel') widget.onCancel();
                          },
                          itemBuilder: (ctx) => [
                            if (invoice.paymentStatus.toUpperCase() != 'PAID')
                              PopupMenuItem(
                                  value: 'edit',
                                  height: 40,
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18, color: zText.withValues(alpha: 0.8)),
                                      const SizedBox(width: 10),
                                      const Text('Edit Invoice', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  )
                              ),
                            PopupMenuItem(
                                value: 'cancel',
                                height: 40,
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade600),
                                    const SizedBox(width: 10),
                                    Text('Cancel Invoice', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                )
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SUPPORTING WIDGETS
// ---------------------------------------------------------

class _CreateOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _CreateOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: zText)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: zMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: zMuted),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Status: ', style: TextStyle(fontSize: 13, color: zMuted, fontWeight: FontWeight.w600)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Icon(Icons.keyboard_arrow_down, size: 16, color: zText),
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: zText),
              onChanged: onChanged,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'draft', child: Text('Drafts')),
                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStatText({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontSize: 12, color: zMuted, fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: TextStyle(fontSize: 13, color: color ?? zText, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const _InfoChip({required this.label, required this.bgColor, required this.textColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(6)
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5)),
    );
  }
}

class _EmptyInvoiceState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyInvoiceState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))
                  ]
              ),
              child: Icon(
                  hasSearch ? Icons.search_off_rounded : Icons.receipt_long_rounded,
                  size: 48,
                  color: zMuted.withValues(alpha: 0.5)
              ),
            ),
            const SizedBox(height: 24),
            Text(
                hasSearch ? 'No invoices match your search' : 'No invoices yet',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: zText)
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch ? 'Try adjusting your filters.' : 'Click "New Invoice" to get started',
              style: const TextStyle(color: zMuted, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonListLoader extends StatelessWidget {
  const _SkeletonListLoader();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: 4,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (ctx, i) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutSine,
      tween: Tween(begin: 0.3, end: 0.7),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 14, width: 100, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Container(height: 18, width: 180, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Container(height: 12, width: 140, color: Colors.grey.shade200),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(height: 20, width: 90, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      Container(height: 8, width: 120, color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 80, color: Colors.grey.shade200),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
