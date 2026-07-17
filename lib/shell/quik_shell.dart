// FILE PATH: lib/modules/shell/quik_shell.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/administration/users/screen_user_management.dart';
import 'package:QUIK/modules/administration/compliance_legal/screens_compliance_legal_list.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_list.dart';
import 'package:QUIK/modules/crm/contacts/screens_contact_list.dart';
import 'package:QUIK/modules/crm/customer_visits/customer_visit_list_screen.dart';
import 'package:QUIK/modules/dashboard/dashboard_screen.dart';
import 'package:QUIK/modules/dispatch/screens/ready_for_dispatch_screen.dart';
import 'package:QUIK/modules/dispatch/screens/dispatch_challans_screen.dart';
import 'package:QUIK/modules/dispatch/screens/shipment_tracking_screen.dart';
import 'package:QUIK/modules/dispatch/screens/delivered_orders_screen.dart';
import 'package:QUIK/modules/inventory/products/screens_product_list.dart';
import 'package:QUIK/modules/inventory/stock_in/screens_stock_in_list.dart';
import 'package:QUIK/modules/sales/inquiries/screens_inquiry_list.dart';
import 'package:QUIK/modules/sales/quotations/screens_quotation_list.dart';
import 'package:QUIK/modules/settings/screen_settings_home.dart';
import 'package:QUIK/modules/sales/sales_orders/screens_sales_order_list.dart';
import 'package:QUIK/modules/sales/Task/screen_tasks.dart';

// Finance Sub-Modules
import 'package:QUIK/modules/finance/invoice/screens/invoice_list_screen.dart';
import 'package:QUIK/modules/finance/invoice/export_invoice/screens/export_invoice_screen.dart';
import 'package:QUIK/modules/finance/invoice/tax_invoice/tax_invoice_screen.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_list_screen.dart';

// Payments & Outstanding Sub-Modules
import 'package:QUIK/modules/finance/payments_received/screens/payments_list_screen.dart';
import 'package:QUIK/modules/finance/outstanding/screens/outstanding_screen.dart';

// Reports
import 'package:QUIK/modules/reports/sales_report/sales_report_screen.dart';

// Service Sub-Modules
import 'package:QUIK/modules/service/service_requests/service_request_list_screen.dart';
import 'package:QUIK/modules/service/service_quotations/service_quotation_list_screen.dart';
import 'package:QUIK/modules/service/service_sales_orders/service_sales_order_list_screen.dart';
import 'package:QUIK/modules/service/service_visits/service_visit_list_screen.dart';
import 'package:QUIK/modules/service/service_technicians/service_technician_list_screen.dart';

// Purchase Sub-Modules
import 'package:QUIK/modules/purchase/purchase_bills/purchase_bill_screens.dart';
import 'package:QUIK/modules/purchase/vendors/screens_vendor_list.dart';

/// ---- ENTERPRISE DESIGN SYSTEM CONSTANTS ----
class ShellLayout {
  static const double sidebarExpandedWidth = 204.0;
  static const double sidebarCollapsedWidth = 60.0;
  static const double headerHeight = 44.0;
  static const double sidebarItemHeight = 34.0;
  static const double sidebarGroupHeight = 36.0;
  static const double pagePadding = 12.0;
  static const double cardPadding = 10.0;
  static const double sectionSpacing = 8.0;
  static const double borderRadius = 6.0;
  static const Duration animDuration = Duration(milliseconds: 200);
  static const Duration animFast = Duration(milliseconds: 150);
}

enum ShellPage {
  dashboard,

  salesInquiries,
  salesQuotations,
  salesOrders,
  salesTasks,

  // Professional Service Workflow
  serviceRequests,
  serviceQuotations,
  serviceSalesOrders,
  serviceVisits,
  serviceTechnicians,

  crmCustomers,
  crmContacts,
  crmVisits,

  purchaseVendors,
  purchaseQuotations,
  purchaseOrders,
  purchaseBills,

  inventoryProducts,
  inventoryStockSummary,
  inventoryStockIn,
  inventoryStockOut,
  inventoryWarehouse,
  inventoryLowStock,

  dispatchReady,
  dispatchChallans,
  dispatchShipmentTracking,
  dispatchDelivered,

  financeProforma,
  financeTaxInvoice,
  financeTaxInvoiceCreate,
  financeExportInvoiceCreate,
  financePaymentsReceived,
  financeOutstanding,
  financeExpenses,

  reportsSales,
  reportsInquiry,
  reportsCustomer,
  reportsProduct,
  reportsPayment,

  adminUsers,
  adminAuditLogs,
  adminComplianceLegal,

  settingsGeneral,
}

extension ShellPageX on ShellPage {
  String get label {
    switch (this) {
      case ShellPage.dashboard:
        return 'Dashboard';
      case ShellPage.salesInquiries:
        return 'Inquiries';
      case ShellPage.salesQuotations:
        return 'Quotations';
      case ShellPage.salesOrders:
        return 'Sales Orders';
      case ShellPage.salesTasks:
        return 'Tasks';
      case ShellPage.serviceRequests:
        return 'Service Requests';
      case ShellPage.serviceQuotations:
        return 'Service Quotations';
      case ShellPage.serviceSalesOrders:
        return 'Service Sales Orders';
      case ShellPage.serviceVisits:
        return 'Service Visits';
      case ShellPage.serviceTechnicians:
        return 'Service Technicians';
      case ShellPage.crmCustomers:
        return 'Customers';
      case ShellPage.crmContacts:
        return 'Contacts';
      case ShellPage.crmVisits:
        return 'Customer Visits';
      case ShellPage.purchaseVendors:
        return 'Vendors';
      case ShellPage.purchaseQuotations:
        return 'Purchase Quotations';
      case ShellPage.purchaseOrders:
        return 'Purchase Orders';
      case ShellPage.purchaseBills:
        return 'Purchase Bills';
      case ShellPage.inventoryProducts:
        return 'Products';
      case ShellPage.inventoryStockSummary:
        return 'Stock Summary';
      case ShellPage.inventoryStockIn:
        return 'Stock In';
      case ShellPage.inventoryStockOut:
        return 'Stock Out';
      case ShellPage.inventoryWarehouse:
        return 'Warehouse';
      case ShellPage.inventoryLowStock:
        return 'Low Stock Alerts';
      case ShellPage.dispatchReady:
        return 'Ready for Dispatch';
      case ShellPage.dispatchChallans:
        return 'Dispatch Challans';
      case ShellPage.dispatchShipmentTracking:
        return 'Shipment Tracking';
      case ShellPage.dispatchDelivered:
        return 'Delivered Orders';
      case ShellPage.financeProforma:
        return 'Proforma Invoice';
      case ShellPage.financeTaxInvoice:
        return 'Invoice';
      case ShellPage.financeTaxInvoiceCreate:
        return 'Create Tax Invoice';
      case ShellPage.financeExportInvoiceCreate:
        return 'Create Export Invoice';
      case ShellPage.financePaymentsReceived:
        return 'Payments Received';
      case ShellPage.financeOutstanding:
        return 'Outstanding';
      case ShellPage.financeExpenses:
        return 'Expense Entries';
      case ShellPage.reportsSales:
        return 'Sales Report';
      case ShellPage.reportsInquiry:
        return 'Inquiry Report';
      case ShellPage.reportsCustomer:
        return 'Customer Report';
      case ShellPage.reportsProduct:
        return 'Product Report';
      case ShellPage.reportsPayment:
        return 'Payment Report';
      case ShellPage.adminUsers:
        return 'Users';
      case ShellPage.adminAuditLogs:
        return 'Audit Logs';
      case ShellPage.adminComplianceLegal:
        return 'Compliance & Legal';
      case ShellPage.settingsGeneral:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case ShellPage.dashboard:
        return Icons.grid_view_rounded;
      case ShellPage.salesInquiries:
        return Icons.campaign_outlined;
      case ShellPage.salesQuotations:
        return Icons.receipt_long_outlined;
      case ShellPage.salesOrders:
        return Icons.shopping_bag_outlined;
      case ShellPage.salesTasks:
        return Icons.task_alt_outlined;
      case ShellPage.serviceRequests:
        return Icons.support_agent_outlined;
      case ShellPage.serviceQuotations:
        return Icons.request_quote_outlined;
      case ShellPage.serviceSalesOrders:
        return Icons.assignment_turned_in_outlined;
      case ShellPage.serviceVisits:
        return Icons.directions_car_outlined;
      case ShellPage.serviceTechnicians:
        return Icons.engineering_outlined;
      case ShellPage.crmCustomers:
        return Icons.people_outline;
      case ShellPage.crmContacts:
        return Icons.contact_phone_outlined;
      case ShellPage.crmVisits:
        return Icons.location_on_outlined;
      case ShellPage.purchaseVendors:
        return Icons.business_outlined;
      case ShellPage.purchaseQuotations:
        return Icons.request_quote_outlined;
      case ShellPage.purchaseOrders:
        return Icons.shopping_cart_checkout_outlined;
      case ShellPage.purchaseBills:
        return Icons.receipt_long_outlined;
      case ShellPage.inventoryProducts:
        return Icons.inventory_2_outlined;
      case ShellPage.inventoryStockSummary:
        return Icons.bar_chart_outlined;
      case ShellPage.inventoryStockIn:
        return Icons.move_to_inbox_outlined;
      case ShellPage.inventoryStockOut:
        return Icons.outbox_outlined;
      case ShellPage.inventoryWarehouse:
        return Icons.warehouse_outlined;
      case ShellPage.inventoryLowStock:
        return Icons.warning_amber_outlined;
      case ShellPage.dispatchReady:
        return Icons.inventory_2_outlined;
      case ShellPage.dispatchChallans:
        return Icons.local_shipping_outlined;
      case ShellPage.dispatchShipmentTracking:
        return Icons.route_outlined;
      case ShellPage.dispatchDelivered:
        return Icons.done_all_outlined;
      case ShellPage.financeProforma:
        return Icons.request_quote_outlined;
      case ShellPage.financeTaxInvoice:
        return Icons.description_outlined;
      case ShellPage.financeTaxInvoiceCreate:
        return Icons.receipt_long_outlined;
      case ShellPage.financeExportInvoiceCreate:
        return Icons.public_outlined;
      case ShellPage.financePaymentsReceived:
        return Icons.payments_outlined;
      case ShellPage.financeOutstanding:
        return Icons.account_balance_wallet_outlined;
      case ShellPage.financeExpenses:
        return Icons.receipt_outlined;
      case ShellPage.reportsSales:
        return Icons.show_chart_outlined;
      case ShellPage.reportsInquiry:
        return Icons.insights_outlined;
      case ShellPage.reportsCustomer:
        return Icons.people_alt_outlined;
      case ShellPage.reportsProduct:
        return Icons.widgets_outlined;
      case ShellPage.reportsPayment:
        return Icons.pie_chart_outline;
      case ShellPage.adminUsers:
        return Icons.manage_accounts_outlined;
      case ShellPage.adminAuditLogs:
        return Icons.fact_check_outlined;
      case ShellPage.adminComplianceLegal:
        return Icons.gavel_outlined;
      case ShellPage.settingsGeneral:
        return Icons.settings_outlined;
    }
  }
}

class SidebarGroup {
  final String key;
  final String title;
  final IconData icon;
  final List<ShellPage> children;

  const SidebarGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.children,
  });
}

class ZohoShell extends StatefulWidget {
  final String userEmail;
  final String userUid;
  final String companyId;
  final String companyName;
  final String role;
  final Map<String, dynamic> permissions;
  final String? userDisplayName;
  final String? industry;

  const ZohoShell({
    super.key,
    required this.userEmail,
    required this.userUid,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.permissions,
    this.userDisplayName,
    this.industry,
  });

  @override
  State<ZohoShell> createState() => _ZohoShellState();
}

class _ZohoShellState extends State<ZohoShell> {
  ShellPage activePage = ShellPage.dashboard;
  final Set<String> expandedGroups = {};

  String? _resolvedIndustry;
  bool _isLoadingIndustry = true;
  String _currentRole = 'viewer';
  Map<String, dynamic> _currentPermissions = {};
  List<SidebarGroup> _currentSidebarGroups = [];

  bool _isSidebarCollapsed = false;

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _userSessionStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _inquiryCountStream;

  SharedPreferences? _prefs;
  String get _prefsGroupsKey =>
      'quik_expanded_groups_${widget.userUid}_${widget.companyId}';
  String get _prefsCollapseKey =>
      'quik_sidebar_collapsed_${widget.userUid}_${widget.companyId}';

  @override
  void initState() {
    super.initState();
    _resolvedIndustry = widget.industry;

    _userSessionStream = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('users')
        .doc(widget.userUid)
        .snapshots();

    _inquiryCountStream = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('inquiries')
        .where('assignedToUid', isEqualTo: widget.userUid)
        .snapshots();

    if (_resolvedIndustry == null || _resolvedIndustry!.isEmpty) {
      _fetchIndustry();
    } else {
      _isLoadingIndustry = false;
    }

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    final savedGroups = _prefs?.getStringList(_prefsGroupsKey);
    if (savedGroups != null && savedGroups.isNotEmpty) {
      setState(() {
        expandedGroups.addAll(savedGroups);
      });
    }

    final isCollapsed = _prefs?.getBool(_prefsCollapseKey);
    if (isCollapsed != null) {
      setState(() {
        _isSidebarCollapsed = isCollapsed;
      });
    }
  }

  Future<void> _toggleGroup(String groupKey) async {
    setState(() {
      if (expandedGroups.contains(groupKey)) {
        expandedGroups.remove(groupKey);
      } else {
        expandedGroups.add(groupKey);
      }
    });

    if (_prefs != null) {
      await _prefs!.setStringList(_prefsGroupsKey, expandedGroups.toList());
    }
  }

  Future<void> _toggleSidebar() async {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
    if (_prefs != null) {
      await _prefs!.setBool(_prefsCollapseKey, _isSidebarCollapsed);
    }
  }

  Future<void> _fetchIndustry() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final raw =
            (data['industryType'] ??
                    data['businessCategory'] ??
                    data['industry'] ??
                    '')
                .toString()
                .toLowerCase();

        _resolvedIndustry = raw;
      } else {
        _resolvedIndustry = 'unknown';
      }
    } catch (e) {
      _resolvedIndustry = 'unknown';
    }

    if (mounted) {
      setState(() {
        _isLoadingIndustry = false;
      });
    }
  }

  bool get isAdminOrManager {
    final r = _currentRole;
    return r == 'owner' ||
        r == 'founder' ||
        r == 'ceo' ||
        r == 'superadmin' ||
        r == 'admin' ||
        r == 'manager';
  }

  bool _checkPerm(String module, String submodule, String action) {
    final moduleData = _currentPermissions[module];
    if (moduleData is Map && moduleData.containsKey(submodule)) {
      final subData = moduleData[submodule];
      if (subData is Map) return subData[action] == true;
      return subData == true;
    }

    if (_currentPermissions.containsKey(submodule)) {
      final legacySubData = _currentPermissions[submodule];
      if (legacySubData is Map) return legacySubData[action] == true;
      return legacySubData == true && action == 'view';
    }

    if (_currentPermissions.containsKey('$module.$submodule')) {
      return _currentPermissions['$module.$submodule'] == true &&
          action == 'view';
    }

    return false;
  }

  List<String> _getAliasesFor(String module, String submodule) {
    if (module == 'service') {
      switch (submodule) {
        case 'serviceRequests':
          return const [
            'serviceRequests',
            'serviceRequest',
            'serviceCalls',
            'serviceCall',
            'complaints',
            'serviceComplaints',
          ];
        case 'serviceQuotations':
          return const ['serviceQuotations', 'serviceQuotation', 'quotations'];
        case 'serviceSalesOrders':
          return const [
            'serviceSalesOrders',
            'serviceSalesOrder',
            'workOrders',
            'serviceWorkOrders',
          ];
        case 'serviceVisits':
          return const ['serviceVisits', 'serviceVisit'];
        case 'serviceTechnicians':
          return const ['serviceTechnicians', 'serviceTechnician'];
      }
    } else if (module == 'sales') {
      if (submodule == 'salesOrders')
        return const ['salesOrders', 'salesOrder'];
    } else if (module == 'purchase') {
      if (submodule == 'purchaseOrders')
        return const ['purchaseOrders', 'purchaseOrder'];
      if (submodule == 'purchaseQuotations')
        return const ['purchaseQuotations', 'purchaseQuotation'];
      if (submodule == 'purchaseBills')
        return const ['purchaseBills', 'purchaseBill'];
    } else if (module == 'crm') {
      if (submodule == 'customers') return const ['customers', 'customer'];
    }
    return [submodule];
  }

  bool _hasPermission(
    String module,
    String submodule, {
    String action = 'view',
  }) {
    if (isAdminOrManager) return true;

    final aliases = _getAliasesFor(module, submodule);

    for (final alias in aliases) {
      if (_checkPerm(module, alias, action)) return true;
      if (!alias.endsWith('s') && _checkPerm(module, '${alias}s', action))
        return true;
      if (alias.endsWith('s') &&
          _checkPerm(module, alias.substring(0, alias.length - 1), action))
        return true;
    }
    return false;
  }

  bool get canInquiries {
    return _hasPermission('sales', 'inquiries');
  }

  bool _canViewPage(ShellPage page) {
    if (isAdminOrManager) return true;

    switch (page) {
      case ShellPage.dashboard:
        return true;
      case ShellPage.settingsGeneral:
        return true;
      case ShellPage.salesInquiries:
        return _hasPermission('sales', 'inquiries');
      case ShellPage.salesQuotations:
        return _hasPermission('sales', 'quotations');
      case ShellPage.salesOrders:
        return _hasPermission('sales', 'salesOrders');
      case ShellPage.salesTasks:
        return _hasPermission('sales', 'tasks');
      case ShellPage.serviceRequests:
        return _hasPermission('service', 'serviceRequests');
      case ShellPage.serviceQuotations:
        return _hasPermission('service', 'serviceQuotations');
      case ShellPage.serviceSalesOrders:
        return _hasPermission('service', 'serviceSalesOrders');
      case ShellPage.serviceVisits:
        return _hasPermission('service', 'serviceVisits');
      case ShellPage.serviceTechnicians:
        return _hasPermission('service', 'serviceTechnicians');
      case ShellPage.crmCustomers:
        return _hasPermission('crm', 'customers');
      case ShellPage.crmContacts:
        return _hasPermission('crm', 'contacts');
      case ShellPage.crmVisits:
        return _hasPermission('crm', 'customerVisits');
      case ShellPage.purchaseVendors:
        return _hasPermission('purchase', 'vendors');
      case ShellPage.purchaseQuotations:
        return _hasPermission('purchase', 'purchaseQuotations');
      case ShellPage.purchaseOrders:
        return _hasPermission('purchase', 'purchaseOrders');
      case ShellPage.purchaseBills:
        return _hasPermission('purchase', 'purchaseBills');
      case ShellPage.inventoryProducts:
        return _hasPermission('inventory', 'products');
      case ShellPage.inventoryStockSummary:
        return _hasPermission('inventory', 'stockSummary');
      case ShellPage.inventoryStockIn:
        return _hasPermission('inventory', 'stockIn');
      case ShellPage.inventoryStockOut:
        return _hasPermission('inventory', 'stockOut');
      case ShellPage.inventoryWarehouse:
        return _hasPermission('inventory', 'warehouse');
      case ShellPage.inventoryLowStock:
        return _hasPermission('inventory', 'lowStockAlerts');
      case ShellPage.dispatchReady:
        return _hasPermission('dispatch', 'readyForDispatch');
      case ShellPage.dispatchChallans:
        return _hasPermission('dispatch', 'dispatchChallans');
      case ShellPage.dispatchShipmentTracking:
        return _hasPermission('dispatch', 'shipmentTracking');
      case ShellPage.dispatchDelivered:
        return _hasPermission('dispatch', 'deliveredOrders');
      case ShellPage.financeProforma:
        return _hasPermission('finance', 'proformaInvoice');
      case ShellPage.financeTaxInvoice:
      case ShellPage.financeTaxInvoiceCreate:
      case ShellPage.financeExportInvoiceCreate:
        return _hasPermission('finance', 'taxInvoice');
      case ShellPage.financePaymentsReceived:
        return _hasPermission('finance', 'paymentReceived');
      case ShellPage.financeOutstanding:
        return _hasPermission('finance', 'outstanding');
      case ShellPage.financeExpenses:
        return _hasPermission('finance', 'expenseEntries');
      case ShellPage.reportsSales:
        return _hasPermission('reports', 'salesReport');
      case ShellPage.reportsInquiry:
        return _hasPermission('reports', 'inquiryReport');
      case ShellPage.reportsCustomer:
        return _hasPermission('reports', 'customerReport');
      case ShellPage.reportsProduct:
        return _hasPermission('reports', 'productReport');
      case ShellPage.reportsPayment:
        return _hasPermission('reports', 'paymentReport');
      case ShellPage.adminUsers:
        return _hasPermission('administration', 'users');
      case ShellPage.adminAuditLogs:
        return _hasPermission('administration', 'auditLogs');
      case ShellPage.adminComplianceLegal:
        return _hasPermission('administration', 'complianceLegal');
    }
  }

  List<SidebarGroup> get _allSidebarGroups {
    return const [
      SidebarGroup(
        key: 'sales',
        title: 'Sales',
        icon: Icons.trending_up_outlined,
        children: [
          ShellPage.salesInquiries,
          ShellPage.salesQuotations,
          ShellPage.salesOrders,
          ShellPage.salesTasks,
        ],
      ),
      SidebarGroup(
        key: 'crm',
        title: 'CRM',
        icon: Icons.people_alt_outlined,
        children: [
          ShellPage.crmCustomers,
          ShellPage.crmContacts,
          ShellPage.crmVisits,
        ],
      ),
      SidebarGroup(
        key: 'service',
        title: 'Service',
        icon: Icons.build_outlined,
        children: [
          ShellPage.serviceRequests,
          ShellPage.serviceQuotations,
          ShellPage.serviceSalesOrders,
          ShellPage.serviceVisits,
          ShellPage.serviceTechnicians,
        ],
      ),
      SidebarGroup(
        key: 'inventory',
        title: 'Inventory',
        icon: Icons.inventory_2_outlined,
        children: [
          ShellPage.inventoryProducts,
          ShellPage.inventoryStockSummary,
          ShellPage.inventoryStockIn,
          ShellPage.inventoryStockOut,
          ShellPage.inventoryWarehouse,
          ShellPage.inventoryLowStock,
        ],
      ),
      SidebarGroup(
        key: 'purchase',
        title: 'Purchase',
        icon: Icons.shopping_cart_outlined,
        children: [
          ShellPage.purchaseVendors,
          ShellPage.purchaseQuotations,
          ShellPage.purchaseOrders,
          ShellPage.purchaseBills,
        ],
      ),
      SidebarGroup(
        key: 'dispatch',
        title: 'Dispatch',
        icon: Icons.local_shipping_outlined,
        children: [
          ShellPage.dispatchReady,
          ShellPage.dispatchChallans,
          ShellPage.dispatchShipmentTracking,
          ShellPage.dispatchDelivered,
        ],
      ),
      SidebarGroup(
        key: 'finance',
        title: 'Finance',
        icon: Icons.account_balance_wallet_outlined,
        children: [
          ShellPage.financeProforma,
          ShellPage.financeTaxInvoice,
          ShellPage.financePaymentsReceived,
          ShellPage.financeOutstanding,
          ShellPage.financeExpenses,
        ],
      ),
      SidebarGroup(
        key: 'reports',
        title: 'Reports',
        icon: Icons.assessment_outlined,
        children: [
          ShellPage.reportsSales,
          ShellPage.reportsInquiry,
          ShellPage.reportsCustomer,
          ShellPage.reportsProduct,
          ShellPage.reportsPayment,
        ],
      ),
      SidebarGroup(
        key: 'admin',
        title: 'Administration',
        icon: Icons.admin_panel_settings_outlined,
        children: [
          ShellPage.adminUsers,
          ShellPage.adminAuditLogs,
          ShellPage.adminComplianceLegal,
        ],
      ),
    ];
  }

  List<SidebarGroup> _computeSidebarGroups() {
    final allGroups = _allSidebarGroups;
    final filtered = <SidebarGroup>[];

    for (var group in allGroups) {
      final allowedChildren = group.children
          .where((page) => _canViewPage(page))
          .toList();
      if (allowedChildren.isNotEmpty) {
        filtered.add(
          SidebarGroup(
            key: group.key,
            title: group.title,
            icon: group.icon,
            children: allowedChildren,
          ),
        );
      }
    }
    return filtered;
  }

  void _noAccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to access this module'),
      ),
    );
  }

  void _selectPage(ShellPage page) {
    if (!_canViewPage(page)) {
      _noAccess();
      return;
    }
    setState(() => activePage = page);
  }

  bool _isImplementedPage(ShellPage page) {
    switch (page) {
      case ShellPage.dashboard:
      case ShellPage.salesInquiries:
      case ShellPage.salesQuotations:
      case ShellPage.salesOrders:
      case ShellPage.salesTasks:
      case ShellPage.crmCustomers:
      case ShellPage.crmContacts:
      case ShellPage.crmVisits:
      case ShellPage.inventoryProducts:
      case ShellPage.adminUsers:
      case ShellPage.settingsGeneral:
      case ShellPage.financeProforma:
      case ShellPage.financeTaxInvoice:
      case ShellPage.financeTaxInvoiceCreate:
      case ShellPage.financeExportInvoiceCreate:
      case ShellPage.financePaymentsReceived:
      case ShellPage.financeOutstanding:
      case ShellPage.reportsSales:
      case ShellPage.serviceRequests:
      case ShellPage.serviceQuotations:
      case ShellPage.serviceSalesOrders:
      case ShellPage.serviceVisits:
      case ShellPage.serviceTechnicians:
      case ShellPage.adminComplianceLegal:
        return true;
      default:
        return false;
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  bool _groupContainsActive(SidebarGroup group) {
    return group.children.contains(activePage);
  }

  String _getBreadcrumbText() {
    if (activePage == ShellPage.dashboard) return 'Workspace / Dashboard';
    if (activePage == ShellPage.settingsGeneral) return 'Workspace / Settings';
    if (activePage == ShellPage.financeTaxInvoiceCreate)
      return 'Finance / Create Tax Invoice';
    if (activePage == ShellPage.financeExportInvoiceCreate)
      return 'Finance / Create Export Invoice';

    for (var group in _currentSidebarGroups) {
      if (group.children.contains(activePage)) {
        return '${group.title} / ${activePage.label}';
      }
    }
    return 'Workspace / ${activePage.label}';
  }

  String _resolvedEmployeeName() {
    final fromDisplayName = (widget.userDisplayName ?? '').trim();
    if (fromDisplayName.isNotEmpty) return fromDisplayName;

    final emailPrefix = widget.userEmail.split('@').first.trim();
    if (emailPrefix.isNotEmpty) return emailPrefix;

    return 'User';
  }

  String _dashboardWelcomeText() {
    if (isAdminOrManager) return 'Welcome ${widget.companyName}';
    return 'Welcome ${_resolvedEmployeeName()}';
  }

  // --- ENTERPRISE SHELL UI COMPONENTS ---

  Widget _buildTopHeader() {
    final breadcrumbs = _getBreadcrumbText().split(' / ');

    return Container(
      height: ShellLayout.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: ShellLayout.pagePadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: zBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: zMuted, size: 18),
            onPressed: _toggleSidebar,
            tooltip: _isSidebarCollapsed ? 'Expand Menu' : 'Collapse Menu',
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          if (breadcrumbs.length > 1) ...[
            Text(
              breadcrumbs[0],
              style: const TextStyle(
                fontSize: 13,
                color: zMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 14, color: Colors.black26),
            ),
            Text(
              breadcrumbs[1],
              style: const TextStyle(
                fontSize: 13,
                color: zText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            Text(
              _getBreadcrumbText(),
              style: const TextStyle(
                fontSize: 13,
                color: zText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const Spacer(),
          // Premium Workspace Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
              border: Border.all(color: zBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.business_center_rounded,
                  size: 13,
                  color: zBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.companyName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: zText,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.unfold_more_rounded, size: 14, color: zMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inquiryBadge({required bool selected}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _inquiryCountStream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: selected ? zBlue : Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _subNavItem(ShellPage page, {bool isDashboard = false}) {
    final bool selected =
        activePage == page ||
        (page == ShellPage.financeTaxInvoice &&
            (activePage == ShellPage.financeExportInvoiceCreate ||
                activePage == ShellPage.financeTaxInvoiceCreate));

    return Tooltip(
      message: _isSidebarCollapsed ? page.label : '',
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: isDashboard
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Material(
          color: selected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
            onTap: () => _selectPage(page),
            hoverColor: Colors.white.withValues(alpha: 0.04),
            child: SizedBox(
              height: ShellLayout.sidebarItemHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: ShellLayout.sidebarCollapsedWidth - 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedOpacity(
                          duration: ShellLayout.animFast,
                          opacity: selected ? 1.0 : 0.0,
                          child: Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          page.icon,
                          size: 16,
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _isSidebarCollapsed ? 0.0 : 1.0,
                      duration: ShellLayout.animFast,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              page.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.65),
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (page == ShellPage.salesInquiries && canInquiries)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _inquiryBadge(selected: selected),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupWidget(SidebarGroup group) {
    final bool expanded = expandedGroups.contains(group.key);
    final bool hasActiveChild = _groupContainsActive(group);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: _isSidebarCollapsed ? group.title : '',
          waitDuration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
                onTap: () {
                  if (_isSidebarCollapsed) {
                    _toggleSidebar();
                    if (!expanded) _toggleGroup(group.key);
                  } else {
                    _toggleGroup(group.key);
                  }
                },
                hoverColor: Colors.white.withValues(alpha: 0.04),
                child: SizedBox(
                  height: ShellLayout.sidebarGroupHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: ShellLayout.sidebarCollapsedWidth - 16,
                        child: Icon(
                          group.icon,
                          size: 16,
                          color: hasActiveChild
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: _isSidebarCollapsed ? 0.0 : 1.0,
                          duration: ShellLayout.animFast,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasActiveChild
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.65),
                                    fontWeight: hasActiveChild
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns: expanded ? 0.25 : 0.0,
                                duration: ShellLayout.animDuration,
                                curve: Curves.easeInOut,
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: ShellLayout.animDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Column(
                    children: group.children
                        .map((page) => _subNavItem(page))
                        .toList(),
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  Widget _buildUserSection() {
    final name = _resolvedEmployeeName();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161F2E),
        border: Border(top: BorderSide(color: Color(0xFF2A3649))),
      ),
      child: Tooltip(
        message: _isSidebarCollapsed ? 'Logout / Expand' : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
          onTap: _isSidebarCollapsed ? _toggleSidebar : null,
          child: Row(
            children: [
              SizedBox(
                width: ShellLayout.sidebarCollapsedWidth - 16,
                child: Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: zBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedOpacity(
                  opacity: _isSidebarCollapsed ? 0.0 : 1.0,
                  duration: ShellLayout.animFast,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentRole.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.logout_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 16,
                        ),
                        onPressed: _logout,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        splashRadius: 16,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockedWorkspaceBody() {
    return Scaffold(
      backgroundColor: zCanvasBg,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: zBorder),
              borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_outlined, size: 32, color: zMuted),
                const SizedBox(height: 12),
                const Text(
                  'Workspace access unavailable',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: zText,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your company workspace access is inactive, archived, or deleted. Please contact your administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: zMuted,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingIndustry) {
      return const Scaffold(
        backgroundColor: zCanvasBg,
        body: Center(child: CircularProgressIndicator(color: zBlue)),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userSessionStream,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting &&
            !userSnap.hasData) {
          return const Scaffold(
            backgroundColor: zCanvasBg,
            body: Center(child: CircularProgressIndicator(color: zBlue)),
          );
        }

        final companyUserData = userSnap.data?.data() ?? <String, dynamic>{};

        _currentRole = (companyUserData['role'] ?? widget.role)
            .toString()
            .trim()
            .toLowerCase();

        final dynamic rawPermissions = companyUserData['permissions'];
        _currentPermissions = rawPermissions is Map
            ? Map<String, dynamic>.from(rawPermissions)
            : widget.permissions;

        final bool isDeleted = companyUserData['isDeleted'] == true;
        final bool isActive = companyUserData.containsKey('isActive')
            ? companyUserData['isActive'] == true
            : true;

        if (isDeleted || !isActive) {
          return _blockedWorkspaceBody();
        }

        _currentSidebarGroups = _computeSidebarGroups();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_canViewPage(activePage)) {
            setState(() => activePage = ShellPage.dashboard);
          }
        });

        final businessGroups = _currentSidebarGroups
            .where((g) => ['sales', 'crm', 'service'].contains(g.key))
            .toList();
        final opsGroups = _currentSidebarGroups
            .where((g) => ['inventory', 'purchase', 'dispatch'].contains(g.key))
            .toList();
        final financeGroups = _currentSidebarGroups
            .where((g) => ['finance', 'reports'].contains(g.key))
            .toList();
        final systemGroups = _currentSidebarGroups
            .where((g) => ['admin'].contains(g.key))
            .toList();

        return Scaffold(
          backgroundColor: zCanvasBg,
          body: Row(
            children: [
              AnimatedContainer(
                duration: ShellLayout.animDuration,
                curve: Curves.easeInOut,
                width: _isSidebarCollapsed
                    ? ShellLayout.sidebarCollapsedWidth
                    : ShellLayout.sidebarExpandedWidth,
                color: zIconRail,
                child: SafeArea(
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: ShellLayout.sidebarExpandedWidth,
                      maxWidth: ShellLayout.sidebarExpandedWidth,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: ShellLayout.sidebarExpandedWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Branding Section
                            Container(
                              height: ShellLayout.headerHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width:
                                        ShellLayout.sidebarCollapsedWidth - 20,
                                    child: Center(
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        height: 20,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.business,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: AnimatedOpacity(
                                      opacity: _isSidebarCollapsed ? 0.0 : 1.0,
                                      duration: ShellLayout.animFast,
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Text(
                                          'QUIK ERP',
                                          maxLines: 1,
                                          overflow: TextOverflow.clip,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Color(0xFF2A3649), height: 1),

                            // Scrollable Workspace
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 20,
                                ),
                                children: [
                                  _subNavItem(
                                    ShellPage.dashboard,
                                    isDashboard: true,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      color: Color(0xFF2A3649),
                                      height: 1,
                                    ),
                                  ),

                                  if (businessGroups.isNotEmpty) ...[
                                    ...businessGroups.map(_groupWidget),
                                    const SizedBox(height: 4),
                                  ],

                                  if (opsGroups.isNotEmpty) ...[
                                    ...opsGroups.map(_groupWidget),
                                    const SizedBox(height: 4),
                                  ],

                                  if (financeGroups.isNotEmpty) ...[
                                    ...financeGroups.map(_groupWidget),
                                    const SizedBox(height: 4),
                                  ],

                                  if (systemGroups.isNotEmpty) ...[
                                    ...systemGroups.map(_groupWidget),
                                    const SizedBox(height: 4),
                                  ],

                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      color: Color(0xFF2A3649),
                                      height: 1,
                                    ),
                                  ),
                                  _subNavItem(ShellPage.settingsGeneral),
                                ],
                              ),
                            ),

                            _buildUserSection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildTopHeader(),
                    Expanded(child: _buildActiveBody()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveBody() {
    if (!_canViewPage(activePage)) {
      return Padding(
        padding: const EdgeInsets.all(ShellLayout.pagePadding),
        child: DashboardScreen(
          companyId: widget.companyId,
          userName: _resolvedEmployeeName(),
          currentUserId: widget.userUid,
          permissions: _currentPermissions,
          role: _currentRole,
        ),
      );
    }

    switch (activePage) {
      case ShellPage.dashboard:
        return DashboardScreen(
          companyId: widget.companyId,
          userName: _resolvedEmployeeName(),
          currentUserId: widget.userUid,
          permissions: _currentPermissions,
          role: _currentRole,
        );

      case ShellPage.salesInquiries:
        return const Padding(
          padding: EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreensInquiryList(),
        );

      // --- Professional Service Workflow Mapping ---

      case ShellPage.serviceRequests:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ServiceRequestListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.serviceQuotations:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ServiceQuotationListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.serviceSalesOrders:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ServiceSalesOrderListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.serviceVisits:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ServiceVisitListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.serviceTechnicians:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ServiceTechnicianListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      // --- CRM Mapping ---

      case ShellPage.crmCustomers:
        return const Padding(
          padding: EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreensCustomerList(),
        );

      case ShellPage.crmContacts:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreensContactList(
            companyRef: FirebaseFirestore.instance
                .collection('companies')
                .doc(widget.companyId),
            companyName: widget.companyName,
          ),
        );

      case ShellPage.crmVisits:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: CustomerVisitListScreen(
            companyId: widget.companyId,
            currentUserId: widget.userUid,
            currentUserRole: _currentRole,
          ),
        );

      case ShellPage.inventoryProducts:
        return const Padding(
          padding: EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreensProductList(),
        );

      case ShellPage.inventoryStockIn:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreensStockInList(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.dispatchReady:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ReadyForDispatchScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.dispatchChallans:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: DispatchChallansScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.dispatchShipmentTracking:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ShipmentTrackingScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.dispatchDelivered:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: DeliveredOrdersScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.salesQuotations:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreensQuotationList(
            userId: (widget.userUid.hashCode).abs() % 1000000,
          ),
        );

      case ShellPage.salesOrders:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: SalesOrderListScreen(companyId: widget.companyId),
        );

      case ShellPage.salesTasks:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: TaskScreen(
            companyId: widget.companyId,
            currentUserId: widget.userUid,
            currentUserRole: _currentRole,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.adminUsers:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreenUserManagement(
            companyId: widget.companyId,
            currentUid: widget.userUid,
          ),
        );

      case ShellPage.adminComplianceLegal:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreensComplianceLegalList(companyId: widget.companyId),
        );

      case ShellPage.financeProforma:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ProformaListScreen(companyId: widget.companyId),
        );

      case ShellPage.financeTaxInvoice:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: InvoiceListScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
            onSelectTax: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaxInvoiceScreen(
                    companyId: widget.companyId,
                    userUid: widget.userUid,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              );
            },
            onSelectExport: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExportInvoiceScreen(
                    companyId: widget.companyId,
                    userUid: widget.userUid,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              );
            },
          ),
        );

      case ShellPage.financePaymentsReceived:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: PaymentsListScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.financeOutstanding:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: OutstandingScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.reportsSales:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: SalesReportScreen(companyId: widget.companyId),
        );

      case ShellPage.settingsGeneral:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: ScreenSettingsHome(
            companyId: widget.companyId,
            companyName: widget.companyName,
            role: _currentRole,
            userEmail: widget.userEmail,
            permissions: _currentPermissions,
            industry: _resolvedIndustry,
            onOpenUsers: () => _selectPage(ShellPage.adminUsers),
            onOpenAuditLogs: () => _selectPage(ShellPage.adminAuditLogs),
          ),
        );

      case ShellPage.purchaseVendors:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: PurchaseVendorListScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.purchaseOrders:
        return SalesOrderListScreen(companyId: widget.companyId);

      case ShellPage.purchaseBills:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: PurchaseBillListScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.all(ShellLayout.pagePadding),
          child: _moduleLandingPage(activePage),
        );
    }
  }

  Widget _moduleLandingPage(ShellPage page) {
    final bool implemented = _isImplementedPage(page);
    final bool allowed = _canViewPage(page);

    String sectionName = 'Workspace';
    for (final group in _currentSidebarGroups) {
      if (group.children.contains(page)) {
        sectionName = group.title;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          page.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: zText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$sectionName module inside ${widget.companyName}',
          style: const TextStyle(
            color: zMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _overviewCard(
                title: 'Module Status',
                value: allowed
                    ? (implemented ? 'Ready to open' : 'Planned')
                    : 'Restricted',
                icon: allowed
                    ? (implemented
                          ? Icons.check_circle_outline
                          : Icons.construction_outlined)
                    : Icons.lock_outline,
                tint: allowed
                    ? (implemented ? zSuccessSoft : zBlueSoft)
                    : const Color(0xFFFFF1F2),
                iconColor: allowed
                    ? (implemented ? zSuccess : zBlue)
                    : Colors.redAccent,
              ),
            ),
            const SizedBox(width: ShellLayout.sectionSpacing),
            Expanded(
              child: _overviewCard(
                title: 'Action',
                value: implemented ? 'Open module' : 'Coming soon',
                icon: implemented
                    ? Icons.open_in_new
                    : Icons.rocket_launch_outlined,
                tint: zOrangeSoft,
                iconColor: zOrange,
              ),
            ),
            const SizedBox(width: ShellLayout.sectionSpacing),
            Expanded(
              child: _overviewCard(
                title: 'Department',
                value: sectionName,
                icon: Icons.apartment_outlined,
                tint: zPurpleSoft,
                iconColor: zPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: ShellLayout.sectionSpacing),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(ShellLayout.cardPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: zBorder),
                    borderRadius: BorderRadius.circular(
                      ShellLayout.borderRadius,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Module Overview',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: zText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _moduleDescription(page),
                        style: const TextStyle(
                          color: zMuted,
                          height: 1.4,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _moduleTags(
                          page,
                        ).map((e) => _moduleTag(e)).toList(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: ShellLayout.sectionSpacing),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: _quickPanel(
                        title: 'Recommended Subfeatures',
                        lines: _moduleRecommendations(page),
                        icon: Icons.auto_awesome_outlined,
                      ),
                    ),
                    const SizedBox(height: ShellLayout.sectionSpacing),
                    Expanded(
                      child: _quickPanel(
                        title: 'Implementation Note',
                        lines: [
                          implemented
                              ? 'This module is already connected to an existing screen.'
                              : 'This is a safe placeholder module.',
                          'You can connect Firestore collections later.',
                          'No current feature is removed from your app.',
                        ],
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _moduleTags(ShellPage page) {
    switch (page) {
      case ShellPage.salesInquiries:
        return ['Leads', 'Assignments', 'Follow-ups', 'Pipeline'];
      case ShellPage.salesQuotations:
        return ['Price', 'Proposal', 'Customer', 'Approval'];
      case ShellPage.crmCustomers:
        return ['Accounts', 'Contacts', 'History', 'Relationships'];
      case ShellPage.inventoryProducts:
        return ['Catalog', 'Stock', 'SKU', 'Pricing'];
      case ShellPage.adminUsers:
        return ['Access', 'Permissions', 'Roles', 'Team'];
      case ShellPage.adminComplianceLegal:
        return ['Compliance', 'Legal', 'Licenses', 'Policies'];
      case ShellPage.settingsGeneral:
        return ['Company', 'Security', 'Users', 'Audit'];
      case ShellPage.serviceRequests:
      case ShellPage.serviceQuotations:
      case ShellPage.serviceSalesOrders:
      case ShellPage.serviceVisits:
      case ShellPage.serviceTechnicians:
        return [
          'Work Orders',
          'Engineers',
          'Warranty',
          'Field Service',
          'Equipment',
          'Repairs',
        ];
      default:
        return ['Professional', 'Scalable', 'Modular', 'ERP'];
    }
  }

  String _moduleDescription(ShellPage page) {
    switch (page) {
      case ShellPage.salesInquiries:
        return 'Track leads and incoming inquiries, assign them to team members, monitor status, and prepare them for quotation and order conversion.';
      case ShellPage.salesQuotations:
        return 'Generate and manage quotations for your sales team. This connects your existing quotation workflow into a cleaner ERP module structure.';
      case ShellPage.crmCustomers:
        return 'Manage customer master records, view customer relationship data, and keep your CRM organized around actual business accounts.';
      case ShellPage.inventoryProducts:
        return 'Manage your product master, stock-facing items, and future inventory movements through a clean inventory module.';
      case ShellPage.adminUsers:
        return 'Handle user management, role-based access, and team structure for each company workspace.';
      case ShellPage.adminComplianceLegal:
        return 'Manage company compliance records, legal documents, registrations, licenses, contracts and statutory obligations.';
      case ShellPage.settingsGeneral:
        return 'Manage workspace preferences, company controls, users, security, notifications, integrations, and audit-related options from one professional ERP settings hub.';
      case ShellPage.serviceRequests:
        return 'Log incoming customer complaints, verify warranty status, and generate initial service requests for the engineering team.';
      case ShellPage.serviceQuotations:
        return 'Manage cost estimations for out-of-warranty services, spare parts, labor, and engineer field visits.';
      case ShellPage.serviceSalesOrders:
        return 'Manage active work orders, assign service engineers, and track repair status for industrial equipment.';
      case ShellPage.serviceVisits:
        return 'Schedule and monitor field visits for service engineers, including site check-ins, travel logs, and utilized spares.';
      case ShellPage.serviceTechnicians:
        return 'Monitor service team workload, manage engineer skill mapping, track real-time availability, and optimize field assignments.';
      default:
        return 'This module is part of the professional ERP architecture. You can keep your current app working while gradually connecting this module to its own database, screens, and workflows.';
    }
  }

  List<String> _moduleRecommendations(ShellPage page) {
    switch (page) {
      case ShellPage.purchaseOrders:
        return [
          'Vendor selection',
          'Supplier bill number',
          'Bill amount',
          'Bill status',
          'Linked GRN entry',
        ];
      case ShellPage.inventoryStockSummary:
        return [
          'Current stock by item',
          'Warehouse balance',
          'Low stock alerts',
          'Stock movement history',
        ];
      case ShellPage.dispatchChallans:
        return [
          'Dispatch challan no.',
          'Vehicle details',
          'Packing list',
          'Delivery status',
        ];
      case ShellPage.financeOutstanding:
        return [
          'Customer ageing',
          'Pending payments',
          'Reminder schedule',
          'Collection dashboard',
        ];
      case ShellPage.adminComplianceLegal:
        return [
          'License renewals',
          'Legal documents',
          'Compliance tracking',
          'Contract management',
        ];
      case ShellPage.settingsGeneral:
        return [
          'Company profile',
          'Users and permissions',
          'Security and access',
          'Audit and integrations',
        ];
      case ShellPage.serviceRequests:
        return [
          'Complaint logging',
          'Warranty validation',
          'Customer mapping',
          'Priority assignment',
        ];
      case ShellPage.serviceQuotations:
        return [
          'Spares estimation',
          'Labor pricing',
          'Visit fees',
          'Customer approval flow',
        ];
      case ShellPage.serviceSalesOrders:
        return [
          'Engineer assignment',
          'Spares requirement',
          'Work order status',
          'Time tracking',
        ];
      case ShellPage.serviceVisits:
        return [
          'Engineer assignment',
          'Travel logs',
          'Spare requirements',
          'Site readiness',
        ];
      case ShellPage.serviceTechnicians:
        return [
          'Technician availability',
          'Skill mapping',
          'Workload dashboard',
          'Territory assignment',
        ];
      default:
        return [
          'Summary card',
          'Search and filters',
          'List screen',
          'Add / edit form',
        ];
    }
  }

  Widget _moduleTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: zText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color tint,
    required Color iconColor,
  }) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(ShellLayout.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: zMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPanel({
    required String title,
    required List<String> lines,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ShellLayout.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: zBlue, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: zText,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: lines
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 4, color: zBlue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e,
                              style: const TextStyle(
                                color: zMuted,
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _homeDashboardLive() {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dateOnly(DateTime.now());

    final canShowInquiryDashboard = canInquiries;
    final welcomeText = _dashboardWelcomeText();

    final inquiryStream = canShowInquiryDashboard ? _inquiryCountStream : null;

    if (!canShowInquiryDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            welcomeText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: _KpiBox(
                  title: 'Sales Modules',
                  value: '6',
                  icon: Icons.trending_up_outlined,
                ),
              ),
              SizedBox(width: ShellLayout.sectionSpacing),
              Expanded(
                child: _KpiBox(
                  title: 'CRM Modules',
                  value: '4',
                  icon: Icons.people_outline,
                ),
              ),
              SizedBox(width: ShellLayout.sectionSpacing),
              Expanded(
                child: _KpiBox(
                  title: 'Inventory Modules',
                  value: '6',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              SizedBox(width: ShellLayout.sectionSpacing),
              Expanded(
                child: _KpiBox(
                  title: 'Reports',
                  value: '5',
                  icon: Icons.assessment_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: ShellLayout.sectionSpacing),
          Expanded(
            child: Row(
              children: const [
                Expanded(
                  child: _Panel(
                    title: 'Workspace Structure',
                    emptyText: 'Professional ERP modules are ready in sidebar',
                    emptyIcon: Icons.dashboard_customize_outlined,
                  ),
                ),
                SizedBox(width: ShellLayout.sectionSpacing),
                Expanded(
                  child: _Panel(
                    title: 'Next Build Suggestion',
                    emptyText:
                        'Start with Follow-ups, Stock Summary and Vendors',
                    emptyIcon: Icons.rocket_launch_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: inquiryStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Dashboard error: ${snap.error}'));
        }

        int total = 0;
        int openDeals = 0;
        int untouched = 0;
        int followupsToday = 0;

        if (snap.hasData) {
          final docs = snap.data!.docs;
          total = docs.length;

          for (final doc in docs) {
            final data = doc.data();

            final status = (data['status'] ?? '').toString().trim();
            final lastNote = (data['lastFollowUpNote'] ?? '').toString().trim();

            if (status == 'Open' || status == 'Quotation Pending') {
              openDeals++;
            }

            if (status == 'Open' && lastNote.isEmpty) {
              untouched++;
            }

            final next = data['nextFollowUpDate'];
            if (next is Timestamp) {
              final dt = dateOnly(next.toDate());
              if (dt == today) {
                followupsToday++;
              }
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              welcomeText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: zText,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KpiBox(
                    title: 'Open Deals',
                    value: '$openDeals',
                    icon: Icons.folder_open_outlined,
                  ),
                ),
                const SizedBox(width: ShellLayout.sectionSpacing),
                Expanded(
                  child: _KpiBox(
                    title: 'Untouched',
                    value: '$untouched',
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ),
                const SizedBox(width: ShellLayout.sectionSpacing),
                Expanded(
                  child: _KpiBox(
                    title: 'Follow-ups Today',
                    value: '$followupsToday',
                    icon: Icons.event_repeat_outlined,
                  ),
                ),
                const SizedBox(width: ShellLayout.sectionSpacing),
                Expanded(
                  child: _KpiBox(
                    title: 'My Inquiries',
                    value: '$total',
                    icon: Icons.insights_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ShellLayout.sectionSpacing),
            Expanded(
              child: Row(
                children: const [
                  Expanded(
                    child: _Panel(
                      title: 'My Open Tasks',
                      emptyText: 'No open tasks',
                      emptyIcon: Icons.task_alt,
                    ),
                  ),
                  SizedBox(width: ShellLayout.sectionSpacing),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _KpiBox({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(ShellLayout.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: zMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: zMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String emptyText;
  final IconData emptyIcon;

  const _Panel({
    required this.title,
    required this.emptyText,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(ShellLayout.borderRadius),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: zBorder)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: zText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(emptyIcon, color: zMuted, size: 20),
                    const SizedBox(height: 8),
                    Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: zMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
