import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_design_system.dart';
import '../controllers/compliance_calendar_controller.dart';
import '../models/compliance_calendar_model.dart';
import '../repositories/compliance_calendar_repository.dart';

class ComplianceCalendarScreen extends StatefulWidget {
  ComplianceCalendarScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.companyName,
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
    this.canExport = true,
    this.canUpload = true,
    this.canDownload = true,
  });

  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String companyName;

  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canExport;
  final bool canUpload;
  final bool canDownload;

  @override
  State<ComplianceCalendarScreen> createState() =>
      _ComplianceCalendarScreenState();
}

class _ComplianceCalendarScreenState extends State<ComplianceCalendarScreen> {
  static const List<String> _categories = <String>[
    'GST',
    'Income Tax',
    'TDS',
    'TCS',
    'ROC',
    'MCA',
    'PF',
    'ESIC',
    'Professional Tax',
    'Labour Law',
    'Factories Act',
    'Pollution Control',
    'Fire NOC',
    'Trade License',
    'MSME',
    'IEC',
    'FSSAI',
    'Legal',
    'Environment',
    'Custom Compliance',
  ];

  static const List<String> _frequencies = <String>[
    'One Time',
    'Daily',
    'Weekly',
    'Fortnightly',
    'Monthly',
    'Quarterly',
    'Half Yearly',
    'Yearly',
    'Custom',
  ];

  static const List<String> _statuses = <String>[
    'Pending',
    'Completed',
    'Upcoming',
    'Overdue',
    'Cancelled',
    'Rescheduled',
  ];

  static const List<String> _priorities = <String>[
    'Critical',
    'High',
    'Medium',
    'Low',
  ];

  late final ComplianceCalendarController _controller;
  late final ComplianceCalendarRepository _repository;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _repository = ComplianceCalendarRepository(companyId: widget.companyId);

    _controller = ComplianceCalendarController(repository: _repository)
      ..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();

    _searchController.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? context.compliance.danger
            : context.compliance.success,
      ),
    );
  }

  Future<void> _showComplianceForm({
    ComplianceCalendarModel? existing,
    DateTime? initialDate,
  }) async {
    final editing = existing != null;
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final actController = TextEditingController(text: existing?.act ?? '');
    final sectionController = TextEditingController(
      text: existing?.section ?? '',
    );
    final authorityController = TextEditingController(
      text: existing?.authority ?? '',
    );
    final assignedController = TextEditingController(
      text: existing?.assignedEmployee ?? '',
    );
    final departmentController = TextEditingController(
      text: existing?.department ?? '',
    );
    final branchController = TextEditingController(
      text: existing?.branch ?? '',
    );
    final penaltyController = TextEditingController(
      text: existing?.penalty.toString() ?? '0',
    );
    final lateFeeController = TextEditingController(
      text: existing?.lateFee.toString() ?? '0',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');

    var category = existing?.category ?? 'GST';
    var frequency = existing?.frequency ?? 'Monthly';
    var priority = existing?.priority ?? 'Medium';
    var status = existing?.status ?? 'Pending';
    var financialYear = existing?.financialYear ?? 'FY 2026–27';
    var assessmentYear = existing?.assessmentYear ?? 'AY 2027–28';
    var dueDate = existing?.dueDate ?? initialDate ?? DateTime.now();

    final result = await showDialog<ComplianceCalendarModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(editing ? 'Edit Compliance' : 'Add Compliance'),
              content: SizedBox(
                width: 920,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _field(
                          controller: titleController,
                          label: 'Compliance Name',
                          width: 580,
                        ),
                        _dropdown(
                          label: 'Category',
                          value: category,
                          values: _categories,
                          width: 280,
                          onChanged: (value) {
                            setDialogState(() => category = value);
                          },
                        ),
                        _field(
                          controller: descriptionController,
                          label: 'Description',
                          width: 880,
                          maxLines: 3,
                        ),
                        _field(
                          controller: actController,
                          label: 'Act',
                          width: 280,
                        ),
                        _field(
                          controller: sectionController,
                          label: 'Section',
                          width: 280,
                        ),
                        _field(
                          controller: authorityController,
                          label: 'Authority',
                          width: 280,
                        ),
                        _dropdown(
                          label: 'Frequency',
                          value: frequency,
                          values: _frequencies,
                          width: 205,
                          onChanged: (value) {
                            setDialogState(() => frequency = value);
                          },
                        ),
                        _dropdown(
                          label: 'Priority',
                          value: priority,
                          values: _priorities,
                          width: 205,
                          onChanged: (value) {
                            setDialogState(() => priority = value);
                          },
                        ),
                        _dropdown(
                          label: 'Status',
                          value: status,
                          values: _statuses,
                          width: 205,
                          onChanged: (value) {
                            setDialogState(() => status = value);
                          },
                        ),
                        _dropdown(
                          label: 'Financial Year',
                          value: financialYear,
                          values: const <String>[
                            'FY 2025–26',
                            'FY 2026–27',
                            'FY 2027–28',
                          ],
                          width: 205,
                          onChanged: (value) {
                            setDialogState(() => financialYear = value);
                          },
                        ),
                        _dropdown(
                          label: 'Assessment Year',
                          value: assessmentYear,
                          values: const <String>[
                            'AY 2026–27',
                            'AY 2027–28',
                            'AY 2028–29',
                          ],
                          width: 205,
                          onChanged: (value) {
                            setDialogState(() => assessmentYear = value);
                          },
                        ),
                        SizedBox(
                          width: 205,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                initialDate: dueDate,
                              );

                              if (date != null) {
                                setDialogState(() => dueDate = date);
                              }
                            },
                            icon: Icon(Icons.calendar_today_outlined),
                            label: Text(
                              DateFormat('dd MMM yyyy').format(dueDate),
                            ),
                          ),
                        ),
                        _field(
                          controller: assignedController,
                          label: 'Responsible Person',
                          width: 280,
                        ),
                        _field(
                          controller: departmentController,
                          label: 'Department',
                          width: 280,
                        ),
                        _field(
                          controller: branchController,
                          label: 'Branch',
                          width: 280,
                        ),
                        _field(
                          controller: penaltyController,
                          label: 'Penalty',
                          width: 205,
                          numeric: true,
                        ),
                        _field(
                          controller: lateFeeController,
                          label: 'Late Fee',
                          width: 205,
                          numeric: true,
                        ),
                        _field(
                          controller: notesController,
                          label: 'Notes',
                          width: 880,
                          maxLines: 4,
                          required: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }

                    final now = DateTime.now();

                    Navigator.pop(
                      dialogContext,
                      ComplianceCalendarModel(
                        id: existing?.id ?? '',
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        act: actController.text.trim(),
                        section: sectionController.text.trim(),
                        authority: authorityController.text.trim(),
                        category: category,
                        frequency: frequency,
                        financialYear: financialYear,
                        assessmentYear: assessmentYear,
                        dueDate: dueDate,
                        reminderDates: <DateTime>[
                          dueDate.subtract(Duration(days: 30)),
                          dueDate.subtract(Duration(days: 15)),
                          dueDate.subtract(Duration(days: 7)),
                          dueDate.subtract(Duration(days: 1)),
                        ],
                        priority: priority,
                        status: status,
                        assignedEmployee: assignedController.text.trim(),
                        department: departmentController.text.trim(),
                        branch: branchController.text.trim(),
                        company: widget.companyName,
                        penalty:
                            double.tryParse(penaltyController.text.trim()) ?? 0,
                        lateFee:
                            double.tryParse(lateFeeController.text.trim()) ?? 0,
                        documentUrls:
                            existing?.documentUrls ?? const <String>[],
                        notes: notesController.text.trim(),
                        createdBy: existing?.createdBy ?? widget.currentUserUid,
                        createdAt: existing?.createdAt ?? now,
                        updatedAt: now,
                      ),
                    );
                  },
                  icon: Icon(Icons.save_outlined),
                  label: Text(editing ? 'Update' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    actController.dispose();
    sectionController.dispose();
    authorityController.dispose();
    assignedController.dispose();
    departmentController.dispose();
    branchController.dispose();
    penaltyController.dispose();
    lateFeeController.dispose();
    notesController.dispose();

    if (result == null || !mounted) return;

    try {
      if (editing) {
        await _controller.update(item: result, userUid: widget.currentUserUid);
        _message('Compliance updated successfully.');
      } else {
        await _controller.create(item: result, userUid: widget.currentUserUid);
        _message('Compliance created successfully.');
      }
    } catch (error) {
      _message('Unable to save compliance: $error', error: true);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required double width,
    int maxLines = 1,
    bool numeric = false,
    bool required = true,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }

          if (numeric &&
              value != null &&
              value.trim().isNotEmpty &&
              double.tryParse(value.trim()) == null) {
            return 'Enter a valid amount';
          }

          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required double width,
    required ValueChanged<String> onChanged,
  }) {
    return ComplianceSelector<String>(
      label: label,
      valueLabel: value,
      options: values,
      labelBuilder: (item) => item,
      onSelected: onChanged,
      searchHint: 'Search $label',
      icon: Icons.manage_search_rounded,
      width: width,
    );
  }

  Future<void> _delete(ComplianceCalendarModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete Compliance'),
          content: Text('Delete "${item.title}" from the calendar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.compliance.danger,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _controller.archive(id: item.id, userUid: widget.currentUserUid);
      _message('Compliance deleted.');
    } catch (error) {
      _message('Unable to delete compliance: $error', error: true);
    }
  }

  Future<void> _exportCsv(List<ComplianceCalendarModel> records) async {
    final rows = <List<String>>[
      const <String>[
        'Due Date',
        'Compliance Name',
        'Description',
        'Category',
        'Act',
        'Section',
        'Authority',
        'Frequency',
        'Financial Year',
        'Assessment Year',
        'Responsible Person',
        'Department',
        'Branch',
        'Priority',
        'Status',
        'Penalty',
        'Late Fee',
        'Notes',
      ],
      ...records.map((item) {
        return <String>[
          DateFormat('yyyy-MM-dd').format(item.dueDate),
          item.title,
          item.description,
          item.category,
          item.act,
          item.section,
          item.authority,
          item.frequency,
          item.financialYear,
          item.assessmentYear,
          item.assignedEmployee,
          item.department,
          item.branch,
          item.priority,
          item.status,
          item.penalty.toStringAsFixed(2),
          item.lateFee.toStringAsFixed(2),
          item.notes,
        ];
      }),
    ];

    String escape(String value) => '"${value.replaceAll('"', '""')}"';

    final csv = rows.map((row) => row.map(escape).join(',')).join('\n');

    await FilePicker.platform.saveFile(
      dialogTitle: 'Export Compliance Calendar',
      fileName: 'compliance_calendar_fy_2026_27.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
  }

  Future<void> _exportIcs(List<ComplianceCalendarModel> records) async {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//MEMCO//Quik ERP//EN');

    for (final item in records) {
      final date = DateFormat('yyyyMMdd').format(item.dueDate);

      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${item.id}@memco-quik-erp')
        ..writeln('DTSTART;VALUE=DATE:$date')
        ..writeln('SUMMARY:${item.title.replaceAll(',', r'\,')}')
        ..writeln('DESCRIPTION:${item.description.replaceAll(',', r'\,')}')
        ..writeln('CATEGORIES:${item.category}')
        ..writeln(
          'STATUS:${item.status == 'Completed' ? 'COMPLETED' : 'CONFIRMED'}',
        )
        ..writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');

    await FilePicker.platform.saveFile(
      dialogTitle: 'Export ICS Calendar',
      fileName: 'compliance_calendar_fy_2026_27.ics',
      bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ComplianceCalendarModel>>(
      stream: _repository.watchCompliance(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Unable to load compliance calendar.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.compliance.danger),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final allRecords = snapshot.data!;
        final filtered = _controller.applyFilters(allRecords);

        return ComplianceSubpageShell(
          title: 'Compliance Calendar',
          subtitle:
              'Centralized due-date control, ownership, reminders and evidence',
          icon: Icons.calendar_month_outlined,
          breadcrumbs: const <String>[
            'Administration',
            'Compliance & Legal',
            'Calendar & Due Dates',
          ],
          onBack: () => Navigator.maybePop(context),
          padding: EdgeInsets.zero,
          actions: <Widget>[
            PopupMenuButton<String>(
              tooltip: 'Export calendar',
              enabled: widget.canExport && filtered.isNotEmpty,
              onSelected: (value) async {
                if (value == 'csv') {
                  await _exportCsv(filtered);
                } else if (value == 'ics') {
                  await _exportIcs(filtered);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem(value: 'csv', child: Text('Export CSV')),
                const PopupMenuItem(
                  value: 'ics',
                  child: Text('Export ICS Calendar'),
                ),
              ],
              icon: const Icon(Icons.download_outlined),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _controller.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            FilledButton.icon(
              onPressed: widget.canCreate ? () => _showComplianceForm() : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Compliance'),
            ),
          ],
          child: Column(
            children: [
              _buildKpis(allRecords),
              _buildFilters(allRecords),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 1100;

                    if (compact) {
                      return Column(
                        children: [
                          Expanded(child: _buildCalendar(filtered)),
                          SizedBox(height: 330, child: _buildAgenda(filtered)),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 3, child: _buildCalendar(filtered)),
                        VerticalDivider(width: 1),
                        Expanded(flex: 2, child: _buildAgenda(filtered)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpis(List<ComplianceCalendarModel> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int countWhere(bool Function(ComplianceCalendarModel item) test) =>
        records.where(test).length;

    int daysUntil(ComplianceCalendarModel item) {
      final due = DateTime(
        item.dueDate.year,
        item.dueDate.month,
        item.dueDate.day,
      );
      return due.difference(today).inDays;
    }

    final cards = <_KpiData>[
      _KpiData(
        label: 'Total Compliance',
        count: records.length,
        color: context.compliance.primary,
      ),
      _KpiData(
        label: 'Completed',
        count: countWhere((item) => item.status == 'Completed'),
        color: context.compliance.success,
      ),
      _KpiData(
        label: 'Pending',
        count: countWhere((item) => item.status == 'Pending'),
        color: context.compliance.warning,
      ),
      _KpiData(
        label: 'Overdue',
        count: countWhere(
          (item) => item.status != 'Completed' && daysUntil(item) < 0,
        ),
        color: context.compliance.danger,
      ),
      _KpiData(
        label: 'Due Today',
        count: countWhere((item) => daysUntil(item) == 0),
        color: context.compliance.danger,
      ),
      _KpiData(
        label: 'Due in 7 Days',
        count: countWhere(
          (item) => daysUntil(item) >= 0 && daysUntil(item) <= 7,
        ),
        color: context.compliance.warning,
      ),
      _KpiData(
        label: 'Due in 30 Days',
        count: countWhere(
          (item) => daysUntil(item) >= 0 && daysUntil(item) <= 30,
        ),
        color: context.compliance.primary,
      ),
      _KpiData(
        label: 'High Priority',
        count: countWhere(
          (item) => item.priority == 'High' || item.priority == 'Critical',
        ),
        color: context.compliance.danger,
      ),
    ];

    return Container(
      color: context.compliance.surface,
      padding: EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = ((constraints.maxWidth - 42) / 4).clamp(160.0, 260.0);

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards.map((data) {
              final selected = _controller.kpiFilter == data.label;

              return InkWell(
                onTap: () => _controller.setKpiFilter(
                  data.label == 'Total Compliance' ? null : data.label,
                ),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  width: width,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? data.color.withValues(alpha: 0.08)
                        : context.compliance.surface,
                    border: Border.all(
                      color: selected ? data.color : context.compliance.border,
                      width: selected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: records.isEmpty
                                  ? 0
                                  : data.count / records.length,
                              strokeWidth: 4,
                              color: data.color,
                              backgroundColor: context.compliance.surfaceMuted,
                            ),
                            Text(
                              '${data.count}',
                              style: TextStyle(
                                color: context.compliance.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          data.label,
                          style: TextStyle(
                            color: context.compliance.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildFilters(List<ComplianceCalendarModel> records) {
    final departments = <String>{
      'All',
      ...records
          .map((item) => item.department)
          .where((value) => value.isNotEmpty),
    }.toList()..sort();

    final branches = <String>{
      'All',
      ...records.map((item) => item.branch).where((value) => value.isNotEmpty),
    }.toList()..sort();

    return Container(
      color: context.compliance.surfaceMuted,
      padding: EdgeInsets.all(10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 270,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _controller.search = value;
                _controller.refresh();
              },
              decoration: InputDecoration(
                hintText: 'Search compliance...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _filter(
            label: 'Financial Year',
            value: _controller.financialYear,
            values: const ['All', 'FY 2025–26', 'FY 2026–27', 'FY 2027–28'],
            onChanged: (value) {
              _controller.financialYear = value;
              _controller.refresh();
            },
          ),
          _filter(
            label: 'Category',
            value: _controller.category,
            values: <String>['All', ..._categories],
            onChanged: (value) {
              _controller.category = value;
              _controller.refresh();
            },
          ),
          _filter(
            label: 'Status',
            value: _controller.status,
            values: <String>['All', ..._statuses],
            onChanged: (value) {
              _controller.status = value;
              _controller.refresh();
            },
          ),
          _filter(
            label: 'Priority',
            value: _controller.priority,
            values: <String>['All', ..._priorities],
            onChanged: (value) {
              _controller.priority = value;
              _controller.refresh();
            },
          ),
          _filter(
            label: 'Department',
            value: departments.contains(_controller.department)
                ? _controller.department
                : 'All',
            values: departments,
            onChanged: (value) {
              _controller.department = value;
              _controller.refresh();
            },
          ),
          _filter(
            label: 'Branch',
            value: branches.contains(_controller.branch)
                ? _controller.branch
                : 'All',
            values: branches,
            onChanged: (value) {
              _controller.branch = value;
              _controller.refresh();
            },
          ),
          SegmentedButton<ComplianceViewMode>(
            segments: const [
              ButtonSegment(
                value: ComplianceViewMode.month,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Month'),
              ),
              ButtonSegment(
                value: ComplianceViewMode.week,
                icon: Icon(Icons.view_week_outlined),
                label: Text('Week'),
              ),
              ButtonSegment(
                value: ComplianceViewMode.agenda,
                icon: Icon(Icons.list_alt_outlined),
                label: Text('Agenda'),
              ),
            ],
            selected: <ComplianceViewMode>{_controller.viewMode},
            onSelectionChanged: (selection) {
              _controller.setViewMode(selection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _filter({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return ComplianceSelector<String>(
      label: label,
      valueLabel: value,
      options: values,
      labelBuilder: (item) => item,
      onSelected: onChanged,
      searchHint: 'Search $label',
      icon: Icons.filter_alt_outlined,
      width: 168,
    );
  }

  Widget _buildCalendar(List<ComplianceCalendarModel> records) {
    if (_controller.viewMode == ComplianceViewMode.agenda) {
      return _buildAgenda(records);
    }

    if (_controller.viewMode == ComplianceViewMode.week) {
      return _buildWeek(records);
    }

    return _buildMonth(records);
  }

  Widget _buildMonth(List<ComplianceCalendarModel> records) {
    final month = _controller.focusedDate;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leadingDays = firstDay.weekday % 7;
    final totalCells = ((leadingDays + lastDay.day) / 7).ceil() * 7;

    return Container(
      margin: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.compliance.surface,
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _calendarToolbar(),
          Divider(height: 1),
          Row(
            children: [
              _Weekday('Sun'),
              _Weekday('Mon'),
              _Weekday('Tue'),
              _Weekday('Wed'),
              _Weekday('Thu'),
              _Weekday('Fri'),
              _Weekday('Sat'),
            ],
          ),
          Divider(height: 1),
          Expanded(
            child: GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final day = index - leadingDays + 1;
                final valid = day >= 1 && day <= lastDay.day;

                if (!valid) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.compliance.surfaceMuted,
                      border: Border(
                        right: BorderSide(color: context.compliance.border),
                        bottom: BorderSide(color: context.compliance.border),
                      ),
                    ),
                  );
                }

                final date = DateTime(month.year, month.month, day);
                final events = records.where((item) {
                  return item.dueDate.year == date.year &&
                      item.dueDate.month == date.month &&
                      item.dueDate.day == date.day;
                }).toList();

                final today = DateTime.now();
                final isToday =
                    today.year == date.year &&
                    today.month == date.month &&
                    today.day == date.day;

                final weekend =
                    date.weekday == DateTime.saturday ||
                    date.weekday == DateTime.sunday;

                return InkWell(
                  onTap: () {
                    _controller.selectDate(date);
                  },
                  onDoubleTap: widget.canCreate
                      ? () => _showComplianceForm(initialDate: date)
                      : null,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: weekend
                          ? context.compliance.surfaceMuted
                          : context.compliance.surface,
                      border: Border(
                        right: BorderSide(color: context.compliance.border),
                        bottom: BorderSide(color: context.compliance.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday
                                ? context.compliance.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: isToday
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : context.compliance.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: 3),
                        Expanded(
                          child: ListView(
                            physics: NeverScrollableScrollPhysics(),
                            children: events
                                .take(3)
                                .map((event) => _calendarEvent(event))
                                .toList(),
                          ),
                        ),
                        if (events.length > 3)
                          Text(
                            '+${events.length - 3} more',
                            style: TextStyle(
                              color: context.compliance.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarToolbar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous',
            onPressed: () {
              final date = _controller.focusedDate;

              _controller.setFocusedDate(DateTime(date.year, date.month - 1));
            },
            icon: Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_controller.focusedDate),
            style: TextStyle(
              color: context.compliance.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: () {
              final date = _controller.focusedDate;

              _controller.setFocusedDate(DateTime(date.year, date.month + 1));
            },
            icon: Icon(Icons.chevron_right),
          ),
          Spacer(),
          OutlinedButton(
            onPressed: () {
              _controller.setFocusedDate(DateTime.now());
            },
            child: Text('Today'),
          ),
          SizedBox(width: 8),
          FilledButton.icon(
            onPressed: widget.canCreate
                ? () =>
                      _showComplianceForm(initialDate: _controller.selectedDate)
                : null,
            icon: Icon(Icons.add),
            label: Text('Quick Add'),
          ),
        ],
      ),
    );
  }

  Widget _calendarEvent(ComplianceCalendarModel item) {
    final color = _statusColor(item);

    return InkWell(
      onTap: () => _showDetails(item),
      child: Container(
        margin: EdgeInsets.only(bottom: 3),
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildWeek(List<ComplianceCalendarModel> records) {
    final focused = _controller.focusedDate;
    final monday = focused.subtract(Duration(days: focused.weekday - 1));

    final days = List<DateTime>.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );

    return Container(
      margin: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.compliance.surface,
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _calendarToolbar(),
          Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: days.map((date) {
                final events = records.where((item) {
                  return item.dueDate.year == date.year &&
                      item.dueDate.month == date.month &&
                      item.dueDate.day == date.day;
                }).toList();

                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: context.compliance.border),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(10),
                          color: context.compliance.surfaceMuted,
                          child: Column(
                            children: [
                              Text(
                                DateFormat('EEE').format(date),
                                style: TextStyle(
                                  color: context.compliance.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                DateFormat('dd MMM').format(date),
                                style: TextStyle(
                                  color: context.compliance.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.all(7),
                            itemCount: events.length,
                            itemBuilder: (_, index) {
                              final item = events[index];

                              return Card(
                                elevation: 0,
                                margin: EdgeInsets.only(bottom: 7),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: context.compliance.border,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  dense: true,
                                  onTap: () => _showDetails(item),
                                  title: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item.category,
                                    style: TextStyle(fontSize: 9),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgenda(List<ComplianceCalendarModel> records) {
    return Container(
      color: context.compliance.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.compliance.border),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Compliance Agenda',
                  style: TextStyle(
                    color: context.compliance.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Spacer(),
                Text(
                  '${records.length} records',
                  style: TextStyle(
                    color: context.compliance.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Text(
                      'No compliance records found.',
                      style: TextStyle(color: context.compliance.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(12),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = records[index];

                      return InkWell(
                        onTap: () => _showDetails(item),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.compliance.surface,
                            border: Border.all(
                              color: context.compliance.border,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    item,
                                  ).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('dd').format(item.dueDate),
                                      style: TextStyle(
                                        color: _statusColor(item),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM').format(item.dueDate),
                                      style: TextStyle(
                                        color: _statusColor(item),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.compliance.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${item.category} • ${item.authority}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.compliance.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _badge(
                                item.priority,
                                item.priority == 'Critical' ||
                                        item.priority == 'High'
                                    ? context.compliance.danger
                                    : context.compliance.warning,
                              ),
                              SizedBox(width: 7),
                              _badge(item.status, _statusColor(item)),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'view') {
                                    _showDetails(item);
                                  } else if (value == 'edit') {
                                    await _showComplianceForm(existing: item);
                                  } else if (value == 'complete') {
                                    await _controller.updateStatus(
                                      id: item.id,
                                      status: 'Completed',
                                      userUid: widget.currentUserUid,
                                    );
                                  } else if (value == 'delete') {
                                    await _delete(item);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'view',
                                    child: Text('View'),
                                  ),
                                  if (widget.canEdit)
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                  if (widget.canEdit)
                                    PopupMenuItem(
                                      value: 'complete',
                                      child: Text('Mark Completed'),
                                    ),
                                  if (widget.canDelete)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ComplianceCalendarModel item) {
    if (item.status == 'Completed') return context.compliance.success;

    final today = DateTime.now();
    final due = DateTime(
      item.dueDate.year,
      item.dueDate.month,
      item.dueDate.day,
    );
    final current = DateTime(today.year, today.month, today.day);

    if (due.isBefore(current)) return context.compliance.danger;
    return context.compliance.warning;
  }

  Widget _badge(String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showDetails(ComplianceCalendarModel item) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close compliance details',
      barrierColor: context.compliance.scrim,
      transitionDuration: Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: context.compliance.surface,
            elevation: 14,
            child: SizedBox(
              width: 500,
              height: double.infinity,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: context.compliance.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(18),
                        children: [
                          _detail(
                            'Due Date',
                            DateFormat('dd MMM yyyy').format(item.dueDate),
                          ),
                          _detail('Description', item.description),
                          _detail('Category', item.category),
                          _detail('Act', item.act),
                          _detail('Section', item.section),
                          _detail('Authority', item.authority),
                          _detail('Frequency', item.frequency),
                          _detail('Financial Year', item.financialYear),
                          _detail('Assessment Year', item.assessmentYear),
                          _detail('Responsible Person', item.assignedEmployee),
                          _detail('Department', item.department),
                          _detail('Branch', item.branch),
                          _detail('Priority', item.priority),
                          _detail('Status', item.status),
                          _detail('Penalty', item.penalty.toStringAsFixed(2)),
                          _detail('Late Fee', item.lateFee.toStringAsFixed(2)),
                          _detail('Notes', item.notes),
                          _detail(
                            'Reminder Schedule',
                            item.reminderDates
                                .map(
                                  (date) =>
                                      DateFormat('dd MMM yyyy').format(date),
                                )
                                .join('\n'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.canEdit
                                  ? () {
                                      Navigator.pop(context);
                                      _showComplianceForm(existing: item);
                                    }
                                  : null,
                              icon: Icon(Icons.edit_outlined),
                              label: Text('Edit'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  item.status == 'Completed' || !widget.canEdit
                                  ? null
                                  : () async {
                                      await _controller.updateStatus(
                                        id: item.id,
                                        status: 'Completed',
                                        userUid: widget.currentUserUid,
                                      );

                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                              icon: Icon(Icons.check_circle_outline),
                              label: Text('Complete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Widget _detail(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.compliance.surfaceMuted,
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: context.compliance.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                color: context.compliance.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: context.compliance.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
