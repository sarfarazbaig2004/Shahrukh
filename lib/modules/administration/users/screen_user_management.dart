// FILE PATH: lib/modules/administration/users/screen_user_management.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/company/screen_create_invite.dart';
import 'package:QUIK/modules/administration/users/dialogs/edit_user_dialog.dart';
import 'package:QUIK/modules/administration/users/dialogs/view_user_dialog.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_filters.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/services/user_management_service.dart';
import 'package:QUIK/modules/administration/users/widgets/desktop_user_table.dart';
import 'package:QUIK/modules/administration/users/widgets/filter_dropdown.dart';
import 'package:QUIK/modules/administration/users/widgets/invite_card.dart';
import 'package:QUIK/modules/administration/users/widgets/user_card.dart';

class ScreenUserManagement extends StatefulWidget {
  final String companyId;
  final String currentUid;

  const ScreenUserManagement({
    super.key,
    required this.companyId,
    required this.currentUid,
  });

  @override
  State<ScreenUserManagement> createState() => _ScreenUserManagementState();
}

class _ScreenUserManagementState extends State<ScreenUserManagement> {
  final TextEditingController _searchController = TextEditingController();
  final UserManagementService _userManagementService = UserManagementService();

  UserFilterState _filterState = const UserFilterState(
    selectedRole: 'all',
    selectedStatus: 'all',
    selectedDepartment: 'all',
    sortField: 'createdAt',
    sortAscending: false,
    limit: 10,
  );

  int? _sortColumnIndex;
  String? _resolvedIndustry;
  bool _isLoadingIndustry = true;

  // 🔥 FIX 1: Cache streams to prevent reconnection and data loss on setState
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pendingInvitesStream;

  @override
  void initState() {
    super.initState();
    // Initialize streams ONCE to maintain real-time connection and local cache
    _usersStream = _userManagementService.watchUsersBase(
      companyId: widget.companyId,
      includeArchived: true,
    );
    _pendingInvitesStream = _userManagementService.watchInvitesBase(
      companyId: widget.companyId,
    );
    _fetchIndustry();
  }

  Future<void> _fetchIndustry() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final raw =
            (data['industryType'] ??
                    data['businessCategory'] ??
                    data['industry'] ??
                    '')
                .toString()
                .toLowerCase();

        if (raw.contains('export') && raw.contains('import')) {
          _resolvedIndustry = 'export_import';
        } else {
          _resolvedIndustry = raw;
        }
      } else {
        _resolvedIndustry = 'unknown';
      }
    } catch (e) {
      _resolvedIndustry = 'unknown';
    }

    if (mounted) {
      setState(() {
        _isLoadingIndustry = false;
      });
    }
  }

  bool get _hasActiveFilters {
    return _filterState.selectedRole != 'all' ||
        _filterState.selectedStatus != 'all' ||
        _filterState.selectedDepartment != 'all';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openInviteUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenCreateInvite(
          companyId: widget.companyId,
          currentUid: widget.currentUid,
          industry: _resolvedIndustry,
        ),
      ),
    );
  }

  Future<void> _handleViewUser(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showViewUserDialog(context: context, doc: doc);
  }

  Future<void> _handleEditUser(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showEditUserDialog(
      context: context,
      doc: doc,
      companyId: widget.companyId,
      currentUid: widget.currentUid,
      industry: _resolvedIndustry,
      onSaveUser:
          ({
            required String companyId,
            required String userUid,
            required String role,
            required bool isActive,
            required Map<String, dynamic> permissions,
            String? department,
            String? designation,
            String? branchName,
            String? accessScope,
          }) {
            return _userManagementService.updateUser(
              companyId: companyId,
              userUid: userUid,
              role: role,
              isActive: isActive,
              permissions: permissions,
              department: department,
              designation: designation,
              branchName: branchName,
              accessScope: accessScope,
              updatedByUid: widget.currentUid,
            );
          },
    );
  }

  Future<void> _handleToggleUser({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) async {
    await _userManagementService.toggleUserStatus(
      companyId: widget.companyId,
      userUid: doc.id,
      updatedByUid: widget.currentUid,
    );
  }

  Future<void> _confirmDeleteUser(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final String name = (data['displayName'] ?? data['name'] ?? 'User')
        .toString();

    final TextEditingController passwordController = TextEditingController();
    bool isVerifying = false;
    String? errorMessage;

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Security Verification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are about to delete $name.\n\n'
                    'This is a destructive action. Please confirm by entering your own account password.',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Your Password',
                      errorText: errorMessage,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: dangerColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final password = passwordController.text.trim();
                          if (password.isEmpty) {
                            setDialogState(
                              () => errorMessage = 'Password is required',
                            );
                            return;
                          }

                          setDialogState(() {
                            isVerifying = true;
                            errorMessage = null;
                          });

                          try {
                            final User? currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser != null &&
                                currentUser.email != null) {
                              final credential = EmailAuthProvider.credential(
                                email: currentUser.email!,
                                password: password,
                              );

                              await currentUser.reauthenticateWithCredential(
                                credential,
                              );

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } else {
                              setDialogState(() {
                                errorMessage =
                                    'Authentication error. Please re-login.';
                                isVerifying = false;
                              });
                            }
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              isVerifying = false;
                              if (e.code == 'wrong-password' ||
                                  e.code == 'invalid-credential') {
                                errorMessage = 'Incorrect password.';
                              } else {
                                errorMessage =
                                    e.message ?? 'Verification failed.';
                              }
                            });
                          } catch (e) {
                            setDialogState(() {
                              isVerifying = false;
                              errorMessage = 'An error occurred. Try again.';
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify & Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    await _userManagementService.deleteUser(
      companyId: widget.companyId,
      userUid: doc.id,
      deletedByUid: widget.currentUid,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User deleted successfully'),
        backgroundColor: successColor,
      ),
    );
  }

  Future<void> _confirmRestoreUser(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final String name = (data['displayName'] ?? data['name'] ?? 'User')
        .toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Restore User?'),
        content: Text(
          'This will restore $name and make the user active again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _userManagementService.restoreUser(
      companyId: widget.companyId,
      userUid: doc.id,
      restoredByUid: widget.currentUid,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User restored successfully'),
        backgroundColor: successColor,
      ),
    );
  }

  Future<void> _confirmPermanentDeleteUser(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final String name = (data['displayName'] ?? data['name'] ?? 'User')
        .toString();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Permanently Delete User?'),
        content: Text(
          'This will permanently delete $name from this company user list. '
          'This action cannot be undone from the ERP screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: dangerColor),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _userManagementService.permanentlyDeleteUser(
      companyId: widget.companyId,
      userUid: doc.id,
      deletedByUid: widget.currentUid,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User permanently deleted'),
        backgroundColor: successColor,
      ),
    );
  }

  Future<void> _confirmCancelInvite(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final String email = (data['email'] ?? '').toString().trim();
    final String name = (data['name'] ?? '').toString().trim();
    final String target = name.isNotEmpty
        ? name
        : (email.isNotEmpty ? email : 'this invite');

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Cancel Invite'),
          content: Text('Do you want to cancel invite for $target?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Cancel Invite',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _userManagementService.cancelInvite(
      companyId: widget.companyId,
      inviteId: doc.id,
      cancelledByUid: widget.currentUid,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite cancelled successfully'),
        backgroundColor: successColor,
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _filterState = _filterState.copyWith(searchQuery: value.trim());
    });
  }

  void _onSort({required int columnIndex, required String field}) {
    setState(() {
      final bool sameField = _filterState.sortField == field;

      _filterState = _filterState.copyWith(
        sortField: field,
        sortAscending: sameField ? !_filterState.sortAscending : true,
      );

      _sortColumnIndex = columnIndex;
    });
  }

  void _resetFilters() {
    _searchController.clear();

    setState(() {
      _filterState = UserFilterState(
        searchQuery: '',
        selectedRole: 'all',
        selectedStatus: 'all',
        selectedDepartment: 'all',
        sortField: 'createdAt',
        sortAscending: false,
        limit: _filterState.limit,
      );
      _sortColumnIndex = null;
    });
  }

  Widget _buildMiniStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 86,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: primaryColor,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: mutedTextColor,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    double vertical = 48,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: vertical, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: mutedTextColor),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedTextColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _buildSearchField({double width = 180}) {
    return SizedBox(
      width: width,
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search users',
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 17),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentColor),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(List<String> departments) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: IconButton(
            tooltip: 'Filters',
            onPressed: () => _openFilterSheet(departments),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: cardBorderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
            ),
            icon: Icon(
              Icons.filter_list,
              size: 17,
              color: _hasActiveFilters ? accentColor : primaryColor,
            ),
          ),
        ),
        if (_hasActiveFilters)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildRoleFilterItems() {
    return [
      const DropdownMenuItem<String>(value: 'all', child: Text('All Roles')),
      ...userRolesList.map(
        (role) => DropdownMenuItem<String>(
          value: role,
          child: Text(formatRole(role)),
        ),
      ),
    ];
  }

  void _openFilterSheet(List<String> departments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Refine user records by role, department, and account status.',
                      style: TextStyle(fontSize: 13, color: mutedTextColor),
                    ),
                    const SizedBox(height: 18),
                    FilterDropdown(
                      label: 'Role',
                      value: _filterState.selectedRole,
                      width: double.infinity,
                      items: _buildRoleFilterItems(),
                      onChanged: (value) {
                        if (value == null) return;
                        modalSetState(() {});
                        setState(() {
                          _filterState = _filterState.copyWith(
                            selectedRole: value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    FilterDropdown(
                      label: 'Department',
                      value: _filterState.selectedDepartment,
                      width: double.infinity,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('All Departments'),
                        ),
                        ...departments.map(
                          (dept) => DropdownMenuItem<String>(
                            value: dept.toLowerCase(),
                            child: Text(dept),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        modalSetState(() {});
                        setState(() {
                          _filterState = _filterState.copyWith(
                            selectedDepartment: value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    FilterDropdown(
                      label: 'Status',
                      value: _filterState.selectedStatus,
                      width: double.infinity,
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'archived',
                          child: Text('Archived'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        modalSetState(() {});
                        setState(() {
                          _filterState = _filterState.copyWith(
                            selectedStatus: value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _resetFilters();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: const BorderSide(color: cardBorderColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopTopActionArea({
    required int totalUsers,
    required int activeUsers,
    required int inactiveUsers,
    required int pendingInvitesCount,
    required List<String> departments,
  }) {
    return _buildSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMiniStat(
              title: 'Total',
              value: '$totalUsers',
              icon: Icons.group_outlined,
              color: primaryColor,
            ),
            const SizedBox(width: 6),
            _buildMiniStat(
              title: 'Active',
              value: '$activeUsers',
              icon: Icons.verified_user_outlined,
              color: successColor,
            ),
            const SizedBox(width: 6),
            _buildMiniStat(
              title: 'Inactive',
              value: '$inactiveUsers',
              icon: Icons.person_off_outlined,
              color: warningColor,
            ),
            const SizedBox(width: 6),
            _buildMiniStat(
              title: 'Pending',
              value: '$pendingInvitesCount',
              icon: Icons.mark_email_unread_outlined,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(width: 10),
            _buildSearchField(width: 220),
            const SizedBox(width: 8),
            _buildFilterButton(departments),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: _openInviteUser,
                icon: const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.white,
                  size: 14,
                ),
                label: const Text(
                  'Invite User',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTopActionArea({
    required int totalUsers,
    required int activeUsers,
    required int inactiveUsers,
    required int pendingInvitesCount,
    required List<String> departments,
  }) {
    return _buildSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMiniStat(
                  title: 'Total',
                  value: '$totalUsers',
                  icon: Icons.group_outlined,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                _buildMiniStat(
                  title: 'Active',
                  value: '$activeUsers',
                  icon: Icons.verified_user_outlined,
                  color: successColor,
                ),
                const SizedBox(width: 8),
                _buildMiniStat(
                  title: 'Inactive',
                  value: '$inactiveUsers',
                  icon: Icons.person_off_outlined,
                  color: warningColor,
                ),
                const SizedBox(width: 8),
                _buildMiniStat(
                  title: 'Pending',
                  value: '$pendingInvitesCount',
                  icon: Icons.mark_email_unread_outlined,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildSearchField(width: double.infinity)),
              const SizedBox(width: 8),
              _buildFilterButton(departments),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _openInviteUser,
              icon: const Icon(
                Icons.person_add_alt_1,
                color: Colors.white,
                size: 16,
              ),
              label: const Text(
                'Invite User',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersSection({
    required bool isDesktop,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    locallySearchedUsers,
  }) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Users',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage user accounts, status, roles, and access history.',
                      style: TextStyle(fontSize: 13, color: mutedTextColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _filterState.searchQuery.trim().isEmpty
                      ? '${users.length} shown'
                      : '${locallySearchedUsers.length} matched locally',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pageDocs.isEmpty)
            _buildEmptyState(
              icon: Icons.group_off_outlined,
              title: 'No users found',
              subtitle: 'Try changing your search or filters.',
            )
          else ...[
            if (isDesktop)
              DesktopUserTable(
                pageDocs: pageDocs,
                currentUid: widget.currentUid,
                sortAscending: _filterState.sortAscending,
                sortColumnIndex: _sortColumnIndex,
                onSort: (columnIndex, field) {
                  _onSort(columnIndex: columnIndex, field: field);
                },
                onView: (doc) async => _handleViewUser(doc),
                onEdit: (doc) async => _handleEditUser(doc),
                onToggle: (doc) => _handleToggleUser(doc: doc),
                onDelete: (doc) async => _confirmDeleteUser(context, doc),
                onRestore: (doc) async => _confirmRestoreUser(context, doc),
                onPermanentDelete: (doc) async =>
                    _confirmPermanentDeleteUser(context, doc),
              )
            else
              Column(
                children: pageDocs.map((doc) {
                  final data = doc.data();
                  final bool isSelfUser = doc.id == widget.currentUid;
                  final bool isDeleted = (data['isDeleted'] ?? false) == true;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: UserCard(
                      doc: doc,
                      currentUid: widget.currentUid,
                      onView: () async => _handleViewUser(doc),
                      onEdit: () async => _handleEditUser(doc),
                      onToggle: (isSelfUser || isDeleted)
                          ? null
                          : () async => _handleToggleUser(doc: doc),
                      onDelete: (isSelfUser || isDeleted)
                          ? null
                          : () async => _confirmDeleteUser(context, doc),
                      onRestore: (isSelfUser || !isDeleted)
                          ? null
                          : () async => _confirmRestoreUser(context, doc),
                      onPermanentDelete: (isSelfUser || !isDeleted)
                          ? null
                          : () async =>
                                _confirmPermanentDeleteUser(context, doc),
                    ),
                  );
                }).toList(),
              ),
            if (_filterState.searchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: cardBorderColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Search is currently applied only on the users already loaded from Firestore. For full production search across all users, add indexed search or external search later.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: mutedTextColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInvitesSection({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingInvites,
  }) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Invites',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Track invitation records that are waiting for acceptance.',
            style: TextStyle(fontSize: 13, color: mutedTextColor),
          ),
          const SizedBox(height: 16),
          if (pendingInvites.isEmpty)
            _buildEmptyState(
              icon: Icons.mail_lock_outlined,
              title: 'No pending invites',
              subtitle: 'New invitations will appear here.',
              vertical: 44,
            )
          else
            Column(
              children: pendingInvites.map((doc) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InviteCard(
                    doc: doc,
                    onDelete: () => _confirmCancelInvite(context, doc),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout({
    required int totalUsers,
    required int activeUsers,
    required int inactiveUsers,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingInvites,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    locallySearchedUsers,
    required List<String> departments,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDesktopTopActionArea(
                totalUsers: totalUsers,
                activeUsers: activeUsers,
                inactiveUsers: inactiveUsers,
                pendingInvitesCount: pendingInvites.length,
                departments: departments,
              ),
              const SizedBox(height: 16),
              _buildUsersSection(
                isDesktop: true,
                users: users,
                pageDocs: pageDocs,
                locallySearchedUsers: locallySearchedUsers,
              ),
              const SizedBox(height: 16),
              _buildInvitesSection(pendingInvites: pendingInvites),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout({
    required int totalUsers,
    required int activeUsers,
    required int inactiveUsers,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingInvites,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    locallySearchedUsers,
    required List<String> departments,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileTopActionArea(
            totalUsers: totalUsers,
            activeUsers: activeUsers,
            inactiveUsers: inactiveUsers,
            pendingInvitesCount: pendingInvites.length,
            departments: departments,
          ),
          const SizedBox(height: 14),
          _buildUsersSection(
            isDesktop: false,
            users: users,
            pageDocs: pageDocs,
            locallySearchedUsers: locallySearchedUsers,
          ),
          const SizedBox(height: 14),
          _buildInvitesSection(pendingInvites: pendingInvites),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingIndustry) {
      return const Scaffold(
        backgroundColor: pageBgColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: pageBgColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, userSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _pendingInvitesStream,
            builder: (context, inviteSnapshot) {
              final bool usersWaiting =
                  userSnapshot.connectionState == ConnectionState.waiting;
              final bool invitesWaiting =
                  inviteSnapshot.connectionState == ConnectionState.waiting;

              if (usersWaiting || invitesWaiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              if (userSnapshot.hasError || inviteSnapshot.hasError) {
                final String userError = userSnapshot.error?.toString() ?? '';
                final String inviteError =
                    inviteSnapshot.error?.toString() ?? '';

                final String combinedError = [
                  if (userError.isNotEmpty) userError,
                  if (inviteError.isNotEmpty) inviteError,
                ].join('\n\n');

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildEmptyState(
                      icon: Icons.error_outline,
                      title: 'Unable to load user data',
                      subtitle: combinedError.isEmpty
                          ? 'Please check Firestore rules, indexes, or connection and try again.'
                          : combinedError,
                    ),
                  ),
                );
              }

              final rawDocs = userSnapshot.data?.docs ?? [];

              // 🔥 FIX 3: Isolate KPI Metrics from local filters
              final nonDeletedDocs = rawDocs.where((doc) {
                return (doc.data()['isDeleted'] ?? false) == false;
              }).toList();

              final int totalUsers = nonDeletedDocs.length;
              final int activeUsers = nonDeletedDocs
                  .where((doc) => (doc.data()['isActive'] ?? true) == true)
                  .length;
              final int inactiveUsers = nonDeletedDocs
                  .where((doc) => (doc.data()['isActive'] ?? true) == false)
                  .length;

              final List<String> departments = extractDepartments(
                nonDeletedDocs,
              );

              // 🔥 FIX 2: Dynamic Archival filtering mapping based strictly on selected state
              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              allUsers = rawDocs.where((doc) {
                final data = doc.data();
                final isDeleted = (data['isDeleted'] ?? false) == true;

                if (_filterState.selectedStatus == 'archived') {
                  return isDeleted; // Safely allow deleted users through if requested
                }
                return !isDeleted; // Aggressively block them otherwise
              }).toList();

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              filteredUsers = filterUsersLocally(
                docs: allUsers,
                state: _filterState,
              );

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              locallySearchedUsers = filteredUsers;
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> users =
                  filteredUsers;
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs =
                  locallySearchedUsers;

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              allInvites = inviteSnapshot.data?.docs ?? [];

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              pendingInvites =
                  allInvites.where((doc) {
                    final data = doc.data();
                    final String status = (data['status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    final bool isDeleted = (data['isDeleted'] ?? false) == true;
                    return !isDeleted && status == 'pending';
                  }).toList()..sort((a, b) {
                    final aTs = a.data()['createdAt'];
                    final bTs = b.data()['createdAt'];

                    DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
                    DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);

                    if (aTs is Timestamp) aDate = aTs.toDate();
                    if (bTs is Timestamp) bDate = bTs.toDate();

                    return bDate.compareTo(aDate);
                  });

              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth >= 900;

                  if (isDesktop) {
                    return _buildDesktopLayout(
                      totalUsers: totalUsers,
                      activeUsers: activeUsers,
                      inactiveUsers: inactiveUsers,
                      pendingInvites: pendingInvites,
                      users: users,
                      pageDocs: pageDocs,
                      locallySearchedUsers: locallySearchedUsers,
                      departments: departments,
                    );
                  }

                  return _buildMobileLayout(
                    totalUsers: totalUsers,
                    activeUsers: activeUsers,
                    inactiveUsers: inactiveUsers,
                    pendingInvites: pendingInvites,
                    users: users,
                    pageDocs: pageDocs,
                    locallySearchedUsers: locallySearchedUsers,
                    departments: departments,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            width: 68,
            height: 68,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFDDE3FF),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              onPressed: _openInviteUser,
              child: const Icon(Icons.add, color: primaryColor, size: 30),
            ),
          );
        },
      ),
    );
  }
}
