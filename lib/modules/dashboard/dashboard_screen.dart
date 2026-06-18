// FILE: lib/modules/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:QUIK/modules/dashboard/dashboard_widgets.dart';
import 'package:QUIK/modules/dashboard/dashboard_service.dart';
import 'package:QUIK/modules/dashboard/dashboard_charts.dart';

class DashboardScreen extends StatefulWidget {
  final String companyId;
  final String userName;
  final String currentUserId;
  final Map<String, dynamic> permissions;
  final String role;

  const DashboardScreen({
    super.key,
    required this.companyId,
    required this.userName,
    required this.currentUserId,
    required this.permissions,
    required this.role,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardService _service;

  @override
  void initState() {
    super.initState();
    _service = DashboardService(companyId: widget.companyId);
  }

  bool hasPermission(String module, String submodule) {
    final r = widget.role.toLowerCase();
    if (['admin', 'owner', 'ceo', 'manager', 'superadmin'].contains(r)) {
      return true;
    }

    final moduleData = widget.permissions[module];
    if (moduleData is Map && moduleData.containsKey(submodule)) {
      return moduleData[submodule] == true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildDashboardElements(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDashboardElements(BuildContext context) {
    List<Widget> elements = [];

    elements.add(_buildHeader());

    final kpiSection = _buildKpiSection();
    if (kpiSection != null) elements.add(kpiSection);

    final chartSection = _buildChartSection();
    if (chartSection != null) elements.add(chartSection);

    final crmSection = _buildCrmSection();
    if (crmSection != null) elements.add(crmSection);

    final tasksSection = _buildTasksActivitiesSection();
    if (tasksSection != null) elements.add(tasksSection);

    final transactionsSection = _buildTransactionsSection();
    if (transactionsSection != null) elements.add(transactionsSection);

    final actionsSection = _buildQuickActionsSection(context);
    if (actionsSection != null) elements.add(actionsSection);

    final alertsSection = _buildAlertsSection();
    if (alertsSection != null) elements.add(alertsSection);

    elements.add(const SizedBox(height: 20));

    List<Widget> spacedElements = [];
    for (int i = 0; i < elements.length; i++) {
      spacedElements.add(elements[i]);
      if (i < elements.length - 1) {
        spacedElements.add(const SizedBox(height: 20));
      }
    }

    return spacedElements;
  }

  Widget _buildHeader() {
    final displayName = widget.userName.isNotEmpty ? widget.userName : 'Admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome $displayName',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Here is your live business overview.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget? _buildKpiSection() {
    final showRevenue = hasPermission('finance', 'taxInvoice');
    final showOutstanding = hasPermission('finance', 'outstanding');
    final showQuotes = hasPermission('sales', 'quotations');
    final showConversion = hasPermission('sales', 'inquiries');

    if (!showRevenue && !showOutstanding && !showQuotes && !showConversion) {
      return null;
    }

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Overview'),
        const SizedBox(height: 16),
        StreamBuilder<DashboardKpiData>(
          stream: _service.streamKpiData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data!;
            List<Widget> visibleKpis = [];

            if (showRevenue) {
              visibleKpis.add(
                KpiCard(
                  title: 'Total Revenue',
                  value: formatter.format(data.totalRevenue),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF3B82F6),
                  trendText: 'Live Data',
                  isPositive: true,
                ),
              );
            }

            if (showOutstanding) {
              visibleKpis.add(
                KpiCard(
                  title: 'Outstanding',
                  value: formatter.format(data.totalOutstanding),
                  icon: Icons.access_time_rounded,
                  color: const Color(0xFFF59E0B),
                  trendText: 'Pending Collections',
                  isPositive: false,
                ),
              );
            }

            if (showQuotes) {
              visibleKpis.add(
                KpiCard(
                  title: 'Active Quotes',
                  value: data.activeQuotes.toString(),
                  icon: Icons.description_outlined,
                  color: const Color(0xFF8B5CF6),
                  trendText: 'In Pipeline',
                  isPositive: true,
                ),
              );
            }

            if (showConversion) {
              visibleKpis.add(
                KpiCard(
                  title: 'Conversion Rate',
                  value: '${data.conversionRate.toStringAsFixed(1)}%',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF10B981),
                  trendText: 'Avg Performance',
                  isPositive: true,
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;
                int crossAxisCount = width > 1000 ? 4 : (width > 650 ? 2 : 1);
                if (visibleKpis.length < crossAxisCount) {
                  crossAxisCount = visibleKpis.length;
                }
                double spacing = 16;
                double cardWidth =
                    (width - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: visibleKpis
                      .map((kpi) => SizedBox(width: cardWidth, child: kpi))
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget? _buildChartSection() {
    final showSalesChart =
        hasPermission('sales', 'quotations') ||
        hasPermission('sales', 'inquiries') ||
        hasPermission('finance', 'taxInvoice');
    final showPaymentChart = hasPermission('finance', 'paymentReceived');

    if (!showSalesChart && !showPaymentChart) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Analytics'),
        const SizedBox(height: 16),
        StreamBuilder<DashboardChartData>(
          stream: _service.streamChartData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data!;

            Widget salesChart = DashboardCard(
              title: 'Sales Overview',
              child: SizedBox(
                height: 280,
                child: SalesBarChart(monthlySales: data.monthlySales),
              ),
            );

            Widget paymentChart = DashboardCard(
              title: 'Payment Analytics',
              child: SizedBox(
                height: 280,
                child: PaymentPieChart(
                  paidAmount: data.paidAmount,
                  pendingAmount: data.pendingAmount,
                ),
              ),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 800;

                if (showSalesChart && showPaymentChart) {
                  return isWide
                      ? Row(
                          children: [
                            Expanded(flex: 3, child: salesChart),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: paymentChart),
                          ],
                        )
                      : Column(
                          children: [
                            salesChart,
                            const SizedBox(height: 16),
                            paymentChart,
                          ],
                        );
                } else if (showSalesChart) {
                  return salesChart;
                } else {
                  return paymentChart;
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget? _buildCrmSection() {
    if (!hasPermission('crm', 'customers')) return null;

    const kpiStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFF0F172A),
      letterSpacing: -0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'CRM Overview'),
        const SizedBox(height: 16),
        StreamBuilder<DashboardCrmData>(
          stream: _service.streamCrmData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;
                double cardWidth = width > 800
                    ? (width - 32) / 3
                    : (width > 500 ? (width - 16) / 2 : width);

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: DashboardCard(
                        title: 'Open Deals',
                        child: Text(data.openDeals.toString(), style: kpiStyle),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: DashboardCard(
                        title: 'New Inquiries',
                        child: Text(
                          data.newInquiries.toString(),
                          style: kpiStyle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget? _buildTasksActivitiesSection() {
    final showTasks = hasPermission('sales', 'tasks');
    final showMeetings = hasPermission('sales', 'meetings');

    if (!showTasks && !showMeetings) return null;

    const kpiStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFF0F172A),
      letterSpacing: -0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Productivity'),
        const SizedBox(height: 16),
        StreamBuilder<DashboardProductivityData>(
          stream: _service.streamProductivityData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data!;
            final cards = <Widget>[];

            if (showTasks) {
              cards.add(
                DashboardCard(
                  title: 'Open Tasks',
                  child: Text(data.openTasks.toString(), style: kpiStyle),
                ),
              );
              cards.add(
                DashboardCard(
                  title: 'Critical Tasks',
                  child: Text(data.criticalTasks.toString(), style: kpiStyle),
                ),
              );
            }

            if (showMeetings) {
              cards.add(
                DashboardCard(
                  title: 'Upcoming Meetings',
                  child: Text(
                    data.upcomingMeetings.toString(),
                    style: kpiStyle,
                  ),
                ),
              );
              cards.add(
                DashboardCard(
                  title: 'Today Meetings',
                  child: Text(data.todayMeetings.toString(), style: kpiStyle),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth = width > 1000
                    ? (width - 48) / 4
                    : (width > 650 ? (width - 16) / 2 : width);

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: cards
                      .map((card) => SizedBox(width: cardWidth, child: card))
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget? _buildTransactionsSection() {
    if (!hasPermission('finance', 'paymentReceived')) return null;

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    );

    return StreamBuilder<List<DashboardTransaction>>(
      stream: _service.streamRecentTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final transactions = snapshot.data!;

        if (transactions.isEmpty) {
          return const DashboardCard(
            title: 'Recent Transactions',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No recent transactions found.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          );
        }

        return DashboardCard(
          title: 'Recent Transactions',
          trailing: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
            ),
            child: const Text(
              'View All',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return TransactionItem(
                title: txn.title,
                subtitle: txn.subtitle,
                amount: '+ ${formatter.format(txn.amount)}',
                isPositive: txn.isPositive,
                status: txn.status,
              );
            },
          ),
        );
      },
    );
  }

  Widget? _buildQuickActionsSection(BuildContext context) {
    List<Widget> actions = [];

    void navigateTo(String title) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: Text('Module Screen Placeholder')),
          ),
        ),
      );
    }

    if (hasPermission('sales', 'inquiries')) {
      actions.add(
        ActionCard(
          icon: Icons.campaign_rounded,
          label: 'Add Inquiry',
          onTap: () => navigateTo('Add Inquiry'),
        ),
      );
    }
    if (hasPermission('sales', 'quotations')) {
      actions.add(
        ActionCard(
          icon: Icons.receipt_long_outlined,
          label: 'Create Quotation',
          onTap: () => navigateTo('Create Quotation'),
        ),
      );
    }
    if (hasPermission('finance', 'taxInvoice')) {
      actions.add(
        ActionCard(
          icon: Icons.add_card_rounded,
          label: 'New Invoice',
          onTap: () => navigateTo('New Invoice'),
        ),
      );
    }
    if (hasPermission('finance', 'paymentReceived')) {
      actions.add(
        ActionCard(
          icon: Icons.receipt_long_rounded,
          label: 'Record Payment',
          onTap: () => navigateTo('Record Payment'),
        ),
      );
    }
    if (hasPermission('crm', 'customers')) {
      actions.add(
        ActionCard(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Add Customer',
          onTap: () => navigateTo('Add Customer'),
        ),
      );
    }

    if (actions.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            double width = constraints.maxWidth;
            double cardWidth = width > 800
                ? (width - 32) / 3
                : (width > 500 ? (width - 16) / 2 : width);

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: actions
                  .map((a) => SizedBox(width: cardWidth, child: a))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget? _buildAlertsSection() {
    if (!hasPermission('inventory', 'lowStockAlerts')) return null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border(
          left: BorderSide(color: Color(0xFFF97316), width: 4),
          top: BorderSide(color: Color(0xFFFFEDD5)),
          right: BorderSide(color: Color(0xFFFFEDD5)),
          bottom: BorderSide(color: Color(0xFFFFEDD5)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF97316),
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'System Alert: Dashboard connected to live Firestore data successfully.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              foregroundColor: const Color(0xFFC2410C),
            ),
            child: const Text(
              'Review',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
