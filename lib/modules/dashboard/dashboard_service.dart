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
  final int upcomingMeetings;
  final int todayMeetings;

  DashboardProductivityData({
    required this.openTasks,
    required this.criticalTasks,
    required this.upcomingMeetings,
    required this.todayMeetings,
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
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
        final quotesSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('quotations')
            .get();
        final inquiriesSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('inquiries')
            .get();

        double revenue = 0;
        double outstanding = 0;

        for (var doc in invoicesSnap.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;
          revenue += _parseDouble(data['totalAmount']);
          outstanding += _parseDouble(data['outstandingAmount']);
        }

        int activeQuotes = 0;
        for (var doc in quotesSnap.docs) {
          final status = (doc.data()['status'] ?? '').toString().toLowerCase();
          if (status != 'converted' &&
              status != 'rejected' &&
              doc.data()['isDeleted'] != true) {
            activeQuotes++;
          }
        }

        int totalInquiries = inquiriesSnap.docs
            .where((d) => d.data()['isDeleted'] != true)
            .length;
        double conversionRate = totalInquiries > 0
            ? (activeQuotes / totalInquiries) * 100
            : 0.0;

        return DashboardKpiData(
          totalRevenue: revenue,
          totalOutstanding: outstanding,
          activeQuotes: activeQuotes,
          conversionRate: conversionRate,
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

        final meetingsSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('meetings')
            .get();

        int openTasks = 0;
        int criticalTasks = 0;
        int upcomingMeetings = 0;
        int todayMeetings = 0;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (final doc in tasksSnap.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;

          final status = (data['status'] ?? '').toString().toLowerCase();
          final priority = (data['priority'] ?? '').toString().toLowerCase();

          if (status != 'completed') openTasks++;
          if (priority == 'critical' && status != 'completed') criticalTasks++;
        }

        for (final doc in meetingsSnap.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;

          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status == 'cancelled') continue;

          final startAt = _parseDate(data['startAt']);
          final meetingDay = DateTime(startAt.year, startAt.month, startAt.day);

          if (startAt.isAfter(now)) upcomingMeetings++;
          if (meetingDay.isAtSameMomentAs(today)) todayMeetings++;
        }

        return DashboardProductivityData(
          openTasks: openTasks,
          criticalTasks: criticalTasks,
          upcomingMeetings: upcomingMeetings,
          todayMeetings: todayMeetings,
        );
      } catch (e) {
        return DashboardProductivityData(
          openTasks: 0,
          criticalTasks: 0,
          upcomingMeetings: 0,
          todayMeetings: 0,
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
