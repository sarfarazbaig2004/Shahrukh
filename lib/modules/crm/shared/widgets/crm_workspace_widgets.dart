import 'package:flutter/material.dart';

enum CrmActionVariant {
  primary,
  secondary,
  subtle,
  danger,
}

class CrmActionDefinition {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final CrmActionVariant variant;
  final String? tooltip;

  const CrmActionDefinition({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = CrmActionVariant.secondary,
    this.tooltip,
  });
}

class CrmActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final CrmActionVariant variant;
  final bool compact;
  final String? tooltip;

  const CrmActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = CrmActionVariant.secondary,
    this.compact = false,
    this.tooltip,
  });

  factory CrmActionButton.fromDefinition(
      CrmActionDefinition definition, {
        Key? key,
        bool compact = false,
      }) {
    return CrmActionButton(
      key: key,
      label: definition.label,
      icon: definition.icon,
      onPressed: definition.onPressed,
      variant: definition.variant,
      compact: compact,
      tooltip: definition.tooltip,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );

    Widget button;
    switch (variant) {
      case CrmActionVariant.primary:
        button = ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFCBD5E1),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: padding,
            shape: shape,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        break;
      case CrmActionVariant.danger:
        button = OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFFECACA)),
            padding: padding,
            shape: shape,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        break;
      case CrmActionVariant.subtle:
        button = TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF475569),
            padding: padding,
            shape: shape,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        break;
      case CrmActionVariant.secondary:
        button = OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: padding,
            shape: shape,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        break;
    }

    if (tooltip == null || tooltip!.trim().isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class CrmInlineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color foregroundColor;

  const CrmInlineActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.foregroundColor = const Color(0xFF475569),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrmStatusPill extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color? backgroundColor;
  final IconData? icon;
  final double maxWidth;

  const CrmStatusPill({
    super.key,
    required this.label,
    required this.foregroundColor,
    this.backgroundColor,
    this.icon,
    this.maxWidth = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? foregroundColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: foregroundColor.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foregroundColor),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
