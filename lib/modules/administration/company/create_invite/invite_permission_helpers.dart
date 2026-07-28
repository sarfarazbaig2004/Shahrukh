// FILE PATH: lib/modules/administration/company/create_invite/widgets/invite_permission_helpers.dart
part of '../screen_create_invite.dart';

extension _CreateInvitePermissionHelpers on _ScreenCreateInviteState {
  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  Map<String, dynamic> _getIndustryDefaultPermissions({
    required String role,
    required bool isExportImport,
  }) {
    if (isExportImport) {
      if (role.toLowerCase() == 'admin') {
        return {
          'dashboard': {'dashboard': true},
          'crm': {'customers': true},
          'finance': {
            'taxInvoice': true,
            'paymentReceived': true,
            'outstanding': true,
            'expenseEntries': true,
          },
          'reports': {
            'salesReport': true,
            'customerReport': true,
            'paymentReport': true,
          },
        };
      } else {
        return {
          'dashboard': {'dashboard': true},
          'crm': {'customers': true},
        };
      }
    }
    return getDefaultPermissions(role);
  }

  Map<String, dynamic> _buildUiPermissionState({
    required String role,
    required bool isExportImport,
    required Map<String, dynamic>? permissions,
  }) {
    return mergePermissionsWithCanonicalShape(
      permissions ??
          _getIndustryDefaultPermissions(
            role: role,
            isExportImport: isExportImport,
          ),
    );
  }

  Map<String, dynamic> _readModulePermissions(
    Map<String, dynamic> permissionsMap,
    String moduleKey,
  ) {
    final moduleValue = permissionsMap[moduleKey];

    if (moduleKey == PermissionModules.dashboard) {
      return moduleValue is Map<String, dynamic>
          ? Map<String, dynamic>.from(moduleValue)
          : <String, dynamic>{};
    }

    return moduleValue is Map<String, dynamic>
        ? Map<String, dynamic>.from(moduleValue)
        : <String, dynamic>{};
  }

  Map<String, dynamic> _setPermissionValue({
    required Map<String, dynamic> permissionsMap,
    required String moduleKey,
    required String? submoduleKey,
    required String action,
    required bool value,
  }) {
    final updated = _deepCopyPermissions(permissionsMap);

    if (submoduleKey == null || submoduleKey.isEmpty) {
      final moduleActions = Map<String, dynamic>.from(updated[moduleKey] ?? {});
      moduleActions[action] = value;
      updated[moduleKey] = moduleActions;
      return updated;
    }

    final moduleMap = Map<String, dynamic>.from(updated[moduleKey] ?? {});
    final submoduleMap = Map<String, dynamic>.from(
      moduleMap[submoduleKey] ?? {},
    );
    submoduleMap[action] = value;
    moduleMap[submoduleKey] = submoduleMap;
    updated[moduleKey] = moduleMap;

    return updated;
  }

  Map<String, dynamic> _deepCopyPermissions(Map<String, dynamic> input) {
    final result = <String, dynamic>{};

    for (final entry in input.entries) {
      final value = entry.value;
      if (value is Map) {
        result[entry.key] = _deepCopyPermissions(
          Map<String, dynamic>.from(value),
        );
      } else {
        result[entry.key] = value;
      }
    }

    return result;
  }

  Map<String, dynamic> _normalizePermissionsForPayload(
    Map<String, dynamic> rawPerms,
  ) {
    final payload = _deepCopyPermissions(rawPerms);

    if (payload['sales'] is Map) {
      final sales = payload['sales'] as Map<String, dynamic>;

      if (sales.containsKey('salesOrder') &&
          !sales.containsKey('salesOrders')) {
        sales['salesOrders'] = sales['salesOrder'];
      } else if (sales.containsKey('salesOrders') &&
          !sales.containsKey('salesOrder')) {
        sales['salesOrder'] = sales['salesOrders'];
      }

      payload['sales'] = sales;
    }

    if (payload['service'] is Map) {
      final service = payload['service'] as Map<String, dynamic>;

      if (service.containsKey('serviceQuotations') &&
          !service.containsKey('serviceQuotation')) {
        service['serviceQuotation'] = service['serviceQuotations'];
      } else if (service.containsKey('serviceQuotation') &&
          !service.containsKey('serviceQuotations')) {
        service['serviceQuotations'] = service['serviceQuotation'];
      }

      if (service.containsKey('serviceSalesOrders') &&
          !service.containsKey('serviceSalesOrder')) {
        service['serviceSalesOrder'] = service['serviceSalesOrders'];
      } else if (service.containsKey('serviceSalesOrder') &&
          !service.containsKey('serviceSalesOrders')) {
        service['serviceSalesOrders'] = service['serviceSalesOrder'];
      }

      payload['service'] = service;
    }

    if (payload['purchase'] is Map) {
      final purchase = payload['purchase'] as Map<String, dynamic>;

      if (purchase.containsKey('purchaseOrders') &&
          !purchase.containsKey('purchaseOrder')) {
        purchase['purchaseOrder'] = purchase['purchaseOrders'];
      } else if (purchase.containsKey('purchaseOrder') &&
          !purchase.containsKey('purchaseOrders')) {
        purchase['purchaseOrders'] = purchase['purchaseOrder'];
      }

      if (purchase.containsKey('purchaseQuotations') &&
          !purchase.containsKey('purchaseQuotation')) {
        purchase['purchaseQuotation'] = purchase['purchaseQuotations'];
      } else if (purchase.containsKey('purchaseQuotation') &&
          !purchase.containsKey('purchaseQuotations')) {
        purchase['purchaseQuotations'] = purchase['purchaseQuotation'];
      }

      if (purchase.containsKey('purchaseBills') &&
          !purchase.containsKey('purchaseBill')) {
        purchase['purchaseBill'] = purchase['purchaseBills'];
      } else if (purchase.containsKey('purchaseBill') &&
          !purchase.containsKey('purchaseBills')) {
        purchase['purchaseBills'] = purchase['purchaseBill'];
      }

      if (purchase.containsKey('purchaseRfq') &&
          !purchase.containsKey('purchaseRfqs')) {
        purchase['purchaseRfqs'] = purchase['purchaseRfq'];
      } else if (purchase.containsKey('purchaseRfqs') &&
          !purchase.containsKey('purchaseRfq')) {
        purchase['purchaseRfq'] = purchase['purchaseRfqs'];
      }

      payload['purchase'] = purchase;
    }

    if (payload['crm'] is Map) {
      final crm = payload['crm'] as Map<String, dynamic>;

      if (crm.containsKey('customers') && !crm.containsKey('customer')) {
        crm['customer'] = crm['customers'];
      } else if (crm.containsKey('customer') && !crm.containsKey('customers')) {
        crm['customers'] = crm['customer'];
      }

      payload['crm'] = crm;
    }

    return payload;
  }

  int _selectedPermissionCount(
    Map<String, dynamic> permissionsMap,
    List<String> activeMods,
  ) {
    int count = 0;

    for (final moduleKey in activeMods) {
      final moduleValue = permissionsMap[moduleKey];

      if (moduleKey == PermissionModules.dashboard) {
        if (moduleValue is Map) {
          for (final value in moduleValue.values) {
            if (value == true) count++;
          }
        }
        continue;
      }

      if (moduleValue is Map) {
        for (final submoduleValue in moduleValue.values) {
          if (submoduleValue is Map) {
            for (final actionValue in submoduleValue.values) {
              if (actionValue == true) count++;
            }
          }
        }
      }
    }

    return count;
  }

  int _countEnabledActionsInModule({
    required String moduleKey,
    required bool isExportImport,
    required Map<String, dynamic> modulePermissions,
  }) {
    int count = 0;

    if (moduleKey == PermissionModules.dashboard) {
      for (final value in modulePermissions.values) {
        if (value == true) count++;
      }
      return count;
    }

    for (final submodule in _displayedPermissionSubmodules(
      moduleKey: moduleKey,
      isExportImport: isExportImport,
    )) {
      final submoduleValue = modulePermissions[submodule];
      if (submoduleValue is Map) {
        for (final action
            in permissionActionsBySubmodule[submodule] ?? standardCrudActions) {
          if (submoduleValue[action] == true) count++;
        }
      }
    }

    return count;
  }

  int _countTotalActionsInModule({
    required String moduleKey,
    required bool isExportImport,
    required Map<String, dynamic> modulePermissions,
  }) {
    int count = 0;

    if (moduleKey == PermissionModules.dashboard) {
      return modulePermissions.length;
    }

    for (final submodule in _displayedPermissionSubmodules(
      moduleKey: moduleKey,
      isExportImport: isExportImport,
    )) {
      count += (permissionActionsBySubmodule[submodule] ?? standardCrudActions)
          .length;
    }

    return count;
  }

  List<String> _displayedPermissionSubmodules({
    required String moduleKey,
    required bool isExportImport,
  }) {
    final submodules = permissionSubmoduleMap[moduleKey] ?? const <String>[];

    if (!isExportImport) {
      return List<String>.from(submodules);
    }

    return submodules
        .where((submoduleKey) {
          if (moduleKey == PermissionModules.crm) {
            return submoduleKey == CrmSubmodules.customers;
          }
          if (moduleKey == PermissionModules.finance) {
            return [
              FinanceSubmodules.taxInvoice,
              FinanceSubmodules.paymentReceived,
              FinanceSubmodules.outstanding,
              FinanceSubmodules.expenseEntries,
            ].contains(submoduleKey);
          }
          if (moduleKey == PermissionModules.reports) {
            return [
              ReportsSubmodules.salesReport,
              ReportsSubmodules.customerReport,
              ReportsSubmodules.paymentReport,
            ].contains(submoduleKey);
          }
          return false;
        })
        .toList(growable: false);
  }
}
