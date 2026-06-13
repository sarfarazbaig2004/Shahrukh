import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../controllers/record_payment_controller.dart';
import '../../invoice/export_invoice/screens/export_invoice_screen.dart';

// --- Premium SaaS Design System Colors ---
const Color _kPrimary = Color(0xFF2563EB);
const Color _kPrimarySoft = Color(0xFFEFF6FF);
const Color _kText = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF64748B);
const Color _kBorder = Color(0xFFE2E8F0);
const Color _kBg = Color(0xFFF8FAFC);
const Color _kCardBg = Colors.white;
const Color _kSuccess = Color(0xFF16A34A);
const Color _kWarning = Color(0xFFEA580C);
const Color _kWarningSoft = Color(0xFFFFF7ED);
const Color _kError = Color(0xFFDC2626);
const Color _kErrorSoft = Color(0xFFFEF2F2);

class RecordPaymentScreen extends StatefulWidget {
  final String companyId;
  final String userUid;
  final String? customerName;
  final String? prefillInvoiceId;
  final PaymentModel? existingPayment; // Integrated for Edit capability

  const RecordPaymentScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.customerName,
    this.prefillInvoiceId,
    this.existingPayment,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  late RecordPaymentController _ctrl;
  final FocusNode _amountFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isAmountFocused = false;
  final Map<String, Timer> _debounceMap = {};
  String? _localError;
  bool _isSavingLocal = false;

  String _currentUserName = 'Unknown User';

  @override
  void initState() {
    super.initState();
    _ctrl = RecordPaymentController(companyId: widget.companyId, userUid: widget.userUid);
    _fetchCurrentUserName();

    _amountFocus.addListener(() {
      setState(() => _isAmountFocused = _amountFocus.hasFocus);
    });

    if (widget.existingPayment != null) {
      _prefillExistingPayment();
    } else if (widget.customerName != null && widget.customerName!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.fetchInvoicesByName(widget.customerName!, prefillInvoiceId: widget.prefillInvoiceId);
      });
    }
  }

  Future<void> _fetchCurrentUserName() async {
    try {
      var userDoc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users').doc(widget.userUid).get();
      if (userDoc.exists) {
        _currentUserName = userDoc.data()?['name'] ?? 'Unknown User';
      }
    } catch(e) {
      _currentUserName = 'Unknown User';
    }
  }

  void _prefillExistingPayment() {
    final p = widget.existingPayment!;
    _ctrl.selectedCurrency = p.currency;
    _ctrl.amountCtrl.text = p.totalAmount.toString();
    _ctrl.paymentMode = p.paymentMode;
    _ctrl.referenceCtrl.text = p.referenceNo;
    _ctrl.paymentDate = p.paymentDate;
    _ctrl.exchangeRateCtrl.text = p.exchangeRate.toString();

    // Fetch related customer invoices instantly to allow re-allocation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.fetchInvoices(p.customerId);
    });
  }

  // 🔴 Robust Firestore Update logic specific for the Edit mode safely overriding Controller saves
  Future<bool> _updatePaymentLocally() async {
    setState(() => _isSavingLocal = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('payments')
          .doc(widget.existingPayment!.id)
          .update({
        'totalAmount': _ctrl.totalReceived,
        'amountInr': _ctrl.baseAmountInr,
        'advanceAmount': _ctrl.advanceAmount,
        'allocatedAmount': _ctrl.totalAllocated,
        'paymentDate': Timestamp.fromDate(_ctrl.paymentDate),
        'paymentMode': _ctrl.paymentMode,
        'referenceNo': _ctrl.referenceCtrl.text.trim(),
        'exchangeRate': double.tryParse(_ctrl.exchangeRateCtrl.text.trim()) ?? 1.0,
        'updatedBy': widget.userUid,
        'updatedByName': _currentUserName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch(e) {
      return false;
    } finally {
      if (mounted) setState(() => _isSavingLocal = false);
    }
  }

  @override
  void dispose() {
    for (var timer in _debounceMap.values) {
      timer.cancel();
    }
    _debounceMap.clear();
    _scrollController.dispose();
    _amountFocus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  double _round(double val, {int decimals = 2}) {
    return double.parse(val.toStringAsFixed(decimals));
  }

  int _getDecimalsForCurrency(String currency) {
    const zeroDecimalCurrencies = ['JPY', 'KRW', 'VND', 'BIF', 'CLP', 'PYG'];
    const threeDecimalCurrencies = ['BHD', 'KWD', 'OMR', 'JOD', 'TND'];
    if (zeroDecimalCurrencies.contains(currency.toUpperCase())) return 0;
    if (threeDecimalCurrencies.contains(currency.toUpperCase())) return 3;
    return 2;
  }

  String _formatCurrency(double amount, String currency) {
    int decimals = _getDecimalsForCurrency(currency);
    return NumberFormat.currency(
      symbol: '',
      decimalDigits: decimals,
      locale: 'en_US',
    ).format(amount).trim();
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'INR': return '₹';
      case 'AED': return 'د.إ';
      case 'SGD': return 'S\$';
      case 'JPY': return '¥';
      case 'AUD': return 'A\$';
      case 'CAD': return 'C\$';
      case 'CHF': return 'CHF';
      case 'CNY': return '¥';
      default: return currency;
    }
  }

  String get _currencySymbol => _getCurrencySymbol(_ctrl.selectedCurrency);

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  void _handleAllocationChange(String docId, String val, double pending, int invDecimals) {
    if (_debounceMap[docId]?.isActive ?? false) _debounceMap[docId]!.cancel();

    _debounceMap[docId] = Timer(const Duration(milliseconds: 300), () {
      final ctrl = _ctrl.allocationCtrls[docId];
      if (ctrl == null) return;

      double inputVal = double.tryParse(val.trim()) ?? 0.0;
      if (inputVal > pending) {
        ctrl.text = pending.toStringAsFixed(invDecimals);
        ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
      }
      _ctrl.calculateTotals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    final bool isEdit = widget.existingPayment != null;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        foregroundColor: _kText,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: _kBorder, width: 1)),
        title: Semantics(
            label: 'Record Payment Screen',
            child: Text(isEdit ? 'Edit Payment' : 'Record Payment', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5))
        ),
        leading: Semantics(
          label: 'Go Back',
          child: IconButton(
            tooltip: 'Go Back',
            icon: const Icon(Icons.arrow_back, color: _kText),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      bottomNavigationBar: _buildStickySummaryBar(isEdit),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) {
              if (_localError != null && (_localError ?? '').toString().isNotEmpty) {
                return _buildErrorState((_localError ?? '').toString());
              }

              bool isCurrencyLocked = _ctrl.allUnpaidInvoices.isNotEmpty && _ctrl.availableCurrencies.length == 1;

              List<String> safeCurrencyList = ['USD', 'EUR', 'GBP', 'INR', 'AED', 'SGD'];
              if (!safeCurrencyList.contains(_ctrl.selectedCurrency)) {
                safeCurrencyList.add(_ctrl.selectedCurrency);
              }

              int selectedDecimals = _getDecimalsForCurrency(_ctrl.selectedCurrency);

              return Form(
                key: _ctrl.formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 32),
                  children: [
                    // SECTION 1: CUSTOMER & DATE
                    _buildSectionContainer(
                      step: '1',
                      title: 'Payment Details',
                      child: Column(
                        children: [
                          _responsiveRow(
                            isDesktop: isDesktop,
                            children: [
                              Expanded(flex: 3, child: _buildCustomerSearchField(isEdit)),
                              Expanded(flex: 2, child: _buildDatePicker()),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _responsiveRow(
                            isDesktop: isDesktop,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      label: 'Select Currency',
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _ctrl.selectedCurrency,
                                        decoration: _inputDecoration('Currency *', icon: isCurrencyLocked ? Icons.lock_outline : Icons.public),
                                        items: safeCurrencyList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                                        onChanged: isCurrencyLocked ? null : (v) => _ctrl.changeCurrency((v ?? '').toString()),
                                      ),
                                    ),
                                    if (_ctrl.availableCurrencies.length > 1)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline, size: 14, color: _kWarning),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text("Invoices use multiple currencies. Please record separate payments per currency.", style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w500))),
                                          ],
                                        ),
                                      )
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      label: 'Exchange Rate',
                                      child: TextFormField(
                                        controller: _ctrl.exchangeRateCtrl,
                                        decoration: _inputDecoration('Exchange Rate (${_ctrl.selectedCurrency} → INR) *', icon: Icons.currency_exchange),
                                        readOnly: _ctrl.selectedCurrency == 'INR',
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d{0,4})?$')),
                                        ],
                                        validator: (v) {
                                          double val = double.tryParse((v ?? '').toString().trim()) ?? 0;
                                          if (val <= 0) return 'Required';
                                          if (_ctrl.selectedCurrency != 'INR' && val == 1.0) return 'Verify Rate';
                                          return null;
                                        },
                                      ),
                                    ),
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8, left: 4),
                                        child: _ctrl.selectedCurrency == 'INR'
                                            ? const Text('Base currency — no conversion required', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w500))
                                            : Text('1 ${_ctrl.selectedCurrency} = ₹ ${_formatCurrency(double.tryParse(_ctrl.exchangeRateCtrl.text.trim()) ?? 0, 'INR')}', style: const TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600))
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // HERO AMOUNT FIELD
                          Semantics(
                            label: 'Amount Received Input',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                color: _isAmountFocused ? _kPrimarySoft : _kCardBg,
                                border: Border.all(
                                    color: _isAmountFocused ? _kPrimary : _kBorder,
                                    width: _isAmountFocused ? 2 : 1
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _isAmountFocused ? [BoxShadow(color: _kPrimary.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))] : [],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 64,
                                    width: 64,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
                                    child: const Icon(Icons.account_balance_wallet_rounded, color: _kPrimary, size: 32),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _ctrl.amountCtrl,
                                      focusNode: _amountFocus,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                                      decoration: InputDecoration(
                                        labelText: 'Amount Received ($_currencySymbol) *',
                                        labelStyle: TextStyle(fontSize: 16, color: _isAmountFocused ? _kPrimary : _kMuted, fontWeight: FontWeight.w600),
                                        floatingLabelBehavior: FloatingLabelBehavior.always,
                                        border: InputBorder.none,
                                        hintText: 'Enter amount',
                                        hintStyle: const TextStyle(color: _kBorder, fontSize: 32, fontWeight: FontWeight.w900),
                                        prefixText: '$_currencySymbol ',
                                        prefixStyle: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: _kText),
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 36, color: _kText, letterSpacing: -1.0),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        selectedDecimals == 0
                                            ? FilteringTextInputFormatter.digitsOnly
                                            : FilteringTextInputFormatter.allow(RegExp('^\\d+(\\.\\d{0,$selectedDecimals})?\$')),
                                      ],
                                      validator: (v) => (double.tryParse((v ?? '').toString().trim()) ?? 0) <= 0 ? 'Enter a valid amount' : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          _responsiveRow(
                            isDesktop: isDesktop,
                            children: [
                              Expanded(
                                child: Semantics(
                                  label: 'Payment Mode',
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _ctrl.paymentMode,
                                    decoration: _inputDecoration('Payment Mode', icon: Icons.account_balance_outlined),
                                    items: const [
                                      DropdownMenuItem(value: 'Wire Transfer (TT)', child: Text('Wire Transfer (TT)', style: TextStyle(fontWeight: FontWeight.w600))),
                                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer', style: TextStyle(fontWeight: FontWeight.w600))),
                                      DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card', style: TextStyle(fontWeight: FontWeight.w600))),
                                      DropdownMenuItem(value: 'Cash', child: Text('Cash', style: TextStyle(fontWeight: FontWeight.w600))),
                                      DropdownMenuItem(value: 'Letter of Credit', child: Text('Letter of Credit', style: TextStyle(fontWeight: FontWeight.w600))),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        _ctrl.paymentMode = v;
                                        _ctrl.notifyUi();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Semantics(
                                  label: 'Reference Number',
                                  child: TextFormField(
                                    controller: _ctrl.referenceCtrl,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                                    decoration: _inputDecoration('Reference / Check No.', icon: Icons.tag),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // SECTION 2: ALLOCATION
                    _buildSectionContainer(
                      step: '2',
                      title: 'Allocate to Invoices',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_ctrl.filteredInvoices.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Semantics(
                                  label: 'Reset Allocation Button',
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      bool? confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Reset Allocations', style: TextStyle(fontWeight: FontWeight.w800, color: _kText)),
                                            content: const Text('Are you sure you want to clear all invoice allocations?', style: TextStyle(color: _kMuted)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _kMuted))),
                                              FilledButton(
                                                  style: FilledButton.styleFrom(backgroundColor: _kError),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Clear All')
                                              ),
                                            ],
                                          )
                                      );
                                      if (confirm == true) {
                                        for (var doc in _ctrl.filteredInvoices) {
                                          final ctrl = _ctrl.allocationCtrls[doc.id];
                                          if (ctrl != null) ctrl.clear();
                                        }
                                        _ctrl.calculateTotals();
                                      }
                                    },
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Reset Allocation', style: TextStyle(fontWeight: FontWeight.w600)),
                                    style: TextButton.styleFrom(foregroundColor: _kMuted),
                                  ),
                                ),
                                Semantics(
                                  label: 'Auto Allocate Button',
                                  child: Tooltip(
                                    message: "Automatically allocate payment to oldest invoices first",
                                    child: FilledButton.tonalIcon(
                                      onPressed: _ctrl.totalReceived > 0 ? () {
                                        double remaining = _ctrl.totalReceived;

                                        // Sort by Date (FIFO)
                                        final sortedDocs = List<DocumentSnapshot>.from(_ctrl.filteredInvoices);
                                        sortedDocs.sort((a, b) {
                                          final dataA = (a.data() as Map<String, dynamic>?) ?? {};
                                          final dataB = (b.data() as Map<String, dynamic>?) ?? {};
                                          final dateA = _parseDate(dataA['invoiceDate']);
                                          final dateB = _parseDate(dataB['invoiceDate']);
                                          return dateA.compareTo(dateB);
                                        });

                                        for (var doc in sortedDocs) {
                                          final ctrl = _ctrl.allocationCtrls[doc.id];
                                          if (ctrl != null) {
                                            final data = (doc.data() as Map<String, dynamic>?) ?? {};
                                            double total = _safeDouble(data['totals']?['grandTotal']);
                                            double received = _safeDouble(data['amountReceived']);
                                            double pending = data.containsKey('amountOutstanding') ? _safeDouble(data['amountOutstanding']) : (total - received);
                                            if (pending < 0) pending = 0.0;

                                            String invCurrency = (data['currency'] is String && (data['currency'] as String).isNotEmpty)
                                                ? (data['currency'] ?? '').toString()
                                                : _ctrl.selectedCurrency;
                                            int decimals = _getDecimalsForCurrency(invCurrency);
                                            pending = _round(pending, decimals: decimals);

                                            if (remaining > 0 && pending > 0) {
                                              double alloc = remaining >= pending ? pending : remaining;
                                              alloc = _round(alloc, decimals: decimals);
                                              ctrl.text = alloc.toStringAsFixed(decimals);
                                              remaining -= alloc;
                                              remaining = _round(remaining, decimals: _getDecimalsForCurrency(_ctrl.selectedCurrency));
                                            } else {
                                              ctrl.clear();
                                            }
                                          }
                                        }
                                        _ctrl.calculateTotals();
                                      } : null,
                                      icon: const Icon(Icons.auto_awesome, size: 18),
                                      label: const Text('Auto Allocate', style: TextStyle(fontWeight: FontWeight.w700)),
                                      style: FilledButton.styleFrom(backgroundColor: _kPrimarySoft, foregroundColor: _kPrimary),
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          _buildAllocationState(isDesktop),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              );
            }
        ),
      ),
    );
  }

  Widget _responsiveRow({required bool isDesktop, required List<Widget> children}) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.expand((widget) => [widget, const SizedBox(width: 24)]).toList()..removeLast(),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.expand((widget) => [widget, const SizedBox(height: 16)]).toList()..removeLast(),
      );
    }
  }

  Widget _buildSectionContainer({required String step, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder, width: 1))),
              child: Row(
                  children: [
                    Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: _kPrimarySoft, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(step, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w900, fontSize: 14))
                    ),
                    const SizedBox(width: 16),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kText, letterSpacing: -0.5))
                  ]
              ),
            ),
            Padding(padding: const EdgeInsets.all(24), child: child),
          ]
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w600),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: _kMuted) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kPrimary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kError, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildCustomerSearchField(bool isEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (opt) => (opt['name'] ?? '').toString(),
          optionsBuilder: (TextEditingValue tv) {
            if (tv.text.trim().isEmpty) return _ctrl.customersList;
            return _ctrl.customersList.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(tv.text.trim().toLowerCase()));
          },
          onSelected: (selection) {
            FocusScope.of(context).unfocus();
            _ctrl.fetchInvoices((selection['id'] ?? '').toString());
          },
          fieldViewBuilder: (context, txtCtrl, focusNode, onFieldSubmitted) {
            // For Edit mode, hardlock the customer text
            if (isEdit) {
              txtCtrl.text = widget.existingPayment!.customerName;
            } else if (_ctrl.selectedCustomerName.isNotEmpty && txtCtrl.text.trim().isEmpty) {
              txtCtrl.text = _ctrl.selectedCustomerName;
            }
            bool hasSelection = _ctrl.selectedCustomerName.isNotEmpty || isEdit;
            return Semantics(
              label: 'Customer Search Field',
              child: TextFormField(
                controller: txtCtrl,
                focusNode: focusNode,
                readOnly: isEdit || (widget.customerName != null && (widget.customerName ?? '').toString().isNotEmpty),
                style: const TextStyle(fontWeight: FontWeight.w700, color: _kText, fontSize: 16),
                decoration: _inputDecoration('Search Customer *', icon: Icons.business_outlined).copyWith(
                  fillColor: hasSelection ? _kPrimarySoft.withValues(alpha: 0.5) : Colors.white,
                  suffixIcon: _ctrl.isLoadingCustomers
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : (hasSelection && widget.customerName == null && !isEdit)
                      ? IconButton(icon: const Icon(Icons.close, color: _kMuted, size: 20), onPressed: () { txtCtrl.clear(); _ctrl.clearCustomer(); })
                      : const Icon(Icons.keyboard_arrow_down, color: _kMuted),
                ),
                validator: (v) => _ctrl.selectedCustomerId.isEmpty && _ctrl.selectedCustomerName.isEmpty && !isEdit ? 'Please select a customer' : null,
              ),
            );
          },
        ),
        if ((_ctrl.selectedCustomerId.isNotEmpty || isEdit) && !_ctrl.isLoadingInvoices)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _ctrl.filteredInvoices.isEmpty
                  ? "No outstanding invoices"
                  : "${_ctrl.filteredInvoices.length} outstanding invoice${_ctrl.filteredInvoices.length > 1 ? 's' : ''}",
              style: TextStyle(
                  color: _ctrl.filteredInvoices.isEmpty ? _kMuted : _kPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600
              ),
            ),
          )
      ],
    );
  }

  Widget _buildDatePicker() {
    return Semantics(
      label: 'Payment Date Picker',
      child: InkWell(
        onTap: () async {
          final d = await showDatePicker(
              context: context,
              initialDate: _ctrl.paymentDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now()
          );
          if (d != null) {
            _ctrl.paymentDate = d;
            _ctrl.notifyUi();
          }
        },
        child: InputDecorator(
          decoration: _inputDecoration('Payment Date', icon: Icons.calendar_today_outlined),
          child: Text(DateFormat('dd MMM yyyy').format(_ctrl.paymentDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kText)),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: _kErrorSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200)
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _kError, size: 48),
              const SizedBox(height: 16),
              const Text('An error occurred', style: TextStyle(color: _kError, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 24),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _kError),
                  onPressed: () {
                    setState(() => _localError = null);
                    if (widget.existingPayment != null) {
                      _ctrl.fetchInvoices(widget.existingPayment!.customerId);
                    } else if (widget.customerName != null && widget.customerName!.isNotEmpty) {
                      _ctrl.fetchInvoicesByName(widget.customerName!, prefillInvoiceId: widget.prefillInvoiceId);
                    } else if (_ctrl.selectedCustomerId.isNotEmpty) {
                      _ctrl.fetchInvoices(_ctrl.selectedCustomerId);
                    }
                  },
                  child: const Text('Try Again')
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllocationState(bool isDesktop) {
    if (_ctrl.isLoadingInvoices) {
      return const Padding(
          padding: EdgeInsets.all(48),
          child: Center(
              child: Column(
                  children: [
                    CircularProgressIndicator(color: _kPrimary),
                    SizedBox(height: 24),
                    Text("Fetching outstanding invoices...", style: TextStyle(color: _kMuted, fontWeight: FontWeight.w500))
                  ]
              )
          )
      );
    }

    if (_ctrl.selectedCustomerId.isEmpty && _ctrl.selectedCustomerName.isEmpty && widget.existingPayment == null) {
      return _buildEmptyState(
          icon: Icons.person_search_rounded,
          title: "No customer selected",
          subtitle: "Search and select a customer to continue.",
          color: _kMuted,
          showCreateCta: false
      );
    }

    if (_ctrl.filteredInvoices.isEmpty) {
      if (_ctrl.totalReceived > 0) {
        return _buildEmptyState(
            icon: Icons.account_balance_wallet_rounded,
            title: "Advance Payment",
            subtitle: "No pending invoices found. This will be recorded as an Advance.",
            color: _kWarning,
            showCreateCta: true
        );
      }
      return _buildEmptyState(
          icon: Icons.receipt_long_rounded,
          title: "All Cleared",
          subtitle: "No outstanding invoices found for this customer.",
          color: _kSuccess,
          showCreateCta: true
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_ctrl.totalAllocated > _ctrl.totalReceived + 0.01)
          Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: _kErrorSoft, border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [const Icon(Icons.error_outline, color: _kError), const SizedBox(width: 8), Text("Allocated amount exceeds received amount", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold))])
          ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _ctrl.filteredInvoices.map((doc) => _buildInvoiceCard(doc, isDesktop)).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle, required Color color, bool showCreateCta = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder, style: BorderStyle.solid)
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 24),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: _kMuted, fontWeight: FontWeight.w500)),
            if (showCreateCta) ...[
              const SizedBox(height: 24),
              Semantics(
                label: 'Create Invoice Button',
                child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportInvoiceScreen(
                          companyId: widget.companyId,
                          userUid: widget.userUid,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Invoice', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _kPrimary,
                        side: const BorderSide(color: _kPrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                    )
                ),
              )
            ]
          ]
      ),
    );
  }

  Widget _buildInvoiceCard(DocumentSnapshot doc, bool isDesktop) {
    final ctrl = _ctrl.allocationCtrls[doc.id];
    if (ctrl == null) return const SizedBox.shrink();

    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    double total = _safeDouble(data['totals']?['grandTotal']);
    double received = _safeDouble(data['amountReceived']);
    double pending = data.containsKey('amountOutstanding') ? _safeDouble(data['amountOutstanding']) : (total - received);
    if (pending < 0) pending = 0.0;

    String invCurrency = (data['currency'] is String && (data['currency'] as String).isNotEmpty)
        ? data['currency']
        : _ctrl.selectedCurrency;
    String invSymbol = _getCurrencySymbol(invCurrency);
    int invDecimals = _getDecimalsForCurrency(invCurrency);

    pending = _round(pending, decimals: invDecimals);

    DateTime dt = _parseDate(data['invoiceDate']);
    String? errorMsg = _ctrl.validateAllocation(doc.id, pending);
    bool hasError = errorMsg != null;

    String status = (data['status'] is String) ? data['status'] : '';
    String paymentStatus = (data['paymentStatus'] is String) ? data['paymentStatus'] : '';

    final isDraft = status.toLowerCase() == 'draft';
    final displayStatus = isDraft
        ? 'DRAFT'
        : (paymentStatus.isEmpty
        ? 'UNPAID'
        : paymentStatus.toUpperCase());

    Color badgeBg = _kErrorSoft;
    Color badgeText = _kError;
    if (displayStatus == 'PARTIALLY PAID') {
      badgeBg = _kWarningSoft;
      badgeText = _kWarning;
    } else if (displayStatus == 'DRAFT') {
      badgeBg = _kBg;
      badgeText = _kMuted;
    }

    String invoiceNumber = (data['invoiceNumber'] is String && (data['invoiceNumber'] as String).isNotEmpty)
        ? data['invoiceNumber']
        : 'Unknown';

    Widget invoiceInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kText, letterSpacing: -0.3)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
              child: Text(displayStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeText, letterSpacing: 0.5)),
            )
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: _kMuted),
            const SizedBox(width: 4),
            Text(DateFormat('dd MMM yyyy').format(dt), style: const TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );

    Widget invoiceStats = Row(
      mainAxisAlignment: isDesktop ? MainAxisAlignment.spaceAround : MainAxisAlignment.spaceBetween,
      children: [
        _buildCardStat('Total', total, invCurrency),
        _buildCardStat('Received', received, invCurrency, color: _kMuted),
        _buildCardStat('Pending', pending, invCurrency, color: _kWarning, isBold: true),
      ],
    );

    Widget allocationField = SizedBox(
      width: isDesktop ? 160 : double.infinity,
      child: Semantics(
        label: 'Allocate Payment for $invoiceNumber',
        child: TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: isDesktop ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _kPrimary),
          inputFormatters: [
            invDecimals == 0
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(RegExp('^\\d*(\\.\\d{0,$invDecimals})?\$')),
          ],
          onTap: () {
            if (ctrl.text.isEmpty || (double.tryParse(ctrl.text.trim()) ?? 0) == 0) {
              ctrl.text = pending.toStringAsFixed(invDecimals);
              _ctrl.calculateTotals();
            }
          },
          onChanged: (val) => _handleAllocationChange(doc.id, val, pending, invDecimals),
          decoration: InputDecoration(
              hintText: '0.${'0'*invDecimals}',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixText: '$invSymbol ',
              prefixStyle: const TextStyle(color: _kMuted, fontSize: 14, fontWeight: FontWeight.normal),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kPrimary, width: 2)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kError, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              errorText: errorMsg
          ),
        ),
      ),
    );

    return _HoverCard(
      hasError: hasError,
      child: isDesktop
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: invoiceInfo),
          Expanded(flex: 4, child: invoiceStats),
          const SizedBox(width: 32),
          allocationField,
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          invoiceInfo,
          const SizedBox(height: 16),
          const Divider(color: _kBorder),
          const SizedBox(height: 16),
          invoiceStats,
          const SizedBox(height: 24),
          allocationField,
        ],
      ),
    );
  }

  Widget _buildCardStat(String label, double amount, String currency, {Color color = _kText, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(_formatCurrency(amount, currency), style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildStickySummaryBar(bool isEdit) {
    return ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          bool isOverAllocated = _ctrl.totalAllocated > _ctrl.totalReceived + 0.01;
          bool isAdvanceOnly = _ctrl.totalReceived > 0 && _ctrl.totalAllocated == 0;

          double unallocated = _ctrl.totalReceived - _ctrl.totalAllocated;
          if (unallocated < 0) unallocated = 0;

          String disableReason = '';
          if (!_ctrl.isValidToSave) {
            if (_ctrl.totalReceived <= 0) {
              disableReason = "Enter Amount Received";
            } else if (double.tryParse(_ctrl.exchangeRateCtrl.text.trim()) == null || double.tryParse(_ctrl.exchangeRateCtrl.text.trim())! <= 0) {
              disableReason = "Enter Valid Exchange Rate";
            } else if (isOverAllocated) {
              disableReason = "Allocated exceeds Received";
            } else {
              disableReason = "Fix allocation errors above";
            }
          } else if (isOverAllocated) {
            disableReason = "Allocated exceeds Received";
          }

          String btnLabel = isEdit ? 'Update Payment' : 'Save Payment';
          if (_ctrl.isSaving || _isSavingLocal) {
            btnLabel = 'Processing...';
          } else if (isAdvanceOnly) {
            btnLabel = isEdit ? 'Update as Advance' : 'Save as Advance';
          } else if (_ctrl.totalAllocated > 0) {
            btnLabel = isEdit ? 'Update & Allocate' : 'Save & Allocate';
          }

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              decoration: const BoxDecoration(
                  color: _kCardBg,
                  border: Border(top: BorderSide(color: _kBorder)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSummaryStat("Received", _ctrl.totalReceived, _ctrl.selectedCurrency, _kText, isHero: true),
                          _buildVerticalDivider(),
                          _buildSummaryStat("Allocated", _ctrl.totalAllocated, _ctrl.selectedCurrency, isOverAllocated ? _kError : _kText),
                          _buildVerticalDivider(),
                          _buildSummaryStat("Unallocated", unallocated, _ctrl.selectedCurrency, unallocated > 0 ? _kWarning : _kMuted),
                          _buildVerticalDivider(),
                          _buildSummaryStat("Advance", _ctrl.advanceAmount, _ctrl.selectedCurrency, _ctrl.advanceAmount > 0 ? _kWarning : _kMuted),
                          _buildVerticalDivider(),
                          _buildSummaryStat("INR Value", _ctrl.baseAmountInr, "INR", _kMuted, isSmall: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Semantics(
                        label: 'Save Payment Button',
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: _ctrl.isValidToSave && !isOverAllocated ? (isAdvanceOnly ? _kWarning : _kPrimary) : Colors.grey.shade300,
                              foregroundColor: _ctrl.isValidToSave && !isOverAllocated ? Colors.white : Colors.grey.shade500,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: _ctrl.isValidToSave && !isOverAllocated ? 2 : 0
                          ),
                          onPressed: (_ctrl.isValidToSave && !_ctrl.isSaving && !_isSavingLocal && !_ctrl.isLoadingInvoices && !isOverAllocated) ? () async {
                            if (_ctrl.isSaving || _isSavingLocal) return;

                            if (_ctrl.totalAllocated > _ctrl.totalReceived + 0.01) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot save. Allocated amount exceeds received amount.'),
                                  backgroundColor: _kError,
                                ),
                              );
                              return;
                            }

                            bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(isEdit ? 'Confirm Update' : 'Confirm Payment', style: const TextStyle(fontWeight: FontWeight.w900, color: _kText, letterSpacing: -0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isEdit ? 'Are you sure you want to update this payment?' : 'Are you sure you want to record this payment?', style: const TextStyle(color: _kMuted, fontSize: 14)),
                                        const SizedBox(height: 24),
                                        Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
                                            child: Column(
                                              children: [
                                                _buildBreakdownRow('Amount Received', _ctrl.totalReceived, isBold: true),
                                                const Divider(height: 24, color: _kBorder),
                                                _buildBreakdownRow('Allocated', _ctrl.totalAllocated),
                                                const SizedBox(height: 8),
                                                _buildBreakdownRow('Advance', _ctrl.advanceAmount, color: _ctrl.advanceAmount > 0 ? _kWarning : _kText),
                                              ],
                                            )
                                        )
                                      ]
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _kMuted))),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _kPrimary), child: const Text('Confirm')),
                                  ],
                                )
                            );
                            if (confirm != true) return;

                            try {
                              bool success = false;
                              if (isEdit) {
                                success = await _updatePaymentLocally();
                              } else {
                                // Since _ctrl.savePayment doesn't accept createdByName directly, we can ensure it is populated natively if the Controller gets upgraded
                                success = await _ctrl.savePayment();
                              }

                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Payment Updated successfully!' : 'Payment processed successfully!'), backgroundColor: _kSuccess));
                                Navigator.pop(context);
                              }
                              if (!success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to process payment. Please try again.'),
                                    backgroundColor: _kError,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unexpected error occurred'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } : () {
                            if (isOverAllocated) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot save. Allocated amount exceeds received amount.'),
                                  backgroundColor: _kError,
                                ),
                              );
                            }
                          },
                          icon: (_ctrl.isSaving || _isSavingLocal)
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : (isAdvanceOnly ? const Icon(Icons.account_balance_wallet, size: 20) : const Icon(Icons.check_circle_outline, size: 20)),
                          label: Text(btnLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ),
                      if (disableReason.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(disableReason, style: const TextStyle(color: _kError, fontSize: 13, fontWeight: FontWeight.w700))
                        )
                    ],
                  )
                ],
              ),
            ),
          );
        }
    );
  }

  Widget _buildSummaryStat(String label, double amount, String currency, Color color, {bool isHero = false, bool isSmall = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: isHero ? 13 : 12, color: _kMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
            currency == 'INR' ? '₹ ${_formatCurrency(amount, currency)}' : '${_getCurrencySymbol(currency)} ${_formatCurrency(amount, currency)}',
            style: TextStyle(fontSize: isHero ? 28 : (isSmall ? 16 : 20), fontWeight: isHero ? FontWeight.w900 : FontWeight.w800, color: color, letterSpacing: -0.5)
        )
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
        height: 36,
        width: 1,
        color: _kBorder,
        margin: const EdgeInsets.symmetric(horizontal: 32)
    );
  }

  Widget _buildBreakdownRow(String label, double amount, {bool isBold = false, Color color = _kText}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: _kMuted, fontSize: 14)),
        Text('$_currencySymbol ${_formatCurrency(amount, _ctrl.selectedCurrency)}', style: TextStyle(fontWeight: isBold ? FontWeight.w800 : FontWeight.w700, color: color, fontSize: 14)),
      ],
    );
  }
}

// --- Animated Hover Card ---
class _HoverCard extends StatefulWidget {
  final Widget child;
  final bool hasError;
  const _HoverCard({required this.child, this.hasError = false});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.hasError ? Colors.red.shade300 : (_isHovered ? _kPrimary.withValues(alpha: 0.5) : _kBorder), width: widget.hasError ? 1.5 : 1),
            boxShadow: [
              if (_isHovered) BoxShadow(color: _kPrimary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))
            ]
        ),
        child: widget.child,
      ),
    );
  }
}
