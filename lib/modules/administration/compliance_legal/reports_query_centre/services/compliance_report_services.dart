import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/compliance_models.dart';

class ComplianceKpis {
  const ComplianceKpis({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.critical,
    required this.notices,
    required this.openQueries,
    required this.resolvedQueries,
    required this.todayDue,
    required this.lateFilings,
    required this.penalties,
    required this.reports,
  });
  final int total,
      completed,
      pending,
      overdue,
      critical,
      notices,
      openQueries,
      resolvedQueries,
      todayDue,
      lateFilings,
      reports;
  final double penalties;
  factory ComplianceKpis.fromRecords(
    List<ComplianceRecord> records, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    bool same(DateTime? d) =>
        d != null &&
        d.year == today.year &&
        d.month == today.month &&
        d.day == today.day;
    final compliance = records
        .where((r) => r.type == ComplianceRecordType.compliance)
        .toList();
    return ComplianceKpis(
      total: compliance.length,
      completed: compliance.where((r) => r.isCompleted).length,
      pending: compliance.where((r) => !r.isCompleted && !r.isOverdue).length,
      overdue: compliance.where((r) => r.isOverdue).length,
      critical: records.where((r) => r.isCritical).length,
      notices: records
          .where((r) => r.type == ComplianceRecordType.notice && !r.isCompleted)
          .length,
      openQueries: records
          .where((r) => r.type == ComplianceRecordType.query && !r.isCompleted)
          .length,
      resolvedQueries: records
          .where((r) => r.type == ComplianceRecordType.query && r.isCompleted)
          .length,
      todayDue: records.where((r) => same(r.dueDate)).length,
      lateFilings: compliance.where((r) => r.isOverdue).length,
      penalties: records.fold(0, (v, r) => v + r.penalty),
      reports: records
          .where((r) => r.type == ComplianceRecordType.report)
          .length,
    );
  }
}

class ReportDefinition {
  const ReportDefinition(
    this.id,
    this.name, {
    this.category = '',
    this.status = '',
    this.period = '',
  });
  final String id, name, category, status, period;
}

const complianceReportDefinitions = <ReportDefinition>[
  ReportDefinition('summary', 'Compliance Summary Report'),
  ReportDefinition('pending', 'Pending Compliance Report', status: 'Pending'),
  ReportDefinition(
    'completed',
    'Completed Compliance Report',
    status: 'Completed',
  ),
  ReportDefinition('overdue', 'Overdue Compliance Report', status: 'Overdue'),
  ReportDefinition('department', 'Department-wise Report'),
  ReportDefinition('employee', 'Employee-wise Report'),
  ReportDefinition('branch', 'Branch-wise Report'),
  ReportDefinition('company', 'Company-wise Report'),
  ReportDefinition('gst', 'GST Compliance Report', category: 'GST'),
  ReportDefinition(
    'income_tax',
    'Income Tax Compliance Report',
    category: 'Income Tax',
  ),
  ReportDefinition('tds_tcs', 'TDS/TCS Compliance Report', category: 'TDS/TCS'),
  ReportDefinition('roc', 'ROC Compliance Report', category: 'ROC'),
  ReportDefinition('pf', 'PF Compliance Report', category: 'PF'),
  ReportDefinition('esic', 'ESIC Compliance Report', category: 'ESIC'),
  ReportDefinition(
    'professional_tax',
    'Professional Tax Report',
    category: 'Professional Tax',
  ),
  ReportDefinition('labour', 'Labour Law Report', category: 'Labour Law'),
  ReportDefinition('audit', 'Audit Report'),
  ReportDefinition('penalty', 'Penalty Report'),
  ReportDefinition('interest', 'Interest Report'),
  ReportDefinition('late', 'Late Filing Report'),
  ReportDefinition('notice', 'Legal Notice Report'),
  ReportDefinition('monthly', 'Monthly Report', period: 'Monthly'),
  ReportDefinition('quarterly', 'Quarterly Report', period: 'Quarterly'),
  ReportDefinition('half_yearly', 'Half-Yearly Report', period: 'Half-Yearly'),
  ReportDefinition('annual', 'Annual Report', period: 'Annual'),
  ReportDefinition('custom', 'Custom Report Builder'),
];

class ComplianceReportEngine {
  List<ComplianceRecord> generate(
    List<ComplianceRecord> source,
    ReportDefinition definition,
    ReportFilters filters,
  ) => source
      .where((r) => filters.matches(r))
      .where(
        (r) =>
            definition.category.isEmpty ||
            r.category.toLowerCase() == definition.category.toLowerCase(),
      )
      .where((r) {
        if (definition.status == 'Overdue') {
          return r.isOverdue;
        }
        return definition.status.isEmpty ||
            r.status.toLowerCase() == definition.status.toLowerCase();
      })
      .toList();
}

abstract class ComplianceExportService {
  Set<String> get supportedFormats;
  Future<Uint8List> export(
    String format,
    String title,
    List<ComplianceRecord> rows, {
    required String companyName,
    required String generatedBy,
    required ReportFilters filters,
  });
  String filename(String title, String format, DateTime at);
}

class DefaultComplianceExportService implements ComplianceExportService {
  @override
  Set<String> get supportedFormats => {'csv', 'pdf'};
  @override
  String filename(String title, String format, DateTime at) =>
      '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '')}_${at.toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.$format';
  @override
  Future<Uint8List> export(
    String format,
    String title,
    List<ComplianceRecord> rows, {
    required String companyName,
    required String generatedBy,
    required ReportFilters filters,
  }) async {
    if (format == 'csv') {
      String cell(String v) => '"${v.replaceAll('"', '""')}"';
      final data = <List<String>>[
        [
          'Reference No.',
          'Title',
          'Department',
          'Authority',
          'Category',
          'Assigned To',
          'Due Date',
          'Status',
          'Priority',
        ],
        ...rows.map(
          (r) => [
            r.referenceNumber,
            r.title,
            r.department,
            r.authority,
            r.category,
            r.assignedTo,
            r.dueDate?.toIso8601String() ?? '',
            r.status,
            r.priority,
          ],
        ),
      ];
      return Uint8List.fromList(
        utf8.encode(data.map((row) => row.map(cell).join(',')).join('\r\n')),
      );
    }
    if (format == 'pdf') {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(title),
              pw.Text('Generated by $generatedBy • ${DateTime.now()}'),
            ],
          ),
          footer: (c) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${c.pageNumber} of ${c.pagesCount}'),
          ),
          build: (_) => [
            pw.TableHelper.fromTextArray(
              headers: ['Reference', 'Title', 'Due', 'Status', 'Priority'],
              data: rows
                  .map(
                    (r) => [
                      r.referenceNumber,
                      r.title,
                      r.dueDate?.toString().split(' ').first ?? '',
                      r.status,
                      r.priority,
                    ],
                  )
                  .toList(),
            ),
          ],
        ),
      );
      return doc.save();
    }
    throw UnsupportedError('$format export is not configured');
  }
}

abstract class ComplianceCommunicationService {
  bool get emailAvailable;
  bool get whatsAppAvailable;
  Future<void> sendEmail(
    Uint8List attachment,
    String filename,
    List<String> recipients,
  );
}

class DisabledComplianceCommunicationService
    implements ComplianceCommunicationService {
  @override
  bool get emailAvailable => false;
  @override
  bool get whatsAppAvailable => false;
  @override
  Future<void> sendEmail(
    Uint8List attachment,
    String filename,
    List<String> recipients,
  ) => throw UnsupportedError('Email provider configuration required');
}
