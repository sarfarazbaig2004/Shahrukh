import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/auth/register/register_screen_local.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/notifications/screen_notification_center.dart';
import 'package:QUIK/modules/settings/screen_company_profile_bank_settings.dart';
import 'package:QUIK/modules/settings/letterhead_settings_screen.dart';

enum _SettingsSection { personal, workspace, access, system, danger }

class ScreenSettingsHome extends StatefulWidget {
  final String companyId;
  final String companyName;
  final String role;
  final String userEmail;
  final Map<String, dynamic> permissions;
  final String? industry;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenCompanyProfile;
  final VoidCallback? onOpenAuditLogs;

  const ScreenSettingsHome({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.userEmail,
    this.permissions = const {},
    this.industry,
    this.onOpenUsers,
    this.onOpenCompanyProfile,
    this.onOpenAuditLogs,
  });

  @override
  State<ScreenSettingsHome> createState() => _ScreenSettingsHomeState();
}

class _ScreenSettingsHomeState extends State<ScreenSettingsHome> {
  _SettingsSection _activeSection = _SettingsSection.personal;

  bool _isUploadingLogo = false;
  double? _uploadProgress;

  bool get isAdmin => widget.role.toLowerCase() == 'admin';
  bool get isManager => widget.role.toLowerCase() == 'manager';

  bool get isAdminOrManager {
    final r = widget.role.toLowerCase().trim();
    return r == 'admin' ||
        r == 'manager' ||
        r == 'owner' ||
        r == 'founder' ||
        r == 'ceo' ||
        r == 'superadmin' ||
        r == 'software_super_admin' ||
        r == 'company_super_admin';
  }

  bool get isExportImport => widget.industry == 'export_import';

  bool _hasPermission(String key) {
    if (isAdminOrManager) return true;
    return widget.permissions[key] == true;
  }

  bool get canOpenUsers => isAdminOrManager || _hasPermission('userManagement');
  bool get canOpenCompanyProfile =>
      !isExportImport && (isAdminOrManager || _hasPermission('companyProfile'));
  bool get canOpenAuditLogs =>
      !isExportImport && (isAdminOrManager || _hasPermission('auditLogs'));
  bool get canOpenRoles =>
      !isExportImport && (isAdminOrManager || _hasPermission('roles'));

  List<_NavItemData> get _navItems {
    return [
      const _NavItemData(
        section: _SettingsSection.personal,
        title: 'My Account',
        icon: Icons.person_outline,
      ),
      if (!isExportImport && (canOpenCompanyProfile || isAdminOrManager))
        const _NavItemData(
          section: _SettingsSection.workspace,
          title: 'Workspace',
          icon: Icons.apartment_outlined,
        ),
      if (canOpenUsers || canOpenRoles)
        const _NavItemData(
          section: _SettingsSection.access,
          title: 'Users & Access',
          icon: Icons.admin_panel_settings_outlined,
        ),
      if (!isExportImport && (canOpenAuditLogs || isAdminOrManager))
        const _NavItemData(
          section: _SettingsSection.system,
          title: 'System',
          icon: Icons.settings_suggest_outlined,
        ),
      const _NavItemData(
        section: _SettingsSection.danger,
        title: 'Danger Zone',
        icon: Icons.warning_amber_rounded,
      ),
    ];
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.red.shade700 : zSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickAndUploadLogo(String? currentLogoUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('Authentication error. Please log in again.', isError: true);
        return;
      }

      await user.getIdToken(true);

      if (widget.companyId.isEmpty) {
        _showSnack('Invalid Workspace. Missing Company ID.', isError: true);
        return;
      }

      if (!isAdminOrManager) {
        _showSnack(
          'Only Admins or Managers can update the logo.',
          isError: true,
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.size > 2 * 1024 * 1024) {
        _showSnack(
          'Image size exceeds 2MB limit. Please compress it.',
          isError: true,
        );
        return;
      }

      if (file.bytes == null || file.bytes!.isEmpty) {
        _showSnack(
          'Failed to read image data. Please try another file.',
          isError: true,
        );
        return;
      }

      setState(() {
        _isUploadingLogo = true;
        _uploadProgress = 0.0;
      });

      if (currentLogoUrl != null && currentLogoUrl.trim().startsWith('http')) {
        try {
          await FirebaseStorage.instance
              .refFromURL(currentLogoUrl.trim())
              .delete();
        } catch (e) {
          debugPrint('Notice: Failed to delete old logo (might not exist): $e');
        }
      }

      final cleanCompanyId = widget.companyId.trim().replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '',
      );
      final fileExt = file.extension?.toLowerCase() ?? 'png';

      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'logo_$uniqueId.$fileExt';
      final storagePath = 'companies/$cleanCompanyId/branding/$fileName';

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/$fileExt');

      final uploadTask = storageRef.putData(file.bytes!, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .update({
        'companyLogoUrl': downloadUrl,
        'logoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });

      if (mounted) {
        setState(() {
          _isUploadingLogo = false;
          _uploadProgress = null;
        });
        _showSnack('Company logo updated successfully.');
      }
    } on FirebaseException catch (e) {
      if (mounted)
        setState(() {
          _isUploadingLogo = false;
          _uploadProgress = null;
        });
      debugPrint('Firebase Storage Exception: ${e.code} - ${e.message}');
      _showSnack(
        e.code == 'unauthorized'
            ? 'Access Denied: Check Firebase Storage Rules or user permissions.'
            : 'Storage Error: ${e.message}',
        isError: true,
      );
    } catch (e) {
      if (mounted)
        setState(() {
          _isUploadingLogo = false;
          _uploadProgress = null;
        });
      debugPrint('Unknown Upload Error: $e');
      _showSnack('Failed to upload logo: $e', isError: true);
    }
  }

  Future<void> _removeLogo(String currentLogoUrl) async {
    if (!isAdminOrManager) {
      _showSnack('Only Admins or Managers can remove the logo.', isError: true);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Remove Logo?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete the company logo? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await user.getIdToken(true);

      setState(() {
        _isUploadingLogo = true;
        _uploadProgress = null;
      });

      if (currentLogoUrl.trim().startsWith('http')) {
        try {
          await FirebaseStorage.instance
              .refFromURL(currentLogoUrl.trim())
              .delete();
        } catch (e) {
          debugPrint(
            'Notice: Storage delete failed (URL might be invalid): $e',
          );
        }
      }

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .update({
        'companyLogoUrl': FieldValue.delete(),
        'logoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
      });

      if (mounted) {
        setState(() => _isUploadingLogo = false);
        _showSnack('Company logo removed successfully.');
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingLogo = false);
      _showSnack('Failed to remove logo: $e', isError: true);
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
  }

  int _calculateProfileHealth(Map<String, dynamic> data) {
    int score = 0;
    int totalFields = 6;

    if ((data['companyName'] ?? '').toString().isNotEmpty) score++;
    if ((data['companyLogoUrl'] ?? data['logoUrl'] ?? '').toString().isNotEmpty)
      score++;
    if ((data['gstNo'] ?? '').toString().isNotEmpty) score++;
    if ((data['panNo'] ?? '').toString().isNotEmpty) score++;
    if ((data['industry'] ?? '').toString().isNotEmpty) score++;
    if ((data['address'] ?? '').toString().isNotEmpty) score++;

    return ((score / totalFields) * 100).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopSummaryRow(),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 250, child: _buildLeftNav()),
              const SizedBox(width: 10),
              Expanded(child: _buildRightPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Workspace',
            value: widget.companyName,
            icon: Icons.business_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Company ID',
            value: widget.companyId,
            icon: Icons.badge_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Role',
            value: widget.role.toUpperCase(),
            icon: Icons.shield_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Account',
            value: widget.userEmail,
            icon: Icons.person_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildLeftNav() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _navItems.map((item) {
          final selected = _activeSection == item.section;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _activeSection = item.section),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected ? zBlueSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? zBlue.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: selected ? zBlue : zMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: selected ? zBlue : zText,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRightPanel() {
    switch (_activeSection) {
      case _SettingsSection.personal:
        return _buildPersonalSection();
      case _SettingsSection.workspace:
        return _buildWorkspaceSection();
      case _SettingsSection.access:
        return _buildAccessSection();
      case _SettingsSection.system:
        return _buildSystemSection();
      case _SettingsSection.danger:
        return _buildDangerSection();
    }
  }

  Widget _buildPersonalSection() {
    return _SectionPanel(
      title: 'My Account',
      subtitle: 'Personal profile, password, and account preferences.',
      children: [
        _ActionTile(
          title: 'My Profile',
          subtitle:
          'View and update the same company and registration details already saved in your workspace.',
          icon: Icons.person_outline,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreenLocal()),
            );

            if (!mounted) return;
            _showSnack(
              'Profile screen closed. Any saved changes are now updated.',
              isError: false,
            );
          },
        ),
        _ActionTile(
          title: 'Change Password',
          subtitle: 'Securely update your login password.',
          icon: Icons.lock_reset_outlined,
          onTap: () => _showChangePasswordDialog(context),
        ),
        _ActionTile(
          title: 'Notification Center',
          subtitle:
          'View alerts, reminders, task updates, and meeting invitations.',
          icon: Icons.notifications_active_outlined,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ScreenNotificationCenter(companyId: widget.companyId),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWorkspaceSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: zBlue));
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        final String? rawLogoUrl =
            data['companyLogoUrl'] as String? ?? data['logoUrl'] as String?;
        final String? logoUrl =
        (rawLogoUrl != null && rawLogoUrl.trim().isNotEmpty)
            ? rawLogoUrl.trim()
            : null;

        final createdAt = data['createdAt'] as Timestamp?;
        final updatedAt = data['updatedAt'] as Timestamp?;
        final health = _calculateProfileHealth(data);

        return _SectionPanel(
          title: 'Workspace Overview',
          subtitle:
          'Company-level settings, identity, and workspace information.',
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: zBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔥 FIX: Clean URL Network Image
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              color: zCanvasBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: zBorder, width: 2),
                            ),
                            child: logoUrl != null
                                ? Image.network(
                              logoUrl, // ❌ NO Cache Buster Strings
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.business_outlined,
                                  size: 40,
                                  color: zMuted,
                                );
                              },
                            )
                                : const Icon(
                              Icons.business_outlined,
                              size: 40,
                              color: zMuted,
                            ),
                          ),
                          if (_isUploadingLogo)
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: _uploadProgress,
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 20),

                      // Company Info & Actions
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['companyName'] ?? widget.companyName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: zText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _StatusBadge(
                                  text:
                                  data['industry']
                                      ?.toString()
                                      .toUpperCase() ??
                                      'INDUSTRY NOT SET',
                                  color: zPurple,
                                  bgColor: zPurpleSoft,
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(
                                  text: 'ID: ${widget.companyId}',
                                  color: zMuted,
                                  bgColor: zCanvasBg,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (canOpenCompanyProfile) ...[
                                  ElevatedButton.icon(
                                    onPressed: _isUploadingLogo
                                        ? null
                                        : () => _pickAndUploadLogo(logoUrl),
                                    icon: const Icon(
                                      Icons.upload_file,
                                      size: 16,
                                    ),
                                    label: Text(
                                      logoUrl != null
                                          ? 'Change Logo'
                                          : 'Upload Logo',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: zBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (logoUrl != null)
                                    OutlinedButton.icon(
                                      onPressed: _isUploadingLogo
                                          ? null
                                          : () => _removeLogo(logoUrl),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                      ),
                                      label: const Text('Remove'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: BorderSide(
                                          color: Colors.red.shade200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Timestamps
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Created: ${_formatDate(createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: zMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last Updated: ${_formatDate(updatedAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: zMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: zBorder, height: 1),
                  ),

                  // Profile Completion Health Bar
                  Row(
                    children: [
                      const Icon(
                        Icons.health_and_safety_outlined,
                        size: 18,
                        color: zSuccess,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Profile Completion',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: zText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: health / 100,
                            minHeight: 8,
                            backgroundColor: zCanvasBg,
                            color: health == 100 ? zSuccess : zOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$health%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: health == 100 ? zSuccess : zOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Standard Action Tiles
            if (canOpenCompanyProfile)
              _ActionTile(
                title: 'Company Profile & Banking',
                subtitle:
                'Manage company identity, GST, PAN, address, billing information, and multiple bank accounts.',
                icon: Icons.apartment_outlined,
                enabled: canOpenCompanyProfile,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScreenCompanyProfileBankSettings(
                        companyId: widget.companyId,
                      ),
                    ),
                  );
                },
              ),
            if (!isExportImport) ...[
              _ActionTile(
                title: 'Branches & Locations',
                subtitle:
                'Manage branch structure, warehouses, and branch-level setup.',
                icon: Icons.account_tree_outlined,
                enabled: isAdminOrManager,
                onTap: () => _showComingSoon('Branches'),
              ),
              _ActionTile(
                title: 'Letter Head Layout',
                subtitle:
                'Configure the Letter Head layout, printable area, margins, and upload the company letterhead.',
                icon: Icons.dashboard_customize_outlined,
                enabled: isAdminOrManager,
                onTap: isAdminOrManager
                    ? () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LetterheadSettingsScreen(
                        companyId: widget.companyId,
                        currentUserUid:
                        FirebaseAuth.instance.currentUser?.uid ?? '',
                        currentUserName: widget.userEmail,
                      ),
                    ),
                  );
                }
                    : null,
              ),
              _ActionTile(
                title: 'Document Numbering',
                subtitle:
                'Control quotation, invoice, and sales order numbering formats.',
                icon: Icons.numbers_outlined,
                enabled: isAdminOrManager,
                onTap: () => _showComingSoon('Document Numbering'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAccessSection() {
    return _SectionPanel(
      title: 'Users & Access',
      subtitle: 'User management, permissions, and access control.',
      children: [
        if (canOpenUsers)
          _ActionTile(
            title: 'Users',
            subtitle: 'Manage active users, invitations, and team access.',
            icon: Icons.manage_accounts_outlined,
            onTap: widget.onOpenUsers,
          ),
        if (canOpenRoles)
          _ActionTile(
            title: 'Roles & Permissions',
            subtitle: 'Define role rights and module permissions.',
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => _showComingSoon('Roles & Permissions'),
          ),
        if (!isExportImport)
          _ActionTile(
            title: 'Access Scope',
            subtitle: 'Control future branch, department, and scope access.',
            icon: Icons.lock_open_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Access Scope'),
          ),
      ],
    );
  }

  Widget _buildSystemSection() {
    return _SectionPanel(
      title: 'System',
      subtitle: 'Logs, integrations, and workspace-level system controls.',
      children: [
        if (canOpenAuditLogs)
          _ActionTile(
            title: 'Audit Logs',
            subtitle: 'Review important actions and change history.',
            icon: Icons.fact_check_outlined,
            enabled: canOpenAuditLogs,
            onTap: widget.onOpenAuditLogs,
          ),
        if (!isExportImport) ...[
          _ActionTile(
            title: 'Integrations',
            subtitle: 'Connect external systems and future APIs.',
            icon: Icons.hub_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Integrations'),
          ),
          _ActionTile(
            title: 'Security Policies',
            subtitle:
            'Future controls for session rules and account protection.',
            icon: Icons.security_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Security Policies'),
          ),
        ],
      ],
    );
  }

  Widget _buildDangerSection() {
    return _SectionPanel(
      title: 'Danger Zone',
      subtitle: 'Sensitive account actions. Use with caution.',
      children: [
        _ActionTile(
          title: 'Delete Account',
          subtitle:
          'Permanently delete your login and remove your root user profile.',
          icon: Icons.delete_forever_outlined,
          isDanger: true,
          onTap: () => _showDeleteDialog(context),
        ),
      ],
    );
  }

  void _showComingSoon(String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: zBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_outlined, color: zBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: const Text(
          'This enterprise setting is planned for the next configuration upgrade. Current live modules will continue to work normally.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              final currentPassword = currentPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                setLocalState(() {
                  errorText = 'All fields are required.';
                });
                return;
              }

              if (newPassword.length < 6) {
                setLocalState(() {
                  errorText = 'New password must be at least 6 characters.';
                });
                return;
              }

              if (newPassword != confirmPassword) {
                setLocalState(() {
                  errorText = 'New password and confirm password do not match.';
                });
                return;
              }

              try {
                setLocalState(() {
                  saving = true;
                  errorText = null;
                });

                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) {
                  throw FirebaseAuthException(
                    code: 'user-not-found',
                    message: 'No authenticated user found.',
                  );
                }

                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassword,
                );

                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassword);

                if (!mounted) return;
                Navigator.of(dialogContext).pop();

                _showSnack('Password updated successfully.');
              } on FirebaseAuthException catch (e) {
                setLocalState(() {
                  saving = false;
                  errorText = _friendlyAuthError(e);
                });
              } catch (e) {
                setLocalState(() {
                  saving = false;
                  errorText = 'Failed to update password: $e';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final passwordController = TextEditingController();

    bool deleting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: !deleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submitDelete() async {
              final password = passwordController.text.trim();

              if (password.isEmpty) {
                setLocalState(() {
                  errorText = 'Password is required.';
                });
                return;
              }

              try {
                setLocalState(() {
                  deleting = true;
                  errorText = null;
                });

                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) {
                  throw FirebaseAuthException(
                    code: 'user-not-found',
                    message: 'No authenticated user found.',
                  );
                }

                final uid = user.uid;

                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: password,
                );

                await user.reauthenticateWithCredential(credential);

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .delete()
                    .catchError((_) {});

                await user.delete();

                if (!mounted) return;
                Navigator.of(dialogContext).pop();

                _showSnack('Account deleted successfully.');
              } on FirebaseAuthException catch (e) {
                setLocalState(() {
                  deleting = false;
                  errorText = _friendlyAuthError(e);
                });
              } catch (e) {
                setLocalState(() {
                  deleting = false;
                  errorText = 'Failed to delete account: $e';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter your password to permanently delete this account.',
                        style: TextStyle(
                          color: zMuted,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: deleting ? null : submitDelete,
                  child: deleting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'The password you entered is incorrect.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'requires-recent-login':
        return 'Please log in again and retry this action.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;

  const _StatusBadge({
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _NavItemData {
  final _SettingsSection section;
  final String title;
  final IconData icon;

  const _NavItemData({
    required this.section,
    required this.title,
    required this.icon,
  });
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: zMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => children[index],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isDanger;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDanger ? Colors.red : zBlue;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: isDanger ? Colors.red.shade100 : zBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDanger ? const Color(0xFFFFF1F2) : zBlueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Opacity(
                opacity: enabled ? 1 : 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDanger ? Colors.red : zText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: zMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline,
              size: 16,
              color: enabled ? accent : zMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              Icon(icon, size: 16, color: zMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: zText,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}