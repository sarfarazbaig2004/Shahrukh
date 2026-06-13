import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExportTotalsCard extends StatelessWidget {
  final String currency;
  final bool isLut;
  final double exchangeRate;

  final double subtotal;
  final double freight;
  final double insurance;
  final double taxAmt;
  final double grandTotalForeign;

  final double amountReceived;
  final double advanceAmount;
  final double advancePercentage;
  final double amountOutstanding;
  final String paymentStatus;

  const ExportTotalsCard({
    super.key,
    required this.currency,
    required this.isLut,
    required this.exchangeRate,
    required this.subtotal,
    required this.freight,
    required this.insurance,
    required this.taxAmt,
    required this.grandTotalForeign,
    this.amountReceived = 0.0,
    this.advanceAmount = 0.0,
    this.advancePercentage = 0.0,
    this.amountOutstanding = 0.0,
    this.paymentStatus = 'UNPAID',
  });

  double _round(double val) => double.parse(val.toStringAsFixed(2));

  String _formatCurrency(double value) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${currency.toUpperCase()} ${formatter.format(value)}';
  }

  String _formatInr(double value) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '₹${formatter.format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final grandTotalInr = _round(grandTotalForeign * exchangeRate);

    final totalReceived = advanceAmount + amountReceived;

    final isOverpaid = amountOutstanding < -0.01;
    final displayOutstanding = isOverpaid ? 0.0 : amountOutstanding;

    final excess = isOverpaid ? (totalReceived - grandTotalForeign) : 0.0;

    double advancePctRatio = advancePercentage / 100.0;
    double receivedPctRatio = grandTotalForeign > 0 ? (amountReceived / grandTotalForeign) : 0.0;

    if (advancePctRatio > 1.0) advancePctRatio = 1.0;
    if ((advancePctRatio + receivedPctRatio) > 1.0) receivedPctRatio = 1.0 - advancePctRatio;
    final totalPct = ((advancePctRatio + receivedPctRatio) * 100).toStringAsFixed(1);

    int remainingFlex = ((1 - advancePctRatio - receivedPctRatio) * 1000).toInt();
    if (remainingFlex < 0) remainingFlex = 0;

    final isDraft = paymentStatus == 'DRAFT' || grandTotalForeign == 0;
    final isPartial = paymentStatus == 'PARTIALLY PAID';
    final isPaid = paymentStatus == 'PAID' || (amountOutstanding <= 0.01 && grandTotalForeign > 0);

    Color statusBgColor = isPaid ? Colors.green.shade50 : (isPartial ? Colors.orange.shade50 : (isDraft ? Colors.grey.shade100 : Colors.red.shade50));
    Color statusTextColor = isPaid ? Colors.green.shade700 : (isPartial ? Colors.orange.shade800 : (isDraft ? Colors.grey.shade600 : Colors.red.shade700));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _row('Subtotal', subtotal),
          const SizedBox(height: 10),

          _row('IGST', taxAmt, subtitle: isLut ? 'Zero Rated (LUT)' : null),
          const SizedBox(height: 10),

          if (freight > 0) _row('Freight', freight),
          if (insurance > 0) _row('Insurance', insurance),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.grey)),

          _row('Grand Total', grandTotalForeign, isBold: true, highlight: true),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Base Currency (INR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                const SizedBox(height: 6),
                Text('1 ${currency.toUpperCase()} = ${_formatInr(exchangeRate)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 8),
                Text(_formatInr(grandTotalInr), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blue)),
              ],
            ),
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.grey)),

          if (totalReceived > 0) ...[
            if (advanceAmount > 0)
              _row('Advance Applied', advanceAmount, subtitle: '${advancePercentage.toStringAsFixed(1)}% of Invoice', color: Colors.orange.shade700),

            if (amountReceived > 0)
              Padding(
                padding: EdgeInsets.only(top: advanceAmount > 0 ? 8.0 : 0),
                child: _row('Additional Payment', amountReceived, subtitle: '${(receivedPctRatio * 100).toStringAsFixed(1)}% of Invoice', color: Colors.green.shade600),
              ),

            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _row('Total Received', totalReceived, isBold: true, color: Colors.green.shade800),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Text('$totalPct% Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      color: Colors.grey.shade200,
                      child: Row(
                        children: [
                          if (advanceAmount > 0)
                            Flexible(flex: (advancePctRatio * 1000).toInt(), child: Container(color: Colors.orange.shade400)),
                          if (amountReceived > 0)
                            Flexible(flex: (receivedPctRatio * 1000).toInt(), child: Container(color: Colors.green.shade500)),
                          Flexible(flex: remainingFlex, child: Container(color: Colors.transparent)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.grey)),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6)),
                child: Text(paymentStatus, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: statusTextColor)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Balance Due', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(displayOutstanding),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: statusTextColor),
                  ),
                  if (isOverpaid)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('Excess Received: ${_formatCurrency(excess)}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool isBold = false, bool highlight = false, String? subtitle, Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: Colors.black87)),
              if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11, color: color ?? Colors.orange, fontWeight: FontWeight.w700)),
            ],
          ),
          Text(_formatCurrency(value), style: TextStyle(fontSize: isBold ? 20 : 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color ?? (highlight ? Colors.blue : Colors.black87))),
        ],
      ),
    );
  }
}