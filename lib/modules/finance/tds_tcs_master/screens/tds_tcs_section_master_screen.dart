import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_design_system.dart';
import '../models/tds_tcs_section_model.dart';
import '../repositories/tds_tcs_section_repository.dart';

class TdsTcsSectionMasterScreen extends StatefulWidget {
  TdsTcsSectionMasterScreen({
    super.key,
    required this.companyId,
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
    this.canExport = true,
  });

  final String companyId;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canExport;

  @override
  State<TdsTcsSectionMasterScreen> createState() =>
      _TdsTcsSectionMasterScreenState();
}

class _TdsTcsSectionMasterScreenState extends State<TdsTcsSectionMasterScreen> {
  static const List<String> _tabs = <String>[
    'Code',
    'Nature',
    'Deductor',
    'Old Sec',
    'New Sec',
    'Rate',
    'Threshold',
    'Payee',
    'Form',
  ];

  static const List<String> _forms = <String>[
    'Form 13',
    'Form 13A',
    'Form 15G',
    'Form 15H',
    'Form 16',
    'Form 16A',
    'Form 24Q',
    'Form 26Q',
    'Form 27Q',
    'Form 27EQ',
    'Form 26QB',
    'Form 26QC',
    'Form 26QD',
    'Form 27BA',
    'Form 27A',
    'Form 24G',
    'Form 3CD',
    'Form 10IEA',
    'Form 140',
    'Form 143',
    'Form 144',
  ];

  static const List<String> _categories = <String>['TDS', 'TCS', 'Both'];

  static const List<String> _statuses = <String>['Active', 'Inactive'];

  static const List<String> _residencies = <String>[
    'Resident',
    'Non Resident',
    'Both',
  ];

  static const List<String> _financialYears = <String>[
    'FY 2025–26',
    'FY 2026–27',
  ];

  late final TdsTcsSectionRepository _repository;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();

  String _selectedTab = 'Code';
  String _selectedFinancialYear = 'All';
  String _selectedCategory = 'Both';
  String _selectedStatus = 'All';
  String _selectedResidency = 'All';
  String _selectedDeductorCategory = 'All';

  String _search = '';
  bool _cardsView = false;
  bool _sortAscending = true;
  bool _busy = false;

  int _pageSize = 50;
  int _currentPage = 0;

  final Set<String> _selectedIds = <String>{};

  String get _userUid => FirebaseAuth.instance.currentUser?.uid ?? 'system';

  @override
  void initState() {
    super.initState();
    _repository = TdsTcsSectionRepository(companyId: widget.companyId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  String _tabValue(TdsTcsSectionModel record) {
    switch (_selectedTab) {
      case 'Nature':
        return record.nature;
      case 'Deductor':
        return record.deductor;
      case 'Old Sec':
        return record.oldSection;
      case 'New Sec':
        return record.newSection;
      case 'Rate':
        return record.rate.toString();
      case 'Threshold':
        return record.threshold.toString();
      case 'Payee':
        return record.payee;
      case 'Form':
        return record.applicableForms.join(' ');
      case 'Code':
      default:
        return record.code;
    }
  }

  List<TdsTcsSectionModel> _applyFilters(List<TdsTcsSectionModel> records) {
    final query = _search.trim().toLowerCase();

    final result = records.where((record) {
      final matchesFinancialYear =
          _selectedFinancialYear == 'All' ||
          record.financialYear == _selectedFinancialYear;

      final matchesCategory =
          _selectedCategory == 'Both' ||
          record.category == _selectedCategory ||
          record.category == 'Both';

      final matchesStatus =
          _selectedStatus == 'All' || record.status == _selectedStatus;

      final matchesResidency =
          _selectedResidency == 'All' ||
          record.residency == _selectedResidency ||
          record.residency == 'Both';

      final matchesDeductor =
          _selectedDeductorCategory == 'All' ||
          record.deductorCategory == _selectedDeductorCategory;

      final matchesSearch =
          query.isEmpty ||
          _tabValue(record).toLowerCase().contains(query) ||
          record.code.toLowerCase().contains(query) ||
          record.nature.toLowerCase().contains(query) ||
          record.oldSection.toLowerCase().contains(query) ||
          record.newSection.toLowerCase().contains(query) ||
          record.payee.toLowerCase().contains(query);

      return matchesFinancialYear &&
          matchesCategory &&
          matchesStatus &&
          matchesResidency &&
          matchesDeductor &&
          matchesSearch;
    }).toList();

    result.sort((first, second) {
      final left = _tabValue(first).toLowerCase();
      final right = _tabValue(second).toLowerCase();
      final comparison = left.compareTo(right);
      return _sortAscending ? comparison : -comparison;
    });

    return result;
  }

  List<TdsTcsSectionModel> _visibleRecords(List<TdsTcsSectionModel> records) {
    if (_pageSize == -1) {
      return records;
    }

    final start = _currentPage * _pageSize;

    if (start >= records.length) {
      return const <TdsTcsSectionModel>[];
    }

    final end = (start + _pageSize).clamp(0, records.length);
    return records.sublist(start, end);
  }

  int _pageCount(int total) {
    if (_pageSize == -1 || total == 0) {
      return 1;
    }

    return (total / _pageSize).ceil();
  }

  void _resetFilters() {
    setState(() {
      _selectedTab = 'Code';
      _selectedFinancialYear = 'All';
      _selectedCategory = 'Both';
      _selectedStatus = 'All';
      _selectedResidency = 'All';
      _selectedDeductorCategory = 'All';
      _sortAscending = true;
      _currentPage = 0;
      _search = '';
      _selectedIds.clear();
      _searchController.clear();
    });
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? context.compliance.danger
            : context.compliance.success,
      ),
    );
  }

  Future<void> _showSectionForm({TdsTcsSectionModel? existing}) async {
    final editing = existing != null;

    final codeController = TextEditingController(text: existing?.code ?? '');
    final natureController = TextEditingController(
      text: existing?.nature ?? '',
    );
    final deductorController = TextEditingController(
      text: existing?.deductor ?? '',
    );
    final deductorCategoryController = TextEditingController(
      text: existing?.deductorCategory ?? '',
    );
    final oldSectionController = TextEditingController(
      text: existing?.oldSection ?? '',
    );
    final newSectionController = TextEditingController(
      text: existing?.newSection ?? '',
    );
    final rateController = TextEditingController(
      text: existing == null ? '' : existing.rate.toString(),
    );
    final thresholdController = TextEditingController(
      text: existing == null ? '' : existing.threshold.toString(),
    );
    final payeeController = TextEditingController(text: existing?.payee ?? '');
    final legalNoteController = TextEditingController(
      text: existing?.legalNote ?? '',
    );

    String category = existing?.category ?? 'TDS';
    String residency = existing?.residency ?? 'Resident';
    String status = existing?.status ?? 'Active';
    String financialYear = existing?.financialYear ?? 'FY 2026–27';

    DateTime? effectiveDate = existing?.effectiveDate;
    final selectedForms = <String>{...?existing?.applicableForms};

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<TdsTcsSectionModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                editing ? 'Edit TDS/TCS Section' : 'Add TDS/TCS Section',
              ),
              content: SizedBox(
                width: 940,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _formText(
                          controller: codeController,
                          label: 'Section Code',
                          width: 210,
                        ),
                        _formDropdown(
                          label: 'Category',
                          value: category,
                          values: _categories,
                          width: 210,
                          onChanged: (value) {
                            setDialogState(() => category = value);
                          },
                        ),
                        _formDropdown(
                          label: 'Financial Year',
                          value: financialYear,
                          values: _financialYears,
                          width: 210,
                          onChanged: (value) {
                            setDialogState(() => financialYear = value);
                          },
                        ),
                        _formDropdown(
                          label: 'Status',
                          value: status,
                          values: _statuses,
                          width: 210,
                          onChanged: (value) {
                            setDialogState(() => status = value);
                          },
                        ),
                        _formText(
                          controller: natureController,
                          label: 'Nature of Payment',
                          width: 900,
                          maxLines: 2,
                        ),
                        _formText(
                          controller: deductorController,
                          label: 'Deductor',
                          width: 285,
                        ),
                        _formText(
                          controller: deductorCategoryController,
                          label: 'Deductor Category',
                          width: 285,
                        ),
                        _formDropdown(
                          label: 'Residency',
                          value: residency,
                          values: _residencies,
                          width: 285,
                          onChanged: (value) {
                            setDialogState(() => residency = value);
                          },
                        ),
                        _formText(
                          controller: oldSectionController,
                          label: 'Old Section',
                          width: 210,
                        ),
                        _formText(
                          controller: newSectionController,
                          label: 'New Section',
                          width: 210,
                        ),
                        _formText(
                          controller: rateController,
                          label: 'Rate (%)',
                          width: 210,
                          numeric: true,
                        ),
                        _formText(
                          controller: thresholdController,
                          label: 'Threshold Limit',
                          width: 210,
                          numeric: true,
                        ),
                        _formText(
                          controller: payeeController,
                          label: 'Payee',
                          width: 440,
                        ),
                        SizedBox(
                          width: 440,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: effectiveDate ?? DateTime.now(),
                              );

                              if (picked != null) {
                                setDialogState(() => effectiveDate = picked);
                              }
                            },
                            icon: Icon(Icons.calendar_today_outlined),
                            label: Text(
                              effectiveDate == null
                                  ? 'Select Effective Date'
                                  : 'Effective: ${DateFormat('dd MMM yyyy').format(effectiveDate!)}',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 900,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Applicable Forms',
                              border: OutlineInputBorder(),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _forms.map((form) {
                                return FilterChip(
                                  label: Text(form),
                                  selected: selectedForms.contains(form),
                                  onSelected: (selected) {
                                    setDialogState(() {
                                      if (selected) {
                                        selectedForms.add(form);
                                      } else {
                                        selectedForms.remove(form);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        _formText(
                          controller: legalNoteController,
                          label: 'Legal Notes',
                          width: 900,
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

                    Navigator.pop(
                      dialogContext,
                      TdsTcsSectionModel(
                        id: existing?.id ?? '',
                        code: codeController.text.trim(),
                        nature: natureController.text.trim(),
                        deductor: deductorController.text.trim(),
                        deductorCategory: deductorCategoryController.text
                            .trim(),
                        residency: residency,
                        oldSection: oldSectionController.text.trim(),
                        newSection: newSectionController.text.trim(),
                        rate: double.tryParse(rateController.text.trim()) ?? 0,
                        threshold:
                            double.tryParse(thresholdController.text.trim()) ??
                            0,
                        payee: payeeController.text.trim(),
                        applicableForms: selectedForms.toList()..sort(),
                        category: category,
                        financialYear: financialYear,
                        effectiveDate: effectiveDate,
                        legalNote: legalNoteController.text.trim(),
                        cbdtCirculars:
                            existing?.cbdtCirculars ?? const <String>[],
                        amendments: existing?.amendments ?? const <String>[],
                        examples: existing?.examples ?? const <String>[],
                        caseLaws: existing?.caseLaws ?? const <String>[],
                        notifications:
                            existing?.notifications ?? const <String>[],
                        historicalChanges:
                            existing?.historicalChanges ?? const <String>[],
                        status: status,
                        createdAt: existing?.createdAt,
                        updatedAt: existing?.updatedAt,
                        createdBy: existing?.createdBy ?? '',
                        updatedBy: existing?.updatedBy ?? '',
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

    codeController.dispose();
    natureController.dispose();
    deductorController.dispose();
    deductorCategoryController.dispose();
    oldSectionController.dispose();
    newSectionController.dispose();
    rateController.dispose();
    thresholdController.dispose();
    payeeController.dispose();
    legalNoteController.dispose();

    if (result == null || !mounted) {
      return;
    }

    setState(() => _busy = true);

    try {
      if (editing) {
        await _repository.update(section: result, userUid: _userUid);
        _showMessage('Section updated successfully.');
      } else {
        await _repository.create(section: result, userUid: _userUid);
        _showMessage('Section created successfully.');
      }
    } catch (error) {
      _showMessage('Unable to save section: $error', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _formText({
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
            return 'Enter a valid number';
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

  Widget _formDropdown({
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

  Future<void> _deleteSection(TdsTcsSectionModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete Section'),
          content: Text(
            'Delete section ${record.code}? This will archive the record.',
          ),
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

    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);

    try {
      await _repository.archive(id: record.id, userUid: _userUid);

      setState(() => _selectedIds.remove(record.id));
      _showMessage('Section archived successfully.');
    } catch (error) {
      _showMessage('Unable to delete section: $error', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) {
      return;
    }

    setState(() => _busy = true);

    try {
      await _repository.bulkArchive(ids: _selectedIds, userUid: _userUid);

      setState(() => _selectedIds.clear());
      _showMessage('Selected records archived.');
    } catch (error) {
      _showMessage('Bulk delete failed: $error', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _bulkUpdateStatus(String status) async {
    if (_selectedIds.isEmpty) {
      return;
    }

    setState(() => _busy = true);

    try {
      await _repository.bulkUpdateStatus(
        ids: _selectedIds,
        status: status,
        userUid: _userUid,
      );

      setState(() => _selectedIds.clear());
      _showMessage('Selected records updated.');
    } catch (error) {
      _showMessage('Bulk update failed: $error', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportCsv(List<TdsTcsSectionModel> records) async {
    final rows = <List<String>>[
      <String>[
        'Code',
        'Nature',
        'Deductor',
        'Deductor Category',
        'Residency',
        'Old Section',
        'New Section',
        'Rate',
        'Threshold',
        'Payee',
        'Applicable Forms',
        'Category',
        'Financial Year',
        'Effective Date',
        'Status',
      ],
      ...records.map((record) {
        return <String>[
          record.code,
          record.nature,
          record.deductor,
          record.deductorCategory,
          record.residency,
          record.oldSection,
          record.newSection,
          record.rate.toString(),
          record.threshold.toString(),
          record.payee,
          record.applicableForms.join('; '),
          record.category,
          record.financialYear,
          record.effectiveDate == null
              ? ''
              : DateFormat('yyyy-MM-dd').format(record.effectiveDate!),
          record.status,
        ];
      }),
    ];

    String escape(String value) => '"${value.replaceAll('"', '""')}"';

    final csv = rows.map((row) => row.map(escape).join(',')).join('\n');

    await FilePicker.platform.saveFile(
      dialogTitle: 'Export TDS/TCS Master',
      fileName: 'tds_tcs_section_master.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
  }

  Future<void> _printRecords(List<TdsTcsSectionModel> records) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          pw.Text(
            'TDS / TCS Section Code Master',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Code',
              'Nature',
              'Deductor',
              'Old',
              'New',
              'Rate',
              'Threshold',
              'Payee',
              'Forms',
              'Category',
              'Status',
            ],
            data: records.map((record) {
              return [
                record.code,
                record.nature,
                record.deductor,
                record.oldSection,
                record.newSection,
                '${record.rate}%',
                '₹${record.threshold}',
                record.payee,
                record.applicableForms.join(', '),
                record.category,
                record.status,
              ];
            }).toList(),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'TDS-TCS Section Master',
      onLayout: (_) => document.save(),
    );
  }

  void _showDetails(TdsTcsSectionModel record) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: context.compliance.scrim,
      transitionDuration: Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: context.compliance.surface,
            elevation: 12,
            child: SizedBox(
              width: 480,
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
                              '${record.code} – ${record.nature}',
                              style: TextStyle(
                                color: context.compliance.textPrimary,
                                fontSize: 18,
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
                          _detail('Old Section', record.oldSection),
                          _detail('New Section', record.newSection),
                          _detail('Deductor', record.deductor),
                          _detail('Deductor Category', record.deductorCategory),
                          _detail('Residency', record.residency),
                          _detail('Rate', '${record.rate}%'),
                          _detail('Threshold', '₹${record.threshold}'),
                          _detail('Payee', record.payee),
                          _detail(
                            'Applicable Forms',
                            record.applicableForms.join(', '),
                          ),
                          _detail('Category', record.category),
                          _detail('Financial Year', record.financialYear),
                          _detail(
                            'Effective Date',
                            record.effectiveDate == null
                                ? 'Not set'
                                : DateFormat(
                                    'dd MMM yyyy',
                                  ).format(record.effectiveDate!),
                          ),
                          _detail('Status', record.status),
                          _detail(
                            'Legal Notes',
                            record.legalNote.isEmpty
                                ? 'No legal notes'
                                : record.legalNote,
                          ),
                          _detail(
                            'CBDT Circulars',
                            record.cbdtCirculars.isEmpty
                                ? 'None'
                                : record.cbdtCirculars.join('\n'),
                          ),
                          _detail(
                            'Amendments',
                            record.amendments.isEmpty
                                ? 'None'
                                : record.amendments.join('\n'),
                          ),
                          _detail(
                            'Examples',
                            record.examples.isEmpty
                                ? 'None'
                                : record.examples.join('\n'),
                          ),
                          _detail(
                            'Case Laws',
                            record.caseLaws.isEmpty
                                ? 'None'
                                : record.caseLaws.join('\n'),
                          ),
                          _detail(
                            'Notifications',
                            record.notifications.isEmpty
                                ? 'None'
                                : record.notifications.join('\n'),
                          ),
                          _detail(
                            'Historical Changes',
                            record.historicalChanges.isEmpty
                                ? 'None'
                                : record.historicalChanges.join('\n'),
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
                                      _showSectionForm(existing: record);
                                    }
                                  : null,
                              icon: Icon(Icons.edit_outlined),
                              label: Text('Edit'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Close'),
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
          position: Tween<Offset>(
            begin: Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    );
  }

  Widget _detail(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
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
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                color: context.compliance.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.compliance.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TdsTcsSectionModel>>(
      stream: _repository.watchSections(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load TDS/TCS sections.\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.compliance.danger),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final allRecords = snapshot.data!;
        final deductorCategories = <String>{
          'All',
          ...allRecords
              .map((record) => record.deductorCategory)
              .where((value) => value.isNotEmpty),
        }.toList()..sort();

        if (!deductorCategories.contains(_selectedDeductorCategory)) {
          _selectedDeductorCategory = 'All';
        }

        final filteredRecords = _applyFilters(allRecords);
        final visibleRecords = _visibleRecords(filteredRecords);

        return Stack(
          children: [
            ComplianceSubpageShell(
              title: 'TDS / TCS Section Code Master',
              subtitle:
                  'Income Tax Act, 1961 and 2025 reference, rates, thresholds and forms',
              icon: Icons.account_balance_outlined,
              breadcrumbs: const <String>[
                'Finance',
                'Compliance & Legal',
                'TDS / TCS Section Codes',
              ],
              padding: EdgeInsets.zero,
              actions: <Widget>[
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                OutlinedButton.icon(
                  onPressed: widget.canExport
                      ? () => _exportCsv(filteredRecords)
                      : null,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.canExport
                      ? () => _printRecords(filteredRecords)
                      : null,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Print'),
                ),
                FilledButton.icon(
                  onPressed: widget.canCreate ? () => _showSectionForm() : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Section'),
                ),
              ],
              child: Column(
                children: [
                  _buildTabs(),
                  _buildFilters(deductorCategories),
                  _buildToolbar(filteredRecords),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: allRecords.isEmpty
                          ? _buildEmptyState()
                          : _cardsView
                          ? _buildCards(visibleRecords)
                          : _buildTable(visibleRecords),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: context.compliance.scrim.withValues(alpha: .45),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      color: context.compliance.surface,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs.map((tab) {
            final selected = _selectedTab == tab;

            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab),
                    if (selected) ...[
                      SizedBox(width: 5),
                      Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: context.compliance.surface,
                      ),
                    ],
                  ],
                ),
                selectedColor: context.compliance.primary,
                backgroundColor: context.compliance.surface,
                side: BorderSide(color: context.compliance.border),
                labelStyle: TextStyle(
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : context.compliance.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) {
                  setState(() {
                    if (_selectedTab == tab) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _selectedTab = tab;
                      _sortAscending = true;
                    }

                    _currentPage = 0;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilters(List<String> deductorCategories) {
    return Container(
      color: context.compliance.surface,
      padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _search = value;
                  _currentPage = 0;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by $_selectedTab...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _search = '';
                            _searchController.clear();
                          });
                        },
                        icon: Icon(Icons.close),
                      ),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _filterDropdown(
            label: 'Financial Year',
            value: _selectedFinancialYear,
            values: const ['All', 'FY 2025–26', 'FY 2026–27'],
            onChanged: (value) {
              setState(() {
                _selectedFinancialYear = value;
                _currentPage = 0;
              });
            },
          ),
          _filterDropdown(
            label: 'Type',
            value: _selectedCategory,
            values: const ['TDS', 'TCS', 'Both'],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                _currentPage = 0;
              });
            },
          ),
          _filterDropdown(
            label: 'Deductor Category',
            value: _selectedDeductorCategory,
            values: deductorCategories,
            onChanged: (value) {
              setState(() {
                _selectedDeductorCategory = value;
                _currentPage = 0;
              });
            },
          ),
          _filterDropdown(
            label: 'Residency',
            value: _selectedResidency,
            values: const ['All', 'Resident', 'Non Resident', 'Both'],
            onChanged: (value) {
              setState(() {
                _selectedResidency = value;
                _currentPage = 0;
              });
            },
          ),
          _filterDropdown(
            label: 'Status',
            value: _selectedStatus,
            values: const ['All', 'Active', 'Inactive'],
            onChanged: (value) {
              setState(() {
                _selectedStatus = value;
                _currentPage = 0;
              });
            },
          ),
          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: Icon(Icons.restart_alt),
            label: Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
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
      width: 180,
    );
  }

  Widget _buildToolbar(List<TdsTcsSectionModel> records) {
    final pages = _pageCount(records.length);

    if (_currentPage >= pages) {
      _currentPage = pages - 1;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: context.compliance.surfaceMuted,
        border: Border(
          top: BorderSide(color: context.compliance.border),
          bottom: BorderSide(color: context.compliance.border),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${records.length} records',
            style: TextStyle(
              color: context.compliance.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            SizedBox(width: 14),
            Text(
              '${_selectedIds.length} selected',
              style: TextStyle(
                color: context.compliance.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 8),
            OutlinedButton(
              onPressed: widget.canEdit
                  ? () => _bulkUpdateStatus('Active')
                  : null,
              child: Text('Mark Active'),
            ),
            SizedBox(width: 6),
            OutlinedButton(
              onPressed: widget.canEdit
                  ? () => _bulkUpdateStatus('Inactive')
                  : null,
              child: Text('Mark Inactive'),
            ),
            SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: widget.canDelete ? _bulkDelete : null,
              icon: Icon(
                Icons.delete_outline,
                color: context.compliance.danger,
              ),
              label: Text(
                'Bulk Delete',
                style: TextStyle(color: context.compliance.danger),
              ),
            ),
          ],
          Spacer(),
          ComplianceSelector<int>(
            label: 'Rows',
            valueLabel: _pageSize == -1 ? 'All' : '$_pageSize',
            options: const <int>[50, 100, 250, -1],
            labelBuilder: (value) => value == -1 ? 'All' : '$value',
            onSelected: (value) {
              setState(() {
                _pageSize = value;
                _currentPage = 0;
              });
            },
            icon: Icons.table_rows_outlined,
            width: 128,
          ),
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            icon: Icon(Icons.chevron_left),
          ),
          Text(
            'Page ${_currentPage + 1} of $pages',
            style: TextStyle(
              color: context.compliance.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: _currentPage < pages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: Icon(Icons.chevron_right),
          ),
          SizedBox(width: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.table_rows_outlined),
                label: Text('Table'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.view_module_outlined),
                label: Text('Cards'),
              ),
            ],
            selected: <bool>{_cardsView},
            onSelectionChanged: (selection) {
              setState(() => _cardsView = selection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: 460,
        padding: EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.compliance.surface,
          border: Border.all(color: context.compliance.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 52,
              color: context.compliance.primary,
            ),
            SizedBox(height: 16),
            Text(
              'No TDS/TCS sections found',
              style: TextStyle(
                color: context.compliance.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The table is connected to Firestore. Add the first section to create a live database record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.compliance.textSecondary),
            ),
            SizedBox(height: 18),
            FilledButton.icon(
              onPressed: widget.canCreate ? () => _showSectionForm() : null,
              icon: Icon(Icons.add),
              label: Text('Add First Section'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<TdsTcsSectionModel> records) {
    if (records.isEmpty) {
      return Center(child: Text('No matching records found.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: context.compliance.surface,
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 2100,
            child: Column(
              children: [
                _tableHeader(records),
                Expanded(
                  child: ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _tableRow(records[index], index);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(List<TdsTcsSectionModel> records) {
    final allSelected =
        records.isNotEmpty &&
        records.every((record) => _selectedIds.contains(record.id));

    return Container(
      color: context.compliance.primaryHover,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Checkbox(
              value: allSelected,
              fillColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.onPrimary,
              ),
              checkColor: context.compliance.primaryHover,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.addAll(records.map((record) => record.id));
                  } else {
                    _selectedIds.removeAll(records.map((record) => record.id));
                  }
                });
              },
            ),
          ),
          _header('CODE', 90),
          _header('NATURE OF PAYMENT', 290),
          _header('DEDUCTOR', 190),
          _header('OLD SECTION', 120),
          _header('NEW SECTION', 120),
          _header('RATE (%)', 95),
          _header('THRESHOLD', 130),
          _header('PAYEE', 160),
          _header('APPLICABLE FORM', 190),
          _header('CATEGORY', 100),
          _header('EFFECTIVE DATE', 125),
          _header('STATUS', 100),
          _header('ACTIONS', 145),
        ],
      ),
    );
  }

  Widget _header(String label, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: context.compliance.primaryHover),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.compliance.surface,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tableRow(TdsTcsSectionModel record, int index) {
    return InkWell(
      onTap: () => _showDetails(record),
      child: Container(
        color: index.isEven
            ? context.compliance.surface
            : context.compliance.surfaceMuted,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Checkbox(
                value: _selectedIds.contains(record.id),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(record.id);
                    } else {
                      _selectedIds.remove(record.id);
                    }
                  });
                },
              ),
            ),
            _cell(record.code, 90, strong: true),
            _cell(record.nature, 290),
            _cell(record.deductor, 190),
            _cell(record.oldSection, 120),
            _cell(record.newSection, 120),
            _cell('${record.rate}', 95),
            _cell('₹${record.threshold}', 130),
            _cell(record.payee, 160),
            _cell(record.applicableForms.join(', '), 190),
            _cell(record.category, 100),
            _cell(
              record.effectiveDate == null
                  ? ''
                  : DateFormat('dd MMM yyyy').format(record.effectiveDate!),
              125,
            ),
            SizedBox(
              width: 100,
              child: Center(child: _statusBadge(record.status)),
            ),
            SizedBox(
              width: 145,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'View',
                    onPressed: () => _showDetails(record),
                    icon: Icon(Icons.visibility_outlined, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: widget.canEdit
                        ? () => _showSectionForm(existing: record)
                        : null,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 19,
                      color: context.compliance.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.canDelete
                        ? () => _deleteSection(record)
                        : null,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: context.compliance.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String value, double width, {bool strong = false}) {
    return Tooltip(
      message: value,
      child: Container(
        width: width,
        constraints: BoxConstraints(minHeight: 62),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: context.compliance.border),
            bottom: BorderSide(color: context.compliance.border),
          ),
        ),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.compliance.textPrimary,
            fontSize: 11,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final active = status == 'Active';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? context.compliance.successSoft
            : context.compliance.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: active
              ? context.compliance.success
              : context.compliance.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCards(List<TdsTcsSectionModel> records) {
    if (records.isEmpty) {
      return Center(child: Text('No matching records found.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1350
            ? 4
            : constraints.maxWidth >= 950
            ? 3
            : constraints.maxWidth >= 650
            ? 2
            : 1;

        return GridView.builder(
          itemCount: records.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final record = records[index];

            return InkWell(
              onTap: () => _showDetails(record),
              borderRadius: BorderRadius.circular(12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.compliance.border),
                ),
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _selectedIds.contains(record.id),
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedIds.add(record.id);
                                } else {
                                  _selectedIds.remove(record.id);
                                }
                              });
                            },
                          ),
                          _smallBadge(record.code),
                          SizedBox(width: 7),
                          _smallBadge(record.category),
                          Spacer(),
                          _statusBadge(record.status),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        record.nature,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.compliance.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 13),
                      _cardLine('Old Section', record.oldSection),
                      _cardLine('New Section', record.newSection),
                      _cardLine('Rate', '${record.rate}%'),
                      _cardLine('Threshold', '₹${record.threshold}'),
                      _cardLine('Forms', record.applicableForms.join(', ')),
                      Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showDetails(record),
                              child: Text('View'),
                            ),
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.canEdit
                                  ? () => _showSectionForm(existing: record)
                                  : null,
                              child: Text('Edit'),
                            ),
                          ),
                          SizedBox(width: 7),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: widget.canDelete
                                ? () => _deleteSection(record)
                                : null,
                            icon: Icon(
                              Icons.delete_outline,
                              color: context.compliance.danger,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _smallBadge(String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.compliance.primarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: context.compliance.primaryHover,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _cardLine(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
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
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.compliance.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
