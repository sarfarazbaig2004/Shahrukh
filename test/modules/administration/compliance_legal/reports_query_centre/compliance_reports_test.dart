import 'package:QUIK/modules/administration/compliance_legal/reports_query_centre/models/compliance_models.dart';
import 'package:QUIK/modules/administration/compliance_legal/reports_query_centre/permissions/compliance_permissions.dart';
import 'package:QUIK/modules/administration/compliance_legal/reports_query_centre/services/compliance_report_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ComplianceRecord record({
    String status = 'Pending',
    String priority = 'Medium',
    DateTime? due,
    String category = 'GST',
    bool deleted = false,
  }) => ComplianceRecord.fromMap('1', {
    'title': 'GST return',
    'companyId': 'c1',
    'status': status,
    'priority': priority,
    'dueDate': due,
    'category': category,
    'isDeleted': deleted,
  }, ComplianceRecordType.compliance);
  test('legacy records without isDeleted remain active', () {
    expect(record().isDeleted, isFalse);
  });
  test('overdue calculation excludes completed records', () {
    final past = DateTime.now().subtract(const Duration(days: 2));
    expect(record(due: past).isOverdue, isTrue);
    expect(record(status: 'Completed', due: past).isOverdue, isFalse);
  });
  test('KPI aggregation uses source records', () {
    final rows = [
      record(status: 'Completed'),
      record(due: DateTime.now().subtract(const Duration(days: 1))),
      record(priority: 'Critical'),
    ];
    final k = ComplianceKpis.fromRecords(rows);
    expect(k.total, 3);
    expect(k.completed, 1);
    expect(k.overdue, 1);
    expect(k.critical, 1);
  });
  test('priority and report filters match records', () {
    final critical = record(priority: 'Critical');
    expect(const ReportFilters(priority: 'Critical').matches(critical), isTrue);
    expect(const ReportFilters(priority: 'Low').matches(critical), isFalse);
    expect(
      ComplianceReportEngine().generate(
        [critical],
        const ReportDefinition('gst', 'GST', category: 'GST'),
        const ReportFilters(),
      ),
      hasLength(1),
    );
  });
  test('query status transitions enforce workflow', () {
    final q = ComplianceQuery(
      id: '1',
      queryNumber: 'Q1',
      subject: 'S',
      description: 'D',
      companyId: 'c',
      createdByUserId: 'u',
      createdByName: 'U',
    );
    expect(q.canTransitionTo('Assigned'), isTrue);
    expect(q.canTransitionTo('Closed'), isFalse);
  });
  test('schedule recurrence calculates next run', () {
    final start = DateTime(2026, 7, 1);
    expect(
      ReportSchedule(
        id: '1',
        recurrence: 'weekly',
        nextRunAt: start,
      ).followingRun(),
      DateTime(2026, 7, 8),
    );
    expect(
      ReportSchedule(
        id: '1',
        recurrence: 'quarterly',
        nextRunAt: start,
      ).followingRun(),
      DateTime(2026, 10, 1),
    );
  });
  test('permission decisions use supplied capabilities', () {
    const p = CompliancePermissions(
      canView: true,
      canCreate: false,
      canEdit: false,
      canDelete: false,
      canExport: true,
      canUpload: false,
      canDownload: false,
      canApprove: false,
    );
    expect(p.allows('complianceReports.export'), isTrue);
    expect(p.allows('complianceQueries.create'), isFalse);
  });
  test('export filename is safe and has real extension', () {
    final name = DefaultComplianceExportService().filename(
      'Penalty Report',
      'pdf',
      DateTime(2026, 7, 22),
    );
    expect(name, startsWith('penalty_report_'));
    expect(name, endsWith('.pdf'));
  });
}
