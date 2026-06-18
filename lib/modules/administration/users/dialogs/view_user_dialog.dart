// FILE PATH: lib/modules/administration/users/dialogs/view_user_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/widgets/mini_badge.dart';

typedef UserDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

const Color _viewPrimaryColor = Color(0xFF17324D);
const Color _viewAccentColor = Color(0xFF3B82F6);
const Color _viewScaffoldBgColor = Color(0xFFF4F7FB);
const Color _viewCardBorderColor = Color(0xFFE2E8F0);
const Color _viewMutedTextColor = Color(0xFF64748B);
const Color _viewHeadingTextColor = Color(0xFF0F172A);

Future<void> showViewUserDialog({
  required BuildContext context,
  required UserDoc doc,
}) async {
  final data = doc.data();

  final name = _readDisplayName(data);
  final email = (data['email'] ?? '').toString().trim();
  final phone = (data['phone'] ?? '').toString().trim();
  final role = (data['role'] ?? '').toString().trim();
  final department = (data['department'] ?? '').toString().trim();
  final designation = (data['designation'] ?? '').toString().trim();
  final accessScope = (data['accessScope'] ?? '').toString().trim();
  final employeeCode = (data['employeeCode'] ?? '').toString().trim();

  final isActive = (data['isActive'] ?? true) == true;
  final isDeleted = (data['isDeleted'] ?? false) == true;
  final storedStatus = (data['status'] ?? '').toString().trim();
  final industry = (data['industry'] ?? '').toString().trim();

  final createdAt = formatTimestamp(data['createdAt']);
  final updatedAt = formatTimestamp(data['updatedAt']);
  final lastLogin = formatTimestamp(data['lastLoginAt']);

  final currentStatus = storedStatus.isNotEmpty
      ? statusLabelFromValue(storedStatus)
      : statusLabel(
    isActive: isActive,
    isDeleted: isDeleted,
  );

  final currentStatusColor = storedStatus.isNotEmpty
      ? statusColorFromValue(storedStatus)
      : statusColor(
    isActive: isActive,
    isDeleted: isDeleted,
  );

  final permissions = Map<String, dynamic>.from(data['permissions'] ?? {});

  final bool isExportImport = industry == 'export_import';
  final enabledPermissions = _extractEnabledPermissions(permissions, isExportImport);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 860),
          decoration: BoxDecoration(
            color: _viewScaffoldBgColor,
            borderRadius: BorderRadius.circular(26),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Administration • Users • View User',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _viewMutedTextColor,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Review employee profile, access control, system activity, and enabled permissions.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _viewMutedTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Close'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _viewHeadingTextColor,
                              side: const BorderSide(color: _viewCardBorderColor),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildDialogUserHeader(data),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 22,
                    ),
                    child: Column(
                      children: [
                        _buildSectionCard(
                          title: 'Profile Information',
                          subtitle:
                          'Basic employee identity and organization mapping.',
                          child: Column(
                            children: [
                              _buildResponsiveTwoColumn(
                                left: Column(
                                  children: [
                                    _detailRow('Full Name', name.isEmpty ? '-' : name),
                                    _detailRow('Email', email.isEmpty ? '-' : email),
                                    _detailRow('Phone', phone.isEmpty ? '-' : phone),
                                  ],
                                ),
                                right: Column(
                                  children: [
                                    _detailRow(
                                      'Employee Code',
                                      employeeCode.isEmpty ? '-' : employeeCode,
                                    ),
                                    _detailRow(
                                      'Department',
                                      department.isEmpty
                                          ? '-'
                                          : formatDepartment(department),
                                    ),
                                    _detailRow(
                                      'Designation',
                                      designation.isEmpty
                                          ? '-'
                                          : formatDesignation(designation),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          title: 'Access Control',
                          subtitle:
                          'Current role, access scope, and account state.',
                          child: Column(
                            children: [
                              _buildResponsiveTwoColumn(
                                left: Column(
                                  children: [
                                    _detailRow(
                                      'Role',
                                      role.isEmpty ? '-' : formatRole(role),
                                      valueColor: roleColor(role),
                                    ),
                                    _detailRow(
                                      'Status',
                                      currentStatus,
                                      valueColor: currentStatusColor,
                                    ),
                                  ],
                                ),
                                right: Column(
                                  children: [
                                    _detailRow(
                                      'Access Scope',
                                      accessScope.isEmpty
                                          ? '-'
                                          : formatAccessScope(accessScope),
                                    ),
                                    _detailRow(
                                      'Account Type',
                                      isDeleted
                                          ? 'Deleted'
                                          : (isActive ? 'Active User' : 'Inactive User'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          title: 'System Activity',
                          subtitle:
                          'Timeline details for creation, updates, and login activity.',
                          child: Column(
                            children: [
                              _buildResponsiveTwoColumn(
                                left: Column(
                                  children: [
                                    _detailRow('Last Login', lastLogin),
                                    _detailRow('Created Date', createdAt),
                                  ],
                                ),
                                right: Column(
                                  children: [
                                    _detailRow('Updated Date', updatedAt),
                                    _detailRow(
                                      'Record Status',
                                      storedStatus.isEmpty ? '-' : storedStatus,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          title: 'Enabled Permissions',
                          subtitle:
                          'Permissions granted across ERP modules and submodules.',
                          child: enabledPermissions.isEmpty
                              ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _viewCardBorderColor),
                            ),
                            child: const Text(
                              'No explicit permissions assigned.',
                              style: TextStyle(
                                color: _viewMutedTextColor,
                                fontSize: 13,
                              ),
                            ),
                          )
                              : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: enabledPermissions
                                .map(
                                  (permission) => MiniBadge(
                                text: _permissionDisplayLabel(permission),
                                textColor: _viewPrimaryColor,
                                backgroundColor: const Color(0xFFF1F5F9),
                              ),
                            )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildDialogUserHeader(Map<String, dynamic> data) {
  final name = _readDisplayName(data);
  final email = (data['email'] ?? '').toString().trim();
  final phone = (data['phone'] ?? '').toString().trim();
  final role = (data['role'] ?? UserRoles.sales).toString().trim();
  final department = (data['department'] ?? '').toString().trim();
  final designation = (data['designation'] ?? '').toString().trim();

  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _viewCardBorderColor),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: _viewPrimaryColor.withValues(alpha: 0.10),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _viewPrimaryColor,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Unnamed User' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: _viewHeadingTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email.isEmpty ? '-' : email,
                style: const TextStyle(color: _viewMutedTextColor),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(color: _viewMutedTextColor),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MiniBadge(
                    text: formatRole(role),
                    textColor: roleColor(role),
                    backgroundColor: roleColor(role).withValues(alpha: 0.10),
                  ),
                  if (department.isNotEmpty)
                    MiniBadge(
                      text: formatDepartment(department),
                      textColor: const Color(0xFF475569),
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  if (designation.isNotEmpty)
                    MiniBadge(
                      text: formatDesignation(designation),
                      textColor: _viewAccentColor,
                      backgroundColor: const Color(0x1A2563EB),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionCard({
  required String title,
  required String subtitle,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _viewCardBorderColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D0F172A),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _viewHeadingTextColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: _viewMutedTextColor,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

Widget _buildResponsiveTwoColumn({
  required Widget left,
  required Widget right,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 860) {
        return Column(
          children: [
            left,
            const SizedBox(height: 8),
            right,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 24),
          Expanded(child: right),
        ],
      );
    },
  );
}

Widget _detailRow(
    String label,
    String value, {
      Color? valueColor,
    }) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: _viewMutedTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? _viewPrimaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    ),
  );
}

List<String> _extractEnabledPermissions(Map<String, dynamic> permissions, bool isExportImport) {
  final enabled = <String>[];

  permissions.forEach((module, submodules) {
    if (submodules is Map) {
      if (module == 'dashboard') {
        submodules.forEach((action, value) {
          if (value == true && _isModuleAllowed(module, null, isExportImport)) {
            enabled.add('$module.$action');
          }
        });
      } else {
        submodules.forEach((submodule, actions) {
          if (_isModuleAllowed(module, submodule, isExportImport)) {
            if (actions is Map) {
              actions.forEach((action, value) {
                if (value == true) {
                  enabled.add('$module.$submodule.$action');
                }
              });
            } else if (actions == true) {
              enabled.add('$module.$submodule');
            }
          }
        });
      }
    }
  });

  enabled.sort();
  return enabled;
}

bool _isModuleAllowed(String module, String? submodule, bool isExportImport) {
  if (!isExportImport) return true;

  if (module == 'dashboard') return true;
  if (module == 'sales') return false; // Strictly blocked
  if (module == 'crm') return submodule == 'customers';
  if (module == 'finance') {
    return ['taxInvoice', 'paymentReceived', 'outstanding', 'expenseEntries'].contains(submodule);
  }
  if (module == 'reports') {
    return ['salesReport', 'customerReport', 'paymentReport'].contains(submodule);
  }
  return false;
}

String _permissionDisplayLabel(String key) {
  if (key.contains('.')) {
    final parts = key.split('.');
    if (parts.length == 3) {
      return '${_moduleLabel(parts[0])} • ${_submoduleLabel(parts[1])} • ${formatPermissionActionLabel(parts[2])}';
    } else if (parts.length == 2 && parts[0] == 'dashboard') {
      return '${_moduleLabel(parts[0])} • ${formatPermissionActionLabel(parts[1])}';
    } else if (parts.length == 2) {
      return '${_moduleLabel(parts[0])} • ${_submoduleLabel(parts[1])}';
    }
  }
  return permissionLabel(key);
}

String _moduleLabel(String moduleKey) {
  switch (moduleKey) {
    case 'dashboard':
      return 'Dashboard';
    case 'sales':
      return 'Sales';
    case 'crm':
      return 'CRM';
    case 'purchase':
      return 'Purchase';
    case 'inventory':
      return 'Inventory';
    case 'dispatch':
      return 'Dispatch';
    case 'finance':
      return 'Finance';
    case 'reports':
      return 'Reports';
    case 'administration':
      return 'Administration';
    default:
      return moduleKey;
  }
}

String _submoduleLabel(String key) {
  const labels = {
    'dashboard': 'Dashboard',
    'inquiries': 'Inquiries',
    'quotations': 'Quotations',
    'salesOrder': 'Sales Order',
    'tasks': 'Tasks',
    'meetings': 'Meetings',
    'customers': 'Customers',
    'contacts': 'Contacts',
    'customerVisits': 'Customer Visits',
    'communicationHistory': 'Communication History',
    'vendors': 'Vendors',
    'purchaseOrders': 'Purchase Orders',
    'grnMaterialReceipt': 'GRN / Material Receipt',
    'vendorLedger': 'Vendor Ledger',
    'products': 'Products',
    'stockSummary': 'Stock Summary',
    'stockIn': 'Stock In',
    'stockOut': 'Stock Out',
    'warehouse': 'Warehouse',
    'lowStockAlerts': 'Low Stock Alerts',
    'readyForDispatch': 'Ready for Dispatch',
    'dispatchChallans': 'Dispatch Challans',
    'shipmentTracking': 'Shipment Tracking',
    'deliveredOrders': 'Delivered Orders',
    'proformaInvoice': 'Proforma Invoice',
    'taxInvoice': 'Invoice',
    'paymentReceived': 'Payment Received',
    'outstanding': 'Outstanding',
    'expenseEntries': 'Expense Entries',
    'salesReport': 'Sales Report',
    'inquiryReport': 'Inquiry Report',
    'customerReport': 'Customer Report',
    'productReport': 'Product Report',
    'paymentReport': 'Payment Report',
    'users': 'Users',
    'rolesPermissions': 'Roles & Permissions',
    'companyProfile': 'Company Profile',
    'branches': 'Branches',
    'auditLogs': 'Audit Logs',
  };

  return labels[key] ?? key;
}

String _readDisplayName(Map<String, dynamic> data) {
  final displayName = (data['displayName'] ?? '').toString().trim();
  if (displayName.isNotEmpty) return displayName;

  final legacyName = (data['name'] ?? '').toString().trim();
  if (legacyName.isNotEmpty) return legacyName;

  return 'Unnamed User';
}