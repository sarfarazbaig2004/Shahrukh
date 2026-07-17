// FILE: lib/modules/dashboard/dashboard_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardKpiData {
  final double totalRevenue;
  final double totalOutstanding;
  final int activeQuotes;
  final double conversionRate;

  DashboardKpiData({
    required this.totalRevenue,
    required this.totalOutstanding,
    required this.activeQuotes,
    required this.conversionRate,
  });
}

class DashboardChartData {
  final Map<int, double> monthlySales;
  final double paidAmount;
  final double pendingAmount;

  DashboardChartData({
    required this.monthlySales,
    required this.paidAmount,
    required this.pendingAmount,
  });
}

class DashboardCrmData {
  final int openDeals;
  final int newInquiries;

  DashboardCrmData({required this.openDeals, required this.newInquiries});
}

class DashboardProductivityData {
  final int openTasks;
  final int criticalTasks;

  DashboardProductivityData({
    required this.openTasks,
    required this.criticalTasks,
  });
}

class DashboardTransaction {
  final String title;
  final String subtitle;
  final double amount;
  final bool isPositive;
  final String status;

  DashboardTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.status,
  });
}

class DashboardService {
  final String companyId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DashboardService({required this.companyId});

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value
          .replaceAll(',', '')
          .replaceAll('₹', '')
          .replaceAll(RegExp(r'[^0-9.\-]'), '')
          .trim();
      if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return 0.0;
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  double _firstAmount(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final amount = _parseDouble(data[key]);
      if (amount != 0) return amount;
    }
    return 0.0;
  }

  bool _isDeleted(Map<String, dynamic> data) {
    return data['isDeleted'] == true || data['isActive'] == false;
  }

  bool _isOldRevision(Map<String, dynamic> data) {
    return data['isLatest'] == false;
  }

  bool _isCancelledOrRejected(String status) {
    final s = status.toLowerCase().trim();
    return s == 'cancelled' || s == 'canceled' || s == 'rejected';
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  Stream<DashboardKpiData> streamKpiData() {
    return _db.collection('companies').doc(companyId).snapshots().asyncMap((
      _,
    ) async {
      try {
        final invoicesSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('tax_invoices')
            .get();

        final salesOrdersSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('sales_orders')
            .get();

        final quotesSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('quotations')
            .get();

        double invoiceRevenue = 0;
        double outstanding = 0;

        for (final doc in invoicesSnap.docs) {
          final data = doc.data();
          if (_isDeleted(data)) continue;

          final total = _firstAmount(data, [
            'totalAmount',
            'finalTotal',
            'grandTotal',
            'invoiceTotal',
            'netAmount',
            'amount',
          ]);

          invoiceRevenue += total;

          final explicitOutstanding = _firstAmount(data, [
            'outstandingAmount',
            'balanceAmount',
            'dueAmount',
            'pendingAmount',
            'amountDue',
          ]);

          final paymentStatus = (data['paymentStatus'] ?? data['status'] ?? '')
              .toString()
              .toLowerCase();

          if (explicitOutstanding != 0) {
            outstanding += explicitOutstanding;
          } else if (paymentStatus.contains('unpaid') ||
              paymentStatus.contains('pending') ||
              paymentStatus.contains('partial')) {
            outstanding += total;
          }
        }

        // Fallback for companies where tax invoice module is not yet used.
        // Do not double count: use Sales Orders only when invoice revenue is zero.
        double salesOrderRevenue = 0;
        if (invoiceRevenue == 0) {
          for (final doc in salesOrdersSnap.docs) {
            final data = doc.data();
            if (_isDeleted(data)) continue;

            final status = (data['status'] ?? '').toString().toLowerCase();
            if (_isCancelledOrRejected(status)) continue;

            salesOrderRevenue += _firstAmount(data, [
              'finalTotal',
              'grandTotal',
              'totalAmount',
              'orderTotal',
              'netAmount',
              'amount',
            ]);
          }
        }

        int latestQuoteCount = 0;
        int activeQuotes = 0;
        int convertedQuotes = 0;

        for (final doc in quotesSnap.docs) {
          final data = doc.data();
          if (_isDeleted(data) || _isOldRevision(data)) continue;

          latestQuoteCount++;

          final status = (data['status'] ?? '').toString().toLowerCase();
          final convertedFlag =
              data['convertedToSalesOrder'] == true ||
              data['convertedToSalesOrderId'] != null;

          if (status == 'converted' || convertedFlag) {
            convertedQuotes++;
            continue;
          }

          if (!_isCancelledOrRejected(status)) {
            activeQuotes++;
          }
        }

        final revenue = invoiceRevenue != 0
            ? invoiceRevenue
            : salesOrderRevenue;

        final conversionRate = latestQuoteCount > 0
            ? ((convertedQuotes / latestQuoteCount) * 100).clamp(0, 100)
            : 0.0;

        return DashboardKpiData(
          totalRevenue: revenue,
          totalOutstanding: outstanding,
          activeQuotes: activeQuotes,
          conversionRate: conversionRate.toDouble(),
        );
      } catch (e) {
        return DashboardKpiData(
          totalRevenue: 0,
          totalOutstanding: 0,
          activeQuotes: 0,
          conversionRate: 0,
        );
      }
    });
  }

  Stream<DashboardChartData> streamChartData() {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('tax_invoices')
        .snapshots()
        .map((snap) {
          Map<int, double> monthlySales = {
            for (int i = 1; i <= 12; i++) i: 0.0,
          };
          double paidAmount = 0;
          double pendingAmount = 0;

          final currentYear = DateTime.now().year;

          for (var doc in snap.docs) {
            final data = doc.data();
            if (data['isDeleted'] == true) continue;

            double total = _parseDouble(data['totalAmount']);
            double outstanding = _parseDouble(data['outstandingAmount']);
            double paid = total - outstanding;

            paidAmount += paid;
            pendingAmount += outstanding;

            DateTime date = _parseDate(data['invoiceDate']);
            if (date.year == currentYear) {
              monthlySales[date.month] =
                  (monthlySales[date.month] ?? 0) + total;
            }
          }

          return DashboardChartData(
            monthlySales: monthlySales,
            paidAmount: paidAmount,
            pendingAmount: pendingAmount,
          );
        });
  }

  Stream<DashboardCrmData> streamCrmData() {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('inquiries')
        .snapshots()
        .map((snap) {
          int openDeals = 0;
          int newInquiries = 0;

          for (var doc in snap.docs) {
            final data = doc.data();
            if (data['isDeleted'] == true) continue;

            final status = (data['status'] ?? '').toString().toLowerCase();
            if (status == 'open' || status == 'pending') openDeals++;
            if (status == 'new') newInquiries++;
          }

          return DashboardCrmData(
            openDeals: openDeals,
            newInquiries: newInquiries,
          );
        });
  }

  Stream<DashboardProductivityData> streamProductivityData() {
    return _db.collection('companies').doc(companyId).snapshots().asyncMap((
      _,
    ) async {
      try {
        final tasksSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('tasks')
            .get();

        int openTasks = 0;
        int criticalTasks = 0;

        for (final doc in tasksSnap.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;

          final status = (data['status'] ?? '').toString().toLowerCase();
          final priority = (data['priority'] ?? '').toString().toLowerCase();

          if (status != 'completed') openTasks++;
          if (priority == 'critical' && status != 'completed') criticalTasks++;
        }

        return DashboardProductivityData(
          openTasks: openTasks,
          criticalTasks: criticalTasks,
        );
      } catch (e) {
        return DashboardProductivityData(
          openTasks: 0,
          criticalTasks: 0,
        );
      }
    });
  }

  Stream<List<DashboardTransaction>> streamRecentTransactions() {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('payments_received')
        .orderBy('paymentDate', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = doc.data();
            return DashboardTransaction(
              title: 'Payment Received',
              subtitle:
                  'Ref: ${data['paymentNumber'] ?? data['invoiceNumber'] ?? 'N/A'}',
              amount: _parseDouble(data['amount']),
              isPositive: true,
              status: 'Paid',
            );
          }).toList();
        });
  }
}
