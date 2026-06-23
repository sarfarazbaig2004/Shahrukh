import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';

/// -----------------------------------------------------------------
/// 1. DASHBOARD CARD
/// Reusable container wrapper with a consistent standard ERP styling.
/// -----------------------------------------------------------------
class DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const DashboardCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kAppRadiusLg),
        border: Border.all(color: zBorder),
        boxShadow: [
          BoxShadow(
            color: zText.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Allows dynamic scaling
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------
/// 2. SECTION HEADER
/// Clean, standard heading for breaking up dashboard sections.
/// -----------------------------------------------------------------
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
      ),
    );
  }
}

/// -----------------------------------------------------------------
/// 3. KPI CARD
/// Advanced metrics card with trend indicators and themed icon boxes.
/// -----------------------------------------------------------------
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trendText;
  final bool isPositive;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trendText,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final Color trendColor = isPositive ? zBlue : zMuted;
    final IconData trendIcon = isPositive
        ? Icons.trending_up_rounded
        : Icons.schedule_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kAppRadiusLg),
        border: Border.all(color: zBorder),
        boxShadow: [
          BoxShadow(
            color: zText.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zBlueSoft,
                  borderRadius: BorderRadius.circular(kAppRadiusSm),
                ),
                child: const Icon(
                  Icons.hexagon_outlined,
                  size: 18,
                  color: zBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(trendIcon, size: 16, color: trendColor),
              const SizedBox(width: 4),
              Text(
                trendText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: trendColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------
/// 4. ACTION CARD
/// Large interactive buttons for the Quick Actions section.
/// -----------------------------------------------------------------
class ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kAppRadiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kAppRadiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kAppRadiusLg),
            border: Border.all(color: zBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: zBlue),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------
/// 5. ACTIVITY ITEM
/// List tile style element for recent system activities.
/// -----------------------------------------------------------------
class ActivityItem extends StatelessWidget {
  final String text;

  const ActivityItem({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history_rounded, size: 18, color: Color(0xFF94A3B8)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------
/// 6. TASK ITEM
/// List tile style element for pending tasks.
/// -----------------------------------------------------------------
class TaskItem extends StatelessWidget {
  final String text;

  const TaskItem({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_box_outline_blank_rounded,
          size: 18,
          color: Color(0xFF94A3B8),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------
/// 7. TRANSACTION ITEM
/// Dual-column list item with dynamic styling based on transaction status.
/// -----------------------------------------------------------------
class TransactionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final bool isPositive;
  final String status;

  const TransactionItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPaid = status.toLowerCase() == 'paid';
    final Color badgeBgColor = isPaid
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);
    final Color badgeTextColor = isPaid
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    final Color amountColor = isPositive ? const Color(0xFF16A34A) : zText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
