// UI REVISION V2: Reference and Created columns removed; status is single-line; created date appears under creator.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_screen.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_invoice_pdf_generator.dart';


// =========================================================
// ENTERPRISE PROFORMA WORKSPACE THEME
// =========================================================
const Color _zSlate50 = Color(0xFFF8FAFC);
const Color _zSlate100 = Color(0xFFF1F5F9);
const Color _zSlate200 = Color(0xFFE2E8F0);
const Color _zSlate300 = Color(0xFFCBD5E1);
const Color _zSlate400 = Color(0xFF94A3B8);
const Color _zSlate500 = Color(0xFF64748B);
const Color _zSlate600 = Color(0xFF475569);
const Color _zSlate700 = Color(0xFF334155);
const Color _zSlate800 = Color(0xFF1E293B);
const Color _zSoftHoverBorder = Color(0xFFB8C7D9);
const Color _zErpPrimaryBlue = Color(0xFF2F6EA5);

const double _proformaGridMinWidth = 1040;
const double _proformaGridHorizontalPadding = 12;
const double _proformaGridActionWidth = 48;
const int _proformaCustomerFlex = 34;
const int _proformaStatusFlex = 10;
const int _proformaItemsFlex = 19;
const int _proformaAmountFlex = 14;
const int _proformaOwnerFlex = 14;
const int _proformaFollowUpFlex = 9;

class ProformaListScreen extends StatefulWidget {
  final String companyId;

  const ProformaListScreen({super.key, required this.companyId});

  @override
  State<ProformaListScreen> createState() => _ProformaListScreenState();
}

class _ProformaListScreenState extends State<ProformaListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');

  String _searchText = '';
  String _statusFilter = 'All';
  String _sortOption = 'Date: Newest';
  bool _isLoading = false;

  final Map<String, String> _userNamesCache = {};

  final List<String> _statuses = [
    'All',
    'Draft',
    'Sent',
    'Approved',
    'Converted',
    'Cancelled',
    'Rejected',
  ];

  final List<String> _sortOptions = [
    'Date: Newest',
    'Date: Oldest',
    'Amount: High to Low',
    'Amount: Low to High',
  ];

  @override
  void dispose() {
    _searchNotifier.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // HELPER FUNCTIONS & FORMATTING
  // ==========================================

  bool get _hasActiveFilters =>
      _statusFilter != 'All' || _sortOption != 'Date: Newest';

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _sortOption = 'Date: Newest';
    });
  }

  void _showLoading(bool show) {
    if (mounted) {
      setState(() => _isLoading = show);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmAction(
      String title,
      String content, {
        String confirmText = 'Confirm',
        bool isDestructive = false,
      }) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ??
        false;
  }

  // ==========================================
  // USER NAME CACHING LOGIC
  // ==========================================

  String _getCreatorName(Map<String, dynamic> data) {
    final String createdByName = (data['createdByName'] ?? '')
        .toString()
        .trim();
    if (createdByName.isNotEmpty) return createdByName;

    final String uid = (data['createdBy'] ?? '').toString().trim();
    if (uid.isEmpty) return 'Unknown';

    if (_userNamesCache.containsKey(uid)) {
      return _userNamesCache[uid]!;
    }

    _fetchAndCacheUserName(uid);
    return 'Fetching...';
  }

  Future<void> _fetchAndCacheUserName(String uid) async {
    _userNamesCache[uid] = 'Fetching...';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final name =
        (doc.data()!['name'] ?? doc.data()!['fullName'] ?? 'Unknown')
            .toString()
            .trim();
        if (mounted) {
          setState(() {
            _userNamesCache[uid] = name.isNotEmpty ? name : 'Unknown';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userNamesCache[uid] = 'Unknown';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userNamesCache[uid] = 'Unknown';
        });
      }
    }
  }

  // ==========================================
  // PROFORMA ACTION LOGIC (ENTERPRISE GRADE)
  // ==========================================

  Future<void> _updateStatus(
      String docId,
      String newStatus, {
        bool setApprovedAt = false,
      }) async {
    try {
      _showLoading(true);
      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (setApprovedAt) {
        updates['approvedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .doc(docId)
          .update(updates);

      _showSnack('Proforma marked as $newStatus');
    } catch (e) {
      _showSnack('Error updating status: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  Future<void> _deleteProforma(String docId) async {
    try {
      _showLoading(true);
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .doc(docId)
          .update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnack('Proforma invoice deleted');
    } catch (e) {
      _showSnack('Error deleting: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  Future<void> _createRevision(String docId, Map<String, dynamic> data) async {
    try {
      _showLoading(true);
      final oldNumber = (data['proformaNumber'] ?? '').toString();

      String newNumber = oldNumber;
      if (oldNumber.contains('-R')) {
        final parts = oldNumber.split('-R');
        final base = parts[0];
        final revStr = parts[1];
        final revNum = int.tryParse(revStr) ?? 0;
        newNumber = '$base-R${revNum + 1}';
      } else if (oldNumber.isNotEmpty && oldNumber != 'Draft') {
        newNumber = '$oldNumber-R1';
      }

      final newData = Map<String, dynamic>.from(data);
      newData.remove('id');
      newData['proformaNumber'] = newNumber;
      newData['status'] = 'Draft';
      newData['referenceProformaId'] = docId;
      newData['createdAt'] = FieldValue.serverTimestamp();
      newData['updatedAt'] = FieldValue.serverTimestamp();
      newData.remove('approvedAt');
      newData.remove('invoiceId');

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .add(newData);

      _showSnack('Revision $newNumber created successfully');
    } catch (e) {
      _showSnack('Error creating revision: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  Future<void> _convertToInvoice(
      String docId,
      Map<String, dynamic> data,
      ) async {
    try {
      _showLoading(true);

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final invoiceRef = db
          .collection('companies')
          .doc(widget.companyId)
          .collection('invoices')
          .doc();

      final invoiceData = {
        'customerId': data['customerId'],
        'customerName': data['customerName'] ?? data['clientName'],
        'items': data['items'] ?? [],
        'grandTotal': data['grandTotal'] ?? data['totalAmount'] ?? 0,
        'taxAmount': data['taxAmount'] ?? 0,
        'subTotal': data['subTotal'] ?? 0,
        'status': 'Draft',
        'proformaId': docId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': data['createdBy'],
        'createdByName': data['createdByName'],
        'isDeleted': false,
      };

      batch.set(invoiceRef, invoiceData);

      final proformaRef = db
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .doc(docId);

      batch.update(proformaRef, {
        'status': 'Converted',
        'invoiceId': invoiceRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _showSnack('Successfully converted to Invoice');
    } catch (e) {
      _showSnack('Error converting to invoice: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  Future<void> _openFilterSheet() async {
    String tempStatus = _statusFilter;
    String tempSort = _sortOption;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters & Sort',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: tempStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _statuses
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                      )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempStatus = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: tempSort,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _sortOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                      )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempSort = value ?? 'Date: Newest';
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'All';
                                _sortOption = 'Date: Newest';
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = tempStatus;
                                _sortOption = tempSort;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Apply'),
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final search = _searchText.trim().toLowerCase();

    var filtered = docs.where((doc) {
      final data = doc.data();

      final piNumber = (data['proformaNumber'] ?? '').toString().toLowerCase();
      final customer = (data['customerName'] ?? data['clientName'] ?? '')
          .toString()
          .toLowerCase();
      final status = (data['status'] ?? 'Draft').toString();
      final isDeleted = data['isDeleted'] == true;

      final matchesSearch =
          search.isEmpty ||
              piNumber.contains(search) ||
              customer.contains(search);
      final matchesStatus =
          _statusFilter == 'All' ||
              status.toLowerCase() == _statusFilter.toLowerCase();

      return !isDeleted && matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      if (_sortOption.startsWith('Amount')) {
        final amtA =
            double.tryParse(
              (dataA['grandTotal'] ?? dataA['totalAmount'] ?? 0).toString(),
            ) ??
                0;
        final amtB =
            double.tryParse(
              (dataB['grandTotal'] ?? dataB['totalAmount'] ?? 0).toString(),
            ) ??
                0;
        return _sortOption.contains('High')
            ? amtB.compareTo(amtA)
            : amtA.compareTo(amtB);
      } else {
        final dateA =
            (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final dateB =
            (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return _sortOption.contains('Newest')
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      }
    });

    return filtered;
  }


  void _onSearchChanged(String value) {
    if (_searchNotifier.value == value) return;
    _searchText = value;
    _searchNotifier.value = value;
  }

  void _clearSearch() {
    _searchController.clear();
    _searchText = '';
    _searchNotifier.value = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _openProformaEditor(String docId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProformaScreen(
          companyId: widget.companyId,
          proformaId: docId,
        ),
      ),
    );
  }

  Future<void> _openProformaPreview(
      String docId,
      Map<String, dynamic> data,
      ) async {
    final previewData = Map<String, dynamic>.from(data);
    previewData['id'] = docId;

    List<ProformaLocalItem> parsedItems = <ProformaLocalItem>[];
    final rawItems = previewData['items'];
    if (rawItems is List) {
      try {
        parsedItems = rawItems
            .whereType<Map>()
            .map(
              (item) => ProformaLocalItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
            .toList();
      } catch (_) {
        parsedItems = <ProformaLocalItem>[];
      }
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProformaPreviewScreen(
          data: previewData,
          items: parsedItems,
        ),
      ),
    );
  }

  Future<void> _handleProformaAction(
      String value,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    final data = doc.data();

    switch (value) {
      case 'edit':
        await _openProformaEditor(doc.id);
        break;
      case 'view_pdf':
        await _openProformaPreview(doc.id, data);
        break;
      case 'approve':
        final confirm = await _confirmAction(
          'Approve Proforma',
          'Are you sure you want to approve this proforma invoice?',
        );
        if (confirm) {
          await _updateStatus(
            doc.id,
            'Approved',
            setApprovedAt: true,
          );
        }
        break;
      case 'reject':
        final confirm = await _confirmAction(
          'Reject Proforma',
          'Are you sure you want to reject this proforma invoice?',
        );
        if (confirm) {
          await _updateStatus(doc.id, 'Rejected');
        }
        break;
      case 'cancel':
        final confirm = await _confirmAction(
          'Cancel Proforma',
          'Are you sure you want to cancel this proforma invoice?',
        );
        if (confirm) {
          await _updateStatus(doc.id, 'Cancelled');
        }
        break;
      case 'revise':
        final confirm = await _confirmAction(
          'Create Revision',
          'Are you sure you want to create a new revision from this proforma?',
        );
        if (confirm) {
          await _createRevision(doc.id, data);
        }
        break;
      case 'convert':
        final confirm = await _confirmAction(
          'Convert to Invoice',
          'Are you sure you want to convert this Proforma into a final Tax Invoice?',
        );
        if (confirm) {
          await _convertToInvoice(doc.id, data);
        }
        break;
      case 'delete':
        final confirm = await _confirmAction(
          'Delete Proforma',
          'Are you sure you want to delete this proforma invoice?',
          confirmText: 'Delete',
          isDestructive: true,
        );
        if (confirm) {
          await _deleteProforma(doc.id);
        }
        break;
    }
  }

  Widget _buildWorkspaceHeader({
    required String searchValue,
    required int total,
    required int draft,
    required int sent,
    required int approved,
    required int converted,
    required String totalValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _zSlate200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compactToolbar = constraints.maxWidth < 980;
          final Widget searchBox = _buildToolbarSearchBox(searchValue);
          final Widget kpiBar = _buildToolbarKpiBar(
            total: total,
            draft: draft,
            sent: sent,
            approved: approved,
            converted: converted,
            totalValue: totalValue,
          );
          final Widget actions = _buildToolbarActions();

          if (compactToolbar) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchBox,
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: kpiBar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    actions,
                  ],
                ),
              ],
            );
          }

          final double searchWidth = constraints.maxWidth < 1250 ? 280 : 330;
          return Row(
            children: [
              SizedBox(width: searchWidth, child: searchBox),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: kpiBar,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbarSearchBox(String searchValue) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 11, color: _zSlate700),
        decoration: InputDecoration(
          hintText: 'Search proforma number or customer...',
          hintStyle: const TextStyle(color: _zSlate400, fontSize: 10.8),
          prefixIcon: const Icon(Icons.search, size: 14, color: _zSlate400),
          prefixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIcon: searchValue.trim().isEmpty
              ? null
              : IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.close, size: 13, color: _zSlate500),
            padding: EdgeInsets.zero,
            onPressed: _clearSearch,
          ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _zSlate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _zSlate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _zSlate300),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarKpiBar({
    required int total,
    required int draft,
    required int sent,
    required int approved,
    required int converted,
    required String totalValue,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnterpriseProformaKpi(title: 'Total', value: total.toString()),
        const SizedBox(width: 16),
        _EnterpriseProformaKpi(title: 'Value', value: totalValue),
        const SizedBox(width: 16),
        _EnterpriseProformaKpi(title: 'Draft', value: draft.toString()),
        const SizedBox(width: 16),
        _EnterpriseProformaKpi(title: 'Sent', value: sent.toString()),
        const SizedBox(width: 16),
        _EnterpriseProformaKpi(title: 'Approved', value: approved.toString()),
        const SizedBox(width: 16),
        _EnterpriseProformaKpi(title: 'Converted', value: converted.toString()),
      ],
    );
  }

  Widget _buildToolbarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProformaToolbarButton(
          icon: Icons.filter_list_rounded,
          label: _hasActiveFilters ? 'Filters (Active)' : 'Filters',
          isActive: _hasActiveFilters,
          onTap: _openFilterSheet,
        ),
      ],
    );
  }

  Widget _buildActiveFiltersSummary() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    final List<Widget> chips = <Widget>[];

    Widget buildChip(String label, VoidCallback onClear) {
      return Container(
        height: 22,
        padding: const EdgeInsets.only(left: 8, right: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _zSlate200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _zSlate600,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(1),
                child: Icon(Icons.close, size: 11, color: _zSlate400),
              ),
            ),
          ],
        ),
      );
    }

    if (_statusFilter != 'All') {
      chips.add(
        buildChip('Status: $_statusFilter', () {
          setState(() => _statusFilter = 'All');
        }),
      );
    }
    if (_sortOption != 'Date: Newest') {
      chips.add(
        buildChip('Sort: $_sortOption', () {
          setState(() => _sortOption = 'Date: Newest');
        }),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: const BoxDecoration(
        color: _zSlate50,
        border: Border(bottom: BorderSide(color: _zSlate100)),
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: Text(
              'Active filters',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _zSlate500,
              ),
            ),
          ),
          ...chips,
          InkWell(
            onTap: _resetFilters,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'Clear all',
                style: TextStyle(
                  fontSize: 10,
                  color: _zSlate600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(
        horizontal: _proformaGridHorizontalPadding,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FA),
        border: Border(bottom: BorderSide(color: _zSlate300, width: 0.9)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: _proformaCustomerFlex,
            child: _ProformaHeaderText('Proforma / Customer'),
          ),
          Expanded(
            flex: _proformaStatusFlex,
            child: _ProformaHeaderText('Status'),
          ),
          Expanded(
            flex: _proformaItemsFlex,
            child: _ProformaHeaderText('Items'),
          ),
          Expanded(
            flex: _proformaAmountFlex,
            child: _ProformaHeaderText('Amount'),
          ),
          Expanded(
            flex: _proformaOwnerFlex,
            child: _ProformaHeaderText('Created By'),
          ),
          Expanded(
            flex: _proformaFollowUpFlex,
            child: _ProformaHeaderText('Follow-up'),
          ),
          SizedBox(
            width: _proformaGridActionWidth,
            child: Center(child: _ProformaHeaderText('Actions')),
          ),
        ],
      ),
    );
  }

  String _compactMoney(double value) {
    final double absolute = value.abs();
    if (absolute >= 10000000) {
      return '₹ ${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (absolute >= 100000) {
      return '₹ ${(value / 100000).toStringAsFixed(2)} L';
    }
    if (absolute >= 1000) {
      return '₹ ${(value / 1000).toStringAsFixed(1)} K';
    }
    return '₹ ${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 6,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          floatingActionButton: SizedBox(
            width: 52,
            height: 52,
            child: FloatingActionButton(
              tooltip: 'Create Proforma Invoice',
              backgroundColor: _zErpPrimaryBlue,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProformaScreen(companyId: widget.companyId),
                  ),
                );
              },
              child: const Icon(Icons.add, size: 18),
            ),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('companies')
                .doc(widget.companyId)
                .collection('proforma_invoices')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading proforma invoices:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8A4F4F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ProformaLoadingWorkspace();
              }

              final allDocs = snapshot.data?.docs.toList() ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              return ValueListenableBuilder<String>(
                valueListenable: _searchNotifier,
                builder: (context, searchValue, _) {
                  final filteredDocs = _applyLocalFilters(allDocs);

                  int draft = 0;
                  int sent = 0;
                  int approved = 0;
                  int converted = 0;
                  double totalValue = 0;

                  for (final doc in filteredDocs) {
                    final data = doc.data();
                    final status = (data['status'] ?? '')
                        .toString()
                        .toLowerCase();
                    totalValue += double.tryParse(
                      (data['grandTotal'] ?? data['totalAmount'] ?? 0)
                          .toString()
                          .replaceAll(',', ''),
                    ) ??
                        0;

                    if (status == 'draft') draft++;
                    if (status == 'sent') sent++;
                    if (status == 'approved') approved++;
                    if (status == 'converted') converted++;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWorkspaceHeader(
                        searchValue: searchValue,
                        total: filteredDocs.length,
                        draft: draft,
                        sent: sent,
                        approved: approved,
                        converted: converted,
                        totalValue: _compactMoney(totalValue),
                      ),
                      _buildActiveFiltersSummary(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double tableWidth =
                            constraints.maxWidth < _proformaGridMinWidth
                                ? _proformaGridMinWidth
                                : constraints.maxWidth;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildTableHeader(),
                                    Expanded(
                                      child: filteredDocs.isEmpty
                                          ? _EmptyProformaState(
                                        hasSearch:
                                        searchValue.trim().isNotEmpty ||
                                            _hasActiveFilters,
                                        onReset: () {
                                          _clearSearch();
                                          _resetFilters();
                                        },
                                      )
                                          : ListView.builder(
                                        padding: const EdgeInsets.only(
                                          bottom: 92,
                                        ),
                                        itemCount: filteredDocs.length,
                                        itemBuilder: (context, index) {
                                          final doc = filteredDocs[index];
                                          return _EnterpriseProformaRow(
                                            key: ValueKey(doc.id),
                                            document: doc,
                                            creatorName: _getCreatorName(
                                              doc.data(),
                                            ),
                                            onEdit: () =>
                                                _openProformaEditor(doc.id),
                                            onView: () =>
                                                _openProformaPreview(
                                                  doc.id,
                                                  doc.data(),
                                                ),
                                            onAction: (value) =>
                                                _handleProformaAction(
                                                  value,
                                                  doc,
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.28),
            child: const Center(
              child: CircularProgressIndicator(color: _zErpPrimaryBlue),
            ),
          ),
      ],
    );
  }
}

class _ProformaHeaderText extends StatelessWidget {
  final String label;

  const _ProformaHeaderText(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(
        fontSize: 10.1,
        fontWeight: FontWeight.w600,
        color: _zSlate600,
        letterSpacing: 0.04,
      ),
    );
  }
}

class _ProformaToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ProformaToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? _zSlate100 : Colors.white,
          border: Border.all(color: isActive ? _zSlate300 : _zSlate200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? _zSlate700 : _zSlate500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isActive ? _zSlate700 : _zSlate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterpriseProformaKpi extends StatelessWidget {
  final String title;
  final String value;

  const _EnterpriseProformaKpi({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10.2,
            color: _zSlate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _zSlate700,
          ),
        ),
      ],
    );
  }
}

class _ProformaLoadingWorkspace extends StatelessWidget {
  const _ProformaLoadingWorkspace();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth < _proformaGridMinWidth
            ? _proformaGridMinWidth
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 42,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _zSlate200)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 30,
                        color: const Color(0xFFF4F7FA),
                      ),
                      const Expanded(
                        child: _ProformaSkeletonList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProformaSkeletonList extends StatelessWidget {
  const _ProformaSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 12,
      itemBuilder: (context, index) => _ProformaSkeletonRow(index: index),
    );
  }
}

class _ProformaSkeletonRow extends StatelessWidget {
  final int index;

  const _ProformaSkeletonRow({required this.index});

  Widget _block(double width, {double height = 8}) {
    return Container(
      width: width * (0.78 + (index % 3) * 0.09),
      height: height,
      decoration: BoxDecoration(
        color: _zSlate100,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _twoBlocks(double first, double second) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _block(first, height: 9),
        const SizedBox(height: 5),
        _block(second, height: 7),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(
        horizontal: _proformaGridHorizontalPadding,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _zSlate100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _proformaCustomerFlex,
            child: _twoBlocks(180, 130),
          ),
          Expanded(
            flex: _proformaStatusFlex,
            child: _block(65),
          ),
          Expanded(
            flex: _proformaItemsFlex,
            child: _twoBlocks(110, 70),
          ),
          Expanded(
            flex: _proformaAmountFlex,
            child: _twoBlocks(90, 58),
          ),
          Expanded(
            flex: _proformaOwnerFlex,
            child: _twoBlocks(90, 58),
          ),
          Expanded(
            flex: _proformaFollowUpFlex,
            child: _block(65),
          ),
          const SizedBox(
            width: _proformaGridActionWidth,
            child: Icon(Icons.more_vert, size: 15, color: _zSlate200),
          ),
        ],
      ),
    );
  }
}

class _EnterpriseProformaRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final String creatorName;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final ValueChanged<String> onAction;

  const _EnterpriseProformaRow({
    super.key,
    required this.document,
    required this.creatorName,
    required this.onEdit,
    required this.onView,
    required this.onAction,
  });

  @override
  State<_EnterpriseProformaRow> createState() =>
      _EnterpriseProformaRowState();
}

class _EnterpriseProformaRowState extends State<_EnterpriseProformaRow> {
  bool _isHovered = false;

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
      value?.toString().replaceAll(',', '').trim() ?? '',
    ) ??
        0;
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String _dateText(dynamic value) {
    final DateTime? date = _toDate(value);
    if (date == null) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _titleCase(String value, {String fallback = '-'}) {
    final String text = value.trim();
    if (text.isEmpty) return fallback;
    return text
        .split(RegExp(r'[\s_]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
      '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
    )
        .join(' ');
  }

  String _quantityText(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'converted':
        return const Color(0xFF56745D);
      case 'sent':
      case 'viewed':
        return const Color(0xFF557495);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFF8A4F4F);
      case 'draft':
        return const Color(0xFF806B4B);
      default:
        return _zSlate600;
    }
  }

  List<dynamic> _items(Map<String, dynamic> data) {
    final raw = data['items'];
    return raw is List ? raw : const <dynamic>[];
  }

  String _firstItemName(List<dynamic> items) {
    if (items.isEmpty) return 'No items';
    final first = items.first;
    if (first is Map) {
      return _safeString(
        first['name'] ??
            first['itemName'] ??
            first['productName'] ??
            first['description'],
        fallback: 'Item',
      );
    }
    return _safeString(first, fallback: 'Item');
  }

  double _totalQuantity(List<dynamic> items) {
    double total = 0;
    for (final item in items) {
      if (item is Map) {
        total += _toDouble(item['quantity'] ?? item['qty']);
      }
    }
    return total;
  }

  String _firstUnit(List<dynamic> items) {
    if (items.isEmpty || items.first is! Map) return '';
    final first = items.first as Map;
    return _safeString(first['uom'] ?? first['unit']);
  }

  String _money(double value) {
    return '₹ ${value.toStringAsFixed(2)}';
  }

  Widget _twoLineText({
    required String primary,
    required String secondary,
    Color primaryColor = _zSlate700,
    Color secondaryColor = _zSlate500,
    FontWeight primaryWeight = FontWeight.w500,
    VoidCallback? onPrimaryTap,
  }) {
    final Widget primaryWidget = Text(
      primary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(
        fontSize: 11,
        height: 1.08,
        color: primaryColor,
        fontWeight: primaryWeight,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onPrimaryTap == null)
            primaryWidget
          else
            InkWell(
              onTap: onPrimaryTap,
              borderRadius: BorderRadius.circular(3),
              child: primaryWidget,
            ),
          const SizedBox(height: 3),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 9.8,
              height: 1.05,
              color: secondaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenu(String status) {
    final String statLw = status.toLowerCase();
    final List<PopupMenuEntry<String>> menuItems =
    <PopupMenuEntry<String>>[];

    if (statLw == 'draft' || statLw == 'rejected') {
      menuItems.add(
        const PopupMenuItem(
          value: 'edit',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit',
          ),
        ),
      );
    } else if (statLw == 'sent') {
      menuItems.add(
        const PopupMenuItem(
          value: 'edit',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.edit_note_outlined,
            label: 'View / Edit',
          ),
        ),
      );
    } else if (statLw == 'approved' ||
        statLw == 'converted' ||
        statLw == 'cancelled') {
      menuItems.add(
        const PopupMenuItem(
          value: 'view_pdf',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.visibility_outlined,
            label: 'View',
          ),
        ),
      );
    } else {
      menuItems.add(
        const PopupMenuItem(
          value: 'edit',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.edit_note_outlined,
            label: 'View / Edit',
          ),
        ),
      );
    }

    if (statLw == 'draft' || statLw == 'sent') {
      menuItems.add(const PopupMenuDivider(height: 8));
      menuItems.add(
        const PopupMenuItem(
          value: 'approve',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.check_circle_outline,
            label: 'Approve',
          ),
        ),
      );
      menuItems.add(
        const PopupMenuItem(
          value: 'reject',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.highlight_off_outlined,
            label: 'Reject',
          ),
        ),
      );
    }

    if (statLw != 'cancelled' && statLw != 'converted') {
      menuItems.add(
        const PopupMenuItem(
          value: 'cancel',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.cancel_outlined,
            label: 'Cancel',
            destructive: true,
          ),
        ),
      );
    }

    menuItems.add(const PopupMenuDivider(height: 8));
    menuItems.add(
      const PopupMenuItem(
        value: 'revise',
        height: 32,
        child: _ProformaMenuItem(
          icon: Icons.copy_all_outlined,
          label: 'Create Revision',
        ),
      ),
    );

    if (statLw != 'converted' &&
        statLw != 'cancelled' &&
        statLw != 'rejected') {
      menuItems.add(
        const PopupMenuItem(
          value: 'convert',
          height: 32,
          child: _ProformaMenuItem(
            icon: Icons.receipt_long_outlined,
            label: 'Convert to Invoice',
          ),
        ),
      );
    }

    menuItems.add(const PopupMenuDivider(height: 8));
    menuItems.add(
      const PopupMenuItem(
        value: 'delete',
        height: 32,
        child: _ProformaMenuItem(
          icon: Icons.delete_outline,
          label: 'Delete',
          destructive: true,
        ),
      ),
    );

    return menuItems;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data();

    final String proformaNo = _safeString(
      data['proformaNumber'],
      fallback: 'Draft',
    );
    final String customerName = _safeString(
      data['customerName'] ?? data['clientName'],
      fallback: 'Unknown Customer',
    );
    final String status = _safeString(data['status'], fallback: 'Draft');
    final String statusLower = status.toLowerCase();

    String reference = _safeString(data['referenceNumber']);
    String referenceType = 'Reference';
    if (reference.isEmpty) {
      reference = _safeString(data['quotationNumber']);
      referenceType = 'Quotation';
    }
    if (reference.isEmpty) {
      reference = _safeString(data['inquiryNumber']);
      referenceType = 'Inquiry';
    }
    if (reference.isEmpty) {
      reference = '-';
      referenceType = 'No linked reference';
    }

    final List<dynamic> items = _items(data);
    final String firstItem = _firstItemName(items);
    final double totalQuantity = _totalQuantity(items);
    final String unit = _firstUnit(items);
    final String itemSummary = items.isEmpty
        ? 'No items'
        : '$firstItem${items.length > 1 ? ' +${items.length - 1}' : ''}';
    final String quantitySummary = items.isEmpty
        ? '-'
        : 'Qty ${_quantityText(totalQuantity)}${unit.isEmpty ? '' : ' $unit'}';

    final double grandTotal = _toDouble(
      data['grandTotal'] ?? data['totalAmount'],
    );
    final double advance = _toDouble(data['advanceAmount']);
    final double balance = _toDouble(data['balanceAmount']);
    final String amountSecondary = advance > 0 || balance > 0
        ? 'Advance ${_money(advance)} • Bal ${_money(balance)}'
        : '${items.length} item${items.length == 1 ? '' : 's'}';

    final String createdDate = _dateText(data['createdAt']);
    final String followUpDate = _dateText(data['nextFollowUpDate']);

    final bool opensPreview = statusLower == 'approved' ||
        statusLower == 'converted' ||
        statusLower == 'cancelled';

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 54,
          padding: const EdgeInsets.symmetric(
            horizontal: _proformaGridHorizontalPadding,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFFBFCFE) : Colors.white,
            border: Border(
              bottom: const BorderSide(color: _zSlate100),
              left: BorderSide(
                color: _isHovered ? _zSoftHoverBorder : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: _proformaCustomerFlex,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: InkWell(
                              onTap: opensPreview ? widget.onView : widget.onEdit,
                              borderRadius: BorderRadius.circular(3),
                              child: Text(
                                proformaNo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.8,
                                  height: 1.08,
                                  fontWeight: FontWeight.w700,
                                  color: _zErpPrimaryBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: InkWell(
                              onTap: opensPreview ? widget.onView : widget.onEdit,
                              borderRadius: BorderRadius.circular(3),
                              child: Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.08,
                                  fontWeight: FontWeight.w600,
                                  color: _zSlate800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reference == '-'
                            ? 'No source reference'
                            : '$referenceType: $reference',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.8,
                          height: 1.05,
                          color: _zSlate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: _proformaStatusFlex,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _titleCase(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.08,
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _proformaItemsFlex,
                child: _twoLineText(
                  primary: itemSummary,
                  secondary: quantitySummary,
                ),
              ),
              Expanded(
                flex: _proformaAmountFlex,
                child: _twoLineText(
                  primary: _money(grandTotal),
                  secondary: amountSecondary,
                  primaryColor: _zSlate800,
                  primaryWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                flex: _proformaOwnerFlex,
                child: _twoLineText(
                  primary: widget.creatorName,
                  secondary: 'Created: $createdDate',
                ),
              ),
              Expanded(
                flex: _proformaFollowUpFlex,
                child: Text(
                  followUpDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.7,
                    color: followUpDate == '-' ? _zSlate400 : _zSlate600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: _proformaGridActionWidth,
                child: Center(
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Actions',
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: _isHovered
                          ? _zSlate600
                          : _zSlate400.withValues(alpha: 0.62),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: _zSlate200),
                    ),
                    onSelected: widget.onAction,
                    itemBuilder: (context) => _buildMenu(status),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProformaMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _ProformaMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = destructive ? const Color(0xFF8A4F4F) : _zSlate700;
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: color),
        ),
      ],
    );
  }
}

class _EmptyProformaState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyProformaState({required this.hasSearch, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.request_quote_outlined,
              size: 44,
              color: _zSlate300,
            ),
            const SizedBox(height: 14),
            Text(
              hasSearch
                  ? 'No matching proforma invoices found'
                  : 'No proforma invoices found',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _zSlate700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'Try adjusting the search text or active filters.'
                  : 'Create a proforma invoice to begin tracking this workflow.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _zSlate500),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _zSlate300),
                  foregroundColor: _zSlate700,
                ),
                child: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
