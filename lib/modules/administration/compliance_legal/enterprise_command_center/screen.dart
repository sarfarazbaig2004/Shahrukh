import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controller.dart';
import 'models.dart';
import 'services.dart';

import '../design_system/compliance_design_system.dart';

class EnterpriseComplianceCommandCenterScreen extends StatefulWidget {
  EnterpriseComplianceCommandCenterScreen({
    super.key,
    required this.controller,
    this.onToggleTheme,
    this.onExport,
    this.documentService,
    this.notificationService,
  });

  final CommandCenterController controller;
  final VoidCallback? onToggleTheme;
  final CommandCenterFileHandler? onExport;
  final CommandCenterDocumentService? documentService;
  final CommandCenterNotificationService? notificationService;

  @override
  State<EnterpriseComplianceCommandCenterScreen> createState() =>
      _EnterpriseComplianceCommandCenterScreenState();
}

class _EnterpriseComplianceCommandCenterScreenState
    extends State<EnterpriseComplianceCommandCenterScreen> {
  Color get blue => context.compliance.primary;
  Color get green => context.compliance.success;
  Color get orange => context.compliance.warning;
  Color get red => context.compliance.danger;
  Color get purple => context.compliance.legal;

  final _assistant = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;
  String? _selectedNoticeId;

  CommandCenterController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_listen);
  }

  void _listen() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    c.removeListener(_listen);
    _assistant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!c.permissions.view) {
      return Scaffold(body: Center(child: Text('Permission denied')));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        final background = context.compliance.canvas;

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _openCommandPalette,
            SingleActivator(LogicalKeyboardKey.keyR, control: true): c.refresh,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: background,
              drawer: compact
                  ? Drawer(
                      width: 292,
                      child: SafeArea(child: _sidebar(expanded: true)),
                    )
                  : null,
              body: SafeArea(
                child: Row(
                  children: [
                    if (!compact)
                      AnimatedContainer(
                        duration: Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: _sidebarCollapsed ? 76 : 272,
                        child: _sidebar(expanded: !_sidebarCollapsed),
                      ),
                    if (!compact)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: context.compliance.border,
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          _topBar(compact: compact),
                          _globalFilterBar(),
                          if (c.filter.count > 0) _filterStrip(),
                          Expanded(
                            child: IndexedStack(
                              index: c.selectedTab,
                              children: [
                                _dashboard(),
                                _compliance(),
                                _risk(),
                                _workflows(),
                                _audit(),
                                _notices(),
                                _legal(),
                                _documents(),
                                _policies(),
                                _findings(),
                                _security(),
                                _notifications(),
                                _analytics(),
                                _assistantPanel(),
                                _automation(),
                              ],
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
    );
  }

  Widget _topBar({required bool compact}) {
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      elevation: 1,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              if (compact)
                IconButton(
                  tooltip: 'Navigation',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: Icon(Icons.menu),
                )
              else
                IconButton(
                  tooltip: _sidebarCollapsed
                      ? 'Expand navigation'
                      : 'Collapse navigation',
                  onPressed: () {
                    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                  },
                  icon: Icon(
                    _sidebarCollapsed
                        ? Icons.keyboard_double_arrow_right
                        : Icons.keyboard_double_arrow_left,
                  ),
                ),
              SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPageTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Compliance / $_currentPageTitle',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: .62),
                      ),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 880)
                _commandSearchButton(),
              SizedBox(width: 10),
              if (c.loading)
                Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: 'Refresh (Ctrl+R)',
                onPressed: c.refresh,
                icon: Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: isDarkTheme
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  isDarkTheme
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              _notificationButton(),
              PopupMenuButton<String>(
                tooltip: 'User menu',
                onSelected: (value) {
                  if (value == 'settings') {
                    c.selectTab(10);
                  } else if (value == 'theme') {
                    widget.onToggleTheme?.call();
                  } else if (value == 'help') {
                    _showInformation(
                      'Use Ctrl+K for command search and Ctrl+R to refresh.',
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'theme',
                    child: ListTile(
                      leading: Icon(
                        isDarkTheme
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      title: Text(
                        isDarkTheme
                            ? 'Switch to light mode'
                            : 'Switch to dark mode',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'help',
                    child: ListTile(
                      leading: Icon(Icons.help_outline),
                      title: Text('Help & shortcuts'),
                    ),
                  ),
                ],
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.compliance.borderStrong),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: blue.withValues(alpha: .12),
                        child: Text(
                          _initials(c.userName),
                          style: TextStyle(
                            color: blue,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 1180) ...[
                        SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 120),
                          child: Text(
                            c.userName.isEmpty ? 'User' : c.userName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 17),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Export',
                onPressed: c.permissions.export ? _export : null,
                icon: Icon(Icons.file_download_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _globalFilterBar() {
    return Material(
      color: Theme.of(context).cardColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.compliance.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final controls = <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 17, color: blue),
                    SizedBox(width: 7),
                    Text(
                      'GLOBAL SCOPE',
                      style: TextStyle(
                        color: blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              _selector(
                icon: Icons.business_outlined,
                label: 'Company',
                value: c.companyName,
                options: [c.companyName],
                onSelected: (_) {},
                locked: true,
              ),
              SizedBox(width: 8),
              _selector(
                icon: Icons.account_tree_outlined,
                label: 'Branch',
                value: c.filter.branchId ?? 'All Branches',
                options: _uniqueOptions(['All Branches', c.filter.branchId]),
                onSelected: (value) {
                  c.applyFilter(
                    _copyFilter(
                      branchId: value == 'All Branches' ? null : value,
                      replaceBranch: true,
                    ),
                  );
                },
              ),
              SizedBox(width: 8),
              _selector(
                icon: Icons.apartment_outlined,
                label: 'Business Unit',
                value: c.filter.businessUnit ?? 'All Business Units',
                options: _uniqueOptions([
                  'All Business Units',
                  c.filter.businessUnit,
                ]),
                onSelected: (value) {
                  c.applyFilter(
                    _copyFilter(
                      businessUnit: value == 'All Business Units'
                          ? null
                          : value,
                      replaceBusinessUnit: true,
                    ),
                  );
                },
              ),
              SizedBox(width: 8),
              _selector(
                icon: Icons.calendar_month_outlined,
                label: 'Financial Year',
                value: c.filter.financialYear ?? 'Current FY',
                options: _financialYears(),
                onSelected: (value) {
                  c.applyFilter(
                    _copyFilter(
                      financialYear: value == 'Current FY' ? null : value,
                      replaceFinancialYear: true,
                    ),
                  );
                },
              ),
              SizedBox(width: 8),
              _selector(
                icon: Icons.groups_2_outlined,
                label: 'Department',
                value: c.filter.department ?? 'All Departments',
                options: _uniqueOptions([
                  'All Departments',
                  c.filter.department,
                ]),
                onSelected: (value) {
                  c.applyFilter(
                    _copyFilter(
                      department: value == 'All Departments' ? null : value,
                      replaceDepartment: true,
                    ),
                  );
                },
              ),
            ];

            if (constraints.maxWidth >= 1180) {
              return Row(children: controls);
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: controls),
            );
          },
        ),
      ),
    );
  }

  Widget _selector({
    required IconData icon,
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
    bool locked = false,
  }) {
    return InkWell(
      onTap: locked
          ? () => _showInformation(
              'Company access is controlled by your MEMCO user permissions.',
            )
          : () => _openSelector(
              label: label,
              currentValue: value,
              options: options,
              onSelected: onSelected,
            ),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 176,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: context.compliance.surfaceMuted,
          border: Border.all(color: context.compliance.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: blue),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .45,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: .58),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Icon(
              locked ? Icons.lock_outline : Icons.unfold_more,
              size: 16,
              color: context.compliance.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar({required bool expanded}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = context.compliance.sidebar;

    return Material(
      color: surface,
      child: Column(
        children: [
          SizedBox(
            height: 86,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 16 : 14,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.compliance.primary,
                          context.compliance.primaryHover,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: blue.withValues(alpha: .22),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  if (expanded) ...[
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COMPLIANCE',
                            style: TextStyle(
                              color: blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Command Center',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: context.compliance.border),
          Expanded(
            child: expanded
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 18),
                    children: [
                      _navItem(
                        title: 'Executive Dashboard',
                        icon: Icons.dashboard_outlined,
                        tab: 0,
                      ),
                      _navGroup(
                        title: 'Compliance',
                        icon: Icons.fact_check_outlined,
                        tabs: const [1],
                        children: [
                          _NavDestination('Compliance Register', 1),
                          _NavDestination(
                            'Due Dates',
                            1,
                            statusFilter: 'overdue',
                          ),
                          _NavDestination('Filing Status', 1),
                        ],
                      ),
                      _navGroup(
                        title: 'Risk Management',
                        icon: Icons.warning_amber_outlined,
                        tabs: const [2],
                        children: [
                          _NavDestination('Risk Register', 2),
                          _NavDestination('Heat Map', 2),
                          _NavDestination('Mitigation Plans', 2),
                        ],
                      ),
                      _navGroup(
                        title: 'Workflow',
                        icon: Icons.account_tree_outlined,
                        tabs: const [3],
                        children: [
                          _NavDestination('Pending Approvals', 3),
                          _NavDestination('Workflow Designer', 3),
                        ],
                      ),
                      _navGroup(
                        title: 'Audit',
                        icon: Icons.assignment_turned_in_outlined,
                        tabs: const [4, 9],
                        children: [
                          _NavDestination('Internal Audit', 9),
                          _NavDestination('Audit Trail', 4),
                        ],
                      ),
                      _navGroup(
                        title: 'Government & Legal',
                        icon: Icons.account_balance_outlined,
                        tabs: const [5, 6],
                        children: [
                          _NavDestination('Government Notices', 5),
                          _NavDestination('Litigation & Cases', 6),
                        ],
                      ),
                      _navItem(
                        title: 'Documents',
                        icon: Icons.folder_outlined,
                        tab: 7,
                      ),
                      _navItem(
                        title: 'Policies',
                        icon: Icons.policy_outlined,
                        tab: 8,
                      ),
                      _navItem(
                        title: 'Reports & Analytics',
                        icon: Icons.analytics_outlined,
                        tab: 12,
                      ),
                      _navItem(
                        title: 'AI Assistant',
                        icon: Icons.auto_awesome_outlined,
                        tab: 13,
                      ),
                      _navItem(
                        title: 'Automation',
                        icon: Icons.schedule_outlined,
                        tab: 14,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(12, 18, 12, 7),
                        child: Text(
                          'ADMINISTRATION',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .9,
                            color: context.compliance.textTertiary,
                          ),
                        ),
                      ),
                      _navItem(
                        title: 'Security',
                        icon: Icons.security_outlined,
                        tab: 10,
                      ),
                      _navItem(
                        title: 'Notifications',
                        icon: Icons.notifications_active_outlined,
                        tab: 11,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _collapsedNav(Icons.dashboard_outlined, 0, 'Dashboard'),
                      _collapsedNav(Icons.fact_check_outlined, 1, 'Compliance'),
                      _collapsedNav(Icons.warning_amber_outlined, 2, 'Risk'),
                      _collapsedNav(Icons.account_tree_outlined, 3, 'Workflow'),
                      _collapsedNav(
                        Icons.assignment_turned_in_outlined,
                        9,
                        'Audit',
                      ),
                      _collapsedNav(
                        Icons.account_balance_outlined,
                        5,
                        'Notices',
                      ),
                      _collapsedNav(Icons.gavel_outlined, 6, 'Legal'),
                      _collapsedNav(Icons.folder_outlined, 7, 'Documents'),
                      _collapsedNav(Icons.analytics_outlined, 12, 'Analytics'),
                      _collapsedNav(Icons.auto_awesome_outlined, 13, 'AI'),
                      _collapsedNav(Icons.security_outlined, 10, 'Security'),
                    ],
                  ),
          ),
          if (expanded)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: blue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: blue),
                  SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enterprise GRC',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          c.companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterStrip() {
    return Container(
      width: double.infinity,
      color: blue.withValues(alpha: .055),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.filter_alt_outlined, size: 17, color: blue),
          Text(
            '${c.filter.count} active filter${c.filter.count == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (c.filter.search.isNotEmpty)
            Chip(label: Text('Search: ${c.filter.search}')),
          if (c.filter.branchId != null)
            Chip(label: Text('Branch: ${c.filter.branchId}')),
          if (c.filter.businessUnit != null)
            Chip(label: Text('Business Unit: ${c.filter.businessUnit}')),
          if (c.filter.financialYear != null)
            Chip(label: Text('FY: ${c.filter.financialYear}')),
          if (c.filter.department != null)
            Chip(label: Text('Department: ${c.filter.department}')),
          if (c.filter.status != null)
            Chip(label: Text('Status: ${c.filter.status}')),
          TextButton.icon(
            onPressed: c.clearFilter,
            icon: Icon(Icons.close, size: 16),
            label: Text('Clear all'),
          ),
        ],
      ),
    );
  }

  Widget _dashboard() {
    return StreamBuilder<List<RiskRegisterItem>>(
      stream: c.risks,
      builder: (context, riskSnapshot) {
        final risks = riskSnapshot.data ?? const <RiskRegisterItem>[];
        return StreamBuilder<List<GovernmentNotice>>(
          stream: c.notices,
          builder: (context, noticeSnapshot) {
            final notices = noticeSnapshot.data ?? const <GovernmentNotice>[];
            return StreamBuilder<List<LegalCase>>(
              stream: c.cases,
              builder: (context, caseSnapshot) {
                final cases = caseSnapshot.data ?? const <LegalCase>[];
                return StreamBuilder<List<AuditFinding>>(
                  stream: c.findings,
                  builder: (context, findingSnapshot) {
                    final findings =
                        findingSnapshot.data ?? const <AuditFinding>[];
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: c.audit,
                      builder: (context, activitySnapshot) {
                        final activity = activitySnapshot.data ?? const [];
                        return _page([
                          if (c.error != null) _error(c.error!),
                          _executiveSummary(),
                          SizedBox(height: 18),
                          _groupedKpis(
                            risks: risks,
                            notices: notices,
                            cases: cases,
                            findings: findings,
                          ),
                          SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1120;
                              final charts = _dashboardCharts(risks: risks);
                              final recent = _recentActivity(activity);
                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: charts),
                                    SizedBox(width: 14),
                                    Expanded(flex: 2, child: recent),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  charts,
                                  SizedBox(height: 14),
                                  recent,
                                ],
                              );
                            },
                          ),
                          SizedBox(height: 18),
                          _quickActionTiles(),
                        ]);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _compliance() => StreamBuilder<List<ComplianceRecord>>(
    stream: c.compliance,
    builder: (_, s) => _workspace(
      'Compliance Register',
      'Statutory, contractual and internal-control obligations',
      s.connectionState == ConnectionState.waiting,
      s.error,
      s.data?.isEmpty ?? true,
      _table(
        1250,
        const [
          'Reference',
          'Compliance',
          'Department',
          'Owner',
          'Due Date',
          'Status',
          'Risk',
          'Progress',
          'Exposure',
        ],
        (s.data ?? const [])
            .map(
              (v) => [
                Text(v.referenceNumber),
                Text(v.title),
                Text(v.department),
                Text(v.ownerName),
                Text(_date(v.dueDate)),
                _badge(
                  v.isOverdue ? 'overdue' : eccEnum(v.status),
                  v.isOverdue
                      ? red
                      : v.status == ComplianceStatus.completed
                      ? green
                      : orange,
                ),
                _badge(eccEnum(v.riskLevel), _riskColor(v.riskLevel)),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(value: v.progress.clamp(0, 1)),
                ),
                Text(_money(v.financialExposure)),
              ],
            )
            .toList(),
      ),
    ),
  );

  Widget _risk() => StreamBuilder<List<RiskRegisterItem>>(
    stream: c.risks,
    builder: (_, s) {
      final risks = s.data ?? const <RiskRegisterItem>[];
      return _page([
        _title(
          'Real-Time Risk Dashboard',
          'Inherent and residual enterprise risk exposure',
        ),
        if (s.connectionState == ConnectionState.waiting)
          LinearProgressIndicator(),
        if (s.hasError) _error('${s.error}'),
        LayoutBuilder(
          builder: (_, box) {
            final matrix = _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heading('Risk Matrix', Icons.grid_view),
                  SizedBox(height: 12),
                  SizedBox(height: 320, child: _RiskMatrix(risks: risks)),
                ],
              ),
            );
            final priorities = _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heading('Residual Risk Priorities', Icons.priority_high),
                  ...risks
                      .take(8)
                      .map(
                        (v) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _riskColor(
                              v.residualLevel,
                            ).withValues(alpha: .12),
                            child: Text('${v.residualScore}'),
                          ),
                          title: Text(v.title),
                          subtitle: Text('${v.department} • ${v.ownerName}'),
                          trailing: _badge(
                            eccEnum(v.residualLevel),
                            _riskColor(v.residualLevel),
                          ),
                        ),
                      ),
                ],
              ),
            );
            if (box.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: matrix),
                  SizedBox(width: 14),
                  Expanded(flex: 2, child: priorities),
                ],
              );
            }
            return Column(children: [matrix, SizedBox(height: 14), priorities]);
          },
        ),
        SizedBox(height: 14),
        _table(
          1300,
          const [
            'Risk',
            'Department',
            'Owner',
            'Inherent',
            'Residual',
            'Financial',
            'Penalty',
            'Legal',
            'Review Date',
            'Mitigation',
          ],
          risks
              .map(
                (v) => [
                  Text(v.title),
                  Text(v.department),
                  Text(v.ownerName),
                  Text('${v.inherentScore}'),
                  _badge(
                    '${v.residualScore} ${eccEnum(v.residualLevel)}',
                    _riskColor(v.residualLevel),
                  ),
                  Text(_money(v.financialExposure)),
                  Text(_money(v.penaltyExposure)),
                  Text(_money(v.legalExposure)),
                  Text(_date(v.reviewDate)),
                  Text(
                    v.mitigationPlan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
              .toList(),
        ),
      ]);
    },
  );

  Widget _workflows() => StreamBuilder<List<ApprovalWorkflow>>(
    stream: c.workflows,
    builder: (_, s) {
      final data = s.data ?? const <ApprovalWorkflow>[];
      return _workspace(
        'Workflow Engine',
        'Unlimited approval levels, reminders, delegation and escalation',
        s.connectionState == ConnectionState.waiting,
        s.error,
        data.isEmpty,
        Column(
          children: data.map((w) {
            final levels = [...w.levels]
              ..sort((a, b) => a.order.compareTo(b.order));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            w.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _badge(
                          w.enabled ? 'Active' : 'Inactive',
                          w.enabled ? green : context.compliance.textTertiary,
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < levels.length; i++) ...[
                            Container(
                              width: 160,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: blue.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: blue,
                                    child: Text(
                                      '${levels[i].order}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    levels[i].name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    levels[i].approverRole,
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (i != levels.length - 1)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    },
  );

  Widget _audit() {
    if (!c.permissions.viewAudit) {
      return Center(child: Text('Audit-trail permission is required.'));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: c.audit,
      builder: (_, s) => _workspace(
        'Audit Trail',
        'Record creation, update, deletion, approval, print and export activity',
        s.connectionState == ConnectionState.waiting,
        s.error,
        s.data?.isEmpty ?? true,
        Column(
          children: (s.data ?? const [])
              .map(
                (v) => ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(
                    '${v['userName'] ?? ''} ${v['action'] ?? ''} ${v['entityType'] ?? ''}',
                  ),
                  subtitle: Text('Record: ${v['entityId'] ?? ''}'),
                  trailing: Text(_dynamicDate(v['timestamp'])),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _notices() => StreamBuilder<List<GovernmentNotice>>(
    stream: c.notices,
    builder: (context, snapshot) {
      final notices = snapshot.data ?? const <GovernmentNotice>[];
      GovernmentNotice? selected;
      for (final notice in notices) {
        if (notice.id == _selectedNoticeId) {
          selected = notice;
          break;
        }
      }
      selected ??= notices.isEmpty ? null : notices.first;

      return _page([
        _title(
          'Government Notice Management',
          'Master-detail workspace for notices, replies, hearings and evidence',
        ),
        if (snapshot.connectionState == ConnectionState.waiting)
          LinearProgressIndicator(),
        if (snapshot.hasError) _error('${snapshot.error}'),
        if (!snapshot.hasError && notices.isEmpty)
          _card(
            child: Padding(
              padding: EdgeInsets.all(34),
              child: Center(
                child: Text('No notices match the active filters.'),
              ),
            ),
          )
        else if (notices.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              if (!wide) {
                return _card(
                  child: Column(
                    children: notices
                        .map(
                          (notice) => _noticeListTile(
                            notice,
                            onTap: () => _showNoticeDetails(notice),
                          ),
                        )
                        .toList(),
                  ),
                );
              }

              return SizedBox(
                height: math
                    .max(560, MediaQuery.sizeOf(context).height - 260)
                    .toDouble(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 360,
                      child: _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Notices',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _badge('${notices.length}', blue),
                              ],
                            ),
                            SizedBox(height: 10),
                            Expanded(
                              child: ListView.separated(
                                itemCount: notices.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: context.compliance.border,
                                ),
                                itemBuilder: (context, index) {
                                  final notice = notices[index];
                                  return _noticeListTile(
                                    notice,
                                    selected: notice.id == selected?.id,
                                    onTap: () {
                                      setState(() {
                                        _selectedNoticeId = notice.id;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _card(
                        child: selected == null
                            ? Center(child: Text('Select a notice'))
                            : _noticeDetail(selected),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ]);
    },
  );

  Widget _legal() => StreamBuilder<List<LegalCase>>(
    stream: c.cases,
    builder: (_, s) => _workspace(
      'Legal Case Management',
      'Courts, authorities, acts, hearings, orders and expenses',
      s.connectionState == ConnectionState.waiting,
      s.error,
      s.data?.isEmpty ?? true,
      _table(
        1200,
        const [
          'Case No.',
          'Court',
          'Authority',
          'Act',
          'Section',
          'Advocate',
          'Type',
          'Hearing',
          'Status',
          'Expenses',
        ],
        (s.data ?? const [])
            .map(
              (v) => [
                Text(v.caseNumber),
                Text(v.court),
                Text(v.authority),
                Text(v.act),
                Text(v.section),
                Text(v.advocate),
                Text(v.caseType),
                Text(_date(v.hearingDate)),
                _badge(eccEnum(v.status), purple),
                Text(_money(v.expenses)),
              ],
            )
            .toList(),
      ),
    ),
  );

  Widget _documents() => StreamBuilder<List<Map<String, dynamic>>>(
    stream: c.documents,
    builder: (_, s) => _workspace(
      'Enterprise Document Repository',
      'Versioned evidence, policies, notices, cases and signed records',
      s.connectionState == ConnectionState.waiting,
      s.error,
      s.data?.isEmpty ?? true,
      LayoutBuilder(
        builder: (_, box) {
          final width = box.maxWidth >= 1000
              ? (box.maxWidth - 36) / 4
              : box.maxWidth >= 700
              ? (box.maxWidth - 24) / 3
              : box.maxWidth >= 480
              ? (box.maxWidth - 12) / 2
              : box.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: (s.data ?? const [])
                .map(
                  (v) => SizedBox(
                    width: width,
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            child: Icon(Icons.insert_drive_file_outlined),
                          ),
                          SizedBox(height: 10),
                          Text(
                            v['title']?.toString() ?? 'Document',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(v['originalFileName']?.toString() ?? ''),
                          SizedBox(height: 8),
                          Text(
                            'Version ${v['version'] ?? 1} • ${v['category'] ?? ''}',
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ),
  );

  Widget _policies() => StreamBuilder<List<PolicyDocument>>(
    stream: c.policies,
    builder: (_, s) => _workspace(
      'Policy Management',
      'Policies, SOPs, ISO documents, controls and acknowledgement',
      s.connectionState == ConnectionState.waiting,
      s.error,
      s.data?.isEmpty ?? true,
      _table(
        1000,
        const [
          'Policy',
          'Category',
          'Version',
          'Owner',
          'Review Date',
          'Status',
          'Acknowledgement',
        ],
        (s.data ?? const [])
            .map(
              (v) => [
                Text(v.title),
                Text(v.category),
                Text(v.version),
                Text(v.ownerName),
                Text(_date(v.reviewDate)),
                _badge(
                  eccEnum(v.status),
                  v.status == PolicyStatus.published ? green : orange,
                ),
                Text(
                  v.acknowledgementRequired
                      ? '${v.acknowledgedUserIds.length} acknowledged'
                      : 'Not required',
                ),
              ],
            )
            .toList(),
      ),
    ),
  );

  Widget _findings() => StreamBuilder<List<AuditFinding>>(
    stream: c.findings,
    builder: (_, s) => _workspace(
      'Internal Audit & CAPA',
      'Audit observations, corrective action, evidence and closure',
      s.connectionState == ConnectionState.waiting,
      s.error,
      s.data?.isEmpty ?? true,
      _table(
        1100,
        const [
          'Observation',
          'Risk',
          'Corrective Action',
          'CAPA',
          'Responsible',
          'Target Date',
          'Status',
        ],
        (s.data ?? const [])
            .map(
              (v) => [
                Text(v.observation),
                _badge(eccEnum(v.riskLevel), _riskColor(v.riskLevel)),
                Text(v.correctiveAction),
                Text(v.capa),
                Text(v.responsiblePersonName),
                Text(_date(v.targetDate)),
                _badge(
                  eccEnum(v.status),
                  v.status == AuditFindingStatus.closed ? green : orange,
                ),
              ],
            )
            .toList(),
      ),
    ),
  );

  Widget _security() {
    const items = [
      ('Two-Factor Authentication', Icons.phonelink_lock_outlined),
      ('Single Sign-On', Icons.login_outlined),
      ('Password Policy', Icons.password_outlined),
      ('Session Timeout', Icons.timer_outlined),
      ('Device Management', Icons.devices_outlined),
      ('Encryption', Icons.enhanced_encryption_outlined),
      ('Backup', Icons.backup_outlined),
      ('Disaster Recovery', Icons.restore_page_outlined),
      ('Login History', Icons.manage_history_outlined),
      ('Security Alerts', Icons.notification_important),
    ];
    return _page([
      _title(
        'Enterprise Security',
        'Identity, device, session, encryption, backup and recovery controls',
      ),
      LayoutBuilder(
        builder: (_, box) {
          final width = box.maxWidth >= 900
              ? (box.maxWidth - 24) / 3
              : box.maxWidth >= 600
              ? (box.maxWidth - 12) / 2
              : box.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map(
                  (v) => SizedBox(
                    width: width,
                    child: _card(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: blue.withValues(alpha: .1),
                          child: Icon(v.$2, color: blue),
                        ),
                        title: Text(v.$1),
                        subtitle: Text(
                          'Configuration governed by MEMCO identity and security backend',
                        ),
                        trailing: Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ]);
  }

  Widget _notifications() {
    const items = [
      'Email',
      'WhatsApp',
      'SMS',
      'Desktop Notification',
      'Mobile Push',
      'Microsoft Teams',
      'Slack',
      'Webhook',
    ];
    return _page([
      _title(
        'Notification Engine',
        'Enterprise delivery channels and scheduler integrations',
      ),
      LayoutBuilder(
        builder: (_, box) {
          final width = box.maxWidth >= 900
              ? (box.maxWidth - 24) / 3
              : box.maxWidth >= 600
              ? (box.maxWidth - 12) / 2
              : box.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map(
                  (v) => SizedBox(
                    width: width,
                    child: _card(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: blue.withValues(alpha: .1),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: blue,
                          ),
                        ),
                        title: Text(v),
                        subtitle: Text(
                          widget.notificationService == null
                              ? 'Provider configuration required'
                              : 'Connected to MEMCO communication service',
                        ),
                        trailing: Icon(
                          widget.notificationService == null
                              ? Icons.link_off
                              : Icons.check_circle,
                          color: widget.notificationService == null
                              ? orange
                              : green,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ]);
  }

  Widget _analytics() {
    return _page([
      _title(
        'Enterprise Analytics',
        'Compliance, risk, audit, legal, notice and performance trends',
      ),
      LayoutBuilder(
        builder: (_, box) {
          final a = _gauge(
            'Compliance Completion %',
            c.metrics.healthPercent,
            green,
          );
          final b = _gauge(
            'Risk-Control Effectiveness',
            math.max(0, 100 - c.metrics.criticalRisks * 8).toDouble(),
            red,
          );
          return box.maxWidth >= 850
              ? Row(
                  children: [
                    Expanded(child: a),
                    SizedBox(width: 14),
                    Expanded(child: b),
                  ],
                )
              : Column(children: [a, SizedBox(height: 14), b]);
        },
      ),
      SizedBox(height: 14),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Exposure Trend', Icons.show_chart),
            SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: CustomPaint(
                painter: _TrendPainter(
                  <double>[
                    c.metrics.financialExposure.toDouble(),
                    c.metrics.penaltyExposure.toDouble(),
                    c.metrics.legalExposure.toDouble(),
                  ],
                  blue,
                  context.compliance.border,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _assistantPanel() {
    final answer = c.assistantAnswer;
    return _page([
      _title(
        'AI Compliance Assistant',
        'Natural-language search over governed enterprise data',
      ),
      _card(
        child: Column(
          children: [
            TextField(
              controller: _assistant,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    'Ask: Show overdue GST filings, summarize pending legal cases, suggest risk mitigation...',
                prefixIcon: Icon(Icons.auto_awesome),
                border: OutlineInputBorder(),
              ),
              onSubmitted: c.ask,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => c.ask(_assistant.text),
                  icon: Icon(Icons.send),
                  label: Text('Run Query'),
                ),
                SizedBox(width: 8),
                TextButton(onPressed: _assistant.clear, child: Text('Clear')),
              ],
            ),
          ],
        ),
      ),
      if (answer != null) ...[
        SizedBox(height: 14),
        _card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.auto_awesome)),
            title: Text(
              answer.title,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(answer.summary),
          ),
        ),
      ],
    ]);
  }

  Widget _automation() {
    const items = [
      ('Auto Reminder', 'Rule-based due-date and approval reminders'),
      ('Auto Escalation', 'Escalate overdue tasks and approval breaches'),
      ('Auto Assignment', 'Assign records by department, category and owner'),
      ('Recurring Compliance', 'Generate obligations from approved templates'),
      ('Recurring Reports', 'Schedule management and board reporting'),
      ('Recurring Audits', 'Create periodic audit plans and checklists'),
      ('Recurring Notices', 'Track recurring statutory correspondence'),
    ];
    return _page([
      _title(
        'Automation & Scheduler',
        'Backend-controlled recurrence, reminder and escalation',
      ),
      ...items.map(
        (v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(Icons.schedule)),
              title: Text(v.$1, style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(v.$2),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
      ),
    ]);
  }

  String get _currentPageTitle {
    const titles = [
      'Executive Dashboard',
      'Compliance Register',
      'Risk Management',
      'Workflow Engine',
      'Audit Trail',
      'Government Notices',
      'Legal Case Management',
      'Document Repository',
      'Policy Management',
      'Internal Audit & CAPA',
      'Security & Access',
      'Notification Engine',
      'Reports & Analytics',
      'AI Compliance Assistant',
      'Automation & Scheduler',
    ];
    if (c.selectedTab < 0 || c.selectedTab >= titles.length) {
      return 'Enterprise Compliance';
    }
    return titles[c.selectedTab];
  }

  Widget _commandSearchButton() {
    return InkWell(
      onTap: _openCommandPalette,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 300,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.compliance.surfaceMuted,
          border: Border.all(color: context.compliance.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 19),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Search commands, notices, risks...',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: context.compliance.surfaceMuted,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Ctrl K',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationButton() {
    final count = c.metrics.governmentNotices + c.metrics.criticalRisks;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => c.selectTab(11),
          icon: Icon(Icons.notifications_none),
        ),
        if (count > 0)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: red,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navItem({
    required String title,
    required IconData icon,
    required int tab,
  }) {
    final selected = c.selectedTab == tab;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: () => _navigate(tab),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: selected ? blue.withValues(alpha: .1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: selected ? blue : null),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? blue : null,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navGroup({
    required String title,
    required IconData icon,
    required List<int> tabs,
    required List<_NavDestination> children,
  }) {
    final selected = tabs.contains(c.selectedTab);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>('nav-$title'),
        initiallyExpanded: selected,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 11),
        childrenPadding: const EdgeInsets.only(left: 18, bottom: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: selected ? blue.withValues(alpha: .045) : null,
        collapsedBackgroundColor: Colors.transparent,
        leading: Icon(icon, size: 19, color: selected ? blue : null),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? blue : null,
          ),
        ),
        children: children
            .map(
              (destination) => ListTile(
                dense: true,
                visualDensity: VisualDensity(vertical: -2),
                minLeadingWidth: 14,
                leading: Icon(
                  c.selectedTab == destination.tab
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 13,
                  color: c.selectedTab == destination.tab
                      ? blue
                      : context.compliance.textTertiary,
                ),
                title: Text(
                  destination.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: c.selectedTab == destination.tab
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                onTap: () => _navigate(
                  destination.tab,
                  statusFilter: destination.statusFilter,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _collapsedNav(IconData icon, int tab, String label) {
    final selected = c.selectedTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => _navigate(tab),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: selected ? blue.withValues(alpha: .11) : null,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: selected ? blue : null),
          ),
        ),
      ),
    );
  }

  void _navigate(int tab, {String? statusFilter}) {
    if (statusFilter != null) {
      c.applyFilter(_copyFilter(status: statusFilter, replaceStatus: true));
    }
    c.selectTab(tab);
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  CommandCenterFilter _copyFilter({
    String? branchId,
    bool replaceBranch = false,
    String? businessUnit,
    bool replaceBusinessUnit = false,
    String? financialYear,
    bool replaceFinancialYear = false,
    String? department,
    bool replaceDepartment = false,
    String? status,
    bool replaceStatus = false,
  }) {
    return CommandCenterFilter(
      search: c.filter.search,
      branchId: replaceBranch ? branchId : c.filter.branchId,
      businessUnit: replaceBusinessUnit ? businessUnit : c.filter.businessUnit,
      financialYear: replaceFinancialYear
          ? financialYear
          : c.filter.financialYear,
      department: replaceDepartment ? department : c.filter.department,
      status: replaceStatus ? status : c.filter.status,
      riskLevel: c.filter.riskLevel,
      dateFrom: c.filter.dateFrom,
      dateTo: c.filter.dateTo,
    );
  }

  List<String> _uniqueOptions(List<String?> values) {
    final result = <String>[];
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty && !result.contains(trimmed)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  List<String> _financialYears() {
    final now = DateTime.now();
    final start = now.month >= 4 ? now.year : now.year - 1;
    return [
      'Current FY',
      for (var offset = -2; offset <= 2; offset++)
        'FY ${start + offset}-${(start + offset + 1).toString().substring(2)}',
    ];
  }

  Future<void> _openSelector({
    required String label,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) async {
    final search = TextEditingController();
    var query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = options
                .where(
                  (value) => value.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              title: Row(
                children: [
                  Expanded(child: Text('Select $label')),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 430,
                child: Column(
                  children: [
                    TextField(
                      controller: search,
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() => query = value);
                      },
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search $label...',
                        border: OutlineInputBorder(),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  search.clear();
                                  setDialogState(() => query = '');
                                },
                                icon: Icon(Icons.close),
                              ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text('No matching values found.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final value = filtered[index];
                                final active = value == currentValue;
                                return ListTile(
                                  leading: Icon(
                                    active
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: active
                                        ? blue
                                        : context.compliance.textTertiary,
                                  ),
                                  title: Text(value),
                                  selected: active,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, value),
                                );
                              },
                            ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: .055),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$label values are controlled by MEMCO master data and your role access.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    search.dispose();
    if (selected != null) {
      onSelected(selected);
    }
  }

  Future<void> _openCommandPalette() async {
    final search = TextEditingController();
    var query = '';
    final commands = <_CommandAction>[
      _CommandAction(
        'Open executive dashboard',
        'Dashboard',
        Icons.dashboard_outlined,
        () => _navigate(0),
      ),
      _CommandAction(
        'Find overdue compliance',
        'Compliance',
        Icons.event_busy_outlined,
        () {
          c.applyFilter(_copyFilter(status: 'overdue', replaceStatus: true));
          _navigate(1);
        },
      ),
      _CommandAction(
        'Open risk heat map',
        'Risk Management',
        Icons.grid_view_outlined,
        () => _navigate(2),
      ),
      _CommandAction(
        'Open pending approvals',
        'Workflow',
        Icons.approval_outlined,
        () => _navigate(3),
      ),
      _CommandAction(
        'Open government notices',
        'Government',
        Icons.mark_email_unread_outlined,
        () => _navigate(5),
      ),
      _CommandAction(
        'Open legal cases',
        'Legal',
        Icons.gavel_outlined,
        () => _navigate(6),
      ),
      _CommandAction(
        'Upload or find documents',
        'Documents',
        Icons.folder_outlined,
        () => _navigate(7),
      ),
      _CommandAction(
        'Open internal audit findings',
        'Audit',
        Icons.assignment_turned_in_outlined,
        () => _navigate(9),
      ),
      _CommandAction(
        'Generate management analytics',
        'Reports',
        Icons.analytics_outlined,
        () => _navigate(12),
      ),
      _CommandAction(
        'Ask the AI compliance assistant',
        'AI Assistant',
        Icons.auto_awesome_outlined,
        () => _navigate(13),
      ),
    ];

    final action = await showDialog<_CommandAction>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = commands
                .where(
                  (command) =>
                      command.title.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      command.category.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
            return Dialog(
              alignment: Alignment(0, -.65),
              insetPadding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              child: SizedBox(
                width: 650,
                height: 480,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: search,
                        autofocus: true,
                        onChanged: (value) {
                          setDialogState(() => query = value);
                        },
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search commands and records...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.compliance.border),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text('No commands found.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final command = filtered[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: blue.withValues(alpha: .1),
                                    child: Icon(command.icon, color: blue),
                                  ),
                                  title: Text(command.title),
                                  subtitle: Text(command.category),
                                  trailing: Icon(Icons.keyboard_return),
                                  onTap: () =>
                                      Navigator.pop(dialogContext, command),
                                );
                              },
                            ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: context.compliance.surfaceMuted,
                      child: Text(
                        'Tip: Use Ctrl+K anywhere in the Command Center.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    search.dispose();
    action?.run();
  }

  Widget _executiveSummary() {
    final metrics = c.metrics;
    final score = metrics.score.clamp(0, 100).toDouble();
    final color = _scoreColor(score);
    final healthLabel = score >= 90
        ? 'Excellent'
        : score >= 75
        ? 'Good'
        : score >= 55
        ? 'Attention Required'
        : 'Critical';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [blue.withValues(alpha: .13), Theme.of(context).cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: blue.withValues(alpha: .16)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          final health = Row(
            children: [
              SizedBox(
                width: 138,
                height: 138,
                child: CustomPaint(
                  painter: _GaugePainter(score, color),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          score.toStringAsFixed(0),
                          style: TextStyle(
                            color: color,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'SCORE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Compliance Health',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 7),
                        Text(
                          healthLabel,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      metrics.totalCompliance == 0
                          ? 'No live compliance obligations are available for the selected global scope.'
                          : '${metrics.completed} of ${metrics.totalCompliance} obligations are complete. ${metrics.overdue} require overdue attention.',
                      style: TextStyle(height: 1.45),
                    ),
                    SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: metrics.healthPercent.clamp(0, 100) / 100,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(9),
                      color: color,
                      backgroundColor: color.withValues(alpha: .13),
                    ),
                  ],
                ),
              ),
            ],
          );

          final priority = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryStat(
                'Pending',
                '${metrics.pending}',
                Icons.pending_actions,
                orange,
                () => _navigate(1),
              ),
              _summaryStat(
                'Overdue',
                '${metrics.overdue}',
                Icons.event_busy_outlined,
                red,
                () {
                  c.applyFilter(
                    _copyFilter(status: 'overdue', replaceStatus: true),
                  );
                  _navigate(1);
                },
              ),
              _summaryStat(
                'Notices',
                '${metrics.governmentNotices}',
                Icons.mark_email_unread_outlined,
                purple,
                () => _navigate(5),
              ),
            ],
          );

          if (wide) {
            return Row(
              children: [
                Expanded(flex: 3, child: health),
                SizedBox(width: 24),
                SizedBox(width: 330, child: priority),
              ],
            );
          }
          return Column(children: [health, SizedBox(height: 20), priority]);
        },
      ),
    );
  }

  Widget _summaryStat(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .085),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(height: 9),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(title, style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _groupedKpis({
    required List<RiskRegisterItem> risks,
    required List<GovernmentNotice> notices,
    required List<LegalCase> cases,
    required List<AuditFinding> findings,
  }) {
    final low = risks
        .where((risk) => risk.residualLevel == RiskLevel.low)
        .length;
    final medium = risks
        .where((risk) => risk.residualLevel == RiskLevel.medium)
        .length;
    final high = risks
        .where((risk) => risk.residualLevel == RiskLevel.high)
        .length;
    final critical = risks
        .where((risk) => risk.residualLevel == RiskLevel.critical)
        .length;
    final today = DateTime.now();
    final next30 = today.add(Duration(days: 30));
    final hearings = cases
        .where(
          (legalCase) =>
              !legalCase.hearingDate.isBefore(today) &&
              legalCase.hearingDate.isBefore(next30),
        )
        .length;
    final openFindings = findings
        .where((finding) => finding.status != AuditFindingStatus.closed)
        .length;
    final closedFindings = findings.length - openFindings;
    final actionInProgress = findings
        .where(
          (finding) =>
              finding.status == AuditFindingStatus.actionInProgress ||
              finding.status == AuditFindingStatus.evidenceSubmitted,
        )
        .length;

    final groups = <Widget>[
      _kpiGroup(
        title: 'Compliance',
        icon: Icons.fact_check_outlined,
        color: blue,
        items: [
          _MiniKpi('Total', '${c.metrics.totalCompliance}', blue, 1),
          _MiniKpi('Pending', '${c.metrics.pending}', orange, 1),
          _MiniKpi('Completed', '${c.metrics.completed}', green, 1),
          _MiniKpi('Overdue', '${c.metrics.overdue}', red, 1),
        ],
      ),
      _kpiGroup(
        title: 'Risk',
        icon: Icons.warning_amber_outlined,
        color: red,
        items: [
          _MiniKpi('Critical', '$critical', red, 2),
          _MiniKpi('High', '$high', context.compliance.warning, 2),
          _MiniKpi('Medium', '$medium', orange, 2),
          _MiniKpi('Low', '$low', green, 2),
        ],
      ),
      _kpiGroup(
        title: 'Legal & Notices',
        icon: Icons.account_balance_outlined,
        color: purple,
        items: [
          _MiniKpi('Notices', '${notices.length}', purple, 5),
          _MiniKpi('Open Cases', '${c.metrics.openLegalCases}', purple, 6),
          _MiniKpi('Hearings', '$hearings', orange, 6),
          _MiniKpi('Penalty', _money(c.metrics.penaltyExposure), red, 5),
        ],
      ),
      _kpiGroup(
        title: 'Internal Audit',
        icon: Icons.assignment_turned_in_outlined,
        color: context.compliance.audit,
        items: [
          _MiniKpi(
            'Findings',
            '${findings.length}',
            context.compliance.audit,
            9,
          ),
          _MiniKpi('CAPA Open', '$actionInProgress', orange, 9),
          _MiniKpi('Open', '$openFindings', red, 9),
          _MiniKpi('Closed', '$closedFindings', green, 9),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1240
            ? 2
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: groups
              .map((group) => SizedBox(width: width, child: group))
              .toList(),
        );
      },
    );
  }

  Widget _kpiGroup({
    required String title,
    required IconData icon,
    required Color color,
    required List<_MiniKpi> items,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: items
                .map((item) => Expanded(child: _compactKpi(item)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _compactKpi(_MiniKpi item) {
    return InkWell(
      onTap: () => _navigate(item.tab),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: item.color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 3),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCharts({required List<RiskRegisterItem> risks}) {
    final complianceCounts = [
      c.metrics.completed,
      c.metrics.pending,
      c.metrics.overdue,
    ];
    final riskCounts = [
      risks.where((risk) => risk.residualLevel == RiskLevel.low).length,
      risks.where((risk) => risk.residualLevel == RiskLevel.medium).length,
      risks.where((risk) => risk.residualLevel == RiskLevel.high).length,
      risks.where((risk) => risk.residualLevel == RiskLevel.critical).length,
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Compliance & Risk Distribution', Icons.donut_large),
          SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 660;
              final status = _distributionPanel(
                title: 'Compliance Status',
                values: complianceCounts,
                labels: const ['Completed', 'Pending', 'Overdue'],
                colors: <Color>[green, orange, red],
              );
              final risk = _riskBarPanel(riskCounts);
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: status),
                    SizedBox(width: 18),
                    Expanded(child: risk),
                  ],
                );
              }
              return Column(children: [status, SizedBox(height: 18), risk]);
            },
          ),
        ],
      ),
    );
  }

  Widget _distributionPanel({
    required String title,
    required List<int> values,
    required List<String> labels,
    required List<Color> colors,
  }) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: CustomPaint(
                painter: _DonutPainter(
                  values,
                  colors,
                  context.compliance.border,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('RECORDS', style: TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                children: List.generate(labels.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: colors[index],
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(labels[index])),
                        Text(
                          '${values[index]}',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        if (total == 0)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No live records in the selected scope.',
              style: TextStyle(
                fontSize: 11,
                color: context.compliance.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _riskBarPanel(List<int> values) {
    const labels = ['Low', 'Medium', 'High', 'Critical'];
    final colors = <Color>[green, orange, context.compliance.warning, red];
    final maxValue = values.fold<int>(
      1,
      (current, value) => value > current ? value : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Residual Risk', style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 18),
        ...List.generate(labels.length, (index) {
          final value = values[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(width: 58, child: Text(labels[index])),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value / maxValue,
                      minHeight: 12,
                      color: colors[index],
                      backgroundColor: colors[index].withValues(alpha: .1),
                    ),
                  ),
                ),
                SizedBox(width: 9),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _recentActivity(List<Map<String, dynamic>> activity) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _heading('Recent Activity', Icons.history)),
              TextButton(
                onPressed: () => _navigate(4),
                child: Text('View audit trail'),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (activity.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 38,
                      color: context.compliance.textTertiary,
                    ),
                    SizedBox(height: 9),
                    Text(
                      'No recent governed activity is available.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...activity.take(7).map((entry) {
              final action = entry['action']?.toString() ?? 'updated';
              final entity = entry['entityType']?.toString() ?? 'record';
              final user = entry['userName']?.toString() ?? 'User';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.history, size: 17, color: blue),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$user ${_titleCase(action)} ${_titleCase(entity)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _dynamicDate(entry['timestamp']),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.compliance.textTertiary,
                            ),
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

  Widget _quickActionTiles() {
    final actions = [
      _QuickAction('Risk Register', Icons.warning_amber_outlined, red, 2),
      _QuickAction('Workflow', Icons.account_tree_outlined, blue, 3),
      _QuickAction(
        'Government Notices',
        Icons.account_balance_outlined,
        purple,
        5,
      ),
      _QuickAction('Legal Cases', Icons.gavel_outlined, purple, 6),
      _QuickAction('Documents', Icons.folder_outlined, blue, 7),
      _QuickAction('AI Assistant', Icons.auto_awesome_outlined, blue, 13),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Quick Actions',
          'Open high-frequency GRC workspaces without leaving the command center',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 6
                : constraints.maxWidth >= 720
                ? 3
                : 2;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: width,
                      child: InkWell(
                        onTap: () => _navigate(action.tab),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            border: Border.all(
                              color: context.compliance.border,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: action.color.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(action.icon, color: action.color),
                              ),
                              SizedBox(height: 14),
                              Text(
                                action.title,
                                maxLines: 2,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 5),
                              Icon(Icons.arrow_forward, size: 17),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _noticeListTile(
    GovernmentNotice notice, {
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final overdue = notice.isOverdue;
    final color = overdue
        ? red
        : notice.status == NoticeStatus.resolved ||
              notice.status == NoticeStatus.closed
        ? green
        : orange;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? blue.withValues(alpha: .08) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.description_outlined, color: color, size: 19),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.noticeNumber,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    notice.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '${notice.authority} • Due ${_date(notice.replyDueDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.compliance.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 7),
            _badge(overdue ? 'overdue' : eccEnum(notice.status), color),
          ],
        ),
      ),
    );
  }

  Widget _noticeDetail(GovernmentNotice notice) {
    final overdue = notice.isOverdue;
    final statusColor = overdue
        ? red
        : notice.status == NoticeStatus.resolved ||
              notice.status == NoticeStatus.closed
        ? green
        : orange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: purple.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.account_balance_outlined, color: purple),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.subject,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text('${notice.noticeNumber} • ${notice.authority}'),
                ],
              ),
            ),
            _badge(overdue ? 'overdue' : eccEnum(notice.status), statusColor),
          ],
        ),
        SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _noticeInfo('Issue Date', _date(notice.issueDate)),
            _noticeInfo('Reply Due', _date(notice.replyDueDate)),
            _noticeInfo(
              'Hearing Date',
              notice.hearingDate == null
                  ? 'Not scheduled'
                  : _date(notice.hearingDate!),
            ),
            _noticeInfo(
              'Assigned Lawyer',
              notice.assignedLawyer.isEmpty
                  ? 'Unassigned'
                  : notice.assignedLawyer,
            ),
          ],
        ),
        SizedBox(height: 20),
        Divider(color: context.compliance.border),
        SizedBox(height: 12),
        Text('Case Workspace', style: TextStyle(fontWeight: FontWeight.w900)),
        SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _workspaceCounter(
              'Documents',
              notice.documents.length,
              Icons.folder_outlined,
            ),
            _workspaceCounter(
              'Replies',
              notice.replies.length,
              Icons.reply_outlined,
            ),
            _workspaceCounter(
              'Orders',
              notice.orders.length,
              Icons.balance_outlined,
            ),
            _workspaceCounter(
              'Appeals',
              notice.appeals.length,
              Icons.gavel_outlined,
            ),
          ],
        ),
        SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: blue.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'Use the linked document, reply, hearing and audit actions to maintain a complete regulatory evidence trail.',
            style: TextStyle(height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _noticeInfo(String label, String value) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.compliance.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .45,
              color: context.compliance.textTertiary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _workspaceCounter(String label, int count, IconData icon) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: blue),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count', style: TextStyle(fontWeight: FontWeight.w900)),
              Text(label, style: TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showNoticeDetails(GovernmentNotice notice) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(child: _noticeDetail(notice)),
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

  void _showInformation(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'U';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  Widget _workspace(
    String title,
    String subtitle,
    bool loading,
    Object? error,
    bool empty,
    Widget child,
  ) {
    return _page([
      _title(title, subtitle),
      if (loading) LinearProgressIndicator(),
      if (error != null)
        _error('$error')
      else if (!loading && empty)
        _card(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('No records match the active filters.')),
          ),
        )
      else
        child,
    ]);
  }

  Widget _page(List<Widget> children) => RefreshIndicator(
    onRefresh: c.refresh,
    child: ListView(padding: const EdgeInsets.all(18), children: children),
  );

  Widget _title(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 2),
        Text(subtitle),
      ],
    ),
  );

  Widget _card({required Widget child}) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: context.compliance.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _heading(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: blue, size: 19),
      SizedBox(width: 8),
      Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    ],
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      _titleCase(text),
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );

  Widget _table(
    double minWidth,
    List<String> columns,
    List<List<Widget>> rows,
  ) => _card(
    child: Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              blue.withValues(alpha: .06),
            ),
            columns: columns
                .map(
                  (v) => DataColumn(
                    label: Text(
                      v,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
                .toList(),
            rows: rows
                .map((r) => DataRow(cells: r.map((v) => DataCell(v)).toList()))
                .toList(),
          ),
        ),
      ),
    ),
  );

  Widget _gauge(String title, double value, Color color) => _card(
    child: Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _GaugePainter(value.clamp(0, 100).toDouble(), color),
            child: Center(
              child: Text(
                '${value.clamp(0, 100).toStringAsFixed(0)}%',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
              ),
            ),
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ],
    ),
  );

  Widget _error(String message) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: red.withValues(alpha: .08),
      border: Border.all(color: red.withValues(alpha: .2)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: red),
        SizedBox(width: 8),
        Expanded(child: Text(message)),
        TextButton(onPressed: c.refresh, child: Text('Retry')),
      ],
    ),
  );

  void _export() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.onExport == null
              ? 'Connect the existing MEMCO export service to enable governed PDF, Excel, Word and PowerPoint exports.'
              : 'Export callback is connected to the module entry.',
        ),
      ),
    );
  }

  Color _scoreColor(double score) => score >= 90
      ? green
      : score >= 70
      ? blue
      : score >= 50
      ? orange
      : red;
  Color _riskColor(RiskLevel v) => switch (v) {
    RiskLevel.low => green,
    RiskLevel.medium => orange,
    RiskLevel.high => context.compliance.warning,
    RiskLevel.critical => red,
  };
  String _date(DateTime v) =>
      '${v.day.toString().padLeft(2, '0')}-${v.month.toString().padLeft(2, '0')}-${v.year}';
  String _dynamicDate(dynamic v) =>
      eccDate(v) == null ? '—' : _date(eccDate(v)!);
  String _money(num v) => '₹${v.round()}';
  String _titleCase(String v) => v
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .split(' ')
      .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
      .join(' ');
}

class _NavDestination {
  const _NavDestination(this.title, this.tab, {this.statusFilter});

  final String title;
  final int tab;
  final String? statusFilter;
}

class _CommandAction {
  const _CommandAction(this.title, this.category, this.icon, this.run);

  final String title;
  final String category;
  final IconData icon;
  final VoidCallback run;
}

class _MiniKpi {
  const _MiniKpi(this.title, this.value, this.color, this.tab);

  final String title;
  final String value;
  final Color color;
  final int tab;
}

class _QuickAction {
  const _QuickAction(this.title, this.icon, this.color, this.tab);

  final String title;
  final IconData icon;
  final Color color;
  final int tab;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.values, this.colors, this.trackColor);

  final List<int> values;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (total == 0) {
      return;
    }

    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      if (values[index] <= 0) {
        continue;
      }
      final sweep = 2 * math.pi * values[index] / total;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.butt
        ..color = colors[index];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.trackColor != trackColor;
  }
}

class _RiskMatrix extends StatelessWidget {
  const _RiskMatrix({required this.risks});
  final List<RiskRegisterItem> risks;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final v in risks) {
      final key = '${v.residualLikelihood}-${v.residualImpact}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return Column(
      children: [
        Text('Impact →', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Expanded(
          child: Row(
            children: [
              RotatedBox(quarterTurns: 3, child: Text('Likelihood →')),
              SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: List.generate(5, (row) {
                    final likelihood = 5 - row;
                    return Expanded(
                      child: Row(
                        children: List.generate(5, (col) {
                          final impact = col + 1;
                          final score = likelihood * impact;
                          final level = RiskRegisterItem.levelFor(score);
                          final palette = context.compliance;
                          final color = switch (level) {
                            RiskLevel.low => palette.success,
                            RiskLevel.medium => palette.warning,
                            RiskLevel.high => palette.warning,
                            RiskLevel.critical => palette.danger,
                          };
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .85),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Center(
                                child: Text(
                                  counts['$likelihood-$impact'] == null
                                      ? '$score'
                                      : '$score\n${counts['$likelihood-$impact']} risk',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = color.withValues(alpha: .15);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value / 100,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values, this.color, this.gridColor);
  final List<double> values;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = math.max(1, values.reduce(math.max));
    final grid = Paint()..color = gridColor.withValues(alpha: .7);
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - values[i] / maxV * (size.height - 20) - 10;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.color != color || old.gridColor != gridColor;
}
