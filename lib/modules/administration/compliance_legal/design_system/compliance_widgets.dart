import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'compliance_theme.dart';

class ComplianceCard extends StatefulWidget {
  const ComplianceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ComplianceSpacing.md),
    this.onTap,
    this.hoverable = false,
    this.tone,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hoverable;
  final ComplianceTone? tone;
  final String? semanticLabel;

  @override
  State<ComplianceCard> createState() => _ComplianceCardState();
}

class _ComplianceCardState extends State<ComplianceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;
    final accent = widget.tone == null
        ? palette.border
        : context.complianceTone(widget.tone!);

    final content = AnimatedContainer(
      duration: ComplianceMotion.normal,
      curve: ComplianceMotion.standard,
      transform: Matrix4.translationValues(
        0,
        widget.hoverable && _hovered ? -1 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ComplianceRadius.lg),
        border: Border.all(
          color: widget.hoverable && _hovered
              ? accent.withValues(alpha: .58)
              : palette.border,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow.withValues(
              alpha: widget.hoverable && _hovered ? .28 : .12,
            ),
            blurRadius: widget.hoverable && _hovered ? 14 : 8,
            offset: Offset(0, widget.hoverable && _hovered ? 5 : 2),
          ),
        ],
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: widget.hoverable
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.hoverable
            ? (_) => setState(() => _hovered = false)
            : null,
        child: widget.onTap == null
            ? content
            : InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(ComplianceRadius.lg),
                child: content,
              ),
      ),
    );
  }
}

class ComplianceSectionHeader extends StatelessWidget {
  const ComplianceSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(ComplianceRadius.md),
            ),
            child: Icon(icon, color: palette.primary, size: compact ? 18 : 21),
          ),
          const SizedBox(width: ComplianceSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style:
                    (compact
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.titleLarge)
                        ?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: ComplianceSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class CompliancePageHeader extends StatelessWidget {
  const CompliancePageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.icon,
    this.actions = const <Widget>[],
    this.breadcrumbs = const <String>[],
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 18),
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final IconData? icon;
  final List<Widget> actions;
  final List<String> breadcrumbs;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final titleArea = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(ComplianceRadius.lg),
                  ),
                  child: Icon(icon, color: palette.primary, size: 24),
                ),
                const SizedBox(width: ComplianceSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (breadcrumbs.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          for (
                            var index = 0;
                            index < breadcrumbs.length;
                            index++
                          ) ...<Widget>[
                            Text(
                              breadcrumbs[index],
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: index == breadcrumbs.length - 1
                                        ? palette.primary
                                        : palette.textTertiary,
                                  ),
                            ),
                            if (index != breadcrumbs.length - 1)
                              Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: palette.textTertiary,
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (eyebrow != null) ...<Widget>[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.45,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                titleArea,
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ComplianceSpacing.md),
                  Wrap(
                    spacing: ComplianceSpacing.xs,
                    runSpacing: ComplianceSpacing.xs,
                    children: actions,
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: titleArea),
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(width: ComplianceSpacing.lg),
                Wrap(
                  spacing: ComplianceSpacing.xs,
                  runSpacing: ComplianceSpacing.xs,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ComplianceStatusBadge extends StatelessWidget {
  const ComplianceStatusBadge({
    super.key,
    required this.label,
    this.tone,
    this.icon,
    this.compact = false,
  });

  final String label;
  final ComplianceTone? tone;
  final IconData? icon;
  final bool compact;

  static ComplianceTone toneFor(String value) {
    final normalized = value.trim().toLowerCase();

    if (<String>{
      'completed',
      'approved',
      'resolved',
      'closed',
      'active',
      'success',
      'published',
      'verified',
      'paid',
    }.contains(normalized)) {
      return ComplianceTone.success;
    }

    if (<String>{
      'pending',
      'in progress',
      'under review',
      'waiting',
      'due soon',
      'assigned',
      'reply in progress',
      'hearing scheduled',
      'draft',
    }.contains(normalized)) {
      return ComplianceTone.warning;
    }

    if (<String>{
      'overdue',
      'critical',
      'rejected',
      'failed',
      'cancelled',
      'expired',
      'high',
    }.contains(normalized)) {
      return ComplianceTone.danger;
    }

    if (<String>{
      'legal',
      'appealed',
      'litigation',
      'order reserved',
    }.contains(normalized)) {
      return ComplianceTone.legal;
    }

    if (<String>{'audit', 'finding', 'capa'}.contains(normalized)) {
      return ComplianceTone.audit;
    }

    if (<String>{
      'new',
      'information',
      'notice',
      'upcoming',
    }.contains(normalized)) {
      return ComplianceTone.info;
    }

    return ComplianceTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTone = tone ?? toneFor(label);
    final foreground = context.complianceTone(effectiveTone);
    final background = context.complianceToneSoft(effectiveTone);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(ComplianceRadius.pill),
          border: Border.all(color: foreground.withValues(alpha: .18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: compact ? 12 : 14, color: foreground),
              const SizedBox(width: 5),
            ] else ...<Widget>[
              Container(
                width: compact ? 5 : 6,
                height: compact ? 5 : 6,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComplianceKpiCard extends StatelessWidget {
  const ComplianceKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.tone = ComplianceTone.primary,
    this.subtitle,
    this.trend,
    this.trendUp,
    this.progress,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final ComplianceTone tone;
  final String? subtitle;
  final String? trend;
  final bool? trendUp;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = context.complianceTone(tone);
    final soft = context.complianceToneSoft(tone);
    final palette = context.compliance;

    return ComplianceCard(
      hoverable: onTap != null,
      onTap: onTap,
      tone: tone,
      semanticLabel: '$title: $value',
      padding: const EdgeInsets.all(ComplianceSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(ComplianceRadius.md),
                ),
                child: Icon(icon, color: foreground, size: 20),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (trendUp == false
                        ? palette.dangerSoft
                        : palette.successSoft),
                    borderRadius: BorderRadius.circular(ComplianceRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        trendUp == false
                            ? Icons.trending_down
                            : Icons.trending_up,
                        size: 13,
                        color: trendUp == false
                            ? palette.danger
                            : palette.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend!,
                        style: TextStyle(
                          color: trendUp == false
                              ? palette.danger
                              : palette.success,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: ComplianceSpacing.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -.45,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: palette.textTertiary),
            ),
          ],
          if (progress != null) ...<Widget>[
            const SizedBox(height: ComplianceSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(ComplianceRadius.pill),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: palette.border,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ComplianceSearchField extends StatelessWidget {
  const ComplianceSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.width,
    this.autofocus = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double? width;
  final bool autofocus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon:
              trailing ??
              (controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    )),
          filled: true,
          fillColor: palette.surfaceMuted,
        ),
      ),
    );
  }
}

class ComplianceSelector<T> extends StatelessWidget {
  const ComplianceSelector({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.options,
    required this.labelBuilder,
    required this.onSelected,
    this.icon = Icons.tune,
    this.title,
    this.searchHint = 'Search options',
    this.width = 180,
    this.allowClear = false,
    this.onClear,
    this.enabled = true,
    this.loading = false,
    this.addLabel,
    this.onAdd,
  });

  final String label;
  final String valueLabel;
  final List<T> options;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelected;
  final IconData icon;
  final String? title;
  final String searchHint;
  final double width;
  final bool allowClear;
  final VoidCallback? onClear;
  final bool enabled;
  final bool loading;
  final String? addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return Semantics(
      button: true,
      label: '$label: $valueLabel',
      child: SizedBox(
        width: width,
        child: InkWell(
          onTap: !enabled || loading
              ? null
              : () => _showSelectionDialog<T>(
                  context: context,
                  title: title ?? 'Select $label',
                  searchHint: searchHint,
                  options: options,
                  labelBuilder: labelBuilder,
                  selectedLabel: valueLabel,
                  allowClear: allowClear,
                  onClear: onClear,
                  addLabel: addLabel,
                  onAdd: onAdd,
                  onSelected: onSelected,
                ),
          borderRadius: BorderRadius.circular(ComplianceRadius.md),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: enabled ? palette.surface : palette.surfaceMuted,
              borderRadius: BorderRadius.circular(ComplianceRadius.md),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: palette.textSecondary),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textTertiary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .45,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        valueLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: palette.textPrimary),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 17,
                    color: palette.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required String searchHint,
  required List<T> options,
  required String Function(T option) labelBuilder,
  required String selectedLabel,
  required ValueChanged<T> onSelected,
  required bool allowClear,
  required VoidCallback? onClear,
  required String? addLabel,
  required VoidCallback? onAdd,
}) async {
  final search = TextEditingController();
  var query = '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = options.where((option) {
            return labelBuilder(
              option,
            ).toLowerCase().contains(query.trim().toLowerCase());
          }).toList();

          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Search and select an option. Use arrow keys and Enter to navigate.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: context.compliance.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ComplianceSearchField(
                      controller: search,
                      hintText: searchHint,
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() => query = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const ComplianceEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching options',
                            message: 'Try a different search term.',
                            compact: true,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 3),
                            itemBuilder: (context, index) {
                              final option = filtered[index];
                              final label = labelBuilder(option);
                              final selected = label == selectedLabel;

                              return ListTile(
                                autofocus: index == 0,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: selected
                                      ? context.compliance.primarySoft
                                      : context.compliance.surfaceMuted,
                                  child: Icon(
                                    selected
                                        ? Icons.check
                                        : Icons.chevron_right,
                                    size: 17,
                                    color: selected
                                        ? context.compliance.primary
                                        : context.compliance.textTertiary,
                                  ),
                                ),
                                title: Text(label),
                                selected: selected,
                                selectedTileColor:
                                    context.compliance.primarySoft,
                                onTap: () {
                                  onSelected(option);
                                  Navigator.pop(dialogContext);
                                },
                              );
                            },
                          ),
                  ),
                  if (allowClear || addLabel != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: context.compliance.border),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          if (allowClear)
                            TextButton.icon(
                              onPressed: () {
                                onClear?.call();
                                Navigator.pop(dialogContext);
                              },
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Clear selection'),
                            ),
                          const Spacer(),
                          if (addLabel != null)
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                onAdd?.call();
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(addLabel),
                            ),
                        ],
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
}

class ComplianceMultiSelector<T> extends StatelessWidget {
  const ComplianceMultiSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.icon = Icons.checklist,
    this.width = 230,
  });

  final String label;
  final List<T> options;
  final Set<T> selected;
  final String Function(T option) labelBuilder;
  final ValueChanged<Set<T>> onChanged;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    final valueLabel = selected.isEmpty
        ? 'All'
        : selected.length == 1
        ? labelBuilder(selected.first)
        : '${selected.length} selected';

    return ComplianceSelector<T>(
      label: label,
      valueLabel: valueLabel,
      options: options,
      labelBuilder: labelBuilder,
      icon: icon,
      width: width,
      onSelected: (option) {
        final next = <T>{...selected};
        if (!next.add(option)) {
          next.remove(option);
        }
        onChanged(next);
      },
      allowClear: selected.isNotEmpty,
      onClear: () => onChanged(<T>{}),
    );
  }
}

class ComplianceEmptyState extends StatelessWidget {
  const ComplianceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ComplianceSpacing.xl,
          vertical: compact ? ComplianceSpacing.xl : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: compact ? 54 : 68,
                height: compact ? 54 : 68,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(ComplianceRadius.xl),
                ),
                child: Icon(
                  icon,
                  color: palette.primary,
                  size: compact ? 27 : 34,
                ),
              ),
              const SizedBox(height: ComplianceSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ComplianceSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: ComplianceSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ComplianceErrorState extends StatelessWidget {
  const ComplianceErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return Container(
      padding: EdgeInsets.all(compact ? ComplianceSpacing.md : 22),
      decoration: BoxDecoration(
        color: palette.dangerSoft,
        borderRadius: BorderRadius.circular(ComplianceRadius.lg),
        border: Border.all(color: palette.danger.withValues(alpha: .22)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.danger.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(ComplianceRadius.md),
            ),
            child: Icon(Icons.error_outline, color: palette.danger),
          ),
          const SizedBox(width: ComplianceSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Unable to load this workspace',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: palette.danger),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class ComplianceSkeleton extends StatefulWidget {
  const ComplianceSkeleton({super.key, this.lines = 5, this.height = 16});

  final int lines;
  final double height;

  @override
  State<ComplianceSkeleton> createState() => _ComplianceSkeletonState();
}

class _ComplianceSkeletonState extends State<ComplianceSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = .45 + math.sin(_controller.value * math.pi) * .25;

        return Column(
          children: List<Widget>.generate(widget.lines, (index) {
            return Container(
              height: widget.height,
              margin: EdgeInsets.only(
                bottom: index == widget.lines - 1 ? 0 : 12,
              ),
              width: index == widget.lines - 1 ? 210 : double.infinity,
              decoration: BoxDecoration(
                color: palette.border.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(ComplianceRadius.sm),
              ),
            );
          }),
        );
      },
    );
  }
}

class ComplianceQuickAction extends StatefulWidget {
  const ComplianceQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.tone = ComplianceTone.primary,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final ComplianceTone tone;

  @override
  State<ComplianceQuickAction> createState() => _ComplianceQuickActionState();
}

class _ComplianceQuickActionState extends State<ComplianceQuickAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = context.complianceTone(widget.tone);
    final soft = context.complianceToneSoft(widget.tone);
    final palette = context.compliance;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(ComplianceRadius.lg),
        child: AnimatedContainer(
          duration: ComplianceMotion.normal,
          padding: const EdgeInsets.all(ComplianceSpacing.md),
          decoration: BoxDecoration(
            color: _hovered ? soft : palette.surface,
            borderRadius: BorderRadius.circular(ComplianceRadius.lg),
            border: Border.all(
              color: _hovered
                  ? foreground.withValues(alpha: .35)
                  : palette.border,
            ),
          ),
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
                    child: Icon(widget.icon, color: foreground, size: 21),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: _hovered ? foreground : palette.textTertiary,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: ComplianceSpacing.sm),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.description != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  widget.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ComplianceGridColumn<T> {
  const ComplianceGridColumn({
    required this.id,
    required this.label,
    required this.cellBuilder,
    this.width = 160,
    this.minWidth = 100,
    this.sortValue,
    this.numeric = false,
  });

  final String id;
  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;
  final double width;
  final double minWidth;
  final Comparable<dynamic>? Function(T row)? sortValue;
  final bool numeric;
}

class ComplianceDataGrid<T> extends StatefulWidget {
  const ComplianceDataGrid({
    super.key,
    required this.rows,
    required this.columns,
    required this.rowId,
    this.pageSize = 25,
    this.pageSizeOptions = const <int>[10, 25, 50, 100],
    this.onRowTap,
    this.onRowDoubleTap,
    this.contextMenuBuilder,
    this.selectable = true,
    this.emptyTitle = 'No records found',
    this.emptyMessage = 'Adjust filters or create a new record.',
    this.loading = false,
    this.error,
    this.onRetry,
    this.maxHeight = 620,
  });

  final List<T> rows;
  final List<ComplianceGridColumn<T>> columns;
  final String Function(T row) rowId;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<T>? onRowTap;
  final ValueChanged<T>? onRowDoubleTap;
  final List<PopupMenuEntry<String>> Function(BuildContext, T)?
  contextMenuBuilder;
  final bool selectable;
  final String emptyTitle;
  final String emptyMessage;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;
  final double maxHeight;

  @override
  State<ComplianceDataGrid<T>> createState() => _ComplianceDataGridState<T>();
}

class _ComplianceDataGridState<T> extends State<ComplianceDataGrid<T>> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();
  final Set<String> _selected = <String>{};
  late int _pageSize;
  int _page = 0;
  String? _sortColumn;
  bool _ascending = true;
  late List<double> _widths;
  late List<int> _columnOrder;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.pageSize;
    _widths = widget.columns.map((column) => column.width).toList();
    _columnOrder = List<int>.generate(widget.columns.length, (index) => index);
  }

  @override
  void didUpdateWidget(covariant ComplianceDataGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns.length != widget.columns.length) {
      _widths = widget.columns.map((column) => column.width).toList();
      _columnOrder = List<int>.generate(
        widget.columns.length,
        (index) => index,
      );
    }
    final maxPage = math.max(0, (widget.rows.length - 1) ~/ _pageSize);
    if (_page > maxPage) {
      _page = maxPage;
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  List<T> get _sortedRows {
    final result = <T>[...widget.rows];
    final id = _sortColumn;
    if (id == null) {
      return result;
    }

    ComplianceGridColumn<T>? sortColumn;
    for (final column in widget.columns) {
      if (column.id == id) {
        sortColumn = column;
        break;
      }
    }

    final valueBuilder = sortColumn?.sortValue;
    if (valueBuilder == null) {
      return result;
    }

    result.sort((left, right) {
      final first = valueBuilder(left);
      final second = valueBuilder(right);
      if (first == null && second == null) {
        return 0;
      }
      if (first == null) {
        return _ascending ? -1 : 1;
      }
      if (second == null) {
        return _ascending ? 1 : -1;
      }
      final comparison = first.compareTo(second);
      return _ascending ? comparison : -comparison;
    });

    return result;
  }

  List<T> get _pageRows {
    final rows = _sortedRows;
    final start = _page * _pageSize;
    if (start >= rows.length) {
      return <T>[];
    }
    return rows.sublist(start, math.min(rows.length, start + _pageSize));
  }

  double get _gridWidth {
    final selectionWidth = widget.selectable ? 48.0 : 0.0;
    return selectionWidth +
        _columnOrder.fold<double>(0, (total, index) => total + _widths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    if (widget.loading) {
      return ComplianceCard(
        child: ComplianceSkeleton(lines: math.min(8, widget.pageSize)),
      );
    }

    if (widget.error != null) {
      return ComplianceErrorState(
        message: widget.error.toString(),
        onRetry: widget.onRetry,
      );
    }

    if (widget.rows.isEmpty) {
      return ComplianceCard(
        child: ComplianceEmptyState(
          icon: Icons.table_rows_outlined,
          title: widget.emptyTitle,
          message: widget.emptyMessage,
        ),
      );
    }

    final rows = _pageRows;
    final allPageSelected =
        rows.isNotEmpty &&
        rows.every((row) => _selected.contains(widget.rowId(row)));

    return ComplianceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _gridWidth,
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: palette.surfaceMuted,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(ComplianceRadius.lg),
                        ),
                        border: Border(
                          bottom: BorderSide(color: palette.border),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          if (widget.selectable)
                            SizedBox(
                              width: 48,
                              child: Checkbox(
                                value: allPageSelected,
                                onChanged: (selected) {
                                  setState(() {
                                    for (final row in rows) {
                                      final id = widget.rowId(row);
                                      if (selected == true) {
                                        _selected.add(id);
                                      } else {
                                        _selected.remove(id);
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                          for (final columnIndex in _columnOrder)
                            _GridHeaderCell<T>(
                              column: widget.columns[columnIndex],
                              width: _widths[columnIndex],
                              sorted:
                                  _sortColumn == widget.columns[columnIndex].id,
                              ascending: _ascending,
                              onSort:
                                  widget.columns[columnIndex].sortValue == null
                                  ? null
                                  : () {
                                      setState(() {
                                        final id =
                                            widget.columns[columnIndex].id;
                                        if (_sortColumn == id) {
                                          _ascending = !_ascending;
                                        } else {
                                          _sortColumn = id;
                                          _ascending = true;
                                        }
                                      });
                                    },
                              onResize: (delta) {
                                setState(() {
                                  _widths[columnIndex] = math.max(
                                    widget.columns[columnIndex].minWidth,
                                    _widths[columnIndex] + delta,
                                  );
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: widget.maxHeight),
                      child: Scrollbar(
                        controller: _vertical,
                        thumbVisibility: rows.length > 8,
                        child: ListView.builder(
                          controller: _vertical,
                          shrinkWrap: true,
                          itemCount: rows.length,
                          itemBuilder: (context, rowIndex) {
                            final row = rows[rowIndex];
                            final id = widget.rowId(row);
                            final selected = _selected.contains(id);

                            return _GridDataRow<T>(
                              row: row,
                              selected: selected,
                              selectable: widget.selectable,
                              columns: widget.columns,
                              columnOrder: _columnOrder,
                              widths: _widths,
                              onSelect: (value) {
                                setState(() {
                                  if (value) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                });
                              },
                              onTap: widget.onRowTap == null
                                  ? null
                                  : () => widget.onRowTap!(row),
                              onDoubleTap: widget.onRowDoubleTap == null
                                  ? null
                                  : () => widget.onRowDoubleTap!(row),
                              contextMenuBuilder:
                                  widget.contextMenuBuilder == null
                                  ? null
                                  : (context) => widget.contextMenuBuilder!(
                                      context,
                                      row,
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _gridFooter(context),
        ],
      ),
    );
  }

  Widget _gridFooter(BuildContext context) {
    final palette = context.compliance;
    final totalPages = math.max(1, (widget.rows.length / _pageSize).ceil());
    final start = widget.rows.isEmpty ? 0 : _page * _pageSize + 1;
    final end = math.min(widget.rows.length, (_page + 1) * _pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(ComplianceRadius.lg),
        ),
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          if (_selected.isNotEmpty) ...<Widget>[
            ComplianceStatusBadge(
              label: '${_selected.length} selected',
              tone: ComplianceTone.primary,
              compact: true,
            ),
            const SizedBox(width: ComplianceSpacing.sm),
          ],
          Text(
            '$start–$end of ${widget.rows.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text('Rows', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 6),
          PopupMenuButton<int>(
            tooltip: 'Rows per page',
            initialValue: _pageSize,
            onSelected: (value) {
              setState(() {
                _pageSize = value;
                _page = 0;
              });
            },
            itemBuilder: (context) => widget.pageSizeOptions
                .map(
                  (value) =>
                      PopupMenuItem<int>(value: value, child: Text('$value')),
                )
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(ComplianceRadius.sm),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('$_pageSize'),
                  const SizedBox(width: 3),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: ComplianceSpacing.sm),
          IconButton(
            tooltip: 'Previous page',
            onPressed: _page == 0 ? null : () => setState(() => _page--),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_page + 1} / $totalPages',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: _page + 1 >= totalPages
                ? null
                : () => setState(() => _page++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _GridHeaderCell<T> extends StatelessWidget {
  const _GridHeaderCell({
    required this.column,
    required this.width,
    required this.sorted,
    required this.ascending,
    required this.onSort,
    required this.onResize,
  });

  final ComplianceGridColumn<T> column;
  final double width;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onSort;
  final ValueChanged<double> onResize;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return SizedBox(
      width: width,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InkWell(
              onTap: onSort,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: column.numeric
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        column.label.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: sorted
                              ? palette.primary
                              : palette.textSecondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .35,
                        ),
                      ),
                    ),
                    if (onSort != null) ...<Widget>[
                      const SizedBox(width: 4),
                      Icon(
                        sorted
                            ? ascending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward
                            : Icons.unfold_more,
                        size: 14,
                        color: sorted ? palette.primary : palette.textTertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 8,
            bottom: 8,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) => onResize(details.delta.dx),
                child: Container(
                  width: 7,
                  alignment: Alignment.center,
                  child: Container(width: 1, color: palette.border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridDataRow<T> extends StatefulWidget {
  const _GridDataRow({
    required this.row,
    required this.selected,
    required this.selectable,
    required this.columns,
    required this.columnOrder,
    required this.widths,
    required this.onSelect,
    this.onTap,
    this.onDoubleTap,
    this.contextMenuBuilder,
  });

  final T row;
  final bool selected;
  final bool selectable;
  final List<ComplianceGridColumn<T>> columns;
  final List<int> columnOrder;
  final List<double> widths;
  final ValueChanged<bool> onSelect;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final List<PopupMenuEntry<String>> Function(BuildContext)? contextMenuBuilder;

  @override
  State<_GridDataRow<T>> createState() => _GridDataRowState<T>();
}

class _GridDataRowState<T> extends State<_GridDataRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;
    final background = widget.selected
        ? palette.primarySoft
        : _hovered
        ? palette.surfaceMuted
        : palette.surface;

    Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapDown: widget.contextMenuBuilder == null
            ? null
            : (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: ComplianceMotion.fast,
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            color: background,
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          child: Row(
            children: <Widget>[
              if (widget.selectable)
                SizedBox(
                  width: 48,
                  child: Checkbox(
                    value: widget.selected,
                    onChanged: (value) => widget.onSelect(value == true),
                  ),
                ),
              for (final index in widget.columnOrder)
                SizedBox(
                  width: widget.widths[index],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Align(
                      alignment: widget.columns[index].numeric
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: widget.columns[index].cellBuilder(
                        context,
                        widget.row,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.contextMenuBuilder != null) {
      row = ShortcutMenuRegion(
        menuBuilder: widget.contextMenuBuilder!,
        child: row,
      );
    }

    return row;
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: widget.contextMenuBuilder!(context),
    );
  }
}

class ShortcutMenuRegion extends StatelessWidget {
  const ShortcutMenuRegion({
    super.key,
    required this.menuBuilder,
    required this.child,
  });

  final List<PopupMenuEntry<String>> Function(BuildContext) menuBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.contextMenu): () async {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null) {
            return;
          }
          final position = renderBox.localToGlobal(
            Offset(renderBox.size.width / 2, renderBox.size.height / 2),
          );
          final overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          await showMenu<String>(
            context: context,
            position: RelativeRect.fromRect(
              Rect.fromLTWH(position.dx, position.dy, 0, 0),
              Offset.zero & overlay.size,
            ),
            items: menuBuilder(context),
          );
        },
      },
      child: child,
    );
  }
}

class ComplianceFilterBar extends StatelessWidget {
  const ComplianceFilterBar({
    super.key,
    required this.children,
    this.appliedCount = 0,
    this.onClear,
    this.title = 'Filters',
  });

  final List<Widget> children;
  final int appliedCount;
  final VoidCallback? onClear;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.compliance;

    return Container(
      padding: const EdgeInsets.all(ComplianceSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ComplianceRadius.lg),
        border: Border.all(color: palette.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow.withValues(alpha: .45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: ComplianceSpacing.xs,
        runSpacing: ComplianceSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(ComplianceRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.tune_rounded, size: 18, color: palette.primary),
                const SizedBox(width: 7),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .45,
                  ),
                ),
                if (appliedCount > 0) ...<Widget>[
                  const SizedBox(width: 7),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$appliedCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...children,
          if (appliedCount > 0 && onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
              label: const Text('Clear all'),
            ),
        ],
      ),
    );
  }
}

class ComplianceProgressRing extends StatelessWidget {
  const ComplianceProgressRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 120,
    this.tone = ComplianceTone.success,
    this.strokeWidth = 10,
  });

  final double value;
  final String label;
  final double size;
  final ComplianceTone tone;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final color = context.complianceTone(tone);
    final palette = context.compliance;
    final safeValue = value.clamp(0, 1).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: safeValue,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: safeValue * 100),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '${value.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
