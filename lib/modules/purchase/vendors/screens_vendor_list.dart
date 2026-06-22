import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'models/vendor_model.dart';
import 'screens_add_vendor.dart';
import 'services/vendor_service.dart';

class PurchaseVendorListScreen extends StatefulWidget {
  const PurchaseVendorListScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  final String companyId;
  final String userUid;

  @override
  State<PurchaseVendorListScreen> createState() =>
      _PurchaseVendorListScreenState();
}

class _PurchaseVendorListScreenState extends State<PurchaseVendorListScreen> {
  final _service = VendorService();
  final _searchController = TextEditingController();
  String _category = 'All';
  String _status = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<VendorModel>>(
        stream: _service.watchVendors(widget.companyId),
        builder: (context, snapshot) {
          final vendors = snapshot.data ?? const <VendorModel>[];
          final filtered = _filter(vendors);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(filtered.length),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 310,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search name, code, GST, city...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      _filterDropdown(
                        'Category',
                        _category,
                        ['All', ...purchaseVendorCategories],
                        (value) => setState(() => _category = value ?? 'All'),
                      ),
                      _filterDropdown(
                        'Status',
                        _status,
                        const ['All', 'Active', 'Inactive'],
                        (value) => setState(() => _status = value ?? 'All'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? _empty(vendors.isEmpty)
                    : LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 760
                            ? _mobileList(filtered)
                            : _desktopTable(filtered),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vendors',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '$count vendor${count == 1 ? '' : 's'} in this view',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => _openVendor(),
          icon: const Icon(Icons.add),
          label: const Text('Add Vendor'),
        ),
      ],
    );
  }

  List<VendorModel> _filter(List<VendorModel> vendors) {
    final query = _searchController.text.trim().toLowerCase();
    return vendors.where((vendor) {
      final text = [
        vendor.vendorName,
        vendor.vendorCode,
        vendor.contactPerson,
        vendor.mobile,
        vendor.email,
        vendor.city,
        vendor.gstNo,
        vendor.panNo,
      ].join(' ').toLowerCase();
      return (query.isEmpty || text.contains(query)) &&
          (_category == 'All' || vendor.vendorCategory == _category) &&
          (_status == 'All' ||
              (_status == 'Active' ? vendor.isActive : !vendor.isActive));
    }).toList();
  }

  Widget _desktopTable(List<VendorModel> vendors) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(zSurfaceSoft),
            columns: const [
              DataColumn(label: Text('Vendor Name')),
              DataColumn(label: Text('Vendor Code')),
              DataColumn(label: Text('Contact Person')),
              DataColumn(label: Text('Mobile')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('City')),
              DataColumn(label: Text('GST No')),
              DataColumn(label: Text('PAN No')),
              DataColumn(label: Text('Vendor Category')),
              DataColumn(label: Text('Credit Days'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: vendors
                .map(
                  (vendor) => DataRow(
                    cells: [
                      DataCell(
                        Text(
                          vendor.vendorName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text(_dash(vendor.vendorCode))),
                      DataCell(Text(_dash(vendor.contactPerson))),
                      DataCell(Text(_dash(vendor.mobile))),
                      DataCell(Text(_dash(vendor.email))),
                      DataCell(Text(_dash(vendor.city))),
                      DataCell(Text(_dash(vendor.gstNo))),
                      DataCell(Text(_dash(vendor.panNo))),
                      DataCell(Text(vendor.vendorCategory)),
                      DataCell(Text('${vendor.creditDays}')),
                      DataCell(_statusChip(vendor.isActive)),
                      DataCell(_actions(vendor)),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _mobileList(List<VendorModel> vendors) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: vendors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final vendor = vendors[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vendor.vendorName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _statusChip(vendor.isActive),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dash(vendor.vendorCode)} • ${vendor.vendorCategory}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 22),
                Text(
                  '${_dash(vendor.contactPerson)}  ·  ${_dash(vendor.mobile)}',
                ),
                const SizedBox(height: 4),
                Text('${_dash(vendor.city)}  ·  GST ${_dash(vendor.gstNo)}'),
                Align(
                  alignment: Alignment.centerRight,
                  child: _actions(vendor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actions(VendorModel vendor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit vendor',
          onPressed: () => _openVendor(vendor),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: vendor.isActive ? 'Deactivate vendor' : 'Activate vendor',
          onPressed: () => _toggleStatus(vendor),
          icon: Icon(
            vendor.isActive
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            color: vendor.isActive ? zWarning : zSuccess,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? zSuccessSoft : zDangerSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: active ? zSuccess : zDanger,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _filterDropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _empty(bool noData) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.business_outlined, size: 48, color: zMuted),
          const SizedBox(height: 12),
          Text(
            noData ? 'No vendors added yet' : 'No vendors match the filters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            noData
                ? 'Create your first vendor to begin purchase billing.'
                : 'Try changing the search or filter values.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _openVendor([VendorModel? vendor]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddVendorScreen(
          companyId: widget.companyId,
          userUid: widget.userUid,
          vendor: vendor,
        ),
      ),
    );
  }

  Future<void> _toggleStatus(VendorModel vendor) async {
    await _service.setVendorActive(
      companyId: widget.companyId,
      vendorId: vendor.id,
      isActive: !vendor.isActive,
      userUid: widget.userUid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${vendor.vendorName} ${vendor.isActive ? 'deactivated' : 'activated'}.',
        ),
      ),
    );
  }
}

String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();
