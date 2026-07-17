// FILE PATH: lib/modules/sales/inquiries/screens_add_inquiry.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:QUIK/models/inquiry_activity.dart';
import 'package:QUIK/models/inquiry_model.dart';
import 'package:QUIK/modules/crm/customers/screens_add_customer.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_screen.dart';
import 'package:QUIK/modules/sales/inquiries/inquiry_activity_service.dart';
import 'package:QUIK/modules/sales/inquiries/widgets/inquiry_activity_timeline.dart';
import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';

class ScreensAddInquiry extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;
  final DocumentReference<Map<String, dynamic>>? existingDoc;
  final Inquiry? existingInquiry;

  const ScreensAddInquiry({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
    this.existingDoc,
    this.existingInquiry,
  });

  @override
  State<ScreensAddInquiry> createState() => _ScreensAddInquiryState();
}

class _ScreensAddInquiryState extends State<ScreensAddInquiry> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Core Identifiers & DRY Snapshots
  String? _selectedCustomerId;
  String? _selectedContactId;
  List<String> _additionalContactIds = <String>[];
  String? _assignedToUid;
  String? _recordOwnerUid;

  // Enterprise Customer Snapshots
  String _customerNameSnapshot = '';
  String _customerCodeSnapshot = '';
  String _customerIndustrySnapshot = '';
  String _customerStageSnapshot = '';
  String _customerPhoneSnapshot = '';
  String _customerEmailSnapshot = '';
  String _customerGSTSnapshot = '';
  String _customerAssignedToUidSnapshot = '';
  String _customerAssignedToNameSnapshot = '';

  // Address Snapshots
  List<Map<String, dynamic>> _customerAddresses = <Map<String, dynamic>>[];
  String? _selectedAddressId;
  Map<String, dynamic>? _selectedAddressData;
  String _customerPrimaryAddressSnapshot = '';
  String _customerPrimaryCitySnapshot = '';
  String _customerPrimaryStateSnapshot = '';
  String _customerPrimaryCountrySnapshot = '';
  String _customerPrimaryPincodeSnapshot = '';

  // CRM Classification
  String? _selectedSource;
  String? _selectedType;
  String _selectedPriority = 'Warm';

  // Follow-up & Dates
  DateTime? _nextFollowUpDate;
  String _followUpType = 'Call';
  DateTime? _inquiryDate;
  bool _isFollowUpManuallyEdited = false;

  // Controllers
  final TextEditingController _inquirySequenceController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _lastFollowUpNoteController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();

  // Structured Products (ERP Grade Inventory Connection)
  List<Map<String, dynamic>> _structuredProducts = <Map<String, dynamic>>[];

  // State Flags & Concurrency
  bool _isSaving = false;
  bool _isLockedForm = false;
  String? _formMessage;
  String? _lockReason;
  final Map<String, bool> _sectionExpanded = <String, bool>{
    'Customer & Contacts': true,
    'Inquiry Basics': true,
    'Products & Scope': true,
    'Follow-up & Activity': true,
  };

  // Enterprise Caching & Concurrency Control
  Map<String, dynamic>? _selectedCustomerData;
  Map<String, dynamic>? _selectedContactData;
  Map<String, dynamic>? _assignedUserData;
  Map<String, dynamic>? _existingRawData;
  DocumentReference<Map<String, dynamic>>? _pendingCreateInquiryRef;
  String? _pendingMutationId;
  String? _savedInquiryId;
  String? _savedInquiryNumber;

  // LRU Cache for Search
  Timer? _debounceTimer;
  Timer? _autosaveTimer;
  int _customerSearchEpoch = 0;
  final int _maxCacheSize = 50;
  final LinkedHashMap<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _customerSearchCache = LinkedHashMap<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allCustomerDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  List<DocumentSnapshot<Map<String, dynamic>>> _customerSuggestions = <DocumentSnapshot<Map<String, dynamic>>>[];

  bool get _isEditing => widget.existingDoc != null;

  bool get _isAdminOrManager {
    final role = widget.currentUserRole.trim().toLowerCase();
    return ['admin', 'manager', 'director', 'md', 'ceo', 'superadmin'].contains(role);
  }

  // Firestore References
  CollectionReference<Map<String, dynamic>> get _companyCustomersRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('customers');

  CollectionReference<Map<String, dynamic>> get _companyUsersRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users');

  CollectionReference<Map<String, dynamic>> get _companyInquiriesRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('inquiries');

  CollectionReference<Map<String, dynamic>> get _companyCountersRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('counters');

  CollectionReference<Map<String, dynamic>> _companyContactsRef(String customerId) {
    return _companyCustomersRef.doc(customerId).collection('contacts');
  }

  @override
  void initState() {
    super.initState();
    _inquiryDate = DateTime.now().toUtc(); // Timezone-safe initialization
    _initializeForm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _triggerAsyncCustomerSearch('');
    });
  }

  Future<void> _initializeForm() async {
    try {
      if (!_isEditing) {
        await _checkOfflineDraft();
      }

      if (!_isEditing && !_isAdminOrManager && _assignedToUid == null) {
        _assignedToUid = widget.currentUserUid;
      }
      _hydrateFromInquiry();
      await _loadExtraData();

      // Auto-save listener
      if (!_isEditing) {
        _subjectController.addListener(_triggerAutosave);
      }
    } catch (e, st) {
      _handleError('Failed to initialize module', e, st);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _autosaveTimer?.cancel();
    _subjectController.removeListener(_triggerAutosave);
    _scrollController.dispose();
    _inquirySequenceController.dispose();
    _subjectController.dispose();
    _lastFollowUpNoteController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // OFFLINE DRAFT RECOVERY SYSTEM (SharedPreferences)
  // ---------------------------------------------------------
  String get _draftKey => 'draft_inquiry_${widget.companyId}_${widget.currentUserUid}';

  void _triggerAutosave() {
    if (_autosaveTimer?.isActive ?? false) _autosaveTimer!.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), () async {
      if (!_isEditing && mounted && !_isSaving) {
        await _saveDraftToLocal();
      }
    });
  }

  Future<void> _saveDraftToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftPayload = <String, dynamic>{
        'subject': _subjectController.text.trim(),
        'customerId': _selectedCustomerId,
        'customerNameSnapshot': _customerNameSnapshot,
        'products': _structuredProducts,
        'lastFollowUpNote': _lastFollowUpNoteController.text.trim(),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString(_draftKey, jsonEncode(draftPayload));
    } catch (e) {
      developer.log('Draft autosave failed', error: e, name: 'InquiryModule');
    }
  }

  Future<void> _checkOfflineDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString(_draftKey);
      if (draftJson != null && draftJson.isNotEmpty) {
        final draftData = jsonDecode(draftJson) as Map<String, dynamic>;
        final savedAtStr = draftData['savedAt']?.toString();
        if (savedAtStr != null) {
          final savedAt = DateTime.parse(savedAtStr);
          if (DateTime.now().toUtc().difference(savedAt).inDays < 7) {
            // Valid draft found, show recovery prompt
            if (mounted) {
              _showDraftRecoveryDialog(draftData);
            }
          } else {
            await prefs.remove(_draftKey); // Cleanup stale draft
          }
        }
      }
    } catch (e) {
      developer.log('Draft recovery failed', error: e, name: 'InquiryModule');
    }
  }

  void _showDraftRecoveryDialog(Map<String, dynamic> draftData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Draft Found'),
        content: const Text('You have an unsaved inquiry draft. Would you like to restore it?'),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_draftKey);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _subjectController.text = draftData['subject']?.toString() ?? '';
                _lastFollowUpNoteController.text = draftData['lastFollowUpNote']?.toString() ?? '';
                _selectedCustomerId = draftData['customerId']?.toString();
                _customerNameSnapshot = draftData['customerNameSnapshot']?.toString() ?? '';
                if (_customerNameSnapshot.isNotEmpty) {
                  _customerSearchController.text = _customerNameSnapshot;
                }
                if (draftData['products'] != null) {
                  _structuredProducts = List<Map<String, dynamic>>.from(draftData['products']);
                }
              });
              if (_selectedCustomerId != null) {
                _loadCustomerData(_selectedCustomerId);
              }
              Navigator.pop(context);
            },
            child: const Text('Restore Draft'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      developer.log('Draft clear failed', error: e, name: 'InquiryModule');
    }
  }

  // ---------------------------------------------------------
  // STRUCTURED ERROR HANDLING & LOGGING
  // ---------------------------------------------------------
  void _handleError(String contextMessage, Object error, [StackTrace? st]) {
    final traceId = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    developer.log(
      '[$traceId] ERROR: $contextMessage',
      error: error,
      stackTrace: st,
      name: 'InquiryModule',
      level: 1000,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('$contextMessage (Trace: $traceId)')),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _setFormMessage(String? message) {
    if (!mounted) return;
    setState(() => _formMessage = message);
  }

  void _showValidationMessage(String message) {
    _setFormMessage(message);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  // ---------------------------------------------------------
  // CACHE MANAGEMENT (LRU)
  // ---------------------------------------------------------
  void _updateSearchCache(String query, List<QueryDocumentSnapshot<Map<String, dynamic>>> results) {
    if (_customerSearchCache.containsKey(query)) {
      _customerSearchCache.remove(query);
    }
    _customerSearchCache[query] = results;
    if (_customerSearchCache.length > _maxCacheSize) {
      _customerSearchCache.remove(_customerSearchCache.keys.first);
    }
  }

  // ---------------------------------------------------------
  // DATA NORMALIZATION & FINGERPRINTING & TOKENIZATION
  // ---------------------------------------------------------
  String _normalizeText(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }

  List<String> _generateSearchTokens(String input) {
    final normalized = _normalizeText(input);
    if (normalized.isEmpty) return <String>[];
    final words = normalized.split(' ').where((e) => e.isNotEmpty).toSet().toList();
    final tokens = <String>{};
    for (var word in words) {
      for (int i = 1; i <= word.length; i++) {
        tokens.add(word.substring(0, i));
      }
    }
    return tokens.toList();
  }

  String _buildProductFingerprint() {
    final tokens = _structuredProducts.map((item) {
      final productId = (item['productId'] ?? '').toString().trim();
      final name = _normalizeText((item['name'] ?? '').toString());
      final sku = _normalizeText((item['sku'] ?? '').toString());
      return [productId, sku, name].where((e) => e.isNotEmpty).join(':');
    }).where((e) => e.isNotEmpty).toList()..sort();
    return tokens.join('|');
  }

  String _buildRequirementFingerprint(String subjectSearch) {
    return [subjectSearch, _buildProductFingerprint()].where((e) => e.isNotEmpty).join('|');
  }

  String _generateChecksum(Map<String, dynamic> payload) {
    try {
      final normalizedStr = jsonEncode(payload);
      final bytes = utf8.encode(normalizedStr);
      return sha256.convert(bytes).toString(); // Stable SHA256 Checksum
    } catch (_) {
      return DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    }
  }

  void _hydrateFromInquiry() {
    final iq = widget.existingInquiry;
    if (iq == null) return;

    _subjectController.text = iq.subject;
    _lastFollowUpNoteController.text = iq.lastFollowUpNote;
    _selectedPriority = iq.priority.isNotEmpty ? iq.priority : 'Warm';
    _selectedSource = iq.source.isNotEmpty ? iq.source : null;
    _selectedType = iq.inquiryType.isNotEmpty ? iq.inquiryType : null;
    _assignedToUid = iq.assignedToUid.isNotEmpty ? iq.assignedToUid : null;

    if (iq.nextFollowUpDate != null) {
      _nextFollowUpDate = iq.nextFollowUpDate;
    }
    _isFollowUpManuallyEdited = true;
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  Future<void> _loadExtraData() async {
    if (widget.existingDoc == null) return;
    try {
      final existingSnap = await widget.existingDoc!.get();
      if (!existingSnap.exists) {
        throw Exception("Inquiry record not found.");
      }

      final data = existingSnap.data() ?? <String, dynamic>{};
      _existingRawData = data;

      // Soft Delete + Lock Protection Hardening
      final isDeleted = data['isDeleted'] == true;
      final isLocked = data['isLocked'] == true;
      final isArchived = data['isArchived'] == true;
      final isActive = data['isActive'] ?? true;

      if (isDeleted || isLocked || isArchived || !isActive) {
        _isLockedForm = true;
        _lockReason = "This inquiry is ${isDeleted ? 'deleted' : isArchived ? 'archived' : isLocked ? 'locked' : 'inactive'} and cannot be edited.";
        _setFormMessage(_lockReason);
      }

      if (!mounted) return;
      setState(() {
        _selectedCustomerId = _firstNonEmptyString([data['customerId'], _selectedCustomerId]);
        _selectedContactId = _firstNonEmptyString([data['contactId'], _selectedContactId]);
        if (data['additionalContactIds'] != null) {
          _additionalContactIds = List<String>.from(data['additionalContactIds']);
        }

        _selectedAddressId = _firstNonEmptyString([data['addressId']]);

        _customerNameSnapshot = (data['customerName'] ?? '').toString();
        _customerCodeSnapshot = (data['customerCode'] ?? '').toString();
        _customerIndustrySnapshot = (data['customerIndustry'] ?? '').toString();
        _customerStageSnapshot = (data['customerStage'] ?? '').toString();
        _customerPhoneSnapshot = (data['customerPhone'] ?? '').toString();
        _customerEmailSnapshot = (data['customerEmail'] ?? '').toString();
        _customerGSTSnapshot = (data['customerGST'] ?? '').toString();
        _customerAssignedToUidSnapshot = (data['customerAssignedToUid'] ?? '').toString();
        _customerAssignedToNameSnapshot = (data['customerAssignedToName'] ?? '').toString();

        _customerPrimaryAddressSnapshot = (data['customerPrimaryAddress'] ?? '').toString();
        _customerPrimaryCitySnapshot = (data['customerPrimaryCity'] ?? data['customerCity'] ?? '').toString();
        _customerPrimaryStateSnapshot = (data['customerPrimaryState'] ?? '').toString();
        _customerPrimaryCountrySnapshot = (data['customerPrimaryCountry'] ?? '').toString();
        _customerPrimaryPincodeSnapshot = (data['customerPrimaryPincode'] ?? '').toString();

        String rawNo = _firstNonEmptyString([data['inquiryNumber']]) ?? '';
        if (rawNo.isNotEmpty) {
          List<String> parts = rawNo.split('/');
          if (parts.length == 3 && parts[0] == 'INQ') {
            _inquirySequenceController.text = parts[1];
          } else {
            _inquirySequenceController.text = rawNo;
          }
        }

        _subjectController.text = _firstNonEmptyString([data['subject'], _subjectController.text]) ?? '';
        _lastFollowUpNoteController.text = _firstNonEmptyString([data['lastFollowUpNote'], _lastFollowUpNoteController.text]) ?? '';

        _selectedSource = _firstNonEmptyString([data['source'], _selectedSource]);
        _selectedType = _firstNonEmptyString([data['inquiryType'], _selectedType]);
        _selectedPriority = _firstNonEmptyString([data['priority'], _selectedPriority]) ?? 'Warm';
        _followUpType = _firstNonEmptyString([data['followUpType'], 'Call']) ?? 'Call';
        _assignedToUid = _firstNonEmptyString([data['assignedToUid'], _assignedToUid]);
        _recordOwnerUid = _firstNonEmptyString([data['recordOwnerUid'], _recordOwnerUid]);

        if (data['products'] != null && (data['products'] as List).isNotEmpty) {
          _structuredProducts = List<Map<String, dynamic>>.from(data['products']);
        } else if (data['requiredProducts'] != null && data['requiredProducts'].toString().isNotEmpty) {
          _structuredProducts = <Map<String, dynamic>>[
            <String, dynamic>{
              'productId': 'legacy',
              'name': data['requiredProducts'],
              'quantity': data['quantityScope'] ?? '1',
              'price': 0.0,
              'unit': 'Nos',
              'sku': '',
              'productNature': 'General',
            },
          ];
        }

        if (data['inquiryDate'] != null && data['inquiryDate'] is Timestamp) {
          _inquiryDate = (data['inquiryDate'] as Timestamp).toDate().toUtc();
        } else if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
          _inquiryDate = (data['createdAt'] as Timestamp).toDate().toUtc();
        }

        if (data['nextFollowUpDate'] != null && data['nextFollowUpDate'] is Timestamp) {
          _nextFollowUpDate = (data['nextFollowUpDate'] as Timestamp).toDate().toUtc();
        }

        _isFollowUpManuallyEdited = true;
      });

      if (_selectedCustomerId != null) {
        await _loadCustomerData(_selectedCustomerId!);
        _customerSearchController.text = _customerNameSnapshot;
        if (_selectedContactId != null) {
          await _loadContactData(_selectedCustomerId!, _selectedContactId!);
        }
      }
      if (_assignedToUid != null) {
        await _loadAssignedUserData(_assignedToUid!);
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      _handleError('Failed to load existing data', e, st);
    }
  }

  // ---------------------------------------------------------
  // ENTERPRISE INDEXED SEARCH + SYNCHRONOUS AUTOCOMPLETE
  // ---------------------------------------------------------
  void _triggerAsyncCustomerSearch(String query) {
    final q = _normalizeText(query);
    if (_customerSearchCache.containsKey(q)) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    final currentEpoch = ++_customerSearchEpoch;

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        // IMPORTANT:
        // Do not use Firestore arrayContains / prefix composite queries here.
        // Those queries can fail when indexes are missing and they also hide old
        // customer records where fields like isDeleted/searchKeywords are absent.
        // We load a safe batch and filter locally so the inquiry form can show all
        // customers saved from the customer module.
        final snap = await _companyCustomersRef.limit(1000).get();

        if (currentEpoch != _customerSearchEpoch) return;

        var filteredDocs = _filterCustomersBySecurityAndRole(snap.docs).toList();

        if (q.isNotEmpty) {
          final queryWords = q.split(' ').where((e) => e.isNotEmpty).toList();
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data();
            final searchable = _normalizeText(<String>[
              data['companyName'],
              data['name'],
              data['customerCode'],
              data['phone'],
              data['phoneNormalized'],
              data['email'],
              data['emailNormalized'],
              data['gst'],
              data['city'],
              data['state'],
              data['industry'],
              data['customerStage'],
              ...(data['tags'] is Iterable ? List<dynamic>.from(data['tags']) : const <dynamic>[]),
              ...(data['searchKeywords'] is Iterable ? List<dynamic>.from(data['searchKeywords']) : const <dynamic>[]),
            ].whereType<Object>().map((e) => e.toString()).join(' '));

            // Full-name friendly search:
            // Example: typing "Afcons Infrastructure Ltd" should match even if
            // Firestore has punctuation, double spaces, comma, Pvt. Ltd., etc.
            if (searchable.contains(q)) return true;
            return queryWords.every(searchable.contains);
          }).toList();
        }

        filteredDocs.sort((a, b) {
          final ad = a.data();
          final bd = b.data();
          final an = (ad['companyName'] ?? ad['name'] ?? '').toString().toLowerCase();
          final bn = (bd['companyName'] ?? bd['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

        if (q.isEmpty || _allCustomerDocs.isEmpty) {
          _allCustomerDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(filteredDocs);
        }

        _updateSearchCache(q, filteredDocs);

        if (mounted) {
          setState(() {
            _customerSuggestions = filteredDocs;
          });
        }
      } catch (e, st) {
        // Customer search should not disturb the form with a red snackbar.
        // Log only and keep the dropdown empty for this search attempt.
        developer.log(
          'Customer search failed silently',
          error: e,
          stackTrace: st,
          name: 'InquiryModule',
          level: 900,
        );
        if (currentEpoch == _customerSearchEpoch && mounted) {
          setState(() {
            _customerSuggestions = <DocumentSnapshot<Map<String, dynamic>>>[];
          });
        }
      }
    });
  }

  Iterable<DocumentSnapshot<Map<String, dynamic>>> _getSyncCustomerOptions(String query) {
    final q = _normalizeText(query);
    _triggerAsyncCustomerSearch(q);

    final List<DocumentSnapshot<Map<String, dynamic>>> baseDocs = <DocumentSnapshot<Map<String, dynamic>>>[
      ...?_customerSearchCache[q],
      if (!_customerSearchCache.containsKey(q)) ..._allCustomerDocs,
      if (!_customerSearchCache.containsKey(q) && _allCustomerDocs.isEmpty) ..._customerSuggestions,
      if (!_customerSearchCache.containsKey(q) && _allCustomerDocs.isEmpty && _customerSuggestions.isEmpty) ...?_customerSearchCache[''],
    ];

    final Map<String, DocumentSnapshot<Map<String, dynamic>>> uniqueDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in baseDocs) {
      uniqueDocs[doc.id] = doc;
    }

    var docs = uniqueDocs.values.toList();

    if (q.isNotEmpty) {
      final queryWords = q.split(' ').where((e) => e.isNotEmpty).toList();
      docs = docs.where((doc) {
        final data = doc.data() ?? <String, dynamic>{};
        final searchable = _normalizeText(<String>[
          (data['companyName'] ?? '').toString(),
          (data['name'] ?? '').toString(),
          (data['customerCode'] ?? '').toString(),
          (data['phone'] ?? '').toString(),
          (data['phoneNormalized'] ?? '').toString(),
          (data['email'] ?? '').toString(),
          (data['emailNormalized'] ?? '').toString(),
          (data['gst'] ?? '').toString(),
          (data['city'] ?? '').toString(),
          (data['state'] ?? '').toString(),
          (data['industry'] ?? '').toString(),
          (data['customerStage'] ?? '').toString(),
          ...(data['tags'] is Iterable ? List<dynamic>.from(data['tags']).map((e) => e.toString()) : const <String>[]),
          ...(data['searchKeywords'] is Iterable ? List<dynamic>.from(data['searchKeywords']).map((e) => e.toString()) : const <String>[]),
        ].join(' '));

        if (searchable.contains(q)) return true;
        return queryWords.every(searchable.contains);
      }).toList();
    }

    docs.sort((a, b) {
      final ad = a.data() ?? <String, dynamic>{};
      final bd = b.data() ?? <String, dynamic>{};
      final an = (ad['companyName'] ?? ad['name'] ?? '').toString().toLowerCase();
      final bn = (bd['companyName'] ?? bd['name'] ?? '').toString().toLowerCase();
      return an.compareTo(bn);
    });

    return docs.take(80);
  }

  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> _filterCustomersBySecurityAndRole(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final normalizedRole = widget.currentUserRole.trim().toLowerCase();
    return docs.where((d) {
      final data = d.data();
      if (data['isLocked'] == true) return false;
      if (data['isActive'] == false) return false;
      if (data['isDeleted'] == true) return false;

      if (_isAdminOrManager) return true;

      final visibleToRoles = List<dynamic>.from(data['visibleToRoles'] ?? <dynamic>[])
          .map((e) => e.toString().trim().toLowerCase())
          .toList();

      if (visibleToRoles.isNotEmpty && !visibleToRoles.contains(normalizedRole)) {
        return false;
      }

      return data['assignedToUid'] == widget.currentUserUid ||
          data['recordOwnerUid'] == widget.currentUserUid ||
          data['createdByUid'] == widget.currentUserUid ||
          data['createdBy'] == widget.currentUserUid;
    });
  }

  Future<void> _loadCustomerData(String? customerId) async {
    if (customerId == null || customerId.trim().isEmpty) return;
    try {
      final doc = await _companyCustomersRef.doc(customerId).get();
      if (doc.exists) {
        _selectedCustomerData = doc.data();
        if (mounted) {
          setState(() {
            _customerNameSnapshot = (_selectedCustomerData?['companyName'] ?? _selectedCustomerData?['name'] ?? '').toString();
            _customerCodeSnapshot = (_selectedCustomerData?['customerCode'] ?? '').toString();
            _customerIndustrySnapshot = (_selectedCustomerData?['industry'] ?? '').toString();
            _customerStageSnapshot = (_selectedCustomerData?['customerStage'] ?? '').toString();
            _customerPhoneSnapshot = (_selectedCustomerData?['phoneNormalized'] ?? _selectedCustomerData?['phone'] ?? '').toString();
            _customerEmailSnapshot = (_selectedCustomerData?['emailNormalized'] ?? _selectedCustomerData?['email'] ?? '').toString();
            _customerGSTSnapshot = (_selectedCustomerData?['gst'] ?? '').toString();
            _customerAssignedToUidSnapshot = (_selectedCustomerData?['assignedToUid'] ?? '').toString();
            _customerAssignedToNameSnapshot = (_selectedCustomerData?['assignedToName'] ?? '').toString();

            // Extract addresses safely
            _customerAddresses = <Map<String, dynamic>>[];
            if (_selectedCustomerData?['addresses'] != null) {
              _customerAddresses = List<Map<String, dynamic>>.from(_selectedCustomerData!['addresses']);
            }

            // Null-safe address verification
            if (_selectedAddressId != null) {
              final exists = _customerAddresses.any((a) => a['id'] == _selectedAddressId);
              if (!exists) {
                _selectedAddressId = null;
                _selectedAddressData = null;
              }
            }

            // Auto-select primary or billing address if none selected
            if (_customerAddresses.isNotEmpty && _selectedAddressId == null) {
              final primaryBillingMatches = _customerAddresses.where((a) => a['isBillingAddress'] == true && a['isPrimary'] == true);
              final primaryMatches = _customerAddresses.where((a) => a['isPrimary'] == true);

              _selectedAddressData = primaryBillingMatches.isNotEmpty
                  ? primaryBillingMatches.first
                  : (primaryMatches.isNotEmpty ? primaryMatches.first : _customerAddresses.first);

              _selectedAddressId = _selectedAddressData?['id'];
              _updateAddressSnapshots(_selectedAddressData);
            }
          });
        }
      }
    } catch (e, st) {
      _handleError('Failed to load customer data', e, st);
    }
  }

  void _updateAddressSnapshots(Map<String, dynamic>? address) {
    if (address == null) return;
    _customerPrimaryAddressSnapshot = (address['combinedAddress'] ?? address['address'] ?? '').toString();
    _customerPrimaryCitySnapshot = (address['city'] ?? '').toString();
    _customerPrimaryStateSnapshot = (address['state'] ?? '').toString();
    _customerPrimaryCountrySnapshot = (address['country'] ?? '').toString();
    _customerPrimaryPincodeSnapshot = (address['pincode'] ?? '').toString();
  }

  Future<void> _loadContactData(String customerId, String contactId) async {
    try {
      final doc = await _companyContactsRef(customerId).doc(contactId).get();
      if (mounted) {
        setState(() {
          _selectedContactData = doc.exists ? doc.data() : null;
        });
      } else {
        _selectedContactData = doc.exists ? doc.data() : null;
      }
    } catch (e, st) {
      _handleError('Failed to load contact data', e, st);
    }
  }

  Future<void> _loadAssignedUserData(String userId) async {
    try {
      final doc = await _companyUsersRef.doc(userId).get();
      _assignedUserData = doc.data();
    } catch (e) {
      developer.log('User load error (non-fatal)', error: e, name: 'InquiryModule');
    }
  }

  // ---------------------------------------------------------
  // FINANCIAL YEAR CALCULATION
  // ---------------------------------------------------------
  String _getFinancialYear(DateTime date) {
    final localDate = date.toLocal(); // FY based on local company timezone typically
    int year = localDate.year % 100;
    if (localDate.month >= 4) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  bool _validateForm() {
    if (_isLockedForm) {
      _showValidationMessage(_lockReason ?? 'Form is locked.');
      return false;
    }

    _setFormMessage(null);

    if (!_formKey.currentState!.validate()) {
      _showValidationMessage('Please fill in all required fields marked with *.');
      return false;
    }

    if (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty) {
      _showValidationMessage('Please select a valid customer from the search results.');
      return false;
    }

    if (_inquiryDate == null) {
      _showValidationMessage('Inquiry Date is required.');
      return false;
    }

    if (_structuredProducts.isEmpty) {
      _showValidationMessage('Add at least one product or requirement before saving.');
      return false;
    }

    for (var item in _structuredProducts) {
      double qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
      if (qty <= 0) {
        _showValidationMessage('Product "${item['name']}" must have a quantity greater than zero.');
        return false;
      }
    }

    return true;
  }

  Future<Map<String, dynamic>> _buildPayload() async {
    final assignedTo = _isAdminOrManager ? (_assignedToUid ?? widget.currentUserUid).trim() : widget.currentUserUid;
    await _loadAssignedUserData(assignedTo);

    final contactData = _selectedContactData ?? <String, dynamic>{};
    final assignedUserData = _assignedUserData ?? <String, dynamic>{};

    // Standardize Flat Contact Extraction (Enterprise fallback)
    final contactName = (contactData['name'] ?? contactData['contactName'] ?? '').toString().trim();
    final contactPhone = (contactData['phoneNormalized'] ?? contactData['phone'] ?? contactData['mobile'] ?? '').toString().trim();
    final contactEmail = (contactData['emailNormalized'] ?? contactData['email'] ?? '').toString().trim();
    final contactDesignation = (contactData['designation'] ?? '').toString().trim();
    final contactDepartment = (contactData['department'] ?? '').toString().trim();

    final assignedToName = (assignedUserData['name'] ?? assignedUserData['fullName'] ?? '').toString().trim();
    final assignedToRole = (assignedUserData['role'] ?? '').toString().trim();

    final now = DateTime.now().toUtc();
    bool isOverdue = false;
    if (_nextFollowUpDate != null) {
      final today = DateTime(now.year, now.month, now.day);
      final compareDate = DateTime(_nextFollowUpDate!.year, _nextFollowUpDate!.month, _nextFollowUpDate!.day);
      isOverdue = compareDate.isBefore(today);
    }

    final subjectStr = _subjectController.text.trim();
    final subjectSearch = subjectStr.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final requirementFingerprint = _buildRequirementFingerprint(subjectSearch);
    final uniqueKey = '${_selectedCustomerId}_${requirementFingerprint.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    final searchCache = '${_customerNameSnapshot.toLowerCase()} ${_customerIndustrySnapshot.toLowerCase()} ${_customerPrimaryCitySnapshot.toLowerCase()} $subjectSearch'.trim();
    final searchableTokens = _generateSearchTokens(searchCache);

    double totalQuantity = _structuredProducts.fold<double>(
      0.0,
          (runningTotal, item) => runningTotal + (double.tryParse(item['quantity'].toString()) ?? 0.0),
    );

    final payload = <String, dynamic>{
      'schemaVersion': '2.0.0',
      'payloadVersion': 2,

      'inquiryDate': _inquiryDate != null ? Timestamp.fromDate(_inquiryDate!) : FieldValue.serverTimestamp(),
      'subject': subjectStr,
      'subjectSearch': subjectSearch,
      'searchableTokens': searchableTokens,
      'customerSearchCache': searchCache,
      'uniqueKey': uniqueKey,
      'requirementFingerprint': requirementFingerprint,
      'productFingerprint': _buildProductFingerprint(),

      // Enterprise Snapshots
      'customerId': _selectedCustomerId,
      'customerName': _customerNameSnapshot,
      'customerCode': _customerCodeSnapshot,
      'customerIndustry': _customerIndustrySnapshot,
      'customerStage': _customerStageSnapshot,
      'customerPhone': _customerPhoneSnapshot,
      'customerEmail': _customerEmailSnapshot,
      'customerGST': _customerGSTSnapshot,
      'customerAssignedToUid': _customerAssignedToUidSnapshot,
      'customerAssignedToName': _customerAssignedToNameSnapshot,

      // Address Snapshots
      'addressId': _selectedAddressId ?? '',
      'customerPrimaryAddress': _customerPrimaryAddressSnapshot,
      'customerPrimaryCity': _customerPrimaryCitySnapshot,
      'customerPrimaryState': _customerPrimaryStateSnapshot,
      'customerPrimaryCountry': _customerPrimaryCountrySnapshot,
      'customerPrimaryPincode': _customerPrimaryPincodeSnapshot,

      // Contact Consistency Flat fields
      'contactId': _selectedContactId ?? '',
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'contactDesignation': contactDesignation,
      'contactDepartment': contactDepartment,
      'additionalContactIds': _additionalContactIds,

      'source': (_selectedSource ?? '').trim(),
      'inquiryType': (_selectedType ?? '').trim(),
      'products': _structuredProducts,
      'quantityScope': totalQuantity.toString(),
      'totalQuantity': totalQuantity,
      'expectedValue': 0.0,
      'priority': _selectedPriority.trim(),
      'status': _isEditing ? (_existingRawData?['status'] ?? 'Open').toString() : 'Open',
      'followUpType': _followUpType,
      'nextFollowUpDate': _nextFollowUpDate == null ? null : Timestamp.fromDate(_nextFollowUpDate!),
      'isOverdue': isOverdue,
      'lastFollowUpNote': _lastFollowUpNoteController.text.trim(),

      // Enterprise Security Role Models
      'assignedToUid': assignedTo,
      'assignedToName': assignedToName,
      'assignedToRole': assignedToRole,
      'recordOwnerUid': _recordOwnerUid ?? assignedTo,
      'updatedBy': widget.currentUserUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActivityDate': FieldValue.serverTimestamp(),
      'lastActivityBy': widget.currentUserUid,
    };

    payload['auditChecksum'] = _generateChecksum(payload);
    return payload;
  }

  // ---------------------------------------------------------
  // ENTERPRISE AUDIT DIFF ENGINE
  // ---------------------------------------------------------
  Map<String, dynamic> _generateAuditDiff(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    Map<String, dynamic> prev = <String, dynamic>{};
    Map<String, dynamic> curr = <String, dynamic>{};
    List<String> changedFields = <String>[];

    const keysToTrack = ['subject', 'priority', 'status', 'followUpType', 'nextFollowUpDate', 'assignedToUid', 'totalQuantity', 'addressId'];

    for (var key in keysToTrack) {
      var oldVal = oldData[key]?.toString() ?? '';
      var newVal = newData[key]?.toString() ?? '';
      if (oldVal != newVal) {
        prev[key] = oldData[key];
        curr[key] = newData[key];
        changedFields.add(key);
      }
    }

    // Product tracking check
    final oldProd = oldData['products'] as List? ?? <dynamic>[];
    final newProd = newData['products'] as List? ?? <dynamic>[];
    if (oldProd.length != newProd.length) {
      changedFields.add('products');
      prev['products_count'] = oldProd.length;
      curr['products_count'] = newProd.length;
    }

    return <String, dynamic>{
      'previousValues': prev,
      'newValues': curr,
      'changedFields': changedFields,
    };
  }

  Future<void> _executeSave(Map<String, dynamic> payload) async {
    int attempts = 0;
    bool success = false;
    _pendingMutationId ??= _companyInquiriesRef.doc().id;
    final requestId = _pendingMutationId!;
    String actorName = 'Unknown user';
    try {
      final actorData = (await _companyUsersRef.doc(widget.currentUserUid).get()).data();
      actorName = (actorData?['name'] ?? actorData?['fullName'] ?? actorName).toString().trim();
      if (actorName.isEmpty) actorName = 'Unknown user';
    } on FirebaseException {
      // Actor profile enrichment must never block the business save.
    }
    _pendingCreateInquiryRef ??= _isEditing ? null : _companyInquiriesRef.doc();

    while (attempts < 2 && !success) {
      attempts++;
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {

          String finalInquiryNumber;
          final dateToUse = _inquiryDate ?? DateTime.now().toUtc();
          final fy = _getFinancialYear(dateToUse);
          String manualSequence = _inquirySequenceController.text.trim();

          if (manualSequence.isEmpty) {
            final counterRef = _companyCountersRef.doc('inquiry_counter_$fy');
            final counterSnap = await transaction.get(counterRef);

            int currentSeq = 1;
            if (counterSnap.exists) {
              currentSeq = (counterSnap.data()?['sequence'] ?? 0) + 1;
            }

            String formattedSequence = currentSeq.toString().padLeft(3, '0');
            finalInquiryNumber = 'INQ/$formattedSequence/$fy';

            transaction.set(counterRef, <String, dynamic>{'sequence': currentSeq}, SetOptions(merge: true));
          } else {
            int? parsedSeq = int.tryParse(manualSequence);
            if (parsedSeq != null) {
              manualSequence = parsedSeq.toString().padLeft(3, '0');
            } else if (manualSequence.length < 3) {
              manualSequence = manualSequence.padLeft(3, '0');
            }
            finalInquiryNumber = 'INQ/$manualSequence/$fy';
          }

          payload['inquiryNumber'] = finalInquiryNumber;
          _savedInquiryNumber = finalInquiryNumber;

          if (_isEditing) {
            final docRef = widget.existingDoc!;
            _savedInquiryId = docRef.id;
            final snapshot = await transaction.get(docRef);

            if (!snapshot.exists) throw Exception("Inquiry document no longer exists.");
            final data = snapshot.data() ?? <String, dynamic>{};

            if (data['isActive'] == false || data['isDeleted'] == true || data['isLocked'] == true) {
              throw Exception("Cannot edit locked or inactive inquiry.");
            }

            // Optimistic Concurrency Protection
            if (data['updatedAt'] != null && _existingRawData?['updatedAt'] != null) {
              final remoteTime = (data['updatedAt'] as Timestamp).millisecondsSinceEpoch;
              final localTime = (_existingRawData!['updatedAt'] as Timestamp).millisecondsSinceEpoch;
              if (remoteTime > localTime) {
                throw Exception("Document was modified by another user. Please refresh and try again.");
              }
            }

            final rawLog = data['activityLog'] as List<dynamic>? ?? <dynamic>[];
            final List<Map<String, dynamic>> existingLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();

            final auditDiff = _generateAuditDiff(data, payload);
            List<String> changedFields = List<String>.from(auditDiff['changedFields'] as List<dynamic>);

            String actionDesc = 'Inquiry updated.';
            if (changedFields.isNotEmpty) {
              actionDesc = 'Updated fields: ${changedFields.join(', ')}';
            }
            if (_lastFollowUpNoteController.text.isNotEmpty && _lastFollowUpNoteController.text != data['lastFollowUpNote']) {
              actionDesc = 'Added follow-up note. $actionDesc';
            }

            // Enterprise Activity Log with Web-Safe Timestamp
            existingLog.add(<String, dynamic>{
              'actionType': 'Update',
              'module': 'Inquiry',
              'description': actionDesc,
              'changedFields': changedFields,
              'previousValues': auditDiff['previousValues'],
              'newValues': auditDiff['newValues'],
              'uid': widget.currentUserUid,
              'role': widget.currentUserRole,
              'timestamp': Timestamp.now(),
              'auditVersion': 2,
              'deviceType': kIsWeb ? 'Web' : Platform.operatingSystem,
              'platform': kIsWeb ? 'Web' : 'App',
              'mutationSource': 'ScreensAddInquiry',
              'requestId': requestId,
            });

            payload['activityLog'] = existingLog;
            payload['lastActivityType'] = 'Updated';

            transaction.update(docRef, payload);
            final previousAssignedUid = (data['assignedToUid'] ?? '').toString().trim();
            final newAssignedUid = (payload['assignedToUid'] ?? '').toString().trim();
            if (previousAssignedUid != newAssignedUid) {
              transaction.set(
                docRef.collection('activities').doc('inquiry_assigned_${docRef.id}_$requestId'),
                InquiryActivityService.buildActivityData(
                  companyId: widget.companyId,
                  inquiryId: docRef.id,
                  inquiryNumber: finalInquiryNumber,
                  type: InquiryActivityType.inquiryAssigned,
                  title: 'Inquiry Assigned',
                  createdByUid: widget.currentUserUid,
                  createdByName: actorName,
                  metadata: <String, dynamic>{
                    'mutationId': requestId,
                    'previousAssignedUid': previousAssignedUid,
                    'previousAssignedName': (data['assignedToName'] ?? '').toString(),
                    'newAssignedUid': newAssignedUid,
                    'newAssignedName': (payload['assignedToName'] ?? '').toString(),
                  },
                ),
              );
            }
          } else {
            final docRef = _pendingCreateInquiryRef!;
            _savedInquiryId = docRef.id;

            payload['lastActivityType'] = 'Created';
            payload['activityLog'] = <Map<String, dynamic>>[
              <String, dynamic>{
                'actionType': 'Create',
                'module': 'Inquiry',
                'description': 'Inquiry created.',
                'changedFields': <String>[],
                'previousValues': <String, dynamic>{},
                'newValues': <String, dynamic>{},
                'uid': widget.currentUserUid,
                'role': widget.currentUserRole,
                'timestamp': Timestamp.now(), // CRITICAL FIX for Web
                'auditVersion': 2,
                'deviceType': kIsWeb ? 'Web' : Platform.operatingSystem,
                'platform': kIsWeb ? 'Web' : 'App',
                'mutationSource': 'ScreensAddInquiry',
                'requestId': requestId,
              },
            ];

            payload.addAll(<String, dynamic>{
              'companyId': widget.companyId,
              'createdByUid': widget.currentUserUid,
              'createdBy': widget.currentUserUid,
              'createdAt': FieldValue.serverTimestamp(),
              'isActive': true,
              'isDeleted': false,
            });

            transaction.set(docRef, payload);
            transaction.set(
              docRef.collection('activities').doc('inquiry_created_${docRef.id}'),
              InquiryActivityService.buildActivityData(
                companyId: widget.companyId,
                inquiryId: docRef.id,
                inquiryNumber: finalInquiryNumber,
                type: InquiryActivityType.inquiryCreated,
                title: 'Inquiry Created',
                createdByUid: widget.currentUserUid,
                createdByName: actorName,
                status: (payload['status'] ?? '').toString(),
                metadata: <String, dynamic>{
                  'customerId': payload['customerId'],
                  'customerName': payload['customerName'],
                  'creatorUid': widget.currentUserUid,
                  'creatorName': actorName,
                },
              ),
            );
          }
        });
        success = true;
      } catch (e, st) {
        if (e.toString().contains('Duplicate') || e.toString().contains('inactive') || e.toString().contains('modified')) {
          rethrow;
        }
        if (attempts >= 2) {
          _handleError('Transaction Save Failed', e, st);
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _ensureNotDuplicate(Map<String, dynamic> payload) async {
    final fingerprint = (payload['requirementFingerprint'] ?? '').toString().trim();
    final customerId = (payload['customerId'] ?? '').toString().trim();
    if (fingerprint.isEmpty || customerId.isEmpty) return;

    final duplicateSnap = await _companyInquiriesRef
        .where('customerId', isEqualTo: customerId)
        .where('requirementFingerprint', isEqualTo: fingerprint)
        .limit(5)
        .get();

    final duplicateExists = duplicateSnap.docs.any((doc) {
      if (_isEditing && doc.id == widget.existingDoc?.id) return false;
      final data = doc.data();
      return data['isActive'] != false && data['isDeleted'] != true && (data['status'] ?? '') == 'Open';
    });

    if (duplicateExists) {
      throw Exception('A similar open inquiry already exists for this customer. Reuse the existing inquiry instead of creating a duplicate.');
    }
  }

  Future<void> _saveInquiry({bool createQuote = false}) async {
    if (_isSaving || _isLockedForm) return;
    FocusScope.of(context).unfocus();

    if (!_validateForm()) return;

    setState(() => _isSaving = true);

    try {
      final payload = await _buildPayload();
      await _ensureNotDuplicate(payload);
      await _executeSave(payload);

      await _clearDraft(); // Clean draft on success

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Inquiry successfully updated.' : 'Inquiry successfully created.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _setFormMessage(null);

      if (createQuote) {
        payload['id'] = _savedInquiryId;
        payload['inquiryId'] = _savedInquiryId;
        payload['inquiryNumber'] = _savedInquiryNumber;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationScreenLocal(
              currentUserUid: widget.currentUserUid,
              companyId: widget.companyId,
              inquirySeed: payload,
            ),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      _showValidationMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _viewRelatedActivity(InquiryActivity activity) async {
    final id = activity.relatedDocumentId?.trim() ?? '';
    if (id.isEmpty || !_isAdminOrManager) {
      if (mounted && !_isAdminOrManager) _showValidationMessage('You do not have permission to view this document.');
      return;
    }
    if (activity.relatedDocumentType == 'quotation') {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('quotations').doc(id).get();
      if (!doc.exists || !mounted) {
        if (mounted) _showValidationMessage('Quotation is unavailable.');
        return;
      }
      await Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationScreenLocal(
        companyId: widget.companyId,
        currentUserUid: widget.currentUserUid,
        quotationId: id,
        existingQuotation: doc.data(),
      )));
    } else if (activity.relatedDocumentType == 'proforma' && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ProformaScreen(
        companyId: widget.companyId,
        proformaId: id,
      )));
    }
  }

  // ==========================================
  // UI BUILDER METHODS
  // ==========================================

  InputDecoration _dec(String label, {String? hint, Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildResponsiveFields(List<Widget> children, {double breakpoint = 720, double spacing = 16}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: children.map((child) => Padding(padding: EdgeInsets.only(bottom: spacing), child: child)).toList(),
          );
        }

        final rowChildren = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          rowChildren.add(Expanded(child: children[i]));
          if (i != children.length - 1) {
            rowChildren.add(SizedBox(width: spacing));
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        );
      },
    );
  }

  Widget _buildFormMessageBanner() {
    if (_formMessage == null || _formMessage!.trim().isEmpty) return const SizedBox.shrink();

    final isError = _isLockedForm;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? const Color(0xFFFCA5A5) : const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
                isError ? Icons.lock_outline : Icons.info_outline,
                color: isError ? const Color(0xFFB91C1C) : const Color(0xFF9A3412)
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _formMessage!,
              style: TextStyle(
                  color: isError ? const Color(0xFFB91C1C) : const Color(0xFF9A3412),
                  fontWeight: FontWeight.w600
              ),
            ),
          ),
          if (!isError)
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: () => _setFormMessage(null),
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF9A3412)),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    final isExpanded = _sectionExpanded[title] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _sectionExpanded[title] = !isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(isExpanded ? 0 : 16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: const Color(0xFF334155), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(padding: const EdgeInsets.all(24), child: child),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final customerField = Autocomplete<DocumentSnapshot<Map<String, dynamic>>>(
              initialValue: TextEditingValue(text: _customerNameSnapshot),
              displayStringForOption: (doc) {
                final data = doc.data() ?? <String, dynamic>{};
                return (data['companyName'] ?? data['name'] ?? 'Unknown').toString();
              },
              optionsBuilder: (TextEditingValue textEditingValue) {
                return _getSyncCustomerOptions(textEditingValue.text);
              },
              onSelected: (doc) async {
                setState(() {
                  _selectedCustomerId = doc.id;
                  _selectedContactId = null;
                  _selectedContactData = null;
                  _additionalContactIds.clear();
                  _selectedAddressId = null;
                  _customerAddresses.clear();
                  _formMessage = null;
                });
                _customerSearchController.text = (doc.data()?['companyName'] ?? doc.data()?['name'] ?? '').toString();
                await _loadCustomerData(doc.id);
                _triggerAutosave();
              },
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                if (_customerSearchController.text.isNotEmpty && controller.text.isEmpty) {
                  controller.text = _customerSearchController.text;
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: _dec('Search Customer Database *', hint: 'Type name, phone, tags...', prefixIcon: const Icon(Icons.business_outlined)),
                  validator: (v) => _selectedCustomerId == null ? 'Required' : null,
                  onChanged: (value) {
                    _customerSearchController.text = value;
                    _triggerAsyncCustomerSearch(value);
                    final normalizedInput = _normalizeText(value);
                    final normalizedSelected = _normalizeText(_customerNameSnapshot);
                    if (_selectedCustomerId != null && normalizedInput != normalizedSelected) {
                      setState(() {
                        _selectedCustomerId = null;
                        _selectedContactId = null;
                        _selectedContactData = null;
                        _additionalContactIds.clear();
                        _selectedAddressId = null;
                        _customerAddresses.clear();
                      });
                    }
                  },
                );
              },
            );

            final newButton = SizedBox(
              height: 56,
              width: isCompact ? double.infinity : null,
              child: OutlinedButton.icon(
                onPressed: _isLockedForm ? null : () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScreensAddCustomer(
                        companyId: widget.companyId,
                        currentUserUid: widget.currentUserUid,
                        currentUserRole: widget.currentUserRole,
                      ),
                    ),
                  );
                  if (result == true) {
                    if (mounted) {
                      setState(() {
                        _selectedCustomerId = null;
                        _customerSearchController.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer added. Please search and select it.')));
                    }
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('New'),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            );

            if (isCompact) {
              return Column(children: [customerField, const SizedBox(height: 12), newButton]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: customerField), const SizedBox(width: 12), newButton]);
          },
        ),
        if (_selectedCustomerId != null && _customerNameSnapshot.isNotEmpty) ...[
          const SizedBox(height: 16),

          // Enterprise Address Selector
          if (_customerAddresses.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _customerAddresses.any((a) => a['id'] == _selectedAddressId) ? _selectedAddressId : null,
              decoration: _dec('Select Inquiry Address', prefixIcon: const Icon(Icons.location_on_outlined)),
              items: _customerAddresses.map<DropdownMenuItem<String>>((addr) {
                final type = (addr['type'] ?? 'Address').toString();
                final isPrimary = addr['isPrimary'] == true ? ' (Primary)' : '';
                final isBilling = addr['isBillingAddress'] == true ? ' (Billing)' : '';
                final shortAddr = (addr['combinedAddress'] ?? addr['address'] ?? '').toString().replaceAll('\n', ', ');
                return DropdownMenuItem<String>(
                  value: addr['id']?.toString(),
                  child: Text('$type$isPrimary$isBilling - $shortAddr', maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              selectedItemBuilder: (BuildContext context) {
                return _customerAddresses.map<Widget>((addr) {
                  final type = (addr['type'] ?? 'Address').toString();
                  final isPrimary = addr['isPrimary'] == true ? ' (Primary)' : '';
                  final isBilling = addr['isBillingAddress'] == true ? ' (Billing)' : '';
                  final shortAddr = (addr['combinedAddress'] ?? addr['address'] ?? '').toString().replaceAll('\n', ', ');
                  return Text('$type$isPrimary$isBilling - $shortAddr', maxLines: 1, overflow: TextOverflow.ellipsis);
                }).toList();
              },
              onChanged: (v) {
                setState(() {
                  _selectedAddressId = v;
                  _selectedContactId = null;
                  _selectedContactData = null;
                  _additionalContactIds.clear();

                  if (v != null) {
                    final matches = _customerAddresses.where((a) => a['id'] == v);
                    _selectedAddressData = matches.isNotEmpty ? matches.first : null;
                    _updateAddressSnapshots(_selectedAddressData);
                  }
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          _buildContactDropdown(),

          // Enterprise Contact Display
          if (_selectedContactData != null) Builder(
            builder: (context) {
              final phone = (_selectedContactData!['phoneNormalized'] ?? _selectedContactData!['phone'] ?? _selectedContactData!['mobile'] ?? '').toString().trim();
              final designation = (_selectedContactData!['designation'] ?? '').toString().trim();
              if (phone.isNotEmpty || designation.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4, bottom: 8),
                  child: Row(
                    children: [
                      if (phone.isNotEmpty) ...[
                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Flexible(child: Text('Contact: $phone', style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      ],
                      if (phone.isNotEmpty && designation.isNotEmpty) const Text(' • ', style: TextStyle(color: Color(0xFF64748B))),
                      if (designation.isNotEmpty) ...[
                        Flexible(child: Text(designation, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
                      ],
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customerNameSnapshot, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('Industry: ${_customerIndustrySnapshot.isEmpty ? 'N/A' : _customerIndustrySnapshot} • City: ${_customerPrimaryCitySnapshot.isEmpty ? 'N/A' : _customerPrimaryCitySnapshot}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContactDropdown() {
    if (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyContactsRef(_selectedCustomerId!)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        var contacts = snap.data!.docs.where((d) => d.data()['isDeleted'] != true).toList();
        if (contacts.isEmpty) return const SizedBox.shrink();

        if (_selectedAddressId != null) {
          bool anyContactHasAddress = contacts.any((d) {
            final data = d.data();
            final addrId = data['addressId'];
            final linked = data['linkedAddressIds'] as List?;
            final assigned = data['assignedAddressId'];
            return addrId != null || (linked != null && linked.isNotEmpty) || assigned != null;
          });

          if (anyContactHasAddress) {
            contacts = contacts.where((d) {
              final data = d.data();
              final addrId = data['addressId'];
              final linked = data['linkedAddressIds'] as List?;
              final assigned = data['assignedAddressId'];
              if (addrId == _selectedAddressId) return true;
              if (assigned == _selectedAddressId) return true;
              if (linked != null && linked.contains(_selectedAddressId)) return true;
              return false;
            }).toList();
          }
        }

        if (contacts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: Text('No contacts found for the selected address.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }

        final validContactId = contacts.any((d) => d.id == _selectedContactId) ? _selectedContactId : null;

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: validContactId,
                decoration: _dec('Primary Contact Person', prefixIcon: const Icon(Icons.person_outline)),
                items: contacts.map<DropdownMenuItem<String>>((doc) => DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text((doc.data()['name'] ?? doc.data()['contactName'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis)
                )).toList(),
                selectedItemBuilder: (BuildContext context) {
                  return contacts.map<Widget>((doc) {
                    return Text((doc.data()['name'] ?? doc.data()['contactName'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis);
                  }).toList();
                },
                onChanged: (v) {
                  setState(() {
                    _selectedContactId = v;
                    _selectedContactData = null;
                  });
                  if (v != null && _selectedCustomerId != null) {
                    _loadContactData(_selectedCustomerId!, v);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: validContactId == null ? null : () => _showMultiContactPicker(contacts),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('+ ${_additionalContactIds.length} More'),
            ),
          ],
        );
      },
    );
  }

  void _showMultiContactPicker(List<DocumentSnapshot<Map<String, dynamic>>> contacts) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Additional Contacts'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: contacts.where((c) => c.id != _selectedContactId).map((doc) {
                    final isSelected = _additionalContactIds.contains(doc.id);
                    return CheckboxListTile(
                      title: Text((doc.data()?['name'] ?? doc.data()?['contactName'] ?? '').toString()),
                      value: isSelected,
                      onChanged: (bool? val) {
                        setDialogState(() {
                          if (val == true) {
                            _additionalContactIds.add(doc.id);
                          } else {
                            _additionalContactIds.remove(doc.id);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSegmentedInquiryNumber() {
    final fy = _getFinancialYear(_inquiryDate ?? DateTime.now().toUtc());
    return TextFormField(
      controller: _inquirySequenceController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 15, color: Color(0xFF0F172A)),
      decoration: _dec('Inquiry No.', hint: 'Auto').copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        counterText: "",
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        prefixIconConstraints: const BoxConstraints(minWidth: 70, minHeight: 54),
        prefixIcon: Container(
          width: 70,
          alignment: Alignment.center,
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
          child: const Text('INQ', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 14)),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 80, minHeight: 54),
        suffixIcon: Container(
          width: 80,
          alignment: Alignment.center,
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Text(fy, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildInquiryBasicsSection() {
    final sourceOptions = const <String>['Whatsapp', 'E-mail', 'Website', 'Referral', 'Cold Call', 'Exhibition', 'IndiaMART', 'Visit', 'Other'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResponsiveFields([
          _buildSegmentedInquiryNumber(),
          _buildDateSelector(
            label: 'Inquiry Date *',
            value: _inquiryDate,
            onTap: () async => await _pickDate(
              initialValue: _inquiryDate,
              onPicked: (d) => setState(() {
                _inquiryDate = d;
                if (!_isFollowUpManuallyEdited) {
                  _nextFollowUpDate = d.add(const Duration(days: 2));
                }
              }),
            ),
            onClear: () => setState(() => _inquiryDate = null),
          ),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller: _subjectController,
          decoration: _dec('Inquiry Subject *', hint: 'E.g. Requirement for 50 Laptops', prefixIcon: const Icon(Icons.title)),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildResponsiveFields([
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: sourceOptions.contains(_selectedSource) ? _selectedSource : null,
            decoration: _dec('Source', prefixIcon: const Icon(Icons.campaign_outlined)),
            items: sourceOptions.map<DropdownMenuItem<String>>((String e) => DropdownMenuItem<String>(value: e, child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
            selectedItemBuilder: (BuildContext context) {
              return sourceOptions.map<Widget>((String e) => Text(e, maxLines: 1, overflow: TextOverflow.ellipsis)).toList();
            },
            onChanged: (v) => setState(() => _selectedSource = v),
          ),
          _buildAssignUserDropdown(),
        ]),
      ],
    );
  }

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_structuredProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid)),
            child: const Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text('No products added yet.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                Text('Click \'Add Product from Inventory\' to continue.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _structuredProducts.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _structuredProducts[index];
              return RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.widgets_outlined, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('Nature: ${item['productNature'] ?? 'General'}  •  Unit: ${item['unit'] ?? 'Nos'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Builder(
                                builder: (context) {
                                  final sku = (item['sku'] ?? '').toString().trim();
                                  final brand = (item['brand'] ?? '').toString().trim();
                                  final model = (item['model'] ?? '').toString().trim();
                                  List<String> extras = <String>[];
                                  if (sku.isNotEmpty) extras.add('SKU: $sku');
                                  if (brand.isNotEmpty) extras.add('Brand: $brand');
                                  if (model.isNotEmpty) extras.add('Model: $model');
                                  if (extras.isEmpty) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      extras.join('  •  '),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Qty: ${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('₹${item['price'] ?? 0}', style: const TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20), onPressed: () => _editProduct(index)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () {
                        setState(() => _structuredProducts.removeAt(index));
                        _triggerAutosave();
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isLockedForm ? null : () {
            showDialog(
              context: context,
              builder: (context) {
                return _ERPProductSearchDialog(
                  companyId: widget.companyId,
                  onProductSelected: (docData, docId) {
                    Navigator.pop(context);
                    _showProductDetailEntry(
                      productId: docId,
                      name: (docData['itemName'] ?? docData['name'] ?? 'Unknown').toString(),
                      sku: (docData['sku'] ?? docData['itemCode'] ?? '').toString(),
                      defaultPrice: double.tryParse(docData['sellingPrice']?.toString() ?? docData['price']?.toString() ?? '0') ?? 0.0,
                      unit: (docData['uom'] ?? docData['unit'] ?? 'Nos').toString(),
                      category: (docData['category'] ?? docData['categoryId'] ?? '').toString(),
                      subCategory: (docData['subCategory'] ?? docData['subcategoryId'] ?? '').toString(),
                      brand: (docData['brand'] ?? '').toString(),
                      model: (docData['model'] ?? '').toString(),
                      costPrice: double.tryParse(docData['costPrice']?.toString() ?? '0') ?? 0.0,
                      productNature: (docData['productNature'] ?? 'General').toString(),
                      machineType: (docData['machineType'] ?? '').toString(),
                    );
                  },
                  onManualAdd: (String query) {
                    Navigator.pop(context);
                    _showProductDetailEntry(
                        productId: 'manual', name: query, sku: '', defaultPrice: 0.0, unit: 'Nos',
                        category: 'General', subCategory: '', brand: '', model: '', costPrice: 0.0,
                        productNature: 'General', machineType: ''
                    );
                  },
                );
              },
            );
          },
          icon: const Icon(Icons.add_shopping_cart, size: 18),
          label: const Text('Add Product from Inventory'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2563EB), side: const BorderSide(color: Color(0xFF2563EB), width: 1.5), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ],
    );
  }

  void _showProductDetailEntry({
    required String productId,
    required String name,
    required String sku,
    required double defaultPrice,
    required String unit,
    required String category,
    required String subCategory,
    required String brand,
    required String model,
    required double costPrice,
    required String productNature,
    required String machineType,
    int? editIndex,
  }) {
    final nameCtrl = TextEditingController(text: name);
    final qtyCtrl = TextEditingController(text: editIndex != null ? _structuredProducts[editIndex]['quantity'].toString() : '1');
    final priceCtrl = TextEditingController(text: editIndex != null ? _structuredProducts[editIndex]['price'].toString() : defaultPrice.toString());
    final unitCtrl = TextEditingController(text: editIndex != null ? _structuredProducts[editIndex]['unit'] : unit);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(editIndex != null ? 'Edit Product' : 'Add to Inquiry', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: _dec('Product / Description *'), enabled: productId == 'manual' || editIndex != null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: qtyCtrl, decoration: _dec('Quantity *'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: unitCtrl, decoration: _dec('Unit (e.g. Nos, Kg)'))),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: priceCtrl, decoration: _dec('Expected Unit Price (₹)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty) return;
              double sPrice = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              double parsedQty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
              if (parsedQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than 0.')));
                return;
              }
              final productMap = <String, dynamic>{
                'productId': productId,
                'name': nameCtrl.text.trim(),
                'sku': sku,
                'quantity': parsedQty,
                'unit': unitCtrl.text.trim(),
                'price': sPrice,
                'costPrice': costPrice,
                'margin': sPrice - costPrice,
                'category': category,
                'subCategory': subCategory,
                'brand': brand,
                'model': model,
                'productNature': productNature,
                'machineType': machineType,
              };
              setState(() {
                if (editIndex != null) {
                  _structuredProducts[editIndex] = productMap;
                } else {
                  _structuredProducts.add(productMap);
                }
              });
              _triggerAutosave();
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _editProduct(int index) {
    final item = _structuredProducts[index];
    _showProductDetailEntry(
      productId: item['productId'] ?? 'manual',
      name: item['name'],
      sku: item['sku'] ?? '',
      defaultPrice: double.tryParse(item['price'].toString()) ?? 0.0,
      unit: item['unit'] ?? 'Nos',
      category: item['category'] ?? 'General',
      subCategory: item['subCategory'] ?? '',
      brand: item['brand'] ?? '',
      model: item['model'] ?? '',
      costPrice: double.tryParse(item['costPrice']?.toString() ?? '0') ?? 0.0,
      productNature: item['productNature'] ?? 'General',
      machineType: item['machineType'] ?? '',
      editIndex: index,
    );
  }

  Widget _buildFollowUpSection() {
    final followUpOptions = const <String>['Call', 'Email', 'Visit', 'Meeting', 'WhatsApp'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResponsiveFields([
          _buildDateSelector(
            label: 'Next Follow-up Date',
            value: _nextFollowUpDate,
            onTap: () async => await _pickDate(
              initialValue: _nextFollowUpDate,
              onPicked: (d) => setState(() {
                _nextFollowUpDate = d;
                _isFollowUpManuallyEdited = true;
              }),
            ),
            onClear: () => setState(() {
              _nextFollowUpDate = null;
              _isFollowUpManuallyEdited = true;
            }),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: followUpOptions.contains(_followUpType) ? _followUpType : 'Call',
            decoration: _dec('Follow-up Type', prefixIcon: const Icon(Icons.event_outlined)),
            items: followUpOptions.map<DropdownMenuItem<String>>((String e) => DropdownMenuItem<String>(value: e, child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
            selectedItemBuilder: (BuildContext context) {
              return followUpOptions.map<Widget>((String e) => Text(e, maxLines: 1, overflow: TextOverflow.ellipsis)).toList();
            },
            onChanged: (v) => setState(() => _followUpType = v ?? 'Call'),
          ),
        ]),
        const SizedBox(height: 16),
        const Text('Priority Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Row(
          children: ['Cold', 'Warm', 'Hot'].map((p) {
            final isSelected = _selectedPriority == p;
            final color = p == 'Hot' ? Colors.red : (p == 'Warm' ? Colors.orange : Colors.blue);
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ChoiceChip(
                label: Text(p, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                selected: isSelected,
                onSelected: (v) {
                  if (v) setState(() => _selectedPriority = p);
                },
                selectedColor: color,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? color : Colors.grey.shade300)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastFollowUpNoteController,
          maxLines: 2,
          decoration: _dec('Latest Follow-up Remarks', hint: 'E.g. Called client, asked for quote.', prefixIcon: const Icon(Icons.history_edu)),
        ),
      ],
    );
  }

  Widget _buildDateSelector({required String label, required DateTime? value, required VoidCallback onTap, VoidCallback? onClear}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(
          label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          suffixIcon: value != null ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClear) : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(value.toLocal()),
          style: TextStyle(color: value == null ? Colors.grey.shade500 : Colors.black87, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildAssignUserDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyUsersRef.where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;

        // Deterministic valid value
        final validAssignedUid = docs.any((d) => d.id == _assignedToUid) ? _assignedToUid : null;

        return DropdownButtonFormField<String>(
          isExpanded: true,
          value: validAssignedUid,
          decoration: _dec('Assigned Record Owner *', prefixIcon: const Icon(Icons.assignment_ind_outlined)),
          items: docs.map<DropdownMenuItem<String>>((doc) => DropdownMenuItem<String>(
              value: doc.id,
              child: Text((doc.data()['name'] ?? doc.data()['fullName'] ?? 'Unknown').toString(), maxLines: 1, overflow: TextOverflow.ellipsis)
          )).toList(),
          selectedItemBuilder: (BuildContext context) {
            return docs.map<Widget>((doc) {
              return Text((doc.data()['name'] ?? doc.data()['fullName'] ?? 'Unknown').toString(), maxLines: 1, overflow: TextOverflow.ellipsis);
            }).toList();
          },
          onChanged: _isAdminOrManager ? (v) => setState(() => _assignedToUid = v) : null,
          validator: (v) => v == null ? 'Required' : null,
        );
      },
    );
  }

  Future<void> _pickDate({required DateTime? initialValue, required ValueChanged<DateTime> onPicked}) async {
    final now = DateTime.now().toUtc();
    final firstDate = DateTime(now.year - 5).toUtc();
    final lastDate = DateTime(now.year + 5).toUtc();
    var initialDate = initialValue ?? now;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final picked = await showDatePicker(context: context, initialDate: initialDate.toLocal(), firstDate: firstDate.toLocal(), lastDate: lastDate.toLocal());
    if (picked != null) onPicked(picked.toUtc()); // Normalize to UTC
  }

  Widget _buildStickyActionBar() {
    final disableButtons = _isSaving || _isLockedForm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final buttonWidth = compact ? constraints.maxWidth : null;
            return Wrap(
              alignment: WrapAlignment.end,
              runSpacing: 12,
              spacing: 12,
              children: [
                SizedBox(
                  width: buttonWidth,
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(
                  width: buttonWidth,
                  child: OutlinedButton(
                    onPressed: disableButtons ? null : () => _saveInquiry(createQuote: true),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), side: BorderSide(color: disableButtons ? Colors.grey.shade400 : const Color(0xFF2563EB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text('Save & Quote', style: TextStyle(color: disableButtons ? Colors.grey.shade500 : const Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(
                  width: buttonWidth,
                  child: FilledButton.icon(
                    onPressed: disableButtons ? null : () => _saveInquiry(),
                    style: FilledButton.styleFrom(backgroundColor: disableButtons ? Colors.grey.shade400 : const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
                    label: Text(_isEditing ? 'Update Inquiry' : 'Save Inquiry', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Inquiry' : 'Create Inquiry', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFE2E8F0), height: 1)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  _buildFormMessageBanner(),
                  _buildSection(title: 'Customer & Contacts', icon: Icons.domain, child: _buildCustomerSection()),
                  _buildSection(title: 'Inquiry Basics', icon: Icons.info_outline, child: _buildInquiryBasicsSection()),
                  _buildSection(title: 'Products & Scope', icon: Icons.inventory_2_outlined, child: _buildProductsSection()),
                  _buildSection(title: 'Follow-up & Activity', icon: Icons.event_available, child: _buildFollowUpSection()),
                  if (_isEditing)
                    _buildSection(
                      title: 'Activity Timeline',
                      icon: Icons.timeline,
                      child: InquiryActivityTimeline(
                        companyId: widget.companyId,
                        inquiryId: widget.existingDoc!.id,
                        legacyStatus: (_existingRawData?['status'] ?? 'Open').toString(),
                        onViewRelatedDocument: _viewRelatedActivity,
                      ),
                    ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildStickyActionBar(),
    );
  }
}

// ---------------------------------------------------------
// ENTERPRISE PAGINATED SEARCH DIALOG FOR INVENTORY
// ---------------------------------------------------------
class _ERPProductSearchDialog extends StatefulWidget {
  final String companyId;
  final Function(Map<String, dynamic> docData, String docId) onProductSelected;
  final Function(String query) onManualAdd;

  const _ERPProductSearchDialog({required this.companyId, required this.onProductSelected, required this.onManualAdd});

  @override
  State<_ERPProductSearchDialog> createState() => _ERPProductSearchDialogState();
}

class _ERPProductSearchDialogState extends State<_ERPProductSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DocumentSnapshot> _allItems = <DocumentSnapshot>[];
  List<DocumentSnapshot> _items = <DocumentSnapshot>[];
  bool _isLoading = false;
  bool _hasMore = true;
  String _currentQuery = '';
  Timer? _debounce;
  int _searchEpoch = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_currentQuery.isNotEmpty) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchItems(loadMore: true);
    }
  }

  bool _matchesQuery(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final q = _currentQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    final fields = [
      data['itemName'], data['name'], data['category'],
      data['subCategory'], data['sku'], data['itemCode'],
      data['brand'], data['model'], data['productNature'],
      data['machineType']
    ];
    return fields.any((value) => (value ?? '').toString().toLowerCase().contains(q));
  }

  void _applyLocalFilter() {
    final filtered = _currentQuery.isEmpty ? List<DocumentSnapshot>.from(_allItems) : _allItems.where(_matchesQuery).toList();
    if (!mounted) return;
    setState(() => _items = filtered);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = query.toLowerCase().trim();
      if (q != _currentQuery) {
        setState(() => _currentQuery = q);
        _applyLocalFilter();
        if (_currentQuery.isNotEmpty && _items.isEmpty && _hasMore) {
          _fetchItems(loadMore: true);
        }
      }
    });
  }

  Future<void> _fetchItems({bool loadMore = false}) async {
    if (_isLoading || !_hasMore) return;
    if (loadMore && _allItems.isEmpty) return;

    final epoch = ++_searchEpoch;
    setState(() => _isLoading = true);

    try {
      Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('products')
          .where('isActive', isEqualTo: true);

      ref = ref.limit(80);
      if (loadMore && _allItems.isNotEmpty) ref = ref.startAfterDocument(_allItems.last);

      final snap = await ref.get();
      if (epoch != _searchEpoch) return;

      final fetchedDocs = snap.docs.where((doc) => !_allItems.any((existing) => existing.id == doc.id)).toList();

      if (!mounted) return;
      setState(() {
        if (!loadMore) {
          _allItems = fetchedDocs;
        } else {
          _allItems.addAll(fetchedDocs);
        }
        _hasMore = snap.docs.length == 80;
        _items = _currentQuery.isEmpty ? List<DocumentSnapshot>.from(_allItems) : _allItems.where(_matchesQuery).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      developer.log('Product fetch error', error: e, name: 'InquiryModule');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('Select Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search by Name, Category, SKU or Nature...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _items.isEmpty && !_isLoading
                  ? Center(child: Text('No products found matching "$_currentQuery".\nYou can add manually below.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.separated(
                controller: _scrollController,
                itemCount: _items.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  if (index == _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  final doc = _items[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['itemName'] ?? data['name'] ?? 'Unknown').toString();
                  final sku = (data['sku'] ?? data['itemCode'] ?? '').toString();
                  final price = double.tryParse(data['sellingPrice']?.toString() ?? data['price']?.toString() ?? '0') ?? 0.0;
                  final category = (data['category'] ?? data['categoryId'] ?? '').toString();
                  final productNature = (data['productNature'] ?? 'General').toString();

                  return RepaintBoundary(
                    child: ListTile(
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.inventory_2, color: Colors.blue, size: 20)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Cat: $category | SKU: $sku\nNature: $productNature'),
                      isThreeLine: true,
                      trailing: Text('₹$price', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      onTap: () => widget.onProductSelected(data, doc.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(onPressed: () => widget.onManualAdd(_searchCtrl.text), icon: const Icon(Icons.edit_note, size: 18), label: const Text('Add Manually')),
      ],
    );
  }
}
