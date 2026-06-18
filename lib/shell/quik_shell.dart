import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/administration/users/screen_user_management.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_list.dart';
import 'package:QUIK/modules/crm/customer_visits/customer_visit_list_screen.dart';
import 'package:QUIK/modules/dashboard/dashboard_screen.dart';
import 'package:QUIK/modules/inventory/products/screens_product_list.dart';
import 'package:QUIK/modules/sales/inquiries/screens_inquiry_list.dart';
import 'package:QUIK/modules/sales/quotations/screens_quotation_list.dart';
import 'package:QUIK/modules/settings/screen_settings_home.dart';
import 'package:QUIK/modules/sales/sales_orders/screens_sales_order_list.dart';
import 'package:QUIK/modules/sales/tasks/screens_task_list.dart';

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
import 'package:QUIK/modules/service/service_visits/service_visit_list_screen.dart';
import 'package:QUIK/modules/service/service_technicians/service_technician_list_screen.dart';
import 'package:QUIK/modules/service/service_quotations/service_quotation_list_screen.dart';

enum ShellPage {
  dashboard,

  salesInquiries,
  salesQuotations,
  salesOrders,
  salesFollowUps,
  salesTasks,
  salesMeetings,

  // Professional Service Workflow
  serviceRequests,
  serviceWorkOrders,
  serviceQuotations,
  serviceVisits,
  serviceInstallationCommissioning,
  serviceTechnicians,
  serviceReports,
  serviceEquipmentHistory,
  serviceClosedWorkOrders,

  crmCustomers,
  crmContacts,
  crmVisits,
  crmCommunication,

  purchaseVendors,
  purchaseOrders,
  purchaseGrn,
  purchaseLedger,

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
  adminRoles,
  adminCompanyProfile,
  adminBranches,
  adminAuditLogs,

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
      case ShellPage.salesFollowUps:
        return 'Follow-ups';
      case ShellPage.salesTasks:
        return 'Tasks';
      case ShellPage.salesMeetings:
        return 'Meetings';

      case ShellPage.serviceRequests:
        return 'Service Requests';
      case ShellPage.serviceWorkOrders:
        return 'Work Orders';
      case ShellPage.serviceQuotations:
        return 'Quotations';
      case ShellPage.serviceVisits:
        return 'Service Visits';
      case ShellPage.serviceInstallationCommissioning:
        return 'Installation / Commissioning';
      case ShellPage.serviceTechnicians:
        return 'Service Technicians';
      case ShellPage.serviceReports:
        return 'Service Reports';
      case ShellPage.serviceEquipmentHistory:
        return 'Equipment History';
      case ShellPage.serviceClosedWorkOrders:
        return 'Closed Work Orders';

      case ShellPage.crmCustomers:
        return 'Customers';
      case ShellPage.crmContacts:
        return 'Contacts';
      case ShellPage.crmVisits:
        return 'Customer Visits';
      case ShellPage.crmCommunication:
        return 'Communication History';

      case ShellPage.purchaseVendors:
        return 'Vendors';
      case ShellPage.purchaseOrders:
        return 'Purchase Bills';
      case ShellPage.purchaseGrn:
        return 'GRN / Material Receipt';
      case ShellPage.purchaseLedger:
        return 'Vendor Ledger';

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
      case ShellPage.adminRoles:
        return 'Roles & Permissions';
      case ShellPage.adminCompanyProfile:
        return 'Company Profile';
      case ShellPage.adminBranches:
        return 'Branches';
      case ShellPage.adminAuditLogs:
        return 'Audit Logs';

      case ShellPage.settingsGeneral:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case ShellPage.dashboard:
        return Icons.home_outlined;
      case ShellPage.salesInquiries:
        return Icons.campaign_outlined;
      case ShellPage.salesQuotations:
        return Icons.receipt_long_outlined;
      case ShellPage.salesOrders:
        return Icons.shopping_bag_outlined;
      case ShellPage.salesFollowUps:
        return Icons.event_repeat_outlined;
      case ShellPage.salesTasks:
        return Icons.task_alt_outlined;
      case ShellPage.salesMeetings:
        return Icons.groups_outlined;

      case ShellPage.serviceRequests:
        return Icons.support_agent_outlined;
      case ShellPage.serviceWorkOrders:
        return Icons.handyman_outlined;
      case ShellPage.serviceQuotations:
        return Icons.request_quote_outlined;
      case ShellPage.serviceVisits:
        return Icons.directions_car_outlined;
      case ShellPage.serviceInstallationCommissioning:
        return Icons.precision_manufacturing_outlined;
      case ShellPage.serviceTechnicians:
        return Icons.engineering_outlined;
      case ShellPage.serviceReports:
        return Icons.assignment_outlined;
      case ShellPage.serviceEquipmentHistory:
        return Icons.history_outlined;
      case ShellPage.serviceClosedWorkOrders:
        return Icons.fact_check_outlined;

      case ShellPage.crmCustomers:
        return Icons.people_outline;
      case ShellPage.crmContacts:
        return Icons.contact_phone_outlined;
      case ShellPage.crmVisits:
        return Icons.location_on_outlined;
      case ShellPage.crmCommunication:
        return Icons.chat_bubble_outline;
      case ShellPage.purchaseVendors:
        return Icons.business_outlined;
      case ShellPage.purchaseOrders:
        return Icons.shopping_cart_outlined;
      case ShellPage.purchaseGrn:
        return Icons.inventory_outlined;
      case ShellPage.purchaseLedger:
        return Icons.menu_book_outlined;
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
      case ShellPage.adminRoles:
        return Icons.admin_panel_settings_outlined;
      case ShellPage.adminCompanyProfile:
        return Icons.apartment_outlined;
      case ShellPage.adminBranches:
        return Icons.account_tree_outlined;
      case ShellPage.adminAuditLogs:
        return Icons.fact_check_outlined;
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

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _userSessionStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _inquiryCountStream;

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

  // 🔥 CRITICAL FIX: Smart Permission Getter
  // Automatically detects plural and singular mismatches from database records
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

  bool _hasPermission(
    String module,
    String submodule, {
    String action = 'view',
  }) {
    if (isAdminOrManager) return true;

    // 1. Exact match check
    if (_checkPerm(module, submodule, action)) return true;

    // 2. Fallback: Check Plural version if singular failed
    if (!submodule.endsWith('s') &&
        _checkPerm(module, '${submodule}s', action)) {
      return true;
    }

    // 3. Fallback: Check Singular version if plural failed
    if (submodule.endsWith('s') &&
        _checkPerm(
          module,
          submodule.substring(0, submodule.length - 1),
          action,
        )) {
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

      // Sales
      case ShellPage.salesInquiries:
        return _hasPermission('sales', 'inquiries');
      case ShellPage.salesQuotations:
        return _hasPermission('sales', 'quotations');
      case ShellPage.salesOrders:
        return _hasPermission('sales', 'salesOrder');
      case ShellPage.salesFollowUps:
        return false;
      case ShellPage.salesTasks:
        return _hasPermission('sales', 'tasks');
      case ShellPage.salesMeetings:
        return _hasPermission('sales', 'meetings');

      // Service (Industrial Workflow)
      case ShellPage.serviceRequests:
        return _hasPermission('service', 'serviceRequests');
      case ShellPage.serviceWorkOrders:
        return _hasPermission('service', 'workOrders');
      case ShellPage.serviceQuotations:
        return _hasPermission('service', 'quotations');
      case ShellPage.serviceVisits:
        return _hasPermission('service', 'serviceVisits');
      case ShellPage.serviceInstallationCommissioning:
        return _hasPermission('service', 'installationCommissioning');
      case ShellPage.serviceTechnicians:
        return _hasPermission('service', 'serviceTechnicians');
      case ShellPage.serviceReports:
        return _hasPermission('service', 'serviceReports');
      case ShellPage.serviceEquipmentHistory:
        return _hasPermission('service', 'equipmentHistory');
      case ShellPage.serviceClosedWorkOrders:
        return _hasPermission('service', 'closedWorkOrders');

      // CRM
      case ShellPage.crmCustomers:
        return _hasPermission('crm', 'customers');
      case ShellPage.crmContacts:
        return _hasPermission('crm', 'contacts');
      case ShellPage.crmVisits:
        return _hasPermission('crm', 'customerVisits');
      case ShellPage.crmCommunication:
        return _hasPermission('crm', 'communicationHistory');

      // Purchase
      case ShellPage.purchaseVendors:
        return _hasPermission('purchase', 'vendors');
      case ShellPage.purchaseOrders:
        return _hasPermission('purchase', 'purchaseOrders');
      case ShellPage.purchaseGrn:
        return _hasPermission('purchase', 'grnMaterialReceipt');
      case ShellPage.purchaseLedger:
        return _hasPermission('purchase', 'vendorLedger');

      // Inventory
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

      // Dispatch
      case ShellPage.dispatchReady:
        return _hasPermission('dispatch', 'readyForDispatch');
      case ShellPage.dispatchChallans:
        return _hasPermission('dispatch', 'dispatchChallans');
      case ShellPage.dispatchShipmentTracking:
        return _hasPermission('dispatch', 'shipmentTracking');
      case ShellPage.dispatchDelivered:
        return _hasPermission('dispatch', 'deliveredOrders');

      // Finance
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

      // Reports
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

      // Administration
      case ShellPage.adminUsers:
        return _hasPermission('administration', 'users');
      case ShellPage.adminRoles:
        return _hasPermission('administration', 'rolesPermissions');
      case ShellPage.adminCompanyProfile:
        return _hasPermission('administration', 'companyProfile');
      case ShellPage.adminBranches:
        return _hasPermission('administration', 'branches');
      case ShellPage.adminAuditLogs:
        return _hasPermission('administration', 'auditLogs');
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
          ShellPage.salesMeetings,
        ],
      ),
      SidebarGroup(
        key: 'service',
        title: 'Service',
        icon: Icons.build_outlined,
        children: [
          ShellPage.serviceRequests,
          ShellPage.serviceWorkOrders,
          ShellPage.serviceQuotations,
          ShellPage.serviceVisits,
          ShellPage.serviceInstallationCommissioning,
          ShellPage.serviceTechnicians,
          ShellPage.serviceReports,
          ShellPage.serviceEquipmentHistory,
          ShellPage.serviceClosedWorkOrders,
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
          ShellPage.crmCommunication,
        ],
      ),
      SidebarGroup(
        key: 'purchase',
        title: 'Purchase',
        icon: Icons.shopping_cart_outlined,
        children: [
          ShellPage.purchaseVendors,
          ShellPage.purchaseOrders,
          ShellPage.purchaseGrn,
          ShellPage.purchaseLedger,
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
          ShellPage.adminRoles,
          ShellPage.adminCompanyProfile,
          ShellPage.adminBranches,
          ShellPage.adminAuditLogs,
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
      case ShellPage.crmCustomers:
      case ShellPage.crmVisits: // ✅ NEW: Registered CRM Visits
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
      case ShellPage.serviceRequests: // ✅ Connected Service Requests
      case ShellPage.serviceVisits: // ✅ Connected Service Visits
      case ShellPage.serviceTechnicians: // ✅ Connected Service Technicians
      case ShellPage.serviceQuotations: // ✅ Connected Service Quotations
        return true;
      default:
        // Service modules removed to trigger placeholder correctly
        return false;
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  bool _groupContainsActive(SidebarGroup group) {
    return group.children.contains(activePage);
  }

  String _activeSectionTitle() {
    if (activePage == ShellPage.dashboard) return 'Dashboard';
    if (activePage == ShellPage.settingsGeneral) return 'Settings';
    if (activePage == ShellPage.financeTaxInvoiceCreate) {
      return 'Finance • Create Tax Invoice';
    }
    if (activePage == ShellPage.financeExportInvoiceCreate) {
      return 'Finance • Create Export Invoice';
    }

    if (_currentSidebarGroups.any(
      (group) => group.children.contains(activePage),
    )) {
      final group = _currentSidebarGroups.firstWhere(
        (g) => g.children.contains(activePage),
      );
      return '${group.title} • ${activePage.label}';
    }

    return activePage.label;
  }

  String _resolvedEmployeeName() {
    final fromDisplayName = (widget.userDisplayName ?? '').trim();
    if (fromDisplayName.isNotEmpty) return fromDisplayName;

    final emailPrefix = widget.userEmail.split('@').first.trim();
    if (emailPrefix.isNotEmpty) return emailPrefix;

    return 'User';
  }

  String _dashboardWelcomeText() {
    if (isAdminOrManager) {
      return 'Welcome ${widget.companyName}';
    }
    return 'Welcome ${_resolvedEmployeeName()}';
  }

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('notifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream() {
    return _notificationsRef
        .where('recipientUid', isEqualTo: widget.userUid)
        .limit(50)
        .snapshots();
  }

  DateTime? _notificationDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _notificationTimeText(dynamic value) {
    final date = _notificationDate(value);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day ago';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  IconData _notificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'task_assignment':
      case 'task':
        return Icons.task_alt_outlined;
      case 'task_status':
        return Icons.sync_alt_outlined;
      case 'meeting':
      case 'meeting_invitation':
        return Icons.groups_outlined;
      case 'inquiry':
      case 'inquiry_update':
        return Icons.campaign_outlined;
      case 'system':
      case 'announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _notificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'task_assignment':
      case 'task':
        return const Color(0xFF2563EB);
      case 'task_status':
        return const Color(0xFF7C3AED);
      case 'meeting':
      case 'meeting_invitation':
        return const Color(0xFF0891B2);
      case 'inquiry':
      case 'inquiry_update':
        return const Color(0xFFF59E0B);
      case 'system':
      case 'announcement':
        return const Color(0xFF0F172A);
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _markNotificationRead(String id, bool isRead) async {
    await _notificationsRef.doc(id).update({
      'isRead': isRead,
      'readAt': isRead ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAllNotificationsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unreadDocs = docs
        .where((doc) => doc.data()['isRead'] != true)
        .toList();
    if (unreadDocs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unreadDocs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Widget _notificationBell() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationsStream(),
      builder: (context, snap) {
        final docs =
            snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final unreadCount = docs
            .where((doc) => doc.data()['isRead'] != true)
            .length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => _openNotificationsDialog(docs),
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: zMuted,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openNotificationsDialog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> initialDocs,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _notificationsStream(),
              builder: (context, snap) {
                final docs = (snap.data?.docs ?? initialDocs).toList();

                docs.sort((a, b) {
                  final aDate =
                      _notificationDate(a.data()['createdAt']) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bDate =
                      _notificationDate(b.data()['createdAt']) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bDate.compareTo(aDate);
                });

                final unreadCount = docs
                    .where((doc) => doc.data()['isRead'] != true)
                    .length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: zText,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            TextButton(
                              onPressed: () => _markAllNotificationsRead(docs),
                              child: const Text('Mark all read'),
                            ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (snap.hasError)
                      Expanded(
                        child: Center(
                          child: Text(
                            'Notification error: ${snap.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else if (!snap.hasData && initialDocs.isEmpty)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (docs.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No notifications yet.',
                            style: TextStyle(color: zMuted),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final type = (data['type'] ?? '').toString();
                            final title = (data['title'] ?? 'Notification')
                                .toString();
                            final message = (data['message'] ?? '').toString();
                            final isRead = data['isRead'] == true;
                            final color = _notificationColor(type);

                            return Container(
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.white
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRead
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(
                                    _notificationIcon(type),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w700
                                        : FontWeight.w900,
                                    color: zText,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (message.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          color: zMuted,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 5),
                                    Text(
                                      _notificationTimeText(data['createdAt']),
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: isRead ? 'Mark unread' : 'Mark read',
                                  onPressed: () =>
                                      _markNotificationRead(doc.id, !isRead),
                                  icon: Icon(
                                    isRead
                                        ? Icons.mark_email_unread_outlined
                                        : Icons.mark_email_read_outlined,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: zBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _activeSectionTitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: zText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _notificationBell(),
        ],
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
              borderRadius: BorderRadius.circular(12),
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

        return Scaffold(
          backgroundColor: zCanvasBg,
          body: Row(
            children: [
              Container(
                width: 240,
                color: zIconRail,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUIK ERP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.companyName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xFF243041), height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                          children: [
                            _dashboardNavItem(),
                            const SizedBox(height: 6),
                            ..._currentSidebarGroups.map(_groupWidget),
                            const SizedBox(height: 6),
                            const Divider(color: Color(0xFF243041)),
                            _settingsNavItem(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _logout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.logout,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  _currentRole.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Widget _dashboardNavItem() {
    final selected = activePage == ShellPage.dashboard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectPage(ShellPage.dashboard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 18,
                color: selected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsNavItem() {
    final selected = activePage == ShellPage.settingsGeneral;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectPage(ShellPage.settingsGeneral),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 18,
                color: selected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupWidget(SidebarGroup group) {
    final bool expanded = expandedGroups.contains(group.key);
    final bool hasActiveChild = _groupContainsActive(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: hasActiveChild
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border.all(
            color: hasActiveChild
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (expanded) {
                    expandedGroups.remove(group.key);
                  } else {
                    expandedGroups.clear();
                    expandedGroups.add(group.key);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      group.icon,
                      size: 18,
                      color: hasActiveChild ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasActiveChild ? Colors.white : Colors.white70,
                          fontWeight: hasActiveChild
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Colors.white60,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Column(
                  children: group.children
                      .map((page) => _subNavItem(page))
                      .toList(),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subNavItem(ShellPage page) {
    final bool selected =
        activePage == page ||
        (page == ShellPage.financeTaxInvoice &&
            (activePage == ShellPage.financeExportInvoiceCreate ||
                activePage == ShellPage.financeTaxInvoiceCreate));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _selectPage(page),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                page.icon,
                size: 16,
                color: selected ? zBlue : Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  page.label,
                  style: TextStyle(
                    color: selected ? zText : Colors.white70,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
              if (page == ShellPage.salesInquiries && canInquiries)
                _inquiryBadge(selected: selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inquiryBadge({required bool selected}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _inquiryCountStream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? zBlueSoft : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? zBlue.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
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

  Widget _buildActiveBody() {
    if (!_canViewPage(activePage)) {
      return Padding(
        padding: const EdgeInsets.all(10),
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
          padding: EdgeInsets.all(10),
          child: ScreensInquiryList(),
        );

      case ShellPage.serviceRequests:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ServiceRequestListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.serviceVisits:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ServiceVisitListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.serviceTechnicians:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ServiceTechnicianListScreen(companyId: widget.companyId),
        );

      case ShellPage.serviceQuotations:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ServiceQuotationListScreen(companyId: widget.companyId),
        );

      // Industrial Service Submodules Routing (Now using placeholder fallback)
      case ShellPage.serviceWorkOrders:
      case ShellPage.serviceInstallationCommissioning:
      case ShellPage.serviceReports:
      case ShellPage.serviceEquipmentHistory:
      case ShellPage.serviceClosedWorkOrders:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: _moduleLandingPage(
            activePage,
          ), // Render professional placeholder for now
        );

      case ShellPage.crmCustomers:
        return const Padding(
          padding: EdgeInsets.all(10),
          child: ScreensCustomerList(),
        );

      // ✅ NEW: Connected Customer Visits
      case ShellPage.crmVisits:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: CustomerVisitListScreen(
            companyId: widget.companyId,
            currentUserId: widget.userUid,
            currentUserRole: _currentRole,
          ),
        );

      case ShellPage.inventoryProducts:
        return const Padding(
          padding: EdgeInsets.all(10),
          child: ScreensProductList(),
        );

      case ShellPage.salesQuotations:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ScreensQuotationList(
            userId: (widget.userUid.hashCode).abs() % 1000000,
          ),
        );

      case ShellPage.salesOrders:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: SalesOrderListScreen(companyId: widget.companyId),
        );

      case ShellPage.salesTasks:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: TaskListScreen(
            companyId: widget.companyId,
            currentUserUid: widget.userUid,
            currentUserName: _resolvedEmployeeName(),
          ),
        );

      case ShellPage.adminUsers:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ScreenUserManagement(
            companyId: widget.companyId,
            currentUid: widget.userUid,
          ),
        );

      case ShellPage.financeProforma:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ProformaListScreen(companyId: widget.companyId),
        );

      case ShellPage.financeTaxInvoice:
        return Padding(
          padding: const EdgeInsets.all(10),
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
          padding: const EdgeInsets.all(10),
          child: PaymentsListScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.financeOutstanding:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: OutstandingScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.reportsSales:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: SalesReportScreen(companyId: widget.companyId),
        );

      case ShellPage.settingsGeneral:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ScreenSettingsHome(
            companyId: widget.companyId,
            companyName: widget.companyName,
            role: _currentRole,
            userEmail: widget.userEmail,
            permissions: _currentPermissions,
            industry: _resolvedIndustry,
            onOpenUsers: () => _selectPage(ShellPage.adminUsers),
            onOpenCompanyProfile: () =>
                _selectPage(ShellPage.adminCompanyProfile),
            onOpenAuditLogs: () => _selectPage(ShellPage.adminAuditLogs),
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.all(10),
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: zText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$sectionName module inside ${widget.companyName}',
          style: const TextStyle(
            color: zMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
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
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: zBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Module Overview',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: zText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _moduleDescription(page),
                        style: const TextStyle(
                          color: zMuted,
                          height: 1.55,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _moduleTags(
                          page,
                        ).map((e) => _moduleTag(e)).toList(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    const SizedBox(height: 8),
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
        return ['Leads', 'Assignments', 'Tasks', 'Pipeline'];
      case ShellPage.salesQuotations:
        return ['Price', 'Proposal', 'Customer', 'Approval'];
      case ShellPage.crmCustomers:
        return ['Accounts', 'Contacts', 'History', 'Relationships'];
      case ShellPage.inventoryProducts:
        return ['Catalog', 'Stock', 'SKU', 'Pricing'];
      case ShellPage.adminUsers:
        return ['Access', 'Permissions', 'Roles', 'Team'];
      case ShellPage.settingsGeneral:
        return ['Company', 'Security', 'Users', 'Audit'];
      case ShellPage.serviceRequests:
      case ShellPage.serviceWorkOrders:
      case ShellPage.serviceQuotations:
      case ShellPage.serviceVisits:
      case ShellPage.serviceInstallationCommissioning:
      case ShellPage.serviceTechnicians:
      case ShellPage.serviceReports:
      case ShellPage.serviceEquipmentHistory:
      case ShellPage.serviceClosedWorkOrders:
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
      case ShellPage.settingsGeneral:
        return 'Manage workspace preferences, company controls, users, security, notifications, integrations, and audit-related options from one professional ERP settings hub.';

      // Professional Service Module Descriptions
      case ShellPage.serviceRequests:
        return 'Log incoming customer complaints, verify warranty status, and generate initial service requests for the engineering team.';
      case ShellPage.serviceWorkOrders:
        return 'Manage active work orders, assign service engineers, and track repair status for industrial equipment.';
      case ShellPage.serviceQuotations:
        return 'Manage cost estimations for out-of-warranty services, spare parts, labor, and engineer field visits.';
      case ShellPage.serviceVisits:
        return 'Schedule and monitor field visits for service engineers, including site check-ins, travel logs, and utilized spares.';
      case ShellPage.serviceInstallationCommissioning:
        return 'Manage complete machine installations, site readiness checks, trial runs, and formal customer handover processes.';
      case ShellPage.serviceTechnicians:
        return 'Monitor service team workload, manage engineer skill mapping, track real-time availability, and optimize field assignments.';
      case ShellPage.serviceReports:
        return 'Generate and track post-service completion reports and client acknowledgments.';
      case ShellPage.serviceEquipmentHistory:
        return 'View complete lifecycle and repair history for specific machines and equipment serial numbers.';
      case ShellPage.serviceClosedWorkOrders:
        return 'Review past service interventions and historical completed repair data.';

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
      case ShellPage.adminCompanyProfile:
        return [
          'GST / VAT details',
          'Address and branches',
          'Branding',
          'Default numbering formats',
        ];
      case ShellPage.settingsGeneral:
        return [
          'Company profile',
          'Users and permissions',
          'Security and access',
          'Audit and integrations',
        ];

      // Professional Service Module Recommendations
      case ShellPage.serviceRequests:
        return [
          'Complaint logging',
          'Warranty validation',
          'Customer mapping',
          'Priority assignment',
        ];
      case ShellPage.serviceWorkOrders:
        return [
          'Engineer assignment',
          'Spares requirement',
          'Work order status',
          'Time tracking',
        ];
      case ShellPage.serviceQuotations:
        return [
          'Spares estimation',
          'Labor pricing',
          'Visit fees',
          'Customer approval flow',
        ];
      case ShellPage.serviceVisits:
        return [
          'Engineer assignment',
          'Travel logs',
          'Spare requirements',
          'Site readiness',
        ];
      case ShellPage.serviceInstallationCommissioning:
        return [
          'Installation checklist',
          'Commissioning reports',
          'Trial run sign-off',
          'Calibration details',
        ];
      case ShellPage.serviceTechnicians:
        return [
          'Technician availability',
          'Skill mapping',
          'Workload dashboard',
          'Territory assignment',
        ];
      case ShellPage.serviceEquipmentHistory:
        return [
          'Serial number tracking',
          'Component replacement history',
          'Warranty claims summary',
          'Performance logs',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: zText,
          fontSize: 11,
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
      height: 76,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
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
              fontSize: 15,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: zBlue, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: zText,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
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
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 5, color: zBlue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e,
                              style: const TextStyle(
                                color: zMuted,
                                fontSize: 11.5,
                                height: 1.45,
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
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _KpiBox(
                  title: 'Sales Modules',
                  value: '6',
                  icon: Icons.trending_up_outlined,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _KpiBox(
                  title: 'CRM Modules',
                  value: '4',
                  icon: Icons.people_outline,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _KpiBox(
                  title: 'Inventory Modules',
                  value: '6',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _KpiBox(
                  title: 'Reports',
                  value: '5',
                  icon: Icons.assessment_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                SizedBox(width: 8),
                Expanded(
                  child: _Panel(
                    title: 'Next Build Suggestion',
                    emptyText:
                        'Start with Tasks, Meetings, Stock Summary and Vendors',
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
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiBox(
                    title: 'Untouched',
                    value: '$untouched',
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiBox(
                    title: 'Follow-ups Today',
                    value: '$followupsToday',
                    icon: Icons.event_repeat_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiBox(
                    title: 'My Inquiries',
                    value: '$total',
                    icon: Icons.insights_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  SizedBox(width: 8),
                  Expanded(
                    child: _Panel(
                      title: 'My Meetings',
                      emptyText: 'No meetings scheduled',
                      emptyIcon: Icons.event_available,
                    ),
                  ),
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
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: zMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
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
              fontSize: 18,
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: zBorder)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(emptyIcon, color: zMuted, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
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
