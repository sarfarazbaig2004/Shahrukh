import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/crm/contacts/screens_add_contact.dart';

String _safeString(dynamic value) => (value ?? '').toString().trim();

bool _safeBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value == 1;
  final text = value.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes' || text == 'active';
}

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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'All';
  String _categoryFilter = 'All';
  bool _onlyEmail = false;
  bool _onlyPhone = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _customersStream {
    return widget.companyRef.collection('customers').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _customersStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorBox(message: 'Contacts loading failed: ${snap.error}');
          }

          final allRows = (snap.data?.docs ?? [])
              .map(_ContactRow.fromCustomerDoc)
              .where((row) => row.companyName.isNotEmpty || row.contactName.isNotEmpty || row.phone.isNotEmpty || row.email.isNotEmpty)
              .toList()
            ..sort((a, b) => a.sortName.compareTo(b.sortName));

          final rows = _applyFilters(allRows);
          final activeCount = allRows.where((e) => e.status.toLowerCase() == 'active').length;
          final phoneCount = allRows.where((e) => e.phone.isNotEmpty).length;
          final emailCount = allRows.where((e) => e.email.isNotEmpty).length;

          return Column(
            children: [
              _topBar(total: allRows.length, visible: rows.length, active: activeCount, phone: phoneCount, email: emailCount),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filterPanel(allRows),
                    Expanded(
                      child: rows.isEmpty
                          ? _emptyState(allRows.isEmpty)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _contactCard(rows[index]),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_ContactRow> _applyFilters(List<_ContactRow> rows) {
    final q = _query.trim().toLowerCase();
    return rows.where((row) {
      if (q.isNotEmpty && !row.searchText.contains(q)) return false;
      if (_statusFilter != 'All' && row.status.toLowerCase() != _statusFilter.toLowerCase()) return false;
      if (_categoryFilter != 'All' && row.category.toLowerCase() != _categoryFilter.toLowerCase()) return false;
      if (_onlyEmail && row.email.isEmpty) return false;
      if (_onlyPhone && row.phone.isEmpty) return false;
      return true;
    }).toList();
  }

  Widget _topBar({required int total, required int visible, required int active, required int phone, required int email}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Contacts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddContactHint(),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(title: 'Visible', value: '$visible', icon: Icons.visibility_outlined),
              const SizedBox(width: 12),
              _StatCard(title: 'Total Customers', value: '$total', icon: Icons.people_alt_outlined),
              const SizedBox(width: 12),
              _StatCard(title: 'Active', value: '$active', icon: Icons.check_circle_outline),
              const SizedBox(width: 12),
              _StatCard(title: 'Phone Numbers', value: '$phone', icon: Icons.phone_outlined),
              const SizedBox(width: 12),
              _StatCard(title: 'Email IDs', value: '$email', icon: Icons.email_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterPanel(List<_ContactRow> rows) {
    final suggestions = _query.isEmpty ? <_ContactRow>[] : rows.where((e) => e.searchText.contains(_query.toLowerCase())).take(8).toList();
    return Container(
      width: 310,
      margin: const EdgeInsets.fromLTRB(16, 14, 0, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0F172A)), SizedBox(width: 8), Text('Search & Filters', style: TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search name, company, phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearSearch),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: suggestions.map((row) => ListTile(
                        dense: true,
                        leading: CircleAvatar(radius: 14, backgroundColor: const Color(0xFFDBEAFE), child: Text(row.initial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)))),
                        title: Text(row.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(row.phone.isEmpty ? row.companyName : row.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        onTap: () => setState(() {
                          _query = row.displayTitle;
                          _searchController.text = row.displayTitle;
                          _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
                        }),
                      )).toList(),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const _PanelLabel('Customer Status'),
            _DropdownBox(value: _statusFilter, values: const ['All', 'Active', 'Inactive'], onChanged: (v) => setState(() => _statusFilter = v ?? 'All')),
            const SizedBox(height: 14),
            const _PanelLabel('Customer Category'),
            _DropdownBox(value: _categoryFilter, values: const ['All', 'Existing Customer', 'Potential Customer', 'Lead', 'Prospect'], onChanged: (v) => setState(() => _categoryFilter = v ?? 'All')),
            const SizedBox(height: 18),
            const _PanelLabel('Quick Filters'),
            _CheckRow(label: 'Has Email Address', value: _onlyEmail, onChanged: (v) => setState(() => _onlyEmail = v ?? false)),
            _CheckRow(label: 'Has Phone Number', value: _onlyPhone, onChanged: (v) => setState(() => _onlyPhone = v ?? false)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _resetFilters, child: const Text('Reset All Filters'))),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(_ContactRow row) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 22, backgroundColor: const Color(0xFFDBEAFE), child: Text(row.initial, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (row.customerCode.isNotEmpty) _Tag(text: row.customerCode, bg: const Color(0xFFDBEAFE), fg: const Color(0xFF2563EB)),
                        if (row.customerCode.isNotEmpty) const SizedBox(width: 8),
                        Expanded(child: Text(row.displayTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tag(text: row.category.isEmpty ? 'Customer' : row.category, bg: const Color(0xFFDCFCE7), fg: const Color(0xFF166534)),
                        _Tag(text: row.status, bg: const Color(0xFFEFF6FF), fg: const Color(0xFF1D4ED8)),
                        if (row.priority.isNotEmpty) _Tag(text: row.priority, bg: const Color(0xFFF3E8FF), fg: const Color(0xFF7E22CE)),
                        if (row.city.isNotEmpty) _Tag(text: row.city, bg: const Color(0xFFF8FAFC), fg: const Color(0xFF334155)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'add_contact') _openAddContact(row);
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'add_contact', child: Text('Add / Edit Contact'))],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _InlineInfo(icon: Icons.business_outlined, text: row.companyName.isEmpty ? '-' : row.companyName),
              _InlineInfo(icon: Icons.phone_outlined, text: row.phone.isEmpty ? '-' : row.phone),
              _InlineInfo(icon: Icons.email_outlined, text: row.email.isEmpty ? '-' : row.email),
              if (row.contactName.isNotEmpty) _InlineInfo(icon: Icons.person_outline, text: row.contactName),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _openAddContact(row), icon: const Icon(Icons.person_add_alt_1, size: 17), label: const Text('Add Contact'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.history, size: 17), label: const Text('Timeline'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool noCustomers) {
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.contact_phone_outlined, size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(noCustomers ? 'No Customers Found' : 'No Matching Contacts', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(noCustomers ? 'Your customer database has no customer records yet.' : 'Change search or filters to view saved customer contacts.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _query = '';
      _searchController.clear();
    });
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _statusFilter = 'All';
      _categoryFilter = 'All';
      _onlyEmail = false;
      _onlyPhone = false;
    });
  }

  void _showAddContactHint() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer card and click Add Contact to save a person under that customer.')));
  }

  void _openAddContact(_ContactRow row) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensAddContact(companyRef: row.customerRef)));
  }
}

class _ContactRow {
  final DocumentReference<Map<String, dynamic>> customerRef;
  final String customerCode;
  final String companyName;
  final String contactName;
  final String phone;
  final String email;
  final String city;
  final String status;
  final String category;
  final String priority;
  final String assignedTo;

  const _ContactRow({
    required this.customerRef,
    required this.customerCode,
    required this.companyName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.city,
    required this.status,
    required this.category,
    required this.priority,
    required this.assignedTo,
  });

  factory _ContactRow.fromCustomerDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final companyName = _firstNonEmpty([d['companyName'], d['customerName'], d['name']]);
    final contactName = _firstNonEmpty([d['contactName'], d['contactPerson'], d['personName'], d['primaryContactName'], d['customerContactName']]);
    final phone = _firstNonEmpty([d['companyPhone'], d['phone'], d['mobile'], d['contactPhone'], d['primaryPhone'], d['telephone'], d['whatsapp']]);
    final email = _firstNonEmpty([d['businessEmail'], d['email'], d['companyEmail'], d['contactEmail'], d['primaryEmail']]);
    final statusRaw = _firstNonEmpty([d['status'], d['customerStatus']]);
    final category = _firstNonEmpty([d['customerType'], d['category'], d['leadType'], d['type']]);
    return _ContactRow(
      customerRef: doc.reference,
      customerCode: _firstNonEmpty([d['customerCode'], d['code']]),
      companyName: companyName,
      contactName: contactName,
      phone: phone,
      email: email,
      city: _firstNonEmpty([d['city'], d['location'], d['addressCity'], d['state']]),
      status: statusRaw.isEmpty ? (_safeBool(d['isActive']) ? 'Active' : 'Active') : statusRaw,
      category: category.isEmpty ? 'Customer' : category,
      priority: _firstNonEmpty([d['priority'], d['customerPriority']]),
      assignedTo: _firstNonEmpty([d['assignedToName'], d['assignedTo'], d['salesPerson'], d['ownerName']]),
    );
  }

  String get displayTitle => companyName.isNotEmpty ? companyName : contactName;
  String get sortName => displayTitle.toLowerCase();
  String get initial => displayTitle.isEmpty ? '?' : displayTitle.characters.first.toUpperCase();
  String get searchText => '$customerCode $companyName $contactName $phone $email $city $status $category $priority'.toLowerCase();
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _safeString(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [CircleAvatar(radius: 18, backgroundColor: const Color(0xFFE2E8F0), child: Icon(icon, size: 18, color: const Color(0xFF334155))), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))])]),
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  final String text;
  const _PanelLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))));
}

class _DropdownBox extends StatelessWidget {
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  const _DropdownBox({required this.value, required this.values, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: values.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _CheckRow({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => CheckboxListTile(value: value, onChanged: onChanged, title: Text(label, style: const TextStyle(fontSize: 13)), controlAffinity: ListTileControlAffinity.trailing, contentPadding: EdgeInsets.zero, dense: true);
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag({required this.text, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)), child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)));
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineInfo({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: const Color(0xFF64748B)), const SizedBox(width: 5), Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))]);
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Center(child: Container(width: 620, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))), child: Text(message, style: const TextStyle(color: Color(0xFF991B1B)))));
}
