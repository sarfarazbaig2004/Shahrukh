import 'package:flutter/material.dart';

import 'package:QUIK/modules/inventory/inventory_service.dart';

class ScreensWarehouseList extends StatefulWidget {
  const ScreensWarehouseList({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<ScreensWarehouseList> createState() => _ScreensWarehouseListState();
}

class _ScreensWarehouseListState extends State<ScreensWarehouseList> {
  final _service = InventoryService();
  final _searchCtrl = TextEditingController();
  int _page = 0;
  static const _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WarehouseRecord>>(
      stream: _service.warehousesStream(widget.companyId),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final warehouses = snapshot.data ?? [];
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = warehouses.where((w) {
          final haystack = '${w.code} ${w.name} ${w.location} ${w.contactPerson} ${w.mobileNumber} ${w.email} ${w.status}'.toLowerCase();
          return query.isEmpty || haystack.contains(query);
        }).toList();
        final maxPage = filtered.isEmpty ? 0 : ((filtered.length - 1) / _pageSize).floor();
        if (_page > maxPage) _page = maxPage;
        final visible = filtered.skip(_page * _pageSize).take(_pageSize).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: 'Warehouse',
              subtitle: '${filtered.length} warehouse${filtered.length == 1 ? '' : 's'}',
              actionLabel: 'New Warehouse',
              onAction: () => _openWarehouseDialog(),
            ),
            const SizedBox(height: 12),
            _Toolbar(
              controller: _searchCtrl,
              hint: 'Search code, name, location, contact',
              onChanged: () => setState(() => _page = 0),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: _panelDecoration(),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const _EmptyState(title: 'No warehouses found', message: 'Create warehouses such as Main Warehouse, Raw Material Store, or Service Store.')
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Code')),
                                      DataColumn(label: Text('Warehouse Name')),
                                      DataColumn(label: Text('Location')),
                                      DataColumn(label: Text('Contact')),
                                      DataColumn(label: Text('Mobile')),
                                      DataColumn(label: Text('Email')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: visible.map((w) {
                                      return DataRow(cells: [
                                        DataCell(Text(w.code)),
                                        DataCell(Text(w.name)),
                                        DataCell(Text(w.location)),
                                        DataCell(Text(w.contactPerson)),
                                        DataCell(Text(w.mobileNumber)),
                                        DataCell(Text(w.email)),
                                        DataCell(_StatusPill(text: w.status)),
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'View',
                                              icon: const Icon(Icons.visibility_outlined),
                                              onPressed: () => _viewWarehouse(w),
                                            ),
                                            IconButton(
                                              tooltip: 'Edit',
                                              icon: const Icon(Icons.edit_outlined),
                                              onPressed: () => _openWarehouseDialog(warehouse: w),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete',
                                              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                                              onPressed: () => _deleteWarehouse(w),
                                            ),
                                          ],
                                        )),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
            _Pagination(
              page: _page,
              maxPage: maxPage,
              total: filtered.length,
              onPrevious: _page == 0 ? null : () => setState(() => _page--),
              onNext: _page >= maxPage ? null : () => setState(() => _page++),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWarehouseDialog({WarehouseRecord? warehouse}) async {
    final codeCtrl = TextEditingController(text: warehouse?.code ?? '');
    final nameCtrl = TextEditingController(text: warehouse?.name ?? '');
    final locationCtrl = TextEditingController(text: warehouse?.location ?? '');
    final addressCtrl = TextEditingController(text: warehouse?.address ?? '');
    final contactCtrl = TextEditingController(text: warehouse?.contactPerson ?? '');
    final mobileCtrl = TextEditingController(text: warehouse?.mobileNumber ?? '');
    final emailCtrl = TextEditingController(text: warehouse?.email ?? '');
    var status = warehouse?.status ?? 'Active';
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(warehouse == null ? 'Create Warehouse' : 'Edit Warehouse'),
              content: SizedBox(
                width: 760,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Wrap(
                      runSpacing: 14,
                      spacing: 14,
                      children: [
                        _field(codeCtrl, 'Warehouse Code', required: true),
                        _field(nameCtrl, 'Warehouse Name', required: true),
                        _field(locationCtrl, 'Location'),
                        _field(addressCtrl, 'Address', maxLines: 2),
                        _field(contactCtrl, 'Contact Person'),
                        _field(mobileCtrl, 'Mobile Number'),
                        _field(emailCtrl, 'Email'),
                        SizedBox(
                          width: 230,
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                            items: const ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (value) => setDialogState(() => status = value ?? 'Active'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await _service.saveWarehouse(
                      companyId: widget.companyId,
                      userUid: widget.userUid,
                      warehouse: WarehouseRecord(
                        id: warehouse?.id ?? '',
                        code: codeCtrl.text,
                        name: nameCtrl.text,
                        location: locationCtrl.text,
                        address: addressCtrl.text,
                        contactPerson: contactCtrl.text,
                        mobileNumber: mobileCtrl.text,
                        email: emailCtrl.text,
                        status: status,
                      ),
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _viewWarehouse(WarehouseRecord w) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(w.name),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detail('Warehouse Code', w.code),
              _detail('Location', w.location),
              _detail('Address', w.address),
              _detail('Contact Person', w.contactPerson),
              _detail('Mobile Number', w.mobileNumber),
              _detail('Email', w.email),
              _detail('Status', w.status),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _deleteWarehouse(WarehouseRecord w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete warehouse?'),
        content: Text('This will remove ${w.name}. Existing stock documents remain unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _service.deleteWarehouse(widget.companyId, w.id);
  }
}

Widget _field(TextEditingController controller, String label, {bool required = false, int maxLines = 1}) {
  return SizedBox(
    width: 230,
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    ),
  );
}

Widget _detail(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Color(0xFF64748B)))),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

BoxDecoration _panelDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, required this.actionLabel, required this.onAction});
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
        FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add), label: Text(actionLabel)),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final active = text.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: TextStyle(color: active ? const Color(0xFF166534) : const Color(0xFF475569), fontWeight: FontWeight.w700)),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.page, required this.maxPage, required this.total, required this.onPrevious, required this.onNext});
  final int page;
  final int maxPage;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(total == 0 ? 'No records' : 'Page ${page + 1} of ${maxPage + 1}', style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onPrevious, child: const Text('Previous')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warehouse_outlined, size: 44, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
