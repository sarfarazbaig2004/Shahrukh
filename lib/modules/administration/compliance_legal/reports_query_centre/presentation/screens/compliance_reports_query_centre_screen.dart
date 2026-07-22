import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_design_system.dart';

import '../../controllers/compliance_reports_controller.dart';
import '../../models/compliance_models.dart';
import '../../permissions/compliance_permissions.dart';
import '../../repositories/compliance_reports_repository.dart';
import '../../services/compliance_report_services.dart';

class ComplianceReportsQueryCentreScreen extends StatefulWidget {
  ComplianceReportsQueryCentreScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.permissions,
    this.companyName = 'MEMCO',
  });
  final String companyId, currentUserUid, currentUserName, companyName;
  final CompliancePermissions permissions;
  @override
  State<ComplianceReportsQueryCentreScreen> createState() =>
      _ComplianceReportsQueryCentreScreenState();
}

class _ComplianceReportsQueryCentreScreenState
    extends State<ComplianceReportsQueryCentreScreen> {
  late final ComplianceReportsController controller;
  final search = TextEditingController();
  int tab = 0;
  bool cards = false;
  bool sidebarCollapsed = false;
  String financialYear = 'FY 2026–27';
  @override
  void initState() {
    super.initState();
    controller = ComplianceReportsController(
      repository: ComplianceReportsRepository(companyId: widget.companyId),
    );
    controller.initialize();
  }

  @override
  void dispose() {
    search.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.permissions.canView) {
      return ComplianceThemeShell(
        child: Scaffold(
          body: ComplianceErrorState(
            message:
                'You do not have permission to view Compliance Reports & Query Centre.',
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ComplianceSubpageShell(
          title: 'Compliance Reports & Query Centre',
          subtitle:
              'Governed reporting, query management, notices, litigation and evidence',
          icon: Icons.analytics_outlined,
          breadcrumbs: const <String>[
            'Administration',
            'Compliance & Legal',
            'Reports & Query Centre',
          ],
          onBack: () => Navigator.maybePop(context),
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.loading ? null : controller.refresh,
              icon: Icon(Icons.refresh_rounded),
            ),
            OutlinedButton.icon(
              onPressed: widget.permissions.canExport
                  ? () => _message(
                      'Open a generated report to select CSV or PDF export.',
                    )
                  : null,
              icon: Icon(Icons.file_download_outlined, size: 18),
              label: Text('Export'),
            ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              final workspace = Column(
                children: <Widget>[
                  _header(),
                  SizedBox(height: ComplianceSpacing.md),
                  if (compact) ...<Widget>[
                    _mobileNavigation(),
                    SizedBox(height: ComplianceSpacing.md),
                  ],
                  Expanded(child: _content()),
                ],
              );

              if (compact) {
                return workspace;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AnimatedContainer(
                    duration: ComplianceMotion.normal,
                    curve: ComplianceMotion.standard,
                    width: sidebarCollapsed ? 76 : 238,
                    child: _navigation(),
                  ),
                  SizedBox(width: ComplianceSpacing.md),
                  Expanded(child: workspace),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _header() {
    return ComplianceCard(
      padding: const EdgeInsets.all(ComplianceSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final searchField = ComplianceSearchField(
            controller: search,
            hintText: 'Search reports, queries, notices and cases',
            onChanged: controller.search,
          );
          final yearSelector = ComplianceSelector<String>(
            label: 'Financial Year',
            valueLabel: financialYear,
            options: const <String>['FY 2026–27', 'FY 2025–26'],
            labelBuilder: (value) => value,
            onSelected: (value) => setState(() => financialYear = value),
            icon: Icons.calendar_month_outlined,
            width: compact ? double.infinity : 190,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                searchField,
                SizedBox(height: ComplianceSpacing.sm),
                yearSelector,
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(child: searchField),
              SizedBox(width: ComplianceSpacing.sm),
              yearSelector,
              SizedBox(width: ComplianceSpacing.sm),
              ComplianceStatusBadge(
                label: '${controller.records.length} governed records',
                tone: ComplianceTone.info,
              ),
            ],
          );
        },
      ),
    );
  }

  static const List<(String, IconData)> _sections = <(String, IconData)>[
    ('Dashboard', Icons.space_dashboard_outlined),
    ('Reports', Icons.description_outlined),
    ('Queries', Icons.question_answer_outlined),
    ('Notices', Icons.mark_email_unread_outlined),
    ('Legal Cases', Icons.gavel_outlined),
    ('Documents', Icons.folder_outlined),
    ('Analytics', Icons.insights_outlined),
    ('Audit Log', Icons.history_outlined),
    ('Schedules', Icons.schedule_outlined),
    ('Settings', Icons.settings_outlined),
  ];

  Widget _navigation() {
    final palette = context.compliance;
    return ComplianceCard(
      padding: const EdgeInsets.all(ComplianceSpacing.xs),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              if (!sidebarCollapsed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      'WORKSPACE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.textTertiary,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: sidebarCollapsed ? 'Expand menu' : 'Collapse menu',
                onPressed: () =>
                    setState(() => sidebarCollapsed = !sidebarCollapsed),
                icon: Icon(
                  sidebarCollapsed
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                ),
              ),
            ],
          ),
          Divider(color: palette.border),
          Expanded(
            child: ListView.separated(
              itemCount: _sections.length,
              separatorBuilder: (_, __) => SizedBox(height: 3),
              itemBuilder: (context, index) {
                final item = _sections[index];
                final selected = tab == index;
                return Tooltip(
                  message: sidebarCollapsed ? item.$1 : '',
                  child: ListTile(
                    selected: selected,
                    selectedTileColor: palette.primarySoft,
                    leading: Icon(
                      item.$2,
                      color: selected ? palette.primary : palette.textSecondary,
                    ),
                    title: sidebarCollapsed
                        ? null
                        : Text(
                            item.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => setState(() => tab = index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileNavigation() {
    return ComplianceSelector<int>(
      label: 'Workspace',
      valueLabel: _sections[tab].$1,
      options: List<int>.generate(_sections.length, (index) => index),
      labelBuilder: (index) => _sections[index].$1,
      onSelected: (index) => setState(() => tab = index),
      icon: _sections[tab].$2,
      width: double.infinity,
    );
  }

  Widget _content() {
    if (controller.loading) {
      return Center(
        child: CircularProgressIndicator(color: context.compliance.primary),
      );
    }
    if (controller.error != null) {
      return _state(
        Icons.error_outline,
        controller.error!,
        action: TextButton(onPressed: controller.refresh, child: Text('Retry')),
      );
    }
    return switch (tab) {
      0 => _dashboard(),
      1 => _reports(),
      2 => _records(
        ComplianceRecordType.query,
        'Queries',
        canAdd: widget.permissions.canCreate,
      ),
      3 => _records(
        ComplianceRecordType.notice,
        'Government Notices',
        canAdd: widget.permissions.canCreate,
      ),
      4 => _records(
        ComplianceRecordType.legalCase,
        'Legal Cases',
        canAdd: widget.permissions.canCreate,
      ),
      5 => _records(
        ComplianceRecordType.document,
        'Documents',
        canAdd: widget.permissions.canUpload,
      ),
      6 => _analytics(),
      7 => _records(null, 'Audit Log'),
      8 => _schedules(),
      _ => _settings(),
    };
  }

  Widget _dashboard() {
    final k = controller.kpis;
    final values = <(String, num, Color, String)>[
      ('Total Compliance', k.total, context.compliance.primary, ''),
      (
        'Completed Compliance',
        k.completed,
        context.compliance.success,
        'Completed',
      ),
      ('Pending Compliance', k.pending, context.compliance.warning, 'Pending'),
      ('Overdue Compliance', k.overdue, context.compliance.danger, 'Overdue'),
      (
        'Critical Compliance',
        k.critical,
        context.compliance.danger,
        'Critical',
      ),
      ('Government Notices', k.notices, context.compliance.warning, ''),
      ('Open Queries', k.openQueries, context.compliance.warning, 'Open'),
      (
        'Resolved Queries',
        k.resolvedQueries,
        context.compliance.success,
        'Resolved',
      ),
      ("Today's Due", k.todayDue, context.compliance.warning, ''),
      ('Late Filings', k.lateFilings, context.compliance.danger, ''),
      ('Penalties', k.penalties, context.compliance.danger, ''),
      ('Total Reports Generated', k.reports, context.compliance.primary, ''),
    ];
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width > 1200
                  ? 4
                  : MediaQuery.sizeOf(context).width > 700
                  ? 3
                  : 2,
              childAspectRatio: 2.15,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: values.length,
            itemBuilder: (context, i) {
              final v = values[i];
              return Semantics(
                button: true,
                label: '${v.$1}: ${v.$2}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (v.$4.isNotEmpty) {
                      if (v.$4 == 'Critical') {
                        controller.setPriority(v.$4);
                      } else {
                        controller.setStatus(v.$4);
                      }
                    }
                    setState(
                      () => tab = v.$1.contains('Query')
                          ? 2
                          : v.$1.contains('Notice')
                          ? 3
                          : 1,
                    );
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            v.$1,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            v.$2 is double
                                ? NumberFormat.currency(
                                    symbol: '₹',
                                  ).format(v.$2)
                                : v.$2.toString(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: v.$3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reports() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _toolbar('Report definitions', false),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: complianceReportDefinitions
            .map(
              (definition) => SizedBox(
                width: 300,
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.description_outlined,
                      color: context.compliance.primary,
                    ),
                    title: Text(definition.name),
                    subtitle: Text(
                      '${controller.report(definition).length} matching records',
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => _showReport(definition),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
  Widget _records(
    ComplianceRecordType? type,
    String title, {
    bool canAdd = false,
  }) {
    final rows = type == null
        ? <ComplianceRecord>[]
        : controller.filtered.where((r) => r.type == type).toList();
    return Column(
      children: [
        _toolbar(title, canAdd),
        Expanded(
          child: rows.isEmpty
              ? _state(
                  Icons.inbox_outlined,
                  type == null
                      ? 'Audit entries are written for changes and can be reviewed in Firestore.'
                      : 'No $title match the active filters.',
                )
              : cards
              ? _cardList(rows)
              : _table(rows),
        ),
      ],
    );
  }

  Widget _toolbar(String title, bool canAdd) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (controller.filters.count > 0) ...[
          SizedBox(width: 8),
          Chip(
            label: Text('${controller.filters.count} filters'),
            onDeleted: controller.clearFilters,
          ),
        ],
        Spacer(),
        IconButton(
          tooltip: 'Table view',
          onPressed: () => setState(() => cards = false),
          icon: Icon(
            Icons.table_rows,
            color: cards ? null : context.compliance.primary,
          ),
        ),
        IconButton(
          tooltip: 'Card view',
          onPressed: () => setState(() => cards = true),
          icon: Icon(
            Icons.grid_view,
            color: cards ? context.compliance.primary : null,
          ),
        ),
        if (canAdd)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: context.compliance.primary,
            ),
            onPressed: tab == 2
                ? _queryDialog
                : () => _message(
                    tab == 5
                        ? 'Use the upload action on a source record to preserve document linkage.'
                        : 'Creation form is available from the corresponding record workflow.',
                  ),
            icon: Icon(Icons.add),
            label: Text('New'),
          ),
      ],
    ),
  );
  Widget _table(List<ComplianceRecord> rows) {
    String date(DateTime? value) =>
        value == null ? '—' : DateFormat('dd MMM yyyy').format(value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: ComplianceDataGrid<ComplianceRecord>(
        rows: rows,
        rowId: (row) => row.id,
        pageSize: 25,
        onRowTap: _details,
        onRowDoubleTap: _details,
        contextMenuBuilder: (context, row) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'view',
            onTap: () => WidgetsBinding.instance.addPostFrameCallback(
              (_) => _details(row),
            ),
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.visibility_outlined),
              title: Text('Open record'),
            ),
          ),
          if (widget.permissions.canExport)
            PopupMenuItem<String>(
              value: 'export',
              onTap: () => WidgetsBinding.instance.addPostFrameCallback(
                (_) => _message(
                  'Generate the linked report before exporting this record.',
                ),
              ),
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.file_download_outlined),
                title: Text('Export'),
              ),
            ),
        ],
        columns: <ComplianceGridColumn<ComplianceRecord>>[
          ComplianceGridColumn<ComplianceRecord>(
            id: 'reference',
            label: 'REFERENCE NO.',
            width: 150,
            sortValue: (row) => row.referenceNumber,
            cellBuilder: (_, row) => Text(
              row.referenceNumber,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'title',
            label: 'TITLE',
            width: 260,
            sortValue: (row) => row.title,
            cellBuilder: (_, row) =>
                Text(row.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'department',
            label: 'DEPARTMENT',
            width: 150,
            sortValue: (row) => row.department,
            cellBuilder: (_, row) =>
                Text(row.department.isEmpty ? '—' : row.department),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'authority',
            label: 'AUTHORITY',
            width: 165,
            sortValue: (row) => row.authority,
            cellBuilder: (_, row) =>
                Text(row.authority.isEmpty ? '—' : row.authority),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'category',
            label: 'CATEGORY',
            width: 150,
            sortValue: (row) => row.category,
            cellBuilder: (_, row) =>
                Text(row.category.isEmpty ? '—' : row.category),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'assigned',
            label: 'ASSIGNED TO',
            width: 160,
            sortValue: (row) => row.assignedTo,
            cellBuilder: (_, row) =>
                Text(row.assignedTo.isEmpty ? 'Unassigned' : row.assignedTo),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'dueDate',
            label: 'DUE DATE',
            width: 135,
            sortValue: (row) => row.dueDate,
            cellBuilder: (_, row) => Text(date(row.dueDate)),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'status',
            label: 'STATUS',
            width: 135,
            sortValue: (row) => row.status,
            cellBuilder: (_, row) => ComplianceStatusBadge(
              label: row.isOverdue ? 'Overdue' : row.status,
              compact: true,
            ),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'priority',
            label: 'PRIORITY',
            width: 120,
            sortValue: (row) => row.priority,
            cellBuilder: (_, row) =>
                ComplianceStatusBadge(label: row.priority, compact: true),
          ),
          ComplianceGridColumn<ComplianceRecord>(
            id: 'updated',
            label: 'LAST UPDATED',
            width: 145,
            sortValue: (row) => row.updatedAt,
            cellBuilder: (_, row) => Text(date(row.updatedAt)),
          ),
        ],
      ),
    );
  }

  Widget _cardList(List<ComplianceRecord> rows) => ListView.builder(
    padding: const EdgeInsets.all(20),
    itemCount: rows.length,
    itemBuilder: (context, i) {
      final r = rows[i];
      return Card(
        child: ListTile(
          onTap: () => _details(r),
          title: Text('${r.referenceNumber} · ${r.title}'),
          subtitle: Text(
            '${r.department.isEmpty ? r.category : r.department} • Due ${r.dueDate == null ? '—' : DateFormat('dd MMM yyyy').format(r.dueDate!)}',
          ),
          trailing: Wrap(
            spacing: 6,
            children: [
              _badge(r.status, _statusColor(r)),
              _badge(
                r.priority,
                r.isCritical
                    ? context.compliance.danger
                    : context.compliance.warning,
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _analytics() {
    final k = controller.kpis;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Real-time Analytics',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compliance Completion %',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(8),
                  color: context.compliance.success,
                  value: k.total == 0 ? 0 : k.completed / k.total,
                ),
                SizedBox(height: 8),
                Text(
                  k.total == 0
                      ? 'No compliance data available'
                      : '${(k.completed / k.total * 100).toStringAsFixed(1)}% completed',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _schedules() => _state(
    Icons.schedule_outlined,
    'Backend scheduler configuration required',
    action: Text(
      'Schedule definitions can be saved only after a trusted backend runner is configured.',
    ),
  );
  Widget _settings() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        child: ListTile(
          leading: Icon(Icons.email_outlined),
          title: Text('Email delivery'),
          subtitle: Text('Email provider configuration required'),
          enabled: false,
        ),
      ),
      Card(
        child: ListTile(
          leading: Icon(Icons.chat_outlined),
          title: Text('WhatsApp delivery'),
          subtitle: Text('No working WhatsApp provider is configured'),
          enabled: false,
        ),
      ),
      Card(
        child: ListTile(
          leading: Icon(Icons.file_present_outlined),
          title: Text('Additional export formats'),
          subtitle: Text(
            'Excel, ODS, Word, JPEG and PNG adapters require configuration',
          ),
          enabled: false,
        ),
      ),
    ],
  );
  Widget _state(IconData icon, String text, {Widget? action}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[SizedBox(height: 12), action],
        ],
      ),
    ),
  );
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
  Color _statusColor(ComplianceRecord r) => r.isOverdue
      ? context.compliance.danger
      : r.isCompleted
      ? context.compliance.success
      : r.status.toLowerCase().contains('legal')
      ? context.compliance.legal
      : context.compliance.warning;
  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  void _details(ComplianceRecord r) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(r.referenceNumber),
        content: SizedBox(
          width: 480,
          child: SelectableText(
            '${r.title}\n\n${r.description}\n\nStatus: ${r.status}\nPriority: ${r.priority}\nAssigned to: ${r.assignedTo.isEmpty ? 'Unassigned' : r.assignedTo}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReport(ReportDefinition definition) async {
    final rows = controller.report(definition);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(definition.name),
        content: SizedBox(
          width: 760,
          height: 420,
          child: rows.isEmpty
              ? _state(
                  Icons.description_outlined,
                  'No real repository records match this report.',
                )
              : _table(rows),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close'),
          ),
          PopupMenuButton<String>(
            enabled: widget.permissions.canExport,
            onSelected: (format) => _export(definition, rows, format),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
              PopupMenuItem(value: 'pdf', child: Text('Export PDF / Print')),
            ],
            child: Padding(padding: EdgeInsets.all(12), child: Text('Export')),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    ReportDefinition definition,
    List<ComplianceRecord> rows,
    String format,
  ) async {
    try {
      final service = DefaultComplianceExportService();
      final bytes = await service.export(
        format,
        definition.name,
        rows,
        companyName: widget.companyName,
        generatedBy: widget.currentUserName,
        filters: controller.filters,
      );
      final filename = service.filename(
        definition.name,
        format,
        DateTime.now(),
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save $filename',
        fileName: filename,
        bytes: bytes,
      );
      if (mounted) {
        _message('$format report generated.');
      }
    } catch (e) {
      if (mounted) {
        _message(e.toString());
      }
    }
  }

  Future<void> _queryDialog() async {
    final subject = TextEditingController(),
        description = TextEditingController();
    String priority = 'Medium';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create compliance query'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subject,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                ComplianceSelector<String>(
                  label: 'Priority',
                  valueLabel: priority,
                  options: ComplianceQuery.priorities,
                  labelBuilder: (value) => value,
                  onSelected: (value) {
                    setDialogState(() => priority = value);
                  },
                  icon: Icons.priority_high_rounded,
                  width: double.infinity,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.compliance.primary,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && subject.text.trim().isNotEmpty) {
      try {
        await controller.repository.saveQuery(
          ComplianceQuery(
            id: '',
            queryNumber: '',
            subject: subject.text,
            description: description.text,
            companyId: widget.companyId,
            createdByUserId: widget.currentUserUid,
            createdByName: widget.currentUserName,
            priority: priority,
          ),
          userId: widget.currentUserUid,
          userName: widget.currentUserName,
        );
        if (mounted) {
          _message('Query created');
          await controller.refresh();
        }
      } catch (e) {
        if (mounted) {
          _message(e.toString());
        }
      }
    }
    subject.dispose();
    description.dispose();
  }
}
