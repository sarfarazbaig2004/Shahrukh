import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_design_system.dart';

import '../../models/income_tax_models.dart';

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String formatMoney(int value) => _inr.format(value);
String formatPercentBps(int basisPoints) =>
    '${(basisPoints / 100).toStringAsFixed(2)}%';

String enumTitle(Object value) {
  final raw = value.toString().split('.').last;
  return raw
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .trim()
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class TaxCard extends StatelessWidget {
  TaxCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ComplianceCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (subtitle != null) ...[
                        SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          if (title != null || trailing != null) SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class ResponsiveFieldGrid extends StatelessWidget {
  ResponsiveFieldGrid({
    super.key,
    required this.children,
    this.minFieldWidth = 230,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minFieldWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / minFieldWidth)
            .floor()
            .clamp(1, 4)
            .toInt();
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class MoneyField extends StatefulWidget {
  MoneyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.enabled = true,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? helperText;
  final bool enabled;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value == 0 ? '' : widget.value.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant MoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value == 0 ? '' : widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        _editing = focused;
        if (!focused) {
          final value = int.tryParse(_controller.text.replaceAll(',', '')) ?? 0;
          _controller.text = value == 0 ? '' : value.toString();
        }
      },
      child: TextFormField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          prefixText: '₹ ',
        ),
        onChanged: (text) => widget.onChanged(int.tryParse(text) ?? 0),
      ),
    );
  }
}

class TextValueField extends StatefulWidget {
  TextValueField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.validator,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final String? Function(String?)? validator;

  @override
  State<TextValueField> createState() => _TextValueFieldState();
}

class _TextValueFieldState extends State<TextValueField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant TextValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => _editing = focused,
      child: TextFormField(
        controller: _controller,
        maxLength: widget.maxLength,
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(labelText: widget.label, counterText: ''),
        validator: widget.validator,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class EnumDropdown<T extends Enum> extends StatelessWidget {
  EnumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.labelBuilder,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    String optionLabel(T option) =>
        labelBuilder?.call(option) ?? enumTitle(option);

    return ComplianceSelector<T>(
      label: label,
      valueLabel: optionLabel(value),
      options: values,
      labelBuilder: optionLabel,
      onSelected: onChanged,
      icon: Icons.manage_search_rounded,
      searchHint: 'Search $label',
      width: double.infinity,
    );
  }
}

class DateValueField extends StatelessWidget {
  DateValueField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(1990, 1, 1),
          firstDate: firstDate ?? DateTime(1900),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value == null
              ? 'Select date'
              : DateFormat('dd MMM yyyy').format(value!),
        ),
      ),
    );
  }
}

class MetricRow extends StatelessWidget {
  MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style?.copyWith(
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class RegimeSummaryCard extends StatelessWidget {
  RegimeSummaryCard({
    super.key,
    required this.title,
    required this.result,
    required this.recommended,
  });

  final String title;
  final TaxComputationResult result;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return TaxCard(
      title: title,
      trailing: recommended
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.compliance.success.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Recommended',
                style: TextStyle(
                  color: context.compliance.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            )
          : null,
      child: Column(
        children: [
          MetricRow(
            label: 'Gross Income',
            value: formatMoney(result.grossIncome),
          ),
          MetricRow(
            label: 'Total Deductions',
            value: formatMoney(result.totalDeductions),
          ),
          MetricRow(
            label: 'Taxable Income',
            value: formatMoney(result.taxableIncome),
          ),
          Divider(height: 22),
          MetricRow(label: 'Slab-wise Tax', value: formatMoney(result.slabTax)),
          MetricRow(
            label: 'Special-rate Tax',
            value: formatMoney(result.specialRateTax),
          ),
          MetricRow(label: 'Surcharge', value: formatMoney(result.surcharge)),
          MetricRow(
            label: 'Marginal Relief',
            value: formatMoney(result.marginalRelief),
          ),
          MetricRow(
            label: 'Rebate',
            value: '- ${formatMoney(result.rebate)}',
            valueColor: context.compliance.success,
          ),
          MetricRow(
            label: 'Health & Education Cess',
            value: formatMoney(result.cess),
          ),
          MetricRow(
            label: 'Interest',
            value: formatMoney(
              result.interest234A + result.interest234B + result.interest234C,
            ),
            valueColor:
                result.interest234A +
                        result.interest234B +
                        result.interest234C >
                    0
                ? context.compliance.warning
                : null,
          ),
          Divider(height: 24),
          MetricRow(
            label: 'Net Tax',
            value: formatMoney(result.netTax),
            valueColor: result.netTax > 0
                ? context.compliance.danger
                : context.compliance.success,
            emphasized: true,
          ),
          MetricRow(
            label: 'Refund',
            value: formatMoney(result.refund),
            valueColor: result.refund > 0 ? context.compliance.success : null,
          ),
          MetricRow(
            label: 'Payable',
            value: formatMoney(result.payable),
            valueColor: result.payable > 0 ? context.compliance.danger : null,
          ),
        ],
      ),
    );
  }
}
