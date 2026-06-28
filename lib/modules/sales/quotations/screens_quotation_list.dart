import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';
import 'package:QUIK/modules/sales/quotations/letterhead_settings_screen.dart';
import 'quotation_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);

const String _kCollectionCompanies = 'companies';
const String _kCollectionUsers = 'users';
const String _kCollectionQuotations = 'quotations';
const String _kCollectionSalesOrders = 'sales_orders';

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

  Future<void> _openLetterheadSettings() async {
    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) {
      _showSnack(
        'Company context missing. Cannot open letterhead settings.',
        isError: true,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LetterheadSettingsScreen(
          companyId: companyId,
          currentUserUid: _currentUserUid ?? '',
          currentUserName: _currentUserName,
        ),
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
      safeData['companyId'] ??= _companyId;

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
    bool isApproved = status == 'Approved' || approval == 'Approved';

    if (!isApproved) {
      _showSnack(
        'Quotation must be Approved before converting to SO.',
        isError: true,
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      'Convert to Sales Order',
      'Convert quotation ${data['quoteNumber']} to a Sales Order?',
    );
    if (confirm != true) return;

    if (!mounted) return;

    setState(() => _convertingDocs[docId] = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection(_kCollectionCompanies)
          .doc(_companyId)
          .collection(_kCollectionQuotations)
          .doc(docId);

      final soCollection = FirebaseFirestore.instance
          .collection(_kCollectionCompanies)
          .doc(_companyId)
          .collection(_kCollectionSalesOrders);

      final newSoRef = soCollection.doc();

      bool canProceed = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Quotation not found.');
        }

        final docData = snapshot.data()!;
        final isCurrentlyConverted =
            (docData['status'] ?? '').toString().toLowerCase() == 'converted';
        final isConvertingFlag = docData['isConverting'] == true;

        if (isCurrentlyConverted) {
          throw Exception('Already converted by another user.');
        }

        if (isConvertingFlag) {
          final convertingStartedAt =
              docData['convertingStartedAt'] as Timestamp?;
          if (convertingStartedAt != null) {
            final elapsed = DateTime.now().difference(
              convertingStartedAt.toDate(),
            );
            if (elapsed.inMinutes < 2) {
              throw Exception(
                'Another user is currently converting this quotation.',
              );
            }
          } else {
            throw Exception(
              'Another user is currently converting this quotation.',
            );
          }
        }

        transaction.update(docRef, {
          'isConverting': true,
          'convertingStartedAt': FieldValue.serverTimestamp(),
        });
        canProceed = true;
      });

      if (!canProceed) return;

      final salesOrderData = {
        ...data,
        'id': newSoRef.id,
        'sourceQuotationId': docId,
        'status': 'draft',
        'approvalStatus': 'pending',
        'dispatchStatus': 'pending',
        'documentType': 'sales_order',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUserUid,
        'createdByName': _currentUserName,
        'salesOrderNumber':
            'SO-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        'activities': [
          {
            'type': 'Created',
            'note': 'Sales Order automatically generated from Quotation $docId',
            'timestamp': Timestamp.now(),
            'byUid': _currentUserUid ?? 'system',
          },
        ],
      };

      await newSoRef.set(salesOrderData);

      await docRef.update({
        'status': 'Converted',
        'convertedToSalesOrder': true,
        'convertedToSalesOrderId': newSoRef.id,
        'convertedAt': FieldValue.serverTimestamp(),
        'convertedBy': _currentUserUid,
        'isConverting': false,
        'convertingStartedAt': null,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'Converted',
            'quotationId': docId,
            'salesOrderId': newSoRef.id,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole,
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_to_so',
              'version': '1.0',
            },
            'note': 'Quotation successfully converted to Sales Order',
          },
        ]),
      });

      _showSnack('Quotation successfully converted to Sales Order.');
    } catch (e) {
      _showSnack(
        'Conversion failed: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );

      try {
        final docRef = FirebaseFirestore.instance
            .collection(_kCollectionCompanies)
            .doc(_companyId)
            .collection(_kCollectionQuotations)
            .doc(docId);
        await docRef.update({
          'isConverting': false,
          'convertingStartedAt': null,
        });
      } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingContext) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    if (_primaryQuery == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('System initialization failed')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New Quote',
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        onPressed: _openCreateQuotation,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _primaryQuery!.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading quotations:\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return ValueListenableBuilder<String>(
            valueListenable: _searchNotifier,
            builder: (context, searchValue, _) {
              final filteredDocs = _applyLocalFilters(docs);

              int totalQuotes = filteredDocs.length;
              int approved = 0;
              int converted = 0;
              int sent = 0;

              for (final doc in filteredDocs) {
                final status = (doc.data()['status'] ?? '')
                    .toString()
                    .toLowerCase();
                final approvalStatus = (doc.data()['approvalStatus'] ?? '')
                    .toString()
                    .toLowerCase();

                if (status == 'sent') sent++;
                if (status == 'approved' || approvalStatus == 'approved')
                  approved++;
                if (status == 'converted') converted++;
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textInputAction: TextInputAction.search,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Search quotation, customer...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: searchValue.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear',
                                        icon: const Icon(Icons.close, size: 17),
                                        onPressed: _clearSearch,
                                      ),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          width: 38,
                          child: Material(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _openLetterheadSettings,
                              child: Icon(
                                Icons.settings_outlined,
                                size: 18,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          width: 38,
                          child: Material(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _openFilterSheet,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: Colors.grey.shade800,
                                  ),
                                  if (_hasActiveFilters)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _MiniStatText(
                          label: 'Total',
                          value: totalQuotes.toString(),
                        ),
                        const SizedBox(width: 14),
                        _MiniStatText(label: 'Sent', value: sent.toString()),
                        const SizedBox(width: 14),
                        _MiniStatText(
                          label: 'Approved',
                          value: approved.toString(),
                        ),
                        const SizedBox(width: 14),
                        _MiniStatText(
                          label: 'Converted',
                          value: converted.toString(),
                        ),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filters applied',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _resetFilters,
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Clear Filters',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? _EmptyQuotationsState(
                            hasSearch:
                                searchValue.trim().isNotEmpty ||
                                _hasActiveFilters,
                            onReset: () {
                              _clearSearch();
                              _resetFilters();
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                            itemCount: filteredDocs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data();

                              final rawQNo =
                                  data['quoteNumber']?.toString().trim() ?? '';
                              final qNo = rawQNo.isEmpty ? 'Draft' : rawQNo;
                              final version =
                                  data['version']?.toString() ?? '1';
                              final customer =
                                  data['clientName']?.toString() ??
                                  'Unknown Customer';

                              final amt = _money(data['grandTotal']);
                              final status =
                                  data['status']?.toString() ?? 'Draft';
                              final approval =
                                  data['approvalStatus']?.toString() ??
                                  'Pending';
                              final paymentStat =
                                  data['paymentStatus']?.toString() ??
                                  'Pending';
                              final inqRef =
                                  (data['inquiryRefNo'] ??
                                          data['inquiryNumber'] ??
                                          data['inquiryId'] ??
                                          '')
                                      .toString();

                              bool isCancelled =
                                  status.toLowerCase() == 'cancelled';
                              bool isApproved =
                                  status.toLowerCase() == 'approved' ||
                                  approval.toLowerCase() == 'approved';
                              bool isSent = status.toLowerCase() == 'sent';
                              bool isConverted =
                                  status.toLowerCase() == 'converted';

                              bool canEdit =
                                  !isCancelled && !isApproved && !isConverted;
                              bool isConverting =
                                  _convertingDocs[doc.id] == true;

                              final String createdByUid = _parseSafeString(
                                data['createdBy'],
                              );
                              final String explicitlyStoredName = _safeString(
                                data['createdByName'],
                              );

                              final Timestamp? createdAtRaw = _safeTimestamp(
                                data['createdAt'],
                              );
                              final Timestamp? nextFollowUpRaw = _safeTimestamp(
                                data['nextFollowUpDate'],
                              );

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 0.8,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                Colors.blue.shade50,
                                            child: Text(
                                              customer.isNotEmpty
                                                  ? customer[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$qNo (v$version)',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  customer,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Actions',
                                              icon: Icon(
                                                Icons.more_vert,
                                                size: 20,
                                                color: Colors.grey.shade600,
                                              ),
                                              onSelected: (val) {
                                                if (val == 'view') {
                                                  _openQuotationPreview(data);
                                                } else if (val == 'edit') {
                                                  _openQuotationForEdit(
                                                    doc.id,
                                                    data,
                                                  );
                                                } else if (val == 'approve') {
                                                  _updateApproval(
                                                    doc.id,
                                                    'Approved',
                                                  );
                                                } else if (val == 'reject') {
                                                  _updateApproval(
                                                    doc.id,
                                                    'Rejected',
                                                  );
                                                } else if (val == 'convert') {
                                                  _convertToSalesOrder(
                                                    doc.id,
                                                    data,
                                                  );
                                                } else if (val == 'revision') {
                                                  _createRevision(doc.id, data);
                                                } else if (val == 'cancel') {
                                                  _cancelQuotation(doc.id);
                                                }
                                              },
                                              itemBuilder: (context) {
                                                List<PopupMenuEntry<String>>
                                                items = [
                                                  const PopupMenuItem(
                                                    value: 'view',
                                                    child: Text(
                                                      'View Quotation',
                                                    ),
                                                  ),
                                                ];

                                                if (canEdit) {
                                                  items.add(
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text(
                                                        'Edit Quotation',
                                                      ),
                                                    ),
                                                  );
                                                }

                                                if (!isCancelled) {
                                                  items.add(
                                                    const PopupMenuDivider(),
                                                  );

                                                  if (approval.toLowerCase() !=
                                                          'approved' &&
                                                      approval.toLowerCase() !=
                                                          'rejected') {
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: 'approve',
                                                        child: Text('Approve'),
                                                      ),
                                                    );
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: 'reject',
                                                        child: Text('Reject'),
                                                      ),
                                                    );
                                                  }

                                                  if (!isConverted &&
                                                      isApproved &&
                                                      !isConverting) {
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: 'convert',
                                                        child: Text(
                                                          'Convert to Sales Order',
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  items.add(
                                                    const PopupMenuItem(
                                                      value: 'revision',
                                                      child: Text(
                                                        'Create Revision',
                                                      ),
                                                    ),
                                                  );

                                                  items.add(
                                                    const PopupMenuDivider(),
                                                  );
                                                  items.add(
                                                    const PopupMenuItem(
                                                      value: 'cancel',
                                                      child: Text(
                                                        'Cancel',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }

                                                return items;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _InfoChip(
                                            label: status,
                                            backgroundColor:
                                                _getQuotationStatusBg(status),
                                            textColor: _getQuotationStatusFg(
                                              status,
                                            ),
                                          ),
                                          if (approval != 'Pending')
                                            _InfoChip(
                                              label: approval,
                                              backgroundColor:
                                                  _getQuotationStatusBg(
                                                    approval,
                                                    isApproval: true,
                                                  ),
                                              textColor: _getQuotationStatusFg(
                                                approval,
                                                isApproval: true,
                                              ),
                                            ),
                                          if (status.toLowerCase() ==
                                              'converted')
                                            _InfoChip(
                                              label: paymentStat,
                                              backgroundColor:
                                                  _getQuotationStatusBg(
                                                    paymentStat,
                                                    isPayment: true,
                                                  ),
                                              textColor: _getQuotationStatusFg(
                                                paymentStat,
                                                isPayment: true,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (inqRef.isNotEmpty)
                                            _InlineInfo(
                                              icon: Icons.tag_outlined,
                                              text: 'INQ: $inqRef',
                                            ),
                                          if (explicitlyStoredName.isNotEmpty)
                                            _InlineInfo(
                                              icon: Icons.person_outline,
                                              text: explicitlyStoredName,
                                            )
                                          else
                                            FutureBuilder<String>(
                                              future: _getUserName(
                                                createdByUid,
                                              ),
                                              builder: (context, snapshot) {
                                                return _InlineInfo(
                                                  icon: Icons.person_outline,
                                                  text: snapshot.data ?? '...',
                                                );
                                              },
                                            ),
                                          _InlineInfo(
                                            icon: Icons.currency_rupee_outlined,
                                            text: amt,
                                          ),
                                          _InlineInfo(
                                            icon: Icons.add_circle_outline,
                                            text:
                                                'Created: ${_formatCompactDate(createdAtRaw?.toDate())}',
                                          ),
                                          if (nextFollowUpRaw != null)
                                            _InlineInfo(
                                              icon: Icons.event_repeat_outlined,
                                              text:
                                                  'Next: ${_formatCompactDate(nextFollowUpRaw.toDate())}',
                                            ),
                                        ],
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

  Color _getQuotationStatusBg(
    String status, {
    bool isApproval = false,
    bool isPayment = false,
  }) {
    String s = status.toLowerCase();
    if (isPayment) {
      if (s == 'paid') return Colors.green.shade50;
      if (s == 'partial') return Colors.orange.shade50;
      return Colors.red.shade50;
    } else {
      if (s == 'draft') return Colors.orange.shade50;
      if (s == 'sent' || s == 'viewed') return Colors.blue.shade50;
      if (s == 'approved' || s == 'converted') return Colors.green.shade50;
      if (s == 'rejected') return Colors.red.shade50;
      if (s == 'follow-up' || s == 'negotiation') return Colors.purple.shade50;
      if (s == 'cancelled') return Colors.red.shade100;
      return Colors.grey.shade100;
    }
  }

  Color _getQuotationStatusFg(
    String status, {
    bool isApproval = false,
    bool isPayment = false,
  }) {
    String s = status.toLowerCase();
    if (isPayment) {
      if (s == 'paid') return Colors.green.shade800;
      if (s == 'partial') return Colors.orange.shade800;
      return Colors.red.shade800;
    } else {
      if (s == 'draft') return Colors.orange.shade800;
      if (s == 'sent' || s == 'viewed') return Colors.blue.shade800;
      if (s == 'approved' || s == 'converted') return Colors.green.shade800;
      if (s == 'rejected') return Colors.red.shade800;
      if (s == 'follow-up' || s == 'negotiation') return Colors.purple.shade800;
      if (s == 'cancelled') return Colors.red.shade900;
      return Colors.grey.shade800;
    }
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _EmptyQuotationsState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyQuotationsState({required this.hasSearch, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: IntrinsicHeight(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        hasSearch ? Icons.search_off : Icons.inbox_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch
                          ? 'No matching quotations found'
                          : 'No quotations found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch
                          ? 'Try changing the search text or filter.'
                          : 'No quotation records are available yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (hasSearch)
                      OutlinedButton(
                        onPressed: onReset,
                        child: const Text('Reset Filters'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
