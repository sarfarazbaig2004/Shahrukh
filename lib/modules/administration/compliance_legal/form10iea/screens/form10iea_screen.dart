import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/compliance_design_system.dart';

import '../controllers/form10iea_controller.dart';
import '../models/form10iea_models.dart';
import '../repositories/form10iea_repository.dart';
import '../theme/form10iea_theme.dart';

class Form10IEAScreen extends StatefulWidget {
  const Form10IEAScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.canView,
    required this.canAnalyse,
    required this.canSave,
    required this.canManageRules,
  });

  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  final bool canView;
  final bool canAnalyse;
  final bool canSave;
  final bool canManageRules;

  @override
  State<Form10IEAScreen> createState() => _Form10IEAScreenState();
}

class _Form10IEAScreenState extends State<Form10IEAScreen>
    with SingleTickerProviderStateMixin {
  late final Form10IEARepository _repository;
  late final Form10IEAController _controller;
  late final TabController _tabController;

  final TextEditingController _ruleSearchController = TextEditingController();

  String _ruleSearch = '';

  @override
  void initState() {
    super.initState();

    _repository = Form10IEARepository(companyId: widget.companyId);

    _controller = Form10IEAController(repository: _repository)
      ..addListener(_refresh);

    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          _controller.setPrimaryTab(_tabController.index);
        }
      });
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

    _tabController.dispose();
    _ruleSearchController.dispose();
    super.dispose();
  }

  void _message(String value, {bool error = false}) {
    final theme = Form10IEATheme.resolve(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? theme.error : theme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canView) {
      return const Center(child: _PermissionDenied());
    }

    return StreamBuilder<List<Form10IEAScenarioRule>>(
      stream: _repository.watchRules(),
      builder: (context, ruleSnapshot) {
        final rules = ruleSnapshot.data ?? const <Form10IEAScenarioRule>[];

        return StreamBuilder<List<Form10IEALegalNote>>(
          stream: _repository.watchLegalNotes(),
          builder: (context, noteSnapshot) {
            final notes = noteSnapshot.data ?? const <Form10IEALegalNote>[];

            return ComplianceThemeShell(
              child: Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: SafeArea(
                  child: Column(
                    children: <Widget>[
                      _buildHeader(rules),
                      _buildKpis(rules),
                      _buildTabs(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            _buildSmartFinder(rules),
                            _buildMasterTable(rules),
                            _buildLegalNotes(notes),
                            _buildHowToUse(),
                          ],
                        ),
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

  Widget _buildHeader(List<Form10IEAScenarioRule> rules) {
    final theme = Form10IEATheme.resolve(context);
    final config = Form10IEAFinancialYearConfig.current;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;

          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Form 10-IEA & Regime Switching Reference',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                'Section 115BAC · Income-tax Act, 1961 · Rule 21AGA',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                config.flow,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

          final disclaimer = Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.surfaceMuted,
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'This tool provides a compliance reference based on the '
              'information entered. Final tax filing decisions should be '
              'verified by an authorised tax professional.',
              style: TextStyle(fontSize: 11, height: 1.4),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[title, const SizedBox(height: 12), disclaimer],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(child: title),
              const SizedBox(width: 18),
              disclaimer,
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpis(List<Form10IEAScenarioRule> rules) {
    final activeRules = rules.where((item) => item.active).toList();

    final exceptionCount = activeRules.where((item) {
      return item.resultStatus == Form10IEAResultStatus.needsReview ||
          item.resultStatus == Form10IEAResultStatus.optionRestricted ||
          item.resultStatus == Form10IEAResultStatus.conflictingInformation;
    }).length;

    final itrGeneralPosition = activeRules
        .where(
          (item) =>
              item.proposedItr == Form10IEAItrType.itr1 ||
              item.proposedItr == Form10IEAItrType.itr2,
        )
        .map((item) => item.formRequirement)
        .where((value) => value.isNotEmpty)
        .toSet();

    final values = <({String label, String value})>[
      (label: 'Scenario Master', value: '${activeRules.length}'),
      (
        label: 'Financial Years',
        value:
            '${Form10IEAFinancialYearConfig.current.previousYears.length + 1}',
      ),
      (
        label: 'ITR-1 & ITR-2',
        value: itrGeneralPosition.length == 1
            ? itrGeneralPosition.first
            : itrGeneralPosition.isEmpty
            ? 'Not configured'
            : 'Mixed',
      ),
      (label: 'Exception Scenarios', value: '$exceptionCount'),
    ];

    final theme = Form10IEATheme.resolve(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: theme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 900
              ? (constraints.maxWidth - 30) / 4
              : constraints.maxWidth >= 540
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: values.map((item) {
              return Container(
                width: width,
                constraints: const BoxConstraints(minHeight: 78),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.surfaceMuted,
                  border: Border.all(color: theme.border),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      item.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    final theme = Form10IEATheme.resolve(context);

    return Container(
      color: theme.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(9),
        ),
        labelColor: theme.accentForeground,
        unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const <Widget>[
          Tab(icon: Icon(Icons.explore_outlined), text: 'Smart Finder'),
          Tab(icon: Icon(Icons.table_chart_outlined), text: 'Master Table'),
          Tab(icon: Icon(Icons.menu_book_outlined), text: 'Legal Notes'),
          Tab(icon: Icon(Icons.help_outline), text: 'How to Use'),
        ],
      ),
    );
  }

  Widget _buildSmartFinder(List<Form10IEAScenarioRule> rules) {
    final theme = Form10IEATheme.resolve(context);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        _sectionCard(
          child: Column(
            children: <Widget>[
              _modeSelector<Form10IEAFinderMode>(
                values: Form10IEAFinderMode.values,
                selected: _controller.finderMode,
                label: (value) => value == Form10IEAFinderMode.uploadBased
                    ? 'ITR Form Upload Based'
                    : 'FAQs / Answer Based',
                icon: (value) => value == Form10IEAFinderMode.uploadBased
                    ? Icons.upload_file_outlined
                    : Icons.question_answer_outlined,
                onChanged: _controller.setFinderMode,
              ),
              const SizedBox(height: 12),
              _modeSelector<Form10IEAAssesseeMode>(
                values: Form10IEAAssesseeMode.values,
                selected: _controller.assesseeMode,
                label: (value) => value == Form10IEAAssesseeMode.single
                    ? 'Single Assessee'
                    : 'Multiple Assessee',
                icon: (value) => value == Form10IEAAssesseeMode.single
                    ? Icons.person_outline
                    : Icons.groups_outlined,
                onChanged: _controller.setAssesseeMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.success.withValues(alpha: 0.10),
            border: Border.all(color: theme.success),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.lock_outline, color: theme.success),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Private processing: Your ITR PDF is analysed on your '
                  'device. The raw document is not uploaded to the server.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (_controller.assesseeMode ==
            Form10IEAAssesseeMode.multiple) ...<Widget>[
          const SizedBox(height: 12),
          _buildAssesseeToolbar(),
        ],
        const SizedBox(height: 12),
        _buildActiveAssessee(rules),
      ],
    );
  }

  Widget _buildAssesseeToolbar() {
    return _sectionCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ...List<Widget>.generate(_controller.assessees.length, (index) {
            return ChoiceChip(
              selected: _controller.selectedAssesseeIndex == index,
              label: Text('Assessee ${index + 1}'),
              onSelected: (_) => _controller.selectAssessee(index),
            );
          }),
          OutlinedButton.icon(
            onPressed: _controller.addAssessee,
            icon: const Icon(Icons.add),
            label: const Text('Add Assessee'),
          ),
          OutlinedButton.icon(
            onPressed: () => _controller.duplicateAssessee(
              _controller.selectedAssesseeIndex,
            ),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Duplicate'),
          ),
          OutlinedButton.icon(
            onPressed: _controller.assessees.length > 1
                ? _confirmRemoveAssessee
                : null,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveAssessee() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Assessee'),
          content: const Text(
            'Remove this assessee and all entered assessment details?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _controller.removeAssessee(_controller.selectedAssesseeIndex);
    }
  }

  Widget _buildActiveAssessee(List<Form10IEAScenarioRule> rules) {
    final assesseeIndex = _controller.selectedAssesseeIndex;
    final assessee = _controller.assessees[assesseeIndex];

    return Column(
      children: <Widget>[
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _stepHeader(
                1,
                _controller.finderMode == Form10IEAFinderMode.uploadBased
                    ? 'Upload filed ITR form(s) and confirm the details'
                    : 'Answer the previous-year filing questions',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 760;

                  final cards = List<Widget>.generate(
                    assessee.previousYears.length,
                    (yearIndex) {
                      return _previousYearCard(
                        assesseeIndex: assesseeIndex,
                        yearIndex: yearIndex,
                        value: assessee.previousYears[yearIndex],
                      );
                    },
                  );

                  if (stack) {
                    return Column(
                      children: cards
                          .expand(
                            (item) => <Widget>[
                              item,
                              const SizedBox(height: 10),
                            ],
                          )
                          .toList(),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        cards
                            .expand(
                              (item) => <Widget>[
                                Expanded(child: item),
                                const SizedBox(width: 12),
                              ],
                            )
                            .toList()
                          ..removeLast(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _stepHeader(2, 'Select the ITR planned for FY 2025-26'),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 500 ? 2 : 4;
                  final itemWidth =
                      (constraints.maxWidth - ((columns - 1) * 10)) / columns;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: Form10IEAItrType.values.map((type) {
                      final selected = assessee.proposedItr == type;

                      return SizedBox(
                        width: itemWidth,
                        child: OutlinedButton(
                          onPressed: () => _controller.setProposedItr(
                            assesseeIndex: assesseeIndex,
                            value: type,
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: selected
                                ? Form10IEATheme.resolve(context).accent
                                : null,
                            foregroundColor: selected
                                ? Form10IEATheme.resolve(
                                    context,
                                  ).accentForeground
                                : null,
                          ),
                          child: Text(type.label),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Select the ITR you expect to file for '
                '${Form10IEAFinancialYearConfig.current.targetFinancialYear}, '
                '${Form10IEAFinancialYearConfig.current.targetAssessmentYear}. '
                'You can change it before analysis.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _stepHeader(3, 'Analyse and show your position'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    widget.canAnalyse &&
                        assessee.canAnalyse &&
                        !_controller.isAnalysing
                    ? () {
                        _controller.analyse(
                          assesseeIndex: assesseeIndex,
                          rules: rules,
                        );
                      }
                    : null,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(
                  'Analyse & Show '
                  '${Form10IEAFinancialYearConfig.current.targetFinancialYear} '
                  '(${Form10IEAFinancialYearConfig.current.targetAssessmentYear}) Position',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Form10IEATheme.resolve(context).accent,
                  foregroundColor: Form10IEATheme.resolve(
                    context,
                  ).accentForeground,
                ),
              ),
            ],
          ),
        ),
        if (_controller.results[assessee.temporaryId] case final result?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildResultCard(result, assesseeIndex, rules),
          ),
      ],
    );
  }

  Widget _previousYearCard({
    required int assesseeIndex,
    required int yearIndex,
    required PreviousYearFilingInput value,
  }) {
    final theme = Form10IEATheme.resolve(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceMuted,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'YEAR ${yearIndex + 1}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            '${value.financialYear} (${value.assessmentYear})',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            'Did you file an ITR for ${value.financialYear}?',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, label: Text('Yes, filed')),
              ButtonSegment<bool>(value: false, label: Text('No / Skipped')),
            ],
            selected: value.filed == null
                ? const <bool>{}
                : <bool>{value.filed!},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) {
              if (selection.isEmpty) {
                return;
              }

              _controller.updatePreviousYear(
                assesseeIndex: assesseeIndex,
                yearIndex: yearIndex,
                value: value.copyWith(
                  filed: selection.first,
                  confirmationStatus: selection.first
                      ? Form10IEAConfirmationStatus.pending
                      : Form10IEAConfirmationStatus.confirmed,
                ),
              );
            },
          ),
          if (value.filed == true) ...<Widget>[
            const SizedBox(height: 12),
            if (_controller.finderMode == Form10IEAFinderMode.uploadBased)
              _buildUploadArea(
                assesseeIndex: assesseeIndex,
                yearIndex: yearIndex,
                value: value,
              ),
            const SizedBox(height: 12),
            _manualConfirmationFields(
              assesseeIndex: assesseeIndex,
              yearIndex: yearIndex,
              value: value,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadArea({
    required int assesseeIndex,
    required int yearIndex,
    required PreviousYearFilingInput value,
  }) {
    final theme = Form10IEATheme.resolve(context);

    if (value.fileName.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.picture_as_pdf_outlined),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ITR PDF selected',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${(value.fileSize / 1024).toStringAsFixed(1)} KB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _extractionStatusLabel(value.extractionStatus),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (value.errorMessage.isNotEmpty)
                    Text(
                      value.errorMessage,
                      style: TextStyle(color: theme.error, fontSize: 10),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Replace file',
              onPressed: () => _pickPdf(assesseeIndex, yearIndex),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Remove file',
              onPressed: () => _controller.removePdf(
                assesseeIndex: assesseeIndex,
                yearIndex: yearIndex,
              ),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _pickPdf(assesseeIndex, yearIndex),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: theme.accent),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Column(
          children: <Widget>[
            Icon(Icons.upload_file_outlined),
            SizedBox(height: 6),
            Text(
              'Browse ITR PDF',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 3),
            Text(
              'PDF only · processed locally',
              style: TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdf(int assesseeIndex, int yearIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null) {
      _message('The selected PDF could not be read locally.', error: true);
      return;
    }

    if (bytes.length > 20 * 1024 * 1024) {
      _message(
        'The PDF exceeds the 20 MB local processing limit.',
        error: true,
      );
      return;
    }

    await _controller.extractPdf(
      assesseeIndex: assesseeIndex,
      yearIndex: yearIndex,
      bytes: bytes,
      fileName: 'Selected ITR PDF',
    );
  }

  Widget _manualConfirmationFields({
    required int assesseeIndex,
    required int yearIndex,
    required PreviousYearFilingInput value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ComplianceSelector<Form10IEAItrType>(
          label: 'Filed ITR type',
          valueLabel: value.itrType?.label ?? 'Not selected',
          options: Form10IEAItrType.values,
          labelBuilder: (type) => type.label,
          onSelected: (selected) {
            _controller.updatePreviousYear(
              assesseeIndex: assesseeIndex,
              yearIndex: yearIndex,
              value: value.copyWith(itrType: selected),
            );
          },
          icon: Icons.description_outlined,
          width: double.infinity,
        ),
        const SizedBox(height: 9),
        ComplianceSelector<String>(
          label: 'Selected tax regime',
          valueLabel: value.selectedRegime.isEmpty
              ? 'Select regime'
              : value.selectedRegime,
          options: const <String>['Old Regime', 'New Regime', 'Unknown'],
          labelBuilder: (item) =>
              item == 'Unknown' ? 'Unknown / Needs Review' : item,
          onSelected: (selected) {
            _controller.updatePreviousYear(
              assesseeIndex: assesseeIndex,
              yearIndex: yearIndex,
              value: value.copyWith(selectedRegime: selected),
            );
          },
          icon: Icons.compare_arrows_rounded,
          width: double.infinity,
        ),
        const SizedBox(height: 9),
        _booleanDropdown(
          label: 'Business/professional income',
          value: value.hasBusinessIncome,
          onChanged: (selected) {
            _controller.updatePreviousYear(
              assesseeIndex: assesseeIndex,
              yearIndex: yearIndex,
              value: value.copyWith(hasBusinessIncome: selected),
            );
          },
        ),
        const SizedBox(height: 9),
        _booleanDropdown(
          label: 'Form 10-IEA filed',
          value: value.form10ieaFiled,
          allowUnknown: true,
          onChanged: (selected) {
            _controller.updatePreviousYear(
              assesseeIndex: assesseeIndex,
              yearIndex: yearIndex,
              value: value.copyWith(form10ieaFiled: selected),
            );
          },
        ),
        if (value.panMasked.isNotEmpty) ...<Widget>[
          const SizedBox(height: 9),
          Text(
            'PAN: ${value.panMasked}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
        if (value.acknowledgementMasked.isNotEmpty)
          Text(
            'Acknowledgement: ${value.acknowledgementMasked}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        if (value.extractionConfidence > 0)
          Text(
            'Extraction confidence: '
            '${value.extractionConfidence.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11),
          ),
        const SizedBox(height: 9),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value:
              value.confirmationStatus == Form10IEAConfirmationStatus.confirmed,
          title: const Text(
            'I have checked and confirmed these details.',
            style: TextStyle(fontSize: 11),
          ),
          onChanged: (checked) {
            _controller.updatePreviousYear(
              assesseeIndex: assesseeIndex,
              yearIndex: yearIndex,
              value: value.copyWith(
                confirmationStatus: checked == true
                    ? Form10IEAConfirmationStatus.confirmed
                    : Form10IEAConfirmationStatus.pending,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _booleanDropdown({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
    bool allowUnknown = false,
  }) {
    final options = <String>['Yes', 'No', if (allowUnknown) 'Unknown'];
    final selected = value == null
        ? 'Unknown'
        : value
        ? 'Yes'
        : 'No';
    return ComplianceSelector<String>(
      label: label,
      valueLabel: selected,
      options: options,
      labelBuilder: (item) => item,
      onSelected: (item) {
        onChanged(
          item == 'Yes'
              ? true
              : item == 'No'
              ? false
              : null,
        );
      },
      icon: Icons.rule_outlined,
      width: double.infinity,
    );
  }

  Widget _buildResultCard(
    Form10IEAResult result,
    int assesseeIndex,
    List<Form10IEAScenarioRule> rules,
  ) {
    final theme = Form10IEATheme.resolve(context);
    final warning = result.needsProfessionalReview;

    return _sectionCard(
      borderColor: warning ? theme.warning : theme.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                warning ? Icons.warning_amber_rounded : Icons.verified_outlined,
                color: warning ? theme.warning : theme.success,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  result.status.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.conclusion,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
          ),
          if (result.reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Reasons used',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            ...result.reasons.map(
              (reason) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, size: 18),
                title: Text(reason),
              ),
            ),
          ],
          if (result.missingInformation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Missing or conflicting information',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            ...result.missingInformation.map(
              (item) => ListTile(
                dense: true,
                leading: Icon(
                  Icons.error_outline,
                  color: theme.warning,
                  size: 18,
                ),
                title: Text(item),
              ),
            ),
          ],
          if (result.legalReferences.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Legal references',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            ...result.legalReferences.map(
              (item) => ListTile(
                dense: true,
                leading: const Icon(Icons.menu_book_outlined, size: 18),
                title: Text(item),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Recommended action: ${result.recommendedAction}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (widget.canSave) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _controller.isSaving
                    ? null
                    : () async {
                        try {
                          final id = await _controller.saveAssessment(
                            assesseeIndex: assesseeIndex,
                            rules: rules,
                            userUid: widget.currentUserUid,
                          );

                          _message('Assessment saved: $id');
                        } catch (error) {
                          _message(
                            'Unable to save assessment: $error',
                            error: true,
                          );
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Assessment'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMasterTable(List<Form10IEAScenarioRule> rules) {
    final query = _ruleSearch.trim().toLowerCase();

    final filtered = rules.where((rule) {
      return query.isEmpty ||
          rule.id.toLowerCase().contains(query) ||
          rule.legalReference.toLowerCase().contains(query) ||
          rule.resultStatus.label.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _ruleSearchController,
                  onChanged: (value) {
                    setState(() => _ruleSearch = value);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search scenario master...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              if (widget.canManageRules) ...<Widget>[
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _showRuleDialog(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Rule'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No Form 10-IEA rules are configured.'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final rule = filtered[index];

                          return Card(
                            child: ListTile(
                              title: Text(
                                rule.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${rule.proposedItr?.label ?? 'Any ITR'} · '
                                '${rule.resultStatus.label}\n'
                                '${rule.legalReference}',
                              ),
                              trailing: widget.canManageRules
                                  ? IconButton(
                                      onPressed: () => _showRuleDialog(rule),
                                      icon: const Icon(Icons.edit),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Scenario ID')),
                          DataColumn(label: Text('Active')),
                          DataColumn(label: Text('Previous Regime')),
                          DataColumn(label: Text('Business Income')),
                          DataColumn(label: Text('Form 10-IEA')),
                          DataColumn(label: Text('Proposed ITR')),
                          DataColumn(label: Text('Result')),
                          DataColumn(label: Text('Legal Reference')),
                          DataColumn(label: Text('Version')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filtered.map((rule) {
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(Text(rule.id)),
                              DataCell(
                                Icon(
                                  rule.active
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 18,
                                ),
                              ),
                              DataCell(Text(rule.previousRegime)),
                              DataCell(
                                Text(
                                  rule.businessIncome == null
                                      ? 'Any'
                                      : rule.businessIncome!
                                      ? 'Yes'
                                      : 'No',
                                ),
                              ),
                              DataCell(
                                Text(
                                  rule.form10ieaFiled == null
                                      ? 'Any'
                                      : rule.form10ieaFiled!
                                      ? 'Filed'
                                      : 'Not filed',
                                ),
                              ),
                              DataCell(Text(rule.proposedItr?.label ?? 'Any')),
                              DataCell(Text(rule.resultStatus.label)),
                              DataCell(Text(rule.legalReference)),
                              DataCell(Text(rule.ruleVersion)),
                              DataCell(
                                widget.canManageRules
                                    ? IconButton(
                                        onPressed: () => _showRuleDialog(rule),
                                        icon: const Icon(Icons.edit_outlined),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showRuleDialog(Form10IEAScenarioRule? existing) async {
    if (!widget.canManageRules) {
      _message(
        'You do not have permission to manage legal rules.',
        error: true,
      );
      return;
    }

    final idController = TextEditingController(text: existing?.id ?? '');
    final referenceController = TextEditingController(
      text: existing?.legalReference ?? '',
    );
    final requirementController = TextEditingController(
      text: existing?.formRequirement ?? '',
    );
    final versionController = TextEditingController(
      text: existing?.ruleVersion ?? '1',
    );

    var active = existing?.active ?? true;
    var previousRegime = existing?.previousRegime ?? 'Any';
    var businessIncome = existing?.businessIncome;
    var formFiled = existing?.form10ieaFiled;
    var proposedItr = existing?.proposedItr;
    var resultStatus =
        existing?.resultStatus ?? Form10IEAResultStatus.needsReview;

    final saved = await showDialog<Form10IEAScenarioRule>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add Scenario Rule' : 'Edit Scenario Rule',
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: idController,
                        enabled: existing == null,
                        decoration: const InputDecoration(
                          labelText: 'Scenario ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        title: const Text('Active rule'),
                        onChanged: (value) {
                          setDialogState(() => active = value);
                        },
                      ),
                      ComplianceSelector<String>(
                        label: 'Previous regime',
                        valueLabel: previousRegime,
                        options: const <String>[
                          'Any',
                          'Old Regime',
                          'New Regime',
                        ],
                        labelBuilder: (item) => item,
                        onSelected: (value) {
                          setDialogState(() => previousRegime = value);
                        },
                        icon: Icons.compare_arrows_rounded,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 10),
                      _nullableBooleanSelector(
                        label: 'Business/professional income',
                        value: businessIncome,
                        onChanged: (value) {
                          setDialogState(() => businessIncome = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      _nullableBooleanSelector(
                        label: 'Form 10-IEA filed',
                        value: formFiled,
                        onChanged: (value) {
                          setDialogState(() => formFiled = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      ComplianceSelector<Form10IEAItrType?>(
                        label: 'Proposed ITR',
                        valueLabel: proposedItr?.label ?? 'Any',
                        options: <Form10IEAItrType?>[
                          null,
                          ...Form10IEAItrType.values,
                        ],
                        labelBuilder: (type) => type?.label ?? 'Any',
                        onSelected: (value) {
                          setDialogState(() => proposedItr = value);
                        },
                        icon: Icons.description_outlined,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 10),
                      ComplianceSelector<Form10IEAResultStatus>(
                        label: 'Result',
                        valueLabel: resultStatus.label,
                        options: Form10IEAResultStatus.values,
                        labelBuilder: (status) => status.label,
                        onSelected: (value) {
                          setDialogState(() => resultStatus = value);
                        },
                        icon: Icons.fact_check_outlined,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: requirementController,
                        decoration: const InputDecoration(
                          labelText: 'Form requirement',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Legal reference',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: versionController,
                        decoration: const InputDecoration(
                          labelText: 'Rule version',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (idController.text.trim().isEmpty) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      Form10IEAScenarioRule(
                        id: idController.text.trim(),
                        active: active,
                        assesseType: 'Individual',
                        previousRegime: previousRegime,
                        businessIncome: businessIncome,
                        form10ieaFiled: formFiled,
                        proposedItr: proposedItr,
                        resultStatus: resultStatus,
                        formRequirement: requirementController.text.trim(),
                        legalReference: referenceController.text.trim(),
                        effectiveFrom: Form10IEAFinancialYearConfig
                            .current
                            .targetFinancialYear,
                        effectiveTo: '',
                        ruleVersion: versionController.text.trim(),
                        updatedBy: widget.currentUserUid,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    idController.dispose();
    referenceController.dispose();
    requirementController.dispose();
    versionController.dispose();

    if (saved == null) {
      return;
    }

    try {
      await _repository.saveRule(rule: saved, userUid: widget.currentUserUid);

      _message('Scenario rule saved.');
    } catch (error) {
      _message('Unable to save rule: $error', error: true);
    }
  }

  Widget _nullableBooleanSelector({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    final selected = value == null
        ? 'Any'
        : value
        ? 'Yes'
        : 'No';
    return ComplianceSelector<String>(
      label: label,
      valueLabel: selected,
      options: const <String>['Any', 'Yes', 'No'],
      labelBuilder: (item) => item,
      onSelected: (item) {
        onChanged(
          item == 'Yes'
              ? true
              : item == 'No'
              ? false
              : null,
        );
      },
      icon: Icons.rule_outlined,
      width: double.infinity,
    );
  }

  Widget _buildLegalNotes(List<Form10IEALegalNote> notes) {
    if (notes.isEmpty) {
      return const Center(child: Text('No active legal notes are configured.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final note = notes[index];

        return _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                note.heading,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(note.summary, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _tag(note.reference),
                  _tag(
                    note.financialYears.isEmpty
                        ? 'No year configured'
                        : note.financialYears.join(', '),
                  ),
                  _tag('Version ${note.version}'),
                  _tag(
                    note.lastReviewedDate == null
                        ? 'Not reviewed'
                        : 'Reviewed '
                              '${DateFormat('dd MMM yyyy').format(note.lastReviewedDate!)}',
                  ),
                  _tag(
                    note.reviewedBy.isEmpty
                        ? 'Reviewer not configured'
                        : note.reviewedBy,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHowToUse() {
    const steps = <String>[
      'Choose upload-based or answer-based finder.',
      'Choose single or multiple assessee.',
      'Enter or upload previous-year details.',
      'Confirm all extracted information.',
      'Select the proposed ITR.',
      'Run analysis.',
      'Review the reasons and warnings.',
      'Obtain professional review where the result is uncertain.',
    ];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'How to use this reference',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...List<Widget>.generate(
                steps.length,
                (index) => ListTile(
                  leading: CircleAvatar(
                    radius: 15,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(steps[index]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Privacy, security and limitations',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• Raw ITR PDF bytes are processed locally and are not '
                'written to Firebase Storage, Firestore or application logs.\n'
                '• Only confirmed structured and masked values may be saved.\n'
                '• Extraction from password-protected or scanned PDFs may '
                'require manual entry.\n'
                '• Low-confidence, missing, unmatched or contradictory '
                'information returns Needs Professional Review.\n'
                '• This module is a compliance reference and not a substitute '
                'for professional tax advice.',
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child, Color? borderColor}) {
    final theme = Form10IEATheme.resolve(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: borderColor ?? theme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _stepHeader(int step, String label) {
    final theme = Form10IEATheme.resolve(context);

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Step $step',
            style: TextStyle(
              color: theme.accentForeground,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _modeSelector<T>({
    required List<T> values,
    required T selected,
    required String Function(T value) label,
    required IconData Function(T value) icon,
    required ValueChanged<T> onChanged,
  }) {
    final theme = Form10IEATheme.resolve(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / values.length;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final active = value == selected;

            return SizedBox(
              width: itemWidth,
              child: OutlinedButton.icon(
                onPressed: () => onChanged(value),
                icon: Icon(icon(value)),
                label: Text(
                  label(value),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: active ? theme.accent : null,
                  foregroundColor: active ? theme.accentForeground : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _tag(String value) {
    final theme = Form10IEATheme.resolve(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.surfaceMuted,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value.isEmpty ? 'Not configured' : value,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _extractionStatusLabel(Form10IEAExtractionStatus value) {
    switch (value) {
      case Form10IEAExtractionStatus.idle:
        return 'Not processed';
      case Form10IEAExtractionStatus.fileSelected:
        return 'File selected';
      case Form10IEAExtractionStatus.reading:
        return 'Reading locally...';
      case Form10IEAExtractionStatus.extracted:
        return 'Extracted';
      case Form10IEAExtractionStatus.awaitingConfirmation:
        return 'Awaiting confirmation';
      case Form10IEAExtractionStatus.confirmed:
        return 'Confirmed';
      case Form10IEAExtractionStatus.extractionFailed:
        return 'Manual review required';
      case Form10IEAExtractionStatus.needsReview:
        return 'Low confidence · review required';
    }
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.lock_outline, size: 52),
          SizedBox(height: 12),
          Text(
            'Permission denied',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 7),
          Text(
            'You do not have permission to open the '
            'Form 10-IEA reference module.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
