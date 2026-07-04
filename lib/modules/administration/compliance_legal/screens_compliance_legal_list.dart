import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import 'screens_add_compliance_legal.dart';

class ScreensComplianceLegalList extends StatefulWidget {
  final String companyId;

  const ScreensComplianceLegalList({Key? key, required this.companyId}) : super(key: key);

  @override
  State<ScreensComplianceLegalList> createState() => _ScreensComplianceLegalListState();
}

class _ScreensComplianceLegalListState extends State<ScreensComplianceLegalList> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStatusFilter = 'All';

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  final List<String> _categories = ['All', 'Policy', 'Contract', 'Registration', 'License', 'Other'];
  final List<String> _statuses = ['All', 'Active', 'Expiring Soon', 'Expired'];

  void _deleteRecord(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Delete Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this compliance record?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: zMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('compliance_legal')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Record deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting record: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  int _getDaysRemaining(DateTime? expiry) {
    if (expiry == null) return 9999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = DateTime(expiry.year, expiry.month, expiry.day);
    return expDate.difference(today).inDays;
  }

  String _calculateStatus(DateTime? expiry) {
    if (expiry == null) return 'Active';
    final days = _getDaysRemaining(expiry);
    if (days < 0) return 'Expired';
    if (days <= 30) return 'Expiring Soon';
    return 'Active';
  }

  Widget _buildKPICard(String title, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: zBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: zMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Active':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'Expiring Soon':
        bgColor = zOrange.withOpacity(0.1);
        textColor = zOrange;
        break;
      case 'Expired':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = zMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDaysBadge(int days) {
    if (days == 9999) return Text('-', style: TextStyle(color: zMuted, fontSize: 12));

    Color textColor = days < 0 ? Colors.red : (days <= 30 ? zOrange : zText);
    String text = days < 0 ? '${days.abs()}d overdue' : '${days}d left';

    return Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600));
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    if (timestamp is Timestamp) return DateFormat('dd MMM yyyy').format(timestamp.toDate());
    return timestamp.toString();
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: zCanvasBg,
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Reduced from 24
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Compliance & Legal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: zText)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.refresh, color: zMuted, size: 20),
                      onPressed: () => setState(() {}),
                      splashRadius: 20,
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: zBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ScreensAddComplianceLegal(companyId: widget.companyId)),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Compliance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16), // Reduced spacing

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('companies')
                    .doc(widget.companyId)
                    .collection('compliance_legal')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: zBlue));

                  final allDocs = snapshot.data?.docs ?? [];

                  // Pre-calculate status & filter
                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final expiry = data['expiryDate'] is Timestamp ? (data['expiryDate'] as Timestamp).toDate() : null;
                    final dynamicStatus = _calculateStatus(expiry);

                    final name = (data['complianceName'] ?? '').toString().toLowerCase();
                    final reg = (data['registrationNumber'] ?? '').toString().toLowerCase();
                    final auth = (data['authority'] ?? '').toString().toLowerCase();
                    final cat = data['category'] ?? '';

                    final sq = _searchQuery.toLowerCase();
                    final matchesSearch = name.contains(sq) || reg.contains(sq) || auth.contains(sq) || cat.toLowerCase().contains(sq);
                    final matchesCategory = _selectedCategory == 'All' || cat == _selectedCategory;
                    final matchesStatus = _selectedStatusFilter == 'All' || dynamicStatus == _selectedStatusFilter;

                    return matchesSearch && matchesCategory && matchesStatus;
                  }).toList();

                  // Sorting
                  filteredDocs.sort((a, b) {
                    final dA = a.data() as Map<String, dynamic>;
                    final dB = b.data() as Map<String, dynamic>;
                    int cmp = 0;

                    if (_sortColumnIndex == 0) {
                      cmp = (dA['complianceName'] ?? '').compareTo(dB['complianceName'] ?? '');
                    } else if (_sortColumnIndex == 5) {
                      final tA = dA['expiryDate'] as Timestamp?;
                      final tB = dB['expiryDate'] as Timestamp?;
                      if (tA == null && tB == null) cmp = 0;
                      else if (tA == null) cmp = 1;
                      else if (tB == null) cmp = -1;
                      else cmp = tA.toDate().compareTo(tB.toDate());
                    }
                    return _sortAscending ? cmp : -cmp;
                  });

                  // KPIs
                  int total = allDocs.length;
                  int active = 0, expiring = 0, expired = 0, policies = 0, contracts = 0;

                  for (var d in allDocs) {
                    final data = d.data() as Map<String, dynamic>;
                    final expiry = data['expiryDate'] is Timestamp ? (data['expiryDate'] as Timestamp).toDate() : null;
                    final stat = _calculateStatus(expiry);
                    final cat = data['category'];

                    if (stat == 'Active') active++;
                    if (stat == 'Expiring Soon') expiring++;
                    if (stat == 'Expired') expired++;
                    if (cat == 'Policy') policies++;
                    if (cat == 'Contract') contracts++;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // KPI Row
                      Row(
                        children: [
                          _buildKPICard('Total', total, zBlue),
                          const SizedBox(width: 8),
                          _buildKPICard('Active', active, Colors.green),
                          const SizedBox(width: 8),
                          _buildKPICard('Expiring Soon', expiring, zOrange),
                          const SizedBox(width: 8),
                          _buildKPICard('Expired', expired, Colors.red),
                          const SizedBox(width: 8),
                          _buildKPICard('Policies', policies, zText),
                          const SizedBox(width: 8),
                          _buildKPICard('Contracts', contracts, zText),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filters Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: zBorder)),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Search by name, reg, authority...',
                                    hintStyle: TextStyle(fontSize: 13, color: zMuted),
                                    prefixIcon: Icon(Icons.search, size: 16, color: zMuted),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: zBorder)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: DropdownButtonFormField<String>(
                                  style: TextStyle(fontSize: 13, color: zText),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: zBorder)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  ),
                                  value: _selectedCategory,
                                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: DropdownButtonFormField<String>(
                                  style: TextStyle(fontSize: 13, color: zText),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: zBorder)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  ),
                                  value: _selectedStatusFilter,
                                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (val) => setState(() => _selectedStatusFilter = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Enterprise DataTable
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: zBorder)),
                          child: filteredDocs.isEmpty
                              ? Center(child: Text('No compliance records found.', style: TextStyle(color: zMuted, fontSize: 13)))
                              : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                                dataRowMinHeight: 40, // Dense layout
                                dataRowMaxHeight: 52,
                                columnSpacing: 16,
                                horizontalMargin: 12,
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _sortAscending,
                                headingTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: zMuted),
                                dataTextStyle: TextStyle(fontSize: 13, color: zText),
                                columns: [
                                  DataColumn(label: const Text('Compliance Name'), onSort: _onSort),
                                  const DataColumn(label: Text('Category')),
                                  const DataColumn(label: Text('Reg. Number')),
                                  const DataColumn(label: Text('Authority')),
                                  const DataColumn(label: Text('Issue Date')),
                                  DataColumn(label: const Text('Expiry Date'), onSort: _onSort),
                                  const DataColumn(label: Text('Days Left')),
                                  const DataColumn(label: Text('Status')),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: filteredDocs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final expiryTimestamp = data['expiryDate'] as Timestamp?;
                                  final expiryDate = expiryTimestamp?.toDate();
                                  final status = _calculateStatus(expiryDate);
                                  final daysRemaining = _getDaysRemaining(expiryDate);

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(data['complianceName'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(data['category'] ?? '-')),
                                      DataCell(Text(data['registrationNumber'] ?? '-')),
                                      DataCell(Text(data['authority'] ?? '-')),
                                      DataCell(Text(_formatDate(data['issueDate']))),
                                      DataCell(Text(_formatDate(expiryTimestamp))),
                                      DataCell(_buildDaysBadge(daysRemaining)),
                                      DataCell(_buildStatusBadge(status)),
                                      DataCell(
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert, size: 18, color: zMuted),
                                          splashRadius: 20,
                                          onSelected: (value) {
                                            if (value == 'Edit') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ScreensAddComplianceLegal(
                                                    companyId: widget.companyId,
                                                    docId: doc.id,
                                                    existingData: data,
                                                  ),
                                                ),
                                              );
                                            } else if (value == 'Delete') {
                                              _deleteRecord(doc.id);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'Edit', height: 36, child: Text('Edit', style: TextStyle(fontSize: 13))),
                                            PopupMenuItem(value: 'Delete', height: 36, child: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13))),
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
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}