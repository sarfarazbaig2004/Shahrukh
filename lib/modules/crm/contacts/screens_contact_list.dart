import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/crm/contacts/screens_add_contact.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

bool _safeBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is int) return val == 1;
  final s = val.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String _safeString(dynamic val) {
  return (val ?? '').toString().trim();
}

// ==========================================
// ENTERPRISE CONTACTS WORKSPACE
// ==========================================

class ScreensContactList extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String companyName;

  const ScreensContactList({
    super.key,
    required this.companyRef,
    required this.companyName,
  });

  @override
  State<ScreensContactList> createState() => _ScreensContactListState();
}

class _ScreensContactListState extends State<ScreensContactList> {
  final TextEditingController _search = TextEditingController();

  // Filters
  bool _onlyPrimary = false;
  bool _onlyWithEmail = false;
  bool _onlyWithPhone = false;
  String _statusFilter = 'All';
  String _typeFilter = 'All';

  // Table State
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  bool _tableView = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  bool _isAdminOrManager(String role) {
    return role == 'admin' || role == 'manager' || role == 'owner';
  }

  void _sortRows(List<_ContactRow> rows) {
    rows.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 1:
          cmp = a.designation.toLowerCase().compareTo(b.designation.toLowerCase());
          break;
        case 2:
          cmp = a.department.toLowerCase().compareTo(b.department.toLowerCase());
          break;
        case 3:
          cmp = a.location.toLowerCase().compareTo(b.location.toLowerCase());
          break;
        case 4:
          cmp = a.contactStatus.toLowerCase().compareTo(b.contactStatus.toLowerCase());
          break;
        case 5:
          cmp = (a.isPrimary ? 1 : 0).compareTo(b.isPrimary ? 1 : 0);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981); // Emerald
      case 'inactive':
        return const Color(0xFF64748B); // Slate
      case 'left company':
        return const Color(0xFFEF4444); // Red
      case 'do not contact':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  void _triggerQuickAction(String action, _ContactRow contact) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $action module for ${contact.name}...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login again.')));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadCurrentUserProfile(currentUser.uid),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (userSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Contacts - ${widget.companyName}')),
            body: Center(child: Text('Error loading user profile: ${userSnap.error}')),
          );
        }

        final userData = userSnap.data ?? {};
        final role = _safeString(userData['role']);

        return LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 980;
            final allowTableView = c.maxWidth >= 1100;

            if (!allowTableView && _tableView) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _tableView = false);
              });
            }

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                title: const Text('Contacts Workspace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: c.maxWidth < 700
                        ? IconButton(
                      tooltip: 'Add Contact',
                      onPressed: _goAddContact,
                      icon: const Icon(Icons.person_add_outlined),
                    )
                        : ElevatedButton.icon(
                      onPressed: _goAddContact,
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Add Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: widget.companyRef.get(),
                builder: (context, customerSnap) {
                  if (customerSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (customerSnap.hasError) {
                    return Center(child: Text('Error loading company: ${customerSnap.error}'));
                  }

                  if (!customerSnap.hasData || !customerSnap.data!.exists) {
                    return const Center(child: Text('Company not found.'));
                  }

                  final customerData = customerSnap.data!.data() ?? {};
                  final createdBy = _safeString(customerData['createdBy']);
                  final assignedToUid = _safeString(customerData['assignedToUid']);

                  final hasAccess = _isAdminOrManager(role) ||
                      createdBy == currentUser.uid ||
                      assignedToUid == currentUser.uid;

                  if (!hasAccess) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_outline, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 16),
                            Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            SizedBox(height: 8),
                            Text('You do not have permission to view contacts of this customer.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    );
                  }

                  final contactsRef = widget.companyRef.collection('contacts');

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: contactsRef.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading contacts: ${snapshot.error}'));
                      }

                      final docs = (snapshot.data?.docs ?? []).toList();

                      final rows = docs.map((d) {
                        final m = d.data();

                        String status = _safeString(m['contactStatus']);
                        if (status.isEmpty) {
                          bool isActive = m.containsKey('isActive') ? _safeBool(m['isActive']) : true;
                          status = isActive ? 'Active' : 'Inactive';
                        }

                        return _ContactRow(
                          doc: d,
                          name: _safeString(m['name']),
                          email: _safeString(m['email']),
                          phone: _safeString(m['phone']),
                          alternatePhone: _safeString(m['alternatePhone']),
                          officePhone: _safeString(m['officePhone']),
                          designation: _safeString(m['designation']),
                          department: _safeString(m['department']),
                          contactType: _safeString(m['contactType']).isNotEmpty ? _safeString(m['contactType']) : 'Commercial',
                          contactStatus: status,
                          location: _safeString(m['linkedAddressLabel']),
                          preferredComm: _safeString(m['preferredCommunicationMode']),
                          isPrimary: _safeBool(m['isPrimary']),
                        );
                      }).toList();

                      final q = _search.text.trim().toLowerCase();
                      var filtered = rows.where((r) {
                        if (q.isNotEmpty) {
                          if (!r.name.toLowerCase().contains(q) &&
                              !r.email.toLowerCase().contains(q) &&
                              !r.phone.toLowerCase().contains(q) &&
                              !r.designation.toLowerCase().contains(q) &&
                              !r.department.toLowerCase().contains(q) &&
                              !r.location.toLowerCase().contains(q)) {
                            return false;
                          }
                        }

                        if (_onlyPrimary && !r.isPrimary) return false;
                        if (_onlyWithEmail && r.email.isEmpty) return false;
                        if (_onlyWithPhone && r.phone.isEmpty && r.alternatePhone.isEmpty && r.officePhone.isEmpty) return false;
                        if (_statusFilter != 'All' && r.contactStatus.toLowerCase() != _statusFilter.toLowerCase()) return false;
                        if (_typeFilter != 'All' && r.contactType.toLowerCase() != _typeFilter.toLowerCase()) return false;

                        return true;
                      }).toList();

                      _sortRows(filtered);

                      final primaryCount = rows.where((e) => e.isPrimary).length;
                      final activeCount = rows.where((e) => e.contactStatus.toLowerCase() == 'active').length;
                      final totalCount = rows.length;

                      if (isWide) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1600),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: _filterPanel(
                                    total: totalCount,
                                    primaryCount: primaryCount,
                                    activeCount: activeCount,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 24, 24),
                                    child: Column(
                                      children: [
                                        _companySummaryHeader(
                                          total: filtered.length,
                                          primaryCount: primaryCount,
                                          activeCount: activeCount,
                                          onToggleView: allowTableView ? () => setState(() => _tableView = !_tableView) : null,
                                          showToggle: allowTableView,
                                        ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: filtered.isEmpty
                                              ? _emptyState()
                                              : (_tableView && allowTableView)
                                              ? _contactsTable(filtered)
                                              : _contactsList(filtered),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _companySummaryHeader(
                              total: filtered.length,
                              primaryCount: primaryCount,
                              activeCount: activeCount,
                              onToggleView: null,
                              showToggle: false,
                              compact: true,
                            ),
                            const SizedBox(height: 16),
                            _mobileFilterBar(),
                            const SizedBox(height: 16),
                            Expanded(
                              child: filtered.isEmpty
                                  ? _emptyState()
                                  : _contactsList(filtered),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _companySummaryHeader({
    required int total,
    required int primaryCount,
    required int activeCount,
    required VoidCallback? onToggleView,
    required bool showToggle,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDBEAFE))),
                    child: const Icon(Icons.business, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage enterprise contacts',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showToggle && !compact && onToggleView != null) ...[
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: onToggleView,
                  icon: Icon(_tableView ? Icons.grid_view_rounded : Icons.table_chart_outlined, size: 18),
                  label: Text(_tableView ? 'Card View' : 'Table View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _SummaryPill(label: 'Total Visible', value: '$total', icon: Icons.people_alt_outlined),
                _SummaryPill(label: 'Primary', value: '$primaryCount', icon: Icons.star_outline),
                _SummaryPill(label: 'Active Users', value: '$activeCount', icon: Icons.check_circle_outline, color: const Color(0xFF10B981)),
              ];

              if (constraints.maxWidth < 500) {
                return Wrap(spacing: 12, runSpacing: 12, children: cards);
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mobileFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search names, phones...',
              hintStyle: const TextStyle(fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.trim().isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close, size: 18), onPressed: () { _search.clear(); setState(() {}); }),
              isDense: true, filled: true, fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Primary', style: TextStyle(fontSize: 12)),
                  selected: _onlyPrimary,
                  onSelected: (v) => setState(() => _onlyPrimary = v),
                  backgroundColor: const Color(0xFFF1F5F9),
                  selectedColor: const Color(0xFFDBEAFE),
                  checkmarkColor: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                      items: ['All', 'Active', 'Inactive', 'Left Company'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _statusFilter = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() { _onlyPrimary = false; _onlyWithEmail = false; _onlyWithPhone = false; _statusFilter = 'All'; _typeFilter = 'All'; _search.clear(); }),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final hasFilters = _search.text.trim().isNotEmpty || _onlyPrimary || _onlyWithEmail || _onlyWithPhone || _statusFilter != 'All' || _typeFilter != 'All';

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Icon(hasFilters ? Icons.search_off : Icons.contact_page_outlined, size: 40, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),
            Text(hasFilters ? 'No matching contacts found' : 'No Contacts Found', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(
              hasFilters ? 'Try adjusting your search criteria or filters.' : 'Add decision makers, site contacts, and key personnel to map out this account.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: () => setState(() { _onlyPrimary = false; _onlyWithEmail = false; _onlyWithPhone = false; _statusFilter = 'All'; _typeFilter = 'All'; _search.clear(); }),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset Filters'),
              )
            else
              ElevatedButton.icon(
                onPressed: _goAddContact,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Contact'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterPanel({required int total, required int primaryCount, required int activeCount}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune_rounded, size: 20, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text('Filters & Search', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _search.text.trim().isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close, size: 16), onPressed: () { _search.clear(); setState(() {}); }),
                  isDense: true, filled: true, fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: Color(0xFFE2E8F0))),

              const Text('Contact Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    items: ['All', 'Active', 'Inactive', 'Left Company', 'Do Not Contact'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _statusFilter = v!),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text('Contact Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _typeFilter,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    items: ['All', 'Commercial', 'Technical', 'Management', 'Service', 'Dispatch', 'Emergency', 'General'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _typeFilter = v!),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text('Quick Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _onlyPrimary, onChanged: (v) => setState(() => _onlyPrimary = v ?? false),
                dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFF2563EB),
                title: const Text('Primary Contacts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              CheckboxListTile(
                value: _onlyWithEmail, onChanged: (v) => setState(() => _onlyWithEmail = v ?? false),
                dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFF2563EB),
                title: const Text('Has Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              CheckboxListTile(
                value: _onlyWithPhone, onChanged: (v) => setState(() => _onlyWithPhone = v ?? false),
                dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFF2563EB),
                title: const Text('Has Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() { _onlyPrimary = false; _onlyWithEmail = false; _onlyWithPhone = false; _statusFilter = 'All'; _typeFilter = 'All'; _search.clear(); }),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Reset All Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactsList(List<_ContactRow> rows) {
    return ListView.builder(
      itemCount: rows.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, i) {
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ContactCard(
            row: r,
            statusColor: _getStatusColor(r.contactStatus),
            onAction: (action) => _triggerQuickAction(action, r),
            onEdit: () => _editContact(r),
            onDelete: () => _deleteContact(r),
          ),
        );
      },
    );
  }

  Widget _contactsTable(List<_ContactRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569), fontSize: 13),
                columnSpacing: 24,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 72,
                columns: [
                  DataColumn(label: const Text('Contact Details'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; })),
                  DataColumn(label: const Text('Role & Dept'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; })),
                  DataColumn(label: const Text('Site / Location'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; })),
                  DataColumn(label: const Text('Status'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; })),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: rows.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(child: Text(r.name.isEmpty ? '(No Name)' : r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                                        if (r.isPrimary)
                                          Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.star, size: 14, color: Colors.amber.shade600)),
                                      ],
                                    ),
                                    if (r.phone.isNotEmpty || r.email.isNotEmpty)
                                      Text([r.phone, r.email].where((e) => e.isNotEmpty).join(' • '), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _editContact(r),
                      ),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.designation.isEmpty ? '-' : r.designation, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (r.department.isNotEmpty)
                                Text(r.department, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Text(r.location.isEmpty ? 'Corporate / HQ' : r.location, style: const TextStyle(fontSize: 13, color: Color(0xFF334155)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _getStatusColor(r.contactStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(r.contactStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _getStatusColor(r.contactStatus))),
                          )
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(tooltip: 'Log Activity', icon: const Icon(Icons.add_task, color: Color(0xFF64748B), size: 20), onPressed: () => _triggerQuickAction('Add Activity', r)),
                            IconButton(tooltip: 'Edit Contact', icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20), onPressed: () => _editContact(r)),
                            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20), onPressed: () => _deleteContact(r)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goAddContact() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensAddContact(companyRef: widget.companyRef)));
  }

  void _editContact(_ContactRow r) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensAddContact(companyRef: widget.companyRef, contactDoc: r.doc)));
  }

  Future<void> _deleteContact(_ContactRow r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Are you sure you want to delete "${r.name}" from this customer record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await r.doc.reference.delete();
        final companySnap = await widget.companyRef.get();
        final companyData = companySnap.data() ?? {};
        final oldCount = (companyData['contactsCount'] ?? 0) as num;

        await widget.companyRef.update({
          'contactsCount': oldCount > 0 ? oldCount - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact deleted successfully'), backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete contact: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// --- WIDGETS ---

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _SummaryPill({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFF0F172A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: effectiveColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: effectiveColor),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: effectiveColor)),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final _ContactRow row;
  final Color statusColor;
  final Function(String) onAction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.row,
    required this.statusColor,
    required this.onAction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: row.isPrimary ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(row.name.isNotEmpty ? row.name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(row.name.isEmpty ? '(No Name)' : row.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(row.contactStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5)),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Options',
                            icon: const Icon(Icons.more_horiz, size: 20, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') onEdit();
                              else if (value == 'delete') onDelete();
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit Contact', style: TextStyle(fontSize: 13))),
                              PopupMenuItem(value: 'delete', child: Text('Delete Contact', style: TextStyle(color: Colors.red, fontSize: 13))),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (row.isPrimary)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star, size: 10, color: Colors.amber.shade700), const SizedBox(width: 4), Text('Primary', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber.shade800))])),
                          if (row.designation.isNotEmpty) Text(row.designation, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          if (row.department.isNotEmpty) Text('• ${row.department}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (row.phone.isNotEmpty || row.alternatePhone.isNotEmpty || row.officePhone.isNotEmpty)
                            _InfoChip(icon: Icons.phone_outlined, text: [row.phone, row.alternatePhone, row.officePhone].firstWhere((e) => e.isNotEmpty)),
                          if (row.email.isNotEmpty)
                            _InfoChip(icon: Icons.email_outlined, text: row.email),
                          if (row.location.isNotEmpty)
                            _InfoChip(icon: Icons.location_on_outlined, text: row.location, color: const Color(0xFF8B5CF6)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)), border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ActionBtn(icon: Icons.add_task, label: 'Log Activity', onTap: () => onAction('Log Activity')),
                _ActionBtn(icon: Icons.chat_outlined, label: 'WhatsApp', onTap: () => onAction('WhatsApp')),
                _ActionBtn(icon: Icons.mail_outline, label: 'Email', onTap: () => onAction('Email')),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFF475569);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effectiveColor),
          const SizedBox(width: 6),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: effectiveColor))),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }
}

// --- DOMAIN MODELS ---

class _ContactRow {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final String name;
  final String email;
  final String phone;
  final String alternatePhone;
  final String officePhone;
  final String designation;
  final String department;
  final String contactType;
  final String contactStatus;
  final String location;
  final String preferredComm;
  final bool isPrimary;

  _ContactRow({
    required this.doc,
    required this.name,
    required this.email,
    required this.phone,
    required this.alternatePhone,
    required this.officePhone,
    required this.designation,
    required this.department,
    required this.contactType,
    required this.contactStatus,
    required this.location,
    required this.preferredComm,
    required this.isPrimary,
  });
}