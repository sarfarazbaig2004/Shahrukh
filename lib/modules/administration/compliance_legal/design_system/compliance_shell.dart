import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:QUIK/core/theme/theme_controller.dart';

import 'compliance_theme.dart';
import 'compliance_widgets.dart';

class ComplianceNavigationItem {
  const ComplianceNavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
    this.children = const <ComplianceNavigationItem>[],
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  final List<ComplianceNavigationItem> children;
}

class ComplianceNavigationGroup {
  const ComplianceNavigationGroup({required this.label, required this.items});

  final String label;
  final List<ComplianceNavigationItem> items;
}

class ComplianceCommand {
  const ComplianceCommand({
    required this.label,
    required this.description,
    required this.icon,
    required this.onSelected,
    this.keywords = const <String>[],
    this.shortcut,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onSelected;
  final List<String> keywords;
  final String? shortcut;
}

class ComplianceWorkspaceShell extends StatefulWidget {
  const ComplianceWorkspaceShell({
    super.key,
    required this.activeNavigationId,
    required this.navigationGroups,
    required this.body,
    required this.title,
    required this.subtitle,
    required this.companyName,
    required this.userName,
    required this.globalSearchController,
    required this.onGlobalSearch,
    this.branchLabel = 'All Branches',
    this.businessUnitLabel = 'All Business Units',
    this.financialYearLabel = 'Current FY',
    this.companyOptions = const <String>[],
    this.branchOptions = const <String>[],
    this.businessUnitOptions = const <String>[],
    this.financialYearOptions = const <String>[],
    this.onCompanySelected,
    this.onBranchSelected,
    this.onBusinessUnitSelected,
    this.onFinancialYearSelected,
    this.onRefresh,
    this.onNotifications,
    this.onSettings,
    this.onHelp,
    this.commands = const <ComplianceCommand>[],
    this.notificationCount = 0,
    this.breadcrumbs = const <String>['Administration', 'Compliance & Legal'],
  });

  final String activeNavigationId;
  final List<ComplianceNavigationGroup> navigationGroups;
  final Widget body;
  final String title;
  final String subtitle;
  final String companyName;
  final String userName;
  final TextEditingController globalSearchController;
  final ValueChanged<String> onGlobalSearch;
  final String branchLabel;
  final String businessUnitLabel;
  final String financialYearLabel;
  final List<String> companyOptions;
  final List<String> branchOptions;
  final List<String> businessUnitOptions;
  final List<String> financialYearOptions;
  final ValueChanged<String>? onCompanySelected;
  final ValueChanged<String>? onBranchSelected;
  final ValueChanged<String>? onBusinessUnitSelected;
  final ValueChanged<String>? onFinancialYearSelected;
  final VoidCallback? onRefresh;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;
  final List<ComplianceCommand> commands;
  final int notificationCount;
  final List<String> breadcrumbs;

  @override
  State<ComplianceWorkspaceShell> createState() =>
      _ComplianceWorkspaceShellState();
}

class _ComplianceWorkspaceShellState extends State<ComplianceWorkspaceShell> {
  CompliancePalette get palette =>
      Theme.of(context).extension<CompliancePalette>()!;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _expandedItems = <String>{};
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return ComplianceThemeShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1120;

          return CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _openCommandPalette,
              const SingleActivator(
                LogicalKeyboardKey.keyR,
                control: true,
              ): () =>
                  widget.onRefresh?.call(),
              const SingleActivator(LogicalKeyboardKey.slash):
                  _focusGlobalSearch,
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                key: _scaffoldKey,
                backgroundColor: context.compliance.canvas,
                drawer: compact
                    ? Drawer(
                        width: 292,
                        backgroundColor: context.compliance.sidebar,
                        child: SafeArea(
                          child: _buildSidebar(expanded: true, drawer: true),
                        ),
                      )
                    : null,
                body: SafeArea(
                  child: Row(
                    children: <Widget>[
                      if (!compact)
                        AnimatedContainer(
                          duration: ComplianceMotion.normal,
                          curve: ComplianceMotion.standard,
                          width: _collapsed ? 76 : 272,
                          child: _buildSidebar(expanded: !_collapsed),
                        ),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            _buildTopBar(compact: compact),
                            _buildScopeBar(compact: compact),
                            Expanded(
                              child: ClipRect(
                                child: AnimatedSwitcher(
                                  duration: ComplianceMotion.normal,
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(.015, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: KeyedSubtree(
                                    key: ValueKey(widget.activeNavigationId),
                                    child: widget.body,
                                  ),
                                ),
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
      ),
    );
  }

  Widget _buildSidebar({required bool expanded, bool drawer = false}) {
    final palette = context.compliance;

    return Container(
      color: palette.sidebar,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 76,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(ComplianceRadius.md),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: palette.sidebarText,
                      size: 23,
                    ),
                  ),
                  if (expanded) ...<Widget>[
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'MEMCO GRC',
                            style: TextStyle(
                              color: palette.sidebarText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.2,
                            ),
                          ),
                          Text(
                            'Compliance Workspace',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.sidebarTextMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!drawer)
                      IconButton(
                        tooltip: 'Collapse navigation',
                        onPressed: () => setState(() => _collapsed = true),
                        icon: Icon(
                          Icons.keyboard_double_arrow_left,
                          size: 18,
                          color: palette.sidebarTextMuted,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Divider(color: palette.sidebarText.withValues(alpha: .09)),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: InkWell(
                onTap: _openCommandPalette,
                borderRadius: BorderRadius.circular(ComplianceRadius.md),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: palette.sidebarText.withValues(alpha: .065),
                    borderRadius: BorderRadius.circular(ComplianceRadius.md),
                    border: Border.all(
                      color: palette.sidebarText.withValues(alpha: .09),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.search,
                        color: palette.sidebarTextMuted,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Search commands',
                          style: TextStyle(
                            color: palette.sidebarTextMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: palette.sidebarText.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '⌘K',
                          style: TextStyle(
                            color: palette.sidebarTextMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  expanded ? 10 : 8,
                  5,
                  expanded ? 10 : 8,
                  16,
                ),
                children: <Widget>[
                  for (final group in widget.navigationGroups) ...<Widget>[
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 7),
                        child: Text(
                          group.label.toUpperCase(),
                          style: TextStyle(
                            color: palette.sidebarText.withValues(alpha: .38),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .75,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    for (final item in group.items)
                      _buildNavigationItem(item, expanded: expanded),
                  ],
                ],
              ),
            ),
          ),
          if (!expanded && !drawer)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IconButton(
                tooltip: 'Expand navigation',
                onPressed: () => setState(() => _collapsed = false),
                icon: Icon(
                  Icons.keyboard_double_arrow_right,
                  color: palette.sidebarTextMuted,
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.all(expanded ? 12 : 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: palette.sidebarText.withValues(alpha: .09),
                ),
              ),
            ),
            child: expanded
                ? Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: palette.primary,
                        child: Text(
                          _initials(widget.userName),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.userName.trim().isEmpty
                                  ? 'Current User'
                                  : widget.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.sidebarText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Compliance workspace',
                              style: TextStyle(
                                color: palette.sidebarText.withValues(
                                  alpha: .48,
                                ),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: widget.onSettings,
                        icon: Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: palette.sidebarTextMuted,
                        ),
                      ),
                    ],
                  )
                : CircleAvatar(
                    radius: 19,
                    backgroundColor: palette.primary,
                    child: Text(
                      _initials(widget.userName),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(
    ComplianceNavigationItem item, {
    required bool expanded,
    int depth = 0,
  }) {
    final selected = item.id == widget.activeNavigationId;
    final childSelected = item.children.any(
      (child) => child.id == widget.activeNavigationId,
    );
    final hasChildren = item.children.isNotEmpty;
    final expandedChildren = _expandedItems.contains(item.id) || childSelected;

    final tile = Tooltip(
      message: expanded ? '' : item.label,
      child: InkWell(
        onTap: () {
          if (hasChildren && expanded) {
            setState(() {
              if (!_expandedItems.add(item.id)) {
                _expandedItems.remove(item.id);
              }
            });
            if (!childSelected) {
              item.onTap();
            }
          } else {
            item.onTap();
            if (_scaffoldKey.currentState?.isDrawerOpen == true) {
              Navigator.pop(context);
            }
          }
        },
        borderRadius: BorderRadius.circular(ComplianceRadius.md),
        child: AnimatedContainer(
          duration: ComplianceMotion.fast,
          height: 40,
          margin: const EdgeInsets.only(bottom: 3),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 11 + depth * 12 : 0,
          ),
          decoration: BoxDecoration(
            color: selected || childSelected
                ? context.compliance.sidebarSelected
                : Colors.transparent,
            borderRadius: BorderRadius.circular(ComplianceRadius.md),
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                item.icon,
                size: 19,
                color: selected || childSelected
                    ? palette.sidebarText
                    : palette.sidebarTextMuted,
              ),
              if (expanded) ...<Widget>[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected || childSelected
                          ? palette.sidebarText
                          : palette.sidebarTextMuted,
                      fontSize: 12.2,
                      fontWeight: selected || childSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.compliance.primary.withValues(alpha: .26),
                      borderRadius: BorderRadius.circular(
                        ComplianceRadius.pill,
                      ),
                    ),
                    child: Text(
                      item.badge!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (hasChildren) ...<Widget>[
                  const SizedBox(width: 5),
                  AnimatedRotation(
                    turns: expandedChildren ? .5 : 0,
                    duration: ComplianceMotion.normal,
                    child: Icon(
                      Icons.expand_more,
                      size: 17,
                      color: palette.sidebarTextMuted,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    if (!expanded || !hasChildren) {
      return tile;
    }

    return Column(
      children: <Widget>[
        tile,
        AnimatedSize(
          duration: ComplianceMotion.normal,
          curve: ComplianceMotion.standard,
          child: expandedChildren
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    children: item.children
                        .map(
                          (child) => _buildNavigationItem(
                            child,
                            expanded: true,
                            depth: depth + 1,
                          ),
                        )
                        .toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTopBar({required bool compact}) {
    final palette = context.compliance;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          if (compact)
            IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          if (compact) const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < widget.breadcrumbs.length;
                      index++
                    ) ...<Widget>[
                      Text(
                        widget.breadcrumbs[index],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: index == widget.breadcrumbs.length - 1
                              ? palette.primary
                              : palette.textTertiary,
                        ),
                      ),
                      if (index != widget.breadcrumbs.length - 1)
                        Icon(
                          Icons.chevron_right,
                          size: 13,
                          color: palette.textTertiary,
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.25,
                            ),
                      ),
                    ),
                    if (!compact) ...<Widget>[
                      const SizedBox(width: 9),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!compact)
            InkWell(
              onTap: _openCommandPalette,
              borderRadius: BorderRadius.circular(ComplianceRadius.md),
              child: Container(
                width: 260,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(ComplianceRadius.md),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search, size: 18, color: palette.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search or run a command',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        'Ctrl K',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textTertiary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh (Ctrl+R)',
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          _notificationButton(),
          const ComplianceThemeToggleButton(compact: true),
          IconButton(
            tooltip: 'Help',
            onPressed: widget.onHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'User menu',
            onSelected: (value) {
              if (value == 'settings') {
                widget.onSettings?.call();
              } else if (value == 'theme') {
                QuikThemeController.instance.toggle(context);
              } else if (value == 'help') {
                widget.onHelp?.call();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                enabled: false,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: palette.primarySoft,
                    child: Text(
                      _initials(widget.userName),
                      style: TextStyle(
                        color: palette.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    widget.userName.trim().isEmpty
                        ? 'Current User'
                        : widget.userName,
                  ),
                  subtitle: const Text('Compliance workspace'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Compliance settings'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'theme',
                child: ListTile(
                  leading: Icon(Icons.contrast_outlined),
                  title: Text('Switch theme'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Help & shortcuts'),
                ),
              ),
            ],
            child: Container(
              height: 40,
              margin: const EdgeInsets.only(left: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(ComplianceRadius.md),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: palette.primarySoft,
                    child: Text(
                      _initials(widget.userName),
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >= 1280) ...<Widget>[
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        widget.userName.trim().isEmpty
                            ? 'User'
                            : widget.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                  const SizedBox(width: 3),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationButton() {
    final palette = context.compliance;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          tooltip: 'Notifications',
          onPressed: widget.onNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (widget.notificationCount > 0)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.danger,
                borderRadius: BorderRadius.circular(ComplianceRadius.pill),
                border: Border.all(color: palette.surface, width: 2),
              ),
              child: Text(
                widget.notificationCount > 99
                    ? '99+'
                    : '${widget.notificationCount}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScopeBar({required bool compact}) {
    final palette = context.compliance;
    final selectors = <Widget>[
      ComplianceSelector<String>(
        label: 'Company',
        valueLabel: widget.companyName,
        options: widget.companyOptions.isEmpty
            ? <String>[widget.companyName]
            : widget.companyOptions,
        labelBuilder: (value) => value,
        onSelected: widget.onCompanySelected ?? (_) {},
        icon: Icons.business_outlined,
        width: 230,
      ),
      ComplianceSelector<String>(
        label: 'Branch',
        valueLabel: widget.branchLabel,
        options: widget.branchOptions.isEmpty
            ? <String>[widget.branchLabel]
            : widget.branchOptions,
        labelBuilder: (value) => value,
        onSelected: widget.onBranchSelected ?? (_) {},
        icon: Icons.account_tree_outlined,
        width: 190,
      ),
      ComplianceSelector<String>(
        label: 'Business Unit',
        valueLabel: widget.businessUnitLabel,
        options: widget.businessUnitOptions.isEmpty
            ? <String>[widget.businessUnitLabel]
            : widget.businessUnitOptions,
        labelBuilder: (value) => value,
        onSelected: widget.onBusinessUnitSelected ?? (_) {},
        icon: Icons.apartment_outlined,
        width: 205,
      ),
      ComplianceSelector<String>(
        label: 'Financial Year',
        valueLabel: widget.financialYearLabel,
        options: widget.financialYearOptions.isEmpty
            ? <String>[widget.financialYearLabel]
            : widget.financialYearOptions,
        labelBuilder: (value) => value,
        onSelected: widget.onFinancialYearSelected ?? (_) {},
        icon: Icons.calendar_today_outlined,
        width: 180,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 11),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow.withValues(alpha: .30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: ComplianceSearchField(
                      controller: widget.globalSearchController,
                      hintText: 'Global compliance search',
                      onChanged: widget.onGlobalSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...selectors.expand(
                    (selector) => <Widget>[selector, const SizedBox(width: 8)],
                  ),
                ],
              ),
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: ComplianceSearchField(
                    controller: widget.globalSearchController,
                    hintText: 'Search compliance, notices, risks, sections…',
                    onChanged: widget.onGlobalSearch,
                  ),
                ),
                const SizedBox(width: 10),
                ...selectors.expand(
                  (selector) => <Widget>[selector, const SizedBox(width: 8)],
                ),
              ],
            ),
    );
  }

  void _focusGlobalSearch() {
    FocusScope.of(context).requestFocus();
    widget.globalSearchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.globalSearchController.text.length,
    );
  }

  Future<void> _openCommandPalette() async {
    final controller = TextEditingController();
    var query = '';

    await showDialog<void>(
      context: context,
      barrierColor: context.compliance.scrim,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalized = query.trim().toLowerCase();
            final commands = widget.commands.where((command) {
              if (normalized.isEmpty) {
                return true;
              }
              return command.label.toLowerCase().contains(normalized) ||
                  command.description.toLowerCase().contains(normalized) ||
                  command.keywords.any(
                    (keyword) => keyword.toLowerCase().contains(normalized),
                  );
            }).toList();

            return Align(
              alignment: const Alignment(0, -.58),
              child: Dialog(
                insetPadding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 680,
                  height: 520,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: ComplianceSearchField(
                          controller: controller,
                          hintText:
                              'Search commands, modules, compliance records…',
                          autofocus: true,
                          onChanged: (value) {
                            setDialogState(() => query = value);
                          },
                          trailing: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.compliance.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: context.compliance.border,
                              ),
                            ),
                            child: const Text(
                              'ESC',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Divider(color: context.compliance.border),
                      Expanded(
                        child: commands.isEmpty
                            ? const ComplianceEmptyState(
                                icon: Icons.manage_search_outlined,
                                title: 'No matching commands',
                                message:
                                    'Search by module, action, section or record type.',
                                compact: true,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(10),
                                itemCount: commands.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 3),
                                itemBuilder: (context, index) {
                                  final command = commands[index];
                                  return ListTile(
                                    autofocus: index == 0,
                                    leading: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: context.compliance.primarySoft,
                                        borderRadius: BorderRadius.circular(
                                          ComplianceRadius.md,
                                        ),
                                      ),
                                      child: Icon(
                                        command.icon,
                                        color: context.compliance.primary,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(command.label),
                                    subtitle: Text(command.description),
                                    trailing: command.shortcut == null
                                        ? const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                          )
                                        : ComplianceStatusBadge(
                                            label: command.shortcut!,
                                            compact: true,
                                          ),
                                    onTap: () {
                                      Navigator.pop(dialogContext);
                                      command.onSelected();
                                    },
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.compliance.surfaceMuted,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(ComplianceRadius.xxl),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.keyboard_outlined,
                              size: 16,
                              color: context.compliance.textTertiary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '↑ ↓ navigate  •  Enter open  •  Esc close',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const Spacer(),
                            Text(
                              '${commands.length} commands',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
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

    controller.dispose();
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class ComplianceSubpageShell extends StatelessWidget {
  const ComplianceSubpageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon,
    this.actions = const <Widget>[],
    this.breadcrumbs = const <String>['Compliance & Legal'],
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 30),
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData? icon;
  final List<Widget> actions;
  final List<String> breadcrumbs;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ComplianceThemeShell(
      child: Scaffold(
        backgroundColor: context.compliance.canvas,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              CompliancePageHeader(
                title: title,
                subtitle: subtitle,
                icon: icon,
                breadcrumbs: breadcrumbs,
                actions: <Widget>[
                  if (onBack != null)
                    OutlinedButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                    ),
                  ...actions,
                  const ComplianceThemeToggleButton(compact: true),
                ],
              ),
              Expanded(
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
