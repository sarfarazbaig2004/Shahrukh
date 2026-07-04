// FILE PATH: lib/modules/sales/inquiries/screens_inquiry_list.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:QUIK/models/inquiry_model.dart';
import 'package:QUIK/modules/sales/inquiries/screens_add_inquiry.dart';
import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';

// --- ENTERPRISE COLOR PALETTE ---
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

const Color _zInquiryBlue = Color(0xFF5F7FA3);
const Color _zSoftHoverBorder = Color(0xFFB8C7D9);
const Color _zErpPrimaryBlue = Color(0xFF2F6EA5);

const double _gridHorizontalPadding = 10;
const double _gridSelectWidth = 24;
const double _gridSelectGap = 6;
const double _gridActionWidth = 44;
const int _colCustomerFlex = 40;
const int _colStatusFlex = 7;
const int _colAssignedFlex = 10;
const int _colProductsFlex = 18;
const int _colFollowUpFlex = 10;
const int _colAgeFlex = 5;

bool _isInquiryOverdue(
    Map<String, dynamic> data,
    DateTime? nextDate,
    String status,
    ) {
  if (data['isOverdue'] == true) return true;
  if (nextDate == null) return false;

  final today = DateTime.now();
  final next = DateTime(nextDate.year, nextDate.month, nextDate.day);
  final current = DateTime(today.year, today.month, today.day);

  return next.isBefore(current) &&
      !['won', 'lost', 'not qualified'].contains(status.toLowerCase());
}

class ScreensInquiryList extends StatefulWidget {
  final String? companyId;

  const ScreensInquiryList({super.key, this.companyId});

  @override
  State<ScreensInquiryList> createState() => _ScreensInquiryListState();
}

class _ScreensInquiryListState extends State<ScreensInquiryList> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ScrollController _tableScrollController = ScrollController();
  Timer? _debounceTimer;
  SharedPreferences? _prefs;

  // --- Core State ---
  String? _companyId;
  String _userRole = 'sales';
  Future<Map<String, dynamic>?>? _profileDataFuture;

  // --- True Pagination & Cache State ---
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _isLoadingPage = true;
  bool _isFetchingKPIs = true;

  final Map<int, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _pageCache = {};
  final List<DocumentSnapshot> _pageCursors = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _currentDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _baseDocsCache;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _clientFilteredCache;
  Set<String> _selectedIds = {};

  // --- KPI State ---
  int _totalRecords = 0;
  int _openRecords = 0;
  int _wonRecords = 0;
  int _followUpRecords = 0;

  // --- UI Configuration State ---
  String _densityMode = 'Compact';
  List<String> _visibleColumns = ['Customer', 'Status', 'Assigned To', 'Products', 'Follow-up', 'Age', 'Actions'];
  final List<String> _availableColumns = ['Customer', 'Status', 'Assigned To', 'Products', 'Follow-up', 'Age', 'Actions'];

  // --- Filter State ---
  String _searchQuery = '';
  String _activeQuickFilter = 'All';
  final List<String> _quickFilters = [
    'All', 'My Inquiries', "Today's", 'Open', 'Won', 'Lost', 'Overdue', 'High Priority', 'Quotation Pending'
  ];

  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  String _sourceFilter = 'All';
  String _inquiryTypeFilter = 'All';
  String _quotationStatusFilter = 'All';
  String _ownerFilter = '';
  String _customerFilter = '';
  String _cityFilter = '';
  String _stateFilter = '';
  String _productFilter = '';
  String _assignedToFilter = '';
  String _createdByFilter = '';
  DateTimeRange? _dateRangeFilter;
  bool _overdueOnly = false;
  bool _recentlyUpdatedOnly = false;

  // --- Expandable Drawer State ---
  bool _generalExpanded = true;
  bool _customerExpanded = false;
  bool _assignmentExpanded = false;
  bool _productsExpanded = false;
  bool _dateExpanded = false;
  bool _quickFiltersExpanded = true;
  bool _savedFiltersExpanded = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    _prefs = await SharedPreferences.getInstance();
    _densityMode = 'Compact';

    final savedCols = _prefs?.getStringList('inquiry_columns');
    if (savedCols != null && savedCols.isNotEmpty) {
      _visibleColumns = savedCols;
    }

    final user = _currentUser;
    if (user != null) {
      _profileDataFuture = _loadProfileAndQuery(user.uid);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadProfileAndQuery(String uid) async {
    try {
      final globalDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      Map<String, dynamic> userData = globalDoc.data() ?? {};

      String resolvedCompanyId = widget.companyId ?? _getString(userData, 'activeCompanyId');

      if (resolvedCompanyId.isEmpty) {
        resolvedCompanyId = _getString(userData, 'companyId');
        if (resolvedCompanyId.isEmpty && userData['companyIds'] is List && (userData['companyIds'] as List).isNotEmpty) {
          resolvedCompanyId = _safeString((userData['companyIds'] as List).first);
        }
      }

      userData['companyId'] = resolvedCompanyId;

      if (resolvedCompanyId.isNotEmpty) {
        try {
          final companyUserDoc = await FirebaseFirestore.instance.collection('companies').doc(resolvedCompanyId).collection('users').doc(uid).get();
          if (companyUserDoc.exists && companyUserDoc.data() != null) {
            userData.addAll(companyUserDoc.data()!);
            userData['companyId'] = resolvedCompanyId;
          }
        } catch (e) {
          debugPrint("[INQUIRY LIST] Firebase Rules fallback.");
        }
      }

      if (resolvedCompanyId.isNotEmpty) {
        _companyId = resolvedCompanyId;
        _userRole = _getString(userData, 'role').isEmpty ? 'sales' : _getString(userData, 'role').toLowerCase();

        // Load initial data
        _refreshData();
      }

      return userData;
    } catch (e) {
      throw Exception("Unable to load profile data.");
    }
  }

  // ========================================================
  // CORE ENTERPRISE PAGINATION & QUERY LOGIC
  // ========================================================

  void _refreshData({bool clearBaseCache = true}) {
    _pageCache.clear();
    _pageCursors.clear();
    if (clearBaseCache) _baseDocsCache = null;
    _clientFilteredCache = null;
    _selectedIds.clear();
    _fetchKPIs();
    _loadPage(1);
  }

  String? _quickStatusValue() {
    switch (_activeQuickFilter) {
      case 'Open':
        return 'Open';
      case 'Won':
        return 'Won';
      case 'Lost':
        return 'Lost';
      default:
        return null;
    }
  }

  String? _quickPriorityValue() {
    return _activeQuickFilter == 'High Priority' ? 'Hot' : null;
  }

  Query<Map<String, dynamic>> _buildBaseQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('inquiries');

    // Only the explicit My Inquiries filter narrows the list.
    // Access control remains with Firestore rules; the list itself must not silently hide company records.
    if (_activeQuickFilter == 'My Inquiries' && _currentUser != null) {
      q = q.where(Filter.or(
        Filter('assignedToUid', isEqualTo: _currentUser!.uid),
        Filter('createdByUid', isEqualTo: _currentUser!.uid),
      ));
    }

    // Do not query `isDeleted == false` here.
    // Older inquiry documents may not contain that field, and Firestore equality filters exclude missing fields.
    // Soft-deleted documents are removed in Dart so legacy active records remain visible and paginatable.
    final effectiveStatus = _statusFilter != 'All' ? _statusFilter : _quickStatusValue();
    final effectivePriority = _priorityFilter != 'All' ? _priorityFilter : _quickPriorityValue();

    if (effectiveStatus != null && effectiveStatus != 'All') q = q.where('status', isEqualTo: effectiveStatus);
    if (effectivePriority != null && effectivePriority != 'All') q = q.where('priority', isEqualTo: effectivePriority);
    if (_sourceFilter != 'All') q = q.where('source', isEqualTo: _sourceFilter);
    if (_inquiryTypeFilter != 'All') q = q.where('inquiryType', isEqualTo: _inquiryTypeFilter);

    // Search is intentionally handled in Dart for professional partial matching across
    // customer, inquiry number, subject, product, assignee, mobile, email, and contact person.
    // Do not add a Firestore searchableTokens equality/array filter here, otherwise partial
    // searches such as "mem", "inv", or "047" will miss valid records.
    return q;
  }

  bool _requiresClientSidePaging() {
    // Keep one source of truth for records, counts, sort, partial search, and pagination.
    // Firestore orderBy(createdAt) can exclude legacy records missing createdAt, while local
    // sorting keeps every accessible inquiry visible and still orders by creation time first.
    return true;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadAllFilteredDocs() async {
    if (_clientFilteredCache != null) return _clientFilteredCache!;

    final baseDocs = _baseDocsCache ??= (await _buildBaseQuery().get()).docs;
    final docs = _applyLocalFallbackFilters(baseDocs)..sort(_compareInquiryDocs);
    _clientFilteredCache = docs;
    return docs;
  }

  Future<void> _fetchKPIs() async {
    if (!mounted) return;
    setState(() => _isFetchingKPIs = true);

    try {
      final docs = await _loadAllFilteredDocs();
      int open = 0;
      int won = 0;
      int followUp = 0;

      for (final doc in docs) {
        final status = _getString(doc.data(), 'status').toLowerCase();
        if (status == 'open') open++;
        if (status == 'won') won++;
        if (status == 'follow-up' || status == 'follow up' || status == 'follow-up pending' || status == 'follow up pending') {
          followUp++;
        }
      }

      if (mounted) {
        setState(() {
          _totalRecords = docs.length;
          _openRecords = open;
          _wonRecords = won;
          _followUpRecords = followUp;
          _isFetchingKPIs = false;
        });
      }
    } catch (e) {
      debugPrint("KPI Fetch Error: $e");
      if (mounted) setState(() => _isFetchingKPIs = false);
    }
  }

  Future<void> _ensurePageCached(int targetPage) async {
    if (targetPage < 1 || _pageCache.containsKey(targetPage)) return;

    for (int page = 1; page <= targetPage; page++) {
      if (_pageCache.containsKey(page)) continue;

      Query<Map<String, dynamic>> q = _buildBaseQuery().limit(_itemsPerPage);
      if (page > 1) {
        if (_pageCursors.length < page - 1) return;
        q = q.startAfterDocument(_pageCursors[page - 2]);
      }

      final snap = await q.get();
      if (snap.docs.isEmpty) return;

      _pageCache[page] = snap.docs;
      if (_pageCursors.length < page) {
        _pageCursors.add(snap.docs.last);
      } else {
        _pageCursors[page - 1] = snap.docs.last;
      }

      if (snap.docs.length < _itemsPerPage) return;
    }
  }

  Future<void> _loadPage(int page) async {
    if (!mounted) return;
    final totalPages = _totalRecords > 0 ? math.max(1, (_totalRecords / _itemsPerPage).ceil()).toInt() : null;
    final int safePage = totalPages == null ? math.max(1, page).toInt() : page.clamp(1, totalPages).toInt();

    setState(() {
      _isLoadingPage = true;
      _currentPage = safePage;
    });

    try {
      if (_requiresClientSidePaging()) {
        final docs = await _loadAllFilteredDocs();
        final int start = (safePage - 1) * _itemsPerPage;
        final int end = math.min(start + _itemsPerPage, docs.length).toInt();

        if (!mounted) return;
        setState(() {
          _currentDocs = start >= docs.length ? <QueryDocumentSnapshot<Map<String, dynamic>>>[] : docs.sublist(start, end);
          _totalRecords = docs.length;
          _isLoadingPage = false;
        });
        return;
      }

      await _ensurePageCached(safePage);

      if (!mounted) return;
      final docs = _pageCache[safePage] ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      setState(() {
        _currentDocs = _applyLocalFallbackFilters(docs);
        _isLoadingPage = false;
      });

      _prefetchNextPage(safePage);
    } catch (e) {
      debugPrint("Pagination Error: $e");
      if (mounted) setState(() => _isLoadingPage = false);
    }
  }

  Future<void> _prefetchNextPage(int currentPage) async {
    if (_requiresClientSidePaging()) return;

    final nextPage = currentPage + 1;
    if (_pageCache.containsKey(nextPage)) return;
    if (_pageCursors.length < currentPage) return;

    try {
      final q = _buildBaseQuery()
          .startAfterDocument(_pageCursors[currentPage - 1])
          .limit(_itemsPerPage);

      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _pageCache[nextPage] = snap.docs;
        if (_pageCursors.length < nextPage) {
          _pageCursors.add(snap.docs.last);
        }
      }
    } catch (e) {
      // Ignore prefetch errors gracefully.
    }
  }

  DateTime? _readInquiryCreatedAt(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['createdOn'] ?? data['createdDate'] ?? data['inquiryDate'] ?? data['date'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is double) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    if (raw is String && raw.trim().isNotEmpty) return DateTime.tryParse(raw.trim());
    return null;
  }

  int _inquiryNumberOrdinal(Map<String, dynamic> data) {
    final value = _getString(data, 'inquiryNumber');
    final matches = RegExp(r'\d+').allMatches(value).toList();
    if (matches.isEmpty) return 0;
    return int.tryParse(matches.last.group(0) ?? '') ?? 0;
  }

  int _compareInquiryDocs(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
      ) {
    final aData = a.data();
    final bData = b.data();
    final aCreated = _readInquiryCreatedAt(aData);
    final bCreated = _readInquiryCreatedAt(bData);

    if (aCreated != null && bCreated != null) {
      final byCreated = bCreated.compareTo(aCreated);
      if (byCreated != 0) return byCreated;
    } else if (aCreated != null) {
      return -1;
    } else if (bCreated != null) {
      return 1;
    }

    final byInquiryNumber = _inquiryNumberOrdinal(bData).compareTo(_inquiryNumberOrdinal(aData));
    if (byInquiryNumber != 0) return byInquiryNumber;

    return b.id.compareTo(a.id);
  }

  String _normaliseSearchText(dynamic value) {
    return value.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  void _collectProductSearchParts(List<String> parts, dynamic value) {
    if (value == null) return;
    if (value is Map) {
      for (final item in value.values) {
        _collectProductSearchParts(parts, item);
      }
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        _collectProductSearchParts(parts, item);
      }
      return;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty) parts.add(text);
  }

  bool _matchesSearchQuery(Map<String, dynamic> data) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final parts = <String>[
      _getString(data, 'customerName'),
      _getString(data, 'companyName'),
      _getString(data, 'customerCompanyName'),
      _getString(data, 'inquiryNumber'),
      _getString(data, 'subject'),
      _getString(data, 'requiredProducts'),
      _getString(data, 'assignedToName'),
      _getString(data, 'assignedToEmail'),
      _getString(data, 'ownerName'),
      _getString(data, 'createdByName'),
      _getString(data, 'createdByEmail'),
      _getString(data, 'contactName'),
      _getString(data, 'contactPerson'),
      _getString(data, 'contactPhone'),
      _getString(data, 'contactMobile'),
      _getString(data, 'mobile'),
      _getString(data, 'phone'),
      _getString(data, 'contactEmail'),
      _getString(data, 'email'),
      _getString(data, 'source'),
      _getString(data, 'channelRef'),
      _getString(data, 'location'),
      _getString(data, 'customerPrimaryCity'),
      _getString(data, 'customerPrimaryState'),
    ];

    _collectProductSearchParts(parts, data['products']);
    _collectProductSearchParts(parts, data['items']);

    final rawHaystack = parts.where((v) => v.trim().isNotEmpty).join(' ').toLowerCase();
    final normalisedHaystack = _normaliseSearchText(rawHaystack);
    final compactHaystack = normalisedHaystack.replaceAll(' ', '');
    final normalisedQuery = _normaliseSearchText(query);
    final compactQuery = normalisedQuery.replaceAll(' ', '');

    if (rawHaystack.contains(query)) return true;
    if (normalisedQuery.isNotEmpty && normalisedHaystack.contains(normalisedQuery)) return true;
    if (compactQuery.isNotEmpty && compactHaystack.contains(compactQuery)) return true;

    final tokens = normalisedQuery.split(RegExp(r'\s+')).where((v) => v.isNotEmpty);
    return tokens.isNotEmpty && tokens.every((token) => normalisedHaystack.contains(token) || compactHaystack.contains(token));
  }

  // --- Local fallback for filters that are difficult to index, legacy-safe soft delete handling, and derived nested fields. ---
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFallbackFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) {
      final data = doc.data();
      if (data['isDeleted'] == true) return false;
      if (!_matchesSearchQuery(data)) return false;

      final status = _getString(data, 'status');
      final priority = _getString(data, 'priority');
      final nextTs = data['nextFollowUpDate'];
      final nextDate = nextTs is Timestamp ? nextTs.toDate() : null;

      if (_activeQuickFilter == 'My Inquiries' && _currentUser != null) {
        final assigned = _getString(data, 'assignedToUid') == _currentUser!.uid;
        final created = _getString(data, 'createdByUid') == _currentUser!.uid;
        if (!assigned && !created) return false;
      }

      if (_activeQuickFilter == "Today's") {
        if (nextDate == null || !_isSameDate(nextDate, DateTime.now())) return false;
      }

      if (_activeQuickFilter == 'Open' && status.toLowerCase() != 'open') return false;
      if (_activeQuickFilter == 'Won' && status.toLowerCase() != 'won') return false;
      if (_activeQuickFilter == 'Lost' && status.toLowerCase() != 'lost') return false;
      if (_activeQuickFilter == 'High Priority' && priority.toLowerCase() != 'hot') return false;
      if (_activeQuickFilter == 'Quotation Pending') {
        final quotationStatus = _getFirstString(data, ['quotationStatus', 'quoteStatus', 'quotationStage']).toLowerCase();
        if (status.toLowerCase() != 'quotation pending' && quotationStatus != 'quotation pending') return false;
      }

      if (_activeQuickFilter == 'Overdue' || _overdueOnly) {
        if (!_isInquiryOverdue(data, nextDate, status)) return false;
      }

      if (_dateRangeFilter != null) {
        final createdAt = _readInquiryCreatedAt(data);
        if (createdAt == null) return false;
        final start = DateTime(_dateRangeFilter!.start.year, _dateRangeFilter!.start.month, _dateRangeFilter!.start.day);
        final end = DateTime(_dateRangeFilter!.end.year, _dateRangeFilter!.end.month, _dateRangeFilter!.end.day, 23, 59, 59, 999);
        if (createdAt.isBefore(start) || createdAt.isAfter(end)) return false;
      }

      if (_recentlyUpdatedOnly) {
        final updatedAt = data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : null;
        if (updatedAt == null || DateTime.now().difference(updatedAt).inDays > 3) return false;
      }

      if (_quotationStatusFilter != 'All') {
        final quotationStatus = _getFirstString(data, ['quotationStatus', 'quoteStatus', 'quotationStage']);
        if (quotationStatus.toLowerCase() != _quotationStatusFilter.toLowerCase()) return false;
      }

      if (_customerFilter.isNotEmpty && !_matchesAny(data, ['customerName', 'companyName', 'customerCompanyName'], _customerFilter)) return false;
      if (_cityFilter.isNotEmpty && !_matchesAny(data, ['customerPrimaryCity', 'city', 'location', 'customerCity'], _cityFilter)) return false;
      if (_stateFilter.isNotEmpty && !_matchesAny(data, ['customerPrimaryState', 'state', 'customerState'], _stateFilter)) return false;
      if (_ownerFilter.isNotEmpty && !_matchesAny(data, ['ownerName', 'assignedToName', 'createdByName'], _ownerFilter)) return false;
      if (_assignedToFilter.isNotEmpty && !_matchesAny(data, ['assignedToName', 'assignedToEmail'], _assignedToFilter)) return false;
      if (_createdByFilter.isNotEmpty && !_matchesAny(data, ['createdByName', 'createdByEmail'], _createdByFilter)) return false;

      if (_productFilter.isNotEmpty) {
        final products = data['products'] as List? ?? [];
        final query = _productFilter.toLowerCase();
        final matchesProduct = products.any((item) {
          if (item is! Map) return item.toString().toLowerCase().contains(query);
          return item.values.any((value) => value.toString().toLowerCase().contains(query));
        });
        if (!matchesProduct) return false;
      }

      return true;
    }).toList();
  }

  // ========================================================
  // HELPERS
  // ========================================================
  String _getString(Map<String, dynamic>? data, String key) => (data?[key] ?? '').toString().trim();
  String _safeString(dynamic value) => (value ?? '').toString().trim();
  bool _isAdminOrManager(String role) => ['admin', 'manager', 'owner', 'founder', 'ceo', 'superadmin'].contains(role);

  String _getFirstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _getString(data, key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _matchesAny(Map<String, dynamic> data, List<String> keys, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return keys.any((key) => _getString(data, key).toLowerCase().contains(q));
  }

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;


  int _activeFilterCount() {
    int count = 0;
    if (_activeQuickFilter != 'All') count++;
    if (_statusFilter != 'All') count++;
    if (_priorityFilter != 'All') count++;
    if (_sourceFilter != 'All') count++;
    if (_inquiryTypeFilter != 'All') count++;
    if (_quotationStatusFilter != 'All') count++;
    if (_ownerFilter.isNotEmpty) count++;
    if (_customerFilter.isNotEmpty) count++;
    if (_cityFilter.isNotEmpty) count++;
    if (_stateFilter.isNotEmpty) count++;
    if (_productFilter.isNotEmpty) count++;
    if (_assignedToFilter.isNotEmpty) count++;
    if (_createdByFilter.isNotEmpty) count++;
    if (_dateRangeFilter != null) count++;
    if (_overdueOnly) count++;
    if (_recentlyUpdatedOnly) count++;
    return count;
  }

  String _filterButtonLabel() {
    final count = _activeFilterCount();
    return count == 0 ? 'Filters' : 'Filters ($count)';
  }

  void _applyFilterMutation(VoidCallback mutation, {bool refresh = true}) {
    setState(() {
      mutation();
      _currentPage = 1;
    });
    if (refresh) _refreshData();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (_searchQuery != value) {
        setState(() {
          _searchQuery = value;
          _currentPage = 1;
          _clientFilteredCache = null;
          _selectedIds.clear();
        });
        _fetchKPIs();
        _loadPage(1);
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _priorityFilter = 'All';
      _sourceFilter = 'All';
      _inquiryTypeFilter = 'All';
      _quotationStatusFilter = 'All';
      _ownerFilter = '';
      _customerFilter = '';
      _cityFilter = '';
      _stateFilter = '';
      _productFilter = '';
      _assignedToFilter = '';
      _createdByFilter = '';
      _dateRangeFilter = null;
      _overdueOnly = false;
      _recentlyUpdatedOnly = false;
      _activeQuickFilter = 'All';
      _searchController.clear();
      _searchQuery = '';
      _currentPage = 1;
    });
    _refreshData();
  }

  void _toggleColumn(String column) {
    setState(() {
      if (_visibleColumns.contains(column)) {
        if (_visibleColumns.length > 2) _visibleColumns.remove(column);
      } else {
        _visibleColumns.add(column);
      }
      _prefs?.setStringList('inquiry_columns', _visibleColumns);
    });
  }

  void _handleBulkAction(String action) {
    if (_selectedIds.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk $action initiated for ${_selectedIds.length} records. (Architecture ready)')));
    setState(() => _selectedIds.clear());
  }

  // ========================================================
  // WORKSPACE UI: HEADER
  // ========================================================
  Widget _buildWorkspaceHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _zSlate200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compactToolbar = constraints.maxWidth < 980;
          final Widget searchBox = _buildToolbarSearchBox();
          final Widget actionArea = _selectedIds.isNotEmpty ? _buildBulkActionBar() : _buildKpiBar();
          final Widget toolArea = _buildToolbarActions();

          if (compactToolbar) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchBox,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actionArea,
                      ),
                    ),
                    const SizedBox(width: 12),
                    toolArea,
                  ],
                ),
              ],
            );
          }

          final double searchWidth = math.min(300.0, math.max(260.0, constraints.maxWidth * 0.30)).toDouble();

          return Row(
            children: [
              SizedBox(width: searchWidth, child: searchBox),
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: actionArea,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              toolArea,
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbarSearchBox() {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 10.8, color: _zSlate700),
        decoration: InputDecoration(
          hintText: 'Search inquiries by customer, subject, code...',
          hintStyle: const TextStyle(color: _zSlate400, fontSize: 10.8),
          prefixIcon: const Icon(Icons.search, size: 14, color: _zSlate400),
          prefixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, size: 12, color: _zSlate500),
            padding: EdgeInsets.zero,
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
              _searchFocusNode.requestFocus();
            },
          )
              : null,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _zSlate200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _zSlate200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _zSlate300)),
        ),
      ),
    );
  }

  Widget _buildToolbarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          tooltip: 'Columns',
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.view_column_outlined, size: 15, color: _zSlate600),
          itemBuilder: (ctx) => _availableColumns.map((c) => CheckedPopupMenuItem(
            checked: _visibleColumns.contains(c),
            value: c,
            child: Text(c, style: const TextStyle(fontSize: 11.5)),
          )).toList(),
          onSelected: _toggleColumn,
        ),
        const SizedBox(width: 5),
        _ToolbarBtn(
          icon: Icons.filter_list,
          label: _filterButtonLabel(),
          isActive: _activeFilterCount() > 0,
          onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
      ],
    );
  }

  Widget _buildKpiBar() {
    return _isFetchingKPIs
        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _zSlate300))
        : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnterpriseKpi(title: 'Total', value: _totalRecords.toString()),
        const SizedBox(width: 12),
        _EnterpriseKpi(title: 'Open', value: _openRecords.toString()),
        const SizedBox(width: 12),
        _EnterpriseKpi(title: 'Follow-up', value: _followUpRecords.toString()),
        const SizedBox(width: 12),
        _EnterpriseKpi(title: 'Won', value: _wonRecords.toString()),
      ],
    );
  }

  Widget _buildBulkActionBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _zSlate100, borderRadius: BorderRadius.circular(4)),
          child: Text('${_selectedIds.length} Selected', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _zSlate700)),
        ),
        const SizedBox(width: 12),
        _ToolbarBtn(icon: Icons.assignment_ind_outlined, label: 'Assign', onTap: () => _handleBulkAction('Assign')),
        const SizedBox(width: 8),
        _ToolbarBtn(icon: Icons.delete_outline, label: 'Delete', onTap: () => _handleBulkAction('Delete')),
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
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _zSlate600)),
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

    if (_activeQuickFilter != 'All') chips.add(buildChip('Quick: $_activeQuickFilter', () => _applyFilterMutation(() => _activeQuickFilter = 'All')));
    if (_statusFilter != 'All') chips.add(buildChip('Status: $_statusFilter', () => _applyFilterMutation(() => _statusFilter = 'All')));
    if (_priorityFilter != 'All') chips.add(buildChip('Priority: $_priorityFilter', () => _applyFilterMutation(() => _priorityFilter = 'All')));
    if (_sourceFilter != 'All') chips.add(buildChip('Source: $_sourceFilter', () => _applyFilterMutation(() => _sourceFilter = 'All')));
    if (_inquiryTypeFilter != 'All') chips.add(buildChip('Type: $_inquiryTypeFilter', () => _applyFilterMutation(() => _inquiryTypeFilter = 'All')));
    if (_quotationStatusFilter != 'All') chips.add(buildChip('Quotation: $_quotationStatusFilter', () => _applyFilterMutation(() => _quotationStatusFilter = 'All')));
    if (_customerFilter.isNotEmpty) chips.add(buildChip('Customer: $_customerFilter', () => _applyFilterMutation(() => _customerFilter = '')));
    if (_cityFilter.isNotEmpty) chips.add(buildChip('City: $_cityFilter', () => _applyFilterMutation(() => _cityFilter = '')));
    if (_stateFilter.isNotEmpty) chips.add(buildChip('State: $_stateFilter', () => _applyFilterMutation(() => _stateFilter = '')));
    if (_ownerFilter.isNotEmpty) chips.add(buildChip('Owner: $_ownerFilter', () => _applyFilterMutation(() => _ownerFilter = '')));
    if (_assignedToFilter.isNotEmpty) chips.add(buildChip('Assigned: $_assignedToFilter', () => _applyFilterMutation(() => _assignedToFilter = '')));
    if (_createdByFilter.isNotEmpty) chips.add(buildChip('Creator: $_createdByFilter', () => _applyFilterMutation(() => _createdByFilter = '')));
    if (_productFilter.isNotEmpty) chips.add(buildChip('Product: $_productFilter', () => _applyFilterMutation(() => _productFilter = '')));
    if (_dateRangeFilter != null) chips.add(buildChip('Date Range', () => _applyFilterMutation(() => _dateRangeFilter = null)));
    if (_overdueOnly) chips.add(buildChip('Overdue Only', () => _applyFilterMutation(() => _overdueOnly = false)));
    if (_recentlyUpdatedOnly) chips.add(buildChip('Recent Updates', () => _applyFilterMutation(() => _recentlyUpdatedOnly = false)));

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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
            child: Text('Active filters', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _zSlate500)),
          ),
          ...chips,
          InkWell(
            onTap: _resetFilters,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text('Clear all', style: TextStyle(fontSize: 10, color: _zSlate600, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================
  // DATA GRID UI (STICKY HEADER)
  // ========================================================
  Widget _buildTableHeader() {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FA),
        border: Border(bottom: BorderSide(color: _zSlate300, width: 0.9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: _gridHorizontalPadding),
      child: Row(
        children: [
          SizedBox(
            width: _gridSelectWidth,
            child: Checkbox(
              value: _currentDocs.isNotEmpty && _selectedIds.length == _currentDocs.length,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.addAll(_currentDocs.map((e) => e.id));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: _zSlate700,
            ),
          ),
          const SizedBox(width: _gridSelectGap),
          if (_visibleColumns.contains('Customer'))
            const Expanded(flex: _colCustomerFlex, child: _HeaderText('Customer')),
          if (_visibleColumns.contains('Status'))
            const Expanded(flex: _colStatusFlex, child: _HeaderText('Status')),
          if (_visibleColumns.contains('Assigned To'))
            const Expanded(flex: _colAssignedFlex, child: _HeaderText('Assigned To')),
          if (_visibleColumns.contains('Products'))
            const Expanded(flex: _colProductsFlex, child: _HeaderText('Products')),
          if (_visibleColumns.contains('Follow-up'))
            const Expanded(flex: _colFollowUpFlex, child: _HeaderText('Follow-up')),
          if (_visibleColumns.contains('Age'))
            const Expanded(flex: _colAgeFlex, child: _HeaderText('Age')),
          if (_visibleColumns.contains('Actions'))
            const SizedBox(width: _gridActionWidth, child: Center(child: _HeaderText('Actions'))),
        ],
      ),
    );
  }

  // ========================================================
  // PAGINATION ROW (SCROLLS AFTER DATA ROWS)
  // ========================================================
  Widget _buildPaginationFooter() {
    final int totalPages = math.max(1, (_totalRecords / _itemsPerPage).ceil()).toInt();
    final int startRecord = _totalRecords == 0 ? 0 : ((_currentPage - 1) * _itemsPerPage) + 1;
    final int endRecord = math.min(_currentPage * _itemsPerPage, _totalRecords).toInt();

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: _gridHorizontalPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _zSlate200), bottom: BorderSide(color: _zSlate100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startRecord to $endRecord of $_totalRecords',
            style: const TextStyle(fontSize: 10.5, color: _zSlate500, fontWeight: FontWeight.w500),
          ),
          if (totalPages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPaginationTextButton('Previous', _currentPage > 1 && !_isLoadingPage ? () => _loadPage(_currentPage - 1) : null),
                const SizedBox(width: 4),
                ..._buildVisiblePaginationItems(totalPages),
                const SizedBox(width: 4),
                _buildPaginationTextButton('Next', _currentPage < totalPages && !_isLoadingPage ? () => _loadPage(_currentPage + 1) : null),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildVisiblePaginationItems(int totalPages) {
    final List<Widget> items = [];
    final int windowStart = math.max(1, math.min(_currentPage - 2, math.max(1, totalPages - 4))).toInt();
    final int windowEnd = math.min(totalPages, windowStart + 4).toInt();

    if (windowStart > 1) {
      items.add(_buildPageButton(1));
      if (windowStart > 2) items.add(_paginationEllipsis());
    }

    for (int page = windowStart; page <= windowEnd; page++) {
      items.add(_buildPageButton(page));
    }

    if (windowEnd < totalPages) {
      if (windowEnd < totalPages - 1) items.add(_paginationEllipsis());
      items.add(_buildPaginationTextButton('Last', !_isLoadingPage ? () => _loadPage(totalPages) : null));
    }

    return items
        .expand((w) => [w, const SizedBox(width: 4)])
        .toList()
      ..removeLast();
  }

  Widget _paginationEllipsis() {
    return const SizedBox(
      width: 22,
      height: 26,
      child: Center(child: Text('...', style: TextStyle(fontSize: 11, color: _zSlate400, fontWeight: FontWeight.w600))),
    );
  }

  Widget _buildPaginationTextButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      height: 24,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: _zSlate700,
          disabledForegroundColor: _zSlate300,
          textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildPageButton(int page) {
    final bool active = page == _currentPage;
    return InkWell(
      onTap: active || _isLoadingPage ? null : () => _loadPage(page),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _zSlate800 : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? _zSlate800 : _zSlate200),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            color: active ? Colors.white : _zSlate600,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: _zSlate300),
          const SizedBox(height: 14),
          const Text('No inquiries found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _zSlate700)),
          const SizedBox(height: 6),
          const Text('Try adjusting your filters or search query.', style: TextStyle(fontSize: 12, color: _zSlate500)),
        ],
      ),
    );
  }

  // ========================================================
  // ADVANCED ENTERPRISE FILTER DRAWER
  // ========================================================
  Widget _buildEnterpriseFilterDrawer() {
    return Drawer(
      width: 340,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _zSlate200))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Advanced Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _zSlate800)),
                    const SizedBox(height: 2),
                    Text(_activeFilterCount() == 0 ? 'No filters applied' : '${_activeFilterCount()} filter${_activeFilterCount() == 1 ? '' : 's'} applied', style: const TextStyle(fontSize: 9.8, color: _zSlate500)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: _zSlate500),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 18),
              children: [
                _buildFilterGroup(
                  title: 'General',
                  expanded: _generalExpanded,
                  onChanged: (v) => setState(() => _generalExpanded = v),
                  children: [
                    _buildDrawerDropdown('Status', _statusFilter, ['All', 'Open', 'Qualified', 'Quotation Pending', 'Quotation Sent', 'Follow-up Pending', 'Won', 'Lost', 'Not Qualified'], (v) => setState(() => _statusFilter = v!)),
                    const SizedBox(height: 10),
                    _buildDrawerDropdown('Priority', _priorityFilter, ['All', 'Hot', 'Warm', 'Cold'], (v) => setState(() => _priorityFilter = v!)),
                    const SizedBox(height: 10),
                    _buildDrawerDropdown('Source', _sourceFilter, ['All', 'Website', 'Reference', 'Cold Call', 'Exhibition', 'Other'], (v) => setState(() => _sourceFilter = v!)),
                    const SizedBox(height: 10),
                    _buildDrawerDropdown('Inquiry Type', _inquiryTypeFilter, ['All', 'Sales', 'Service', 'AMC', 'Project', 'Other'], (v) => setState(() => _inquiryTypeFilter = v!)),
                    const SizedBox(height: 10),
                    _buildDrawerDropdown('Quotation Status', _quotationStatusFilter, ['All', 'Not Started', 'Quotation Pending', 'Quotation Sent', 'Approved', 'Rejected'], (v) => setState(() => _quotationStatusFilter = v!)),
                  ],
                ),
                _buildFilterGroup(
                  title: 'Customer',
                  expanded: _customerExpanded,
                  onChanged: (v) => setState(() => _customerExpanded = v),
                  children: [
                    _buildDrawerTextField('Customer Name', _customerFilter, (v) => setState(() => _customerFilter = v)),
                    const SizedBox(height: 10),
                    _buildDrawerTextField('City', _cityFilter, (v) => setState(() => _cityFilter = v)),
                    const SizedBox(height: 10),
                    _buildDrawerTextField('State', _stateFilter, (v) => setState(() => _stateFilter = v)),
                  ],
                ),
                _buildFilterGroup(
                  title: 'Assignment',
                  expanded: _assignmentExpanded,
                  onChanged: (v) => setState(() => _assignmentExpanded = v),
                  children: [
                    _buildDrawerTextField('Owner', _ownerFilter, (v) => setState(() => _ownerFilter = v)),
                    const SizedBox(height: 10),
                    _buildDrawerTextField('Assigned To', _assignedToFilter, (v) => setState(() => _assignedToFilter = v)),
                    const SizedBox(height: 10),
                    _buildDrawerTextField('Created By', _createdByFilter, (v) => setState(() => _createdByFilter = v)),
                  ],
                ),
                _buildFilterGroup(
                  title: 'Products',
                  expanded: _productsExpanded,
                  onChanged: (v) => setState(() => _productsExpanded = v),
                  children: [
                    _buildDrawerTextField('Product / Item', _productFilter, (v) => setState(() => _productFilter = v)),
                  ],
                ),
                _buildFilterGroup(
                  title: 'Dates',
                  expanded: _dateExpanded,
                  onChanged: (v) => setState(() => _dateExpanded = v),
                  children: [
                    _buildDateRangeField(),
                    const SizedBox(height: 8),
                    _buildDrawerSwitch('Overdue inquiries only', _overdueOnly, (v) => setState(() => _overdueOnly = v)),
                    _buildDrawerSwitch('Updated in last 3 days', _recentlyUpdatedOnly, (v) => setState(() => _recentlyUpdatedOnly = v)),
                  ],
                ),
                _buildFilterGroup(
                  title: 'Quick Filters',
                  expanded: _quickFiltersExpanded,
                  onChanged: (v) => setState(() => _quickFiltersExpanded = v),
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickFilters.map((filter) => _buildQuickFilterChip(filter)).toList(),
                    ),
                  ],
                ),
                _buildFilterGroup(
                  title: 'Saved Filters',
                  expanded: _savedFiltersExpanded,
                  onChanged: (v) => setState(() => _savedFiltersExpanded = v),
                  children: [
                    _buildSavedFilterTile(
                      title: 'Default View',
                      subtitle: 'All active inquiries',
                      onTap: () {
                        Navigator.pop(context);
                        _resetFilters();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSavedFilterTile(
                      title: 'My Inquiries',
                      subtitle: 'Assigned to me or created by me',
                      onTap: () {
                        setState(() => _activeQuickFilter = 'My Inquiries');
                        Navigator.pop(context);
                        _refreshData();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _zSlate200))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _zSlate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      minimumSize: const Size.fromHeight(34),
                    ),
                    child: const Text('Reset', style: TextStyle(color: _zSlate700, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _refreshData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _zSlate800,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      minimumSize: const Size.fromHeight(34),
                    ),
                    child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup({
    required String title,
    required bool expanded,
    required ValueChanged<bool> onChanged,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: _zSlate500,
        collapsedIconColor: _zSlate400,
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _zSlate800)),
        children: children,
      ),
    );
  }

  Widget _buildQuickFilterChip(String filter) {
    final bool isActive = _activeQuickFilter == filter;
    return InkWell(
      onTap: () => setState(() => _activeQuickFilter = filter),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? _zSlate800 : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isActive ? _zSlate800 : _zSlate200),
        ),
        child: Text(
          filter,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : _zSlate600,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeField() {
    final label = _dateRangeFilter == null
        ? 'Select created date range'
        : '${DateFormat('d MMM yy').format(_dateRangeFilter!.start)} - ${DateFormat('d MMM yy').format(_dateRangeFilter!.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Created Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _zSlate600)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _dateRangeFilter,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: _zSlate800, onPrimary: Colors.white, onSurface: _zSlate800)),
                  child: child!,
                );
              },
            );
            if (picked != null && mounted) setState(() => _dateRangeFilter = picked);
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _zSlate200),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: _dateRangeFilter == null ? _zSlate400 : _zSlate800))),
                if (_dateRangeFilter != null)
                  InkWell(
                    onTap: () => setState(() => _dateRangeFilter = null),
                    child: const Icon(Icons.close, size: 14, color: _zSlate400),
                  )
                else
                  const Icon(Icons.calendar_today_outlined, size: 14, color: _zSlate400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedFilterTile({required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: _zSlate200),
          borderRadius: BorderRadius.circular(4),
          color: _zSlate50,
        ),
        child: Row(
          children: [
            const Icon(Icons.bookmark_border, size: 15, color: _zSlate500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _zSlate800)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: _zSlate500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 32,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 12, color: _zSlate700, fontWeight: FontWeight.w500)),
        value: value,
        activeColor: _zSlate700,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDrawerDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _zSlate600)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: DropdownButtonFormField<String>(
            value: items.contains(value) ? value : items.first,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _zSlate200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _zSlate200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _zSlate300)),
            ),
            style: const TextStyle(fontSize: 12, color: _zSlate800),
            icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: _zSlate500),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerTextField(String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _zSlate600)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextFormField(
            initialValue: value,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12, color: _zSlate800),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _zSlate200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _zSlate200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _zSlate300)),
            ),
          ),
        ),
      ],
    );
  }

  // --- ACTIONS ---
  Future<void> _openEditInquiry(QueryDocumentSnapshot<Map<String, dynamic>> doc, Inquiry inquiry) async {
    final docData = doc.data();
    final targetCompanyId = _getString(docData, 'companyId').isNotEmpty ? _getString(docData, 'companyId') : (_companyId ?? '');
    if (targetCompanyId.isEmpty) return;

    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScreensAddInquiry(companyId: targetCompanyId, currentUserUid: _currentUser!.uid, currentUserRole: _userRole, existingDoc: doc.reference, existingInquiry: inquiry),
    ));

    if (result == true && mounted) {
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inquiry updated'), backgroundColor: Colors.green));
    }
  }

  Future<void> _openQuotationFromInquiry(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final inquiryData = doc.data();
    final targetCompanyId = _getString(inquiryData, 'companyId').isNotEmpty ? _getString(inquiryData, 'companyId') : (_companyId ?? '');
    if (targetCompanyId.isEmpty) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    Map<String, dynamic> customerData = {};
    final customerId = _getString(inquiryData, 'customerId');

    if (customerId.isNotEmpty) {
      try {
        final custDoc = await FirebaseFirestore.instance.collection('companies').doc(targetCompanyId).collection('customers').doc(customerId).get();
        if (custDoc.exists && custDoc.data() != null) customerData = custDoc.data()!;
      } catch (e) {
        debugPrint("CRM Customer Fetch Error: $e");
      }
    }

    if (context.mounted) Navigator.pop(context);

    final fallbackCustomerName = _getString(inquiryData, 'customerName');
    final Map<String, dynamic> comprehensiveSeed = {
      'id': doc.id,
      'inquiryId': doc.id,
      'inquiryNumber': _getString(inquiryData, 'inquiryNumber'),
      'customerId': customerId,
      'customerName': customerData['companyName'] ?? customerData['name'] ?? fallbackCustomerName,
      'contactPerson': _getString(inquiryData, 'contactName').isNotEmpty ? _getString(inquiryData, 'contactName') : (customerData['contactPerson'] ?? ''),
      'mobile': _getString(inquiryData, 'contactPhone').isNotEmpty ? _getString(inquiryData, 'contactPhone') : (customerData['mobile'] ?? customerData['phone'] ?? ''),
      'email': _getString(inquiryData, 'contactEmail').isNotEmpty ? _getString(inquiryData, 'contactEmail') : (customerData['email'] ?? ''),
      'address': _getString(inquiryData, 'customerPrimaryAddress').isNotEmpty ? _getString(inquiryData, 'customerPrimaryAddress') : (customerData['address'] ?? customerData['billingAddress'] ?? ''),
      'state': _getString(inquiryData, 'customerPrimaryState').isNotEmpty ? _getString(inquiryData, 'customerPrimaryState') : (customerData['state'] ?? ''),
      'gstNo': _getString(inquiryData, 'customerGST').isNotEmpty ? _getString(inquiryData, 'customerGST') : (customerData['gstNo'] ?? customerData['gst'] ?? ''),
      'subject': _getString(inquiryData, 'subject'),
      'notes': inquiryData['notes'] ?? inquiryData['lastFollowUpNote'] ?? '',
      'location': _getString(inquiryData, 'customerPrimaryCity').isNotEmpty ? _getString(inquiryData, 'customerPrimaryCity') : _getString(inquiryData, 'location'),
      'source': _getString(inquiryData, 'source'),
      'items': inquiryData['products'] ?? inquiryData['items'] ?? [],
    };

    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationScreenLocal(currentUserUid: _currentUser?.uid, companyId: targetCompanyId, inquirySeed: comprehensiveSeed)));
  }

  Future<void> _deleteInquiry(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    bool isDeleting = false;
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24), SizedBox(width: 10), Text('Delete Inquiry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
              content: const Text('Are you sure you want to delete this inquiry?', style: TextStyle(fontSize: 12, color: _zSlate700)),
              actions: [
                TextButton(onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
                ElevatedButton(
                  onPressed: isDeleting ? null : () async {
                    setState(() => isDeleting = true);
                    try {
                      final data = doc.data();
                      final existingLog = List<dynamic>.from(data['activityLog'] ?? []);
                      existingLog.add({'actionType': 'Delete', 'module': 'Inquiry', 'description': 'Inquiry soft deleted via UI.', 'uid': _currentUser?.uid ?? '', 'timestamp': FieldValue.serverTimestamp(), 'auditVersion': 2});
                      await doc.reference.update({'isDeleted': true, 'isActive': false, 'deletedAt': FieldValue.serverTimestamp(), 'deletedBy': _currentUser?.uid ?? '', 'activityLog': existingLog});
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                    } catch (e) {
                      setState(() => isDeleting = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, elevation: 0),
                  child: isDeleting ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Delete', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmDelete == true && mounted) {
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inquiry deleted successfully'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profileDataFuture == null) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: _zSlate300, strokeWidth: 2)));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: _buildEnterpriseFilterDrawer(),
      floatingActionButton: SizedBox(
        width: 52,
        height: 52,
        child: FloatingActionButton(
          tooltip: 'Add Inquiry',
          backgroundColor: _zErpPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onPressed: () async {
            if(_companyId == null) return;
            final role = widget.companyId == null ? 'sales' : 'admin';
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensAddInquiry(companyId: _companyId!, currentUserUid: _currentUser!.uid, currentUserRole: role)));
            if (result == true && mounted) {
              _refreshData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inquiry added'), backgroundColor: Colors.green));
            }
          },
          child: const Icon(Icons.add, size: 18),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorkspaceHeader(),
          _buildActiveFiltersSummary(),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: constraints.maxWidth < 1000 ? 1000 : constraints.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTableHeader(),
                        Expanded(
                          child: _isLoadingPage
                              ? ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: 12,
                            itemBuilder: (_, i) => _SkeletonRow(density: _densityMode, visibleColumns: _visibleColumns, index: i),
                          )
                              : _currentDocs.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                            controller: _tableScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: _currentDocs.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _currentDocs.length) {
                                return _buildPaginationFooter();
                              }

                              final doc = _currentDocs[index];
                              final inquiry = Inquiry.fromSnapshot(doc);
                              return _EnterpriseDataRow(
                                key: ValueKey(doc.id),
                                doc: doc,
                                inquiry: inquiry,
                                density: _densityMode,
                                visibleColumns: _visibleColumns,
                                isSelected: _selectedIds.contains(doc.id),
                                onSelect: (val) {
                                  setState(() {
                                    if (val == true) _selectedIds.add(doc.id);
                                    else _selectedIds.remove(doc.id);
                                  });
                                },
                                onEdit: () => _openEditInquiry(doc, inquiry),
                                onQuote: () => _openQuotationFromInquiry(doc),
                                onDelete: () => _deleteInquiry(doc),
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
      ),
    );
  }
}

// --- MICRO WIDGETS ---

class _SortableHeader extends StatelessWidget {
  final String label;
  final String columnKey;
  const _SortableHeader(this.label, this.columnKey);

  @override
  Widget build(BuildContext context) {
    return _HeaderText(label);
  }
}

class _HeaderText extends StatelessWidget {
  final String label;
  const _HeaderText(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(fontSize: 10.1, fontWeight: FontWeight.w600, color: _zSlate600, letterSpacing: 0.04),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  const _ToolbarBtn({required this.icon, required this.label, required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? _zSlate100 : Colors.white,
          border: Border.all(color: isActive ? _zSlate300 : _zSlate200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: isActive ? _zSlate700 : _zSlate500),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: isActive ? _zSlate700 : _zSlate600)),
          ],
        ),
      ),
    );
  }
}

class _EnterpriseKpi extends StatelessWidget {
  final String title, value;
  const _EnterpriseKpi({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: const TextStyle(fontSize: 10.2, color: _zSlate500, fontWeight: FontWeight.w500)),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _zSlate700)),
      ],
    );
  }
}

// --- ENTERPRISE SKELETON ROW ---
class _SkeletonRow extends StatelessWidget {
  final String density;
  final List<String> visibleColumns;
  final int index;

  const _SkeletonRow({required this.density, required this.visibleColumns, required this.index});

  @override
  Widget build(BuildContext context) {
    const double rowHeight = 50.0;
    return Container(
      height: rowHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _zSlate100, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: _gridHorizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: _gridSelectWidth, child: Icon(Icons.check_box_outline_blank, color: _zSlate200, size: 14)),
          const SizedBox(width: _gridSelectGap),
          if (visibleColumns.contains('Customer'))
            Expanded(
              flex: _colCustomerFlex,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(116),
                    const SizedBox(height: 5),
                    _block(156),
                  ],
                ),
              ),
            ),
          if (visibleColumns.contains('Status')) Expanded(flex: _colStatusFlex, child: _block(62)),
          if (visibleColumns.contains('Assigned To')) Expanded(flex: _colAssignedFlex, child: _block(82)),
          if (visibleColumns.contains('Products')) Expanded(flex: _colProductsFlex, child: _block(88)),
          if (visibleColumns.contains('Follow-up')) Expanded(flex: _colFollowUpFlex, child: _block(52)),
          if (visibleColumns.contains('Age')) Expanded(flex: _colAgeFlex, child: _block(30)),
          if (visibleColumns.contains('Actions')) const SizedBox(width: _gridActionWidth, child: Icon(Icons.more_vert, color: _zSlate200, size: 15)),
        ],
      ),
    );
  }

  Widget _block(double baseWidth, {double height = 9}) {
    final double width = baseWidth * (0.72 + (index % 3) * 0.12);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: _zSlate100, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}

// --- ENTERPRISE HYBRID TABLE ROW CARD ---
class _EnterpriseDataRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Inquiry inquiry;
  final String density;
  final List<String> visibleColumns;
  final bool isSelected;
  final Function(bool?) onSelect;
  final VoidCallback onEdit;
  final VoidCallback onQuote;
  final VoidCallback onDelete;

  const _EnterpriseDataRow({
    super.key,
    required this.doc,
    required this.inquiry,
    required this.density,
    required this.visibleColumns,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onQuote,
    required this.onDelete,
  });

  @override
  State<_EnterpriseDataRow> createState() => _EnterpriseDataRowState();
}

class _EnterpriseDataRowState extends State<_EnterpriseDataRow> {
  bool _isHovered = false;

  String _getString(Map<String, dynamic> data, String key) => (data[key] ?? '').toString().trim();

  String _formatRelativeDate(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('d MMM').format(date);
  }

  String _getAge(DateTime? createdAt) {
    if (createdAt == null) return '-';
    final days = DateTime.now().difference(createdAt).inDays;
    if (days == 0) return 'Today';
    return '${days}D';
  }

  Widget _buildAssignedToCell(String owner) {
    final display = owner.trim().isEmpty ? 'Unassigned' : owner.trim();
    return Text(
      display,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11.0, height: 1.12, color: _zSlate600, fontWeight: FontWeight.w400),
    );
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return _zSlate700;
      case 'qualified':
        return const Color(0xFF5F735F);
      case 'quotation pending':
      case 'quotation sent':
        return const Color(0xFF5F7894);
      case 'follow-up':
      case 'follow up':
      case 'follow-up pending':
      case 'follow up pending':
        return const Color(0xFF6D665A);
      case 'won':
        return const Color(0xFF5E735F);
      case 'lost':
      case 'not qualified':
        return _zSlate500;
      default:
        return _zSlate600;
    }
  }

  Widget _buildMinimalStatusText(String status, String priority, bool isOverdue) {
    final String cleanStatus = status.trim().isEmpty ? 'Open' : status.trim();
    final String cleanPriority = priority.trim();

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanStatus,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 11.0,
              height: 1.08,
              fontWeight: FontWeight.w500,
              color: isOverdue ? const Color(0xFF8A4F4F) : _statusTextColor(cleanStatus),
            ),
          ),
          if (cleanPriority.isNotEmpty) const SizedBox(height: 3),
          if (cleanPriority.isNotEmpty)
            Text(
              cleanPriority,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                fontSize: 10.0,
                height: 1.05,
                fontWeight: FontWeight.w400,
                color: _zSlate500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _linkText({
    required String text,
    required TextStyle style,
    required VoidCallback onTap,
    bool fillWidth = true,
  }) {
    final Widget child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: style,
      ),
    );

    if (!fillWidth) return child;
    return SizedBox(width: double.infinity, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();

    final isDeleted = data['isDeleted'] == true;
    final isActive = data['isActive'] != false;
    final isRestricted = data['isLocked'] == true || data['isArchived'] == true || isDeleted || !isActive;

    final subject = _getString(data, 'subject').isEmpty ? 'No Subject' : _getString(data, 'subject');
    final inqNumber = _getString(data, 'inquiryNumber').isEmpty ? '-' : _getString(data, 'inquiryNumber');
    final customer = _getString(data, 'customerName').isEmpty ? 'Unknown Customer' : _getString(data, 'customerName');

    final status = _getString(data, 'status').isEmpty ? 'Open' : _getString(data, 'status');
    final priority = _getString(data, 'priority').isEmpty ? 'Warm' : _getString(data, 'priority');
    final owner = _getString(data, 'assignedToName').isEmpty ? 'Unassigned' : _getString(data, 'assignedToName');

    final createdAtTs = data['createdAt'];
    final nextTs = data['nextFollowUpDate'];
    final createdAt = createdAtTs is Timestamp ? createdAtTs.toDate() : null;
    final nextDate = nextTs is Timestamp ? nextTs.toDate() : null;

    final ageText = _getAge(createdAt);
    final followUpText = _formatRelativeDate(nextDate);
    final isOverdue = _isInquiryOverdue(data, nextDate, status);

    final products = data['products'] as List? ?? [];
    int pCount = products.length;
    double tQty = 0;
    String pName = '';
    if (pCount > 0) {
      final first = products.first;
      if (first is Map) {
        final firstMap = Map<String, dynamic>.from(first);
        pName = _getString(firstMap, 'name').isNotEmpty ? _getString(firstMap, 'name') : _getString(firstMap, 'productName');
      }
      for (final p in products) {
        if (p is Map) {
          final productMap = Map<String, dynamic>.from(p);
          tQty += double.tryParse(_getString(productMap, 'quantity')) ?? 0.0;
        }
      }
    }
    if (pName.isEmpty && pCount > 0) pName = 'Item';
    final String qtyText = tQty.toStringAsFixed(tQty.truncateToDouble() == tQty ? 0 : 2);
    final String productNameLine = '$pName${pCount > 1 ? ' +${pCount - 1}' : ''}';

    const double rowHeight = 50.0;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: () => widget.onSelect(!widget.isSelected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: rowHeight,
            decoration: BoxDecoration(
              color: widget.isSelected ? const Color(0xFFF7FAFD) : (_isHovered ? const Color(0xFFFBFCFE) : Colors.white),
              border: Border(
                bottom: const BorderSide(color: _zSlate100, width: 1),
                left: BorderSide(color: widget.isSelected || _isHovered ? _zSoftHoverBorder : Colors.transparent, width: 2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: _gridHorizontalPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _gridSelectWidth,
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: widget.onSelect,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: _zSlate700,
                  ),
                ),
                const SizedBox(width: _gridSelectGap),

                if (widget.visibleColumns.contains('Customer'))
                  Expanded(
                    flex: _colCustomerFlex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                flex: 4,
                                fit: FlexFit.loose,
                                child: _linkText(
                                  text: customer,
                                  onTap: widget.onEdit,
                                  fillWidth: false,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    height: 1.08,
                                    fontWeight: FontWeight.w600,
                                    color: isDeleted ? _zSlate400 : _zSlate800,
                                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                flex: 2,
                                fit: FlexFit.loose,
                                child: _linkText(
                                  text: '($inqNumber)',
                                  onTap: widget.onEdit,
                                  fillWidth: false,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    height: 1.08,
                                    fontWeight: FontWeight.w400,
                                    color: _zInquiryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: const TextStyle(fontSize: 10.0, height: 1.10, fontWeight: FontWeight.w400, color: _zSlate500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (widget.visibleColumns.contains('Status'))
                  Expanded(
                    flex: _colStatusFlex,
                    child: _buildMinimalStatusText(status, priority, isOverdue),
                  ),

                if (widget.visibleColumns.contains('Assigned To'))
                  Expanded(
                    flex: _colAssignedFlex,
                    child: _buildAssignedToCell(owner),
                  ),

                if (widget.visibleColumns.contains('Products'))
                  Expanded(
                    flex: _colProductsFlex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: pCount == 0
                          ? const Text(
                        '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(fontSize: 11.0, height: 1.10, color: _zSlate300, fontWeight: FontWeight.w400),
                      )
                          : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productNameLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 11.0,
                              height: 1.08,
                              color: _zSlate700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Qty $qtyText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 10.0,
                              height: 1.05,
                              color: _zSlate500,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (widget.visibleColumns.contains('Follow-up'))
                  Expanded(
                    flex: _colFollowUpFlex,
                    child: Text(
                      followUpText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.0, height: 1.12, fontWeight: FontWeight.w500, color: isOverdue ? const Color(0xFF8A4F4F) : _zSlate600),
                    ),
                  ),

                if (widget.visibleColumns.contains('Age'))
                  Expanded(
                    flex: _colAgeFlex,
                    child: Text(ageText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.0, height: 1.12, fontWeight: FontWeight.w500, color: _zSlate600)),
                  ),

                if (widget.visibleColumns.contains('Actions'))
                  SizedBox(
                    width: _gridActionWidth,
                    child: Center(
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert, size: 15, color: _isHovered ? _zSlate600 : _zSlate400.withOpacity(0.58)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: _zSlate200)),
                        onSelected: (val) {
                          if (val == 'edit') widget.onEdit();
                          if (val == 'quote') widget.onQuote();
                          if (val == 'delete') widget.onDelete();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', height: 30, child: Row(children: [Icon(Icons.edit_outlined, size: 13, color: _zSlate600), SizedBox(width: 8), Text('Edit', style: TextStyle(fontSize: 11.5, color: _zSlate700))])),
                          PopupMenuItem(value: 'quote', height: 30, enabled: !isRestricted, child: Row(children: [Icon(Icons.request_quote_outlined, size: 13, color: isRestricted ? _zSlate300 : _zSlate600), const SizedBox(width: 8), Text('Quote', style: TextStyle(fontSize: 11.5, color: isRestricted ? _zSlate400 : _zSlate700))])),
                          const PopupMenuDivider(height: 8),
                          PopupMenuItem(value: 'delete', height: 30, enabled: !isRestricted, child: Row(children: [Icon(Icons.delete_outline, size: 13, color: isRestricted ? _zSlate300 : const Color(0xFF8A5F5F)), const SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 11.5, color: isRestricted ? _zSlate400 : const Color(0xFF8A5F5F)))])),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

