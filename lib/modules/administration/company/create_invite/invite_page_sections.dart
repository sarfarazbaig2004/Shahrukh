part of '../screen_create_invite.dart';

extension _CreateInvitePageSections on _ScreenCreateInviteState {
  static const Set<String> _blockedInviteRoleKeys = {
    'owner',
    'founder',
    'ceo',
    'superadmin',
  };

  List<String> get _allowedInviteRoles => userRolesList.where((role) {
        final normalizedRole = role
            .toLowerCase()
            .replaceAll('_', '')
            .replaceAll('-', '')
            .replaceAll(' ', '');
        return !_blockedInviteRoleKeys.contains(normalizedRole);
      }).toList(growable: false);

  String get _safeSelectedRole {
    if (_allowedInviteRoles.contains(selectedRole)) {
      return selectedRole;
    }
    return UserRoles.sales;
  }

  Widget _buildPageHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Administration • Users • Invite User',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: inviteMutedTextColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Invite a new employee with structured access and module-based permissions.',
                style: TextStyle(fontSize: 14, color: inviteMutedTextColor),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
          style: _outlinedButtonStyle(
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicDetailsSection() {
    return InviteSectionCard(
      title: 'Basic Details',
      subtitle: 'Enter employee identity details for the invitation.',
      child: Column(
        children: [
          _buildDesktopTwoColumn(
            left: InviteTextField(
              controller: nameController,
              label: 'Employee Name',
              hint: 'Enter full name',
              icon: Icons.person_outline_rounded,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Employee name is required';
                }
                return null;
              },
            ),
            right: InviteTextField(
              controller: emailController,
              label: 'Email Address',
              hint: 'Enter business email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
          ),
          const SizedBox(height: 16),
          _buildDesktopTwoColumn(
            left: InviteTextField(
              controller: phoneController,
              label: 'Phone Number',
              hint: 'Enter phone number',
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
            ),
            right: const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentRoleSection() {
    return InviteSectionCard(
      title: 'Department & Role',
      subtitle:
          'Assign the employee to a department and choose the access role.',
      trailing: TextButton(
        onPressed: isLoading ? null : () => _applyRoleDefaults(selectedRole),
        child: const Text('Apply Role Defaults'),
      ),
      child: Column(
        children: [
          _buildDesktopTwoColumn(
            left: InviteDropdownField(
              label: 'Role',
              value: _safeSelectedRole,
              options: _allowedInviteRoles,
              icon: Icons.admin_panel_settings_outlined,
              labelBuilder: formatRole,
              onChanged: (value) {
                final nextRole = value ?? UserRoles.sales;
                selectedRole = nextRole;
                _applyRoleDefaults(nextRole);
              },
            ),
            right: InviteDropdownField(
              label: 'Department',
              value: selectedDepartment,
              options: inviteDepartmentOptions,
              icon: Icons.apartment_outlined,
              onChanged: (value) {
                final department = value ?? 'Sales';
                _onDepartmentChanged(department);
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildDesktopTwoColumn(
            left: InviteDropdownField(
              label: 'Designation',
              value: selectedDesignation,
              options: _designationOptionsForSelectedDepartment,
              icon: Icons.badge_outlined,
              onChanged: (value) {
                _onDesignationChanged(value ?? '');
              },
            ),
            right: InviteDropdownField(
              label: 'Access Scope',
              value: selectedAccessScope,
              options: accessScopeList,
              icon: Icons.lock_open_outlined,
              labelBuilder: (value) => accessScopeLabels[value] ?? value,
              onChanged: (value) {
                _onAccessScopeChanged(value ?? AccessScope.company);
              },
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: sendInviteNow,
            onChanged: (value) {
              _onSendInviteNowChanged(value);
            },
            title: const Text(
              'Send Invite Now',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: inviteHeadingTextColor,
              ),
            ),
            subtitle: const Text(
              'Keep this enabled to create a ready-to-share invite immediately.',
              style: TextStyle(color: inviteMutedTextColor),
            ),
            activeThumbColor: inviteAccentColor,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          InviteSummaryCard(
            selectedRole: selectedRole,
            selectedDepartment: selectedDepartment,
            selectedDesignation: selectedDesignation,
            selectedAccessScope: selectedAccessScope,
            selectedPermissionCount: _selectedPermissionCount(
              permissions,
              activeModules,
            ),
            sendInviteNow: sendInviteNow,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return InviteSectionCard(
      title: 'Module Permissions',
      subtitle:
          'Permissions are aligned with your QUIK ERP modules and submodules.',
      child: Column(
        children: activeModules.map((moduleKey) {
          return _buildPermissionModuleCard(
            moduleKey: moduleKey,
            isExportImport: isExportImport,
            modulePermissions: _readModulePermissions(permissions, moduleKey),
            onActionChanged:
                (String module, String? submodule, String action, bool value) {
                  _onPermissionValueChanged(
                    moduleKey: module,
                    submoduleKey: submodule,
                    action: action,
                    value: value,
                  );
                },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: inviteCardBorderColor),
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
                SizedBox(width: double.infinity, child: _buildCancelButton()),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: _buildCreateButton()),
              ],
            );
          }

          return Row(
            children: [
              _buildCancelButton(),
              const Spacer(),
              _buildCreateButton(),
            ],
          );
        },
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

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email is required';

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';

    return null;
  }
}
