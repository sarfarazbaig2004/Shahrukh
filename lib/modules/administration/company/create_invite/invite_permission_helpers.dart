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

    if (payload['purchase'] is Map) {
      final purchase = payload['purchase'] as Map<String, dynamic>;

      if (purchase.containsKey('purchaseOrder') &&
          !purchase.containsKey('purchaseOrders')) {
        purchase['purchaseOrders'] = purchase['purchaseOrder'];
      } else if (purchase.containsKey('purchaseOrders') &&
          !purchase.containsKey('purchaseOrder')) {
        purchase['purchaseOrder'] = purchase['purchaseOrders'];
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
    required Map<String, dynamic> modulePermissions,
  }) {
    int count = 0;

    if (moduleKey == PermissionModules.dashboard) {
      for (final value in modulePermissions.values) {
        if (value == true) count++;
      }
      return count;
    }

    for (final submoduleValue in modulePermissions.values) {
      if (submoduleValue is Map) {
        for (final actionValue in submoduleValue.values) {
          if (actionValue == true) count++;
        }
      }
    }

    return count;
  }

  int _countTotalActionsInModule({
    required String moduleKey,
    required Map<String, dynamic> modulePermissions,
  }) {
    int count = 0;

    if (moduleKey == PermissionModules.dashboard) {
      return modulePermissions.length;
    }

    for (final submoduleValue in modulePermissions.values) {
      if (submoduleValue is Map) {
        count += submoduleValue.length;
      }
    }

    return count;
  }
}
