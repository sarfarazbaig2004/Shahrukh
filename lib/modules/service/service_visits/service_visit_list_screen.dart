import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_service_visit_screen.dart';

// --- ERP HELPERS ---
int _safeInt(dynamic val) => int.tryParse((val ?? '0').toString()) ?? 0;
String _safeString(dynamic val) => (val ?? '').toString().trim();
DateTime? _extractDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
String _formatDate(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
}

class ServiceVisitListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const ServiceVisitListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<ServiceVisitListScreen> createState() => _ServiceVisitListScreenState();
}

class _ServiceVisitListScreenState extends State<ServiceVisitListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  String _searchQuery = '';
  String _filterEngineer = 'All';
  String _filterType = 'All';
  String _filterStatus = 'All';
  String _filterStage = 'All';

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _isTableView = false;
  bool _isAdmin = false;
  bool _isFetchingRole = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetchUserRole();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users').doc(widget.currentUserUid).get();
      if (doc.exists && mounted) {
        final role = _safeString(doc.data()?['role']).toLowerCase();
        setState(() {
          _isAdmin = ['admin', 'superadmin', 'manager'].contains(role);
          _isFetchingRole = false;
        });
      } else {
        if (mounted) setState(() => _isFetchingRole = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingRole = false);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isTableView = prefs.getBool('erp_visit_view_pref') ?? false);
    }
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isTableView = !_isTableView);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('erp_visit_view_pref', _isTableView);
    } catch (_) {}
  }

  void _onSearch(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.toLowerCase().trim();
        _currentPage = 1;
      });
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final filtered = docs.where((doc) {
      final data = doc.data();
      if (data['isDeleted'] == true) return false;

      // Security Rules
      if (!_isAdmin && _safeString(data['engineerUid']) != widget.currentUserUid && _safeString(data['createdBy']) != widget.currentUserUid) {
        return false;
      }

      final engName = _safeString(data['engineerName']);
      final type = _safeString(data['visitType']);
      final status = _safeString(data['visitStatus']);
      final stage = _safeString(data['workflowStage']);

      if (_filterEngineer != 'All' && engName != _filterEngineer) return false;
      if (_filterType != 'All' && type != _filterType) return false;
      if (_filterStatus != 'All' && status != _filterStatus) return false;
      if (_filterStage != 'All' && stage != _filterStage) return false;

      if (_searchQuery.isNotEmpty) {
        final vNo = _safeString(data['visitNo']).toLowerCase();
        final rNo = _safeString(data['requestNumber']).toLowerCase();
        final cust = _safeString(data['customerName']).toLowerCase();
        final eng = engName.toLowerCase();
        if (!vNo.contains(_searchQuery) && !rNo.contains(_searchQuery) && !cust.contains(_searchQuery) && !eng.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _extractDate(a.data()['visitDate']) ?? _extractDate(a.data()['createdAt']) ?? DateTime(2000);
      final bDate = _extractDate(b.data()['visitDate']) ?? _extractDate(b.data()['createdAt']) ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Map<String, int> _getStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = 0, sched = 0, prog = 0, comp = 0;
    for (var d in docs) {
      if (d.data()['isDeleted'] == true) continue;
      total++;
      final s = _safeString(d.data()['visitStatus']);
      if (s == 'Scheduled') sched++;
      if (s == 'In Progress') prog++;
      if (s == 'Completed') comp++;
    }
    return {'Total': total, 'Scheduled': sched, 'WIP': prog, 'Completed': comp};
  }

  Future<void> _openFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    Set<String> engSet = {'All'};
    Set<String> typeSet = {'All'};
    Set<String> statusSet = {'All', 'Scheduled', 'In Progress', 'Completed', 'Cancelled'};

    for (var d in docs) {
      if (d.data()['isDeleted'] == true) continue;
      if (_safeString(d.data()['engineerName']).isNotEmpty) engSet.add(_safeString(d.data()['engineerName']));
      if (_safeString(d.data()['visitType']).isNotEmpty) typeSet.add(_safeString(d.data()['visitType']));
    }

    String tEng = _filterEngineer, tType = _filterType, tStatus = _filterStatus;

    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: tStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: statusSet.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => tStatus = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: engSet.contains(tEng) ? tEng : 'All',
                decoration: const InputDecoration(labelText: 'Engineer', border: OutlineInputBorder()),
                items: engSet.toList().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => tEng = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: typeSet.contains(tType) ? tType : 'All',
                decoration: const InputDecoration(labelText: 'Visit Type', border: OutlineInputBorder()),
                items: typeSet.toList().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => tType = v!,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() { _filterEngineer = tEng; _filterType = tType; _filterStatus = tStatus; _currentPage = 1; });
                  Navigator.pop(ctx);
                },
                child: const Center(child: Text('Apply Filters')),
              )
            ],
          ),
        )
    );
  }

  void _showDetails(Map<String, dynamic> d) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${_safeString(d['visitNo'])} - ${_safeString(d['customerName'])}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Request No', _safeString(d['requestNumber'])),
                  _detailRow('Engineer', _safeString(d['engineerName'])),
                  _detailRow('Visit Date', _formatDate(d['visitDate'])),
                  _detailRow('Type & Status', '${_safeString(d['visitType'])} / ${_safeString(d['visitStatus'])}'),
                  _detailRow('Workflow Stage', _safeString(d['workflowStage'])),
                  const Divider(height: 32),
                  _detailRow('Observations', _safeString(d['observation'])),
                  _detailRow('Work Done', _safeString(d['workDone'])),
                  _detailRow('Next Action', _safeString(d['nextAction'])),
                  _detailRow('Remarks', _safeString(d['remarks'])),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        )
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
            companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName))),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('service_visits').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final isWaiting = snap.connectionState == ConnectionState.waiting;
          final allDocs = snap.data?.docs ?? [];
          final filteredDocs = _applyFilters(allDocs);
          final stats = _getStats(allDocs);

          final totalPages = math.max(1, (filteredDocs.length / _pageSize).ceil());
          int safePage = _currentPage > totalPages ? totalPages : _currentPage;
          final pagedDocs = filteredDocs.sublist((safePage - 1) * _pageSize, math.min(safePage * _pageSize, filteredDocs.length));

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 300, height: 38,
                      child: TextField(
                        controller: _searchCtrl, onChanged: _onSearch,
                        decoration: InputDecoration(hintText: 'Search visits...', prefixIcon: const Icon(Icons.search, size: 18), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: EdgeInsets.zero),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(icon: const Icon(Icons.tune), onPressed: () => _openFilters(allDocs)),
                    IconButton(icon: Icon(_isTableView ? Icons.grid_view : Icons.table_rows), onPressed: _toggleViewMode),
                    const Spacer(),
                    if (!isWaiting) ...[
                      Text('Total: ${stats['Total']}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 16),
                      Text('Scheduled: ${stats['Scheduled']}', style: const TextStyle(color: Colors.blue)), const SizedBox(width: 16),
                      Text('WIP: ${stats['WIP']}', style: const TextStyle(color: Colors.orange)), const SizedBox(width: 16),
                      Text('Done: ${stats['Completed']}', style: const TextStyle(color: Colors.green)),
                    ]
                  ],
                ),
              ),
              Expanded(
                  child: isWaiting ? const Center(child: CircularProgressIndicator())
                      : _isTableView ? _buildTable(pagedDocs) : _buildCards(pagedDocs)
              ),
              _buildPagination(filteredDocs.length, safePage, totalPages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (ctx, i) {
          final d = docs[i].data();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text('${_safeString(d['visitNo'])} • ${_safeString(d['customerName'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Req: ${_safeString(d['requestNumber'])} | Eng: ${_safeString(d['engineerName'])} | Date: ${_formatDate(d['visitDate'])}'),
              trailing: Chip(label: Text(_safeString(d['visitStatus']), style: const TextStyle(fontSize: 10))),
              onTap: () => _showDetails(d),
              onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceVisitScreen(
                  companyId: widget.companyId, currentUserUid: widget.currentUserUid, currentUserName: widget.currentUserName, existingDocId: docs[i].id, existingData: d))),
            ),
          );
        }
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Visit No')), DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Request No')), DataColumn(label: Text('Engineer')),
            DataColumn(label: Text('Type')), DataColumn(label: Text('Status')), DataColumn(label: Text('Date'))
          ],
          rows: docs.map((doc) {
            final d = doc.data();
            return DataRow(
                cells: [
                  DataCell(Text(_safeString(d['visitNo'])), onTap: () => _showDetails(d)),
                  DataCell(Text(_safeString(d['customerName']))),
                  DataCell(Text(_safeString(d['requestNumber']))),
                  DataCell(Text(_safeString(d['engineerName']))),
                  DataCell(Text(_safeString(d['visitType']))),
                  DataCell(Text(_safeString(d['visitStatus']))),
                  DataCell(Text(_formatDate(d['visitDate']))),
                ]
            );
          }).toList(),
        )
    );
  }

  Widget _buildPagination(int total, int current, int pages) {
    return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Showing ${docsCount(total, current)} of $total'),
            Row(
              children: [
                TextButton(onPressed: current > 1 ? () => setState(() => _currentPage--) : null, child: const Text('Prev')),
                Text(' $current / $pages '),
                TextButton(onPressed: current < pages ? () => setState(() => _currentPage++) : null, child: const Text('Next')),
              ],
            )
          ],
        )
    );
  }

  String docsCount(int total, int curr) => total == 0 ? '0' : '${(curr - 1) * _pageSize + 1}-${math.min(curr * _pageSize, total)}';
}