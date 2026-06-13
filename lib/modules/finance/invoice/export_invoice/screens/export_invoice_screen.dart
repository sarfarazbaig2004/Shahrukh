// 📌 FIRESTORE INDEX OPTIMIZATION NOTE:
// Ensure the following composite indexes exist in your Firebase Console:
// 1. collection: export_invoices -> companyId (Ascending) + createdAt (Descending)
// 2. collection: export_invoices -> customerId (Ascending) + status (Ascending)
// 3. collection: outstanding -> status (Ascending) + dueDate (Ascending)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/export_invoice_item.dart';
import '../models/export_invoice_model.dart';
import '../widgets/export_totals_card.dart';
import '../../widgets/dialog_select_customer.dart';
import '../widgets/dialog_add_export_item.dart';
import '../widgets/export_invoice_document_view.dart';
import '../../../payments_received/screens/record_payment_screen.dart';

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF3B82F6);
const Color backgroundBg = Color(0xFFF8FAFC);
const Color surfaceColor = Colors.white;

String safe(String? v) => (v ?? '').trim();

IconData _getPaymentModeIcon(String mode) {
  if (mode.contains('Bank') || mode.contains('Wire')) return Icons.account_balance;
  if (mode.contains('Credit') || mode.contains('LC')) return Icons.description;
  if (mode.contains('Cheque')) return Icons.money;
  if (mode.contains('Online') || mode.contains('Gateway')) return Icons.language;
  if (mode.contains('Cash')) return Icons.payments;
  return Icons.payment;
}

class ExportSummaryData {
  final double subtotal;
  final double freight;
  final double insurance;
  final double taxAmt;
  final double roundOff;
  final double grandTotalForeign;
  final double exchangeRate;
  final double outstanding;
  final double baseAmountOutstanding;
  final String paymentStatus;

  ExportSummaryData({
    required this.subtotal, required this.freight, required this.insurance,
    required this.taxAmt, required this.roundOff, required this.grandTotalForeign, required this.exchangeRate,
    required this.outstanding, required this.baseAmountOutstanding, required this.paymentStatus,
  });
}

class ExportInvoiceScreen extends StatefulWidget {
  final String companyId;
  final String userUid;
  final String? invoiceId;
  final VoidCallback? onBack;

  const ExportInvoiceScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.invoiceId,
    this.onBack,
  });

  @override
  State<ExportInvoiceScreen> createState() => _ExportInvoiceScreenState();
}

class _ExportInvoiceScreenState extends State<ExportInvoiceScreen> {
  late ExportInvoiceState _state;

  @override
  void initState() {
    super.initState();
    _state = ExportInvoiceState(companyId: widget.companyId, userUid: widget.userUid, invoiceId: widget.invoiceId, context: context);
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLocked = _state.isSubmitted || _state.isCancelled;
    return Scaffold(
      backgroundColor: backgroundBg,
      appBar: AppBar(
        backgroundColor: _state.isCancelled ? Colors.red.shade900 : const Color(0xFF0F2A3D),
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack) : null,
        title: Row(
          children: [
            Text(widget.invoiceId != null ? 'Edit Export Invoice' : 'Create Export Invoice', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            if (_state.isCancelled) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                child: const Text('CANCELLED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              )
            ]
          ],
        ),
        actions: [
          if (_state.isSubmitted && !_state.isCancelled)
            TextButton.icon(
              onPressed: () => _state.cancelInvoice(),
              icon: const Icon(Icons.cancel, color: Colors.white70, size: 18),
              label: const Text('Cancel Invoice', style: TextStyle(color: Colors.white70)),
            )
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _state.isLoading,
        builder: (context, isLoading, _) {
          if (isLoading) return const Center(child: CircularProgressIndicator());

          return LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 900;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildForm(context, isDesktop, isLocked)),
                  if (isDesktop) Expanded(flex: 3, child: _buildLiveSummaryPanel(context, isLocked)),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 900 ? _buildMobileBottomBar(context, isLocked) : null,
    );
  }

  Widget _buildForm(BuildContext context, bool isDesktop, bool isLocked) {
    return IgnorePointer(
      ignoring: isLocked || _state.isSaving.value,
      child: Form(
        key: _state.formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                title: '1. Invoice Details',
                icon: Icons.receipt_long,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _CustomField(
                                label: _state.invoiceId == null ? 'Draft Invoice No.' : 'Invoice No.',
                                controller: _state.invoiceNoCtrl,
                                required: true,
                                readOnly: true,
                                icon: Icons.numbers
                            )
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _state.invoiceDate,
                            builder: (context, date, _) => InkWell(
                              onTap: () async {
                                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (d != null) {
                                  _state.invoiceDate.value = d;
                                  _state.autoCalcDueDate();
                                }
                              },
                              child: InputDecorator(decoration: _inputDecoration('Invoice Date', Icons.calendar_today), child: Text(_state.formatDate(date))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValueListenableBuilder<String>(
                            valueListenable: _state.selectedPlaceOfSupply,
                            builder: (context, pos, _) => Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: pos,
                                  decoration: _inputDecoration('Place of Supply *', Icons.location_on),
                                  items: _state.placeOfSupplyOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (v) => _state.selectedPlaceOfSupply.value = v!,
                                ),
                                if (pos == 'Custom') ...[
                                  const SizedBox(height: 12),
                                  _CustomField(
                                    label: 'Enter Custom Place of Supply',
                                    controller: _state.customPlaceOfSupplyCtrl,
                                    required: true,
                                    validator: (v) {
                                      if (v == null || safe(v).isEmpty) return 'Required for Custom POS';
                                      return null;
                                    },
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _CustomField(label: 'Export Reference No.', controller: _state.exportRefCtrl)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValueListenableBuilder<DateTime?>(
                            valueListenable: _state.buyerOrderDateNotifier,
                            builder: (context, date, _) => InkWell(
                              onTap: () async {
                                final d = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (d != null) _state.buyerOrderDateNotifier.value = d;
                              },
                              child: InputDecorator(decoration: _inputDecoration('Buyer Order Date', Icons.event), child: Text(date != null ? _state.formatDate(date) : 'Select Date', style: TextStyle(color: date != null ? Colors.black87 : Colors.grey.shade600))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(
                          label: 'Supplier IEC (Auto-Fetched)',
                          controller: _state.supIEC,
                          icon: Icons.verified_user,
                          readOnly: true,
                          validator: (v) {
                            if (v != null && v.isNotEmpty && !RegExp(r'^[0-9]{10}$').hasMatch(v)) {
                              return 'Invalid IEC (Must be 10 digits)';
                            }
                            return null;
                          },
                        )),
                      ],
                    )
                  ],
                ),
              ),

              _SectionCard(
                title: '2. Tax & Compliance',
                icon: Icons.account_balance,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _state.isLUT,
                  builder: (context, isLUT, _) => ValueListenableBuilder<bool>(
                    valueListenable: _state.isReverseCharge,
                    builder: (context, isRC, _) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile(
                                  title: const Text('Export Under LUT / Bond (No IGST)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: const Text('Without payment of IGST', style: TextStyle(fontSize: 12)),
                                  value: isLUT,
                                  onChanged: _state.toggleLUT,
                                  activeThumbColor: accentColor,
                                  contentPadding: EdgeInsets.zero
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: SwitchListTile(
                                  title: const Text('Reverse Charge', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(isRC ? 'Yes' : 'No', style: TextStyle(fontSize: 12, color: isRC ? Colors.green : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                  value: isRC,
                                  onChanged: (v) => _state.isReverseCharge.value = v,
                                  activeThumbColor: accentColor,
                                  contentPadding: EdgeInsets.zero
                              ),
                            ),
                          ],
                        ),
                        if (isLUT) Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            children: [
                              Expanded(child: _CustomField(label: 'LUT Number', controller: _state.lutNumberCtrl, required: true)),
                              const SizedBox(width: 16),
                              Expanded(child: _CustomField(label: 'AD Code', controller: _state.adCodeCtrl)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              _SectionCard(
                title: '3. Forex Details',
                icon: Icons.currency_exchange,
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _state.selectedCurrency,
                        builder: (context, currency, _) => DropdownButtonFormField<String>(
                          initialValue: currency,
                          decoration: _inputDecoration('Currency', Icons.monetization_on),
                          items: _state.currencyItems,
                          onChanged: (v) => _state.selectedCurrency.value = v!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CustomField(
                            label: 'Exchange Rate (₹) *',
                            controller: _state.exchangeRateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            required: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if ((double.tryParse(safe(v)) ?? 0.0) <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                          ValueListenableBuilder(
                              valueListenable: _state.summaryState,
                              builder: (context, summary, __) {
                                return Text('1 ${_state.selectedCurrency.value} = ₹${summary.exchangeRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey));
                              }
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _SectionCard(
                title: '4. Buyer & Consignee',
                icon: Icons.local_shipping,
                action: _state.invoiceId != null
                    ? Chip(
                    label: const Text('Customer Locked', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(color: Colors.grey.shade300)
                )
                    : TextButton.icon(
                    onPressed: () => _pickCustomer(context),
                    icon: const Icon(Icons.search),
                    label: const Text('Select Customer')
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SubHeader('BUYER (BILL TO)'),
                          // ✅ STRICT FIX: Always Read-Only to prevent unlinked manual entries
                          _CustomField(label: 'Company Name *', controller: _state.billName, required: true, readOnly: true),
                          _CustomField(label: 'Address', controller: _state.billAddress, maxLines: 2, readOnly: true),
                          Row(children: [Expanded(child: _CustomField(label: 'Country', controller: _state.billCountry, readOnly: true)), const SizedBox(width: 8), Expanded(child: _CustomField(label: 'Email', controller: _state.billEmail, readOnly: true))]),
                          _CustomField(label: 'Contact No.', controller: _state.billPhone, readOnly: true),
                          _CustomField(label: 'Contact Person', controller: _state.billContact, readOnly: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _state.sameAsBill,
                        builder: (context, sameAsBill, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const _SubHeader('CONSIGNEE (SHIP TO)'), Row(children: [Switch(value: sameAsBill, onChanged: _state.invoiceId != null ? null : _state.toggleSameAsBill, activeThumbColor: accentColor), const Text('Same as Buyer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])]),
                            if (sameAsBill) Container(height: 120, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Center(child: Text("Consignee details matching Buyer.", style: TextStyle(color: Colors.grey))))
                            else Column(
                              children: [
                                _CustomField(label: 'Company Name *', controller: _state.shipName, required: true, readOnly: _state.invoiceId != null),
                                _CustomField(label: 'Address', controller: _state.shipAddress, maxLines: 2, readOnly: _state.invoiceId != null),
                                Row(children: [Expanded(child: _CustomField(label: 'Country', controller: _state.shipCountry, readOnly: _state.invoiceId != null)), const SizedBox(width: 8), Expanded(child: _CustomField(label: 'Email', controller: _state.shipEmail, readOnly: _state.invoiceId != null))]),
                                _CustomField(label: 'Contact No.', controller: _state.shipPhone, readOnly: _state.invoiceId != null),
                                _CustomField(label: 'Contact Person', controller: _state.shipContact, readOnly: _state.invoiceId != null),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _SectionCard(
                title: '5. Logistics & Transport',
                icon: Icons.flight_takeoff,
                child: ValueListenableBuilder<String>(
                  valueListenable: _state.selectedTransportMode,
                  builder: (context, transportMode, _) => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _CustomField(label: 'Pre-Carriage By', controller: _state.preCarriageCtrl)),
                          const SizedBox(width: 16),
                          Expanded(child: DropdownButtonFormField<String>(initialValue: transportMode, decoration: _inputDecoration('Mode of Transport', Icons.commute), items: _state.transportModeItems, onChanged: (v) => _state.selectedTransportMode.value = v!)),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(label: _state.carrierLabel, controller: _state.carrierCtrl)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _CustomField(label: _state.loadingLabel, controller: _state.loadingCtrl)),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(label: _state.dischargeLabel, controller: _state.dischargeCtrl)),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(
                            label: 'Port Code',
                            controller: _state.portCodeCtrl,
                            validator: (v) {
                              if(v != null && v.isNotEmpty && !RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(v)) return 'Invalid Port Code (6 chars)';
                              return null;
                            },
                          )),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _CustomField(label: 'Country of Origin', controller: _state.countryOrigin)),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(label: 'Final Destination', controller: _state.countryFinal)),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(label: 'Shipping Bill No.', controller: _state.shippingBillNoCtrl)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<DateTime?>(
                              valueListenable: _state.shippingBillDateNotifier,
                              builder: (context, date, _) => InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                  if (d != null) _state.shippingBillDateNotifier.value = d;
                                },
                                child: InputDecorator(decoration: _inputDecoration('Shipping Bill Date', Icons.calendar_month), child: Text(date != null ? _state.formatDate(date) : 'Select Date', style: TextStyle(color: date != null ? Colors.black87 : Colors.grey.shade600))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(label: 'Marks & Container No.', controller: _state.marksAndNosCtrl)),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(label: 'No. of Packages', controller: _state.packagesCtrl, keyboardType: TextInputType.number)),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(child: _CustomField(label: 'Gross Wt (KG)', controller: _state.grossWtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          const SizedBox(width: 16),
                          Expanded(child: _CustomField(label: 'Net Wt (KG)', controller: _state.netWtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                              child: _CustomField(
                                label: 'Freight Charges',
                                controller: _state.freightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                icon: Icons.local_shipping,
                                validator: (v) {
                                  if (v != null && v.isNotEmpty) {
                                    final val = double.tryParse(safe(v)) ?? 0.0;
                                    if (val < 0) return 'Cannot be negative';
                                  }
                                  return null;
                                },
                              )
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _CustomField(
                                label: 'Insurance Charges',
                                controller: _state.insuranceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                icon: Icons.security,
                                validator: (v) {
                                  if (v != null && v.isNotEmpty) {
                                    final val = double.tryParse(safe(v)) ?? 0.0;
                                    if (val < 0) return 'Cannot be negative';
                                  }
                                  return null;
                                },
                              )
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              _SectionCard(
                title: '6. Export Line Items',
                icon: Icons.inventory_2,
                action: ElevatedButton.icon(onPressed: () => _manageItem(context), icon: const Icon(Icons.add), label: const Text('Add Item'), style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white)),
                child: ValueListenableBuilder<List<ExportInvoiceItem>>(
                  valueListenable: _state.items,
                  builder: (context, itemsList, _) {
                    if (itemsList.isEmpty) return Container(padding: const EdgeInsets.all(32), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)), child: const Text('No items added. Click "Add Item" to begin.', style: TextStyle(color: Colors.grey, fontSize: 16)));
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text('HSN', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text(''))],
                        rows: itemsList.asMap().entries.map((entry) {
                          int idx = entry.key; ExportInvoiceItem item = entry.value;
                          return DataRow(cells: [
                            DataCell(Text(item.name)), DataCell(Text(item.hsnCode)), DataCell(Text('${item.quantity} ${item.unit}')), DataCell(Text(item.rate.toStringAsFixed(2))), DataCell(Text('${_state.selectedCurrency.value} ${item.computedAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, size: 18, color: accentColor), onPressed: () => _manageItem(context, existingItem: item, index: idx)), IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _state.removeItem(idx))])),
                          ]);
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),

              _SectionCard(
                title: '7. Bank & Delivery Terms',
                icon: Icons.account_balance_wallet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20), const SizedBox(width: 8), const Expanded(child: Text('Note: Financial payments are tracked strictly in the Payments module. Invoice ledger reflects grand total.', style: TextStyle(color: Colors.black87, fontSize: 13)))])
                    ),
                    Row(
                      children: [
                        Expanded(
                          // ✅ STRICT FIX: Listen to non-nullable type String
                          child: ValueListenableBuilder<String>(
                            valueListenable: _state.selectedPaymentMode,
                            builder: (context, paymentMode, _) => DropdownButtonFormField<String>(
                              initialValue: paymentMode,
                              decoration: _inputDecoration('Mode of Realisation *', Icons.payment),
                              items: _state.paymentModeItems,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              onChanged: (v) => _state.selectedPaymentMode.value = v!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: 'PO / Ref No.', controller: _state.paymentRefCtrl)),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<String>(
                            valueListenable: _state.selectedPaymentTermState,
                            builder: (context, currentTerm, _) => Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: currentTerm,
                                  decoration: _inputDecoration('Payment Terms (Due Logic)', Icons.handshake),
                                  items: _state.paymentTermsList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      _state.selectedPaymentTermState.value = v;
                                      _state.autoCalcDueDate();
                                    }
                                  },
                                ),
                                if (currentTerm == 'Custom Terms') ...[
                                  const SizedBox(height: 12),
                                  _CustomField(
                                    label: 'Enter Custom Term Details',
                                    controller: _state.customPaymentTermCtrl,
                                    required: true,
                                    validator: (v) => v == null || safe(v).isEmpty ? 'Required' : null,
                                    onChanged: (_) => _state.autoCalcDueDate(),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _state.dueDateNotifier,
                            builder: (context, dueDate, _) => InkWell(
                              onTap: () async {
                                final d = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (d != null) {
                                  if (_state.selectedPaymentTermState.value != 'Custom Terms') {
                                    _state.selectedPaymentTermState.value = 'Custom Terms';
                                  }
                                  _state.dueDateNotifier.value = d;
                                }
                              },
                              child: InputDecorator(decoration: _inputDecoration('Calculated Due Date', Icons.event_available), child: Text(_state.formatDate(dueDate), style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _CustomField(label: 'Beneficiary Name', controller: _state.beneficiaryNameCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: 'Bank Name', controller: _state.bankNameCtrl)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _CustomField(label: 'A/C Number', controller: _state.accNoCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(
                          label: 'IFSC Code',
                          controller: _state.ifscCtrl,
                          validator: (v) {
                            if (v != null && v.isNotEmpty && !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v)) return 'Invalid IFSC (e.g. SBIN0123456)';
                            return null;
                          },
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(
                          label: 'SWIFT Code',
                          controller: _state.swiftCtrl,
                          validator: (v) {
                            if (v != null && v.isNotEmpty && !RegExp(r'^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$').hasMatch(v)) return 'Invalid SWIFT';
                            return null;
                          },
                        )),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _CustomField(label: 'Bank Address', controller: _state.bankAddressCtrl)),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: _CustomField(label: 'Delivery Terms (Shipping)', controller: _state.deliveryTermsCtrl)),
                      ],
                    ),
                    _CustomField(label: 'Invoice Declaration', controller: _state.declarationCtrl, maxLines: 3),
                    _CustomField(label: 'Internal Notes', controller: _state.notesCtrl, maxLines: 2),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSummaryPanel(BuildContext context, bool isLocked) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: surfaceColor, border: Border(left: BorderSide(color: Colors.grey.shade200)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(-5, 0))]),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _state.isCancelled ? Colors.red.shade900 : const Color(0xFF0F2A3D), border: Border(bottom: BorderSide(color: Colors.grey.shade800))), child: Row(children: [const Icon(Icons.analytics, color: Colors.white), const SizedBox(width: 12), Text(_state.isCancelled ? 'Cancelled Document' : 'Live Summary', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))])),
          Expanded(
            child: IgnorePointer(
              ignoring: isLocked || _state.isSaving.value,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: _state.selectedIncoterm,
                      builder: (context, incoterm, _) => DropdownButtonFormField<String>(
                        initialValue: incoterm,
                        decoration: _inputDecoration('Incoterms (Affects Pricing)', Icons.handshake),
                        items: _state.incotermsList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) {
                          _state.selectedIncoterm.value = v!;
                          _state.summaryState.value = _state._computeSummary();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    ValueListenableBuilder<ExportSummaryData>(
                      valueListenable: _state.summaryState,
                      builder: (context, summary, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (summary.roundOff != 0.0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                                child: Text('Round Off: ${summary.roundOff > 0 ? '+' : ''}${summary.roundOff.toStringAsFixed(2)}', textAlign: TextAlign.right, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                              ),
                            ExportTotalsCard(
                              subtotal: summary.subtotal,
                              freight: summary.freight,
                              insurance: summary.insurance,
                              taxAmt: summary.taxAmt,
                              grandTotalForeign: summary.grandTotalForeign,
                              exchangeRate: summary.exchangeRate,
                              currency: _state.selectedCurrency.value,
                              isLut: _state.isLUT.value,
                              amountReceived: _state.existingAmountReceived,
                              amountOutstanding: summary.outstanding,
                              paymentStatus: summary.paymentStatus,
                            ),
                          ],
                        );
                      },
                    ),

                    ValueListenableBuilder<bool>(
                      valueListenable: _state.isReverseCharge,
                      builder: (context, isRC, _) {
                        if (!isRC) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tax payable under Reverse Charge',
                                  style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (!isLocked)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: ValueListenableBuilder<bool>(
                valueListenable: _state.isSaving,
                builder: (context, isSaving, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(onPressed: isSaving ? null : () => _handlePreview(context), icon: const Icon(Icons.picture_as_pdf), label: const Text('Preview Document'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(onPressed: isSaving ? null : () => _handleSave(context, isDraft: true), icon: const Icon(Icons.drafts, color: Colors.black87), label: Text(_state.invoiceId != null ? 'Update Draft' : 'Save as Draft', style: const TextStyle(color: Colors.black87)), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                        onPressed: isSaving ? null : () => _handleSave(context, isDraft: false),
                        icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                        label: Text(isSaving ? 'Processing...' : 'Final Submit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, disabledBackgroundColor: Colors.blue.shade200, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(BuildContext context, bool isLocked) {
    if (isLocked) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
        valueListenable: _state.isSaving,
        builder: (context, isSaving, _) {
          return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
              child: SafeArea(
                  child: Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: isSaving ? null : () => _handlePreview(context), child: const Text('Preview'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: ElevatedButton(
                                onPressed: isSaving ? null : () => _handleSave(context, isDraft: false),
                                style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Submit')
                            )
                        )
                      ]
                  )
              )
          );
        }
    );
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => DialogSelectCustomer(companyId: widget.companyId));
    if (result != null) _state.applyCustomer(result);
  }

  Future<void> _manageItem(BuildContext context, {ExportInvoiceItem? existingItem, int? index}) async {
    final result = await showDialog<ExportInvoiceItem>(context: context, builder: (_) => DialogAddExportItem(companyId: widget.companyId, userUid: widget.userUid, selectedCurrency: _state.selectedCurrency.value, existingItem: existingItem));
    if (result != null) _state.saveItem(result, index);
  }

  void _handlePreview(BuildContext context) {
    if ((_state.selectedCustomerId ?? '').trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer first.'), backgroundColor: Colors.red)); return; }
    if (_state.items.value.where((e) => safe(e.name).isNotEmpty).isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least 1 item.'), backgroundColor: Colors.red)); return; }

    if (_state.items.value.any((item) => safe(item.hsnCode).isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HSN Code is mandatory for all export items.'), backgroundColor: Colors.red));
      return;
    }

    String safeNumber = safe(_state.invoiceNoCtrl.text).replaceAll(' (Preview)', '');
    if (safeNumber.isEmpty) safeNumber = _state.generateDraftInvoiceNumber();
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExportInvoiceDocumentView(invoice: _state.buildModel('Draft', safeNumber))));
  }

  // ✅ STRICT FIX: Handle all UI validation explicitly BEFORE calling saveToFirestore
  Future<void> _handleSave(BuildContext context, {required bool isDraft}) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Prevent hidden snackbar queuing

    if (_state.isSubmitted || _state.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice is locked and cannot be edited.'), backgroundColor: Colors.red));
      return;
    }

    // Explicit Front-end checks
    if ((_state.selectedCustomerId ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: You must select a customer before saving.'), backgroundColor: Colors.red));
      return;
    }

    if (_state.items.value.isEmpty || _state.items.value.where((e) => safe(e.name).isNotEmpty).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: At least 1 valid line item is required.'), backgroundColor: Colors.red));
      return;
    }

    if (_state.subtotal <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Total amount must be greater than 0.'), backgroundColor: Colors.red)); return; }

    if (!_state.formKey.currentState!.validate()) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields correctly.'), backgroundColor: Colors.red)); return; }

    try {
      await _state.saveToFirestore(isDraft ? 'Draft' : 'Submitted');

      if (!mounted) return;

      showDialog(
          context: context, barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Column(children: [Icon(Icons.check_circle, color: Colors.green, size: 48), SizedBox(height: 16), Text('Invoice Saved!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))]),
            content: Text(isDraft ? 'Your draft has been securely saved.' : 'Your invoice has been securely saved to the ERP. Outstanding ledgers have been updated automatically.', textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(onPressed: () { Navigator.pop(ctx); if (widget.onBack != null) widget.onBack!(); }, child: const Text('Done', style: TextStyle(color: Colors.grey))),
              if (!isDraft) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                  onPressed: () {
                    Navigator.pop(ctx); if (widget.onBack != null) widget.onBack!();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RecordPaymentScreen(
                      companyId: widget.companyId,
                      userUid: widget.userUid,
                      customerName: safe(_state.billName.text),
                    )));
                  },
                  child: const Text('Record Payment', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          )
      );
    } catch (e, stack) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('❌ FIRESTORE SAVE ERROR: $e');
        debugPrint(stack.toString());
      }

      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Save Failed: $errorMsg', style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
    }
  }
}

// ============================================================================
// STATE CONTROLLER
// ============================================================================

class ExportInvoiceState {
  final String companyId;
  final String userUid;
  final String? invoiceId;
  final BuildContext context;

  ExportInvoiceState({required this.companyId, required this.userUid, this.invoiceId, required this.context});

  final formKey = GlobalKey<FormState>();

  final isLoading = ValueNotifier<bool>(true);
  final isSaving = ValueNotifier<bool>(false);
  final isLUT = ValueNotifier<bool>(true);
  final isReverseCharge = ValueNotifier<bool>(false);
  final sameAsBill = ValueNotifier<bool>(false);

  final selectedCurrency = ValueNotifier<String>('USD');
  final selectedTransportMode = ValueNotifier<String>('Sea / Ship');

  // ✅ STRICT FIX: Initialized to non-nullable default to prevent transaction failures
  final selectedPaymentMode = ValueNotifier<String>('Bank Transfer');

  final selectedIncoterm = ValueNotifier<String>('FOB');
  final selectedPlaceOfSupply = ValueNotifier<String>('Out of India');
  final selectedPaymentTermState = ValueNotifier<String>('Due on Receipt');

  bool isSubmitted = false;
  bool isCancelled = false;
  int currentVersion = 0;

  final invoiceDate = ValueNotifier<DateTime>(DateTime.now());
  final buyerOrderDateNotifier = ValueNotifier<DateTime?>(null);
  final shippingBillDateNotifier = ValueNotifier<DateTime?>(null);
  final dueDateNotifier = ValueNotifier<DateTime>(DateTime.now());
  final taxRate = ValueNotifier<double>(18.0);
  final items = ValueNotifier<List<ExportInvoiceItem>>([]);

  late final List<DropdownMenuItem<String>> paymentModeItems;
  late final List<DropdownMenuItem<String>> currencyItems;
  late final List<DropdownMenuItem<String>> transportModeItems;

  final List<String> incotermsList = ['FOB', 'CIF', 'EXW', 'DAP', 'FCA', 'CFR', 'CPT', 'CIP', 'DDP'];
  final List<String> paymentModes = ['Bank Transfer', 'Wire Transfer (SWIFT / TT)', 'Letter of Credit (LC)', 'Documents Against Payment (DP)', 'Documents Against Acceptance (DA)', 'Cash', 'Cheque', 'Online Payment Gateway', 'Other'];
  final List<String> paymentTermsList = ['Advance', 'Due on Receipt', 'Net 15 Days', 'Net 30 Days', 'Net 45 Days', 'Net 60 Days', 'LC at Sight', 'DP at Sight', 'DA 30 Days', 'CAD', 'Custom Terms'];
  final List<String> placeOfSupplyOptions = ['Out of India', 'SEZ', 'Deemed Export', 'Custom'];
  final List<String> currencies = ['USD', 'EUR', 'AED', 'GBP', 'INR', 'AUD', 'SGD'];
  final List<String> transportModes = ['Sea / Ship', 'Air / Cargo', 'Road', 'Rail', 'Other'];

  double existingAmountReceived = 0.0;
  String existingPaymentStatus = 'UNPAID';

  final invoiceNoCtrl = TextEditingController();
  final customPlaceOfSupplyCtrl = TextEditingController();
  final exportRefCtrl = TextEditingController();

  final supName = TextEditingController(); final supAddress = TextEditingController(); final supGSTIN = TextEditingController(); final supPAN = TextEditingController(); final supIEC = TextEditingController(); final supState = TextEditingController();
  final lutNumberCtrl = TextEditingController(); final adCodeCtrl = TextEditingController();
  final exchangeRateCtrl = TextEditingController(text: "83.50");

  final customPaymentTermCtrl = TextEditingController();

  String? selectedCustomerId;
  final billName = TextEditingController(); final billAddress = TextEditingController(); final billCountry = TextEditingController(); final billEmail = TextEditingController(); final billPhone = TextEditingController(); final billContact = TextEditingController();
  final shipName = TextEditingController(); final shipAddress = TextEditingController(); final shipCountry = TextEditingController(); final shipEmail = TextEditingController(); final shipPhone = TextEditingController(); final shipContact = TextEditingController();

  final preCarriageCtrl = TextEditingController(); final loadingCtrl = TextEditingController(); final dischargeCtrl = TextEditingController(); final carrierCtrl = TextEditingController();
  final countryOrigin = TextEditingController(text: "India"); final countryFinal = TextEditingController(); final portCodeCtrl = TextEditingController(); final shippingBillNoCtrl = TextEditingController();
  final marksAndNosCtrl = TextEditingController(); final packagesCtrl = TextEditingController(text: "1"); final grossWtCtrl = TextEditingController(text: "0.0"); final netWtCtrl = TextEditingController(text: "0.0");

  final freightCtrl = TextEditingController(text: "0.0"); final insuranceCtrl = TextEditingController(text: "0.0");
  final paymentRefCtrl = TextEditingController();
  final beneficiaryNameCtrl = TextEditingController();
  final bankNameCtrl = TextEditingController();
  final bankAddressCtrl = TextEditingController();
  final accNoCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();
  final swiftCtrl = TextEditingController();
  final deliveryTermsCtrl = TextEditingController();
  final declarationCtrl = TextEditingController(); final notesCtrl = TextEditingController(); final signatoryCtrl = TextEditingController(text: "Authorised Signatory");

  late final ValueNotifier<ExportSummaryData> summaryState;

  Future<void> init() async {
    isLoading.value = true;

    currencyItems = currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList();
    transportModeItems = transportModes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList();
    paymentModeItems = paymentModes.map((c) => DropdownMenuItem(value: c, child: Row(children: [Icon(_getPaymentModeIcon(c), size: 16, color: Colors.blueGrey), const SizedBox(width: 8), Text(c)]))).toList();

    summaryState = ValueNotifier(_computeSummary());

    void updateSummary() => summaryState.value = _computeSummary();
    freightCtrl.addListener(updateSummary);
    insuranceCtrl.addListener(updateSummary);
    exchangeRateCtrl.addListener(updateSummary);
    items.addListener(updateSummary);
    isLUT.addListener(updateSummary);
    taxRate.addListener(updateSummary);
    selectedCurrency.addListener(updateSummary);

    invoiceDate.addListener(autoCalcDueDate);

    if (invoiceId != null && invoiceId!.isNotEmpty) {
      await _loadExistingInvoice();
    } else {
      invoiceNoCtrl.text = generateDraftInvoiceNumber();
      await _loadSupplierDetails();
      autoCalcDueDate();
    }
    isLoading.value = false;
  }

  String generateDraftInvoiceNumber() {
    final now = DateTime.now();
    final yyyymmdd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomId = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'DRAFT-$yyyymmdd-$randomId';
  }

  Future<String> generateInvoiceNumber(Transaction tx) async {
    final counterRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('counters')
        .doc('export_invoice_counter');

    final counterSnap = await tx.get(counterRef);
    int nextSeq = 1;
    if (counterSnap.exists) {
      final counterMap = counterSnap.data();
      nextSeq = (counterMap?['currentValue'] ?? 0) + 1;
    }

    tx.set(counterRef, {
      'currentValue': nextSeq
    }, SetOptions(merge: true));

    final now = DateTime.now();
    final currentYear = now.year % 100;
    String fy;
    if (now.month >= 4) {
      fy = '${currentYear.toString().padLeft(2, '0')}-${(currentYear + 1).toString().padLeft(2, '0')}';
    } else {
      fy = '${(currentYear - 1).toString().padLeft(2, '0')}-${currentYear.toString().padLeft(2, '0')}';
    }

    return 'EXP/$fy/${nextSeq.toString().padLeft(4, '0')}';
  }

  void dispose() {
    isLoading.dispose(); isSaving.dispose(); isLUT.dispose(); isReverseCharge.dispose(); sameAsBill.dispose();
    selectedCurrency.dispose(); selectedTransportMode.dispose(); selectedPaymentMode.dispose();
    selectedIncoterm.dispose(); buyerOrderDateNotifier.dispose(); shippingBillDateNotifier.dispose();
    selectedPlaceOfSupply.dispose(); selectedPaymentTermState.dispose();
    invoiceDate.dispose(); dueDateNotifier.dispose(); taxRate.dispose(); items.dispose(); summaryState.dispose();
    invoiceNoCtrl.dispose(); customPlaceOfSupplyCtrl.dispose(); exchangeRateCtrl.dispose(); exportRefCtrl.dispose();
    customPaymentTermCtrl.dispose();
    supName.dispose(); supAddress.dispose(); supGSTIN.dispose(); supPAN.dispose(); supIEC.dispose(); supState.dispose();
    lutNumberCtrl.dispose(); adCodeCtrl.dispose(); billName.dispose(); billAddress.dispose(); billCountry.dispose(); billEmail.dispose(); billPhone.dispose(); billContact.dispose();
    shipName.dispose(); shipAddress.dispose(); shipCountry.dispose(); shipEmail.dispose(); shipPhone.dispose(); shipContact.dispose();
    preCarriageCtrl.dispose(); loadingCtrl.dispose(); dischargeCtrl.dispose(); carrierCtrl.dispose(); countryOrigin.dispose(); countryFinal.dispose(); portCodeCtrl.dispose(); shippingBillNoCtrl.dispose();
    marksAndNosCtrl.dispose(); packagesCtrl.dispose(); grossWtCtrl.dispose(); netWtCtrl.dispose();
    freightCtrl.dispose(); insuranceCtrl.dispose(); paymentRefCtrl.dispose(); beneficiaryNameCtrl.dispose(); bankNameCtrl.dispose(); bankAddressCtrl.dispose(); accNoCtrl.dispose(); ifscCtrl.dispose(); swiftCtrl.dispose(); deliveryTermsCtrl.dispose();
    declarationCtrl.dispose(); notesCtrl.dispose(); signatoryCtrl.dispose();
  }

  double _round(double val) => double.parse(val.toStringAsFixed(2));

  ExportSummaryData _computeSummary() {
    double sub = _round(subtotal);
    double fr = 0.0;
    double ins = 0.0;

    String incoterm = selectedIncoterm.value.toUpperCase();

    if (['CFR', 'CPT'].contains(incoterm)) {
      fr = _round(double.tryParse(safe(freightCtrl.text)) ?? 0.0);
    } else if (['CIF', 'CIP', 'DAP', 'DDP'].contains(incoterm)) {
      fr = _round(double.tryParse(safe(freightCtrl.text)) ?? 0.0);
      ins = _round(double.tryParse(safe(insuranceCtrl.text)) ?? 0.0);
    }

    double tax = isLUT.value ? 0.0 : _round((sub + fr + ins) * (taxRate.value / 100));

    double rawGt = sub + fr + ins + tax;
    double gt = rawGt.roundToDouble();
    double roundOff = _round(gt - rawGt);

    double er = double.tryParse(safe(exchangeRateCtrl.text)) ?? 0.0;
    if (er <= 0) er = 1.0;
    er = _round(er);

    double out = _round(gt - existingAmountReceived);
    if (out < 0) out = 0;

    double baseOut = _round(out * er);

    String stat = "DRAFT";
    if (gt > 0) {
      if (_round(existingAmountReceived) == 0.0) {
        stat = "UNPAID";
      } else if (_round(existingAmountReceived) >= gt) {
        stat = "PAID";
      } else {
        stat = "PARTIALLY PAID";
      }
    }

    return ExportSummaryData(
        subtotal: sub,
        freight: fr,
        insurance: ins,
        taxAmt: tax,
        roundOff: roundOff,
        grandTotalForeign: gt,
        exchangeRate: er,
        outstanding: out,
        baseAmountOutstanding: baseOut,
        paymentStatus: stat
    );
  }

  void autoCalcDueDate() {
    final d = invoiceDate.value;
    final String term = selectedPaymentTermState.value == 'Custom Terms'
        ? safe(customPaymentTermCtrl.text).toLowerCase()
        : selectedPaymentTermState.value.toLowerCase();

    if (term.contains('net 15')) {
      dueDateNotifier.value = d.add(const Duration(days: 15));
    } else if (term.contains('net 30') || term.contains('da 30')) {
      dueDateNotifier.value = d.add(const Duration(days: 30));
    } else if (term.contains('net 45')) {
      dueDateNotifier.value = d.add(const Duration(days: 45));
    } else if (term.contains('net 60')) {
      dueDateNotifier.value = d.add(const Duration(days: 60));
    } else {
      dueDateNotifier.value = d;
    }
  }

  String formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String get loadingLabel => selectedTransportMode.value == 'Air / Cargo' ? 'Airport of Loading' : selectedTransportMode.value == 'Road' ? 'Place of Receipt' : selectedTransportMode.value == 'Rail' ? 'Station of Loading' : 'Port of Loading';
  String get dischargeLabel => selectedTransportMode.value == 'Air / Cargo' ? 'Airport of Discharge' : selectedTransportMode.value == 'Road' ? 'Place of Delivery' : selectedTransportMode.value == 'Rail' ? 'Station of Discharge' : 'Port of Discharge';
  String get carrierLabel => selectedTransportMode.value == 'Air / Cargo' ? 'Flight Number' : selectedTransportMode.value == 'Road' ? 'Vehicle Number' : selectedTransportMode.value == 'Rail' ? 'Train Number' : 'Vessel Name / Voyage No.';
  double get subtotal => items.value.fold(0.0, (total, item) => total + item.computedAmount);

  Future<void> _loadExistingInvoice() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).collection('export_invoices').doc(invoiceId).get();
      if (doc.exists && doc.data() != null) {
        final dataMap = doc.data()!;
        final inv = ExportInvoiceModel.fromMap(dataMap, doc.id);

        isSubmitted = inv.status == 'Submitted';
        isCancelled = inv.status == 'Cancelled';
        currentVersion = dataMap['version'] ?? 0;
        selectedCustomerId = inv.customerId;

        invoiceNoCtrl.text = inv.invoiceNumber; invoiceDate.value = inv.invoiceDate;

        if (paymentTermsList.contains(inv.paymentTerms)) {
          selectedPaymentTermState.value = inv.paymentTerms;
        } else {
          selectedPaymentTermState.value = 'Custom Terms';
          customPaymentTermCtrl.text = inv.paymentTerms;
        }
        dueDateNotifier.value = inv.dueDate;

        if (placeOfSupplyOptions.contains(inv.placeOfSupply)) {
          selectedPlaceOfSupply.value = inv.placeOfSupply;
        } else {
          selectedPlaceOfSupply.value = 'Custom';
          customPlaceOfSupplyCtrl.text = inv.placeOfSupply;
        }

        isLUT.value = inv.exportDetails.exportType == 'WITH_LUT';
        isReverseCharge.value = inv.taxDetails.reverseCharge;
        lutNumberCtrl.text = inv.exportDetails.lutNumber; adCodeCtrl.text = inv.exportDetails.adCode; selectedCurrency.value = currencies.contains(inv.currency) ? inv.currency : 'USD'; exchangeRateCtrl.text = inv.exchangeRate.toString();

        exportRefCtrl.text = inv.exportReference;
        buyerOrderDateNotifier.value = inv.buyerOrderDate;
        selectedIncoterm.value = incotermsList.contains(inv.exportDetails.incoterm) ? inv.exportDetails.incoterm : 'FOB';

        billName.text = inv.buyer.name; billAddress.text = inv.buyer.address; billCountry.text = inv.buyer.country; billEmail.text = inv.buyer.email; billPhone.text = inv.buyer.phone; billContact.text = inv.buyer.contactPerson;
        shipName.text = inv.consignee.name; shipAddress.text = inv.consignee.address; shipCountry.text = inv.consignee.country; shipEmail.text = inv.consignee.email; shipPhone.text = inv.consignee.phone; shipContact.text = inv.consignee.contactPerson; sameAsBill.value = (billName.text == shipName.text && billAddress.text == shipAddress.text);

        preCarriageCtrl.text = inv.logistics.preCarriageBy; selectedTransportMode.value = transportModes.contains(inv.logistics.modeOfTransport) ? inv.logistics.modeOfTransport : 'Sea / Ship'; carrierCtrl.text = inv.logistics.vesselOrFlight; loadingCtrl.text = inv.exportDetails.portOfLoading; dischargeCtrl.text = inv.exportDetails.portOfDischarge; countryOrigin.text = inv.exportDetails.countryOfOrigin; countryFinal.text = inv.exportDetails.countryOfDestination; portCodeCtrl.text = inv.exportDetails.portCode; shippingBillNoCtrl.text = inv.logistics.shippingBillNo; shippingBillDateNotifier.value = inv.logistics.shippingBillDate; marksAndNosCtrl.text = inv.logistics.marksAndNos; packagesCtrl.text = inv.logistics.numberOfPackages.toString(); grossWtCtrl.text = inv.logistics.grossWeight.toString(); netWtCtrl.text = inv.logistics.netWeight.toString();

        freightCtrl.text = inv.totals.freight.toString(); insuranceCtrl.text = inv.totals.insurance.toString(); taxRate.value = inv.taxDetails.igstRate; items.value = inv.items;

        selectedPaymentMode.value = paymentModes.contains(inv.paymentDetails.paymentMode) ? inv.paymentDetails.paymentMode : 'Bank Transfer';
        paymentRefCtrl.text = inv.paymentDetails.paymentReference;
        deliveryTermsCtrl.text = inv.paymentDetails.deliveryTerms;
        beneficiaryNameCtrl.text = inv.paymentDetails.beneficiaryName;
        bankNameCtrl.text = inv.paymentDetails.bankName;
        bankAddressCtrl.text = inv.paymentDetails.bankAddress;
        accNoCtrl.text = inv.paymentDetails.accountNumber;
        ifscCtrl.text = inv.paymentDetails.ifsc;
        swiftCtrl.text = inv.paymentDetails.swiftCode;

        declarationCtrl.text = inv.declaration; notesCtrl.text = inv.notes; signatoryCtrl.text = inv.authorizedSignatory;

        existingAmountReceived = inv.amountReceived;
        existingPaymentStatus = inv.paymentStatus;
        await _loadSupplierDetails();
      }
    } catch (e) {
      debugPrint("Error loading existing invoice: $e");
    }
  }

  Future<void> _loadSupplierDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        supName.text = data['name'] ?? data['companyName'] ?? ''; supAddress.text = data['address'] ?? ''; supGSTIN.text = data['gstin'] ?? data['gstNo'] ?? ''; supPAN.text = data['pan'] ?? '';
        supIEC.text = data['iec'] ?? data['iecCode'] ?? '';
        supState.text = data['state'] ?? '';
        if(bankNameCtrl.text.isEmpty) bankNameCtrl.text = data['bankName'] ?? ''; if(accNoCtrl.text.isEmpty) accNoCtrl.text = data['accountNumber'] ?? ''; if(ifscCtrl.text.isEmpty) ifscCtrl.text = data['ifsc'] ?? ''; if(swiftCtrl.text.isEmpty) swiftCtrl.text = data['swiftCode'] ?? ''; if(lutNumberCtrl.text.isEmpty) lutNumberCtrl.text = data['lutNumber'] ?? ''; if(adCodeCtrl.text.isEmpty) adCodeCtrl.text = data['adCode'] ?? '';
      }
    } catch (e) { debugPrint("Error fetching company details: $e"); }
  }

  void toggleLUT(bool val) { isLUT.value = val; _updateDeclaration(); }
  void toggleSameAsBill(bool val) { sameAsBill.value = val; if (val) _copyBillToShip(); }
  void handleBillToChange() { if (sameAsBill.value) _copyBillToShip(); }
  void saveItem(ExportInvoiceItem item, int? index) { final list = List<ExportInvoiceItem>.from(items.value); if (index != null) {
    list[index] = item;
  } else {
    list.add(item);
  } items.value = list; }
  void removeItem(int index) { final list = List<ExportInvoiceItem>.from(items.value); list.removeAt(index); items.value = list; }

  void _copyBillToShip() { shipName.text = billName.text; shipAddress.text = billAddress.text; shipCountry.text = billCountry.text; shipEmail.text = billEmail.text; shipPhone.text = billPhone.text; shipContact.text = billContact.text; }

  void _updateDeclaration() {
    declarationCtrl.text = isLUT.value ? "We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.\nSupply meant for export under Letter of Undertaking without payment of IGST." : "We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.\nSupply meant for export on payment of IGST.";
  }

  void applyCustomer(Map<String, dynamic> result) {
    selectedCustomerId = result['id'];
    billName.text = (result['companyName'] ?? result['name'] ?? '').toString(); billAddress.text = (result['address'] ?? result['billingAddress'] ?? '').toString(); billEmail.text = (result['email'] ?? '').toString(); billPhone.text = (result['mobile'] ?? result['phone'] ?? '').toString(); billContact.text = (result['contactPerson'] ?? result['contactName'] ?? '').toString(); billCountry.text = (result['country'] ?? '').toString();
    if (sameAsBill.value) _copyBillToShip();
  }

  ExportInvoiceModel buildModel(String status, String calculatedInvoiceNo) {
    ExportSummaryData summary = _computeSummary();

    double grandTotalINR = _round((summary.grandTotalForeign * summary.exchangeRate));
    String finalStatus = status;
    String finalPlaceOfSupply = selectedPlaceOfSupply.value == 'Custom' ? safe(customPlaceOfSupplyCtrl.text) : selectedPlaceOfSupply.value;
    String finalPaymentTerm = selectedPaymentTermState.value == 'Custom Terms' ? safe(customPaymentTermCtrl.text) : selectedPaymentTermState.value;

    return ExportInvoiceModel(
      id: invoiceId ?? '',
      companyId: companyId,
      customerId: selectedCustomerId ?? '',
      exportReference: safe(exportRefCtrl.text),
      buyerOrderDate: buyerOrderDateNotifier.value,
      invoiceNumber: calculatedInvoiceNo,
      invoiceDate: invoiceDate.value,
      dueDate: dueDateNotifier.value,
      paymentTerms: finalPaymentTerm,
      baseCurrency: 'INR',
      baseAmount: grandTotalINR,
      currency: selectedCurrency.value,
      exchangeRate: summary.exchangeRate,
      placeOfSupply: finalPlaceOfSupply,
      status: finalStatus,
      createdBy: userUid,
      supplier: Party(name: safe(supName.text), address: safe(supAddress.text), country: "India", state: safe(supState.text), gstin: safe(supGSTIN.text), pan: safe(supPAN.text), iec: safe(supIEC.text)),
      buyer: Party(name: safe(billName.text), address: safe(billAddress.text), country: safe(billCountry.text), email: safe(billEmail.text), phone: safe(billPhone.text), contactPerson: safe(billContact.text)),
      consignee: Party(name: safe(shipName.text), address: safe(shipAddress.text), country: safe(shipCountry.text), email: safe(shipEmail.text), phone: safe(shipPhone.text), contactPerson: safe(shipContact.text)),
      exportDetails: ExportDetails(exportType: isLUT.value ? 'WITH_LUT' : 'WITH_IGST', lutNumber: safe(lutNumberCtrl.text), adCode: safe(adCodeCtrl.text), portCode: safe(portCodeCtrl.text), portOfLoading: safe(loadingCtrl.text), portOfDischarge: safe(dischargeCtrl.text), countryOfOrigin: safe(countryOrigin.text), countryOfDestination: safe(countryFinal.text), incoterm: selectedIncoterm.value),
      logistics: Logistics(preCarriageBy: safe(preCarriageCtrl.text), modeOfTransport: selectedTransportMode.value, vesselOrFlight: safe(carrierCtrl.text), shippingBillNo: safe(shippingBillNoCtrl.text), shippingBillDate: shippingBillDateNotifier.value, marksAndNos: safe(marksAndNosCtrl.text), numberOfPackages: int.tryParse(safe(packagesCtrl.text)) ?? 1, grossWeight: double.tryParse(safe(grossWtCtrl.text)) ?? 0, netWeight: double.tryParse(safe(netWtCtrl.text)) ?? 0),
      items: items.value
          .where((e) => safe(e.name).isNotEmpty && e.quantity > 0 && e.rate > 0)
          .map((e) => ExportInvoiceItem(
        id: e.id,
        companyId: e.companyId,
        name: safe(e.name),
        description: safe(e.description),
        hsnCode: safe(e.hsnCode),
        quantity: e.quantity,
        unit: safe(e.unit),
        rate: e.rate,
        amount: e.computedAmount,
        createdAt: e.createdAt,
        createdBy: e.createdBy,
        updatedAt: DateTime.now(),
        updatedBy: e.updatedBy,
      ))
          .toList(),
      taxDetails: TaxDetails(taxableValue: (summary.subtotal + summary.freight + summary.insurance), igstRate: isLUT.value ? 0 : taxRate.value, igstAmount: summary.taxAmt, reverseCharge: isReverseCharge.value),
      totals: Totals(subTotal: summary.subtotal, freight: summary.freight, insurance: summary.insurance, tax: summary.taxAmt, grandTotal: summary.grandTotalForeign, grandTotalInr: grandTotalINR),
      paymentDetails: PaymentDetails(
          paymentMode: selectedPaymentMode.value, // ✅ Non-nullable guarantee
          paymentReference: safe(paymentRefCtrl.text),
          beneficiaryName: safe(beneficiaryNameCtrl.text),
          bankName: safe(bankNameCtrl.text),
          bankAddress: safe(bankAddressCtrl.text),
          accountNumber: safe(accNoCtrl.text),
          ifsc: safe(ifscCtrl.text),
          swiftCode: safe(swiftCtrl.text),
          deliveryTerms: safe(deliveryTermsCtrl.text)
      ),
      declaration: safe(declarationCtrl.text), notes: safe(notesCtrl.text), authorizedSignatory: safe(signatoryCtrl.text), createdAt: DateTime.now(), updatedAt: DateTime.now(),
      amountReceived: existingAmountReceived,
      amountOutstanding: summary.outstanding,
      baseAmountOutstanding: summary.baseAmountOutstanding,
      paymentStatus: summary.paymentStatus,
    );
  }

  // ✅ STRICT FIX: Validations pulled entirely out of transaction to stop retry loops
  // ✅ STRICT FIX: removeNulls() function was deleted to prevent breaking Firebases' Timestamp schema.
  Future<String> saveToFirestore(String status) async {
    // 1. Validation Gate
    if ((selectedCustomerId ?? '').trim().isEmpty) throw Exception("Validation failed: You must select a customer before saving.");
    if (items.value.isEmpty || items.value.where((e) => safe(e.name).isNotEmpty).isEmpty) throw Exception("Validation failed: At least one item is required.");

    for (var i = 0; i < items.value.length; i++) {
      final item = items.value[i];
      if (safe(item.name).isEmpty) throw Exception("Validation failed: Item ${i+1} is missing a name.");
      if (item.quantity <= 0) throw Exception("Validation failed: Item ${i+1} quantity must be greater than 0.");
      if (item.rate <= 0) throw Exception("Validation failed: Item ${i+1} rate must be greater than 0.");
    }

    if (summaryState.value.grandTotalForeign <= 0) throw Exception("Validation failed: Grand Total must be greater than 0.");
    final er = double.tryParse(safe(exchangeRateCtrl.text)) ?? 0.0;
    if (er <= 0) throw Exception("Validation failed: Exchange Rate must be greater than 0.");
    if (safe(selectedPaymentMode.value).isEmpty) throw Exception("Validation failed: Payment Mode is required.");

    isSaving.value = true;
    try {
      final db = FirebaseFirestore.instance;
      final collectionRef = db.collection('companies').doc(companyId).collection('export_invoices');

      DocumentReference docRef = (invoiceId != null && invoiceId!.isNotEmpty) ? collectionRef.doc(invoiceId) : collectionRef.doc();
      final outRef = db.collection('companies').doc(companyId).collection('outstanding').doc(docRef.id);

      int maxRetries = 3;
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          await db.runTransaction((tx) async {
            final docSnap = await tx.get(docRef);
            final outSnap = await tx.get(outRef);

            bool isNewDoc = !docSnap.exists;
            final dataMap = docSnap.data() as Map<String, dynamic>?;

            if (!isNewDoc && dataMap != null) {
              final existingCustomerId = dataMap['customerId'];
              if (existingCustomerId != null && existingCustomerId != selectedCustomerId) {
                throw Exception("Audit Lock: Customer cannot be modified after initial document creation.");
              }
              final docVersion = dataMap['version'] ?? 0;
              if (docVersion != currentVersion) {
                throw Exception("Conflict: Document was modified in another tab or device. Please refresh.");
              }
            }

            String finalInvoiceNo = safe(invoiceNoCtrl.text).replaceAll(' (Preview)', '');
            if (isNewDoc && finalInvoiceNo.isEmpty) {
              finalInvoiceNo = generateDraftInvoiceNumber();
            }

            bool needsNewNumber = (isNewDoc || finalInvoiceNo.startsWith('DRAFT')) && status == 'Submitted';

            if (needsNewNumber) {
              finalInvoiceNo = await generateInvoiceNumber(tx);
              invoiceNoCtrl.text = finalInvoiceNo;
            }

            // Build model. The nested array FieldValue issue is now fixed inside the Model
            final model = buildModel(status, finalInvoiceNo);
            final data = Map<String, dynamic>.from(model.toMap());

            data['id'] = docRef.id;
            data['lastEditedBy'] = userUid;

            // ✅ FIX: FieldValue is perfectly safe at the ROOT of the document
            data['lastEditedAt'] = FieldValue.serverTimestamp();
            data['version'] = isNewDoc ? 1 : currentVersion + 1;
            data['isDeleted'] = false;

            final totalsMap = Map<String, dynamic>.from(data['totals'] ?? {});
            totalsMap['roundOff'] = summaryState.value.roundOff;
            totalsMap['grandTotal'] = summaryState.value.grandTotalForeign;
            data['totals'] = totalsMap;

            if (isNewDoc) {
              data['createdAt'] = FieldValue.serverTimestamp(); // Root level, Safe
            } else {
              data.remove('createdAt');
              data.remove('createdBy');
            }

            bool isDraft = status == 'Draft';
            bool isCancel = status == 'Cancelled';

            Map<String, dynamic> outData = {
              'invoiceId': docRef.id,
              'invoiceNumber': model.invoiceNumber,
              'invoiceDate': Timestamp.fromDate(model.invoiceDate),
              'invoiceType': 'EXPORT',
              'customerId': model.customerId,
              'customerName': model.buyer.name,
              'totalAmount': model.totals.grandTotal,
              'outstandingAmount': isCancel ? 0.0 : model.amountOutstanding,
              'baseTotalAmount': model.baseAmount,
              'baseOutstandingAmount': isCancel ? 0.0 : model.baseAmountOutstanding,
              'currency': model.currency,
              'exchangeRate': model.exchangeRate,
              'status': isCancel ? 'CANCELLED' : (isDraft ? 'DRAFT' : model.paymentStatus),
              'isFinalized': (!isDraft && !isCancel),
              'dueDate': Timestamp.fromDate(model.dueDate),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            if (!outSnap.exists) {
              outData['createdAt'] = FieldValue.serverTimestamp();
              outData['createdBy'] = userUid;
            }

            // ✅ FIX: Directly set the safe data payload. No recursive corruptions.
            tx.set(docRef, data, SetOptions(merge: true));

            final logRef = db.collection('companies').doc(companyId).collection('invoice_activity_logs').doc();
            tx.set(logRef, {
              'invoiceId': docRef.id,
              'action': isNewDoc ? 'CREATED' : 'UPDATED',
              'status': status,
              'timestamp': FieldValue.serverTimestamp(),
              'uid': userUid,
            });

            tx.set(outRef, outData, SetOptions(merge: true));
          });

          currentVersion++;
          return docRef.id;
        } catch (e) {
          // 🚨 CRITICAL ARCHITECTURE FIX: Never swallow Firebase Exceptions!
          if (e is FirebaseException ||
              e.toString().contains("Audit Lock") ||
              e.toString().contains("Conflict") ||
              e.toString().contains("Validation failed")) {
            rethrow; // Break out of retry loop instantly
          }
          if (attempt == maxRetries - 1) rethrow;
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
      throw Exception("Transaction failed after multiple network retries.");
    } catch (e) {
      rethrow; // Bubble exactly to UI
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> cancelInvoice() async {
    bool? conf = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
            title: const Text('Cancel Invoice?'),
            content: const Text('This action is permanent. The outstanding balance will be zeroed and the document locked.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go Back')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white))),
            ]
        )
    );
    if (conf != true || invoiceId == null) return;

    isSaving.value = true;
    try {
      int maxRetries = 3;
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          final db = FirebaseFirestore.instance;
          final batch = db.batch();

          final invRef = db.collection('companies').doc(companyId).collection('export_invoices').doc(invoiceId);
          final outRef = db.collection('companies').doc(companyId).collection('outstanding').doc(invoiceId);
          final logRef = db.collection('companies').doc(companyId).collection('invoice_activity_logs').doc();

          batch.update(invRef, {
            'status': 'Cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
            'lastEditedBy': userUid,
            'lastEditedAt': FieldValue.serverTimestamp(),
            'version': currentVersion + 1,
          });

          batch.set(outRef, {
            'status': 'CANCELLED',
            'outstandingAmount': 0.0,
            'baseOutstandingAmount': 0.0,
            'isFinalized': false,
            'updatedAt': FieldValue.serverTimestamp()
          }, SetOptions(merge: true));

          batch.set(logRef, {
            'invoiceId': invoiceId,
            'action': 'CANCELLED',
            'status': 'Cancelled',
            'timestamp': FieldValue.serverTimestamp(),
            'uid': userUid,
          });

          await batch.commit();
          currentVersion++;

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice Cancelled Successfully.'), backgroundColor: Colors.red));
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
          break;
        } catch (e) {
          if (attempt == maxRetries - 1) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cancelling invoice: ${e.toString()}'), backgroundColor: Colors.red));
            }
            break;
          }
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    } finally {
      isSaving.value = false;
    }
  }
}

// ============================================================================
// 3. REUSABLE WIDGETS
// ============================================================================

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 14),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    prefixIcon: Icon(icon, size: 20, color: primaryColor.withValues(alpha: 0.7)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
  );
}

class _CustomField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final bool required;
  final TextInputType keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final String? Function(String?)? validator;

  const _CustomField({
    required this.label,
    this.controller,
    this.icon,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        readOnly: readOnly,
        validator: validator ?? (required ? (val) => val == null || val.trim().isEmpty ? 'Required' : null : null),
        style: TextStyle(fontSize: 14, color: readOnly ? Colors.grey.shade700 : Colors.black87),
        decoration: _inputDecoration(label, icon ?? Icons.edit_note).copyWith(
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  const _SectionCard({required this.title, required this.icon, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Icon(icon, color: primaryColor, size: 22), const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor))),
                if (action != null) action!,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor)));
}
