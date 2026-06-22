part of '../screen_create_invite.dart';

extension _CreateInvitePermissionWidgets on _ScreenCreateInviteState {
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
        data: Theme.of(context).copyWith(
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
                    color: inviteHeadingTextColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                      style: TextStyle(color: inviteMutedTextColor),
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
                      onChanged: (action, value) => onActionChanged(
                        moduleKey,
                        submoduleKey,
                        action,
                        value,
                      ),
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
                  color: inviteHeadingTextColor,
                ),
              ),
            ),
            Text(
              '$selectedCount / $totalCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: inviteMutedTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.entries.map((entry) {
            return PermissionChip(
              label: formatPermissionActionLabel(entry.key),
              value: entry.value,
              onChanged: (value) => onChanged(entry.key, value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
