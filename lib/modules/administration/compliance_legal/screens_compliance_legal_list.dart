import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/core/theme/theme_controller.dart';
import 'package:QUIK/modules/finance/tds_tcs_master/screens/tds_tcs_section_master_screen.dart';

import '../../compliance/income_tax/integration/income_tax_module_entry.dart';
import 'challan_converter/screens/challan_converter_screen.dart';
import 'compliance_calendar/models/compliance_calendar_model.dart';
import 'compliance_calendar/screens/compliance_calendar_screen.dart';
import 'design_system/compliance_design_system.dart';
import 'enterprise_command_center/enterprise_compliance_command_center.dart';
import 'form10iea/screens/form10iea_screen.dart';
import 'overview/compliance_overview_repository.dart';
import 'reports_query_centre/permissions/compliance_permissions.dart';
import 'reports_query_centre/reports_query_centre.dart';

class ScreensComplianceLegalList extends StatefulWidget {
  const ScreensComplianceLegalList({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    this.companyName = 'MEMCO',
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canApprove = false,
    this.canExport = false,
    this.canComplete = false,
    this.canUpload = false,
    this.canDownload = false,
    this.canArchive = false,
    this.canRenew = false,
  });

  final String companyId;
  final String companyName;
  final String currentUserUid;
  final String currentUserName;

  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canApprove;
  final bool canExport;
  final bool canComplete;
  final bool canUpload;
  final bool canDownload;
  final bool canArchive;
  final bool canRenew;

  @override
  State<ScreensComplianceLegalList> createState() =>
      _ScreensComplianceLegalListState();
}

class _ScreensComplianceLegalListState
    extends State<ScreensComplianceLegalList> {
  final TextEditingController _globalSearch = TextEditingController();
  late final ComplianceOverviewRepository _overviewRepository;
  late final Stream<ComplianceOverviewSnapshot> _overviewStream;
  late final List<_ComplianceToolDefinition> _tools;

  String _activeNavigationId = 'dashboard';
  String _query = '';
  String _branch = 'All Branches';
  String _businessUnit = 'All Business Units';
  String _financialYear = 'FY 2026–27';

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeFormat = DateFormat('dd MMM, hh:mm a');

  @override
  void initState() {
    super.initState();
    _overviewRepository = ComplianceOverviewRepository(
      companyId: widget.companyId,
    );
    _overviewStream = _overviewRepository.watchOverview();
    _tools = _buildTools();
  }

  @override
  void dispose() {
    _globalSearch.dispose();
    super.dispose();
  }

  List<_ComplianceToolDefinition> _buildTools() {
    return <_ComplianceToolDefinition>[
      _ComplianceToolDefinition(
        id: 'tds_tcs',
        title: 'TDS / TCS Section Codes',
        description:
            'Searchable statutory reference for rates, thresholds, forms and sections across the 1961 and 2025 Acts.',
        icon: Icons.account_balance_outlined,
        group: _ToolGroup.reference,
        badge: 'Updated',
        tone: ComplianceTone.info,
        features: const <String>[
          'Section comparison',
          'Rates & thresholds',
          'Effective dates',
          'Export & print',
        ],
        onOpen: _openTdsTcs,
      ),
      _ComplianceToolDefinition(
        id: 'challan_converter',
        title: 'Tax Challan Converter',
        description:
            'Convert Income Tax, TDS and TCS PDF challans into governed structured data and export-ready files.',
        icon: Icons.document_scanner_outlined,
        group: _ToolGroup.tax,
        badge: 'Automation',
        tone: ComplianceTone.primary,
        features: const <String>[
          'PDF extraction',
          'Validation',
          'Bulk queue',
          'CSV / ODS',
        ],
        onOpen: _openChallanConverter,
      ),
      _ComplianceToolDefinition(
        id: 'calendar',
        title: 'Compliance Calendar',
        description:
            'Enterprise due-date control for statutory filings, owners, reminders, priorities and evidence.',
        icon: Icons.calendar_month_outlined,
        group: _ToolGroup.operations,
        badge: 'Core',
        tone: ComplianceTone.success,
        features: const <String>[
          'Monthly calendar',
          'Agenda view',
          'Due-date alerts',
          'Owner tracking',
        ],
        onOpen: _openCalendar,
      ),
      _ComplianceToolDefinition(
        id: 'form_10iea',
        title: 'Form 10-IEA & Regime Switching',
        description:
            'Scenario-driven reference and decision support for tax-regime switching, legal notes and CBDT guidance.',
        icon: Icons.menu_book_outlined,
        group: _ToolGroup.reference,
        badge: 'Reference',
        tone: ComplianceTone.legal,
        features: const <String>[
          'Scenario master',
          'Smart finder',
          'Legal notes',
          'Case laws',
        ],
        onOpen: _openForm10Iea,
      ),
      _ComplianceToolDefinition(
        id: 'income_tax',
        title: 'Income Tax Calculator',
        description:
            'Enterprise tax computation with Old versus New Regime comparison, deductions, advance tax and reports.',
        icon: Icons.calculate_outlined,
        group: _ToolGroup.tax,
        badge: 'Calculator',
        tone: ComplianceTone.primary,
        features: const <String>[
          'Old vs New',
          'Advance tax',
          'Tax planning',
          'PDF / print',
        ],
        onOpen: _openIncomeTax,
      ),
      _ComplianceToolDefinition(
        id: 'command_center',
        title: 'Enterprise Compliance Command Center',
        description:
            'Executive GRC cockpit for compliance health, risk, workflow, audit, notices, litigation, policies and security.',
        icon: Icons.shield_outlined,
        group: _ToolGroup.grc,
        badge: 'Enterprise',
        tone: ComplianceTone.primary,
        features: const <String>[
          'Executive health',
          'Risk matrix',
          'Approval workflow',
          'Audit & legal',
        ],
        onOpen: _openCommandCenter,
      ),
      _ComplianceToolDefinition(
        id: 'reports_queries',
        title: 'Reports & Query Centre',
        description:
            'Central report generation, compliance queries, government notices, legal cases and document repository.',
        icon: Icons.analytics_outlined,
        group: _ToolGroup.grc,
        badge: 'Analytics',
        tone: ComplianceTone.audit,
        features: const <String>[
          'Compliance reports',
          'Query workflow',
          'Notice tracking',
          'Scheduled reports',
        ],
        onOpen: _openReportsQueryCentre,
      ),
    ];
  }

  List<ComplianceNavigationGroup> get _navigationGroups {
    return <ComplianceNavigationGroup>[
      ComplianceNavigationGroup(
        label: 'Overview',
        items: <ComplianceNavigationItem>[
          ComplianceNavigationItem(
            id: 'dashboard',
            label: 'Executive Dashboard',
            icon: Icons.space_dashboard_outlined,
            onTap: () => _selectSection('dashboard'),
          ),
        ],
      ),
      ComplianceNavigationGroup(
        label: 'Compliance Operations',
        items: <ComplianceNavigationItem>[
          ComplianceNavigationItem(
            id: 'calendar',
            label: 'Calendar & Due Dates',
            icon: Icons.calendar_month_outlined,
            onTap: _openCalendar,
          ),
          ComplianceNavigationItem(
            id: 'tax_tools',
            label: 'Tax & Filing Tools',
            icon: Icons.receipt_long_outlined,
            onTap: () => _selectSection('tax_tools'),
          ),
          ComplianceNavigationItem(
            id: 'reference',
            label: 'Statutory Reference',
            icon: Icons.library_books_outlined,
            onTap: () => _selectSection('reference'),
          ),
        ],
      ),
      ComplianceNavigationGroup(
        label: 'Governance, Risk & Audit',
        items: <ComplianceNavigationItem>[
          ComplianceNavigationItem(
            id: 'grc',
            label: 'GRC Command Center',
            icon: Icons.shield_outlined,
            onTap: _openCommandCenter,
          ),
          ComplianceNavigationItem(
            id: 'reports',
            label: 'Reports & Queries',
            icon: Icons.analytics_outlined,
            onTap: _openReportsQueryCentre,
          ),
          ComplianceNavigationItem(
            id: 'all_tools',
            label: 'All Compliance Apps',
            icon: Icons.apps_outlined,
            onTap: () => _selectSection('all_tools'),
          ),
        ],
      ),
      ComplianceNavigationGroup(
        label: 'Administration',
        items: <ComplianceNavigationItem>[
          ComplianceNavigationItem(
            id: 'preferences',
            label: 'Workspace Preferences',
            icon: Icons.tune_outlined,
            onTap: () => _selectSection('preferences'),
          ),
        ],
      ),
    ];
  }

  List<ComplianceCommand> get _commands {
    return <ComplianceCommand>[
      ComplianceCommand(
        label: 'Open Executive Dashboard',
        description: 'View compliance health, risk and recent activity.',
        icon: Icons.space_dashboard_outlined,
        onSelected: () => _selectSection('dashboard'),
        keywords: const <String>['health', 'kpi', 'overview'],
        shortcut: 'D',
      ),
      for (final tool in _tools)
        ComplianceCommand(
          label: tool.title,
          description: tool.description,
          icon: tool.icon,
          onSelected: tool.onOpen,
          keywords: <String>[tool.group.label, ...tool.features],
        ),
      ComplianceCommand(
        label: 'Switch light / dark theme',
        description: 'Change the ERP appearance instantly.',
        icon: Icons.contrast_outlined,
        onSelected: () => QuikThemeController.instance.toggle(context),
        keywords: const <String>['theme', 'dark', 'light', 'appearance'],
        shortcut: 'T',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ComplianceOverviewSnapshot>(
      stream: _overviewStream,
      initialData: ComplianceOverviewSnapshot.empty,
      builder: (context, snapshot) {
        final overview = snapshot.data ?? ComplianceOverviewSnapshot.empty;
        final branchOptions = <String>{
          'All Branches',
          ...overview.calendarRecords
              .map((record) => record.branch.trim())
              .where((value) => value.isNotEmpty),
        }.toList();
        final businessUnitOptions = <String>{
          'All Business Units',
          ...overview.calendarRecords
              .map((record) => record.department.trim())
              .where((value) => value.isNotEmpty),
        }.toList();
        final financialYearOptions = <String>{
          'All Financial Years',
          'FY 2025–26',
          'FY 2026–27',
          ...overview.calendarRecords
              .map((record) => record.financialYear.trim())
              .where((value) => value.isNotEmpty),
        }.toList();

        return ComplianceWorkspaceShell(
          activeNavigationId: _activeNavigationId,
          navigationGroups: _navigationGroups,
          title: _pageTitle,
          subtitle: _pageSubtitle,
          companyName: widget.companyName,
          userName: widget.currentUserName,
          globalSearchController: _globalSearch,
          onGlobalSearch: (value) => setState(() => _query = value),
          branchLabel: _branch,
          businessUnitLabel: _businessUnit,
          financialYearLabel: _financialYear,
          companyOptions: <String>[widget.companyName],
          branchOptions: branchOptions,
          businessUnitOptions: businessUnitOptions,
          financialYearOptions: financialYearOptions,
          onBranchSelected: (value) => setState(() => _branch = value),
          onBusinessUnitSelected: (value) {
            setState(() => _businessUnit = value);
          },
          onFinancialYearSelected: (value) {
            setState(() => _financialYear = value);
          },
          onRefresh: () => setState(() {}),
          onNotifications: _showNotifications,
          onSettings: () => _selectSection('preferences'),
          onHelp: _showHelp,
          commands: _commands,
          notificationCount: overview.overdue + overview.dueSoon,
          breadcrumbs: <String>[
            'Administration',
            'Compliance & Legal',
            _pageTitle,
          ],
          body: _buildBody(
            overview,
            loading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
          ),
        );
      },
    );
  }

  String get _pageTitle {
    return switch (_activeNavigationId) {
      'tax_tools' => 'Tax & Filing Tools',
      'reference' => 'Statutory Reference Library',
      'all_tools' => 'Compliance Application Catalogue',
      'preferences' => 'Workspace Preferences',
      _ => 'Compliance Executive Dashboard',
    };
  }

  String get _pageSubtitle {
    return switch (_activeNavigationId) {
      'tax_tools' => 'Calculators, converters and filing productivity tools',
      'reference' => 'Controlled statutory references and decision support',
      'all_tools' => 'All Compliance applications in one governed workspace',
      'preferences' => 'Theme, density and workspace behavior',
      _ => 'Governance, risk, filing health and management insight',
    };
  }

  Widget _buildBody(
    ComplianceOverviewSnapshot overview, {
    required bool loading,
    required Object? error,
  }) {
    return switch (_activeNavigationId) {
      'tax_tools' => _toolCatalogue(
        _tools.where((tool) => tool.group == _ToolGroup.tax).toList(),
        title: 'Tax & Filing Tools',
        subtitle: 'High-confidence computation, conversion and filing support.',
      ),
      'reference' => _toolCatalogue(
        _tools.where((tool) => tool.group == _ToolGroup.reference).toList(),
        title: 'Statutory Reference Library',
        subtitle:
            'Searchable controlled references for tax sections and legal decisions.',
      ),
      'all_tools' => _toolCatalogue(
        _tools,
        title: 'Compliance Application Catalogue',
        subtitle:
            'Launch every Compliance application from a consistent enterprise workspace.',
      ),
      'preferences' => _preferencesPage(),
      _ => _dashboard(overview, loading: loading, error: error),
    };
  }

  Widget _premiumOverviewStrip(
    ComplianceOverviewSnapshot overview, {
    required bool loading,
  }) {
    final health = overview.complianceHealth;

    final healthTone = health >= 90
        ? ComplianceTone.success
        : health >= 70
        ? ComplianceTone.warning
        : ComplianceTone.danger;

    final cards = <Widget>[
      ComplianceKpiCard(
        title: 'Compliance Health',
        value: loading ? '—' : '${health.toStringAsFixed(0)}%',
        icon: Icons.verified_user_outlined,
        tone: healthTone,
        subtitle: 'Overall statutory posture',
      ),
      ComplianceKpiCard(
        title: 'Pending',
        value: loading ? '—' : '${overview.pending}',
        icon: Icons.pending_actions_outlined,
        tone: ComplianceTone.warning,
        subtitle: 'Requires action',
      ),
      ComplianceKpiCard(
        title: 'Due Soon',
        value: loading ? '—' : '${overview.dueSoon}',
        icon: Icons.schedule_outlined,
        tone: ComplianceTone.info,
        subtitle: 'Upcoming deadlines',
      ),
      ComplianceKpiCard(
        title: 'Overdue',
        value: loading ? '—' : '${overview.overdue}',
        icon: Icons.event_busy_outlined,
        tone: ComplianceTone.danger,
        subtitle: 'Immediate attention',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ComplianceSectionHeader(
          title: 'Compliance Overview',
          subtitle:
              'A concise view of statutory readiness, deadlines and management attention.',
          icon: Icons.dashboard_customize_outlined,
        ),
        const SizedBox(height: ComplianceSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 620
                ? 2
                : 1;

            const gap = ComplianceSpacing.sm;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _premiumToolCard(_ComplianceToolDefinition tool) {
    final palette = context.compliance;
    final accent = context.complianceTone(tool.tone);
    final soft = context.complianceToneSoft(tool.tone);

    return ComplianceCard(
      onTap: tool.onOpen,
      hoverable: true,
      tone: tool.tone,
      semanticLabel: tool.title,
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 154,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(ComplianceRadius.md),
                  ),
                  child: Icon(tool.icon, size: 20, color: accent),
                ),
                const Spacer(),
                if (tool.badge != null)
                  ComplianceStatusBadge(
                    label: tool.badge!,
                    tone: tool.tone,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: ComplianceSpacing.sm),
            Text(
              tool.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -.15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              tool.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                height: 1.4,
              ),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Text(
                  'Open module',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, size: 17, color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumToolGrid(List<_ComplianceToolDefinition> tools) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;

        const gap = ComplianceSpacing.md;

        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tools
              .map(
                (tool) => SizedBox(width: width, child: _premiumToolCard(tool)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _premiumToolSection(
    String title,
    String subtitle,
    List<_ComplianceToolDefinition> tools, {
    IconData? icon,
  }) {
    if (tools.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ComplianceSectionHeader(title: title, subtitle: subtitle, icon: icon),
        const SizedBox(height: ComplianceSpacing.md),
        _premiumToolGrid(tools),
      ],
    );
  }

  Widget _dashboard(
    ComplianceOverviewSnapshot overview, {
    required bool loading,
    required Object? error,
  }) {
    final coreTools = _tools
        .where(
          (tool) => const <String>{
            'calendar',
            'command_center',
            'reports_queries',
          }.contains(tool.id),
        )
        .toList();

    final taxTools = _tools
        .where((tool) => tool.group == _ToolGroup.tax)
        .toList();

    final referenceTools = _tools
        .where((tool) => tool.group == _ToolGroup.reference)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: <Widget>[
        if (error != null) ...<Widget>[
          ComplianceErrorState(
            message: error.toString(),
            onRetry: () => setState(() {}),
          ),
          const SizedBox(height: ComplianceSpacing.lg),
        ],

        _premiumOverviewStrip(overview, loading: loading),

        const SizedBox(height: 28),

        _premiumToolSection(
          'Core Operations',
          'Daily compliance control, governance, reporting and management oversight.',
          coreTools,
          icon: Icons.account_tree_outlined,
        ),

        const SizedBox(height: 28),

        _premiumToolSection(
          'Tax & Filing',
          'Focused tax computation, challan processing and filing productivity tools.',
          taxTools,
          icon: Icons.receipt_long_outlined,
        ),

        const SizedBox(height: 28),

        _premiumToolSection(
          'Statutory Reference',
          'Controlled references for sections, rates and regulatory decision support.',
          referenceTools,
          icon: Icons.library_books_outlined,
        ),

        const SizedBox(height: 28),

        const ComplianceSectionHeader(
          title: 'Upcoming Work & Activity',
          subtitle: 'What requires attention next and what changed recently.',
          icon: Icons.event_note_outlined,
        ),

        const SizedBox(height: ComplianceSpacing.md),

        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 6, child: _nextDuePanel(overview)),
                  const SizedBox(width: ComplianceSpacing.md),
                  Expanded(flex: 4, child: _activityPanel(overview)),
                ],
              );
            }

            return Column(
              children: <Widget>[
                _nextDuePanel(overview),
                const SizedBox(height: ComplianceSpacing.md),
                _activityPanel(overview),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        const ComplianceSectionHeader(
          title: 'Management Insights',
          subtitle:
              'Status and risk analytics kept separate from operational work.',
          icon: Icons.insights_outlined,
        ),

        const SizedBox(height: ComplianceSpacing.md),

        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _complianceStatusChart(overview)),
                  const SizedBox(width: ComplianceSpacing.md),
                  Expanded(child: _riskDistributionChart(overview)),
                ],
              );
            }

            return Column(
              children: <Widget>[
                _complianceStatusChart(overview),
                const SizedBox(height: ComplianceSpacing.md),
                _riskDistributionChart(overview),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _executiveSummary(
    ComplianceOverviewSnapshot overview, {
    required bool loading,
  }) {
    final palette = context.compliance;
    final health = overview.complianceHealth;
    final healthTone = health >= 90
        ? ComplianceTone.success
        : health >= 70
        ? ComplianceTone.warning
        : ComplianceTone.danger;
    final healthLabel = health >= 90
        ? 'Excellent control posture'
        : health >= 70
        ? 'Management attention required'
        : 'Immediate corrective action required';

    return Container(
      padding: const EdgeInsets.all(ComplianceSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[palette.primary, palette.primaryHover],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ComplianceRadius.xxl),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.primary.withValues(alpha: .24),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final primaryContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(ComplianceRadius.pill),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: .18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'ENTERPRISE COMPLIANCE HEALTH',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .65,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ComplianceSpacing.md),
              Text(
                'One view of statutory readiness, risk and accountability.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.65,
                ),
              ),
              const SizedBox(height: ComplianceSpacing.xs),
              Text(
                'Management insight for statutory audits, board reporting, investor due diligence and enterprise governance.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: .78),
                ),
              ),
              const SizedBox(height: ComplianceSpacing.lg),
              Wrap(
                spacing: ComplianceSpacing.sm,
                runSpacing: ComplianceSpacing.sm,
                children: <Widget>[
                  _heroMetric(
                    'Pending',
                    '${overview.pending}',
                    Icons.pending_actions_outlined,
                  ),
                  _heroMetric(
                    'Overdue',
                    '${overview.overdue}',
                    Icons.event_busy_outlined,
                  ),
                  _heroMetric(
                    'Notices',
                    '${overview.noticeCount}',
                    Icons.mark_email_unread_outlined,
                  ),
                  _heroMetric(
                    'Open Cases',
                    '${overview.openLegalCases}',
                    Icons.gavel_outlined,
                  ),
                ],
              ),
            ],
          );

          final healthCard = Container(
            width: compact ? double.infinity : 310,
            padding: const EdgeInsets.all(ComplianceSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(ComplianceRadius.xl),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: .18),
              ),
            ),
            child: loading
                ? ComplianceSkeleton(lines: 4)
                : Row(
                    children: <Widget>[
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: health / 100,
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withValues(alpha: .18),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.complianceTone(healthTone),
                                ),
                              ),
                            ),
                            Text(
                              '${health.toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: ComplianceSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Overall Score',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: .72),
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              healthLabel,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 9),
                            ComplianceStatusBadge(
                              label: health >= 90
                                  ? 'Healthy'
                                  : health >= 70
                                  ? 'Watch'
                                  : 'Critical',
                              tone: healthTone,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                primaryContent,
                const SizedBox(height: ComplianceSpacing.lg),
                healthCard,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: primaryContent),
              const SizedBox(width: ComplianceSpacing.xl),
              healthCard,
            ],
          );
        },
      ),
    );
  }

  Widget _heroMetric(String label, String value, IconData icon) {
    final foreground = Theme.of(context).colorScheme.onPrimary;

    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(ComplianceRadius.md),
        border: Border.all(color: foreground.withValues(alpha: .14)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: foreground.withValues(alpha: .76), size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  color: foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: foreground.withValues(alpha: .68),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupedKpis(ComplianceOverviewSnapshot overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ComplianceSectionHeader(
          title: 'Management Indicators',
          subtitle:
              'Grouped by compliance, risk, legal and audit accountability.',
          icon: Icons.insights_outlined,
        ),
        const SizedBox(height: ComplianceSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1450
                ? 4
                : constraints.maxWidth >= 950
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - (columns - 1) * ComplianceSpacing.md) /
                columns;

            final groups = <Widget>[
              _kpiGroup(
                'Compliance',
                Icons.fact_check_outlined,
                ComplianceTone.primary,
                <_KpiMetric>[
                  _KpiMetric('Total', overview.total, ComplianceTone.primary),
                  _KpiMetric(
                    'Completed',
                    overview.completed,
                    ComplianceTone.success,
                  ),
                  _KpiMetric(
                    'Pending',
                    overview.pending,
                    ComplianceTone.warning,
                  ),
                  _KpiMetric(
                    'Overdue',
                    overview.overdue,
                    ComplianceTone.danger,
                  ),
                ],
              ),
              _kpiGroup(
                'Risk',
                Icons.warning_amber_rounded,
                ComplianceTone.danger,
                <_KpiMetric>[
                  _KpiMetric(
                    'Critical',
                    overview.criticalRisks,
                    ComplianceTone.danger,
                  ),
                  _KpiMetric('High', overview.highRisks, ComplianceTone.danger),
                  _KpiMetric(
                    'Medium',
                    overview.mediumRisks,
                    ComplianceTone.warning,
                  ),
                  _KpiMetric('Low', overview.lowRisks, ComplianceTone.success),
                ],
              ),
              _kpiGroup(
                'Legal & Government',
                Icons.account_balance_outlined,
                ComplianceTone.legal,
                <_KpiMetric>[
                  _KpiMetric(
                    'Notices',
                    overview.noticeCount,
                    ComplianceTone.warning,
                  ),
                  _KpiMetric(
                    'Open Cases',
                    overview.openLegalCases,
                    ComplianceTone.legal,
                  ),
                  _KpiMetric('Due Soon', overview.dueSoon, ComplianceTone.info),
                  _KpiMetric(
                    'Escalations',
                    overview.overdue,
                    ComplianceTone.danger,
                  ),
                ],
              ),
              _kpiGroup(
                'Audit & Controls',
                Icons.fact_check_outlined,
                ComplianceTone.audit,
                <_KpiMetric>[
                  _KpiMetric(
                    'Open Findings',
                    overview.openAuditFindings,
                    ComplianceTone.audit,
                  ),
                  _KpiMetric(
                    'CAPA Due',
                    overview.openAuditFindings,
                    ComplianceTone.warning,
                  ),
                  _KpiMetric('Evidence Gaps', 0, ComplianceTone.info),
                  _KpiMetric('Closed', 0, ComplianceTone.success),
                ],
              ),
            ];

            return Wrap(
              spacing: ComplianceSpacing.md,
              runSpacing: ComplianceSpacing.md,
              children: groups
                  .map((group) => SizedBox(width: width, child: group))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _kpiGroup(
    String title,
    IconData icon,
    ComplianceTone tone,
    List<_KpiMetric> metrics,
  ) {
    final palette = context.compliance;
    final accent = context.complianceTone(tone);

    return ComplianceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.complianceToneSoft(tone),
                  borderRadius: BorderRadius.circular(ComplianceRadius.md),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: ComplianceSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: ComplianceSpacing.md),
          Row(
            children: metrics.map((metric) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      right: metric != metrics.last
                          ? BorderSide(color: palette.border)
                          : BorderSide.none,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        '${metric.value}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: context.complianceTone(metric.tone),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metric.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _complianceStatusChart(ComplianceOverviewSnapshot overview) {
    final palette = context.compliance;
    final total = overview.total;
    final values = <_ChartSlice>[
      _ChartSlice('Completed', overview.completed.toDouble(), palette.success),
      _ChartSlice('Pending', overview.pending.toDouble(), palette.warning),
      _ChartSlice('Overdue', overview.overdue.toDouble(), palette.danger),
      _ChartSlice(
        'Other',
        (total - overview.completed - overview.pending - overview.overdue)
            .clamp(0, total)
            .toDouble(),
        palette.info,
      ),
    ];

    return ComplianceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ComplianceSectionHeader(
            title: 'Compliance Status',
            subtitle: 'Distribution across the active global scope',
            icon: Icons.donut_large_outlined,
            compact: true,
          ),
          const SizedBox(height: ComplianceSpacing.md),
          SizedBox(
            height: 260,
            child: total == 0
                ? const ComplianceEmptyState(
                    icon: Icons.donut_large_outlined,
                    title: 'No compliance data',
                    message:
                        'Create calendar obligations to populate this analysis.',
                    compact: true,
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 58,
                            sectionsSpace: 3,
                            startDegreeOffset: -90,
                            sections: values
                                .where((slice) => slice.value > 0)
                                .map(
                                  (slice) => PieChartSectionData(
                                    value: slice.value,
                                    color: slice.color,
                                    radius: 28,
                                    showTitle: false,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: ComplianceSpacing.md),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: values.map((slice) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: slice.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      slice.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  Text(
                                    '${slice.value.toInt()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: palette.textPrimary),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _riskDistributionChart(ComplianceOverviewSnapshot overview) {
    final palette = context.compliance;
    final values = <_ChartSlice>[
      _ChartSlice(
        'Critical',
        overview.criticalRisks.toDouble(),
        palette.danger,
      ),
      _ChartSlice('High', overview.highRisks.toDouble(), palette.warning),
      _ChartSlice('Medium', overview.mediumRisks.toDouble(), palette.info),
      _ChartSlice('Low', overview.lowRisks.toDouble(), palette.success),
    ];
    final maxValue = values.fold<double>(
      1,
      (maximum, slice) => slice.value > maximum ? slice.value : maximum,
    );

    return ComplianceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ComplianceSectionHeader(
            title: 'Residual Risk Distribution',
            subtitle: 'Risk concentration after current controls',
            icon: Icons.bar_chart_outlined,
            compact: true,
          ),
          const SizedBox(height: ComplianceSpacing.md),
          SizedBox(
            height: 260,
            child: values.every((slice) => slice.value == 0)
                ? const ComplianceEmptyState(
                    icon: Icons.shield_outlined,
                    title: 'No risk register data',
                    message:
                        'Add risks in the Command Center to view concentration.',
                    compact: true,
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxValue + 1,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: palette.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, _) => Text(
                              value.toInt().toString(),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= values.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  values[index].label,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: <BarChartGroupData>[
                        for (var index = 0; index < values.length; index++)
                          BarChartGroupData(
                            x: index,
                            barRods: <BarChartRodData>[
                              BarChartRodData(
                                toY: values[index].value,
                                width: 28,
                                color: values[index].color,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _nextDuePanel(ComplianceOverviewSnapshot overview) {
    final records = _filteredCalendar(overview.nextDue);

    return ComplianceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ComplianceSectionHeader(
            title: 'Upcoming & Overdue Obligations',
            subtitle: 'Priority filings requiring ownership and evidence',
            icon: Icons.event_note_outlined,
            compact: true,
            trailing: TextButton.icon(
              onPressed: _openCalendar,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open calendar'),
            ),
          ),
          const SizedBox(height: ComplianceSpacing.sm),
          if (records.isEmpty)
            const ComplianceEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No upcoming obligations',
              message: 'No active obligations match the selected global scope.',
              compact: true,
            )
          else
            ...records.map(_dueRow),
        ],
      ),
    );
  }

  List<ComplianceCalendarModel> _filteredCalendar(
    List<ComplianceCalendarModel> records,
  ) {
    final query = _query.trim().toLowerCase();

    return records.where((record) {
      final matchesQuery =
          query.isEmpty ||
          record.title.toLowerCase().contains(query) ||
          record.category.toLowerCase().contains(query) ||
          record.authority.toLowerCase().contains(query);
      final matchesBranch =
          _branch == 'All Branches' || record.branch == _branch;
      final matchesBusiness =
          _businessUnit == 'All Business Units' ||
          record.department == _businessUnit;
      final matchesYear =
          _financialYear == 'All Financial Years' ||
          record.financialYear == _financialYear;
      return matchesQuery && matchesBranch && matchesBusiness && matchesYear;
    }).toList();
  }

  Widget _dueRow(ComplianceCalendarModel record) {
    final palette = context.compliance;
    final now = DateTime.now();
    final overdue =
        record.status.toLowerCase() != 'completed' &&
        record.dueDate.isBefore(now);
    final days = record.dueDate.difference(now).inDays;

    return InkWell(
      onTap: _openCalendar,
      borderRadius: BorderRadius.circular(ComplianceRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: overdue ? palette.dangerSoft : palette.infoSoft,
                borderRadius: BorderRadius.circular(ComplianceRadius.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${record.dueDate.day}',
                    style: TextStyle(
                      color: overdue ? palette.danger : palette.info,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(record.dueDate).toUpperCase(),
                    style: TextStyle(
                      color: overdue ? palette.danger : palette.info,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ComplianceSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    <String>[
                      record.category,
                      if (record.department.isNotEmpty) record.department,
                      if (record.assignedEmployee.isNotEmpty)
                        record.assignedEmployee,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: ComplianceSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                ComplianceStatusBadge(
                  label: overdue
                      ? 'Overdue'
                      : days <= 7
                      ? 'Due Soon'
                      : record.status,
                  tone: overdue
                      ? ComplianceTone.danger
                      : days <= 7
                      ? ComplianceTone.warning
                      : null,
                  compact: true,
                ),
                const SizedBox(height: 5),
                Text(
                  _dateFormat.format(record.dueDate),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityPanel(ComplianceOverviewSnapshot overview) {
    final palette = context.compliance;
    final activity = overview.recentActivity;

    return ComplianceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ComplianceSectionHeader(
            title: 'Recent Governed Activity',
            subtitle: 'Latest auditable changes across the workspace',
            icon: Icons.history_outlined,
            compact: true,
          ),
          const SizedBox(height: ComplianceSpacing.sm),
          if (activity.isEmpty)
            const ComplianceEmptyState(
              icon: Icons.history_toggle_off_outlined,
              title: 'No recent audit activity',
              message:
                  'Governed actions will appear after records are created or updated.',
              compact: true,
            )
          else
            ...activity.take(7).map((item) {
              final tone = ComplianceStatusBadge.toneFor(item.action);
              return Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: context.complianceToneSoft(tone),
                        borderRadius: BorderRadius.circular(
                          ComplianceRadius.md,
                        ),
                      ),
                      child: Icon(
                        _activityIcon(item.entityType),
                        color: context.complianceTone(tone),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title.isEmpty
                                ? 'Compliance record updated'
                                : item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.subtitle} • ${_timeFormat.format(item.timestamp)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _activityIcon(String entityType) {
    final value = entityType.toLowerCase();
    if (value.contains('risk')) {
      return Icons.warning_amber_outlined;
    }
    if (value.contains('notice')) {
      return Icons.mark_email_unread_outlined;
    }
    if (value.contains('legal')) {
      return Icons.gavel_outlined;
    }
    if (value.contains('document')) {
      return Icons.description_outlined;
    }
    if (value.contains('audit')) {
      return Icons.fact_check_outlined;
    }
    return Icons.task_alt_outlined;
  }

  Widget _quickActions() {
    final actions = <ComplianceQuickAction>[
      ComplianceQuickAction(
        icon: Icons.calendar_month_outlined,
        label: 'Compliance Calendar',
        description: 'Review filings and due dates',
        onTap: _openCalendar,
        tone: ComplianceTone.success,
      ),
      ComplianceQuickAction(
        icon: Icons.calculate_outlined,
        label: 'Income Tax Calculator',
        description: 'Compare tax regimes',
        onTap: _openIncomeTax,
      ),
      ComplianceQuickAction(
        icon: Icons.shield_outlined,
        label: 'GRC Command Center',
        description: 'Manage risk, audit and legal',
        onTap: _openCommandCenter,
        tone: ComplianceTone.primary,
      ),
      ComplianceQuickAction(
        icon: Icons.analytics_outlined,
        label: 'Reports & Queries',
        description: 'Generate governed reports',
        onTap: _openReportsQueryCentre,
        tone: ComplianceTone.audit,
      ),
      ComplianceQuickAction(
        icon: Icons.document_scanner_outlined,
        label: 'Challan Converter',
        description: 'Extract and validate challans',
        onTap: _openChallanConverter,
        tone: ComplianceTone.info,
      ),
      ComplianceQuickAction(
        icon: Icons.menu_book_outlined,
        label: 'Form 10-IEA',
        description: 'Regime switching reference',
        onTap: _openForm10Iea,
        tone: ComplianceTone.legal,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ComplianceSectionHeader(
          title: 'Quick Actions',
          subtitle: 'High-frequency workflows for compliance teams',
          icon: Icons.bolt_outlined,
        ),
        const SizedBox(height: ComplianceSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1300
                ? 6
                : constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - (columns - 1) * ComplianceSpacing.sm) /
                columns;
            return Wrap(
              spacing: ComplianceSpacing.sm,
              runSpacing: ComplianceSpacing.sm,
              children: actions
                  .map((action) => SizedBox(width: width, child: action))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _toolCatalogue(
    List<_ComplianceToolDefinition> tools, {
    required String title,
    required String subtitle,
  }) {
    final query = _query.trim().toLowerCase();

    final filtered = query.isEmpty
        ? tools
        : tools.where((tool) {
            final haystack = <String>[
              tool.title,
              tool.description,
              tool.group.label,
              ...tool.features,
            ].join(' ').toLowerCase();

            return haystack.contains(query);
          }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: <Widget>[
        ComplianceSectionHeader(
          title: title,
          subtitle: subtitle,
          icon: Icons.apps_outlined,
        ),
        const SizedBox(height: ComplianceSpacing.md),

        if (filtered.isEmpty)
          ComplianceCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.search_off_rounded,
                  size: 38,
                  color: context.compliance.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No matching applications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.compliance.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Try another search term.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.compliance.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          _premiumToolGrid(filtered),
      ],
    );
  }

  Widget _toolCard(_ComplianceToolDefinition tool) {
    final palette = context.compliance;
    final accent = context.complianceTone(tool.tone);

    return ComplianceCard(
      hoverable: true,
      onTap: tool.onOpen,
      tone: tool.tone,
      padding: const EdgeInsets.all(ComplianceSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.complianceToneSoft(tool.tone),
                  borderRadius: BorderRadius.circular(ComplianceRadius.lg),
                ),
                child: Icon(tool.icon, color: accent, size: 25),
              ),
              const Spacer(),
              ComplianceStatusBadge(
                label: tool.badge,
                tone: tool.tone,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: ComplianceSpacing.md),
          Text(
            tool.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ComplianceSpacing.xs),
          Text(
            tool.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: ComplianceSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tool.features
                .map(
                  (feature) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(ComplianceRadius.sm),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      feature,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: ComplianceSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: tool.onOpen,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Open application'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferencesPage() {
    final themeController = QuikThemeController.instance;
    final palette = context.compliance;

    return ListView(
      padding: const EdgeInsets.all(ComplianceSpacing.lg),
      children: <Widget>[
        const CompliancePageHeader(
          title: 'Workspace Preferences',
          subtitle:
              'Configure appearance and experience for the Compliance Module.',
          eyebrow: 'Administration',
          icon: Icons.tune_outlined,
          breadcrumbs: <String>[],
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: ComplianceSpacing.lg),
        ComplianceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ComplianceSectionHeader(
                title: 'Appearance',
                subtitle:
                    'Theme changes apply instantly to every Compliance page, dialog, menu and data grid.',
                icon: Icons.palette_outlined,
              ),
              const SizedBox(height: ComplianceSpacing.lg),
              SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.computer_outlined),
                  ),
                ],
                selected: <ThemeMode>{themeController.themeMode},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    themeController.setThemeMode(selection.first);
                  }
                },
              ),
              const SizedBox(height: ComplianceSpacing.lg),
              Container(
                padding: const EdgeInsets.all(ComplianceSpacing.md),
                decoration: BoxDecoration(
                  color: palette.infoSoft,
                  borderRadius: BorderRadius.circular(ComplianceRadius.lg),
                  border: Border.all(color: palette.info.withValues(alpha: .2)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: palette.info),
                    const SizedBox(width: ComplianceSpacing.sm),
                    Expanded(
                      child: Text(
                        'The selected theme is stored in user preferences and restored before the ERP starts, preventing white flashes and theme flicker.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ComplianceSpacing.md),
        ComplianceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ComplianceSectionHeader(
                title: 'Keyboard & Productivity',
                subtitle: 'Shortcuts available throughout the workspace.',
                icon: Icons.keyboard_outlined,
              ),
              const SizedBox(height: ComplianceSpacing.md),
              _shortcutRow('Ctrl + K', 'Open global command search'),
              _shortcutRow('Ctrl + R', 'Refresh the current workspace'),
              _shortcutRow('/', 'Focus global search'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shortcutRow(String shortcut, String description) {
    final palette = context.compliance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Container(
            width: 88,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(ComplianceRadius.sm),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              shortcut,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: ComplianceSpacing.sm),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _selectSection(String id) {
    setState(() => _activeNavigationId = id);
  }

  Future<void> _openTdsTcs() {
    return _push(
      TdsTcsSectionMasterScreen(
        companyId: widget.companyId,
        canCreate: widget.canCreate,
        canEdit: widget.canEdit,
        canDelete: widget.canDelete,
        canExport: widget.canExport,
      ),
    );
  }

  Future<void> _openChallanConverter() {
    return _push(
      ChallanConverterScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        canCreate: widget.canCreate,
        canEdit: widget.canEdit,
        canDelete: widget.canDelete,
        canExport: widget.canExport,
        canUpload: widget.canUpload,
        canDownload: widget.canDownload,
      ),
    );
  }

  Future<void> _openCalendar() {
    return _push(
      ComplianceCalendarScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        companyName: widget.companyName,
        canCreate: widget.canCreate,
        canEdit: widget.canEdit,
        canDelete: widget.canDelete,
        canExport: widget.canExport,
        canUpload: widget.canUpload,
        canDownload: widget.canDownload,
      ),
    );
  }

  Future<void> _openForm10Iea() {
    return _push(
      Form10IEAScreen(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        canView: true,
        canAnalyse: widget.canCreate || widget.canEdit,
        canSave: widget.canCreate || widget.canEdit,
        canManageRules: widget.canApprove || widget.canEdit,
      ),
      routeName: '/compliance/income-tax/form-10-iea',
    );
  }

  Future<void> _openIncomeTax() {
    return _push(
      IncomeTaxModuleEntry(
        companyId: widget.companyId,
        userId: widget.currentUserUid,
        canSave: widget.canCreate || widget.canEdit,
        canExport: widget.canExport,
        canDelete: widget.canDelete,
        onFileReady: (filename, bytes, mimeType) async {
          await FilePicker.platform.saveFile(
            dialogTitle: 'Save $filename',
            fileName: filename,
            bytes: bytes,
          );
        },
      ),
    );
  }

  Future<void> _openCommandCenter() {
    return _push(
      EnterpriseComplianceCommandCenterEntry(
        companyId: widget.companyId,
        companyName: widget.companyName,
        userId: widget.currentUserUid,
        userName: widget.currentUserName,
        permissions: CommandCenterPermissions.fromLegacy(
          canCreate: widget.canCreate,
          canEdit: widget.canEdit,
          canDelete: widget.canDelete,
          canApprove: widget.canApprove,
          canExport: widget.canExport,
          canUpload: widget.canUpload,
          canDownload: widget.canDownload,
        ),
      ),
    );
  }

  Future<void> _openReportsQueryCentre() {
    return _push(
      ComplianceReportsQueryCentreScreen(
        companyId: widget.companyId,
        companyName: widget.companyName,
        currentUserUid: widget.currentUserUid,
        currentUserName: widget.currentUserName,
        permissions: CompliancePermissions(
          canView: true,
          canCreate: widget.canCreate,
          canEdit: widget.canEdit,
          canDelete: widget.canDelete,
          canExport: widget.canExport,
          canUpload: widget.canUpload,
          canDownload: widget.canDownload,
          canApprove: widget.canApprove,
        ),
      ),
    );
  }

  Future<void> _push(Widget page, {String? routeName}) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        settings: routeName == null ? null : RouteSettings(name: routeName),
        transitionDuration: const Duration(milliseconds: 230),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(.02, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return const SizedBox(
          height: 330,
          child: ComplianceEmptyState(
            icon: Icons.notifications_none_outlined,
            title: 'Notification centre',
            message:
                'Due-date, approval and risk notifications will appear here from configured backend providers.',
            compact: true,
          ),
        );
      },
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Compliance Workspace Help'),
          content: const SizedBox(
            width: 560,
            child: Text(
              'Use the left navigation to browse Compliance operations, statutory references, GRC and reporting.\n\n'
              'Use Ctrl + K for command search, Ctrl + R to refresh, and / to focus global search. Global Company, Branch, Business Unit and Financial Year selections remain visible across the workspace.',
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}

enum _ToolGroup {
  tax('Tax & Filing'),
  operations('Operations'),
  reference('Reference'),
  grc('Governance & Risk');

  const _ToolGroup(this.label);
  final String label;
}

class _ComplianceToolDefinition {
  const _ComplianceToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.group,
    required this.badge,
    required this.tone,
    required this.features,
    required this.onOpen,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final _ToolGroup group;
  final String badge;
  final ComplianceTone tone;
  final List<String> features;
  final Future<void> Function() onOpen;
}

class _KpiMetric {
  const _KpiMetric(this.label, this.value, this.tone);

  final String label;
  final int value;
  final ComplianceTone tone;
}

class _ChartSlice {
  const _ChartSlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}
