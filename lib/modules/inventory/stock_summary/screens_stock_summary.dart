import 'package:flutter/material.dart';

import 'package:QUIK/modules/inventory/inventory_service.dart';

class ScreensStockSummary extends StatefulWidget {
  const ScreensStockSummary({
    super.key,
    required this.companyId,
  });

  final String companyId;

  @override
  State<ScreensStockSummary> createState() => _ScreensStockSummaryState();
}

class _ScreensStockSummaryState extends State<ScreensStockSummary> {
  final _service = InventoryService();
  final _searchCtrl = TextEditingController();
  late Future<List<StockSummaryRow>> _future;
  String _warehouse = 'All';
  String _nature = 'All';
  int _page = 0;
  static const _pageSize = 12;

  @override
  void initState() {
    super.initState();
    _future = _service.loadSummary(widget.companyId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.loadSummary(widget.companyId);
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StockSummaryRow>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final rows = snapshot.data ?? [];
        final warehouses = ['All', ...{for (final row in rows) row.warehouseName}.where((v) => v.isNotEmpty)];
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = rows.where((row) {
          final matchesWarehouse = _warehouse == 'All' || row.warehouseName == _warehouse;
          final matchesNature = _nature == 'All' || row.productNature == _nature;
          final matchesSearch = query.isEmpty || row.productName.toLowerCase().contains(query);
          return matchesWarehouse && matchesNature && matchesSearch;
        }).toList();
        final maxPage = filtered.isEmpty ? 0 : ((filtered.length - 1) / _pageSize).floor();
        if (_page > maxPage) _page = maxPage;
        final visible = filtered.skip(_page * _pageSize).take(_pageSize).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stock Summary', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('${filtered.length} stock balance${filtered.length == 1 ? '' : 's'} calculated live', style: const TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: _panelDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() => _page = 0),
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Product Name', border: OutlineInputBorder()),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: warehouses.contains(_warehouse) ? _warehouse : 'All',
                        decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
                        items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                        onChanged: (value) => setState(() {
                          _warehouse = value ?? 'All';
                          _page = 0;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: _nature,
                        decoration: const InputDecoration(labelText: 'Product Nature', border: OutlineInputBorder()),
                        items: ['All', ...inventoryProductNatures].map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                        onChanged: (value) => setState(() {
                          _nature = value ?? 'All';
                          _page = 0;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: _panelDecoration(),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const _EmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Product Name')),
                                      DataColumn(label: Text('Product Nature')),
                                      DataColumn(label: Text('Warehouse')),
                                      DataColumn(label: Text('Stock In Qty'), numeric: true),
                                      DataColumn(label: Text('Stock Out Qty'), numeric: true),
                                      DataColumn(label: Text('Available Qty'), numeric: true),
                                    ],
                                    rows: visible.map((row) {
                                      final negative = row.availableQty < 0;
                                      return DataRow(cells: [
                                        DataCell(Text(row.productName)),
                                        DataCell(Text(row.productNature)),
                                        DataCell(Text(row.warehouseName)),
                                        DataCell(Text(formatQty(row.stockInQty))),
                                        DataCell(Text(formatQty(row.stockOutQty))),
                                        DataCell(Text(
                                          formatQty(row.availableQty),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: negative ? const Color(0xFFDC2626) : const Color(0xFF166534),
                                          ),
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
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(filtered.isEmpty ? 'No records' : 'Page ${_page + 1} of ${maxPage + 1}', style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: _page == 0 ? null : () => setState(() => _page--), child: const Text('Previous')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _page >= maxPage ? null : () => setState(() => _page++), child: const Text('Next')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

BoxDecoration _panelDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 44, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('No stock balances found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Save Stock In entries to build live inventory balances.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
