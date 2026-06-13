import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/crm/contacts/screens_add_contact.dart';

String _safeString(dynamic value) => (value ?? '').toString().trim();

bool _safeBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value == 1;
  final text = value.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

DateTime? _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDateTime(dynamic value) {
  final date = _toDate(value);
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final amPm = date.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year $hour:$minute $amPm';
}

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<Contacts> createState() => _ContactsState();
}

class ContactsPage extends Contacts {
  const ContactsPage({super.key});
}

class ContactsScreen extends Contacts {
  const ContactsScreen({super.key});
}

class _ContactsState extends State<Contacts> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'All';
  String _departmentFilter = 'All';
  bool _onlyPrimary = false;
  bool _loadingProfile = true;
  String _companyId = '';
  String _userRole = '';
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loadingProfile = false);
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final globalDoc = await firestore.collection('users').doc(user.uid).get();
      final globalData = globalDoc.data() ?? <String, dynamic>{};

      String companyId = _safeString(globalData['companyId']);
      if (companyId.isEmpty) {
        final companyIds = globalData['companyIds'];
        if (companyIds is List && companyIds.isNotEmpty) {
          companyId = companyIds.first.toString();
        } else {
          final memberships = globalData['memberships'];
          if (memberships is Map && memberships.isNotEmpty) {
            companyId = memberships.keys.first.toString();
          }
        }
      }

      Map<String, dynamic> companyUserData = {};
      if (companyId.isNotEmpty) {
        final companyUserDoc = await firestore
            .collection('companies')
            .doc(companyId)
            .collection('users')
            .doc(user.uid)
            .get();
        companyUserData = companyUserDoc.data() ?? <String, dynamic>{};
      }

      final profile = {...globalData, ...companyUserData};
      if (!mounted) return;
      setState(() {
        _companyId = companyId;
        _userRole = _safeString(profile['role']);
        _currentUserName = _safeString(
          profile['name'] ?? profile['userName'] ?? profile['displayName'],
        );
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  bool get _isAdminOrManager {
    final role = _userRole.toLowerCase();
    return role == 'owner' ||
        role == 'founder' ||
        role == 'ceo' ||
        role == 'superadmin' ||
        role == 'admin' ||
        role == 'manager';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _contactsStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collectionGroup('contacts')
        .where('companyId', isEqualTo: _companyId);

    return query.snapshots();
  }

  Future<List<_ContactItem>> _buildItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final customerRefs = <DocumentReference<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final customerRef = doc.reference.parent.parent;
      if (customerRef != null) customerRefs.add(customerRef);
    }

    final customerSnapMap = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    await Future.wait(customerRefs.map((ref) async {
      try {
        customerSnapMap[ref.path] = await ref.get();
      } catch (_) {}
    }));

    final items = <_ContactItem>[];
    for (final doc in docs) {
      final data = doc.data();
      final customerRef = doc.reference.parent.parent;
      if (customerRef == null) continue;

      final customerData = customerSnapMap[customerRef.path]?.data() ?? {};
      final createdBy = _safeString(customerData['createdBy'] ?? customerData['createdByUid']);
      final assignedToUid = _safeString(customerData['assignedToUid']);
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final canView = _isAdminOrManager || createdBy == currentUid || assignedToUid == currentUid;
      if (!canView) continue;

      items.add(_ContactItem.fromFirestore(
        contactDoc: doc,
        customerRef: customerRef,
        customerData: customerData,
      ));
    }

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  List<_ContactItem> _applyFilters(List<_ContactItem> items) {
    final query = _query.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesSearch = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.customerName.toLowerCase().contains(query) ||
          item.customerCode.toLowerCase().contains(query) ||
          item.phone.toLowerCase().contains(query) ||
          item.email.toLowerCase().contains(query) ||
          item.designation.toLowerCase().contains(query) ||
          item.department.toLowerCase().contains(query);

      if (!matchesSearch) return false;
      if (_onlyPrimary && !item.isPrimary) return false;
      if (_statusFilter != 'All' && item.status.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      if (_departmentFilter != 'All' && item.department.toLowerCase() != _departmentFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  List<String> _departments(List<_ContactItem> items) {
    final values = items
        .map((e) => e.department)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...values];
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _statusFilter = 'All';
      _departmentFilter = 'All';
      _onlyPrimary = false;
    });
  }

  Future<void> _openAddContact([_ContactItem? item]) async {
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a customer card and click Add Contact for that customer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddContact(companyRef: item.customerRef),
      ),
    );
  }

  Future<void> _deleteContact(_ContactItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Delete ${item.name.isEmpty ? 'this contact' : item.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await item.contactDoc.reference.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact deleted.'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login again.')));
    }

    if (_companyId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Company profile not found.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        onPressed: () => _openAddContact(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _contactsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading contacts: ${snapshot.error}'));
          }

          return FutureBuilder<List<_ContactItem>>(
            future: _buildItems(snapshot.data?.docs ?? []),
            builder: (context, itemSnap) {
              if (itemSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allItems = itemSnap.data ?? [];
              final visibleItems = _applyFilters(allItems);
              final departments = _departments(allItems);
              if (!departments.contains(_departmentFilter)) {
                _departmentFilter = 'All';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PageHeader(companyName: 'CRM • Contacts'),
                  _Toolbar(
                    controller: _searchController,
                    allItems: allItems,
                    totalCount: allItems.length,
                    visibleCount: visibleItems.length,
                    primaryCount: allItems.where((e) => e.isPrimary).length,
                    statusFilter: _statusFilter,
                    departmentFilter: _departmentFilter,
                    departments: departments,
                    onlyPrimary: _onlyPrimary,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onSelected: (item) => setState(() {
                      _query = item.name;
                      _searchController.text = item.name;
                    }),
                    onStatusChanged: (value) => setState(() => _statusFilter = value),
                    onDepartmentChanged: (value) => setState(() => _departmentFilter = value),
                    onPrimaryChanged: (value) => setState(() => _onlyPrimary = value),
                    onReset: _resetFilters,
                  ),
                  Expanded(
                    child: visibleItems.isEmpty
                        ? _EmptyContactsState(
                            hasFilters: _query.isNotEmpty ||
                                _statusFilter != 'All' ||
                                _departmentFilter != 'All' ||
                                _onlyPrimary,
                            onReset: _resetFilters,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                            itemCount: visibleItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = visibleItems[index];
                              return _ContactCard(
                                item: item,
                                onAddContact: () => _openAddContact(item),
                                onDelete: () => _deleteContact(item),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String companyName;

  const _PageHeader({required this.companyName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            companyName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 18),
          const Text(
            'Contacts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController controller;
  final List<_ContactItem> allItems;
  final int totalCount;
  final int visibleCount;
  final int primaryCount;
  final String statusFilter;
  final String departmentFilter;
  final List<String> departments;
  final bool onlyPrimary;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ContactItem> onSelected;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<bool> onPrimaryChanged;
  final VoidCallback onReset;

  const _Toolbar({
    required this.controller,
    required this.allItems,
    required this.totalCount,
    required this.visibleCount,
    required this.primaryCount,
    required this.statusFilter,
    required this.departmentFilter,
    required this.departments,
    required this.onlyPrimary,
    required this.onSearchChanged,
    required this.onSelected,
    required this.onStatusChanged,
    required this.onDepartmentChanged,
    required this.onPrimaryChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          final searchBox = SizedBox(
            width: isNarrow ? double.infinity : 420,
            child: RawAutocomplete<_ContactItem>(
              textEditingController: controller,
              focusNode: FocusNode(),
              displayStringForOption: (item) => item.name,
              optionsBuilder: (textValue) {
                final text = textValue.text.trim().toLowerCase();
                if (text.isEmpty) return const Iterable<_ContactItem>.empty();
                final matches = allItems.where((item) {
                  return item.name.toLowerCase().contains(text) ||
                      item.customerName.toLowerCase().contains(text) ||
                      item.phone.toLowerCase().contains(text) ||
                      item.email.toLowerCase().contains(text);
                }).toList()
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                return matches.take(12);
              },
              onSelected: onSelected,
              fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search contact, customer, phone, email...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: controller.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: onReset,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF4F4F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                );
              },
              optionsViewBuilder: (context, onOptionSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final item = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(item.initial, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800)),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${item.customerName} • ${item.phone.isEmpty ? item.email : item.phone}'),
                            onTap: () => onOptionSelected(item),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          );

          final filterRow = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DropdownChip(
                icon: Icons.filter_list,
                value: statusFilter,
                values: const ['All', 'Active', 'Inactive', 'Left Company', 'Do Not Contact'],
                onChanged: onStatusChanged,
              ),
              _DropdownChip(
                icon: Icons.apartment,
                value: departmentFilter,
                values: departments,
                onChanged: onDepartmentChanged,
              ),
              FilterChip(
                label: const Text('Primary'),
                selected: onlyPrimary,
                onSelected: onPrimaryChanged,
                selectedColor: const Color(0xFFDBEAFE),
                checkmarkColor: const Color(0xFF2563EB),
              ),
              IconButton(
                tooltip: 'Reset filters',
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          );

          final counter = Text(
            'Visible: $visibleCount   Total: $totalCount   Primary: $primaryCount',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [searchBox, const SizedBox(height: 12), filterRow, const SizedBox(height: 8), counter],
            );
          }

          return Row(
            children: [
              searchBox,
              const SizedBox(width: 12),
              Expanded(child: filterRow),
              counter,
            ],
          );
        },
      ),
    );
  }
}

class _DropdownChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _DropdownChip({
    required this.icon,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF334155)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: values.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final _ContactItem item;
  final VoidCallback onAddContact;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.item,
    required this.onAddContact,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: false, onChanged: (_) {}),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(item.initial, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.customerCode.isNotEmpty) _Badge(text: item.customerCode, bg: const Color(0xFFDBEAFE), fg: const Color(0xFF2563EB)),
                          Text(
                            item.name.isEmpty ? '(No Name)' : item.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          _Badge(text: item.status, bg: item.statusColor.withOpacity(0.12), fg: item.statusColor),
                          if (item.isPrimary) _Badge(text: 'Primary', bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _MiniInfo(icon: Icons.business_outlined, text: item.customerName),
                          if (item.phone.isNotEmpty) _MiniInfo(icon: Icons.phone_outlined, text: item.phone),
                          if (item.email.isNotEmpty) _MiniInfo(icon: Icons.email_outlined, text: item.email),
                          if (item.designation.isNotEmpty) _MiniInfo(icon: Icons.person_outline, text: item.designation),
                          if (item.department.isNotEmpty) _MiniInfo(icon: Icons.groups_outlined, text: item.department),
                          _MiniInfo(icon: Icons.update, text: 'Updated ${_formatDateTime(item.updatedAt)}'),
                          if (item.updatedByName.isNotEmpty) _MiniInfo(icon: Icons.edit_outlined, text: 'Updated By: ${item.updatedByName}'),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete Contact', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.timeline, size: 18),
                    label: const Text('Timeline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddContact,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add Contact'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Badge({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EmptyContactsState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onReset;

  const _EmptyContactsState({required this.hasFilters, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasFilters ? Icons.search_off : Icons.contact_page_outlined, size: 44, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(
              hasFilters ? 'No matching contacts found' : 'No contacts found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text('Contacts added inside customer cards will appear here alphabetically.'),
            if (hasFilters) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.refresh), label: const Text('Reset Filters')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactItem {
  final QueryDocumentSnapshot<Map<String, dynamic>> contactDoc;
  final DocumentReference<Map<String, dynamic>> customerRef;
  final String name;
  final String phone;
  final String email;
  final String designation;
  final String department;
  final String status;
  final bool isPrimary;
  final String customerName;
  final String customerCode;
  final String updatedByName;
  final dynamic updatedAt;

  const _ContactItem({
    required this.contactDoc,
    required this.customerRef,
    required this.name,
    required this.phone,
    required this.email,
    required this.designation,
    required this.department,
    required this.status,
    required this.isPrimary,
    required this.customerName,
    required this.customerCode,
    required this.updatedByName,
    required this.updatedAt,
  });

  factory _ContactItem.fromFirestore({
    required QueryDocumentSnapshot<Map<String, dynamic>> contactDoc,
    required DocumentReference<Map<String, dynamic>> customerRef,
    required Map<String, dynamic> customerData,
  }) {
    final data = contactDoc.data();
    String status = _safeString(data['contactStatus']);
    if (status.isEmpty) {
      status = data.containsKey('isActive') && !_safeBool(data['isActive']) ? 'Inactive' : 'Active';
    }

    return _ContactItem(
      contactDoc: contactDoc,
      customerRef: customerRef,
      name: _safeString(data['name'] ?? data['contactName']),
      phone: _safeString(data['phone'] ?? data['mobile'] ?? data['mobileNo']),
      email: _safeString(data['email'] ?? data['businessEmail']),
      designation: _safeString(data['designation']),
      department: _safeString(data['department']),
      status: status,
      isPrimary: _safeBool(data['isPrimary']),
      customerName: _safeString(
        customerData['companyName'] ??
            customerData['name'] ??
            customerData['customerName'] ??
            customerData['businessName'] ??
            'Unknown Customer',
      ),
      customerCode: _safeString(customerData['customerCode']).toUpperCase(),
      updatedByName: _safeString(data['updatedByName'] ?? data['createdByName']),
      updatedAt: data['updatedAt'] ?? data['createdAt'],
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF16A34A);
      case 'inactive':
        return const Color(0xFF64748B);
      case 'left company':
        return const Color(0xFFDC2626);
      case 'do not contact':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF2563EB);
    }
  }
}
