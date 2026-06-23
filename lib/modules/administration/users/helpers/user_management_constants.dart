// lib/modules/administration/users/helpers/user_management_constants.dart
import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// USER MANAGEMENT UI COLORS
/// ------------------------------------------------------------

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF2563EB);
const Color pageBgColor = Color(0xFFF5F7FB);
const Color cardBorderColor = Color(0xFFE5E7EB);
const Color mutedTextColor = Color(0xFF6B7280);

/// STATUS COLORS
const Color successColor = Color(0xFF16A34A);
const Color warningColor = Color(0xFFF59E0B);
const Color dangerColor = Color(0xFFDC2626);

/// ------------------------------------------------------------
/// COMMON UI VALUES
/// ------------------------------------------------------------

const double cardRadius = 18;
const double miniRadius = 10;

const EdgeInsets sectionPadding = EdgeInsets.all(18);
const SizedBox sectionSpacing = SizedBox(height: 14);

/// ------------------------------------------------------------
/// USER STATUS
/// ------------------------------------------------------------

class UserStatus {
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String archived = 'archived';
}

const List<String> userStatusList = [
  UserStatus.active,
  UserStatus.inactive,
  UserStatus.archived,
];

/// ------------------------------------------------------------
/// USER ROLES
/// ------------------------------------------------------------

class UserRoles {
  static const String owner = 'owner';
  static const String founder = 'founder';
  static const String ceo = 'ceo';
  static const String superadmin = 'superadmin';
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String sales = 'sales';
  static const String service = 'service';
  static const String accounts = 'accounts';
  static const String purchase = 'purchase';
  static const String inventory = 'inventory';
  static const String dispatch = 'dispatch';
  static const String viewer = 'viewer';
}

const List<String> userRolesList = [
  UserRoles.owner,
  UserRoles.founder,
  UserRoles.ceo,
  UserRoles.superadmin,
  UserRoles.admin,
  UserRoles.manager,
  UserRoles.sales,
  UserRoles.service,
  UserRoles.accounts,
  UserRoles.purchase,
  UserRoles.inventory,
  UserRoles.dispatch,
  UserRoles.viewer,
];

const Map<String, String> roleLabels = {
  UserRoles.owner: 'Owner',
  UserRoles.founder: 'Founder',
  UserRoles.ceo: 'CEO',
  UserRoles.superadmin: 'Super Admin',
  UserRoles.admin: 'Admin',
  UserRoles.manager: 'Manager',
  UserRoles.sales: 'Sales',
  UserRoles.service: 'Service',
  UserRoles.accounts: 'Accounts',
  UserRoles.purchase: 'Purchase',
  UserRoles.inventory: 'Inventory',
  UserRoles.dispatch: 'Dispatch',
  UserRoles.viewer: 'Viewer',
};

bool isSuperAccessRole(String? role) {
  final normalized = (role ?? '').trim().toLowerCase();
  return normalized == UserRoles.owner ||
      normalized == UserRoles.founder ||
      normalized == UserRoles.ceo ||
      normalized == UserRoles.superadmin ||
      normalized == UserRoles.admin;
}

/// ------------------------------------------------------------
/// DEPARTMENTS
/// ------------------------------------------------------------

class Departments {
  static const String sales = 'sales';
  static const String service = 'service';
  static const String accounts = 'accounts';
  static const String purchase = 'purchase';
  static const String inventory = 'inventory';
  static const String dispatch = 'dispatch';
  static const String admin = 'admin';
}

const List<String> departmentList = [
  Departments.sales,
  Departments.service,
  Departments.accounts,
  Departments.purchase,
  Departments.inventory,
  Departments.dispatch,
  Departments.admin,
];

/// ------------------------------------------------------------
/// ACCESS SCOPE
/// ------------------------------------------------------------

class AccessScope {
  static const String company = 'company';
  static const String branch = 'branch';
  static const String assigned = 'assigned';
  static const String own = 'own';
}

const Map<String, String> accessScopeLabels = {
  AccessScope.company: 'Full Company Access',
  AccessScope.branch: 'Branch Only',
  AccessScope.assigned: 'Assigned Records Only',
  AccessScope.own: 'Own Records Only',
};

const List<String> accessScopeList = [
  AccessScope.company,
  AccessScope.branch,
  AccessScope.assigned,
  AccessScope.own,
];

/// ------------------------------------------------------------
/// PERMISSION ACTIONS
/// ------------------------------------------------------------

class PermissionActions {
  static const String view = 'view';
  static const String create = 'create';
  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String approve = 'approve';
  static const String export = 'export';
}

const List<String> permissionActionList = [
  PermissionActions.view,
  PermissionActions.create,
  PermissionActions.edit,
  PermissionActions.delete,
  PermissionActions.approve,
  PermissionActions.export,
];

const Map<String, String> permissionActionLabels = {
  PermissionActions.view: 'View',
  PermissionActions.create: 'Create',
  PermissionActions.edit: 'Edit',
  PermissionActions.delete: 'Delete',
  PermissionActions.approve: 'Approve',
  PermissionActions.export: 'Export',
};

/// ------------------------------------------------------------
/// ERP MODULE KEYS
/// ------------------------------------------------------------

class PermissionModules {
  static const String dashboard = 'dashboard';
  static const String sales = 'sales';
  static const String service = 'service';
  static const String crm = 'crm';
  static const String purchase = 'purchase';
  static const String inventory = 'inventory';
  static const String dispatch = 'dispatch';
  static const String finance = 'finance';
  static const String reports = 'reports';
  static const String administration = 'administration';
}

const List<String> permissionModuleOrder = [
  PermissionModules.dashboard,
  PermissionModules.sales,
  PermissionModules.service,
  PermissionModules.crm,
  PermissionModules.purchase,
  PermissionModules.inventory,
  PermissionModules.dispatch,
  PermissionModules.finance,
  PermissionModules.reports,
  PermissionModules.administration,
];

const Map<String, String> permissionModuleLabels = {
  PermissionModules.dashboard: 'Dashboard',
  PermissionModules.sales: 'Sales',
  PermissionModules.service: 'Service',
  PermissionModules.crm: 'CRM',
  PermissionModules.purchase: 'Purchase',
  PermissionModules.inventory: 'Inventory',
  PermissionModules.dispatch: 'Dispatch',
  PermissionModules.finance: 'Finance',
  PermissionModules.reports: 'Reports',
  PermissionModules.administration: 'Administration',
};

/// ------------------------------------------------------------
/// ERP SUBMODULE KEYS
/// ------------------------------------------------------------

class SalesSubmodules {
  static const String inquiries = 'inquiries';
  static const String quotations = 'quotations';
  static const String salesOrders = 'salesOrders';
  static const String tasks = 'tasks';
  static const String meetings = 'meetings';
}

class ServiceSubmodules {
  // Keep the established storage/runtime keys where they already exist.
  static const String serviceCalls = 'serviceRequests';
  static const String serviceVisits = 'serviceVisits';
  static const String serviceTechnicians = 'serviceTechnicians';
  static const String complaints = 'complaints';
  static const String amc = 'amc';
  static const String installation = 'installationCommissioning';
  static const String serviceReports = 'serviceReports';
}

class CrmSubmodules {
  static const String customers = 'customers';
  static const String contacts = 'contacts';
  static const String customerVisits = 'customerVisits';
}

class PurchaseSubmodules {
  static const String vendors = 'vendors';
  static const String purchaseOrders = 'purchaseOrders';
  static const String grnMaterialReceipt = 'grnMaterialReceipt';
  static const String vendorLedger = 'vendorLedger';
}

class InventorySubmodules {
  static const String products = 'products';
  static const String stockSummary = 'stockSummary';
  static const String stockIn = 'stockIn';
  static const String stockOut = 'stockOut';
  static const String warehouse = 'warehouse';
  static const String lowStockAlerts = 'lowStockAlerts';
}

class DispatchSubmodules {
  static const String readyForDispatch = 'readyForDispatch';
  static const String dispatchChallans = 'dispatchChallans';
  static const String shipmentTracking = 'shipmentTracking';
  static const String deliveredOrders = 'deliveredOrders';
}

class FinanceSubmodules {
  static const String proformaInvoice = 'proformaInvoice';
  static const String taxInvoice = 'taxInvoice'; // Key stays exactly the same
  static const String paymentReceived = 'paymentReceived';
  static const String outstanding = 'outstanding';
  static const String expenseEntries = 'expenseEntries';
}

class ReportsSubmodules {
  static const String salesReport = 'salesReport';
  static const String inquiryReport = 'inquiryReport';
  static const String customerReport = 'customerReport';
  static const String productReport = 'productReport';
  static const String paymentReport = 'paymentReport';
}

class AdministrationSubmodules {
  static const String users = 'users';
  static const String rolesPermissions = 'rolesPermissions';
  static const String companyProfile = 'companyProfile';
  static const String branches = 'branches';
  static const String auditLogs = 'auditLogs';
}

const Map<String, List<String>> permissionSubmoduleMap = {
  PermissionModules.dashboard: <String>[],
  PermissionModules.sales: <String>[
    SalesSubmodules.inquiries,
    SalesSubmodules.quotations,
    SalesSubmodules.salesOrders,
    SalesSubmodules.tasks,
    SalesSubmodules.meetings,
  ],
  PermissionModules.service: <String>[
    ServiceSubmodules.serviceCalls,
    ServiceSubmodules.serviceVisits,
    ServiceSubmodules.serviceTechnicians,
    ServiceSubmodules.complaints,
    ServiceSubmodules.amc,
    ServiceSubmodules.installation,
    ServiceSubmodules.serviceReports,
  ],
  PermissionModules.crm: <String>[
    CrmSubmodules.customers,
    CrmSubmodules.contacts,
    CrmSubmodules.customerVisits,
  ],
  PermissionModules.purchase: <String>[
    PurchaseSubmodules.vendors,
    PurchaseSubmodules.purchaseOrders,
    PurchaseSubmodules.grnMaterialReceipt,
    PurchaseSubmodules.vendorLedger,
  ],
  PermissionModules.inventory: <String>[
    InventorySubmodules.products,
    InventorySubmodules.stockSummary,
    InventorySubmodules.stockIn,
    InventorySubmodules.stockOut,
    InventorySubmodules.warehouse,
    InventorySubmodules.lowStockAlerts,
  ],
  PermissionModules.dispatch: <String>[
    DispatchSubmodules.readyForDispatch,
    DispatchSubmodules.dispatchChallans,
    DispatchSubmodules.shipmentTracking,
    DispatchSubmodules.deliveredOrders,
  ],
  PermissionModules.finance: <String>[
    FinanceSubmodules.proformaInvoice,
    FinanceSubmodules.taxInvoice,
    FinanceSubmodules.paymentReceived,
    FinanceSubmodules.outstanding,
    FinanceSubmodules.expenseEntries,
  ],
  PermissionModules.reports: <String>[
    ReportsSubmodules.salesReport,
    ReportsSubmodules.inquiryReport,
    ReportsSubmodules.customerReport,
    ReportsSubmodules.productReport,
    ReportsSubmodules.paymentReport,
  ],
  PermissionModules.administration: <String>[
    AdministrationSubmodules.users,
    AdministrationSubmodules.rolesPermissions,
    AdministrationSubmodules.companyProfile,
    AdministrationSubmodules.branches,
    AdministrationSubmodules.auditLogs,
  ],
};

const Map<String, String> permissionSubmoduleLabels = {
  SalesSubmodules.inquiries: 'Inquiries',
  SalesSubmodules.quotations: 'Quotations',
  SalesSubmodules.salesOrders: 'Sales Orders',
  SalesSubmodules.tasks: 'Tasks',
  SalesSubmodules.meetings: 'Meetings',

  ServiceSubmodules.serviceCalls: 'Service Calls',
  ServiceSubmodules.serviceVisits: 'Service Visits',
  ServiceSubmodules.serviceTechnicians: 'Service Technicians',
  ServiceSubmodules.complaints: 'Complaints',
  ServiceSubmodules.amc: 'AMC',
  ServiceSubmodules.installation: 'Installation',
  ServiceSubmodules.serviceReports: 'Service Reports',

  CrmSubmodules.customers: 'Customers',
  CrmSubmodules.contacts: 'Contacts',
  CrmSubmodules.customerVisits: 'Customer Visits',

  PurchaseSubmodules.vendors: 'Vendors',
  PurchaseSubmodules.purchaseOrders: 'Purchase Orders',
  PurchaseSubmodules.grnMaterialReceipt: 'GRN / Material Receipt',
  PurchaseSubmodules.vendorLedger: 'Vendor Ledger',

  InventorySubmodules.products: 'Products',
  InventorySubmodules.stockSummary: 'Stock Summary',
  InventorySubmodules.stockIn: 'Stock In',
  InventorySubmodules.stockOut: 'Stock Out',
  InventorySubmodules.warehouse: 'Warehouse',
  InventorySubmodules.lowStockAlerts: 'Low Stock Alerts',

  DispatchSubmodules.readyForDispatch: 'Ready for Dispatch',
  DispatchSubmodules.dispatchChallans: 'Dispatch Challans',
  DispatchSubmodules.shipmentTracking: 'Shipment Tracking',
  DispatchSubmodules.deliveredOrders: 'Delivered Orders',

  FinanceSubmodules.proformaInvoice: 'Proforma Invoice',
  FinanceSubmodules.taxInvoice:
      'Invoice', // Changed from 'Tax Invoice' to 'Invoice'
  FinanceSubmodules.paymentReceived: 'Payment Received',
  FinanceSubmodules.outstanding: 'Outstanding',
  FinanceSubmodules.expenseEntries: 'Expense Entries',

  ReportsSubmodules.salesReport: 'Sales Report',
  ReportsSubmodules.inquiryReport: 'Inquiry Report',
  ReportsSubmodules.customerReport: 'Customer Report',
  ReportsSubmodules.productReport: 'Product Report',
  ReportsSubmodules.paymentReport: 'Payment Report',

  AdministrationSubmodules.users: 'Users',
  AdministrationSubmodules.rolesPermissions: 'Roles & Permissions',
  AdministrationSubmodules.companyProfile: 'Company Profile',
  AdministrationSubmodules.branches: 'Branches',
  AdministrationSubmodules.auditLogs: 'Audit Logs',
};

/// ------------------------------------------------------------
/// PERMISSION MATRIX ACTIONS PER SUBMODULE
/// ------------------------------------------------------------

const List<String> standardCrudActions = [
  PermissionActions.view,
  PermissionActions.create,
  PermissionActions.edit,
  PermissionActions.delete,
];

const List<String> reportActions = [
  PermissionActions.view,
  PermissionActions.export,
];

const List<String> dashboardActions = [PermissionActions.view];

const List<String> serviceOperationalActions = [
  PermissionActions.view,
  PermissionActions.create,
  PermissionActions.edit,
];

const List<String> serviceComplaintActions = [
  PermissionActions.view,
  PermissionActions.create,
];

const Map<String, List<String>> permissionActionsByModule = {
  PermissionModules.dashboard: dashboardActions,
};

const Map<String, List<String>> permissionActionsBySubmodule = {
  SalesSubmodules.inquiries: standardCrudActions,
  SalesSubmodules.quotations: standardCrudActions,
  SalesSubmodules.salesOrders: standardCrudActions,
  SalesSubmodules.tasks: standardCrudActions,
  SalesSubmodules.meetings: standardCrudActions,

  // The Service card intentionally contains 12 visible actions in total.
  ServiceSubmodules.serviceCalls: serviceOperationalActions,
  ServiceSubmodules.serviceVisits: serviceOperationalActions,
  ServiceSubmodules.serviceTechnicians: [PermissionActions.view],
  ServiceSubmodules.complaints: serviceComplaintActions,
  ServiceSubmodules.amc: [PermissionActions.view],
  ServiceSubmodules.installation: [PermissionActions.view],
  ServiceSubmodules.serviceReports: [PermissionActions.view],

  CrmSubmodules.customers: standardCrudActions,
  CrmSubmodules.contacts: standardCrudActions,
  CrmSubmodules.customerVisits: standardCrudActions,

  PurchaseSubmodules.vendors: standardCrudActions,
  PurchaseSubmodules.purchaseOrders: standardCrudActions,
  PurchaseSubmodules.grnMaterialReceipt: standardCrudActions,
  PurchaseSubmodules.vendorLedger: [
    PermissionActions.view,
    PermissionActions.export,
  ],

  InventorySubmodules.products: standardCrudActions,
  InventorySubmodules.stockSummary: [
    PermissionActions.view,
    PermissionActions.export,
  ],
  InventorySubmodules.stockIn: standardCrudActions,
  InventorySubmodules.stockOut: standardCrudActions,
  InventorySubmodules.warehouse: standardCrudActions,
  InventorySubmodules.lowStockAlerts: [
    PermissionActions.view,
    PermissionActions.edit,
  ],

  DispatchSubmodules.readyForDispatch: [
    PermissionActions.view,
    PermissionActions.edit,
    PermissionActions.approve,
  ],
  DispatchSubmodules.dispatchChallans: standardCrudActions,
  DispatchSubmodules.shipmentTracking: [
    PermissionActions.view,
    PermissionActions.edit,
  ],
  DispatchSubmodules.deliveredOrders: [
    PermissionActions.view,
    PermissionActions.edit,
    PermissionActions.export,
  ],

  FinanceSubmodules.proformaInvoice: standardCrudActions,
  FinanceSubmodules.taxInvoice: standardCrudActions,
  FinanceSubmodules.paymentReceived: standardCrudActions,
  FinanceSubmodules.outstanding: [
    PermissionActions.view,
    PermissionActions.export,
  ],
  FinanceSubmodules.expenseEntries: standardCrudActions,

  ReportsSubmodules.salesReport: reportActions,
  ReportsSubmodules.inquiryReport: reportActions,
  ReportsSubmodules.customerReport: reportActions,
  ReportsSubmodules.productReport: reportActions,
  ReportsSubmodules.paymentReport: reportActions,

  AdministrationSubmodules.users: standardCrudActions,
  AdministrationSubmodules.rolesPermissions: [
    PermissionActions.view,
    PermissionActions.edit,
    PermissionActions.approve,
  ],
  AdministrationSubmodules.companyProfile: [
    PermissionActions.view,
    PermissionActions.edit,
  ],
  AdministrationSubmodules.branches: standardCrudActions,
  AdministrationSubmodules.auditLogs: [
    PermissionActions.view,
    PermissionActions.export,
  ],
};

/// ------------------------------------------------------------
/// CANONICAL PERMISSION BUILDERS
/// ------------------------------------------------------------

Map<String, bool> buildActionMap(
  List<String> actions, {
  required bool enabled,
}) {
  return <String, bool>{for (final action in actions) action: enabled};
}

Map<String, dynamic> buildEmptyPermissions() {
  final permissions = <String, dynamic>{};

  for (final module in permissionModuleOrder) {
    if (module == PermissionModules.dashboard) {
      permissions[module] = buildActionMap(
        permissionActionsByModule[module] ?? dashboardActions,
        enabled: false,
      );
      continue;
    }

    final submodules = permissionSubmoduleMap[module] ?? <String>[];
    permissions[module] = <String, dynamic>{
      for (final submodule in submodules)
        submodule: buildActionMap(
          permissionActionsBySubmodule[submodule] ?? standardCrudActions,
          enabled: false,
        ),
    };
  }

  return permissions;
}

Map<String, dynamic> buildFullPermissions() {
  final permissions = <String, dynamic>{};

  for (final module in permissionModuleOrder) {
    if (module == PermissionModules.dashboard) {
      permissions[module] = buildActionMap(
        permissionActionsByModule[module] ?? dashboardActions,
        enabled: true,
      );
      continue;
    }

    final submodules = permissionSubmoduleMap[module] ?? <String>[];
    permissions[module] = <String, dynamic>{
      for (final submodule in submodules)
        submodule: buildActionMap(
          permissionActionsBySubmodule[submodule] ?? standardCrudActions,
          enabled: true,
        ),
    };
  }

  return permissions;
}

Map<String, dynamic> mergePermissionsWithCanonicalShape(
  Map<String, dynamic>? incoming,
) {
  final canonical = buildEmptyPermissions();

  if (incoming == null || incoming.isEmpty) {
    return canonical;
  }

  for (final module in permissionModuleOrder) {
    final incomingModule = incoming[module];

    if (module == PermissionModules.dashboard) {
      final moduleActions = Map<String, bool>.from(
        canonical[module] as Map<String, bool>,
      );

      if (incomingModule is Map) {
        for (final action in moduleActions.keys) {
          moduleActions[action] = incomingModule[action] == true;
        }
      }

      canonical[module] = moduleActions;
      continue;
    }

    final submoduleMap = Map<String, dynamic>.from(
      canonical[module] as Map<String, dynamic>,
    );

    if (incomingModule is Map) {
      for (final submodule in submoduleMap.keys) {
        final canonicalActions = Map<String, bool>.from(
          submoduleMap[submodule] as Map<String, bool>,
        );
        final incomingSubmodules = module == PermissionModules.service
            ? _servicePermissionAliasesFor(submodule)
                  .map((key) => incomingModule[key])
                  .where((value) => value != null)
            : <dynamic>[incomingModule[submodule]];

        for (final incomingSubmodule in incomingSubmodules) {
          if (incomingSubmodule is Map) {
            for (final action in canonicalActions.keys) {
              if (incomingSubmodule[action] == true) {
                canonicalActions[action] = true;
              }
            }

            if (module == PermissionModules.service) {
              for (final entry in incomingSubmodule.entries) {
                if (!canonicalActions.containsKey(entry.key)) {
                  canonicalActions[entry.key.toString()] = entry.value == true;
                }
              }
            }
          } else if (incomingSubmodule == true) {
            canonicalActions[PermissionActions.view] = true;
          }
        }

        submoduleMap[submodule] = canonicalActions;
      }

      if (module == PermissionModules.service) {
        for (final entry in incomingModule.entries) {
          final key = entry.key.toString();
          if (!submoduleMap.containsKey(key) &&
              !_isKnownServicePermissionAlias(key)) {
            submoduleMap[entry.key.toString()] = _copyPermissionValue(
              entry.value,
            );
          }
        }
      }
    }

    canonical[module] = submoduleMap;
  }

  return canonical;
}

Iterable<String> _servicePermissionAliasesFor(String submodule) {
  switch (submodule) {
    case ServiceSubmodules.serviceCalls:
      return const ['serviceRequests', 'serviceCalls', 'serviceCall'];
    case ServiceSubmodules.serviceVisits:
      return const ['serviceVisits', 'serviceVisit'];
    case ServiceSubmodules.serviceTechnicians:
      return const ['serviceTechnicians', 'serviceTechnician'];
    case ServiceSubmodules.complaints:
      return const ['complaints', 'serviceComplaints'];
    case ServiceSubmodules.amc:
      return const ['amc', 'annualMaintenanceContracts'];
    case ServiceSubmodules.installation:
      return const ['installationCommissioning', 'installation'];
    case ServiceSubmodules.serviceReports:
      return const ['serviceReports', 'serviceReport'];
    default:
      return <String>[submodule];
  }
}

bool _isKnownServicePermissionAlias(String key) {
  return permissionSubmoduleMap[PermissionModules.service]!.any(
    (submodule) => _servicePermissionAliasesFor(submodule).contains(key),
  );
}

dynamic _copyPermissionValue(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _copyPermissionValue(entry.value),
    };
  }
  return value;
}

Map<String, dynamic> _canonicalRolePermissions(Map<String, dynamic> partial) {
  return mergePermissionsWithCanonicalShape(partial);
}

Map<String, dynamic> getDefaultPermissions(String role) {
  final normalizedRole = role.trim().toLowerCase();

  switch (normalizedRole) {
    case UserRoles.owner:
    case UserRoles.founder:
    case UserRoles.ceo:
    case UserRoles.superadmin:
    case UserRoles.admin:
      return buildFullPermissions();

    case UserRoles.manager:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
        PermissionModules.sales: {
          SalesSubmodules.inquiries: buildActionMap(
            permissionActionsBySubmodule[SalesSubmodules.inquiries]!,
            enabled: true,
          ),
          SalesSubmodules.quotations: buildActionMap(
            permissionActionsBySubmodule[SalesSubmodules.quotations]!,
            enabled: true,
          ),
          SalesSubmodules.salesOrders: buildActionMap(
            permissionActionsBySubmodule[SalesSubmodules.salesOrders]!,
            enabled: true,
          ),
          SalesSubmodules.tasks: buildActionMap(
            permissionActionsBySubmodule[SalesSubmodules.tasks]!,
            enabled: true,
          ),
          SalesSubmodules.meetings: buildActionMap(
            permissionActionsBySubmodule[SalesSubmodules.meetings]!,
            enabled: true,
          ),
        },
        PermissionModules.service: {
          for (final submodule
              in permissionSubmoduleMap[PermissionModules.service]!)
            submodule: buildActionMap(
              permissionActionsBySubmodule[submodule]!,
              enabled: true,
            ),
        },
        PermissionModules.crm: {
          CrmSubmodules.customers: buildActionMap(
            permissionActionsBySubmodule[CrmSubmodules.customers]!,
            enabled: true,
          ),
          CrmSubmodules.contacts: buildActionMap(
            permissionActionsBySubmodule[CrmSubmodules.contacts]!,
            enabled: true,
          ),
          CrmSubmodules.customerVisits: buildActionMap(
            permissionActionsBySubmodule[CrmSubmodules.customerVisits]!,
            enabled: true,
          ),
        },
        PermissionModules.purchase: {
          PurchaseSubmodules.vendors: buildActionMap(
            permissionActionsBySubmodule[PurchaseSubmodules.vendors]!,
            enabled: true,
          ),
          PurchaseSubmodules.purchaseOrders: buildActionMap(
            permissionActionsBySubmodule[PurchaseSubmodules.purchaseOrders]!,
            enabled: true,
          ),
          PurchaseSubmodules.grnMaterialReceipt: buildActionMap(
            permissionActionsBySubmodule[PurchaseSubmodules
                .grnMaterialReceipt]!,
            enabled: true,
          ),
          PurchaseSubmodules.vendorLedger: buildActionMap(
            permissionActionsBySubmodule[PurchaseSubmodules.vendorLedger]!,
            enabled: true,
          ),
        },
        PermissionModules.inventory: {
          InventorySubmodules.products: buildActionMap(
            permissionActionsBySubmodule[InventorySubmodules.products]!,
            enabled: true,
          ),
          InventorySubmodules.stockSummary: buildActionMap(
            permissionActionsBySubmodule[InventorySubmodules.stockSummary]!,
            enabled: true,
          ),
          InventorySubmodules.stockIn: buildActionMap(
            permissionActionsBySubmodule[InventorySubmodules.stockIn]!,
            enabled: true,
          ),
          InventorySubmodules.stockOut: buildActionMap(
            permissionActionsBySubmodule[InventorySubmodules.stockOut]!,
            enabled: true,
          ),
          InventorySubmodules.warehouse: buildActionMap(
            permissionActionsBySubmodule[InventorySubmodules.warehouse]!,
            enabled: true,
          ),
          InventorySubmodules.lowStockAlerts: buildActionMap(
            permissionActionsBySubmodule[InventorySubmodules.lowStockAlerts]!,
            enabled: true,
          ),
        },
        PermissionModules.dispatch: {
          DispatchSubmodules.readyForDispatch: buildActionMap(
            permissionActionsBySubmodule[DispatchSubmodules.readyForDispatch]!,
            enabled: true,
          ),
          DispatchSubmodules.dispatchChallans: buildActionMap(
            permissionActionsBySubmodule[DispatchSubmodules.dispatchChallans]!,
            enabled: true,
          ),
          DispatchSubmodules.shipmentTracking: buildActionMap(
            permissionActionsBySubmodule[DispatchSubmodules.shipmentTracking]!,
            enabled: true,
          ),
          DispatchSubmodules.deliveredOrders: buildActionMap(
            permissionActionsBySubmodule[DispatchSubmodules.deliveredOrders]!,
            enabled: true,
          ),
        },
        PermissionModules.finance: {
          FinanceSubmodules.proformaInvoice: buildActionMap(
            permissionActionsBySubmodule[FinanceSubmodules.proformaInvoice]!,
            enabled: true,
          ),
          FinanceSubmodules.taxInvoice: buildActionMap(
            permissionActionsBySubmodule[FinanceSubmodules.taxInvoice]!,
            enabled: true,
          ),
          FinanceSubmodules.paymentReceived: buildActionMap(
            permissionActionsBySubmodule[FinanceSubmodules.paymentReceived]!,
            enabled: true,
          ),
          FinanceSubmodules.outstanding: buildActionMap(
            permissionActionsBySubmodule[FinanceSubmodules.outstanding]!,
            enabled: true,
          ),
          FinanceSubmodules.expenseEntries: buildActionMap(
            permissionActionsBySubmodule[FinanceSubmodules.expenseEntries]!,
            enabled: true,
          ),
        },
        PermissionModules.reports: {
          ReportsSubmodules.salesReport: buildActionMap(
            permissionActionsBySubmodule[ReportsSubmodules.salesReport]!,
            enabled: true,
          ),
          ReportsSubmodules.inquiryReport: buildActionMap(
            permissionActionsBySubmodule[ReportsSubmodules.inquiryReport]!,
            enabled: true,
          ),
          ReportsSubmodules.customerReport: buildActionMap(
            permissionActionsBySubmodule[ReportsSubmodules.customerReport]!,
            enabled: true,
          ),
          ReportsSubmodules.productReport: buildActionMap(
            permissionActionsBySubmodule[ReportsSubmodules.productReport]!,
            enabled: true,
          ),
          ReportsSubmodules.paymentReport: buildActionMap(
            permissionActionsBySubmodule[ReportsSubmodules.paymentReport]!,
            enabled: true,
          ),
        },
        PermissionModules.administration: {
          AdministrationSubmodules.users: buildActionMap(
            permissionActionsBySubmodule[AdministrationSubmodules.users]!,
            enabled: false,
          ),
          AdministrationSubmodules.rolesPermissions: buildActionMap(
            permissionActionsBySubmodule[AdministrationSubmodules
                .rolesPermissions]!,
            enabled: false,
          ),
          AdministrationSubmodules.companyProfile: buildActionMap(
            permissionActionsBySubmodule[AdministrationSubmodules
                .companyProfile]!,
            enabled: false,
          ),
          AdministrationSubmodules.branches: buildActionMap(
            permissionActionsBySubmodule[AdministrationSubmodules.branches]!,
            enabled: false,
          ),
          AdministrationSubmodules.auditLogs: buildActionMap(
            permissionActionsBySubmodule[AdministrationSubmodules.auditLogs]!,
            enabled: false,
          ),
        },
      });

    case UserRoles.sales:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
        PermissionModules.sales: {
          SalesSubmodules.inquiries: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          SalesSubmodules.quotations: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          SalesSubmodules.salesOrders: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: false,
            PermissionActions.delete: false,
          },
          SalesSubmodules.tasks: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          SalesSubmodules.meetings: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
        },
        PermissionModules.crm: {
          CrmSubmodules.customers: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          CrmSubmodules.contacts: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          CrmSubmodules.customerVisits: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
        },
      });

    case UserRoles.service:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
        PermissionModules.service: {
          ServiceSubmodules.serviceCalls: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
          },
          ServiceSubmodules.serviceVisits: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: false,
          },
        },
        PermissionModules.crm: {
          CrmSubmodules.customers: {
            PermissionActions.view: true,
            PermissionActions.create: false,
            PermissionActions.edit: false,
            PermissionActions.delete: false,
          },
          CrmSubmodules.contacts: {
            PermissionActions.view: true,
            PermissionActions.create: false,
            PermissionActions.edit: false,
            PermissionActions.delete: false,
          },
          CrmSubmodules.customerVisits: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
        },
      });

    case UserRoles.accounts:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
        PermissionModules.finance: {
          FinanceSubmodules.proformaInvoice: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          FinanceSubmodules.taxInvoice: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          FinanceSubmodules.paymentReceived: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          FinanceSubmodules.outstanding: {
            PermissionActions.view: true,
            PermissionActions.export: true,
          },
          FinanceSubmodules.expenseEntries: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
        },
        PermissionModules.reports: {
          ReportsSubmodules.paymentReport: {
            PermissionActions.view: true,
            PermissionActions.export: true,
          },
        },
      });

    case UserRoles.purchase:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
        PermissionModules.purchase: {
          PurchaseSubmodules.vendors: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          PurchaseSubmodules.purchaseOrders: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          PurchaseSubmodules.grnMaterialReceipt: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          PurchaseSubmodules.vendorLedger: {
            PermissionActions.view: true,
            PermissionActions.export: true,
          },
        },
        PermissionModules.inventory: {
          InventorySubmodules.products: {
            PermissionActions.view: true,
            PermissionActions.create: false,
            PermissionActions.edit: false,
            PermissionActions.delete: false,
          },
          InventorySubmodules.stockSummary: {
            PermissionActions.view: true,
            PermissionActions.export: false,
          },
        },
      });

    case UserRoles.inventory:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
        PermissionModules.inventory: {
          InventorySubmodules.products: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          InventorySubmodules.stockSummary: {
            PermissionActions.view: true,
            PermissionActions.export: true,
          },
          InventorySubmodules.stockIn: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          InventorySubmodules.stockOut: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          InventorySubmodules.warehouse: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          InventorySubmodules.lowStockAlerts: {
            PermissionActions.view: true,
            PermissionActions.edit: true,
          },
        },
      });

    case UserRoles.dispatch:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
        PermissionModules.dispatch: {
          DispatchSubmodules.readyForDispatch: {
            PermissionActions.view: true,
            PermissionActions.edit: true,
            PermissionActions.approve: false,
          },
          DispatchSubmodules.dispatchChallans: {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.edit: true,
            PermissionActions.delete: false,
          },
          DispatchSubmodules.shipmentTracking: {
            PermissionActions.view: true,
            PermissionActions.edit: true,
          },
          DispatchSubmodules.deliveredOrders: {
            PermissionActions.view: true,
            PermissionActions.edit: true,
            PermissionActions.export: true,
          },
        },
      });

    case UserRoles.viewer:
      return _canonicalRolePermissions({
        PermissionModules.dashboard: buildActionMap(
          dashboardActions,
          enabled: true,
        ),
      });

    default:
      return buildEmptyPermissions();
  }
}

/// ------------------------------------------------------------
/// PERMISSION HELPERS
/// ------------------------------------------------------------

Map<String, dynamic> normalizePermissionsForStorage(
  Map<String, dynamic>? permissions, {
  String? role,
}) {
  if (isSuperAccessRole(role)) {
    return buildFullPermissions();
  }
  return mergePermissionsWithCanonicalShape(permissions);
}

bool hasModuleAccess(Map<String, dynamic>? permissions, String moduleKey) {
  if (permissions == null || permissions.isEmpty) return false;

  final moduleData = permissions[moduleKey];
  if (moduleData is! Map) return false;

  for (final value in moduleData.values) {
    if (value == true) return true;

    if (value is Map) {
      for (final nestedValue in value.values) {
        if (nestedValue == true) return true;
      }
    }
  }

  return false;
}

bool hasPermission(
  Map<String, dynamic>? permissions, {
  required String moduleKey,
  String? submoduleKey,
  required String action,
}) {
  if (permissions == null || permissions.isEmpty) return false;

  final moduleData = permissions[moduleKey];
  if (moduleData is! Map) return false;

  if (submoduleKey == null || submoduleKey.isEmpty) {
    return moduleData[action] == true;
  }

  final submoduleData = moduleData[submoduleKey];
  if (submoduleData is! Map) return false;

  return submoduleData[action] == true;
}

/// ------------------------------------------------------------
/// HELPER FUNCTIONS
/// ------------------------------------------------------------

Color getStatusColor(String status) {
  switch (status) {
    case UserStatus.active:
      return successColor;
    case UserStatus.inactive:
      return warningColor;
    case UserStatus.archived:
      return dangerColor;
    default:
      return mutedTextColor;
  }
}

String formatRoleLabel(String role) {
  return roleLabels[role] ?? role;
}

String formatModuleLabel(String moduleKey) {
  return permissionModuleLabels[moduleKey] ?? moduleKey;
}

String formatSubmoduleLabel(String submoduleKey) {
  return permissionSubmoduleLabels[submoduleKey] ?? submoduleKey;
}

String formatPermissionActionLabel(String action) {
  return permissionActionLabels[action] ?? action;
}
