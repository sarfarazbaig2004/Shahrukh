import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';

/// ------------------------------------------------------------
/// ROLE COLOR
/// ------------------------------------------------------------

Color roleColor(String role) {
  switch (_normalize(role)) {
    case UserRoles.admin:
      return const Color(0xFF7C3AED);

    case UserRoles.manager:
      return const Color(0xFF2563EB);

    case UserRoles.sales:
      return const Color(0xFF16A34A);

    case UserRoles.service:
      return const Color(0xFFF97316);

    case UserRoles.accounts:
      return const Color(0xFF0891B2);

    case UserRoles.purchase:
      return const Color(0xFF0EA5E9);

    case UserRoles.inventory:
      return const Color(0xFF22C55E);

    case UserRoles.dispatch:
      return const Color(0xFFEF4444);

    case UserRoles.viewer:
      return const Color(0xFF6B7280);

    default:
      return primaryColor;
  }
}

/// ------------------------------------------------------------
/// STATUS
/// ------------------------------------------------------------

String statusLabel({required bool isActive, required bool isDeleted}) {
  if (isDeleted) return 'Archived';
  if (isActive) return 'Active';
  return 'Inactive';
}

String statusLabelFromValue(String status) {
  switch (_normalize(status)) {
    case UserStatus.active:
      return 'Active';
    case UserStatus.inactive:
      return 'Inactive';
    case UserStatus.archived:
      return 'Archived';
    default:
      return _humanizeKey(status);
  }
}

Color statusColor({required bool isActive, required bool isDeleted}) {
  if (isDeleted) return dangerColor;
  if (isActive) return successColor;
  return warningColor;
}

Color statusColorFromValue(String status) {
  switch (_normalize(status)) {
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

/// ------------------------------------------------------------
/// DATE & TIME
/// ------------------------------------------------------------

String formatTimestamp(dynamic value) {
  if (value == null) return '-';

  if (value is Timestamp) {
    return formatDateTime(value.toDate());
  }

  if (value is DateTime) {
    return formatDateTime(value);
  }

  return value.toString();
}

String formatDateTime(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();

  return '$day/$month/$year ${formatTime(dt)}';
}

String formatTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $ampm';
}

/// ------------------------------------------------------------
/// ROLE / LABEL FORMATTING
/// ------------------------------------------------------------

String formatRole(String role) {
  return roleLabels[role] ?? _humanizeKey(role);
}

String formatDepartment(String department) {
  return _humanizeKey(department);
}

String formatDesignation(String designation) {
  return _humanizeKey(designation);
}

String formatBranch(String branchName) {
  if (branchName.trim().isEmpty) return '-';
  return _humanizeKey(branchName);
}

/// ------------------------------------------------------------
/// ACCESS SCOPE
/// ------------------------------------------------------------

String formatAccessScope(String scope) {
  return accessScopeLabels[scope] ?? _humanizeKey(scope);
}

/// ------------------------------------------------------------
/// PERMISSION LABELS (EXPANDED FOR ERP)
/// ------------------------------------------------------------

String permissionLabel(String key) {
  switch (key) {
    // Dashboard
    case 'dashboard':
      return 'Dashboard';

    // CRM
    case 'customers':
      return 'Customers';
    case 'contacts':
      return 'Contacts';
    case 'customerVisits':
      return 'Customer Visits';

    // Sales
    case 'inquiries':
      return 'Inquiries';
    case 'quotations':
      return 'Quotations';
    case 'salesOrder':
      return 'Sales Orders';
    case 'tasks':
      return 'Tasks';
    case 'meetings':
      return 'Meetings';

    // Service
    case 'service':
      return 'Service';
    case 'serviceRequests':
    case 'serviceCalls':
      return 'Service Calls';
    case 'serviceVisits':
      return 'Service Visits';
    case 'serviceTechnicians':
      return 'Service Technicians';
    case 'complaints':
      return 'Complaints';
    case 'amc':
      return 'AMC';
    case 'installationCommissioning':
    case 'installation':
      return 'Installation';
    case 'serviceReports':
      return 'Service Reports';

    // Inventory
    case 'products':
      return 'Products';
    case 'stockSummary':
      return 'Stock Summary';
    case 'stockIn':
      return 'Stock In';
    case 'stockOut':
      return 'Stock Out';
    case 'warehouse':
      return 'Warehouse';

    // Purchase
    case 'vendors':
      return 'Vendors';
    case 'purchaseOrders':
      return 'Purchase Orders';
    case 'grn':
      return 'GRN';

    // Finance
    case 'invoice':
      return 'Invoices';
    case 'payments':
      return 'Payments';
    case 'expenses':
      return 'Expenses';

    // Reports
    case 'reports':
      return 'Reports';

    // Admin
    case 'userManagement':
      return 'User Management';
    case 'rolesPermissions':
      return 'Roles & Permissions';
    case 'companyProfile':
      return 'Company Profile';
    case 'branches':
      return 'Branches';
    case 'auditLogs':
      return 'Audit Logs';

    default:
      return _humanizeKey(key);
  }
}

/// ------------------------------------------------------------
/// GENERIC HELPERS
/// ------------------------------------------------------------

String _humanizeKey(String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) return '';

  final withSpaces = normalized
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .replaceAll('-', ' ');

  final words = withSpaces
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(_capitalize)
      .toList();

  return words.join(' ');
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}
