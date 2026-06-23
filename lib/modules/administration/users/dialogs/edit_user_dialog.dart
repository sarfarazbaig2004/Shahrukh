// FILE PATH: lib/modules/administration/users/dialogs/edit_user_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/widgets/mini_badge.dart';

typedef UserDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

const Color _editPrimaryColor = Color(0xFF17324D);
const Color _editAccentColor = Color(0xFF3B82F6);
const Color _editScaffoldBgColor = Color(0xFFF4F7FB);
const Color _editCardBorderColor = Color(0xFFE2E8F0);
const Color _editMutedTextColor = Color(0xFF64748B);
const Color _editHeadingTextColor = Color(0xFF0F172A);

Future<void> showEditUserDialog({
  required BuildContext context,
  required UserDoc doc,
  required String companyId,
  required String currentUid,
  String? industry,
  required Future<void> Function({
    required String companyId,
    required String userUid,
    required String role,
    required bool isActive,
    required Map<String, dynamic> permissions,
    String? department,
    String? designation,
    String? branchName,
    String? accessScope,
  })
  onSaveUser,
}) async {
  final data = doc.data();
  final bool isExportImport = industry == 'export_import';

  String selectedRole = _normalizeRoleValue(
    (data['role'] ?? UserRoles.sales).toString(),
  );
  bool isActive = (data['isActive'] ?? true) == true;
  final bool isDeleted = (data['isDeleted'] ?? false) == true;
  final bool isSelfUser = doc.id == currentUid;
  bool isSaving = false;

  final List<String> departmentOptions = const [
    'Sales',
    'CRM',
    'Inventory',
    'Purchase',
    'Dispatch',
    'Finance',
    'Administration',
    'Management',
    'Service',
  ];

  final Map<String, List<String>> designationOptionsByDepartment = const {
    'Sales': [
      'Sales Executive',
      'Senior Sales Executive',
      'Area Sales Manager',
      'Regional Sales Manager',
      'Vice President - Business Development',
    ],
    'CRM': [
      'CRM Executive',
      'CRM Coordinator',
      'Customer Relationship Manager',
    ],
    'Inventory': [
      'Store Executive',
      'Inventory Executive',
      'Warehouse Executive',
      'Inventory Manager',
    ],
    'Purchase': [
      'Purchase Executive',
      'Senior Purchase Executive',
      'Procurement Manager',
    ],
    'Dispatch': [
      'Dispatch Executive',
      'Logistics Coordinator',
      'Dispatch Manager',
    ],
    'Finance': ['Accounts Executive', 'Senior Accountant', 'Finance Manager'],
    'Administration': [
      'Admin Executive',
      'Office Administrator',
      'HR Executive',
      'Admin Manager',
    ],
    'Management': [
      'General Manager',
      'Business Head',
      'Vice President',
      'Director',
    ],
    'Service': [
      'Service Engineer',
      'Service Technician',
      'Service Coordinator',
      'Service Manager',
    ],
  };

  String selectedDepartment = _normalizeDepartmentForDropdown(
    (data['department'] ?? '').toString().trim(),
    departmentOptions,
  );

  List<String> designationOptions =
      designationOptionsByDepartment[selectedDepartment] ?? const <String>[];

  String selectedDesignation = _normalizeDesignationForDropdown(
    designation: (data['designation'] ?? '').toString().trim(),
    allowedOptions: designationOptions,
  );

  String selectedAccessScope = _normalizeAccessScopeValue(
    (data['accessScope'] ?? AccessScope.company).toString(),
  );

  Map<String, dynamic> permissions = _buildUiPermissionState(
    role: selectedRole,
    isExportImport: isExportImport,
    permissions: Map<String, dynamic>.from(
      data['permissions'] ?? const <String, dynamic>{},
    ),
  );

  final List<String> activeModules = isExportImport
      ? ['dashboard', 'crm', 'finance', 'reports']
      : permissionModuleOrder;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> saveUser() async {
            if (isSaving) return;

            setLocalState(() {
              isSaving = true;
            });

            try {
              await onSaveUser(
                companyId: companyId,
                userUid: doc.id,
                role: selectedRole,
                isActive: isDeleted ? false : isActive,
                permissions: permissions,
                department: selectedDepartment.trim(),
                designation: selectedDesignation.trim(),
                accessScope: selectedAccessScope.trim(),
              );

              if (!context.mounted) return;

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User updated successfully'),
                  backgroundColor: successColor,
                ),
              );
            } catch (e) {
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_friendlySaveError(e)),
                  backgroundColor: dangerColor,
                ),
              );
            } finally {
              if (context.mounted) {
                setLocalState(() {
                  isSaving = false;
                });
              }
            }
          }

          final visiblePermissions = _buildUiPermissionState(
            role: selectedRole,
            isExportImport: isExportImport,
            permissions: permissions,
          );

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 900),
              decoration: BoxDecoration(
                color: _editScaffoldBgColor,
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
                                      'Administration • Users • Edit User',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _editMutedTextColor,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Update employee role, department, designation, status, and module permissions.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _editMutedTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Close'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _editHeadingTextColor,
                                  side: const BorderSide(
                                    color: _editCardBorderColor,
                                  ),
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
                          _buildHeaderCard(data),
                          if (isDeleted) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              child: const Text(
                                'This user is deleted. You can review and update settings, but the account remains inactive until restored from user actions.',
                                style: TextStyle(
                                  color: Color(0xFF9A3412),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
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
                              title: 'Basic Access Details',
                              subtitle:
                                  'Update the employee role and structured organizational assignment.',
                              child: Column(
                                children: [
                                  _buildDesktopTwoColumn(
                                    left: _buildDropdownField(
                                      label: 'Role',
                                      value: selectedRole,
                                      options: userRolesList,
                                      icon: Icons.admin_panel_settings_outlined,
                                      labelBuilder: formatRole,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedRole = _normalizeRoleValue(
                                            value,
                                          );
                                          permissions = _buildUiPermissionState(
                                            role: selectedRole,
                                            isExportImport: isExportImport,
                                            permissions: permissions,
                                          );
                                        });
                                      },
                                    ),
                                    right: _buildDropdownField(
                                      label: 'Department',
                                      value: selectedDepartment,
                                      options: departmentOptions,
                                      icon: Icons.apartment_outlined,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedDepartment = value;
                                          designationOptions =
                                              designationOptionsByDepartment[selectedDepartment] ??
                                              const <String>[];
                                          selectedDesignation =
                                              designationOptions.isNotEmpty
                                              ? designationOptions.first
                                              : '';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDesktopTwoColumn(
                                    left: _buildDropdownField(
                                      label: 'Designation',
                                      value: selectedDesignation,
                                      options: designationOptions,
                                      icon: Icons.badge_outlined,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedDesignation = value;
                                        });
                                      },
                                    ),
                                    right: _buildDropdownField(
                                      label: 'Access Scope',
                                      value: selectedAccessScope,
                                      options: accessScopeList,
                                      icon: Icons.lock_open_outlined,
                                      labelBuilder: (value) =>
                                          accessScopeLabels[value] ?? value,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedAccessScope =
                                              _normalizeAccessScopeValue(value);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              title: 'Account Status',
                              subtitle:
                                  'Control whether the employee can use the ERP actively.',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _editCardBorderColor,
                                  ),
                                ),
                                child: SwitchListTile.adaptive(
                                  value: isDeleted ? false : isActive,
                                  onChanged:
                                      (isSelfUser || isDeleted || isSaving)
                                      ? null
                                      : (value) {
                                          setLocalState(() {
                                            isActive = value;
                                          });
                                        },
                                  title: const Text(
                                    'Active User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _editHeadingTextColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isDeleted
                                        ? 'Deleted users cannot be activated from this dialog.'
                                        : isSelfUser
                                        ? 'You cannot deactivate your own account from here.'
                                        : 'Disable this user if you want to restrict login and usage.',
                                    style: const TextStyle(
                                      color: _editMutedTextColor,
                                    ),
                                  ),
                                  activeThumbColor: _editAccentColor,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              title: 'Permission Summary',
                              subtitle:
                                  'Review role mapping, department, designation, and selected permissions.',
                              child: _buildEditSummary(
                                selectedRole: selectedRole,
                                selectedDepartment: selectedDepartment,
                                selectedDesignation: selectedDesignation,
                                selectedAccessScope: selectedAccessScope,
                                selectedPermissionsCount:
                                    _selectedPermissionCount(
                                      visiblePermissions,
                                      activeModules,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              title: 'Module Permissions',
                              subtitle:
                                  'Permissions are aligned with QUIK ERP modules, submodules, and actions.',
                              trailing: TextButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setLocalState(() {
                                          permissions = _buildUiPermissionState(
                                            role: selectedRole,
                                            isExportImport: isExportImport,
                                            permissions:
                                                _getIndustryDefaultPermissions(
                                                  role: selectedRole,
                                                  isExportImport:
                                                      isExportImport,
                                                ),
                                          );
                                        });
                                      },
                                child: const Text('Apply Role Defaults'),
                              ),
                              child: Column(
                                children: activeModules.map((moduleKey) {
                                  return _buildPermissionModuleCard(
                                    moduleKey: moduleKey,
                                    isExportImport: isExportImport,
                                    modulePermissions: _readModulePermissions(
                                      visiblePermissions,
                                      moduleKey,
                                    ),
                                    onActionChanged:
                                        (
                                          String module,
                                          String? submodule,
                                          String action,
                                          bool value,
                                        ) {
                                          setLocalState(() {
                                            permissions = _setPermissionValue(
                                              permissions: permissions,
                                              moduleKey: module,
                                              submoduleKey: submodule,
                                              action: action,
                                              value: value,
                                            );
                                          });
                                        },
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: _editCardBorderColor),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D0F172A),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 700) {
                                    return Column(
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: isSaving
                                                ? null
                                                : () => Navigator.pop(context),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  _editHeadingTextColor,
                                              side: const BorderSide(
                                                color: _editCardBorderColor,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: isSaving
                                                ? null
                                                : saveUser,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _editPrimaryColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: isSaving
                                                ? const SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  )
                                                : const Text(
                                                    'Save Changes',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: isSaving
                                            ? null
                                            : () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              _editHeadingTextColor,
                                          side: const BorderSide(
                                            color: _editCardBorderColor,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: isSaving ? null : saveUser,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _editPrimaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: isSaving
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ],
                                  );
                                },
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
    },
  );
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

Widget _buildHeaderCard(Map<String, dynamic> data) {
  final name = _readDisplayName(data);
  final email = (data['email'] ?? '').toString().trim();
  final phone = (data['phone'] ?? '').toString().trim();
  final role = _normalizeRoleValue(
    (data['role'] ?? UserRoles.sales).toString(),
  );
  final department = (data['department'] ?? '').toString().trim();
  final designation = (data['designation'] ?? '').toString().trim();

  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _editCardBorderColor),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: _editPrimaryColor.withValues(alpha: 0.10),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _editPrimaryColor,
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
                  color: _editHeadingTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email.isEmpty ? '-' : email,
                style: const TextStyle(color: _editMutedTextColor),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(phone, style: const TextStyle(color: _editMutedTextColor)),
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
                      textColor: _editAccentColor,
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
  Widget? trailing,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _editCardBorderColor),
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _editHeadingTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _editMutedTextColor,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

Widget _buildDesktopTwoColumn({required Widget left, required Widget right}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 860) {
        return Column(children: [left, const SizedBox(height: 16), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    },
  );
}

Widget _buildDropdownField({
  required String label,
  required String value,
  required List<String> options,
  required void Function(String?) onChanged,
  IconData? icon,
  String Function(String)? labelBuilder,
}) {
  return DropdownButtonFormField<String>(
    initialValue: options.contains(value) ? value : null,
    decoration: _inputDecoration(label: label, icon: icon),
    items: options
        .map(
          (e) => DropdownMenuItem<String>(
            value: e,
            child: Text(labelBuilder != null ? labelBuilder(e) : e),
          ),
        )
        .toList(),
    onChanged: options.isEmpty ? null : onChanged,
  );
}

InputDecoration _inputDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, color: _editMutedTextColor),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _editCardBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _editCardBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _editAccentColor, width: 1.3),
    ),
    labelStyle: const TextStyle(color: _editMutedTextColor),
  );
}

Widget _buildEditSummary({
  required String selectedRole,
  required String selectedDepartment,
  required String selectedDesignation,
  required String selectedAccessScope,
  required int selectedPermissionsCount,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_user_outlined, color: _editPrimaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _editHeadingTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Role: ${formatRole(selectedRole)} • Department: $selectedDepartment',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Designation: ${selectedDesignation.isEmpty ? 'Not Assigned' : selectedDesignation}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Access Scope: ${accessScopeLabels[selectedAccessScope] ?? selectedAccessScope}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selected permissions: $selectedPermissionsCount',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildPermissionModuleCard({
  required String moduleKey,
  required bool isExportImport,
  required Map<String, dynamic> modulePermissions,
  required void Function(
    String moduleKey,
    String? submoduleKey,
    String action,
    bool value,
  )
  onActionChanged,
}) {
  final moduleLabel = formatModuleLabel(moduleKey);
  final selectedCount = _countEnabledActionsInModule(
    moduleKey: moduleKey,
    isExportImport: isExportImport,
    modulePermissions: modulePermissions,
  );
  final totalCount = _countTotalActionsInModule(
    moduleKey: moduleKey,
    isExportImport: isExportImport,
    modulePermissions: modulePermissions,
  );
  final displayedSubmodules = _displayedPermissionSubmodules(
    moduleKey: moduleKey,
    isExportImport: isExportImport,
  );

  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Theme(
      data: ThemeData().copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          children: [
            Expanded(
              child: Text(
                moduleLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _editHeadingTextColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selectedCount == 0
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$selectedCount / $totalCount selected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selectedCount == 0
                      ? const Color(0xFF475569)
                      : const Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
        children: moduleKey == PermissionModules.dashboard
            ? [
                _buildActionGroup(
                  title: 'Dashboard',
                  actions: Map<String, bool>.from(modulePermissions),
                  onChanged: (action, value) =>
                      onActionChanged(moduleKey, null, action, value),
                ),
              ]
            : displayedSubmodules.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No submodules are configured for this module.',
                    style: TextStyle(color: _editMutedTextColor),
                  ),
                ),
              ]
            : displayedSubmodules.map((submoduleKey) {
                final storedSubmodulePermissions =
                    modulePermissions[submoduleKey] is Map
                    ? Map<String, dynamic>.from(
                        modulePermissions[submoduleKey] as Map,
                      )
                    : const <String, dynamic>{};
                final submodulePermissions = <String, bool>{
                  for (final action
                      in permissionActionsBySubmodule[submoduleKey] ??
                          standardCrudActions)
                    action: storedSubmodulePermissions[action] == true,
                };
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _buildActionGroup(
                    title: formatSubmoduleLabel(submoduleKey),
                    actions: submodulePermissions,
                    onChanged: (action, value) =>
                        onActionChanged(moduleKey, submoduleKey, action, value),
                  ),
                );
              }).toList(),
      ),
    ),
  );
}

Widget _buildActionGroup({
  required String title,
  required Map<String, bool> actions,
  required void Function(String action, bool value) onChanged,
}) {
  final selectedCount = actions.values.where((e) => e).length;
  final totalCount = actions.length;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _editHeadingTextColor,
              ),
            ),
          ),
          Text(
            '$selectedCount / $totalCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _editMutedTextColor,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions.entries.map((entry) {
          return _PermissionChip(
            label: formatPermissionActionLabel(entry.key),
            value: entry.value,
            onChanged: (value) => onChanged(entry.key, value),
          );
        }).toList(),
      ),
    ],
  );
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
  Map<String, dynamic> permissions,
  String moduleKey,
) {
  final moduleValue = permissions[moduleKey];

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
  required Map<String, dynamic> permissions,
  required String moduleKey,
  required String? submoduleKey,
  required String action,
  required bool value,
}) {
  final updated = _deepCopyPermissions(permissions);

  if (submoduleKey == null || submoduleKey.isEmpty) {
    final moduleActions = Map<String, dynamic>.from(updated[moduleKey] ?? {});
    moduleActions[action] = value;
    updated[moduleKey] = moduleActions;
    return updated;
  }

  final moduleMap = Map<String, dynamic>.from(updated[moduleKey] ?? {});
  final submoduleMap = Map<String, dynamic>.from(moduleMap[submoduleKey] ?? {});
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

int _selectedPermissionCount(
  Map<String, dynamic> permissions,
  List<String> activeModules,
) {
  int count = 0;

  for (final moduleKey in activeModules) {
    final moduleValue = permissions[moduleKey];

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
    count +=
        (permissionActionsBySubmodule[submodule] ?? standardCrudActions).length;
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

String _friendlySaveError(Object error) {
  final message = error.toString().trim();
  if (message.isEmpty) {
    return 'Failed to update user.';
  }

  if (message.startsWith('Exception: ')) {
    return message.replaceFirst('Exception: ', '');
  }

  return message;
}

String _readDisplayName(Map<String, dynamic> data) {
  final displayName = (data['displayName'] ?? '').toString().trim();
  if (displayName.isNotEmpty) return displayName;

  final legacyName = (data['name'] ?? '').toString().trim();
  if (legacyName.isNotEmpty) return legacyName;

  return 'Unnamed User';
}

String _normalizeDepartmentForDropdown(
  String rawDepartment,
  List<String> departmentOptions,
) {
  final trimmed = rawDepartment.trim();
  if (trimmed.isEmpty) return 'Sales';

  for (final option in departmentOptions) {
    if (option.toLowerCase() == trimmed.toLowerCase()) {
      return option;
    }
  }

  return 'Sales';
}

String _normalizeDesignationForDropdown({
  required String designation,
  required List<String> allowedOptions,
}) {
  final trimmed = designation.trim();
  if (allowedOptions.isEmpty) return '';

  if (trimmed.isEmpty) return allowedOptions.first;

  for (final option in allowedOptions) {
    if (option.toLowerCase() == trimmed.toLowerCase()) {
      return option;
    }
  }

  return allowedOptions.first;
}

String _normalizeRoleValue(String role) {
  final normalized = role.trim().toLowerCase();
  if (userRolesList.contains(normalized)) {
    return normalized;
  }
  return UserRoles.sales;
}

String _normalizeAccessScopeValue(String accessScope) {
  final normalized = accessScope.trim().toLowerCase();
  if (accessScopeList.contains(normalized)) {
    return normalized;
  }
  return AccessScope.company;
}

class _PermissionChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFE0ECFF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? _editAccentColor : const Color(0xFFD6DEE8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18,
              color: value ? _editAccentColor : _editMutedTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value ? const Color(0xFF1E3A8A) : _editHeadingTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
