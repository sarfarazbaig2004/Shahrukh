import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/widgets/action_button.dart';
import 'package:QUIK/modules/administration/users/widgets/mini_badge.dart';

typedef UserDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class UserCard extends StatelessWidget {
  final UserDoc doc;
  final String currentUid;
  final Future<void> Function() onView;
  final Future<void> Function() onEdit;
  final Future<void> Function()? onToggle;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onRestore;
  final Future<void> Function()? onPermanentDelete;

  const UserCard({
    super.key,
    required this.doc,
    required this.currentUid,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.onRestore,
    this.onPermanentDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final displayName = _readDisplayName(data);
    final email = (data['email'] ?? '').toString().trim();
    final phone = (data['phone'] ?? '').toString().trim();
    final role = (data['role'] ?? UserRoles.sales).toString().trim();
    final department = (data['department'] ?? '').toString().trim();
    final designation = (data['designation'] ?? '').toString().trim();

    final isActive = (data['isActive'] ?? true) == true;
    final isDeleted = (data['isDeleted'] ?? false) == true;
    final storedStatus = (data['status'] ?? '').toString().trim();
    final isSelfUser = doc.id == currentUid;

    final currentStatusText = storedStatus.isNotEmpty
        ? statusLabelFromValue(storedStatus)
        : statusLabel(isActive: isActive, isDeleted: isDeleted);

    final currentStatusColor = storedStatus.isNotEmpty
        ? statusColorFromValue(storedStatus)
        : statusColor(isActive: isActive, isDeleted: isDeleted);

    final currentRoleColor = roleColor(role);

    final canToggle = !isSelfUser && !isDeleted && onToggle != null;
    final canDelete = !isSelfUser && !isDeleted && onDelete != null;
    final canRestore = !isSelfUser && isDeleted && onRestore != null;
    final canPermanentDelete =
        !isSelfUser && isDeleted && onPermanentDelete != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(displayName),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserDetails(
                  displayName: displayName,
                  email: email,
                  phone: phone,
                  role: role,
                  department: department,
                  designation: designation,
                  isSelfUser: isSelfUser,
                  currentRoleColor: currentRoleColor,
                  currentStatusText: currentStatusText,
                  currentStatusColor: currentStatusColor,
                  createdAt: formatTimestamp(data['createdAt']),
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: isDeleted ? false : isActive,
                  onChanged: canToggle
                      ? (_) async {
                          await onToggle!.call();
                        }
                      : null,
                  activeThumbColor: primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActionSection(
            isActive: isActive,
            isDeleted: isDeleted,
            isSelfUser: isSelfUser,
            canToggle: canToggle,
            canDelete: canDelete,
            canRestore: canRestore,
            canPermanentDelete: canPermanentDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String displayName) {
    final safeName = displayName.trim().isEmpty ? 'Unnamed User' : displayName;

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Text(
        safeName[0].toUpperCase(),
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildUserDetails({
    required String displayName,
    required String email,
    required String phone,
    required String role,
    required String department,
    required String designation,
    required bool isSelfUser,
    required Color currentRoleColor,
    required String currentStatusText,
    required Color currentStatusColor,
    required String createdAt,
  }) {
    final secondaryLine = email.isNotEmpty
        ? email
        : (designation.isEmpty ? '-' : formatDesignation(designation));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              displayName.isEmpty ? 'Unnamed User' : displayName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primaryColor,
                height: 1.1,
              ),
            ),
            MiniBadge(
              text: formatRole(role),
              textColor: currentRoleColor,
              backgroundColor: currentRoleColor.withValues(alpha: 0.10),
            ),
            MiniBadge(
              text: currentStatusText,
              textColor: currentStatusColor,
              backgroundColor: currentStatusColor.withValues(alpha: 0.10),
            ),
            if (isSelfUser)
              const MiniBadge(
                text: 'YOU',
                textColor: accentColor,
                backgroundColor: Color(0x1A2563EB),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          secondaryLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 4,
          children: [
            _metaText(phone.isEmpty ? 'No phone' : phone),
            _metaDot(),
            _metaText(
              department.isEmpty
                  ? 'No Department'
                  : formatDepartment(department),
            ),
            _metaDot(),
            _metaText('Created $createdAt'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionSection({
    required bool isActive,
    required bool isDeleted,
    required bool isSelfUser,
    required bool canToggle,
    required bool canDelete,
    required bool canRestore,
    required bool canPermanentDelete,
  }) {
    final toggleLabel = isDeleted
        ? 'Deleted'
        : (isActive ? 'Disable' : 'Enable');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionButton(
          icon: Icons.visibility_outlined,
          label: 'View',
          color: primaryColor,
          onTap: () async => onView(),
        ),
        ActionButton(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: accentColor,
          onTap: () async => onEdit(),
        ),
        if (isDeleted) ...[
          ActionButton(
            icon: Icons.restore_outlined,
            label: 'Restore',
            color: successColor,
            onTap: canRestore ? () async => onRestore!() : null,
          ),
          ActionButton(
            icon: Icons.delete_forever_outlined,
            label: 'Permanent Delete',
            color: dangerColor,
            onTap: canPermanentDelete ? () async => onPermanentDelete!() : null,
          ),
        ] else ...[
          ActionButton(
            icon: isActive
                ? Icons.toggle_off_outlined
                : Icons.toggle_on_outlined,
            label: toggleLabel,
            color: warningColor,
            onTap: canToggle ? () async => onToggle!() : null,
          ),
          ActionButton(
            icon: Icons.delete_outline_rounded,
            label: isSelfUser ? 'Protected' : 'Delete',
            color: isSelfUser ? Colors.grey : dangerColor,
            onTap: canDelete ? () async => onDelete!() : null,
          ),
        ],
      ],
    );
  }

  Widget _metaText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: mutedTextColor,
        fontSize: 11.5,
        height: 1.1,
      ),
    );
  }

  Widget _metaDot() {
    return const Text(
      '•',
      style: TextStyle(color: mutedTextColor, fontSize: 11.5, height: 1.1),
    );
  }

  String _readDisplayName(Map<String, dynamic> data) {
    final displayName = (data['displayName'] ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;

    final legacyName = (data['name'] ?? '').toString().trim();
    if (legacyName.isNotEmpty) return legacyName;

    return 'Unnamed User';
  }
}
