import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:QUIK/core/theme/theme_controller.dart';
import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_design_system.dart';

import '../controllers/income_tax_controller.dart';
import '../models/income_tax_models.dart';
import '../rules/income_tax_rule_registry.dart';
import '../rules/income_tax_rules.dart';
import '../services/income_tax_export_service.dart';
import 'widgets/tax_ui.dart';

typedef IncomeTaxFileHandler =
    Future<void> Function(String filename, Uint8List bytes, String mimeType);

enum _TaxTab {
  calculator('Calculator', Icons.calculate_outlined),
  salary('Salary Income', Icons.badge_outlined),
  houseProperty('House Property', Icons.home_work_outlined),
  business('Business / Profession', Icons.business_center_outlined),
  capitalGains('Capital Gains', Icons.trending_up_outlined),
  otherSources('Other Sources', Icons.account_balance_outlined),
  deductions('Deductions', Icons.savings_outlined),
  advanceTax('Advance Tax', Icons.calendar_month_outlined),
  slabs('Tax Slabs', Icons.table_chart_outlined),
  comparison('Tax Comparison', Icons.compare_arrows_outlined),
  planning('Tax Planning', Icons.lightbulb_outline),
  itrDueDates('ITR Due Dates', Icons.event_available_outlined),
  reports('Reports', Icons.description_outlined),
  history('History', Icons.history),
  settings('Settings', Icons.settings_outlined);

  const _TaxTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class IncomeTaxCalculatorScreen extends StatefulWidget {
  IncomeTaxCalculatorScreen({
    super.key,
    required this.controller,
    this.onToggleTheme,
    this.onFileReady,
    this.canSave = true,
    this.canExport = true,
    this.canDelete = true,
  });

  final IncomeTaxController controller;
  final VoidCallback? onToggleTheme;
  final IncomeTaxFileHandler? onFileReady;
  final bool canSave;
  final bool canExport;
  final bool canDelete;

  @override
  State<IncomeTaxCalculatorScreen> createState() =>
      _IncomeTaxCalculatorScreenState();
}

class _IncomeTaxCalculatorScreenState extends State<IncomeTaxCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _exportService = IncomeTaxExportService();
  final _rulesRegistry = IncomeTaxRuleRegistry();
  final _searchController = TextEditingController();
  _TaxTab _tab = _TaxTab.calculator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
          backgroundColor: context.compliance.canvas,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(controller),
                _buildTabs(),
                if (controller.error != null)
                  MaterialBanner(
                    content: Text(controller.error!),
                    leading: Icon(
                      Icons.error_outline,
                      color: context.compliance.danger,
                    ),
                    actions: [
                      TextButton(
                        onPressed: controller.clearError,
                        child: Text('Dismiss'),
                      ),
                    ],
                  ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 180),
                        child: KeyedSubtree(
                          key: ValueKey(_tab),
                          child: _buildTabBody(controller),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(IncomeTaxController controller) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 1050;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Income Tax Calculator',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Income Tax Planning & Computation System',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final yearSelector = ComplianceSelector<FinancialYear>(
      label: 'Financial Year',
      valueLabel: controller.draft.financialYear.label,
      options: FinancialYear.values,
      labelBuilder: (year) => year.label,
      onSelected: controller.setFinancialYear,
      icon: Icons.calendar_month_outlined,
      searchHint: 'Search financial year',
      width: 190,
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        yearSelector,
        Chip(
          avatar: Icon(Icons.auto_awesome, size: 16),
          label: Text(controller.draft.financialYear.statutoryYearLabel),
        ),
        IconButton.filledTonal(
          tooltip: 'Search history',
          onPressed: () => setState(() => _tab = _TaxTab.history),
          icon: Icon(Icons.search),
        ),
        if (widget.canSave)
          FilledButton.icon(
            onPressed: controller.isSaving ? null : () => _save(false),
            icon: controller.isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.save_outlined),
            label: Text('Save Calculation'),
          ),
        if (widget.canSave)
          OutlinedButton.icon(
            onPressed: controller.isSaving ? null : () => _save(true),
            icon: Icon(Icons.drafts_outlined),
            label: Text('Save as Draft'),
          ),
        if (widget.canExport)
          IconButton.filledTonal(
            tooltip: 'Export PDF',
            onPressed: () => _export('pdf'),
            icon: Icon(Icons.picture_as_pdf_outlined),
          ),
        if (widget.canExport)
          IconButton.filledTonal(
            tooltip: 'Export Excel',
            onPressed: () => _export('excel'),
            icon: Icon(Icons.grid_on_outlined),
          ),
        if (widget.canExport)
          IconButton.filledTonal(
            tooltip: 'Print',
            onPressed: _print,
            icon: Icon(Icons.print_outlined),
          ),
        IconButton.filledTonal(
          tooltip: 'Reset',
          onPressed: () => _handleHeaderAction('reset'),
          icon: Icon(Icons.restart_alt),
        ),
        if (widget.onToggleTheme != null)
          IconButton.filledTonal(
            tooltip: 'Toggle Dark Mode',
            onPressed:
                widget.onToggleTheme ??
                () => QuikThemeController.instance.toggle(context),
            icon: Icon(Icons.dark_mode_outlined),
          ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          onSelected: _handleHeaderAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'load',
              child: Text('Load Previous Calculation'),
            ),
            if (widget.canExport) ...const [
              PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              PopupMenuItem(value: 'excel', child: Text('Export Excel')),
              PopupMenuItem(value: 'print', child: Text('Print')),
            ],
            PopupMenuDivider(),
            PopupMenuItem(value: 'reset', child: Text('Reset')),
            if (widget.onToggleTheme != null)
              PopupMenuItem(value: 'theme', child: Text('Toggle Dark Mode')),
          ],
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_horiz),
                SizedBox(width: 6),
                Text('More'),
              ],
            ),
          ),
        ),
      ],
    );

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, SizedBox(height: 16), actions],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                SizedBox(width: 20),
                Flexible(flex: 3, child: actions),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _TaxTab.values.map((tab) {
            final selected = tab == _tab;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                avatar: Icon(
                  tab.icon,
                  size: 17,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(tab.label),
                selectedColor: context.compliance.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _tab = tab),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabBody(IncomeTaxController controller) => switch (_tab) {
    _TaxTab.calculator => _buildCalculator(controller),
    _TaxTab.salary => _buildSalary(controller),
    _TaxTab.houseProperty => _buildHouseProperty(controller),
    _TaxTab.business => _buildBusiness(controller),
    _TaxTab.capitalGains => _buildCapitalGains(controller),
    _TaxTab.otherSources => _buildOtherSources(controller),
    _TaxTab.deductions => _buildDeductions(controller),
    _TaxTab.advanceTax => _buildAdvanceTax(controller),
    _TaxTab.slabs => _buildSlabs(controller),
    _TaxTab.comparison => _buildComparison(controller),
    _TaxTab.planning => _buildPlanning(controller),
    _TaxTab.itrDueDates => _buildItrDueDates(controller),
    _TaxTab.reports => _buildReports(controller),
    _TaxTab.history => _buildHistory(controller),
    _TaxTab.settings => _buildSettings(controller),
  };

  Widget _buildCalculator(IncomeTaxController controller) {
    final profile = controller.draft.profile;
    final yearEnd = controller.draft.financialYear == FinancialYear.fy2025_26
        ? DateTime(2026, 3, 31)
        : DateTime(2027, 3, 31);
    return Column(
      children: [
        TaxCard(
          title: 'Taxpayer Information',
          subtitle: 'Identity, status and taxpayer classification',
          child: ResponsiveFieldGrid(
            children: [
              TextValueField(
                label: 'Taxpayer Name',
                value: profile.name,
                textCapitalization: TextCapitalization.words,
                onChanged: (value) =>
                    controller.setProfile(profile.copyWith(name: value)),
              ),
              TextValueField(
                label: 'PAN',
                value: profile.pan,
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  return RegExp(
                        r'^[A-Z]{5}[0-9]{4}[A-Z]$',
                      ).hasMatch(value.toUpperCase())
                      ? null
                      : 'Enter a valid PAN';
                },
                onChanged: (value) => controller.setProfile(
                  profile.copyWith(pan: value.toUpperCase()),
                ),
              ),
              TextValueField(
                label: 'Aadhaar Number',
                value: profile.aadhaar,
                maxLength: 12,
                onChanged: (value) =>
                    controller.setProfile(profile.copyWith(aadhaar: value)),
              ),
              DateValueField(
                label: 'Date of Birth',
                value: profile.dob,
                lastDate: DateTime.now(),
                onChanged: (value) =>
                    controller.setProfile(profile.copyWith(dob: value)),
              ),
              InputDecorator(
                decoration: InputDecoration(labelText: 'Age (Auto)'),
                child: Text(
                  profile.dob == null ? '-' : '${profile.ageOn(yearEnd)} years',
                ),
              ),
              EnumDropdown<ResidentialStatus>(
                label: 'Residential Status',
                value: profile.residentialStatus,
                values: ResidentialStatus.values,
                labelBuilder: (value) => switch (value) {
                  ResidentialStatus.resident => 'Resident',
                  ResidentialStatus.rnOR =>
                    'Resident but Not Ordinarily Resident',
                  ResidentialStatus.nonResident => 'Non Resident',
                },
                onChanged: (value) => controller.setProfile(
                  profile.copyWith(residentialStatus: value),
                ),
              ),
              EnumDropdown<TaxpayerCategory>(
                label: 'Category',
                value: profile.category,
                values: TaxpayerCategory.values,
                onChanged: (value) =>
                    controller.setProfile(profile.copyWith(category: value)),
              ),
              EnumDropdown<Gender>(
                label: 'Gender',
                value: profile.gender,
                values: Gender.values,
                onChanged: (value) =>
                    controller.setProfile(profile.copyWith(gender: value)),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        _summaryStrip(controller),
        SizedBox(height: 18),
        _comparisonColumns(controller),
      ],
    );
  }

  Widget _summaryStrip(IncomeTaxController controller) {
    final comparison = controller.comparison;
    final recommended = comparison.recommendedRegime == TaxRegime.oldRegime
        ? 'Old Regime'
        : 'New Regime';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 900
            ? constraints.maxWidth
            : (constraints.maxWidth - 48) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _summaryMetric(
              'Recommended Regime',
              recommended,
              Icons.verified_outlined,
              context.compliance.success,
              width,
            ),
            _summaryMetric(
              'Tax Saving',
              formatMoney(comparison.taxSaving),
              Icons.savings_outlined,
              context.compliance.success,
              width,
            ),
            _summaryMetric(
              'Suggested ITR',
              comparison.suggestedItr,
              Icons.description_outlined,
              context.compliance.primary,
              width,
            ),
            _summaryMetric(
              'Assessment / Tax Year',
              controller.draft.financialYear.statutoryYearLabel,
              Icons.calendar_today_outlined,
              context.compliance.warning,
              width,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryMetric(
    String label,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: TaxCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  SizedBox(height: 3),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
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

  Widget _buildSalary(IncomeTaxController controller) {
    final i = controller.draft.income;
    return TaxCard(
      title: 'Salary Income',
      subtitle:
          'Enter annual values in Indian rupees. Exempt portions are separately captured.',
      child: ResponsiveFieldGrid(
        children: [
          MoneyField(
            label: 'Basic Salary',
            value: i.basicSalary,
            onChanged: (v) => controller.setIncome(i.copyWith(basicSalary: v)),
          ),
          MoneyField(
            label: 'HRA',
            value: i.hra,
            onChanged: (v) => controller.setIncome(i.copyWith(hra: v)),
          ),
          MoneyField(
            label: 'HRA Exemption',
            value: i.hraExemption,
            onChanged: (v) => controller.setIncome(i.copyWith(hraExemption: v)),
          ),
          MoneyField(
            label: 'LTA',
            value: i.lta,
            onChanged: (v) => controller.setIncome(i.copyWith(lta: v)),
          ),
          MoneyField(
            label: 'LTA Exemption',
            value: i.ltaExemption,
            onChanged: (v) => controller.setIncome(i.copyWith(ltaExemption: v)),
          ),
          MoneyField(
            label: 'Bonus',
            value: i.bonus,
            onChanged: (v) => controller.setIncome(i.copyWith(bonus: v)),
          ),
          MoneyField(
            label: 'Commission',
            value: i.commission,
            onChanged: (v) => controller.setIncome(i.copyWith(commission: v)),
          ),
          MoneyField(
            label: 'Gratuity',
            value: i.gratuity,
            onChanged: (v) => controller.setIncome(i.copyWith(gratuity: v)),
          ),
          MoneyField(
            label: 'Gratuity Exemption',
            value: i.gratuityExemption,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(gratuityExemption: v)),
          ),
          MoneyField(
            label: 'Leave Encashment',
            value: i.leaveEncashment,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(leaveEncashment: v)),
          ),
          MoneyField(
            label: 'Leave Encashment Exemption',
            value: i.leaveEncashmentExemption,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(leaveEncashmentExemption: v)),
          ),
          MoneyField(
            label: 'Perquisites',
            value: i.perquisites,
            onChanged: (v) => controller.setIncome(i.copyWith(perquisites: v)),
          ),
          MoneyField(
            label: 'Employer PF / Taxable Contribution',
            value: i.employerPf,
            onChanged: (v) => controller.setIncome(i.copyWith(employerPf: v)),
          ),
          MoneyField(
            label: 'Professional Tax',
            value: i.professionalTax,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(professionalTax: v)),
          ),
          MoneyField(
            label: 'Other Allowances',
            value: i.otherAllowances,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(otherAllowances: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseProperty(IncomeTaxController controller) {
    final i = controller.draft.income;
    return TaxCard(
      title: 'Income from House Property',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Self Occupied'),
                icon: Icon(Icons.home_outlined),
              ),
              ButtonSegment(
                value: false,
                label: Text('Let Out'),
                icon: Icon(Icons.key_outlined),
              ),
            ],
            selected: {i.isSelfOccupied},
            onSelectionChanged: (value) =>
                controller.setIncome(i.copyWith(isSelfOccupied: value.first)),
          ),
          SizedBox(height: 18),
          ResponsiveFieldGrid(
            children: [
              MoneyField(
                label: 'Gross Annual / Rental Value',
                value: i.housePropertyAnnualValue,
                enabled: !i.isSelfOccupied,
                onChanged: (v) => controller.setIncome(
                  i.copyWith(housePropertyAnnualValue: v),
                ),
              ),
              MoneyField(
                label: 'Municipal Tax',
                value: i.municipalTax,
                onChanged: (v) =>
                    controller.setIncome(i.copyWith(municipalTax: v)),
              ),
              MoneyField(
                label: 'Interest on Home Loan',
                value: i.homeLoanInterest,
                onChanged: (v) =>
                    controller.setIncome(i.copyWith(homeLoanInterest: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusiness(IncomeTaxController controller) {
    final i = controller.draft.income;
    return TaxCard(
      title: 'Business / Profession Income',
      subtitle: 'Use net taxable income after allowable business expenditure.',
      child: ResponsiveFieldGrid(
        children: [
          MoneyField(
            label: 'Business Income',
            value: i.businessIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(businessIncome: v)),
          ),
          MoneyField(
            label: 'Presumptive Income',
            value: i.presumptiveIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(presumptiveIncome: v)),
          ),
          MoneyField(
            label: 'Professional Income',
            value: i.professionalIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(professionalIncome: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildCapitalGains(IncomeTaxController controller) {
    final i = controller.draft.income;
    return Column(
      children: [
        TaxCard(
          title: 'Capital Gains',
          subtitle:
              'Separate special-rate gains from gains taxable at slab rates.',
          child: ResponsiveFieldGrid(
            children: [
              MoneyField(
                label: 'STCG – Equity u/s 111A',
                value: i.stcg111A,
                onChanged: (v) => controller.setIncome(i.copyWith(stcg111A: v)),
              ),
              MoneyField(
                label: 'STCG – Property / Debt / Other',
                value: i.stcgOther,
                onChanged: (v) =>
                    controller.setIncome(i.copyWith(stcgOther: v)),
              ),
              MoneyField(
                label: 'LTCG – Equity / MF u/s 112A',
                value: i.ltcg112A,
                onChanged: (v) => controller.setIncome(i.copyWith(ltcg112A: v)),
              ),
              MoneyField(
                label: 'LTCG – Property / Debt / Other',
                value: i.ltcgOther,
                onChanged: (v) =>
                    controller.setIncome(i.copyWith(ltcgOther: v)),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        _warningCard(
          'Asset acquisition date, grandfathering, indexation options, exemptions under sections 54 series and transaction-specific rates must be reviewed before finalising the return.',
        ),
      ],
    );
  }

  Widget _buildOtherSources(IncomeTaxController controller) {
    final i = controller.draft.income;
    return TaxCard(
      title: 'Income from Other Sources',
      child: ResponsiveFieldGrid(
        children: [
          MoneyField(
            label: 'Interest',
            value: i.interestIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(interestIncome: v)),
          ),
          MoneyField(
            label: 'Dividend',
            value: i.dividendIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(dividendIncome: v)),
          ),
          MoneyField(
            label: 'Lottery / Game Winnings',
            value: i.lotteryIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(lotteryIncome: v)),
          ),
          MoneyField(
            label: 'Taxable Gifts',
            value: i.giftsIncome,
            onChanged: (v) => controller.setIncome(i.copyWith(giftsIncome: v)),
          ),
          MoneyField(
            label: 'Foreign Income',
            value: i.foreignIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(foreignIncome: v)),
          ),
          MoneyField(
            label: 'Agricultural Income',
            value: i.agriculturalIncome,
            onChanged: (v) =>
                controller.setIncome(i.copyWith(agriculturalIncome: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductions(IncomeTaxController controller) {
    final d = controller.draft.deductions;
    return Column(
      children: [
        TaxCard(
          title: 'Chapter VI-A Deductions',
          subtitle:
              'Enter the legally allowable claim after section-specific percentage, qualifying-limit and document checks. The engine applies regime eligibility and shared statutory caps.',
          child: ResponsiveFieldGrid(
            children: [
              MoneyField(
                label: '80C – Direct Total',
                value: d.section80CManual,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80CManual: v)),
              ),
              MoneyField(
                label: '80CCC',
                value: d.section80CCC,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80CCC: v)),
              ),
              MoneyField(
                label: '80CCD(1)',
                value: d.section80CCD1,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80CCD1: v)),
              ),
              MoneyField(
                label: '80CCD(1B)',
                value: d.section80CCD1B,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80CCD1B: v)),
              ),
              MoneyField(
                label: '80CCD(2) – Employer NPS',
                value: d.section80CCD2,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80CCD2: v)),
              ),
              MoneyField(
                label: '80D',
                value: d.section80D,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80D: v)),
              ),
              MoneyField(
                label: '80DD',
                value: d.section80DD,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80DD: v)),
              ),
              MoneyField(
                label: '80DDB',
                value: d.section80DDB,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80DDB: v)),
              ),
              MoneyField(
                label: '80E',
                value: d.section80E,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80E: v)),
              ),
              MoneyField(
                label: '80EE',
                value: d.section80EE,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80EE: v)),
              ),
              MoneyField(
                label: '80EEA',
                value: d.section80EEA,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80EEA: v)),
              ),
              MoneyField(
                label: '80EEB',
                value: d.section80EEB,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80EEB: v)),
              ),
              MoneyField(
                label: '80G',
                value: d.section80G,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80G: v)),
              ),
              MoneyField(
                label: '80GG',
                value: d.section80GG,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80GG: v)),
              ),
              MoneyField(
                label: '80GGA',
                value: d.section80GGA,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80GGA: v)),
              ),
              MoneyField(
                label: '80GGC',
                value: d.section80GGC,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80GGC: v)),
              ),
              MoneyField(
                label: '80TTA',
                value: d.section80TTA,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80TTA: v)),
              ),
              MoneyField(
                label: '80TTB',
                value: d.section80TTB,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80TTB: v)),
              ),
              MoneyField(
                label: '80U',
                value: d.section80U,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(section80U: v)),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        TaxCard(
          title: '80C / Investment Break-up',
          subtitle:
              'The higher of direct 80C total or component total is used, avoiding double counting.',
          child: ResponsiveFieldGrid(
            children: [
              MoneyField(
                label: 'NPS',
                value: d.nps,
                onChanged: (v) => controller.setDeductions(d.copyWith(nps: v)),
              ),
              MoneyField(
                label: 'EPF',
                value: d.epf,
                onChanged: (v) => controller.setDeductions(d.copyWith(epf: v)),
              ),
              MoneyField(
                label: 'PPF',
                value: d.ppf,
                onChanged: (v) => controller.setDeductions(d.copyWith(ppf: v)),
              ),
              MoneyField(
                label: 'ELSS',
                value: d.elss,
                onChanged: (v) => controller.setDeductions(d.copyWith(elss: v)),
              ),
              MoneyField(
                label: 'NSC',
                value: d.nsc,
                onChanged: (v) => controller.setDeductions(d.copyWith(nsc: v)),
              ),
              MoneyField(
                label: 'Life Insurance',
                value: d.lifeInsurance,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(lifeInsurance: v)),
              ),
              MoneyField(
                label: 'Home Loan Principal',
                value: d.homeLoanPrincipal,
                onChanged: (v) =>
                    controller.setDeductions(d.copyWith(homeLoanPrincipal: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvanceTax(IncomeTaxController controller) {
    final p = controller.draft.payments;
    final result =
        controller.comparison.recommendedRegime == TaxRegime.oldRegime
        ? controller.comparison.oldRegime
        : controller.comparison.newRegime;
    final schedule = result.advanceTaxSchedule;
    return Column(
      children: [
        TaxCard(
          title: 'Taxes Paid & Advance Tax',
          child: ResponsiveFieldGrid(
            children: [
              MoneyField(
                label: 'TDS / TCS',
                value: p.tdsTcs,
                onChanged: (v) => controller.setPayments(p.copyWith(tdsTcs: v)),
              ),
              MoneyField(
                label: 'Paid by 15 June',
                value: p.advanceTaxJune,
                onChanged: (v) =>
                    controller.setPayments(p.copyWith(advanceTaxJune: v)),
              ),
              MoneyField(
                label: 'Paid by 15 September',
                value: p.advanceTaxSeptember,
                onChanged: (v) =>
                    controller.setPayments(p.copyWith(advanceTaxSeptember: v)),
              ),
              MoneyField(
                label: 'Paid by 15 December',
                value: p.advanceTaxDecember,
                onChanged: (v) =>
                    controller.setPayments(p.copyWith(advanceTaxDecember: v)),
              ),
              MoneyField(
                label: 'Paid by 15 March',
                value: p.advanceTaxMarch,
                onChanged: (v) =>
                    controller.setPayments(p.copyWith(advanceTaxMarch: v)),
              ),
              MoneyField(
                label: 'Self Assessment Tax',
                value: p.selfAssessmentTax,
                onChanged: (v) =>
                    controller.setPayments(p.copyWith(selfAssessmentTax: v)),
              ),
              DateValueField(
                label: 'Return Due Date',
                value: p.returnDueDate,
                onChanged: (v) =>
                    controller.setPayments(p.copyWith(returnDueDate: v)),
              ),
              DateValueField(
                label: 'Return Filing Date',
                value: p.returnFilingDate,
                onChanged: (v) =>
                    controller.setPayments(p.copyWith(returnFilingDate: v)),
              ),
              DateValueField(
                label: 'Self Assessment Payment Date',
                value: p.selfAssessmentPaymentDate,
                onChanged: (v) => controller.setPayments(
                  p.copyWith(selfAssessmentPaymentDate: v),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _advanceMetric('15 June', schedule.june15),
              _advanceMetric('15 September', schedule.september15),
              _advanceMetric('15 December', schedule.december15),
              _advanceMetric('15 March', schedule.march15),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: constraints.maxWidth < 800
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 48) / 4,
                      child: card,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        SizedBox(height: 18),
        TaxCard(
          title: 'Interest Computation',
          child: Column(
            children: [
              MetricRow(
                label: 'Interest u/s 234A',
                value: formatMoney(result.interest234A),
              ),
              MetricRow(
                label: 'Interest u/s 234B',
                value: formatMoney(result.interest234B),
              ),
              MetricRow(
                label: 'Interest u/s 234C',
                value: formatMoney(result.interest234C),
              ),
              Divider(),
              MetricRow(
                label: 'Self Assessment Payable',
                value: formatMoney(result.payable),
                valueColor: result.payable > 0
                    ? context.compliance.danger
                    : null,
                emphasized: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _advanceMetric(String label, int amount) => TaxCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SizedBox(height: 6),
        Text(
          formatMoney(amount),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text('Cumulative liability'),
      ],
    ),
  );

  Widget _buildSlabs(IncomeTaxController controller) {
    final rules = _rulesRegistry.forYear(controller.draft.financialYear);
    return Column(
      children: [
        _slabTable('New Regime', rules.newRegimeSlabs),
        SizedBox(height: 18),
        _slabTable(
          'Old Regime – Individual below 60',
          rules.oldRegimeSlabsBelow60,
        ),
        SizedBox(height: 18),
        _slabTable('Old Regime – Senior Citizen', rules.oldRegimeSlabsSenior),
        SizedBox(height: 18),
        _slabTable(
          'Old Regime – Very Senior Citizen',
          rules.oldRegimeSlabsVerySenior,
        ),
      ],
    );
  }

  Widget _slabTable(String title, List<TaxSlab> slabs) {
    return TaxCard(
      title: title,
      child: Table(
        columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1)},
        border: TableBorder(
          horizontalInside: BorderSide(color: Theme.of(context).dividerColor),
        ),
        children: [
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Income Slab',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Rate',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          ...slabs.map(
            (slab) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(slab.label),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(formatPercentBps(slab.rateBasisPoints)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison(IncomeTaxController controller) => Column(
    children: [
      _summaryStrip(controller),
      SizedBox(height: 18),
      _comparisonColumns(controller),
    ],
  );

  Widget _comparisonColumns(IncomeTaxController controller) {
    final comparison = controller.comparison;
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = [
          RegimeSummaryCard(
            title: 'Old Regime',
            result: comparison.oldRegime,
            recommended: comparison.recommendedRegime == TaxRegime.oldRegime,
          ),
          RegimeSummaryCard(
            title: 'New Regime',
            result: comparison.newRegime,
            recommended: comparison.recommendedRegime == TaxRegime.newRegime,
          ),
        ];
        if (constraints.maxWidth < 900) {
          return Column(
            children: [children[0], SizedBox(height: 18), children[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            SizedBox(width: 18),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }

  Widget _buildPlanning(IncomeTaxController controller) {
    final c = controller.comparison;
    return TaxCard(
      title: 'Smart Tax Planner',
      subtitle:
          'Suggestions are based on entered values and configured statutory caps.',
      child: Column(
        children: [
          ...c.planningSuggestions.map(
            (suggestion) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.compliance.success.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: context.compliance.success,
                ),
              ),
              title: Text(suggestion),
            ),
          ),
          Divider(height: 28),
          MetricRow(
            label: 'Recommended Regime',
            value: c.recommendedRegime == TaxRegime.oldRegime
                ? 'Old Regime'
                : 'New Regime',
            valueColor: context.compliance.success,
            emphasized: true,
          ),
          MetricRow(
            label: 'Estimated Tax Saving',
            value: formatMoney(c.taxSaving),
            valueColor: context.compliance.success,
            emphasized: true,
          ),
          MetricRow(
            label: 'Percentage Saved',
            value: formatPercentBps(c.percentageSavedBasisPoints),
          ),
        ],
      ),
    );
  }

  Widget _buildItrDueDates(IncomeTaxController controller) {
    final fy = controller.draft.financialYear;
    final filingYear = fy == FinancialYear.fy2025_26 ? 2026 : 2027;
    return Column(
      children: [
        TaxCard(
          title: 'ITR Information',
          child: Column(
            children: [
              MetricRow(
                label: 'Suggested ITR Form',
                value: controller.comparison.suggestedItr,
                valueColor: context.compliance.primary,
                emphasized: true,
              ),
              MetricRow(
                label: 'Standard non-audit due date',
                value: '31 July $filingYear',
              ),
              MetricRow(
                label: 'Audit case due date',
                value: '31 October $filingYear',
              ),
              MetricRow(
                label: 'Transfer-pricing case due date',
                value: '30 November $filingYear',
              ),
              MetricRow(
                label: 'Belated / Revised return',
                value: '31 December $filingYear',
              ),
              Divider(height: 26),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Updated return availability and additional tax depend on the applicable Act, elapsed period and statutory conditions.',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        _warningCard(
          'Due dates shown are statutory master values and may be extended by CBDT notification. Keep this master remotely configurable.',
        ),
      ],
    );
  }

  Widget _buildReports(IncomeTaxController controller) {
    final reports = <(String, IconData, String)>[
      ('Tax Computation Sheet', Icons.receipt_long_outlined, 'pdf'),
      ('Income Summary', Icons.summarize_outlined, 'excel'),
      ('Deduction Summary', Icons.savings_outlined, 'excel'),
      ('Advance Tax Report', Icons.calendar_month_outlined, 'pdf'),
      ('Tax Comparison Report', Icons.compare_arrows_outlined, 'pdf'),
      ('Annual Report', Icons.analytics_outlined, 'pdf'),
    ];
    return TaxCard(
      title: 'Reports & Export',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: widget.canExport ? () => _export('pdf') : null,
                icon: Icon(Icons.picture_as_pdf_outlined),
                label: Text('PDF'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.canExport ? () => _export('excel') : null,
                icon: Icon(Icons.grid_on_outlined),
                label: Text('Excel'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.canExport ? () => _export('csv') : null,
                icon: Icon(Icons.table_rows_outlined),
                label: Text('CSV'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.canExport ? () => _export('ods') : null,
                icon: Icon(Icons.dataset_outlined),
                label: Text('ODS'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.canExport ? _print : null,
                icon: Icon(Icons.print_outlined),
                label: Text('Print'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.canExport ? () => _export('pdf') : null,
                icon: Icon(Icons.share_outlined),
                label: Text('Share'),
              ),
            ],
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: reports.map((report) {
              return SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(18),
                  ),
                  onPressed: widget.canExport ? () => _export(report.$3) : null,
                  icon: Icon(report.$2),
                  label: Text(report.$1),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(IncomeTaxController controller) {
    return TaxCard(
      title: 'Calculation History',
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: controller.isLoadingHistory
            ? null
            : () => controller.loadHistory(query: _searchController.text),
        icon: Icon(Icons.refresh),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by taxpayer, PAN or financial year',
              prefixIcon: Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () =>
                    controller.loadHistory(query: _searchController.text),
                icon: Icon(Icons.arrow_forward),
              ),
            ),
            onSubmitted: (value) => controller.loadHistory(query: value),
          ),
          SizedBox(height: 16),
          if (controller.isLoadingHistory)
            Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            )
          else if (controller.history.isEmpty)
            Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off, size: 42),
                  SizedBox(height: 10),
                  Text('No saved calculations found.'),
                ],
              ),
            )
          else
            ...controller.history.map(
              (item) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: context.compliance.primary.withValues(
                    alpha: .1,
                  ),
                  foregroundColor: context.compliance.primary,
                  child: Icon(Icons.calculate_outlined),
                ),
                title: Text(
                  item.profile.name.isEmpty
                      ? 'Unnamed Taxpayer'
                      : item.profile.name,
                ),
                subtitle: Text(
                  '${item.profile.pan.isEmpty ? 'PAN not entered' : item.profile.pan} • ${item.financialYear.label} • ${enumTitle(item.status)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Open',
                      onPressed: () async {
                        await controller.openCalculation(item.id!);
                        if (mounted) setState(() => _tab = _TaxTab.calculator);
                      },
                      icon: Icon(Icons.open_in_new),
                    ),
                    IconButton(
                      tooltip: 'Duplicate',
                      onPressed: () {
                        controller.duplicateCalculation(item);
                        setState(() => _tab = _TaxTab.calculator);
                      },
                      icon: Icon(Icons.copy_outlined),
                    ),
                    if (widget.canDelete)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => controller.deleteCalculation(item.id!),
                        icon: Icon(
                          Icons.delete_outline,
                          color: context.compliance.danger,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettings(IncomeTaxController controller) {
    final rules = _rulesRegistry.forYear(controller.draft.financialYear);
    return TaxCard(
      title: 'Tax Rule Settings',
      subtitle:
          'Read-only runtime metadata. Replace the registry with a remote master repository when your compliance approval workflow is ready.',
      child: Column(
        children: [
          MetricRow(
            label: 'Financial Year',
            value: controller.draft.financialYear.label,
          ),
          MetricRow(
            label: 'Statutory Year',
            value: controller.draft.financialYear.statutoryYearLabel,
          ),
          MetricRow(label: 'Rule Version', value: rules.ruleVersion),
          MetricRow(label: 'Source', value: rules.sourceReference),
          MetricRow(
            label: 'Cess',
            value: formatPercentBps(rules.cessBasisPoints),
          ),
          MetricRow(
            label: 'New Regime Standard Deduction',
            value: formatMoney(rules.newStandardDeduction),
          ),
          MetricRow(
            label: 'Old Regime Standard Deduction',
            value: formatMoney(rules.oldStandardDeduction),
          ),
          Divider(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Production control: tax masters should be versioned, maker-checker approved, effective-dated and immutable after calculations reference them.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.compliance.warning.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: context.compliance.warning.withValues(alpha: .35),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: context.compliance.warning),
        SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );

  Future<void> _save(bool asDraft) async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final saved = await widget.controller.save(asDraft: asDraft);
    if (!mounted || saved == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(asDraft ? 'Draft saved.' : 'Calculation saved.')),
    );
  }

  Future<void> _handleHeaderAction(String action) async {
    switch (action) {
      case 'load':
        setState(() => _tab = _TaxTab.history);
        return;
      case 'pdf':
      case 'excel':
        await _export(action);
        return;
      case 'print':
        await _print();
        return;
      case 'reset':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Reset calculation?'),
            content: Text(
              'All unsaved values in the current calculation will be cleared.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Reset'),
              ),
            ],
          ),
        );
        if (confirmed == true) widget.controller.reset();
        return;
      case 'theme':
        widget.onToggleTheme?.call();
        return;
    }
  }

  Future<void> _export(String type) async {
    if (!widget.canExport) return;
    final handler = widget.onFileReady;
    if (handler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connect onFileReady to the ERP file save/share service.',
          ),
        ),
      );
      return;
    }
    final draft = widget.controller.draft;
    final comparison = widget.controller.comparison;
    final base =
        'income_tax_${draft.profile.pan.isEmpty ? 'calculation' : draft.profile.pan}_${draft.financialYear.name}';
    switch (type) {
      case 'pdf':
        await handler(
          '$base.pdf',
          await _exportService.buildPdf(draft: draft, comparison: comparison),
          'application/pdf',
        );
        break;
      case 'excel':
        await handler(
          '$base.xlsx',
          _exportService.buildExcel(draft: draft, comparison: comparison),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        break;
      case 'csv':
        await handler(
          '$base.csv',
          _exportService.buildCsv(draft: draft, comparison: comparison),
          'text/csv',
        );
        break;
      case 'ods':
        await handler(
          '$base.ods',
          _exportService.buildOds(draft: draft, comparison: comparison),
          'application/vnd.oasis.opendocument.spreadsheet',
        );
        break;
      default:
        throw ArgumentError.value(type, 'type', 'Unsupported export format');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.toUpperCase()} generated.')),
      );
    }
  }

  Future<void> _print() async {
    final bytes = await _exportService.buildPdf(
      draft: widget.controller.draft,
      comparison: widget.controller.comparison,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
