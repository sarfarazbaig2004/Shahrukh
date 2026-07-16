import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';
import 'quotation_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);

// Enterprise quotation workspace palette.
const Color _zSlate50 = Color(0xFFF8FAFC);
const Color _zSlate100 = Color(0xFFF1F5F9);
const Color _zSlate200 = Color(0xFFE2E8F0);
const Color _zSlate300 = Color(0xFFCBD5E1);
const Color _zSlate400 = Color(0xFF94A3B8);
const Color _zSlate500 = Color(0xFF64748B);
const Color _zSlate600 = Color(0xFF475569);
const Color _zSlate700 = Color(0xFF334155);
const Color _zSlate800 = Color(0xFF1E293B);
const Color _zSlate900 = Color(0xFF0F172A);
const Color _zSoftHoverBorder = Color(0xFFB8C7D9);
const Color _zErpPrimaryBlue = Color(0xFF2F6EA5);

const double _quotationGridMinWidth = 1180;
const double _quotationGridHorizontalPadding = 12;
const double _quotationGridActionWidth = 48;
const int _quotationCustomerFlex = 30;
const int _quotationStatusFlex = 11;
const int _quotationItemsFlex = 18;
const int _quotationAmountFlex = 12;
const int _quotationOwnerFlex = 12;
const int _quotationCreatedFlex = 9;
const int _quotationFollowUpFlex = 9;

const String _kCollectionCompanies = 'companies';
const String _kCollectionUsers = 'users';
const String _kCollectionQuotations = 'quotations';

class ScreensQuotationList extends StatefulWidget {
  final int userId;

  const ScreensQuotationList({super.key, required this.userId});

  @override
  State<ScreensQuotationList> createState() => _ScreensQuotationListState();
}

class _ScreensQuotationListState extends State<ScreensQuotationList> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');

  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  String _currentUserName = '';
  bool _isLoadingContext = true;
  String? _errorMessage;

  String _searchText = '';
  String _statusFilter = 'All';
  String _sortOption = 'Date: Newest';

  final Map<String, bool> _convertingDocs = {};
  final Map<String, String> _userNameCache = {};

  final List<String> _statuses = [
    'All',
    'Draft',
    'Sent',
    'Viewed',
    'Follow-up',
    'Negotiation',
    'Approved',
    'Rejected',
    'Converted',
    'Cancelled',
  ];

  final List<String> _sortOptions = [
    'Date: Newest',
    'Date: Oldest',
    'Amount: High to Low',
    'Amount: Low to High',
  ];

  Query<Map<String, dynamic>>? _primaryQuery;
  CollectionReference<Map<String, dynamic>>? _quotationCollection;

  bool get _isAdminOrManager {
    final role = _currentUserRole.trim().toLowerCase().replaceAll('_', '');
    return [
      'admin',
      'manager',
      'owner',
      'founder',
      'ceo',
      'superadmin',
      'director',
      'md',
    ].contains(role);
  }

  bool _hasQuotationPermission(Map<String, dynamic> userData) {
    if (_isAdminOrManager) return true;
    final permissions = userData['permissions'];
    if (permissions is Map) {
      final salesPerms = permissions['sales'];
      if (salesPerms is Map && salesPerms['quotations'] is Map) {
        if (salesPerms['quotations']['view'] == true) return true;
      }
      if (permissions['quotations'] == true) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchNotifier.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Do not call setState while typing. On Flutter Web, rebuilding the full
    // quotation StreamBuilder on every keypress can remove focus from TextField.
    // ValueNotifier refreshes only the quotation list/search UI and keeps
    // controller + FocusNode alive.
    if (_searchNotifier.value == value) return;
    _searchText = value;
    _searchNotifier.value = value;
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchText = '';
    _searchNotifier.value = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage =
            'User authentication required. Please log in again.';
            _isLoadingContext = false;
          });
        }
        return;
      }

      _currentUserUid = user.uid;
      final rootUserDoc = await FirebaseFirestore.instance
          .collection(_kCollectionUsers)
          .doc(user.uid)
          .get();
      Map<String, dynamic> userData = rootUserDoc.data() ?? {};

      String resolvedCompanyId = _safeString(userData['activeCompanyId']);
      if (resolvedCompanyId.isEmpty) {
        resolvedCompanyId = _safeString(userData['companyId']);
      }
      if (resolvedCompanyId.isEmpty &&
          userData['companyIds'] is List &&
          (userData['companyIds'] as List).isNotEmpty) {
        resolvedCompanyId = _safeString((userData['companyIds'] as List).first);
      }
      if (resolvedCompanyId.isEmpty &&
          userData['memberships'] is Map &&
          (userData['memberships'] as Map).isNotEmpty) {
        resolvedCompanyId = _safeString(
          (userData['memberships'] as Map).keys.first,
        );
      }

      if (resolvedCompanyId.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage =
            'No active workspace linked. Please join a company first.';
            _isLoadingContext = false;
          });
        }
        return;
      }

      _companyId = resolvedCompanyId;
      _currentUserName = (userData['name'] ?? userData['fullName'] ?? '')
          .toString();

      final companyUserDoc = await FirebaseFirestore.instance
          .collection(_kCollectionCompanies)
          .doc(resolvedCompanyId)
          .collection(_kCollectionUsers)
          .doc(user.uid)
          .get();
      if (companyUserDoc.exists && companyUserDoc.data() != null) {
        userData.addAll(companyUserDoc.data()!);
      }

      _currentUserRole = (userData['role'] ?? 'sales').toString().trim();

      if (!_hasQuotationPermission(userData)) {
        if (mounted) {
          setState(() {
            _errorMessage =
            'Access Denied: You lack permissions to view quotations.';
            _isLoadingContext = false;
          });
        }
        return;
      }

      _setupQueries(resolvedCompanyId);

      if (mounted) {
        setState(() {
          _isLoadingContext = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
          'Failed to load user context safely. Please try again.';
          _isLoadingContext = false;
        });
      }
    }
  }

  void _setupQueries(String companyId) {
    _quotationCollection = FirebaseFirestore.instance
        .collection(_kCollectionCompanies)
        .doc(companyId)
        .collection(_kCollectionQuotations);

    // 🔥 FIX: Remove .where() filters from here.
    // Mixing OR filters + orderBy immediately crashes without a custom index.
    // We now fetch safely and let `_applyLocalFilters` handle the RBAC logic perfectly.
    _primaryQuery = _quotationCollection!.orderBy(
      'createdAt',
      descending: true,
    );
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final str = value.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  String _parseSafeString(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    final str = val.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  Timestamp? _safeTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  String _formatCompactDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _money(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return '₹ ${parsed.toStringAsFixed(2)}';
  }

  Future<String> _getUserName(String uid) async {
    if (uid.isEmpty) return 'Unknown';
    if (_userNameCache.containsKey(uid)) {
      return _userNameCache[uid]!;
    }
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection(_kCollectionUsers)
          .doc(uid)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data();
        final name = _safeString(
          data?['name'] ?? data?['fullName'],
          fallback: 'Unknown',
        );
        _userNameCache[uid] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching user name for $uid: $e');
    }
    _userNameCache[uid] = 'Unknown';
    return 'Unknown';
  }

  Future<void> _openCreateQuotation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuotationScreenLocal(userId: widget.userId, companyId: _companyId),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQuotationForEdit(
      String docId,
      Map<String, dynamic> data,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(
          userId: widget.userId,
          companyId: _companyId,
          quotationId: docId,
          existingQuotation: data,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQuotationPreview(Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
      const Center(child: CircularProgressIndicator(color: primaryColor)),
    );

    try {
      final safeData = Map<String, dynamic>.from(data);

      final quoteDate =
          (safeData['quoteDate'] as Timestamp?)?.toDate() ?? DateTime.now();
      safeData['quoteDateStr'] =
      '${quoteDate.day.toString().padLeft(2, '0')}/${quoteDate.month.toString().padLeft(2, '0')}/${quoteDate.year}';

      if (safeData['companyName'] == null && _companyId != null) {
        final companyDoc = await FirebaseFirestore.instance
            .collection(_kCollectionCompanies)
            .doc(_companyId)
            .get();
        if (companyDoc.exists) {
          final companyData = companyDoc.data() ?? {};

          safeData['companyName'] ??=
              companyData['companyName'] ?? companyData['name'] ?? '';
          safeData['companyAddress'] ??=
              companyData['companyAddress'] ?? companyData['address'] ?? '';
          safeData['companyPhone'] ??=
              companyData['companyPhone'] ?? companyData['phone'] ?? '';
          safeData['companyEmail'] ??=
              companyData['companyEmail'] ?? companyData['email'] ?? '';
          safeData['companyLogoUrl'] ??=
              companyData['companyLogoUrl'] ?? companyData['logoUrl'] ?? '';
          safeData['companyGst'] ??=
              companyData['companyGst'] ??
                  companyData['gstin'] ??
                  companyData['gstNo'] ??
                  '';
          safeData['companyPan'] ??=
              companyData['companyPan'] ?? companyData['pan'] ?? '';
          safeData['companyIec'] ??=
              companyData['companyIec'] ?? companyData['iec'] ?? '';
          safeData['companyWebsite'] ??=
              companyData['companyWebsite'] ?? companyData['website'] ?? '';
        }
      }

      final itemsList = (safeData['items'] is List)
          ? (safeData['items'] as List)
          : [];
      final parsedItems = itemsList
          .map(
            (e) =>
            QuotationLineItem.fromMap(Map<String, dynamic>.from(e as Map)),
      )
          .toList();

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              QuotationPreviewScreen(quotation: safeData, items: parsedItems),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showSnack('Failed to load preview: $e', isError: true);
    }
  }

  Future<void> _convertToSalesOrder(
      String docId,
      Map<String, dynamic> data,
      ) async {
    if (_companyId == null) {
      _showSnack('Company context missing. Cannot convert.', isError: true);
      return;
    }

    if (_convertingDocs[docId] == true) {
      _showSnack('Conversion in progress. Please wait.');
      return;
    }

    if ((data['status'] ?? '').toString().toLowerCase() == 'converted') {
      _showSnack('Already converted to Sales Order.', isError: true);
      return;
    }

    final String status = data['status']?.toString() ?? 'Draft';
    final String approval = data['approvalStatus']?.toString() ?? 'Pending';
    final bool isApproved = status == 'Approved' || approval == 'Approved';

    if (!isApproved) {
      _showSnack(
        'Quotation must be Approved before converting to SO.',
        isError: true,
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      'Prepare Sales Order',
      'Open quotation ${data['quoteNumber']} to prepare and confirm the Sales Order?',
    );
    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _convertingDocs[docId] = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuotationScreenLocal(
            userId: widget.userId,
            companyId: _companyId,
            quotationId: docId,
            existingQuotation: data,
            prepareSalesOrderMode: true,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _convertingDocs.remove(docId);
        });
      }
    }
  }

  Future<void> _createRevision(String docId, Map<String, dynamic> data) async {
    final inquiryId = data['inquiryId'] ?? data['inquiryRefNo'];
    if (inquiryId == null || inquiryId.toString().trim().isEmpty) {
      _showSnack(
        'Warning: Cannot revise a quotation that is not linked to an Inquiry.',
        isError: true,
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      'Create Revision',
      'Create a new version of quotation ${data['quoteNumber']}?',
    );
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final oldRef = _quotationCollection!.doc(docId);
      batch.update(oldRef, {
        'isLatest': false,
        'status': 'Revised',
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
      });

      final newRef = _quotationCollection!.doc();
      final currentVersion = (data['version'] as int?) ?? 1;

      final newData = Map<String, dynamic>.from(data)
        ..['id'] = newRef.id
        ..['version'] = currentVersion + 1
        ..['parentQuotationId'] = docId
        ..['isLatest'] = true
        ..['status'] = 'Draft'
        ..['approvalStatus'] = 'Pending'
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['createdBy'] = _currentUserUid
        ..['createdByName'] = _currentUserName
        ..['lastEditedAt'] = FieldValue.serverTimestamp()
        ..['lastEditedBy'] = _currentUserUid
        ..['activities'] = [
          {
            'type': 'Revised',
            'quotationId': newRef.id,
            'parentQuotationId': docId,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole,
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_revision',
              'version': '1.0',
            },
            'note': 'Revision ${currentVersion + 1} created from $docId',
          },
        ];

      batch.set(newRef, newData);
      await batch.commit();

      _showSnack('Revision ${currentVersion + 1} created successfully.');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to create revision: $e', isError: true);
    }
  }

  Future<void> _updateApproval(String docId, String status) async {
    try {
      await _quotationCollection!.doc(docId).update({
        'approvalStatus': status,
        if (status == 'Approved') 'status': 'Approved',
        'approvedBy': status == 'Approved' ? _currentUserUid : null,
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'Approval Update',
            'quotationId': docId,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole,
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_approval',
              'version': '1.0',
            },
            'note': 'Approval set to $status',
          },
        ]),
      });
      _showSnack('Quotation $status');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to update approval: $e', isError: true);
    }
  }

  Future<void> _cancelQuotation(String docId) async {
    final confirm = await _showConfirmDialog(
      'Cancel Quotation',
      'Are you sure you want to cancel this quotation?',
    );
    if (confirm != true) return;

    try {
      await _quotationCollection!.doc(docId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _currentUserUid,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'Cancelled',
            'quotationId': docId,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole,
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_cancel',
              'version': '1.0',
            },
            'note': 'Quotation cancelled',
          },
        ]),
      });

      _showSnack('Quotation Cancelled');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to cancel: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final search = _searchNotifier.value.trim().toLowerCase();

    var filtered = docs.where((doc) {
      final data = doc.data();

      // 🔥 FIX: RBAC Role Filter applied locally here instead of Firestore .where()
      bool matchesRole = true;
      if (!_isAdminOrManager && _currentUserUid != null) {
        final createdBy = _safeString(data['createdBy']);
        final assignedToUsers = data['assignedToUsers'] as List<dynamic>? ?? [];

        if (createdBy != _currentUserUid &&
            !assignedToUsers.contains(_currentUserUid)) {
          matchesRole = false;
        }
      }

      if (data['quoteNumber'] == null) {
        return false;
      }

      final quoteNumber = _safeString(data['quoteNumber']).toLowerCase();
      final customer = _safeString(
        data['clientName'] ?? data['customerName'] ?? data['companyName'],
      ).toLowerCase();
      final inquiry = _safeString(
        data['inquiryRefNo'] ?? data['inquiryNumber'] ?? data['inquiryId'],
      ).toLowerCase();
      final createdByName = _safeString(data['createdByName']).toLowerCase();
      final status = _safeString(data['status'], fallback: 'Draft');
      final grandTotal = _safeString(data['grandTotal']).toLowerCase();
      final isDeleted = data['isDeleted'] == true;

      final items = data['items'] is List ? data['items'] as List : const [];
      final itemText = items
          .map((item) {
        if (item is Map) {
          return [
            item['name'],
            item['itemName'],
            item['description'],
            item['model'],
            item['hsn'],
          ].map(_safeString).join(' ');
        }
        return _safeString(item);
      })
          .join(' ')
          .toLowerCase();

      final matchesSearch =
          search.isEmpty ||
              quoteNumber.contains(search) ||
              customer.contains(search) ||
              inquiry.contains(search) ||
              createdByName.contains(search) ||
              status.toLowerCase().contains(search) ||
              grandTotal.contains(search) ||
              itemText.contains(search);
      final matchesStatus =
          _statusFilter == 'All' ||
              status.toLowerCase() == _statusFilter.toLowerCase();

      return matchesRole && !isDeleted && matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      if (_sortOption.startsWith('Amount')) {
        final amtA =
            double.tryParse(dataA['grandTotal']?.toString() ?? '0') ?? 0;
        final amtB =
            double.tryParse(dataB['grandTotal']?.toString() ?? '0') ?? 0;
        return _sortOption.contains('High')
            ? amtB.compareTo(amtA)
            : amtA.compareTo(amtB);
      } else {
        final dateA =
            _safeTimestamp(dataA['createdAt'])?.toDate() ?? DateTime(2000);
        final dateB =
            _safeTimestamp(dataB['createdAt'])?.toDate() ?? DateTime(2000);
        return _sortOption.contains('Newest')
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

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

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _sortOption = 'Date: Newest';
    });
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'All' || _sortOption != 'Date: Newest';


  Widget _buildWorkspaceHeader({
    required String searchValue,
    required int totalQuotes,
    required int sent,
    required int approved,
    required int converted,
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
            totalQuotes: totalQuotes,
            sent: sent,
            approved: approved,
            converted: converted,
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

          final double searchWidth =
          constraints.maxWidth < 1250 ? 280 : 330;

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
        style: const TextStyle(
          fontSize: 11,
          color: _zSlate700,
        ),
        decoration: InputDecoration(
          hintText: 'Search quotation, customer, inquiry, item...',
          hintStyle: const TextStyle(
            color: _zSlate400,
            fontSize: 10.8,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 14,
            color: _zSlate400,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIcon: searchValue.trim().isEmpty
              ? null
              : IconButton(
            tooltip: 'Clear search',
            icon: const Icon(
              Icons.close,
              size: 13,
              color: _zSlate500,
            ),
            padding: EdgeInsets.zero,
            onPressed: _clearSearch,
          ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
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
    required int totalQuotes,
    required int sent,
    required int approved,
    required int converted,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnterpriseQuotationKpi(
          title: 'Total',
          value: totalQuotes.toString(),
        ),
        const SizedBox(width: 16),
        _EnterpriseQuotationKpi(
          title: 'Sent',
          value: sent.toString(),
        ),
        const SizedBox(width: 16),
        _EnterpriseQuotationKpi(
          title: 'Approved',
          value: approved.toString(),
        ),
        const SizedBox(width: 16),
        _EnterpriseQuotationKpi(
          title: 'Converted',
          value: converted.toString(),
        ),
      ],
    );
  }

  Widget _buildToolbarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuotationToolbarButton(
          icon: Icons.filter_list_rounded,
          label: _hasActiveFilters ? 'Filters (Active)' : 'Filters',
          isActive: _hasActiveFilters,
          onTap: _openFilterSheet,
        ),
      ],
    );
  }

  Widget _buildActiveFiltersSummary() {
    final List<Widget> chips = [];

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
                child: Icon(
                  Icons.close,
                  size: 11,
                  color: _zSlate400,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_statusFilter != 'All') {
      chips.add(
        buildChip(
          'Status: $_statusFilter',
              () => setState(() => _statusFilter = 'All'),
        ),
      );
    }

    if (_sortOption != 'Date: Newest') {
      chips.add(
        buildChip(
          'Sort: $_sortOption',
              () => setState(() => _sortOption = 'Date: Newest'),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
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

  Widget _buildQuotationTableHeader() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(
        horizontal: _quotationGridHorizontalPadding,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FA),
        border: Border(
          bottom: BorderSide(color: _zSlate300, width: 0.9),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: _quotationCustomerFlex,
            child: _QuotationHeaderText('Quotation / Customer'),
          ),
          Expanded(
            flex: _quotationStatusFlex,
            child: _QuotationHeaderText('Status'),
          ),
          Expanded(
            flex: _quotationItemsFlex,
            child: _QuotationHeaderText('Items'),
          ),
          Expanded(
            flex: _quotationAmountFlex,
            child: _QuotationHeaderText('Amount'),
          ),
          Expanded(
            flex: _quotationOwnerFlex,
            child: _QuotationHeaderText('Created By'),
          ),
          Expanded(
            flex: _quotationCreatedFlex,
            child: _QuotationHeaderText('Created'),
          ),
          Expanded(
            flex: _quotationFollowUpFlex,
            child: _QuotationHeaderText('Follow-up'),
          ),
          SizedBox(
            width: _quotationGridActionWidth,
            child: Center(child: _QuotationHeaderText('Actions')),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationEmptyState({
    required bool hasSearchOrFilters,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearchOrFilters
                  ? Icons.search_off_outlined
                  : Icons.request_quote_outlined,
              size: 42,
              color: _zSlate300,
            ),
            const SizedBox(height: 12),
            Text(
              hasSearchOrFilters
                  ? 'No matching quotations found'
                  : 'No quotations found',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _zSlate700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasSearchOrFilters
                  ? 'Try changing the search text or active filters.'
                  : 'Create a quotation to begin managing your sales proposals.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: _zSlate500,
              ),
            ),
            if (hasSearchOrFilters) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  _clearSearch();
                  _resetFilters();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _zSlate700,
                  side: const BorderSide(color: _zSlate300),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Reset Search & Filters',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 34,
              color: Color(0xFF9A5A5A),
            ),
            const SizedBox(height: 10),
            const Text(
              'Unable to load quotations',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _zSlate800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              error?.toString() ?? 'Unknown data loading error.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: _zSlate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingContext) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: _zSlate400,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9A5A5A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    if (_primaryQuery == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'System initialization failed',
            style: TextStyle(color: _zSlate600),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: SizedBox(
        width: 52,
        height: 52,
        child: FloatingActionButton(
          tooltip: 'New Quotation',
          backgroundColor: _zErpPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: _openCreateQuotation,
          child: const Icon(Icons.add, size: 19),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _primaryQuery!.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildQuotationError(snapshot.error);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWorkspaceHeader(
                  searchValue: _searchNotifier.value,
                  totalQuotes: 0,
                  sent: 0,
                  approved: 0,
                  converted: 0,
                ),
                _buildQuotationTableHeader(),
                const Expanded(
                  child: _QuotationSkeletonList(),
                ),
              ],
            );
          }

          final docs = snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          return ValueListenableBuilder<String>(
            valueListenable: _searchNotifier,
            builder: (context, searchValue, _) {
              final filteredDocs = _applyLocalFilters(docs);

              int approved = 0;
              int converted = 0;
              int sent = 0;

              for (final doc in filteredDocs) {
                final data = doc.data();
                final status =
                _safeString(data['status']).toLowerCase();
                final approvalStatus =
                _safeString(data['approvalStatus']).toLowerCase();

                if (status == 'sent') sent++;
                if (status == 'approved' ||
                    approvalStatus == 'approved') {
                  approved++;
                }
                if (status == 'converted') converted++;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWorkspaceHeader(
                    searchValue: searchValue,
                    totalQuotes: filteredDocs.length,
                    sent: sent,
                    approved: approved,
                    converted: converted,
                  ),
                  _buildActiveFiltersSummary(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double tableWidth =
                        constraints.maxWidth < _quotationGridMinWidth
                            ? _quotationGridMinWidth
                            : constraints.maxWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                              children: [
                                _buildQuotationTableHeader(),
                                Expanded(
                                  child: filteredDocs.isEmpty
                                      ? _buildQuotationEmptyState(
                                    hasSearchOrFilters:
                                    searchValue.trim().isNotEmpty ||
                                        _hasActiveFilters,
                                  )
                                      : ListView.builder(
                                    physics:
                                    const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.only(
                                      bottom: 92,
                                    ),
                                    itemCount: filteredDocs.length,
                                    itemBuilder: (context, index) {
                                      final doc = filteredDocs[index];
                                      final data = doc.data();

                                      final String rawQNo =
                                      _safeString(
                                        data['quoteNumber'],
                                      );
                                      final String qNo =
                                      rawQNo.isEmpty
                                          ? 'Draft'
                                          : rawQNo;
                                      final String version =
                                      _safeString(
                                        data['version'],
                                        fallback: '1',
                                      );
                                      final String customer =
                                      _safeString(
                                        data['clientName'] ??
                                            data['customerName'] ??
                                            data['companyName'],
                                        fallback:
                                        'Unknown Customer',
                                      );
                                      final String status =
                                      _safeString(
                                        data['status'],
                                        fallback: 'Draft',
                                      );
                                      final String approval =
                                      _safeString(
                                        data['approvalStatus'],
                                        fallback: 'Pending',
                                      );
                                      final String paymentStatus =
                                      _safeString(
                                        data['paymentStatus'],
                                        fallback: 'Pending',
                                      );
                                      final String inquiryRef =
                                      _safeString(
                                        data['inquiryRefNo'] ??
                                            data['inquiryNumber'] ??
                                            data['inquiryId'],
                                      );

                                      final bool isCancelled =
                                          status.toLowerCase() ==
                                              'cancelled';
                                      final bool isApproved =
                                          status.toLowerCase() ==
                                              'approved' ||
                                              approval.toLowerCase() ==
                                                  'approved';
                                      final bool isConverted =
                                          status.toLowerCase() ==
                                              'converted';
                                      final bool canEdit =
                                          !isCancelled &&
                                              !isApproved &&
                                              !isConverted;
                                      final bool isConverting =
                                          _convertingDocs[doc.id] ==
                                              true;

                                      final String createdByUid =
                                      _parseSafeString(
                                        data['createdBy'],
                                      );
                                      final String storedCreatorName =
                                      _safeString(
                                        data['createdByName'],
                                      );

                                      final DateTime? createdAt =
                                      _safeTimestamp(
                                        data['createdAt'],
                                      )?.toDate();
                                      final DateTime? nextFollowUp =
                                      _safeTimestamp(
                                        data['nextFollowUpDate'],
                                      )?.toDate();

                                      return _EnterpriseQuotationRow(
                                        key: ValueKey(doc.id),
                                        quotationNumber: qNo,
                                        version: version,
                                        customer: customer,
                                        inquiryReference: inquiryRef,
                                        status: status,
                                        approvalStatus: approval,
                                        paymentStatus: paymentStatus,
                                        amount:
                                        _money(data['grandTotal']),
                                        items: data['items'] is List
                                            ? List<dynamic>.from(
                                          data['items'] as List,
                                        )
                                            : const <dynamic>[],
                                        createdAtText:
                                        _formatCompactDate(
                                          createdAt,
                                        ),
                                        followUpText:
                                        _formatCompactDate(
                                          nextFollowUp,
                                        ),
                                        storedCreatorName:
                                        storedCreatorName,
                                        creatorNameFuture:
                                        storedCreatorName.isEmpty
                                            ? _getUserName(
                                          createdByUid,
                                        )
                                            : null,
                                        canEdit: canEdit,
                                        isCancelled: isCancelled,
                                        isApproved: isApproved,
                                        isConverted: isConverted,
                                        isConverting: isConverting,
                                        onView: () =>
                                            _openQuotationPreview(
                                              data,
                                            ),
                                        onEdit: () =>
                                            _openQuotationForEdit(
                                              doc.id,
                                              data,
                                            ),
                                        onApprove: () =>
                                            _updateApproval(
                                              doc.id,
                                              'Approved',
                                            ),
                                        onReject: () =>
                                            _updateApproval(
                                              doc.id,
                                              'Rejected',
                                            ),
                                        onConvert: () =>
                                            _convertToSalesOrder(
                                              doc.id,
                                              data,
                                            ),
                                        onRevision: () =>
                                            _createRevision(
                                              doc.id,
                                              data,
                                            ),
                                        onCancel: () =>
                                            _cancelQuotation(doc.id),
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
    );
  }
}

class _QuotationHeaderText extends StatelessWidget {
  final String label;

  const _QuotationHeaderText(this.label);

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

class _QuotationToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _QuotationToolbarButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: isActive ? _zSlate100 : Colors.white,
          border: Border.all(
            color: isActive ? _zSlate300 : _zSlate200,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? _zSlate700 : _zSlate500,
            ),
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

class _EnterpriseQuotationKpi extends StatelessWidget {
  final String title;
  final String value;

  const _EnterpriseQuotationKpi({
    required this.title,
    required this.value,
  });

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

class _QuotationSkeletonList extends StatelessWidget {
  const _QuotationSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      itemBuilder: (context, index) {
        return _QuotationSkeletonRow(index: index);
      },
    );
  }
}

class _QuotationSkeletonRow extends StatelessWidget {
  final int index;

  const _QuotationSkeletonRow({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(
        horizontal: _quotationGridHorizontalPadding,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _zSlate100),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _quotationCustomerFlex,
            child: _buildDoubleBlock(150, 100),
          ),
          Expanded(
            flex: _quotationStatusFlex,
            child: _buildDoubleBlock(66, 46),
          ),
          Expanded(
            flex: _quotationItemsFlex,
            child: _buildDoubleBlock(100, 54),
          ),
          Expanded(
            flex: _quotationAmountFlex,
            child: _buildDoubleBlock(76, 40),
          ),
          Expanded(
            flex: _quotationOwnerFlex,
            child: _buildDoubleBlock(78, 42),
          ),
          Expanded(
            flex: _quotationCreatedFlex,
            child: _buildBlock(58),
          ),
          Expanded(
            flex: _quotationFollowUpFlex,
            child: _buildBlock(58),
          ),
          const SizedBox(
            width: _quotationGridActionWidth,
            child: Icon(
              Icons.more_vert,
              size: 15,
              color: _zSlate200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleBlock(double firstWidth, double secondWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBlock(firstWidth),
        const SizedBox(height: 5),
        _buildBlock(secondWidth, height: 7),
      ],
    );
  }

  Widget _buildBlock(double baseWidth, {double height = 9}) {
    final double width =
        baseWidth * (0.76 + (index % 3) * 0.1);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _zSlate100,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _EnterpriseQuotationRow extends StatefulWidget {
  final String quotationNumber;
  final String version;
  final String customer;
  final String inquiryReference;
  final String status;
  final String approvalStatus;
  final String paymentStatus;
  final String amount;
  final List<dynamic> items;
  final String createdAtText;
  final String followUpText;
  final String storedCreatorName;
  final Future<String>? creatorNameFuture;

  final bool canEdit;
  final bool isCancelled;
  final bool isApproved;
  final bool isConverted;
  final bool isConverting;

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onConvert;
  final VoidCallback onRevision;
  final VoidCallback onCancel;

  const _EnterpriseQuotationRow({
    super.key,
    required this.quotationNumber,
    required this.version,
    required this.customer,
    required this.inquiryReference,
    required this.status,
    required this.approvalStatus,
    required this.paymentStatus,
    required this.amount,
    required this.items,
    required this.createdAtText,
    required this.followUpText,
    required this.storedCreatorName,
    required this.creatorNameFuture,
    required this.canEdit,
    required this.isCancelled,
    required this.isApproved,
    required this.isConverted,
    required this.isConverting,
    required this.onView,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
    required this.onConvert,
    required this.onRevision,
    required this.onCancel,
  });

  @override
  State<_EnterpriseQuotationRow> createState() =>
      _EnterpriseQuotationRowState();
}

class _EnterpriseQuotationRowState
    extends State<_EnterpriseQuotationRow> {
  bool _isHovered = false;

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
      value?.toString().replaceAll(',', '').trim() ?? '',
    ) ??
        0;
  }

  String _quantityText(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }

  Color _statusColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'approved':
      case 'converted':
      case 'paid':
        return const Color(0xFF56745D);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFF8A4F4F);
      case 'sent':
      case 'viewed':
        return const Color(0xFF557495);
      case 'follow-up':
      case 'follow up':
      case 'negotiation':
        return const Color(0xFF726482);
      case 'draft':
        return const Color(0xFF806B4B);
      case 'partial':
        return const Color(0xFF8A6A42);
      default:
        return _zSlate600;
    }
  }

  String _firstItemName() {
    if (widget.items.isEmpty) return '-';

    final first = widget.items.first;
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

  double _totalQuantity() {
    double total = 0;

    for (final item in widget.items) {
      if (item is Map) {
        total += _toDouble(item['quantity'] ?? item['qty']);
      }
    }

    return total;
  }

  String _itemUnit() {
    if (widget.items.isEmpty) return '';

    final first = widget.items.first;
    if (first is Map) {
      return _safeString(first['uom'] ?? first['unit']);
    }

    return '';
  }

  Widget _buildQuotationCustomerCell() {
    final String versionSuffix =
    widget.version.trim().isEmpty ? '' : ' v${widget.version}';
    final String inquiryText = widget.inquiryReference.trim().isEmpty
        ? 'Direct quotation'
        : 'Inquiry: ${widget.inquiryReference}';

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: widget.onView,
                borderRadius: BorderRadius.circular(3),
                child: Text(
                  '${widget.quotationNumber}$versionSuffix',
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
              const SizedBox(width: 7),
              Expanded(
                child: InkWell(
                  onTap: widget.onView,
                  borderRadius: BorderRadius.circular(3),
                  child: Text(
                    widget.customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.7,
                      height: 1.08,
                      fontWeight: FontWeight.w600,
                      color: _zSlate800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            inquiryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.8,
              height: 1.05,
              color: _zSlate500,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell() {
    final String cleanStatus =
    widget.status.trim().isEmpty ? 'Draft' : widget.status.trim();
    final String approval =
    widget.approvalStatus.trim().isEmpty
        ? 'Pending'
        : widget.approvalStatus.trim();

    String secondary = '';
    if (widget.isConverted) {
      secondary = widget.paymentStatus.trim().isEmpty
          ? 'Payment Pending'
          : 'Payment ${widget.paymentStatus}';
    } else if (approval.toLowerCase() != 'pending' &&
        approval.toLowerCase() != cleanStatus.toLowerCase()) {
      secondary = approval;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _statusColor(cleanStatus),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  cleanStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.8,
                    height: 1.08,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(cleanStatus),
                  ),
                ),
              ),
            ],
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.6,
                height: 1.05,
                color: _statusColor(
                  widget.isConverted
                      ? widget.paymentStatus
                      : approval,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCell() {
    if (widget.items.isEmpty) {
      return const Text(
        '-',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: _zSlate300,
        ),
      );
    }

    final String firstName = _firstItemName();
    final int extraItems = widget.items.length - 1;
    final double totalQuantity = _totalQuantity();
    final String unit = _itemUnit();
    final String quantityLine = totalQuantity > 0
        ? 'Qty ${_quantityText(totalQuantity)}${unit.isEmpty ? '' : ' $unit'}'
        : '${widget.items.length} item${widget.items.length == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$firstName${extraItems > 0 ? ' +$extraItems' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.9,
              height: 1.08,
              color: _zSlate700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            quantityLine,
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
    );
  }

  Widget _buildAmountCell() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        widget.amount,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.2,
          height: 1.08,
          fontWeight: FontWeight.w700,
          color: _zSlate800,
        ),
      ),
    );
  }

  Widget _buildCreatorCell() {
    if (widget.storedCreatorName.trim().isNotEmpty) {
      return _creatorText(widget.storedCreatorName);
    }

    final future = widget.creatorNameFuture;
    if (future == null) return _creatorText('Unknown');

    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        return _creatorText(snapshot.data ?? '...');
      },
    );
  }

  Widget _creatorText(String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.8,
          height: 1.08,
          color: _zSlate600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDateCell(String value, {bool mutedWhenEmpty = false}) {
    final bool empty = value.trim().isEmpty || value == '-';

    return Text(
      empty ? '-' : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10.7,
        height: 1.08,
        color: empty && mutedWhenEmpty ? _zSlate300 : _zSlate600,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildActionItems() {
    final List<PopupMenuEntry<String>> items = [
      const PopupMenuItem<String>(
        value: 'view',
        height: 32,
        child: _QuotationMenuItem(
          icon: Icons.visibility_outlined,
          label: 'View Quotation',
        ),
      ),
    ];

    if (widget.canEdit) {
      items.add(
        const PopupMenuItem<String>(
          value: 'edit',
          height: 32,
          child: _QuotationMenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit Quotation',
          ),
        ),
      );
    }

    if (!widget.isCancelled) {
      items.add(const PopupMenuDivider(height: 8));

      final String approval =
      widget.approvalStatus.trim().toLowerCase();

      if (approval != 'approved' && approval != 'rejected') {
        items.add(
          const PopupMenuItem<String>(
            value: 'approve',
            height: 32,
            child: _QuotationMenuItem(
              icon: Icons.check_circle_outline,
              label: 'Approve',
            ),
          ),
        );
        items.add(
          const PopupMenuItem<String>(
            value: 'reject',
            height: 32,
            child: _QuotationMenuItem(
              icon: Icons.highlight_off_outlined,
              label: 'Reject',
            ),
          ),
        );
      }

      if (!widget.isConverted &&
          widget.isApproved &&
          !widget.isConverting) {
        items.add(
          const PopupMenuItem<String>(
            value: 'convert',
            height: 32,
            child: _QuotationMenuItem(
              icon: Icons.shopping_cart_checkout_outlined,
              label: 'Convert to Sales Order',
            ),
          ),
        );
      }

      if (widget.isConverting) {
        items.add(
          const PopupMenuItem<String>(
            enabled: false,
            height: 32,
            child: _QuotationMenuItem(
              icon: Icons.sync,
              label: 'Preparing Sales Order...',
            ),
          ),
        );
      }

      if (widget.isApproved && !widget.isConverted) {
        items.add(
          const PopupMenuItem<String>(
            value: 'revision',
            height: 32,
            child: _QuotationMenuItem(
              icon: Icons.copy_all_outlined,
              label: 'Create Revision',
            ),
          ),
        );
      }

      items.add(const PopupMenuDivider(height: 8));
      items.add(
        const PopupMenuItem<String>(
          value: 'cancel',
          height: 32,
          child: _QuotationMenuItem(
            icon: Icons.cancel_outlined,
            label: 'Cancel Quotation',
            danger: true,
          ),
        ),
      );
    }

    return items;
  }

  void _handleAction(String value) {
    switch (value) {
      case 'view':
        widget.onView();
        break;
      case 'edit':
        widget.onEdit();
        break;
      case 'approve':
        widget.onApprove();
        break;
      case 'reject':
        widget.onReject();
        break;
      case 'convert':
        widget.onConvert();
        break;
      case 'revision':
        widget.onRevision();
        break;
      case 'cancel':
        widget.onCancel();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          height: 54,
          padding: const EdgeInsets.symmetric(
            horizontal: _quotationGridHorizontalPadding,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFFFBFCFE)
                : Colors.white,
            border: Border(
              bottom: const BorderSide(
                color: _zSlate100,
                width: 1,
              ),
              left: BorderSide(
                color: _isHovered
                    ? _zSoftHoverBorder
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: _quotationCustomerFlex,
                child: _buildQuotationCustomerCell(),
              ),
              Expanded(
                flex: _quotationStatusFlex,
                child: _buildStatusCell(),
              ),
              Expanded(
                flex: _quotationItemsFlex,
                child: _buildItemsCell(),
              ),
              Expanded(
                flex: _quotationAmountFlex,
                child: _buildAmountCell(),
              ),
              Expanded(
                flex: _quotationOwnerFlex,
                child: _buildCreatorCell(),
              ),
              Expanded(
                flex: _quotationCreatedFlex,
                child: _buildDateCell(
                  widget.createdAtText,
                  mutedWhenEmpty: true,
                ),
              ),
              Expanded(
                flex: _quotationFollowUpFlex,
                child: _buildDateCell(
                  widget.followUpText,
                  mutedWhenEmpty: true,
                ),
              ),
              SizedBox(
                width: _quotationGridActionWidth,
                child: Center(
                  child: PopupMenuButton<String>(
                    tooltip: 'Quotation actions',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: _isHovered
                          ? _zSlate600
                          : _zSlate400.withValues(alpha: 0.62),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(color: _zSlate200),
                    ),
                    onSelected: _handleAction,
                    itemBuilder: (_) => _buildActionItems(),
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

class _QuotationMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _QuotationMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
    danger ? const Color(0xFF8A5F5F) : _zSlate700;

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
