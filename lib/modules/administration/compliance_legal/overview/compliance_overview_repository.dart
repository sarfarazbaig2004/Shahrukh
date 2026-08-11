import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../compliance_calendar/models/compliance_calendar_model.dart';

class ComplianceOverviewSnapshot {
  const ComplianceOverviewSnapshot({
    required this.calendarRecords,
    required this.riskCounts,
    required this.noticeCount,
    required this.openLegalCases,
    required this.openAuditFindings,
    required this.recentActivity,
  });

  final List<ComplianceCalendarModel> calendarRecords;
  final Map<String, int> riskCounts;
  final int noticeCount;
  final int openLegalCases;
  final int openAuditFindings;
  final List<ComplianceOverviewActivity> recentActivity;

  int get total => calendarRecords.length;

  int get completed => calendarRecords
      .where((record) => record.status.toLowerCase() == 'completed')
      .length;

  int get pending => calendarRecords
      .where((record) => record.status.toLowerCase() == 'pending')
      .length;

  int get overdue {
    final now = DateTime.now();
    return calendarRecords.where((record) {
      return record.status.toLowerCase() != 'completed' &&
          record.dueDate.isBefore(now);
    }).length;
  }

  int get dueSoon {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 30));
    return calendarRecords.where((record) {
      return record.status.toLowerCase() != 'completed' &&
          !record.dueDate.isBefore(now) &&
          record.dueDate.isBefore(limit);
    }).length;
  }

  int get criticalRisks => riskCounts['critical'] ?? 0;
  int get highRisks => riskCounts['high'] ?? 0;
  int get mediumRisks => riskCounts['medium'] ?? 0;
  int get lowRisks => riskCounts['low'] ?? 0;

  double get complianceHealth {
    if (total == 0) {
      return 0;
    }
    final base = completed * 100 / total;
    final penalty = overdue * 2.5 + criticalRisks * 4;
    return (base - penalty).clamp(0, 100).toDouble();
  }

  List<ComplianceCalendarModel> get nextDue {
    final records =
        calendarRecords
            .where((record) => record.status.toLowerCase() != 'completed')
            .toList()
          ..sort((first, second) => first.dueDate.compareTo(second.dueDate));
    return records.take(8).toList();
  }

  static const ComplianceOverviewSnapshot empty = ComplianceOverviewSnapshot(
    calendarRecords: <ComplianceCalendarModel>[],
    riskCounts: <String, int>{},
    noticeCount: 0,
    openLegalCases: 0,
    openAuditFindings: 0,
    recentActivity: <ComplianceOverviewActivity>[],
  );
}

class ComplianceOverviewActivity {
  const ComplianceOverviewActivity({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.timestamp,
    required this.entityType,
  });

  final String title;
  final String subtitle;
  final String action;
  final DateTime timestamp;
  final String entityType;

  factory ComplianceOverviewActivity.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['timestamp'];
    final date = timestamp is Timestamp
        ? timestamp.toDate()
        : data['updatedAt'] is Timestamp
        ? (data['updatedAt'] as Timestamp).toDate()
        : DateTime.now();

    final user = data['userName']?.toString().trim();
    final action = data['action']?.toString().trim();
    final entityType = data['entityType']?.toString().trim();
    final entityId = data['entityId']?.toString().trim();

    return ComplianceOverviewActivity(
      title: <String>[
        if (user != null && user.isNotEmpty) user,
        if (action != null && action.isNotEmpty) action,
        if (entityType != null && entityType.isNotEmpty) entityType,
      ].join(' '),
      subtitle: entityId == null || entityId.isEmpty
          ? 'Compliance activity'
          : 'Reference: $entityId',
      action: action == null || action.isEmpty ? 'updated' : action,
      timestamp: date,
      entityType: entityType == null || entityType.isEmpty
          ? 'compliance'
          : entityType,
    );
  }
}

class ComplianceOverviewRepository {
  ComplianceOverviewRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _company =>
      _firestore.collection('companies').doc(companyId);

  Stream<ComplianceOverviewSnapshot> watchOverview() {
    late StreamController<ComplianceOverviewSnapshot> controller;
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    var calendar = <ComplianceCalendarModel>[];
    var riskCounts = <String, int>{};
    var noticeCount = 0;
    var openLegalCases = 0;
    var openAuditFindings = 0;
    var activity = <ComplianceOverviewActivity>[];

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          ComplianceOverviewSnapshot(
            calendarRecords: calendar,
            riskCounts: riskCounts,
            noticeCount: noticeCount,
            openLegalCases: openLegalCases,
            openAuditFindings: openAuditFindings,
            recentActivity: activity,
          ),
        );
      }
    }

    controller = StreamController<ComplianceOverviewSnapshot>(
      onListen: () {
        subscriptions.add(
          _company.collection('complianceCalendar').snapshots().listen((
            snapshot,
          ) {
            calendar = snapshot.docs
                .map(ComplianceCalendarModel.fromFirestore)
                .where((record) => !record.isDeleted)
                .toList();
            emit();
          }, onError: controller.addError),
        );

        subscriptions.add(
          _company.collection('risk_register').snapshots().listen((snapshot) {
            final counts = <String, int>{
              'critical': 0,
              'high': 0,
              'medium': 0,
              'low': 0,
            };
            for (final document in snapshot.docs) {
              final data = document.data();
              if (data['isDeleted'] == true) {
                continue;
              }
              final level = (data['residualLevel'] ?? data['riskLevel'])
                  ?.toString()
                  .toLowerCase();
              if (level != null && counts.containsKey(level)) {
                counts[level] = counts[level]! + 1;
              }
            }
            riskCounts = counts;
            emit();
          }, onError: controller.addError),
        );

        subscriptions.add(
          _company.collection('government_notices').snapshots().listen((
            snapshot,
          ) {
            noticeCount = snapshot.docs.where((document) {
              return document.data()['isDeleted'] != true;
            }).length;
            emit();
          }, onError: controller.addError),
        );

        subscriptions.add(
          _company.collection('legal_cases').snapshots().listen((snapshot) {
            openLegalCases = snapshot.docs.where((document) {
              final data = document.data();
              final status = data['status']?.toString().toLowerCase() ?? '';
              return data['isDeleted'] != true &&
                  status != 'closed' &&
                  status != 'decided';
            }).length;
            emit();
          }, onError: controller.addError),
        );

        subscriptions.add(
          _company.collection('audit_findings').snapshots().listen((snapshot) {
            openAuditFindings = snapshot.docs.where((document) {
              final data = document.data();
              final status = data['status']?.toString().toLowerCase() ?? '';
              return data['isDeleted'] != true && status != 'closed';
            }).length;
            emit();
          }, onError: controller.addError),
        );

        subscriptions.add(
          _company
              .collection('audit_trail')
              .orderBy('timestamp', descending: true)
              .limit(12)
              .snapshots()
              .listen(
                (snapshot) {
                  activity = snapshot.docs
                      .map(ComplianceOverviewActivity.fromDocument)
                      .toList();
                  emit();
                },
                onError: (_) {
                  // Audit data is optional on older tenants; the rest of the
                  // dashboard should remain available.
                  activity = <ComplianceOverviewActivity>[];
                  emit();
                },
              ),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await controller.close();
      },
    );

    return controller.stream;
  }
}
