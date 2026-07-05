// FILE PATH: lib/modules/sales/quotations/quotation_screen_local.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import 'quotation_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);
const String quotationSeriesPrefix = 'MEM';

class QuotationScreenLocal extends StatefulWidget {
  final int? userId;
  final String? currentUserUid;
  final String? companyId;
  final String? quotationId;
  final Map<String, dynamic>? inquirySeed;
  final Map<String, dynamic>? existingQuotation;

  const QuotationScreenLocal({
    super.key,
    this.userId,
    this.currentUserUid,
    this.companyId,
    this.quotationId,
    this.inquirySeed,
    this.existingQuotation,
  });

  @override
  State<QuotationScreenLocal> createState() => _QuotationScreenLocalState();
}

class _QuotationScreenLocalState extends State<QuotationScreenLocal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _customerNameFocusNode = FocusNode();

  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  String _currentUserName = '';

  String _companyName = '';
  String _companyAddress = '';
  String _companyPhone = '';
  String _companyEmail = '';
  String _companyGst = '';
  String _companyCin = '';
  String _companyPan = '';
  String _companyWebsite = '';
  String _companyBankDetails = '';
  String _companyLogoUrl = '';
  String _companyState = '';
  String _quotationPrefix = quotationSeriesPrefix;
  String _quotationType = 'domestic';
  Map<String, dynamic> _quotationSettings = {};

  bool _isLoading = false;
  bool _isRestoring = false;
  bool _isUserChangingAddress = false;
  String? _errorMessage;
  bool _isInterState = false;
  bool _isReadOnly = false;
  int _currentVersion = 1;

  bool get _isAdminOrManager => [
    'admin',
    'manager',
    'director',
    'md',
    'ceo',
    'super_admin',
  ].contains(_currentUserRole.toLowerCase());

  bool get _hasLinkedInquiry =>
      (_linkedInquiryId?.trim().isNotEmpty ?? false) ||
      (_linkedInquiryNumber?.trim().isNotEmpty ?? false);

  String? _cleanOptionalString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _approvalStatus = 'Pending';
  String _quotationStatus = 'Sent';
  String _paymentStatus = 'Pending';

  String? _selectedCustomerId;
  String _selectedCustomerLabel = '';
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _contactDepartmentController =
      TextEditingController();
  final TextEditingController _contactDesignationController =
      TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  String _customerState = '';
  Map<String, dynamic>? _customerInsights;

  List<Map<String, dynamic>> _customerAddresses = [];
  String? _selectedAddressId;
  Map<String, dynamic>? _selectedAddressData;
  String _customerPrimaryAddressSnapshot = '';
  String _customerPrimaryCitySnapshot = '';
  String _customerPrimaryStateSnapshot = '';
  String _customerPrimaryPincodeSnapshot = '';

  String? _selectedContactId;
  Map<String, dynamic>? _selectedContactData;
  String _contactPersonSnapshot = '';
  String _contactEmailSnapshot = '';
  String _contactMobileSnapshot = '';
  String _contactDepartmentSnapshot = '';
  String _contactDesignationSnapshot = '';

  final TextEditingController _quotationSequenceController =
      TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String? _linkedInquiryId;
  String? _linkedInquiryNumber;
  final TextEditingController _inquiryRefNoteController =
      TextEditingController();

  DateTime _inquiryDate = DateTime.now().toUtc();
  DateTime _quoteDate = DateTime.now().toUtc();
  DateTime? _nextFollowUpDate;
  final TextEditingController _followUpNotesController =
      TextEditingController();

  final List<String> _inquirySources = const [
    'Verbal',
    'Phone Call',
    'In Visit',
    'Email',
    'WhatsApp',
    'Website',
    'Other',
  ];
  String _selectedInquirySource = 'Verbal';

  List<QuotationLineItem> _items = [];
  final Map<String, Map<String, dynamic>> _itemExtras = {};

  // PERFORMANCE: Global product memory cache to prevent duplicate Firestore reads
  final Map<String, Map<String, dynamic>> _productCache = {};

  double _globalDiscountPercent = 0.0;

  double _cachedSubtotal = 0.0;
  double _cachedItemDiscount = 0.0;
  double _cachedGlobalDiscountAmount = 0.0;
  double _cachedTaxableAmount = 0.0;
  double _cachedCgst = 0.0;
  double _cachedSgst = 0.0;
  double _cachedIgst = 0.0;
  double _cachedGrandTotal = 0.0;
  double _cachedRoundOff = 0.0;
  double _cachedFinalTotal = 0.0;

  List<TermRow> _dynamicTerms = [];
  bool _packingChargesExtra = true;

  final TextEditingController _signNameController = TextEditingController();
  final TextEditingController _signDesignationController =
      TextEditingController();
  final TextEditingController _signPhoneController = TextEditingController();

  CollectionReference<Map<String, dynamic>> _companyContactsRef(
    String customerId,
  ) {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('customers')
        .doc(customerId)
        .collection('contacts');
  }

  Future<Map<String, dynamic>?> _getProductData(String productId) async {
    if (_companyId == null || _companyId!.isEmpty || productId.isEmpty)
      return null;
    if (_productCache.containsKey(productId)) return _productCache[productId];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('products')
          .doc(productId)
          .get();
      if (doc.exists && doc.data() != null) {
        _productCache[productId] = {'id': doc.id, ...doc.data()!};
        return _productCache[productId];
      }
    } catch (e) {
      developer.log('Error fetching product data: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getCompatibleProducts(
    QuotationLineItem machine,
    Map<String, dynamic> extras,
  ) async {
    if (_companyId == null || _companyId!.isEmpty) return [];
    List<Map<String, dynamic>> results = [];
    final ref = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products')
        .where('isActive', isEqualTo: true);

    String mType = (extras['machineType'] ?? '').toString();
    String pId = machine.productId;
    String subId = (extras['subcategoryId'] ?? '').toString();

    try {
      if (mType.isNotEmpty) {
        final snap1 = await ref
            .where('compatibleMachineType', isEqualTo: mType)
            .get();
        for (var d in snap1.docs) {
          _productCache[d.id] = {'id': d.id, ...d.data()};
          results.add(_productCache[d.id]!);
        }
      }
      if (pId.isNotEmpty) {
        final snap2 = await ref
            .where('compatibleProductIds', arrayContains: pId)
            .get();
        for (var d in snap2.docs) {
          _productCache[d.id] = {'id': d.id, ...d.data()};
          results.add(_productCache[d.id]!);
        }
      }
      if (subId.isNotEmpty) {
        final snap3 = await ref
            .where('compatibleSubcategories', arrayContains: subId)
            .get();
        for (var d in snap3.docs) {
          _productCache[d.id] = {'id': d.id, ...d.data()};
          results.add(_productCache[d.id]!);
        }
      }
    } catch (e) {
      developer.log('Error fetching compatible products: $e');
    }

    final Map<String, Map<String, dynamic>> unique = {};
    for (var r in results) {
      unique[r['id']] = r;
    }
    return unique.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _quoteDate = DateTime.now().toUtc();
    _inquiryDate = DateTime.now().toUtc();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isRestoring = true;
      });
    }

    await _loadUserContext();
    await _loadCompanyProfile();
    await _loadUserSettings();
    await _loadQuotationSettings();

    if (widget.existingQuotation != null) {
      developer.log('Existing Quotation Restored', name: 'QuotationScreen');
      await _loadExistingQuotation(widget.existingQuotation!);
    } else {
      await _applyInquirySeedIfNeeded();
      _applyQuotationSettingsDefaultTerms(force: true);
    }

    _calculateTotals();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isRestoring = false;
      });
    }
  }

  String _normalizeQuotationType(dynamic value) {
    final text = (value ?? '').toString().trim().toLowerCase();
    return text.contains('export') ? 'export' : 'domestic';
  }

  Future<void> _loadQuotationSettings() async {
    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('letterhead_settings')
          .get();

      _quotationSettings = snap.data() ?? <String, dynamic>{};

      if (_quotationSettings.isEmpty) {
        final oldSnap = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('settings')
            .doc('quotation_settings')
            .get();
        _quotationSettings = oldSnap.data() ?? <String, dynamic>{};
      }
    } catch (e) {
      developer.log(
        'Unable to load quotation settings: $e',
        name: 'QuotationScreen',
      );
    }
  }

  List<TermRow> _settingsTermsForType(String type) {
    final normalizedType = _normalizeQuotationType(type);
    final rawSettings = _quotationSettings[normalizedType];

    if (rawSettings is! Map) return [];

    final settings = Map<String, dynamic>.from(rawSettings);
    final rawTerms = settings['terms'];

    if (rawTerms is! List) return [];

    final rows = <TermRow>[];

    for (final item in rawTerms) {
      if (item is Map) {
        final title = (item['title'] ?? '').toString().trim();
        final value = (item['value'] ?? '').toString().trim();

        if (title.isNotEmpty || value.isNotEmpty) {
          rows.add(TermRow(title: title, value: value));
        }
      } else {
        final value = item.toString().trim();
        if (value.isNotEmpty) {
          rows.add(TermRow(title: 'Term', value: value));
        }
      }
    }

    return rows;
  }

  void _applyQuotationSettingsDefaultTerms({bool force = false}) {
    final hasExistingTerms = _dynamicTerms.any((term) {
      return term.titleCtrl.text.trim().isNotEmpty ||
          term.valueCtrl.text.trim().isNotEmpty;
    });

    if (!force && hasExistingTerms) return;

    final settingTerms = _settingsTermsForType(_quotationType);
    if (settingTerms.isEmpty) return;

    for (final term in _dynamicTerms) {
      term.dispose();
    }

    _dynamicTerms = settingTerms;
  }

  void _applyProfessionalDefaultTerms() {
    for (var t in _dynamicTerms) {
      t.dispose();
    }
    _dynamicTerms.clear();
    _dynamicTerms = [
      TermRow(
        title: 'Payment',
        value: '100% payment against Proforma Invoice before dispatch.',
      ),
      TermRow(
        title: 'Delivery Time',
        value:
            '4 to 6 weeks from the date of receipt of technically and commercially clear PO along with advance.',
      ),
      TermRow(
        title: 'Validity',
        value: '30 Days from the date of this quotation.',
      ),
      TermRow(
        title: 'Warranty',
        value:
            '12 months from the date of dispatch or 18 months from the date of commissioning, whichever is earlier.',
      ),
      TermRow(title: 'Price Basis', value: 'Ex-Works.'),
      TermRow(
        title: 'Freight & Insurance',
        value: 'Extra at actuals. To be borne by the buyer.',
      ),
      TermRow(
        title: 'Installation',
        value:
            'Extra as applicable. Boarding, lodging and local transport of engineer to be arranged by the buyer.',
      ),
    ];
  }

  Future<void> _loadExistingQuotation(Map<String, dynamic> data) async {
    _approvalStatus = data['approvalStatus']?.toString() ?? 'Pending';
    _quotationStatus = data['status']?.toString() ?? 'Sent';
    _paymentStatus = data['paymentStatus']?.toString() ?? 'Pending';
    _currentVersion = data['version'] ?? 1;
    _quotationType = _normalizeQuotationType(data['quotationType']);

    if ((_approvalStatus == 'Approved' || _quotationStatus == 'Converted') &&
        !_isAdminOrManager) {
      _isReadOnly = true;
    }

    _quoteDate =
        (data['quoteDate'] as Timestamp?)?.toDate().toUtc() ??
        DateTime.now().toUtc();

    String rawNo = data['quoteNumber']?.toString() ?? '';
    if (rawNo.isNotEmpty) {
      List<String> parts = rawNo.split('/');
      if (parts.length >= 3) {
        _quotationSequenceController.text = parts[1];
      } else {
        _quotationSequenceController.text = rawNo;
      }
    }

    _subjectController.text = data['subject']?.toString() ?? '';

    _selectedCustomerId = data['customerId']?.toString();
    _selectedAddressId =
        data['addressId']?.toString() ?? data['customerAddressId']?.toString();
    _selectedContactId =
        data['contactId']?.toString() ?? data['customerContactId']?.toString();

    if (data['addressSnapshot'] != null &&
        data['addressSnapshot'] is Map &&
        (data['addressSnapshot'] as Map).isNotEmpty) {
      _selectedAddressData = Map<String, dynamic>.from(data['addressSnapshot']);
      _updateAddressSnapshots(_selectedAddressData, restoreMode: true);
    } else {
      _customerPrimaryAddressSnapshot =
          data['addressLine']?.toString() ??
          data['clientAddress']?.toString() ??
          '';
      _customerPrimaryCitySnapshot = data['city']?.toString() ?? '';
      _customerPrimaryStateSnapshot =
          data['state']?.toString() ?? data['customerState']?.toString() ?? '';
      _customerPrimaryPincodeSnapshot = data['pincode']?.toString() ?? '';
      _addressController.text = _customerPrimaryAddressSnapshot;
      _customerState = _customerPrimaryStateSnapshot.toLowerCase();
      _checkInterState();
    }

    if (data['contactSnapshot'] != null &&
        data['contactSnapshot'] is Map &&
        (data['contactSnapshot'] as Map).isNotEmpty) {
      _selectedContactData = Map<String, dynamic>.from(data['contactSnapshot']);
      _updateContactSnapshots(_selectedContactData, restoreMode: true);
    } else {
      _contactPersonSnapshot = data['contactPerson']?.toString() ?? '';
      _contactEmailSnapshot =
          data['contactEmail']?.toString() ??
          data['clientEmail']?.toString() ??
          '';
      _contactMobileSnapshot =
          data['contactMobile']?.toString() ??
          data['clientMobile']?.toString() ??
          '';
      _contactDepartmentSnapshot =
          (data['contactDepartment'] ?? data['department'] ?? '').toString();
      _contactDesignationSnapshot =
          (data['contactDesignation'] ?? data['designation'] ?? '').toString();
      _contactPersonController.text = _contactPersonSnapshot;
      _contactDepartmentController.text = _contactDepartmentSnapshot;
      _contactDesignationController.text = _contactDesignationSnapshot;

      final existingCustomerGstin =
          (data['customerGstin'] ??
                  data['customerGSTIN'] ??
                  data['customerGstNo'] ??
                  data['partyGstin'] ??
                  data['billingGstin'] ??
                  '')
              .toString()
              .trim();

      if (existingCustomerGstin.isNotEmpty) {
        _gstController.text = existingCustomerGstin;
      }
      _gstController.text =
          (data['customerGstin'] ??
                  data['customerGSTIN'] ??
                  data['customerGstNo'] ??
                  data['billingGstin'] ??
                  data['partyGstin'] ??
                  data['gstin'] ??
                  data['gstNo'] ??
                  '')
              .toString();
      _emailController.text = _contactEmailSnapshot;
      _mobileController.text = _contactMobileSnapshot;
    }

    _clientNameController.text = data['clientName']?.toString() ?? '';
    _selectedCustomerLabel = _clientNameController.text.trim();
    _gstController.text = data['gstNo']?.toString() ?? '';
    _isInterState = data['isInterState'] as bool? ?? false;

    _linkedInquiryId = _cleanOptionalString(data['inquiryId']);
    _linkedInquiryNumber = _cleanOptionalString(
      data['inquiryNumber'] ?? data['inquiryRefNo'],
    );
    _selectedInquirySource = data['inquirySource']?.toString() ?? 'Verbal';
    final restoredInquiryDate = data['inquiryDate'];
    if (_hasLinkedInquiry && restoredInquiryDate is Timestamp) {
      _inquiryDate = restoredInquiryDate.toDate().toUtc();
    } else {
      _linkedInquiryId = null;
      _linkedInquiryNumber = null;
      _inquiryDate = _quoteDate;
    }
    _inquiryRefNoteController.text = data['inquiryReference']?.toString() ?? '';

    _nextFollowUpDate = (data['nextFollowUpDate'] as Timestamp?)
        ?.toDate()
        .toUtc();
    _followUpNotesController.text = data['followUpNotes']?.toString() ?? '';

    if (data['items'] != null && data['items'] is List) {
      final rawItems = data['items'] as List;
      List<Future<QuotationLineItem?>> tasks = [];
      for (var rawItem in rawItems) {
        if (rawItem != null && rawItem is Map) {
          tasks.add(_hydrateProductItem(Map<String, dynamic>.from(rawItem)));
        }
      }
      final results = await Future.wait(tasks);
      _items = results.whereType<QuotationLineItem>().toList();
      _recalculateTaxes();
    }

    _globalDiscountPercent =
        double.tryParse(data['globalDiscountPercent']?.toString() ?? '0') ??
        0.0;
    _packingChargesExtra = data['packingChargesExtra'] as bool? ?? true;

    final existingName = data['signatureName']?.toString().trim() ?? '';
    if (existingName.isNotEmpty) _signNameController.text = existingName;

    final existingDesig = data['signatureDesignation']?.toString().trim() ?? '';
    if (existingDesig.isNotEmpty)
      _signDesignationController.text = existingDesig;

    final existingPhone = data['signaturePhone']?.toString().trim() ?? '';
    if (existingPhone.isNotEmpty) _signPhoneController.text = existingPhone;

    for (var t in _dynamicTerms) {
      t.dispose();
    }
    _dynamicTerms.clear();

    if (data['dynamicTerms'] != null && data['dynamicTerms'] is List) {
      _dynamicTerms = (data['dynamicTerms'] as List)
          .map(
            (e) => TermRow(
              title: e['title']?.toString() ?? '',
              value: e['value']?.toString() ?? '',
            ),
          )
          .toList();
    } else {
      void addIfValid(String title, String? val) {
        if (val != null && val.trim().isNotEmpty) {
          _dynamicTerms.add(TermRow(title: title, value: val.trim()));
        }
      }

      addIfValid('Payment', data['paymentTerms']?.toString());
      addIfValid('Delivery Time', data['deliveryTime']?.toString());
      addIfValid('Validity', data['validity']?.toString());
      addIfValid('Warranty', data['warranty']?.toString());
      addIfValid('Price Basis', data['priceBasis']?.toString());
      addIfValid('Freight', data['freight']?.toString());
      addIfValid('Installation', data['installation']?.toString());

      if (data['extraTerms'] != null && data['extraTerms'] is List) {
        for (var t in data['extraTerms']) {
          addIfValid('Term', t.toString());
        }
      }
    }

    if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
      _fetchCustomerInsights(_selectedCustomerId!);
      await _loadCustomerFromFirestore(_selectedCustomerId!, restoreMode: true);
      if (_selectedContactId != null && _selectedContactId!.isNotEmpty) {
        await _loadContactData(
          _selectedCustomerId!,
          _selectedContactId!,
          restoreMode: true,
        );
      }
    }

    developer.log('Quotation Loaded', name: 'QuotationScreen');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customerNameFocusNode.dispose();
    _clientNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _contactPersonController.dispose();
    _contactDepartmentController.dispose();
    _contactDesignationController.dispose();
    _gstController.dispose();
    _quotationSequenceController.dispose();
    _subjectController.dispose();
    _inquiryRefNoteController.dispose();
    _signNameController.dispose();
    _signDesignationController.dispose();
    _signPhoneController.dispose();
    _followUpNotesController.dispose();
    for (var t in _dynamicTerms) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No logged-in user.');

      final rootUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final rootData = rootUserDoc.data() ?? {};

      _currentUserUid = user.uid;
      _companyId = widget.companyId?.trim().isNotEmpty == true
          ? widget.companyId!.trim()
          : (rootData['activeCompanyId'] ?? rootData['companyId'] ?? '')
                .toString()
                .trim();

      _currentUserRole = (rootData['role'] ?? 'sales').toString().trim();

      Map<String, dynamic>? membershipData;
      if (_companyId != null &&
          _companyId!.isNotEmpty &&
          rootData['memberships'] != null) {
        membershipData =
            rootData['memberships'][_companyId] as Map<String, dynamic>?;
        if (membershipData != null && membershipData['role'] != null) {
          _currentUserRole = membershipData['role'].toString().trim();
        }
      }

      Map<String, dynamic> compData = {};
      if (_companyId != null && _companyId!.isNotEmpty) {
        final compUserDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(_companyId)
            .collection('users')
            .doc(user.uid)
            .get();
        if (compUserDoc.exists) {
          compData = compUserDoc.data() ?? {};
        }
      }

      _currentUserName =
          (compData['name'] ??
                  compData['fullName'] ??
                  membershipData?['name'] ??
                  rootData['name'] ??
                  rootData['fullName'] ??
                  '')
              .toString()
              .trim();

      String userDesignation =
          (compData['designation'] ??
                  membershipData?['designation'] ??
                  rootData['designation'] ??
                  '')
              .toString()
              .trim();

      String userDepartment =
          (compData['department'] ??
                  membershipData?['department'] ??
                  rootData['department'] ??
                  '')
              .toString()
              .trim();

      String userPhone =
          (compData['phone'] ??
                  compData['mobile'] ??
                  membershipData?['phone'] ??
                  membershipData?['mobile'] ??
                  rootData['phone'] ??
                  rootData['mobile'] ??
                  user.phoneNumber ??
                  '')
              .toString()
              .trim();

      if (widget.existingQuotation == null) {
        if (_currentUserName.isNotEmpty)
          _signNameController.text = _currentUserName;
        if (userPhone.isNotEmpty) _signPhoneController.text = userPhone;

        if (userDesignation.isNotEmpty) {
          _signDesignationController.text = userDesignation;
        } else if (userDepartment.isNotEmpty) {
          _signDesignationController.text = userDepartment;
        } else {
          _signDesignationController.text = _currentUserRole.toUpperCase();
        }
      }
    } catch (e) {
      _setError('Failed to load user context.');
    }
  }

  Future<void> _loadCompanyProfile() async {
    if (_companyId == null || _companyId!.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};

      _companyName =
          (data['companyName'] ?? data['name'] ?? data['entityName'] ?? '')
              .toString();

      List<String> addressLines = [];
      final street = (data['streetAddress'] ?? data['address'] ?? '')
          .toString()
          .trim();
      if (street.isNotEmpty) addressLines.add(street);

      final city = (data['city'] ?? data['district'] ?? '').toString().trim();
      final state = (data['state'] ?? '').toString().trim();
      final zip = (data['postalCode'] ?? data['pincode'] ?? data['zip'] ?? '')
          .toString()
          .trim();

      List<String> localityParts = [];
      if (city.isNotEmpty) localityParts.add(city);
      if (state.isNotEmpty) localityParts.add(state);
      if (zip.isNotEmpty) localityParts.add(zip);

      if (localityParts.isNotEmpty) {
        addressLines.add(localityParts.join(', '));
      }

      final country = (data['country'] ?? '').toString().trim();
      if (country.isNotEmpty && country.toLowerCase() != 'india') {
        addressLines.add(country);
      }

      _companyAddress = addressLines.join('\n');
      _companyPhone = (data['phone'] ?? data['mobile'] ?? '').toString();
      _companyEmail = (data['email'] ?? '').toString();
      _companyWebsite = (data['website'] ?? '').toString();
      _companyGst = (data['gstin'] ?? data['gstNo'] ?? data['gst'] ?? '')
          .toString();
      _companyCin = (data['cin'] ?? '').toString();
      _companyPan = (data['pan'] ?? '').toString();
      _companyBankDetails = (data['bankDetails'] ?? '').toString();
      _companyLogoUrl = (data['logoUrl'] ?? '').toString();
      _companyState = (data['state'] ?? '').toString().trim().toLowerCase();

      final configuredPrefix =
          (data['quotationPrefix'] ?? data['quotePrefix'] ?? '')
              .toString()
              .trim();
      if (configuredPrefix.isNotEmpty) {
        _quotationPrefix = configuredPrefix.toUpperCase();
      }
    } catch (_) {}
  }

  void _updateAddressSnapshots(
    Map<String, dynamic>? address, {
    bool restoreMode = false,
  }) {
    if (address == null) return;
    final addr = (address['combinedAddress'] ?? address['address'] ?? '')
        .toString()
        .trim();
    final city = (address['city'] ?? '').toString().trim();
    final state = (address['state'] ?? '').toString().trim();
    final pincode = (address['pincode'] ?? '').toString().trim();

    if (!restoreMode) {
      _addressController.text = addr;
      _customerPrimaryAddressSnapshot = addr;
      _customerPrimaryCitySnapshot = city;
      _customerState = state.toLowerCase();
      _customerPrimaryStateSnapshot = state;
      _customerPrimaryPincodeSnapshot = pincode;
    } else {
      if (_addressController.text.trim().isEmpty && addr.isNotEmpty) {
        _addressController.text = addr;
        _customerPrimaryAddressSnapshot = addr;
      }
      if (_customerPrimaryCitySnapshot.trim().isEmpty && city.isNotEmpty) {
        _customerPrimaryCitySnapshot = city;
      }
      if (_customerPrimaryStateSnapshot.trim().isEmpty && state.isNotEmpty) {
        _customerState = state.toLowerCase();
        _customerPrimaryStateSnapshot = state;
      }
      if (_customerPrimaryPincodeSnapshot.trim().isEmpty &&
          pincode.isNotEmpty) {
        _customerPrimaryPincodeSnapshot = pincode;
      }
    }
    _checkInterState();
  }

  void _updateContactSnapshots(
    Map<String, dynamic>? contactData, {
    bool restoreMode = false,
  }) {
    if (contactData == null) {
      if (!restoreMode) {
        _contactEmailSnapshot = '';
        _contactMobileSnapshot = '';
        _contactPersonSnapshot = '';
        _contactDepartmentSnapshot = '';
        _contactDesignationSnapshot = '';
        _contactPersonController.clear();
        _contactDepartmentController.clear();
        _contactDesignationController.clear();
        _emailController.clear();
        _mobileController.clear();
      }
      return;
    }

    final cName = (contactData['name'] ?? contactData['contactName'] ?? '')
        .toString()
        .trim();
    final cEmail =
        (contactData['emailNormalized'] ?? contactData['email'] ?? '')
            .toString()
            .trim();
    final cPhone =
        (contactData['phoneNormalized'] ??
                contactData['phone'] ??
                contactData['mobile'] ??
                '')
            .toString()
            .trim();
    final cDepartment = (contactData['department'] ?? contactData['dept'] ?? '')
        .toString()
        .trim();
    final cDesignation =
        (contactData['designation'] ??
                contactData['jobTitle'] ??
                contactData['title'] ??
                contactData['position'] ??
                '')
            .toString()
            .trim();

    if (!restoreMode) {
      _contactPersonController.text = cName;
      _contactPersonSnapshot = cName;
      _emailController.text = cEmail;
      _contactEmailSnapshot = cEmail;
      _mobileController.text = cPhone;
      _contactMobileSnapshot = cPhone;
      _contactDepartmentController.text = cDepartment;
      _contactDepartmentSnapshot = cDepartment;
      _contactDesignationController.text = cDesignation;
      _contactDesignationSnapshot = cDesignation;
    } else {
      if (_contactPersonController.text.trim().isEmpty && cName.isNotEmpty) {
        _contactPersonController.text = cName;
        _contactPersonSnapshot = cName;
      }
      if (_emailController.text.trim().isEmpty && cEmail.isNotEmpty) {
        _emailController.text = cEmail;
        _contactEmailSnapshot = cEmail;
      }
      if (_mobileController.text.trim().isEmpty && cPhone.isNotEmpty) {
        _mobileController.text = cPhone;
        _contactMobileSnapshot = cPhone;
      }
      if (_contactDepartmentController.text.trim().isEmpty &&
          cDepartment.isNotEmpty) {
        _contactDepartmentController.text = cDepartment;
        _contactDepartmentSnapshot = cDepartment;
      }
      if (_contactDesignationController.text.trim().isEmpty &&
          cDesignation.isNotEmpty) {
        _contactDesignationController.text = cDesignation;
        _contactDesignationSnapshot = cDesignation;
      }
    }
  }

  Future<void> _loadContactData(
    String customerId,
    String contactId, {
    bool restoreMode = false,
  }) async {
    try {
      final doc = await _companyContactsRef(customerId).doc(contactId).get();
      if (mounted) {
        setState(() {
          _selectedContactData = doc.exists ? doc.data() : null;
          if (_selectedContactData != null) {
            _updateContactSnapshots(
              _selectedContactData,
              restoreMode: restoreMode,
            );
            developer.log(
              'Contact Restored: $contactId',
              name: 'QuotationScreen',
            );
          }
        });
      }
    } catch (e, st) {
      developer.log('Failed to load contact data', error: e, stackTrace: st);
    }
  }

  Future<void> _loadCustomerFromFirestore(
    String customerId, {
    bool restoreMode = false,
  }) async {
    if (_companyId == null || _companyId!.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('customers')
          .doc(customerId)
          .get();
      if (doc.exists && doc.data() != null) {
        developer.log('Customer Loaded', name: 'QuotationScreen');
        final data = doc.data()!;

        final loadedCustomerGstin =
            (data['customerGstin'] ??
                    data['customerGSTIN'] ??
                    data['customerGstNo'] ??
                    data['gstin'] ??
                    data['gstNo'] ??
                    data['gst'] ??
                    '')
                .toString()
                .trim();
        if (loadedCustomerGstin.isNotEmpty) {
          _gstController.text = loadedCustomerGstin;
        }

        _selectedCustomerId = customerId;

        if (!restoreMode || _clientNameController.text.trim().isEmpty) {
          _clientNameController.text =
              (data['companyName'] ?? data['name'] ?? '').toString();
        }
        _selectedCustomerLabel = _clientNameController.text.trim();
        if (!restoreMode || _gstController.text.trim().isEmpty) {
          _gstController.text =
              (data['customerGstin'] ??
                      data['customerGSTIN'] ??
                      data['customerGstNo'] ??
                      data['gstin'] ??
                      data['gstNo'] ??
                      data['gst'] ??
                      '')
                  .toString();
        }

        _customerAddresses = [];
        if (data['addresses'] != null && data['addresses'] is List) {
          _customerAddresses = List<Map<String, dynamic>>.from(
            data['addresses'],
          );
        }

        if (_selectedAddressId != null && _selectedAddressId!.isNotEmpty) {
          final matches = _customerAddresses.where(
            (a) => a['id'] == _selectedAddressId,
          );
          if (matches.isNotEmpty) {
            _selectedAddressData = matches.first;
            _updateAddressSnapshots(
              _selectedAddressData,
              restoreMode: restoreMode,
            );
            developer.log('Address Restored', name: 'QuotationScreen');
          }
        } else if (!restoreMode) {
          final primaryBillingMatches = _customerAddresses.where(
            (a) => a['isBillingAddress'] == true && a['isPrimary'] == true,
          );
          final primaryMatches = _customerAddresses.where(
            (a) => a['isPrimary'] == true,
          );

          _selectedAddressData = primaryBillingMatches.isNotEmpty
              ? primaryBillingMatches.first
              : (primaryMatches.isNotEmpty
                    ? primaryMatches.first
                    : (_customerAddresses.isNotEmpty
                          ? _customerAddresses.first
                          : null));

          _selectedAddressId = _selectedAddressData?['id'];
          _updateAddressSnapshots(
            _selectedAddressData,
            restoreMode: restoreMode,
          );
        }

        if (!restoreMode) {
          if (_selectedContactId == null) {
            _emailController.text = (data['email'] ?? '').toString();
            _mobileController.text = (data['mobile'] ?? data['phone'] ?? '')
                .toString();
            _contactPersonController.text =
                (data['contactPerson'] ?? data['contactName'] ?? '').toString();

            _contactEmailSnapshot = _emailController.text.trim();
            _contactMobileSnapshot = _mobileController.text.trim();
            _contactPersonSnapshot = _contactPersonController.text.trim();
          }
        } else {
          if (_selectedContactId == null) {
            if (_emailController.text.trim().isEmpty) {
              _emailController.text = (data['email'] ?? '').toString();
              _contactEmailSnapshot = _emailController.text.trim();
            }
            if (_mobileController.text.trim().isEmpty) {
              _mobileController.text = (data['mobile'] ?? data['phone'] ?? '')
                  .toString();
              _contactMobileSnapshot = _mobileController.text.trim();
            }
            if (_contactPersonController.text.trim().isEmpty) {
              _contactPersonController.text =
                  (data['contactPerson'] ?? data['contactName'] ?? '')
                      .toString();
              _contactPersonSnapshot = _contactPersonController.text.trim();
            }
          }
        }

        if (!restoreMode) {
          _fetchCustomerInsights(customerId);
        }
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<QuotationLineItem?> _hydrateProductItem(
    Map<String, dynamic> rawItem,
  ) async {
    final Map<String, dynamic> i = Map<String, dynamic>.from(rawItem);
    String productId = (i['productId'] ?? i['itemId'] ?? '').toString();
    String name = (i['name'] ?? i['productName'] ?? i['itemName'] ?? '')
        .toString();
    String desc = (i['description'] ?? i['details'] ?? '').toString();
    String scopeOfSupply =
        (i['scopeOfSupply'] ?? i['scope_of_supply'] ?? i['supplyScope'] ?? '')
            .toString();
    String hsn = (i['hsnCode'] ?? '').toString();
    double qty = double.tryParse(i['quantity']?.toString() ?? '1') ?? 1.0;
    String uom = (i['uom'] ?? i['unit'] ?? 'Nos').toString();
    double price =
        double.tryParse(
          i['unitPrice']?.toString() ??
              i['price']?.toString() ??
              i['rate']?.toString() ??
              '0',
        ) ??
        0.0;
    double disc =
        double.tryParse(
          i['discountPercent']?.toString() ?? i['discount']?.toString() ?? '0',
        ) ??
        0.0;

    double totalGst =
        double.tryParse(
          i['gstPercentage']?.toString() ?? i['tax']?.toString() ?? '0',
        ) ??
        0.0;
    if (totalGst == 0) {
      totalGst =
          (double.tryParse(i['cgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(i['sgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(i['igstPercent']?.toString() ?? '0') ?? 0.0);
    }

    double stock =
        double.tryParse(
          i['stockOnHand']?.toString() ??
              i['availableStock']?.toString() ??
              i['qty']?.toString() ??
              i['stock']?.toString() ??
              '0',
        ) ??
        0.0;

    String sku = (i['sku'] ?? '').toString();
    String brand = (i['brand'] ?? i['make'] ?? '').toString();
    String model = (i['model'] ?? '').toString();
    String productNature = (i['productNature'] ?? 'General').toString();
    String machineType = (i['machineType'] ?? '').toString();
    List includedProducts = i['includedProducts'] as List? ?? [];
    List catalogs = i['catalogs'] as List? ?? [];
    List images = i['images'] as List? ?? [];
    String compatibleMachineType = (i['compatibleMachineType'] ?? '')
        .toString();
    List compatibleProductIds = i['compatibleProductIds'] as List? ?? [];
    List compatibleProductNames = i['compatibleProductNames'] as List? ?? [];
    List compatibleSubcategories = i['compatibleSubcategories'] as List? ?? [];
    String itemCode =
        (i['itemCode'] ??
                i['productCode'] ??
                i['item_code'] ??
                i['code'] ??
                i['materialCode'] ??
                i['partNo'] ??
                i['partNumber'] ??
                i['catalogNo'] ??
                '')
            .toString()
            .trim();
    String sellingPrice = (i['sellingPrice'] ?? '').toString();
    double baseGst =
        double.tryParse(i['baseGst']?.toString() ?? totalGst.toString()) ??
        totalGst;

    bool isScopeItem = (i['isScopeItem'] == true) || (i['parentId'] != null);
    String? parentId = i['parentId']?.toString();
    bool isIncluded = i['isIncluded'] != false;
    String pricingMode = (i['pricingMode'] ?? 'Included').toString();

    if (productId.isNotEmpty) {
      try {
        final pData = await _getProductData(productId);
        if (pData != null) {
          if (name.isEmpty) name = (pData['name'] ?? '').toString();
          if (desc.isEmpty)
            desc = (pData['description'] ?? pData['details'] ?? '').toString();
          if (hsn.isEmpty)
            hsn = (pData['hsnCode'] ?? pData['hsn'] ?? '').toString();
          if (totalGst == 0)
            totalGst =
                double.tryParse(
                  pData['gstPercentage']?.toString() ??
                      pData['tax']?.toString() ??
                      '18',
                ) ??
                18.0;
          if (price == 0 && pricingMode != 'Included')
            price =
                double.tryParse(
                  pData['sellingPrice']?.toString() ??
                      pData['price']?.toString() ??
                      pData['unitPrice']?.toString() ??
                      '0',
                ) ??
                0.0;
          if (uom == 'Nos' || uom.isEmpty)
            uom = (pData['uom'] ?? 'Nos').toString();
          stock =
              double.tryParse(
                pData['stockOnHand']?.toString() ??
                    pData['availableStock']?.toString() ??
                    pData['stockQuantity']?.toString() ??
                    pData['qty']?.toString() ??
                    stock.toString(),
              ) ??
              0.0;

          if (sku.isEmpty)
            sku = (pData['sku'] ?? pData['itemCode'] ?? '').toString();
          if (brand.isEmpty)
            brand = (pData['brand'] ?? pData['make'] ?? '').toString();
          if (model.isEmpty) model = (pData['model'] ?? '').toString();
          if (productNature == 'General')
            productNature = (pData['productNature'] ?? 'General').toString();

          machineType = (pData['machineType'] ?? machineType).toString();
          includedProducts =
              pData['includedProducts'] as List? ?? includedProducts;
          catalogs = pData['catalogs'] as List? ?? catalogs;
          images = pData['images'] as List? ?? images;
          compatibleMachineType =
              (pData['compatibleMachineType'] ?? compatibleMachineType)
                  .toString();
          compatibleProductIds =
              pData['compatibleProductIds'] as List? ?? compatibleProductIds;
          compatibleProductNames =
              pData['compatibleProductNames'] as List? ??
              compatibleProductNames;
          compatibleSubcategories =
              pData['compatibleSubcategories'] as List? ??
              compatibleSubcategories;
          itemCode =
              (pData['itemCode'] ??
                      pData['productCode'] ??
                      pData['item_code'] ??
                      pData['code'] ??
                      pData['materialCode'] ??
                      pData['partNo'] ??
                      pData['partNumber'] ??
                      pData['catalogNo'] ??
                      itemCode)
                  .toString()
                  .trim();
          sellingPrice =
              (pData['sellingPrice'] ?? pData['price'] ?? sellingPrice)
                  .toString();
          if (baseGst == 0) baseGst = totalGst;
        }
      } catch (_) {}
    }

    final id = (i['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
        .toString();

    _itemExtras[id] = {
      'sku': sku,
      'brand': brand,
      'model': model,
      'productNature': productNature,
      'machineType': machineType,
      'includedProducts': includedProducts,
      'catalogs': catalogs,
      'images': images,
      'compatibleMachineType': compatibleMachineType,
      'compatibleProductIds': compatibleProductIds,
      'compatibleProductNames': compatibleProductNames,
      'compatibleSubcategories': compatibleSubcategories,
      'itemCode': itemCode,
      'sellingPrice': sellingPrice,
      'productNatureLower': productNature.toLowerCase(),
      'stockOnHand': stock,
      'qty': stock,
      'baseGst': baseGst,
      'isScopeItem': isScopeItem,
      'parentId': parentId,
      'isIncluded': isIncluded,
      'pricingMode': pricingMode,
    };

    return QuotationLineItem(
      id: id,
      productId: productId,
      itemCode: itemCode,
      name: name,
      description: desc,
      scopeOfSupply: scopeOfSupply,
      hsnCode: hsn,
      quantity: qty,
      uom: uom,
      unitPrice: price,
      discountPercent: disc,
      cgstPercent: 0,
      sgstPercent: 0,
      igstPercent: totalGst,
      availableStock: stock,
    );
  }

  Future<void> _applyInquirySeedIfNeeded() async {
    final seed = widget.inquirySeed;
    if (seed == null || seed.isEmpty) return;

    developer.log('Inquiry Loaded', name: 'QuotationScreen');

    _linkedInquiryId = _cleanOptionalString(seed['id'] ?? seed['inquiryId']);
    _linkedInquiryNumber = _cleanOptionalString(
      seed['inquiryNumber'] ?? seed['inquiryCode'],
    );

    if (seed['inquiryDate'] != null && seed['inquiryDate'] is Timestamp) {
      _inquiryDate = (seed['inquiryDate'] as Timestamp).toDate().toUtc();
    } else if (seed['createdAt'] != null && seed['createdAt'] is Timestamp) {
      _inquiryDate = (seed['createdAt'] as Timestamp).toDate().toUtc();
    }

    final incomingName =
        (seed['customerName'] ??
                seed['companyName'] ??
                seed['clientName'] ??
                '')
            .toString()
            .trim();
    final incomingPerson = (seed['contactPerson'] ?? seed['contactName'] ?? '')
        .toString()
        .trim();
    final incomingGstin =
        (seed['customerGstin'] ??
                seed['customerGSTIN'] ??
                seed['customerGstNo'] ??
                seed['gstin'] ??
                seed['gstNo'] ??
                seed['gst'] ??
                '')
            .toString()
            .trim();
    final incomingEmail =
        (seed['email'] ?? seed['contactEmail'] ?? seed['clientEmail'] ?? '')
            .toString()
            .trim();
    final incomingMobile =
        (seed['mobile'] ??
                seed['contactPhone'] ??
                seed['contactMobile'] ??
                seed['clientMobile'] ??
                '')
            .toString()
            .trim();
    final incomingAddress =
        (seed['address'] ??
                seed['location'] ??
                seed['customerPrimaryAddress'] ??
                seed['clientAddress'] ??
                '')
            .toString()
            .trim();
    final incomingCity = (seed['city'] ?? seed['customerPrimaryCity'] ?? '')
        .toString()
        .trim();
    final incomingStateRaw =
        (seed['state'] ??
                seed['customerPrimaryState'] ??
                seed['customerState'] ??
                '')
            .toString()
            .trim();
    final incomingPincode =
        (seed['pincode'] ?? seed['customerPrimaryPincode'] ?? '')
            .toString()
            .trim();
    final incomingGst =
        (seed['gstNo'] ?? seed['gst'] ?? seed['customerGST'] ?? '')
            .toString()
            .trim();

    if (incomingName.isNotEmpty) _clientNameController.text = incomingName;
    if (incomingPerson.isNotEmpty)
      _contactPersonController.text = incomingPerson;
    if (incomingGstin.isNotEmpty) _gstController.text = incomingGstin;
    if (incomingEmail.isNotEmpty) _emailController.text = incomingEmail;
    if (incomingMobile.isNotEmpty) _mobileController.text = incomingMobile;
    if (incomingAddress.isNotEmpty) _addressController.text = incomingAddress;
    if (incomingGst.isNotEmpty) _gstController.text = incomingGst;

    if (incomingStateRaw.isNotEmpty)
      _customerState = incomingStateRaw.toLowerCase();

    if (incomingPerson.isNotEmpty) _contactPersonSnapshot = incomingPerson;
    if (incomingEmail.isNotEmpty) _contactEmailSnapshot = incomingEmail;
    if (incomingMobile.isNotEmpty) _contactMobileSnapshot = incomingMobile;

    if (incomingAddress.isNotEmpty)
      _customerPrimaryAddressSnapshot = incomingAddress;
    if (incomingCity.isNotEmpty) _customerPrimaryCitySnapshot = incomingCity;
    if (incomingStateRaw.isNotEmpty)
      _customerPrimaryStateSnapshot = incomingStateRaw;
    if (incomingPincode.isNotEmpty)
      _customerPrimaryPincodeSnapshot = incomingPincode;

    final seededAddressId =
        (seed['addressId'] ?? seed['customerAddressId'] ?? '')
            .toString()
            .trim();
    if (seededAddressId.isNotEmpty) {
      _selectedAddressId = seededAddressId;
    }
    final seededContactId =
        (seed['contactId'] ?? seed['customerContactId'] ?? '')
            .toString()
            .trim();
    if (seededContactId.isNotEmpty) {
      _selectedContactId = seededContactId;
    }

    final seededCustomerId = (seed['customerId'] ?? '').toString().trim();
    if (seededCustomerId.isNotEmpty) {
      _selectedCustomerId = seededCustomerId;
      await _loadCustomerFromFirestore(seededCustomerId, restoreMode: true);
      if (_selectedContactId != null && _selectedContactId!.isNotEmpty) {
        await _loadContactData(
          seededCustomerId,
          _selectedContactId!,
          restoreMode: true,
        );
        developer.log(
          'Inquiry Contact Restored: $_selectedContactId',
          name: 'QuotationScreen',
        );
      }
    } else {
      _checkInterState();
    }

    final subject = (seed['subject'] ?? seed['inquirySubject'] ?? '')
        .toString()
        .trim();
    if (subject.isNotEmpty) _subjectController.text = subject;

    final notes =
        (seed['notes'] ?? seed['description'] ?? seed['inquiryReference'] ?? '')
            .toString()
            .trim();
    final loc = (seed['location'] ?? seed['customerPrimaryCity'] ?? '')
        .toString()
        .trim();

    List<String> combinedNotes = [];
    if (loc.isNotEmpty) combinedNotes.add("Location: $loc");
    if (notes.isNotEmpty) combinedNotes.add("Notes: $notes");

    if (combinedNotes.isNotEmpty) {
      _inquiryRefNoteController.text = combinedNotes.join('\n');
    }

    final source = (seed['source'] ?? '').toString().trim();
    if (source.isNotEmpty && _inquirySources.contains(source)) {
      _selectedInquirySource = source;
    }

    final rawItems = seed['items'] ?? seed['products'];
    if (rawItems != null && rawItems is List && rawItems.isNotEmpty) {
      List<Future<QuotationLineItem?>> tasks = [];
      for (var rawItem in rawItems) {
        if (rawItem == null || rawItem is! Map) continue;
        tasks.add(
          _hydrateProductItem(Map<String, dynamic>.from(rawItem as Map)),
        );
      }

      final results = await Future.wait(tasks);
      _items = results.whereType<QuotationLineItem>().toList();
      _recalculateTaxes();
    }

    developer.log('Inquiry Applied', name: 'QuotationScreen');
  }

  Future<void> _fetchCustomerInsights(String custId) async {
    if (_companyId == null) return;
    try {
      final snaps = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('quotations')
          .where('customerId', isEqualTo: custId)
          .orderBy('createdAt', descending: true)
          .get();

      double totalVal = 0;
      double lastQuote = 0;
      if (snaps.docs.isNotEmpty) {
        lastQuote =
            double.tryParse(
              snaps.docs.first.data()['finalTotal']?.toString() ??
                  snaps.docs.first.data()['grandTotal']?.toString() ??
                  '0',
            ) ??
            0.0;
        for (var d in snaps.docs) {
          totalVal +=
              double.tryParse(
                d.data()['finalTotal']?.toString() ??
                    d.data()['grandTotal']?.toString() ??
                    '0',
              ) ??
              0.0;
        }
      }

      if (mounted) {
        setState(() {
          _customerInsights = {
            'count': snaps.docs.length,
            'totalValue': totalVal,
            'lastQuoteAmount': lastQuote,
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserSettings() async {
    if (widget.existingQuotation == null && _dynamicTerms.isEmpty) {
      _applyProfessionalDefaultTerms();
    }

    if (_currentUserUid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('quotationSettings')
          .doc(_currentUserUid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _packingChargesExtra =
            data['packingChargesExtra'] as bool? ?? _packingChargesExtra;

        if (widget.existingQuotation == null) {
          if (data['dynamicTerms'] != null &&
              data['dynamicTerms'] is List &&
              (data['dynamicTerms'] as List).isNotEmpty) {
            for (var t in _dynamicTerms) {
              t.dispose();
            }
            _dynamicTerms = (data['dynamicTerms'] as List)
                .map(
                  (e) => TermRow(
                    title: e['title']?.toString() ?? '',
                    value: e['value']?.toString() ?? '',
                  ),
                )
                .toList();
          }
        }
      }
    } catch (e) {}
  }

  void _checkInterState() {
    if (_companyState.isEmpty || _customerState.isEmpty) {
      _isInterState = false;
    } else {
      _isInterState =
          _companyState.toLowerCase().trim() !=
          _customerState.toLowerCase().trim();
    }
    _recalculateTaxes();
  }

  void _recalculateTaxes() {
    for (var item in _items) {
      final extras = _itemExtras[item.id] ?? {};
      double totalGst = item.cgstPercent + item.sgstPercent + item.igstPercent;

      if (totalGst == 0 && extras['baseGst'] != null) {
        totalGst = double.tryParse(extras['baseGst'].toString()) ?? 0.0;
      }

      if (totalGst > 0) {
        if (_isInterState) {
          item.igstPercent = totalGst;
          item.cgstPercent = 0.0;
          item.sgstPercent = 0.0;
        } else {
          item.cgstPercent = totalGst / 2;
          item.sgstPercent = totalGst / 2;
          item.igstPercent = 0.0;
        }
      }
    }
    _calculateTotals();
  }

  void _calculateTotals() {
    _cachedSubtotal = 0.0;
    _cachedItemDiscount = 0.0;
    _cachedCgst = 0.0;
    _cachedSgst = 0.0;
    _cachedIgst = 0.0;

    for (var item in _items) {
      final extras = _itemExtras[item.id] ?? {};
      final isScopeItem = extras['isScopeItem'] == true;
      final isIncluded = extras['isIncluded'] != false;
      final pricingMode = extras['pricingMode'] ?? 'Included';

      if (isScopeItem && !isIncluded) continue;
      if (isScopeItem && pricingMode == 'Included') continue;

      _cachedSubtotal += item.subtotal;
      _cachedItemDiscount += item.discountAmount;
      _cachedCgst += item.cgstAmount;
      _cachedSgst += item.sgstAmount;
      _cachedIgst += item.igstAmount;
    }

    _cachedGlobalDiscountAmount =
        (_cachedSubtotal - _cachedItemDiscount) *
        (_globalDiscountPercent / 100);
    _cachedTaxableAmount =
        _cachedSubtotal - _cachedItemDiscount - _cachedGlobalDiscountAmount;
    _cachedGrandTotal =
        _cachedTaxableAmount + _cachedCgst + _cachedSgst + _cachedIgst;

    _cachedFinalTotal = _cachedGrandTotal.roundToDouble();
    _cachedRoundOff = _cachedFinalTotal - _cachedGrandTotal;

    if (mounted) setState(() {});
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String _extractLegacyTerm(String searchTitle) {
    TermRow? term;
    for (var t in _dynamicTerms) {
      if (t.titleCtrl.text.toLowerCase().contains(searchTitle.toLowerCase())) {
        term = t;
        break;
      }
    }
    return term?.valueCtrl.text.trim() ?? '';
  }

  String _getFinancialYearFromDate(DateTime date) {
    final localDate = date.toLocal();
    final startYear = localDate.month >= 4
        ? localDate.year
        : localDate.year - 1;
    return '$startYear-${(startYear + 1).toString().substring(2)}';
  }

  String _currentFinancialYearShort() {
    return _getFinancialYearFromDate(_quoteDate);
  }

  bool _isAutoQuoteNumberPlaceholder(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized.contains('auto-generated') ||
        normalized.contains('auto generated') ||
        normalized.contains('auto');
  }

  int? _extractQuoteSequence(String quoteNumber) {
    final match = RegExp(
      r'^[A-Z]+/(\d+)/\d{4}-\d{2}$',
    ).firstMatch(quoteNumber.trim().toUpperCase());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _normalizeManualQuoteNumber(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _quoteNumberRegistryId(String quoteNumber) {
    return quoteNumber
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }

  Future<void> _ensureExistingQuoteNumberIsUnique(String quoteNumber) async {
    final snap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('quotations')
        .where('quoteNumber', isEqualTo: quoteNumber)
        .limit(2)
        .get();

    final duplicateExists = snap.docs.any(
      (doc) => doc.id != widget.quotationId,
    );
    if (duplicateExists) {
      throw Exception(
        'Quotation number $quoteNumber already exists. Use a unique quotation number.',
      );
    }
  }

  Future<void> _saveQuotation() async {
    if (_isReadOnly) {
      _showSnack('Document is locked for editing.', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _setError('Please fill required fields.');
      return;
    }

    final qDate = DateTime(_quoteDate.year, _quoteDate.month, _quoteDate.day);
    if (_hasLinkedInquiry) {
      final iqDate = DateTime(
        _inquiryDate.year,
        _inquiryDate.month,
        _inquiryDate.day,
      );
      if (qDate.isBefore(iqDate)) {
        _setError(
          'Quotation date (${DateFormat('dd/MM/yyyy').format(qDate)}) cannot be earlier than the Inquiry date (${DateFormat('dd/MM/yyyy').format(iqDate)}).',
        );
        return;
      }
    }

    if (_items.isEmpty) {
      _setError('Add at least one item.');
      return;
    }
    if (_companyId == null || _currentUserUid == null) {
      _setError('System Error: Context missing.');
      return;
    }

    developer.log('Quotation Save Started', name: 'QuotationScreen');
    setState(() => _isLoading = true);

    try {
      final bool isUpdate = widget.quotationId != null;

      // Editing an existing quotation must update the same Firestore document.
      // Revision should be created only from the explicit "Create Revision" action
      // on quotation list, not automatically on every save.
      final bool isRevision = false;

      final quoteRef = (isUpdate && !isRevision)
          ? FirebaseFirestore.instance
                .collection('companies')
                .doc(_companyId)
                .collection('quotations')
                .doc(widget.quotationId)
          : FirebaseFirestore.instance
                .collection('companies')
                .doc(_companyId)
                .collection('quotations')
                .doc();

      final financialYear = _getFinancialYearFromDate(_quoteDate);

      String manualSequenceStr = _quotationSequenceController.text.trim();
      int? manualSequence;

      if (manualSequenceStr.isNotEmpty &&
          !_isAutoQuoteNumberPlaceholder(manualSequenceStr)) {
        manualSequence = int.tryParse(manualSequenceStr);
        if (manualSequence == null) {
          _setError(
            'Invalid sequence number format. Please enter a valid number.',
          );
          setState(() => _isLoading = false);
          return;
        }
        final testNumber =
            '$_quotationPrefix/${manualSequence.toString().padLeft(3, '0')}/$financialYear';
        await _ensureExistingQuoteNumberIsUnique(testNumber);
      }

      final activityLog = {
        'type': isRevision
            ? 'Revision Created'
            : (isUpdate ? 'Updated' : 'Created'),
        'status': _quotationStatus,
        'timestamp': Timestamp.now(),
        'byUid': _currentUserUid,
        'byName': _currentUserName,
        'note': isRevision
            ? 'Revision created from ${widget.quotationId}'
            : 'Quotation saved.',
      };

      final mappedTerms = _dynamicTerms
          .map(
            (e) => {
              'title': e.titleCtrl.text.trim(),
              'value': e.valueCtrl.text.trim(),
            },
          )
          .toList();

      final mappedItems = _items.map((e) {
        final map = e.toMap();
        final extras = _itemExtras[e.id] ?? {};
        map.addAll(extras);
        return map;
      }).toList();

      String? finalAddressId = _selectedAddressId;
      if ((finalAddressId == null || finalAddressId.isEmpty) &&
          _linkedInquiryId != null &&
          _linkedInquiryId!.isNotEmpty) {
        finalAddressId = 'INQUIRY_ADDRESS';
      }

      String? finalContactId = _selectedContactId;
      if ((finalContactId == null || finalContactId.isEmpty) &&
          _linkedInquiryId != null &&
          _linkedInquiryId!.isNotEmpty) {
        finalContactId = 'INQUIRY_CONTACT';
      }

      final effectiveAddressSnapshot =
          _selectedAddressData ??
          {
            'address': _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : _customerPrimaryAddressSnapshot,
            'city': _customerPrimaryCitySnapshot,
            'state': _customerPrimaryStateSnapshot,
            'pincode': _customerPrimaryPincodeSnapshot,
          };

      final effectiveContactSnapshot =
          _selectedContactData ??
          {
            'name': _contactPersonController.text.trim().isNotEmpty
                ? _contactPersonController.text.trim()
                : _contactPersonSnapshot,
            'email': _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : _contactEmailSnapshot,
            'mobile': _mobileController.text.trim().isNotEmpty
                ? _mobileController.text.trim()
                : _contactMobileSnapshot,
          };

      final payload = {
        'id': quoteRef.id,
        'companyId': _companyId,
        'quotationType': _quotationType,
        'subject': _subjectController.text.trim(),
        'quoteDate': Timestamp.fromDate(_quoteDate),
        'status': _quotationStatus,
        'approvalStatus': _approvalStatus,
        'paymentStatus': _paymentStatus,
        'customerId': _selectedCustomerId,
        'addressId': finalAddressId,
        'addressSnapshot': effectiveAddressSnapshot,
        'contactId': finalContactId,
        'contactSnapshot': effectiveContactSnapshot,
        'clientName': _clientNameController.text.trim(),
        'clientAddress': _addressController.text.trim(),
        'addressLine': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : _customerPrimaryAddressSnapshot,
        'city': _customerPrimaryCitySnapshot,
        'state': _customerPrimaryStateSnapshot,
        'pincode': _customerPrimaryPincodeSnapshot,
        'clientEmail': _emailController.text.trim(),
        'clientMobile': _mobileController.text.trim(),
        'contactPerson': _contactPersonController.text.trim().isNotEmpty
            ? _contactPersonController.text.trim()
            : _contactPersonSnapshot,
        'customerGstin': _gstController.text.trim(),
        'customerGSTIN': _gstController.text.trim(),
        'customerGstNo': _gstController.text.trim(),
        'contactEmail': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : _contactEmailSnapshot,
        'contactMobile': _mobileController.text.trim().isNotEmpty
            ? _mobileController.text.trim()
            : _contactMobileSnapshot,
        'gstNo': _gstController.text.trim(),
        'isInterState': _isInterState,
        'customerState': _customerState,
        'inquiryId': _hasLinkedInquiry ? (_linkedInquiryId ?? '') : '',
        'inquiryNumber': _hasLinkedInquiry ? (_linkedInquiryNumber ?? '') : '',
        'inquiryRefNo': _hasLinkedInquiry ? (_linkedInquiryNumber ?? '') : '',
        'inquirySource': _hasLinkedInquiry ? _selectedInquirySource : '',
        'inquiryDate': _hasLinkedInquiry
            ? Timestamp.fromDate(_inquiryDate)
            : null,
        'inquiryReference': _inquiryRefNoteController.text.trim(),
        'nextFollowUpDate': _nextFollowUpDate != null
            ? Timestamp.fromDate(_nextFollowUpDate!)
            : null,
        'followUpNotes': _followUpNotesController.text.trim(),
        'totalSubtotal': _cachedSubtotal,
        'totalItemDiscount': _cachedItemDiscount,
        'globalDiscountPercent': _globalDiscountPercent,
        'globalDiscountAmount': _cachedGlobalDiscountAmount,
        'totalTaxableAmount': _cachedTaxableAmount,
        'totalCgst': _cachedCgst,
        'totalSgst': _cachedSgst,
        'totalIgst': _cachedIgst,
        'grandTotal': _cachedGrandTotal,
        'roundOff': _cachedRoundOff,
        'finalTotal': _cachedFinalTotal,
        'deliveryTime': _extractLegacyTerm('delivery'),
        'validity': _extractLegacyTerm('validity'),
        'priceBasis': _extractLegacyTerm('price basis'),
        'paymentTerms': _extractLegacyTerm('payment'),
        'warranty': _extractLegacyTerm('warranty'),
        'freight': _extractLegacyTerm('freight'),
        'installation': _extractLegacyTerm('installation'),
        'dynamicTerms': mappedTerms,
        'packingChargesExtra': _packingChargesExtra,
        'signatureName': _signNameController.text.trim(),
        'signatureDesignation': _signDesignationController.text.trim(),
        'signaturePhone': _signPhoneController.text.trim(),
        'items': mappedItems,
        'activities': FieldValue.arrayUnion([activityLog]),
        'isActive': true,
        'isDeleted': false,
        'lastEditedBy': _currentUserUid,
        'lastEditedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUserUid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isUpdate || isRevision) {
        payload['createdBy'] = _currentUserUid!;
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['version'] = isRevision ? _currentVersion + 1 : 1;
        payload['isLatest'] = true;
        payload['parentQuotationId'] = isRevision ? widget.quotationId : null;
      }

      await FirebaseFirestore.instance
          .runTransaction((tx) async {
            int? sequenceToSync;
            final counterRef = FirebaseFirestore.instance
                .collection('companies')
                .doc(_companyId)
                .collection('counters')
                .doc('quotation_counter_$financialYear');

            final counterDoc = await tx.get(counterRef);
            final currentSequence =
                ((counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0);

            String safeQuoteNumber = '';

            if (manualSequence == null) {
              final nextSequence = currentSequence + 1;
              String formattedSequence = nextSequence.toString().padLeft(
                3,
                '0',
              );
              safeQuoteNumber =
                  '$_quotationPrefix/$formattedSequence/$financialYear';
              sequenceToSync = nextSequence;
            } else {
              String paddedManual = manualSequence.toString().padLeft(3, '0');
              safeQuoteNumber =
                  '$_quotationPrefix/$paddedManual/$financialYear';
              if (manualSequence > currentSequence) {
                sequenceToSync = manualSequence;
              }
            }

            final numberRef = FirebaseFirestore.instance
                .collection('companies')
                .doc(_companyId)
                .collection('quotation_numbers')
                .doc(_quoteNumberRegistryId(safeQuoteNumber));

            final numberDoc = await tx.get(numberRef);
            final reservedFor = numberDoc.data()?['quotationId']?.toString();
            final allowedExistingReservations = {
              quoteRef.id,
              if (widget.quotationId != null) widget.quotationId!,
            };

            if (numberDoc.exists &&
                reservedFor != null &&
                reservedFor.isNotEmpty &&
                !allowedExistingReservations.contains(reservedFor)) {
              throw Exception(
                'Quotation number $safeQuoteNumber is already reserved.',
              );
            }

            final payloadWithNumber = {
              ...payload,
              'quoteNumber': safeQuoteNumber,
              'financialYear': safeQuoteNumber.split('/').last,
            };

            tx.set(numberRef, {
              'quoteNumber': safeQuoteNumber,
              'quotationId': quoteRef.id,
              'companyId': _companyId,
              'sequence': _extractQuoteSequence(safeQuoteNumber),
              'financialYear': safeQuoteNumber.split('/').last,
              'prefix': safeQuoteNumber.split('/').first,
              'updatedAt': FieldValue.serverTimestamp(),
              if (!numberDoc.exists) 'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (sequenceToSync != null) {
              tx.set(counterRef, {
                'sequence': sequenceToSync,
                'prefix': _quotationPrefix,
                'financialYear': financialYear,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }

            if (isRevision) {
              final oldRef = FirebaseFirestore.instance
                  .collection('companies')
                  .doc(_companyId)
                  .collection('quotations')
                  .doc(widget.quotationId);
              tx.set(oldRef, {
                'isLatest': false,
                'updatedAt': FieldValue.serverTimestamp(),
                'updatedBy': _currentUserUid,
              }, SetOptions(merge: true));
            }

            tx.set(quoteRef, payloadWithNumber, SetOptions(merge: true));

            if (_linkedInquiryId != null &&
                _linkedInquiryId!.trim().isNotEmpty) {
              final inqRef = FirebaseFirestore.instance
                  .collection('companies')
                  .doc(_companyId)
                  .collection('inquiries')
                  .doc(_linkedInquiryId);
              tx.set(inqRef, {
                'status': 'Quoted',
                'quotationId': quoteRef.id,
                'updatedAt': FieldValue.serverTimestamp(),
                'updatedBy': _currentUserUid,
              }, SetOptions(merge: true));
            }
          })
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              'Network timeout: Failed to save quotation safely.',
            ),
          );

      if (!_isReadOnly) {
        await FirebaseFirestore.instance
            .collection('quotationSettings')
            .doc(_currentUserUid)
            .set({
              'dynamicTerms': mappedTerms,
              'packingChargesExtra': _packingChargesExtra,
            }, SetOptions(merge: true));
      }

      developer.log('Quotation Save Success', name: 'QuotationScreen');
      if (!mounted) return;
      _showSnack(
        isRevision
            ? 'Revision Created Successfully!'
            : (isUpdate ? 'Quotation Updated!' : 'Quotation Created!'),
      );
      Navigator.pop(context, true);
    } catch (e) {
      developer.log(
        'Quotation Save Failed: $e',
        name: 'QuotationScreen',
        error: e,
      );
      _setError('Save Failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _convertToInvoice() async {
    if (!_isAdminOrManager) {
      _showSnack(
        'Only managers or admins can convert to invoice directly.',
        isError: true,
      );
      return;
    }

    developer.log('Convert To SO', name: 'QuotationScreen');
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      final invoiceRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('tax_invoices')
          .doc();
      final quoteRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('quotations')
          .doc(widget.quotationId);

      String currentNo = _quotationSequenceController.text.trim();
      if (_isAutoQuoteNumberPlaceholder(currentNo)) {
        currentNo = 'Auto';
      } else {
        currentNo =
            '$_quotationPrefix/$currentNo/${_getFinancialYearFromDate(_quoteDate)}';
      }

      final invoicePayload = {
        'id': invoiceRef.id,
        'companyId': _companyId,
        'referenceQuotationId': widget.quotationId,
        'referenceQuotationNo': currentNo,
        'customerGstin': _gstController.text.trim(),
        'customerGSTIN': _gstController.text.trim(),
        'customerGstNo': _gstController.text.trim(),
        'customerId': _selectedCustomerId,
        'clientName': _clientNameController.text.trim(),
        'items': _items.map((e) {
          final map = e.toMap();
          final extras = _itemExtras[e.id] ?? {};
          map.addAll(extras);
          return map;
        }).toList(),
        'totalSubtotal': _cachedSubtotal,
        'totalTaxableAmount': _cachedTaxableAmount,
        'totalCgst': _cachedCgst,
        'totalSgst': _cachedSgst,
        'totalIgst': _cachedIgst,
        'grandTotal': _cachedGrandTotal,
        'roundOff': _cachedRoundOff,
        'finalTotal': _cachedFinalTotal,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUserUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUserUid,
        'isActive': true,
        'isDeleted': false,
      };

      batch.set(invoiceRef, invoicePayload, SetOptions(merge: true));

      batch.set(quoteRef, {
        'status': 'Converted',
        'convertedToInvoiceId': invoiceRef.id,
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUserUid,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'Converted',
            'status': 'Converted',
            'timestamp': Timestamp.now(),
            'byUid': _currentUserUid,
            'byName': _currentUserName,
            'note': 'Converted to Invoice',
          },
        ]),
      }, SetOptions(merge: true));

      await batch.commit().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Network timeout: Failed to convert.'),
      );

      if (!mounted) return;
      _showSnack('Successfully converted to Sales Order!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack('Error converting: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildPreviewData() {
    String previewQuoteNo = _quotationSequenceController.text.trim();
    final fy = _getFinancialYearFromDate(_quoteDate);
    if (_isAutoQuoteNumberPlaceholder(previewQuoteNo)) {
      previewQuoteNo = 'PREVIEW MODE';
    } else {
      int? parsedSeq = int.tryParse(previewQuoteNo);
      if (parsedSeq != null) {
        previewQuoteNo = parsedSeq.toString().padLeft(3, '0');
      } else if (previewQuoteNo.length < 3) {
        previewQuoteNo = previewQuoteNo.padLeft(3, '0');
      }
      previewQuoteNo = '$_quotationPrefix/$previewQuoteNo/$fy';
    }

    return {
      'quoteNumber': previewQuoteNo,
      'companyId': _companyId,
      'quotationType': _quotationType,
      'quoteDateStr':
          '${_quoteDate.day.toString().padLeft(2, '0')}/${_quoteDate.month.toString().padLeft(2, '0')}/${_quoteDate.year}',
      'revisionNo': _currentVersion.toString(),
      'inquiryRefNo': _linkedInquiryNumber ?? '',
      'subject': _subjectController.text.trim(),
      'clientName': _clientNameController.text.trim(),
      'clientAddress': _addressController.text.trim(),
      'clientEmail': _emailController.text.trim(),
      'clientMobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'contactDepartment': _contactDepartmentController.text.trim(),
      'contactDesignation': _contactDesignationController.text.trim(),
      'terms': _dynamicTerms
          .map(
            (term) => {
              'title': term.titleCtrl.text.trim(),
              'value': term.valueCtrl.text.trim(),
            },
          )
          .where(
            (term) =>
                (term['title'] ?? '').toString().trim().isNotEmpty ||
                (term['value'] ?? '').toString().trim().isNotEmpty,
          )
          .toList(),
      'dynamicTerms': _dynamicTerms
          .map(
            (term) => {
              'title': term.titleCtrl.text.trim(),
              'value': term.valueCtrl.text.trim(),
            },
          )
          .where(
            (term) =>
                (term['title'] ?? '').toString().trim().isNotEmpty ||
                (term['value'] ?? '').toString().trim().isNotEmpty,
          )
          .toList(),
      'customerGstin': _gstController.text.trim(),
      'customerGSTIN': _gstController.text.trim(),
      'customerGstNo': _gstController.text.trim(),
      'gstNo': _gstController.text.trim(),
      'customerState': _customerPrimaryStateSnapshot.isNotEmpty
          ? _customerPrimaryStateSnapshot
          : _customerState,
      'isInterState': _isInterState,
      'totalSubtotal': _cachedSubtotal,
      'totalItemDiscount': _cachedItemDiscount,
      'totalTaxableAmount': _cachedTaxableAmount,
      'totalCgst': _cachedCgst,
      'totalSgst': _cachedSgst,
      'totalIgst': _cachedIgst,
      'grandTotal': _cachedGrandTotal,
      'roundOff': _cachedRoundOff,
      'finalTotal': _cachedFinalTotal,
      'dynamicTerms': _dynamicTerms
          .map(
            (e) => {
              'title': e.titleCtrl.text.trim(),
              'value': e.valueCtrl.text.trim(),
            },
          )
          .toList(),
      'packingChargesExtra': _packingChargesExtra,
      'companyName': _companyName,
      'companyAddress': _companyAddress,
      'companyPhone': _companyPhone,
      'companyEmail': _companyEmail,
      'companyWebsite': _companyWebsite,
      'companyGst': _companyGst,
      'companyCin': _companyCin,
      'companyPan': _companyPan,
      'companyBankDetails': _companyBankDetails,
      'companyLogoUrl': _companyLogoUrl,
      'signatureName': _signNameController.text.trim(),
      'signatureDesignation': _signDesignationController.text.trim(),
      'signaturePhone': _signPhoneController.text.trim(),
    };
  }

  void _onPreviewPressed() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add items before previewing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Map<String, dynamic> safeData = Map<String, dynamic>.from(
      _buildPreviewData(),
    );

    final List<QuotationLineItem> safeItems = _items
        .where((e) {
          final extras = _itemExtras[e.id] ?? {};
          final isScopeItem = extras['isScopeItem'] == true;
          final isIncluded = extras['isIncluded'] != false;
          if (isScopeItem && !isIncluded) return false;
          return true;
        })
        .map(
          (e) => QuotationLineItem.fromMap(
            Map<String, dynamic>.from(
              e.toMap()..addAll(_itemExtras[e.id] ?? {}),
            ),
          ),
        )
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QuotationPreviewScreen(quotation: safeData, items: safeItems),
      ),
    );
  }

  void _showSnack(String message, {bool isInfo = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : (isInfo ? Colors.blue : Colors.green),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.02),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  InputDecoration _dec(
    String label, {
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _isReadOnly ? Colors.grey.shade100 : Colors.grey.shade50,
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
    );
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedQuotationNumber() {
    final fy = _getFinancialYearFromDate(_quoteDate);
    return TextFormField(
      controller: _quotationSequenceController,
      keyboardType: TextInputType.text,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
      ],
      textAlign: TextAlign.center,
      readOnly: _isReadOnly,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        fontSize: 15,
        color: Color(0xFF0F172A),
      ),
      decoration: _dec('Quotation No.', hint: 'Auto').copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        counterText: "",
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 70,
          minHeight: 54,
        ),
        prefixIcon: Container(
          width: 70,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Text(
            _quotationPrefix,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 80,
          minHeight: 54,
        ),
        suffixIcon: Container(
          width: 80,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Text(
            fy,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Query<Map<String, dynamic>> _customerAutocompleteQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('customers');

    if (!_isAdminOrManager && _currentUserUid != null) {
      query = query.where('createdBy', isEqualTo: _currentUserUid);
    }

    return query;
  }

  bool _isSelectableCustomer(Map<String, dynamic> data) {
    if (data['isActive'] == false) return false;
    if (data['isDeleted'] == true) return false;
    if (data['archived'] == true) return false;
    if (data['mergedInto'] != null) return false;

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'deleted' || status == 'inactive') return false;

    return true;
  }

  String _customerDisplayName(Map<String, dynamic> customer) {
    return (customer['companyName'] ??
            customer['customerName'] ??
            customer['name'] ??
            customer['clientName'] ??
            '')
        .toString()
        .trim();
  }

  String _customerSubtitle(Map<String, dynamic> customer) {
    final contact = (customer['contactPerson'] ?? customer['contactName'] ?? '')
        .toString()
        .trim();
    final mobile = (customer['mobile'] ?? customer['phone'] ?? '')
        .toString()
        .trim();
    final gst =
        (customer['customerGstin'] ??
                customer['customerGSTIN'] ??
                customer['customerGstNo'] ??
                customer['gstin'] ??
                customer['gstNo'] ??
                '')
            .toString()
            .trim();

    return [contact, mobile, gst].where((e) => e.isNotEmpty).join(' | ');
  }

  void _clearSelectedCustomerIfTyping(String value) {
    if (_isRestoring || _isReadOnly || _hasLinkedInquiry) return;

    final typed = value.trim();
    if (_selectedCustomerId == null || typed == _selectedCustomerLabel) return;

    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerLabel = '';
      _selectedAddressId = null;
      _selectedAddressData = null;
      _customerAddresses = [];
      _selectedContactId = null;
      _selectedContactData = null;
      _customerInsights = null;
      _customerPrimaryAddressSnapshot = '';
      _customerPrimaryCitySnapshot = '';
      _customerPrimaryStateSnapshot = '';
      _customerPrimaryPincodeSnapshot = '';
      _customerState = '';
      _addressController.clear();
      _updateContactSnapshots(null);
      _gstController.clear();
      _isInterState = false;
    });
  }

  Widget _buildCustomerNameAutocomplete({
    String? Function(String?)? validator,
  }) {
    if (_companyId == null || _companyId!.isEmpty) {
      return _buildItemTextField(
        _clientNameController,
        'Customer Name *',
        validator: validator,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _customerAutocompleteQuery().snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return RawAutocomplete<Map<String, dynamic>>(
          textEditingController: _clientNameController,
          focusNode: _customerNameFocusNode,
          displayStringForOption: _customerDisplayName,
          optionsBuilder: (TextEditingValue value) {
            final text = value.text.trim().toLowerCase();
            if (text.isEmpty)
              return const Iterable<Map<String, dynamic>>.empty();

            final matches = docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .where(_isSelectableCustomer)
                .where((customer) {
                  final searchText = [
                    customer['companyName'],
                    customer['customerName'],
                    customer['name'],
                    customer['clientName'],
                    customer['contactPerson'],
                    customer['contactName'],
                    customer['mobile'],
                    customer['phone'],
                  ].where((e) => e != null).join(' ').toLowerCase();

                  return searchText.contains(text);
                })
                .take(20);

            return matches;
          },
          onSelected: (customer) {
            _selectedCustomerLabel = _customerDisplayName(customer);
            _applyCustomer(customer);
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  validator: validator,
                  readOnly: _isReadOnly || _hasLinkedInquiry,
                  onChanged: _clearSelectedCustomerIfTyping,
                  decoration: _dec(
                    'Customer Name *',
                    hint: 'Type customer or company name',
                    prefixIcon: const Icon(Icons.search),
                  ),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            final optionList = options.toList();

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    maxWidth: 620,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: optionList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = optionList[index];
                      final title = _customerDisplayName(customer);
                      final subtitle = _customerSubtitle(customer);

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.business_outlined),
                        title: Text(
                          title.isEmpty ? 'Unnamed Customer' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: subtitle.isEmpty
                            ? null
                            : Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => onSelected(customer),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _selectCustomerDialog() async {
    final searchController = TextEditingController();
    String searchText = '';

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('customers');

    if (!_isAdminOrManager && _currentUserUid != null) {
      query = query.where('createdBy', isEqualTo: _currentUserUid);
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Select Customer',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by company, person, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => setDialogState(
                    () => searchText = value.trim().toLowerCase(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      final filtered = docs.where((doc) {
                        final data = doc.data();
                        if (data['isActive'] == false) return false;
                        if (data['isDeleted'] == true) return false;
                        if (data['archived'] == true) return false;
                        if (data['mergedInto'] != null) return false;
                        final status = (data['status'] ?? '')
                            .toString()
                            .toLowerCase();
                        if (status == 'deleted' || status == 'inactive')
                          return false;

                        final searchStr =
                            '${data['companyName']} ${data['contactPerson']} ${data['mobile']}'
                                .toLowerCase();
                        return searchText.isEmpty ||
                            searchStr.contains(searchText);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('No customers found.'));
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = filtered[index].data();
                          return ListTile(
                            title: Text(
                              data['companyName'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${data['contactPerson'] ?? ''} | ${data['mobile'] ?? ''}',
                            ),
                            onTap: () => Navigator.pop(context, {
                              'id': filtered[index].id,
                              ...data,
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyCustomer(Map<String, dynamic> customer) {
    if (customer['id'] != null) {
      _isUserChangingAddress = false;
      _loadCustomerFromFirestore(customer['id']);
    }
  }

  Future<Map<String, dynamic>?> _selectProductDialog() async {
    final searchController = TextEditingController();
    String searchText = '';
    String _productFilter = 'All';

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products')
        .where('isActive', isEqualTo: true);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Select Product from Inventory',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 700,
            height: 600,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by product name, SKU, or Code...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => setDialogState(
                    () => searchText = value.trim().toLowerCase(),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                              'All',
                              'Machines',
                              'Accessories',
                              'Spares',
                              'Consumables',
                              'Raw Materials',
                            ]
                            .map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f),
                                  selected: _productFilter == f,
                                  onSelected: (val) {
                                    if (val)
                                      setDialogState(() => _productFilter = f);
                                  },
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      final filtered = docs.where((doc) {
                        final data = doc.data();
                        final searchStr =
                            '${data['name']} ${data['sku']} ${data['itemCode']} ${data['description']}'
                                .toLowerCase();
                        if (searchText.isNotEmpty &&
                            !searchStr.contains(searchText))
                          return false;

                        if (_productFilter != 'All') {
                          String pNature =
                              (data['productNatureLower'] ??
                                      data['productNature'] ??
                                      '')
                                  .toString()
                                  .toLowerCase();
                          String filterLower = _productFilter.toLowerCase();
                          if (filterLower == 'machines')
                            filterLower = 'machine';
                          else if (filterLower == 'accessories')
                            filterLower = 'accessory';
                          else if (filterLower == 'spares')
                            filterLower = 'spare';
                          else if (filterLower == 'consumables')
                            filterLower = 'consumable';
                          else if (filterLower == 'raw materials')
                            filterLower = 'raw material';

                          if (pNature != filterLower &&
                              pNature != filterLower.replaceAll(' ', '_'))
                            return false;
                        }
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('No products found matching criteria.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = filtered[index].data();
                          final stock =
                              double.tryParse(
                                data['stockOnHand']?.toString() ??
                                    data['availableStock']?.toString() ??
                                    data['qty']?.toString() ??
                                    '0',
                              ) ??
                              0;

                          final nature = (data['productNature'] ?? 'General')
                              .toString();
                          final itemCode = (data['itemCode'] ?? '').toString();
                          final sku = (data['sku'] ?? '').toString();
                          final brand = (data['brand'] ?? data['make'] ?? '')
                              .toString();
                          final model = (data['model'] ?? '').toString();
                          final machineType = (data['machineType'] ?? '')
                              .toString();

                          final sellingPrice =
                              double.tryParse(
                                data['sellingPrice']?.toString() ?? '',
                              ) ??
                              double.tryParse(
                                data['price']?.toString() ?? '',
                              ) ??
                              double.tryParse(
                                data['unitPrice']?.toString() ?? '',
                              ) ??
                              double.tryParse(data['rate']?.toString() ?? '') ??
                              0.0;

                          final gst =
                              data['gstPercentage']?.toString() ??
                              data['tax']?.toString() ??
                              '18';
                          final uom = (data['uom'] ?? 'Nos').toString();
                          final images = data['images'] as List? ?? [];
                          final imageUrl = images.isNotEmpty
                              ? images.first.toString()
                              : (data['imageUrl']?.toString() ?? '');

                          Color natureColor = Colors.grey;
                          if (nature.toLowerCase() == 'machine')
                            natureColor = Colors.purple;
                          else if (nature.toLowerCase() == 'accessory')
                            natureColor = Colors.orange;
                          else if (nature.toLowerCase() == 'spare')
                            natureColor = Colors.blue;
                          else if (nature.toLowerCase() == 'consumable')
                            natureColor = Colors.teal;
                          else if (nature.toLowerCase() == 'raw material')
                            natureColor = Colors.brown;

                          return ListTile(
                            leading: imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      imageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: natureColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: natureColor,
                                      size: 20,
                                    ),
                                  ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: natureColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: natureColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    nature,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: natureColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'SKU: $sku | Code: $itemCode | Brand: $brand',
                                ),
                                if (machineType.isNotEmpty)
                                  Text(
                                    'Machine Type: $machineType',
                                    style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  'Price: ₹$sellingPrice | Tax: $gst% | Stock: $stock $uom',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: stock <= 0
                                ? const Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                  )
                                : const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                            onTap: () {
                              developer.log(
                                'Product Added: ${filtered[index].id}',
                                name: 'QuotationScreen',
                              );
                              _productCache[filtered[index].id] = {
                                'id': filtered[index].id,
                                ...data,
                              };
                              Navigator.pop(context, {
                                'id': filtered[index].id,
                                'stock': stock,
                                ...data,
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showScopeOfSupplyDialog(
    QuotationLineItem machine,
    List included,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scope of Supply Found'),
        content: Text(
          'This machine contains ${included.length} included items in its scope of supply. Add them to quotation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  Future<void> _addIncludedProducts(List included, String parentId) async {
    int parentIdx = _items.indexWhere((i) => i.id == parentId);
    int insertIdx = _items.length;
    if (parentIdx >= 0) {
      int lastChildIdx = parentIdx;
      for (int k = parentIdx + 1; k < _items.length; k++) {
        if (_itemExtras[_items[k].id]?['parentId'] == parentId) {
          lastChildIdx = k;
        } else {
          break;
        }
      }
      insertIdx = lastChildIdx + 1;
    }

    for (var inc in included) {
      String pId = '';
      double incQty = 1.0;
      String incName = '';
      String incUom = 'Nos';
      String incDesc = '';

      if (inc is String) {
        pId = inc;
      } else if (inc is Map) {
        pId = (inc['productId'] ?? inc['id'] ?? '').toString();
        incQty =
            double.tryParse(
              inc['quantity']?.toString() ?? inc['qty']?.toString() ?? '1',
            ) ??
            1.0;
        incName = (inc['name'] ?? inc['productName'] ?? '').toString();
        incUom = (inc['uom'] ?? 'Nos').toString();
        incDesc = (inc['description'] ?? inc['details'] ?? '').toString();
      }

      if (pId.isEmpty && incName.isEmpty) continue;

      Map<String, dynamic> pData = {};
      if (pId.isNotEmpty) {
        final cachedData = await _getProductData(pId);
        if (cachedData != null) {
          pData = cachedData;
        }
      }

      String finalName = (pData['name'] ?? incName).toString();
      if (finalName.isEmpty) continue;

      bool alreadyInScope = _items.any((i) {
        if (_itemExtras[i.id]?['parentId'] != parentId) return false;
        if (pId.isNotEmpty && i.productId == pId) return true;
        if (pId.isEmpty && i.name == finalName) return true;
        return false;
      });

      if (alreadyInScope) continue;

      String finalDesc = (pData['description'] ?? pData['details'] ?? incDesc)
          .toString();
      String finalHsn = (pData['hsnCode'] ?? pData['hsn'] ?? '').toString();
      String finalUom = (pData['uom'] ?? incUom).toString();

      double finalPrice =
          double.tryParse(
            pData['sellingPrice']?.toString() ??
                pData['price']?.toString() ??
                pData['unitPrice']?.toString() ??
                '0',
          ) ??
          0.0;
      double finalGst =
          double.tryParse(
            pData['gstPercentage']?.toString() ??
                pData['tax']?.toString() ??
                '18',
          ) ??
          18.0;

      double cgst = 0, sgst = 0, igst = 0;
      if (finalGst > 0) {
        if (_isInterState)
          igst = finalGst;
        else {
          cgst = finalGst / 2;
          sgst = finalGst / 2;
        }
      }

      double stock =
          double.tryParse(
            pData['stockOnHand']?.toString() ??
                pData['availableStock']?.toString() ??
                pData['qty']?.toString() ??
                '0',
          ) ??
          0.0;

      final newItem = QuotationLineItem(
        id:
            DateTime.now().millisecondsSinceEpoch.toString() +
            '_' +
            (pId.isNotEmpty ? pId : 'custom'),
        productId: pId,
        name: finalName,
        description: finalDesc,
        hsnCode: finalHsn,
        quantity: incQty,
        uom: finalUom,
        unitPrice: finalPrice,
        discountPercent: 0,
        cgstPercent: cgst,
        sgstPercent: sgst,
        igstPercent: igst,
        availableStock: stock,
      );

      setState(() {
        _itemExtras[newItem.id] = {
          'sku': pData['sku'] ?? pData['itemCode'] ?? '',
          'brand': pData['brand'] ?? pData['make'] ?? '',
          'model': pData['model'] ?? '',
          'productNature': pData['productNature'] ?? 'General',
          'machineType': pData['machineType'] ?? '',
          'itemCode': pData['itemCode'] ?? '',
          'catalogs': pData['catalogs'] ?? [],
          'images': pData['images'] ?? [],
          'sellingPrice': finalPrice,
          'baseGst': finalGst,
          'isScopeItem': true,
          'parentId': parentId,
          'isIncluded': true,
          'pricingMode': 'Included',
        };
        _items.insert(insertIdx++, newItem);
      });
    }
    _calculateTotals();
  }

  void _addRecommendedProduct(String pId, Map<String, dynamic> data) {
    if (_items.any((item) => item.productId == pId)) return;

    double pPrice =
        double.tryParse(data['sellingPrice']?.toString() ?? '') ??
        double.tryParse(data['price']?.toString() ?? '') ??
        double.tryParse(data['unitPrice']?.toString() ?? '') ??
        0.0;
    double pGst =
        double.tryParse(
          data['gstPercentage']?.toString() ?? data['tax']?.toString() ?? '18',
        ) ??
        18.0;
    double cgst = 0, sgst = 0, igst = 0;
    if (_isInterState) {
      igst = pGst;
    } else {
      cgst = pGst / 2;
      sgst = pGst / 2;
    }

    double stock =
        double.tryParse(
          data['stockOnHand']?.toString() ?? data['qty']?.toString() ?? '0',
        ) ??
        0.0;

    final newItem = QuotationLineItem(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + pId,
      productId: pId,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      hsnCode: (data['hsnCode'] ?? '').toString(),
      quantity: 1.0,
      uom: (data['uom'] ?? 'Nos').toString(),
      unitPrice: pPrice,
      discountPercent: 0,
      cgstPercent: cgst,
      sgstPercent: sgst,
      igstPercent: igst,
      availableStock: stock,
    );

    setState(() {
      _itemExtras[newItem.id] = {
        'sku': data['sku'] ?? '',
        'brand': data['brand'] ?? data['make'] ?? '',
        'model': data['model'] ?? '',
        'productNature': data['productNature'] ?? 'General',
        'machineType': data['machineType'] ?? '',
        'itemCode': data['itemCode'] ?? '',
        'sellingPrice': data['sellingPrice'] ?? '',
        'baseGst': pGst,
        'productNatureLower': (data['productNature'] ?? '')
            .toString()
            .toLowerCase(),
        'stockOnHand': stock,
        'qty': stock,
      };
      _items.add(newItem);
      _calculateTotals();
    });
  }

  Future<void> _showRecommendedSparesDialog(
    QuotationLineItem machine,
    Map<String, dynamic> extras,
  ) async {
    final compatDocs = await _getCompatibleProducts(machine, extras);
    final filteredDocs = compatDocs
        .where((d) => !_items.any((i) => i.productId == d['id']))
        .toList();
    if (filteredDocs.isEmpty) return;

    List<String> selectedIds = [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Compatible Products Found'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index];
                    final pId = data['id'];
                    final name = data['name'] ?? 'Unknown';
                    final price =
                        data['sellingPrice'] ?? data['unitPrice'] ?? 0;
                    final isChecked = selectedIds.contains(pId);

                    return CheckboxListTile(
                      title: Text(name),
                      subtitle: Text('Price: ₹$price'),
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selectedIds.add(pId);
                          } else {
                            selectedIds.remove(pId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    );

    for (String pId in selectedIds) {
      final d = filteredDocs.firstWhere((x) => x['id'] == pId);
      _addRecommendedProduct(pId, d);
    }
  }

  Future<void> _triggerMachineAutomations(
    QuotationLineItem machine,
    Map<String, dynamic> extras,
  ) async {
    final existingMachines = machine.productId.isNotEmpty
        ? _items
              .where(
                (i) =>
                    i.productId == machine.productId &&
                    i.id != machine.id &&
                    _itemExtras[i.id]?['parentId'] == null,
              )
              .toList()
        : <QuotationLineItem>[];

    if (existingMachines.isNotEmpty) {
      final existingScope = _items
          .where(
            (i) => _itemExtras[i.id]?['parentId'] == existingMachines.first.id,
          )
          .toList();
      if (existingScope.isNotEmpty) {
        bool? reuse = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate Machine Found'),
            content: const Text(
              'This machine is already in the quotation. Do you want to reuse its existing Scope of Supply or create a new default one?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Create New'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reuse Existing'),
              ),
            ],
          ),
        );
        if (reuse == true) {
          int insertIdx = _items.indexOf(machine) + 1;
          for (var child in existingScope) {
            final childExtras = _itemExtras[child.id] ?? {};
            final newId =
                DateTime.now().millisecondsSinceEpoch.toString() +
                '_' +
                (child.productId.isNotEmpty ? child.productId : 'custom');
            final newItem = QuotationLineItem(
              id: newId,
              productId: child.productId,
              name: child.name,
              description: child.description,
              hsnCode: child.hsnCode,
              quantity: child.quantity,
              uom: child.uom,
              unitPrice: child.unitPrice,
              discountPercent: child.discountPercent,
              cgstPercent: child.cgstPercent,
              sgstPercent: child.sgstPercent,
              igstPercent: child.igstPercent,
              availableStock: child.availableStock,
            );
            setState(() {
              _itemExtras[newId] = Map<String, dynamic>.from(childExtras)
                ..addAll({'parentId': machine.id});
              _items.insert(insertIdx++, newItem);
            });
          }
          _calculateTotals();
          await _showRecommendedSparesDialog(machine, extras);
          return;
        }
      }
    }

    List included = extras['includedProducts'] as List? ?? [];
    if (included.isNotEmpty) {
      bool? addScope = await _showScopeOfSupplyDialog(machine, included);
      if (addScope == true) {
        await _addIncludedProducts(included, machine.id);
      }
    }
    await _showRecommendedSparesDialog(machine, extras);
  }

  void _showAddItemModal([QuotationLineItem? itemToEdit, int? index]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: itemToEdit?.description ?? '');
    final hsnCtrl = TextEditingController(text: itemToEdit?.hsnCode ?? '');
    final qtyCtrl = TextEditingController(
      text: itemToEdit?.quantity.toString() ?? '1',
    );
    final priceCtrl = TextEditingController(
      text: itemToEdit?.unitPrice.toString() ?? '',
    );
    final uomCtrl = TextEditingController(text: itemToEdit?.uom ?? 'Nos');
    final discCtrl = TextEditingController(
      text: itemToEdit?.discountPercent.toString() ?? '0',
    );

    double totalGst =
        (itemToEdit?.cgstPercent ?? 0) +
        (itemToEdit?.sgstPercent ?? 0) +
        (itemToEdit?.igstPercent ?? 0);
    final gstCtrl = TextEditingController(
      text: itemToEdit != null
          ? (totalGst > 0 ? totalGst.toString() : '18')
          : '18',
    );

    String currentId =
        itemToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    String productId = itemToEdit?.productId ?? '';
    double currentStock = itemToEdit?.availableStock ?? 0;

    String sku = _itemExtras[currentId]?['sku']?.toString() ?? '';
    String brand = _itemExtras[currentId]?['brand']?.toString() ?? '';
    String model = _itemExtras[currentId]?['model']?.toString() ?? '';
    String productNature =
        _itemExtras[currentId]?['productNature']?.toString() ?? 'General';
    String machineType =
        _itemExtras[currentId]?['machineType']?.toString() ?? '';
    List includedProducts =
        _itemExtras[currentId]?['includedProducts'] as List? ?? [];
    List catalogs = _itemExtras[currentId]?['catalogs'] as List? ?? [];
    List images = _itemExtras[currentId]?['images'] as List? ?? [];
    String compatibleMachineType =
        _itemExtras[currentId]?['compatibleMachineType']?.toString() ?? '';
    List compatibleProductIds =
        _itemExtras[currentId]?['compatibleProductIds'] as List? ?? [];
    List compatibleProductNames =
        _itemExtras[currentId]?['compatibleProductNames'] as List? ?? [];
    List compatibleSubcategories =
        _itemExtras[currentId]?['compatibleSubcategories'] as List? ?? [];
    String itemCode = _itemExtras[currentId]?['itemCode']?.toString() ?? '';
    String sellingPrice =
        _itemExtras[currentId]?['sellingPrice']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                double parsedQty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
                bool stockWarning =
                    productId.isNotEmpty && parsedQty > currentStock;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            itemToEdit == null
                                ? 'Add Product/Service'
                                : 'Edit Line Item',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.inventory_2),
                            label: const Text('Pick from Inventory'),
                            onPressed: () async {
                              final p = await _selectProductDialog();
                              if (p != null) {
                                setModalState(() {
                                  productId = p['id'];
                                  _productCache[productId] = p;

                                  if (nameCtrl.text.trim().isEmpty)
                                    nameCtrl.text = p['name'] ?? '';
                                  if (descCtrl.text.trim().isEmpty)
                                    descCtrl.text =
                                        p['description'] ?? p['details'] ?? '';
                                  if (hsnCtrl.text.trim().isEmpty)
                                    hsnCtrl.text =
                                        p['hsnCode'] ?? p['hsn'] ?? '';

                                  double pPrice =
                                      double.tryParse(
                                        p['sellingPrice']?.toString() ?? '',
                                      ) ??
                                      double.tryParse(
                                        p['price']?.toString() ?? '',
                                      ) ??
                                      double.tryParse(
                                        p['unitPrice']?.toString() ?? '',
                                      ) ??
                                      double.tryParse(
                                        p['rate']?.toString() ?? '',
                                      ) ??
                                      0.0;

                                  if (priceCtrl.text.trim().isEmpty ||
                                      priceCtrl.text == '0' ||
                                      priceCtrl.text == '0.0') {
                                    priceCtrl.text = pPrice > 0
                                        ? pPrice.toString()
                                        : '0';
                                  }

                                  uomCtrl.text = p['uom'] ?? 'Nos';

                                  String currentGst = gstCtrl.text.trim();
                                  if (currentGst.isEmpty ||
                                      currentGst == '0' ||
                                      currentGst == '18' ||
                                      currentGst == '18.0') {
                                    double pGst =
                                        double.tryParse(
                                          p['gstPercentage']?.toString() ??
                                              p['tax']?.toString() ??
                                              '18',
                                        ) ??
                                        18;
                                    gstCtrl.text = pGst.toString();
                                  }

                                  currentStock =
                                      double.tryParse(
                                        p['stockOnHand']?.toString() ??
                                            p['qty']?.toString() ??
                                            p['stock']?.toString() ??
                                            '0',
                                      ) ??
                                      0;

                                  sku = (p['sku'] ?? p['itemCode'] ?? '')
                                      .toString();
                                  brand = (p['brand'] ?? p['make'] ?? '')
                                      .toString();
                                  model = (p['model'] ?? '').toString();
                                  productNature =
                                      (p['productNature'] ?? 'General')
                                          .toString();
                                  machineType = (p['machineType'] ?? '')
                                      .toString();
                                  includedProducts =
                                      p['includedProducts'] as List? ?? [];
                                  catalogs = p['catalogs'] as List? ?? [];
                                  images = p['images'] as List? ?? [];
                                  compatibleMachineType =
                                      (p['compatibleMachineType'] ?? '')
                                          .toString();
                                  compatibleProductIds =
                                      p['compatibleProductIds'] as List? ?? [];
                                  compatibleProductNames =
                                      p['compatibleProductNames'] as List? ??
                                      [];
                                  compatibleSubcategories =
                                      p['compatibleSubcategories'] as List? ??
                                      [];
                                  itemCode = (p['itemCode'] ?? '').toString();
                                  sellingPrice =
                                      (p['sellingPrice'] ?? p['price'] ?? '')
                                          .toString();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      if (productId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: stockWarning
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Available Stock: $currentStock ${uomCtrl.text}',
                            style: TextStyle(
                              color: stockWarning
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      _buildItemTextField(
                        nameCtrl,
                        'Item Name *',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      _buildItemTextField(hsnCtrl, 'HSN / SAC Code'),
                      _buildItemTextField(
                        descCtrl,
                        'Specification / Description',
                        maxLines: null,
                        hint:
                            'Enter features line by line for bullet points in PDF',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildItemTextField(
                              qtyCtrl,
                              'Quantity *',
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  (double.tryParse(v ?? '') ?? 0) <= 0
                                  ? '> 0 required'
                                  : null,
                              onChanged: (v) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildItemTextField(
                              uomCtrl,
                              'UOM (e.g., Nos, Kgs)',
                            ),
                          ),
                        ],
                      ),
                      if (stockWarning)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '⚠️ Warning: Quantity exceeds available inventory stock.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildItemTextField(
                              priceCtrl,
                              'Unit Price *',
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  (double.tryParse(v ?? '') ?? -1) < 0
                                  ? '>= 0 required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildItemTextField(
                              discCtrl,
                              'Discount (%)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      _buildItemTextField(
                        gstCtrl,
                        'GST (%)',
                        keyboardType: TextInputType.number,
                        hint: 'Default is 18%',
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;

                          double gstVal =
                              double.tryParse(gstCtrl.text.trim()) ?? 18.0;
                          double cgst = 0, sgst = 0, igst = 0;
                          if (_isInterState) {
                            igst = gstVal;
                          } else {
                            cgst = gstVal / 2;
                            sgst = gstVal / 2;
                          }

                          final newItem = QuotationLineItem(
                            id: currentId,
                            productId: productId,
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            hsnCode: hsnCtrl.text.trim(),
                            quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                            uom: uomCtrl.text.trim().isEmpty
                                ? 'Nos'
                                : uomCtrl.text.trim(),
                            unitPrice:
                                double.tryParse(priceCtrl.text.trim()) ?? 0,
                            discountPercent:
                                double.tryParse(discCtrl.text.trim()) ?? 0,
                            cgstPercent: cgst,
                            sgstPercent: sgst,
                            igstPercent: igst,
                            availableStock: currentStock,
                          );

                          setState(() {
                            _itemExtras[currentId] = {
                              'sku': sku,
                              'brand': brand,
                              'model': model,
                              'productNature': productNature,
                              'machineType': machineType,
                              'includedProducts': includedProducts,
                              'catalogs': catalogs,
                              'images': images,
                              'compatibleMachineType': compatibleMachineType,
                              'compatibleProductIds': compatibleProductIds,
                              'compatibleProductNames': compatibleProductNames,
                              'compatibleSubcategories':
                                  compatibleSubcategories,
                              'itemCode': itemCode,
                              'sellingPrice': sellingPrice,
                              'baseGst': gstVal,
                              'productNatureLower': productNature.toLowerCase(),
                              'stockOnHand': currentStock,
                              'qty': currentStock,
                              'parentId': null,
                              'isScopeItem': false,
                            };

                            if (index != null) {
                              _items[index] = newItem;
                              developer.log(
                                'Product Updated: $currentId',
                                name: 'QuotationScreen',
                              );
                            } else {
                              _items.add(newItem);
                            }
                            _calculateTotals();
                          });
                          Navigator.pop(context);

                          if (index == null &&
                              (productNature.toLowerCase().contains(
                                    'machine',
                                  ) ||
                                  includedProducts.isNotEmpty)) {
                            _triggerMachineAutomations(
                              newItem,
                              _itemExtras[currentId]!,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Save Item',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showScopeItemModal(String parentId, [QuotationLineItem? itemToEdit]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: itemToEdit?.description ?? '');
    final qtyCtrl = TextEditingController(
      text: itemToEdit?.quantity.toString() ?? '1',
    );
    final uomCtrl = TextEditingController(text: itemToEdit?.uom ?? 'Nos');

    final childExtras = itemToEdit != null
        ? (_itemExtras[itemToEdit.id] ?? {})
        : {};
    bool isIncluded = childExtras['isIncluded'] ?? true;
    String pricingMode = childExtras['pricingMode'] ?? 'Included';

    final priceCtrl = TextEditingController(
      text: itemToEdit?.unitPrice.toString() ?? '0',
    );
    final discCtrl = TextEditingController(
      text: itemToEdit?.discountPercent.toString() ?? '0',
    );

    double totalGst =
        (itemToEdit?.cgstPercent ?? 0) +
        (itemToEdit?.sgstPercent ?? 0) +
        (itemToEdit?.igstPercent ?? 0);
    if (totalGst == 0 && childExtras['baseGst'] != null) {
      totalGst = double.tryParse(childExtras['baseGst'].toString()) ?? 0.0;
    }
    final gstCtrl = TextEditingController(
      text: totalGst > 0 ? totalGst.toString() : '18',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        itemToEdit == null
                            ? 'Add Scope Item'
                            : 'Edit Scope Item',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const Divider(),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Included in Scope of Supply (Print in PDF)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        value: isIncluded,
                        onChanged: (v) =>
                            setModalState(() => isIncluded = v ?? true),
                      ),
                      _buildItemTextField(
                        nameCtrl,
                        'Item Name *',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      _buildItemTextField(
                        descCtrl,
                        'Description (Optional)',
                        maxLines: null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildItemTextField(
                              qtyCtrl,
                              'Quantity *',
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  (double.tryParse(v ?? '') ?? 0) <= 0
                                  ? '> 0 required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildItemTextField(
                              uomCtrl,
                              'UOM (e.g., Nos, Kgs)',
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          value: pricingMode,
                          decoration: _dec('Pricing Mode'),
                          items: const [
                            DropdownMenuItem(
                              value: 'Included',
                              child: Text('Included in Machine Price'),
                            ),
                            DropdownMenuItem(
                              value: 'Separate',
                              child: Text('Charge Separately'),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() => pricingMode = v!),
                        ),
                      ),
                      if (pricingMode == 'Separate') ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildItemTextField(
                                priceCtrl,
                                'Unit Price *',
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    (double.tryParse(v ?? '') ?? -1) < 0
                                    ? '>= 0 required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildItemTextField(
                                discCtrl,
                                'Discount (%)',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        _buildItemTextField(
                          gstCtrl,
                          'GST (%)',
                          keyboardType: TextInputType.number,
                          hint: 'Default is 18%',
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;

                          double gstVal = pricingMode == 'Separate'
                              ? (double.tryParse(gstCtrl.text) ?? 18.0)
                              : (double.tryParse(gstCtrl.text) ?? 18.0);
                          double cgst = 0, sgst = 0, igst = 0;
                          if (gstVal > 0) {
                            if (_isInterState)
                              igst = gstVal;
                            else {
                              cgst = gstVal / 2;
                              sgst = gstVal / 2;
                            }
                          }

                          final newItem = QuotationLineItem(
                            id:
                                itemToEdit?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                        .toString() +
                                    '_custom',
                            productId: itemToEdit?.productId ?? '',
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            hsnCode: itemToEdit?.hsnCode ?? '',
                            quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                            uom: uomCtrl.text.trim().isEmpty
                                ? 'Nos'
                                : uomCtrl.text.trim(),
                            unitPrice: double.tryParse(priceCtrl.text) ?? 0,
                            discountPercent: pricingMode == 'Separate'
                                ? (double.tryParse(discCtrl.text) ?? 0)
                                : 0,
                            cgstPercent: cgst,
                            sgstPercent: sgst,
                            igstPercent: igst,
                            availableStock: itemToEdit?.availableStock ?? 0,
                          );

                          setState(() {
                            _itemExtras[newItem.id] = {
                              ...?_itemExtras[newItem.id],
                              'baseGst': gstVal,
                              'isScopeItem': true,
                              'parentId': parentId,
                              'isIncluded': isIncluded,
                              'pricingMode': pricingMode,
                            };

                            if (itemToEdit != null) {
                              int idx = _items.indexWhere(
                                (i) => i.id == itemToEdit.id,
                              );
                              if (idx >= 0) _items[idx] = newItem;
                            } else {
                              int parentIdx = _items.indexWhere(
                                (i) => i.id == parentId,
                              );
                              if (parentIdx >= 0) {
                                int lastChildIdx = parentIdx;
                                for (
                                  int k = parentIdx + 1;
                                  k < _items.length;
                                  k++
                                ) {
                                  if (_itemExtras[_items[k].id]?['parentId'] ==
                                      parentId) {
                                    lastChildIdx = k;
                                  } else {
                                    break;
                                  }
                                }
                                _items.insert(lastChildIdx + 1, newItem);
                              } else {
                                _items.add(newItem);
                              }
                            }
                            _calculateTotals();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Save Scope Item',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _moveScopeItem(String childId, int direction) {
    int index = _items.indexWhere((i) => i.id == childId);
    if (index < 0) return;

    final child = _items[index];
    final parentId = _itemExtras[childId]?['parentId'];
    final children = _items
        .where((i) => _itemExtras[i.id]?['parentId'] == parentId)
        .toList();
    children.sort((a, b) => _items.indexOf(a).compareTo(_items.indexOf(b)));

    int childListIndex = children.indexWhere((i) => i.id == childId);
    if (direction == -1 && childListIndex > 0) {
      final swapWith = children[childListIndex - 1];
      int swapIndex = _items.indexOf(swapWith);
      setState(() {
        _items[index] = swapWith;
        _items[swapIndex] = child;
      });
    } else if (direction == 1 && childListIndex < children.length - 1) {
      final swapWith = children[childListIndex + 1];
      int swapIndex = _items.indexOf(swapWith);
      setState(() {
        _items[index] = swapWith;
        _items[swapIndex] = child;
      });
    }
  }

  void _onDeleteTopLevelItem(QuotationLineItem item) {
    final children = _items
        .where((i) => _itemExtras[i.id]?['parentId'] == item.id)
        .toList();
    if (children.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Linked Items?'),
          content: const Text(
            'This machine has Scope of Supply items. Do you want to delete them as well?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  for (var c in children) {
                    _itemExtras[c.id]?['parentId'] = null;
                    _itemExtras[c.id]?['isScopeItem'] = false;
                  }
                  _itemExtras.remove(item.id);
                  _items.remove(item);
                  _calculateTotals();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Keep Scope Items'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  for (var c in children) {
                    _itemExtras.remove(c.id);
                    _items.remove(c);
                  }
                  _itemExtras.remove(item.id);
                  _items.remove(item);
                  _calculateTotals();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Delete All'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _itemExtras.remove(item.id);
        _items.remove(item);
        _calculateTotals();
      });
    }
  }

  Widget _buildItemTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLines = 1,
    String? hint,
    Function(String)? onChanged,
    bool readOnlyOverride = false,
  }) {
    final effectiveReadOnly = _isReadOnly || readOnlyOverride;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        onChanged: onChanged,
        readOnly: effectiveReadOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          filled: true,
          fillColor: effectiveReadOnly
              ? Colors.grey.shade100
              : Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildLegacyContactFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildItemTextField(
                _contactPersonController,
                'Contact Person',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildItemTextField(_mobileController, 'Mobile')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _buildItemTextField(_emailController, 'Email ID')),
            const SizedBox(width: 10),
            Expanded(
              child: _buildItemTextField(
                _contactDesignationController,
                'Designation',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildItemTextField(
                _contactDepartmentController,
                'Department',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildItemTextField(_gstController, 'Customer GSTIN'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _calcRow(
    String label,
    double amount, {
    bool bold = false,
    double size = 14,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: size,
              color: color ?? Colors.grey.shade700,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: size,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool showAddressDropdown =
        _customerAddresses.isNotEmpty &&
        _selectedAddressId != null &&
        _selectedAddressId!.isNotEmpty;

    final bool showContactDropdown =
        _selectedCustomerId != null && _selectedCustomerId!.isNotEmpty;

    List<QuotationLineItem> topLevelItems = _items
        .where((i) => _itemExtras[i.id]?['parentId'] == null)
        .toList();

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        title: Text(
          widget.quotationId != null ? 'Edit Quotation' : 'Create Quotation',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: _onPreviewPressed,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Preview'),
            style: TextButton.styleFrom(foregroundColor: accentColor),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isReadOnly)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock,
                                color: Colors.green.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This document is $_approvalStatus and locked for editing.',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Customer Details',
                              Icons.business,
                            ),
                            if (_customerInsights != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade100,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          'Total Quotes',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        Text(
                                          '${_customerInsights!['count']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Last Quote',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        Text(
                                          '₹${_customerInsights!['lastQuoteAmount']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Lifetime Value',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        Text(
                                          '₹${_customerInsights!['totalValue']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            _buildCustomerNameAutocomplete(
                              validator: (v) =>
                                  v!.trim().isEmpty ? 'Required' : null,
                            ),
                            if (showAddressDropdown) ...[
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value:
                                    _customerAddresses.any(
                                      (a) => a['id'] == _selectedAddressId,
                                    )
                                    ? _selectedAddressId
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'Select Billing Address',
                                  prefixIcon: const Icon(
                                    Icons.location_on_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  isDense: true,
                                ),
                                items: _customerAddresses
                                    .map<DropdownMenuItem<String>>((addr) {
                                      final type = (addr['type'] ?? 'Address')
                                          .toString();
                                      final isPrimary =
                                          addr['isPrimary'] == true
                                          ? ' (Primary)'
                                          : '';
                                      final isBilling =
                                          addr['isBillingAddress'] == true
                                          ? ' (Billing)'
                                          : '';
                                      final shortAddr =
                                          (addr['combinedAddress'] ??
                                                  addr['address'] ??
                                                  '')
                                              .toString()
                                              .replaceAll('\n', ', ');
                                      return DropdownMenuItem<String>(
                                        value: addr['id']?.toString(),
                                        child: Text(
                                          '$type$isPrimary$isBilling - $shortAddr',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    })
                                    .toList(),
                                selectedItemBuilder: (BuildContext context) {
                                  return _customerAddresses.map<Widget>((addr) {
                                    final type = (addr['type'] ?? 'Address')
                                        .toString();
                                    final isPrimary = addr['isPrimary'] == true
                                        ? ' (Primary)'
                                        : '';
                                    final isBilling =
                                        addr['isBillingAddress'] == true
                                        ? ' (Billing)'
                                        : '';
                                    final shortAddr =
                                        (addr['combinedAddress'] ??
                                                addr['address'] ??
                                                '')
                                            .toString()
                                            .replaceAll('\n', ', ');
                                    return Text(
                                      '$type$isPrimary$isBilling - $shortAddr',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }).toList();
                                },
                                onChanged: _isReadOnly
                                    ? null
                                    : (v) {
                                        if (v == _selectedAddressId) return;
                                        setState(() {
                                          _selectedAddressId = v;
                                          _isUserChangingAddress = true;
                                          if (!_isRestoring) {
                                            _selectedContactId = null;
                                            _selectedContactData = null;
                                            _updateContactSnapshots(null);
                                            developer.log(
                                              'Address Changed By User',
                                              name: 'QuotationScreen',
                                            );
                                          }

                                          if (v != null) {
                                            final matches = _customerAddresses
                                                .where((a) => a['id'] == v);
                                            _selectedAddressData =
                                                matches.isNotEmpty
                                                ? matches.first
                                                : null;
                                            _updateAddressSnapshots(
                                              _selectedAddressData,
                                            );
                                          }
                                        });
                                      },
                              ),
                              const SizedBox(height: 12),
                            ] else ...[
                              _buildItemTextField(
                                _addressController,
                                'Billing Address',
                                maxLines: 2,
                              ),
                            ],
                            if (showContactDropdown) ...[
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream:
                                    _companyContactsRef(_selectedCustomerId!)
                                        .where('isActive', isEqualTo: true)
                                        .snapshots(),
                                builder: (context, snap) {
                                  if (!snap.hasData)
                                    return _buildLegacyContactFields();

                                  var contacts = snap.data!.docs
                                      .where(
                                        (d) =>
                                            d.data()['isDeleted'] != true ||
                                            d.id == _selectedContactId,
                                      )
                                      .toList();
                                  if (contacts.isEmpty)
                                    return _buildLegacyContactFields();

                                  if (contacts.isEmpty) {
                                    return Column(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: Text(
                                            'No linked contacts for selected address. Enter manually.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        _buildLegacyContactFields(),
                                      ],
                                    );
                                  }

                                  final validContactId =
                                      contacts.any(
                                        (d) => d.id == _selectedContactId,
                                      )
                                      ? _selectedContactId
                                      : null;

                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          value: validContactId,
                                          decoration: InputDecoration(
                                            labelText: 'Select Contact Person',
                                            prefixIcon: const Icon(
                                              Icons.person_outline,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            isDense: true,
                                          ),
                                          items: contacts
                                              .map<DropdownMenuItem<String>>(
                                                (
                                                  doc,
                                                ) => DropdownMenuItem<String>(
                                                  value: doc.id,
                                                  child: Text(
                                                    (doc.data()['name'] ??
                                                            doc.data()['contactName'] ??
                                                            '')
                                                        .toString(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          selectedItemBuilder:
                                              (BuildContext context) {
                                                return contacts.map<Widget>((
                                                  doc,
                                                ) {
                                                  return Text(
                                                    (doc.data()['name'] ??
                                                            doc.data()['contactName'] ??
                                                            '')
                                                        .toString(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  );
                                                }).toList();
                                              },
                                          onChanged: _isReadOnly
                                              ? null
                                              : (v) {
                                                  setState(() {
                                                    _selectedContactId = v;
                                                    _selectedContactData = null;
                                                    if (v != null) {
                                                      final matches = contacts
                                                          .where(
                                                            (c) => c.id == v,
                                                          );
                                                      _selectedContactData =
                                                          matches.isNotEmpty
                                                          ? matches.first.data()
                                                          : null;
                                                      _updateContactSnapshots(
                                                        _selectedContactData,
                                                      );
                                                      developer.log(
                                                        'Contact Changed By User',
                                                        name: 'QuotationScreen',
                                                      );
                                                    }
                                                  });
                                                },
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildItemTextField(
                                              _mobileController,
                                              'Mobile',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildItemTextField(
                                              _emailController,
                                              'Email ID',
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildItemTextField(
                                              _contactDesignationController,
                                              'Designation',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildItemTextField(
                                              _contactDepartmentController,
                                              'Department',
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildItemTextField(
                                              _contactDesignationController,
                                              'Designation',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildItemTextField(
                                              _contactDepartmentController,
                                              'Department',
                                            ),
                                          ),
                                        ],
                                      ),
                                      _buildItemTextField(
                                        _gstController,
                                        'Customer GSTIN',
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ] else ...[
                              _buildLegacyContactFields(),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Quotation & Inquiry Link',
                              Icons.link,
                            ),
                            if (_hasLinkedInquiry)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Linked Inquiry: ${_linkedInquiryNumber ?? _linkedInquiryId ?? ''}. Status will auto-update to "Quoted".',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DropdownButtonFormField<String>(
                                value: _quotationType,
                                isExpanded: true,
                                decoration: _dec('Quotation Type'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'domestic',
                                    child: Text('Domestic Quotation'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'export',
                                    child: Text('Export Quotation'),
                                  ),
                                ],
                                onChanged: _isReadOnly
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _quotationType =
                                              _normalizeQuotationType(value);
                                          _applyQuotationSettingsDefaultTerms(
                                            force: true,
                                          );
                                        });
                                      },
                              ),
                            ),
                            _buildItemTextField(
                              _subjectController,
                              'Subject Line *',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildSegmentedQuotationNumber(),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: _isReadOnly
                                        ? null
                                        : () async {
                                            final now = DateTime.now();
                                            final fyStart = now.month >= 4
                                                ? DateTime(now.year, 4, 1)
                                                : DateTime(now.year - 1, 4, 1);
                                            final fyEnd = now.month >= 4
                                                ? DateTime(now.year + 1, 3, 31)
                                                : DateTime(now.year, 3, 31);

                                            DateTime initDate = DateTime(
                                              _quoteDate.year,
                                              _quoteDate.month,
                                              _quoteDate.day,
                                            );

                                            if (initDate.isBefore(fyStart)) {
                                              initDate = fyStart;
                                            }
                                            if (initDate.isAfter(fyEnd)) {
                                              initDate = fyEnd;
                                            }

                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate: initDate,
                                              firstDate: fyStart,
                                              lastDate: fyEnd,
                                              helpText: 'Select Quote Date',
                                              fieldLabelText: 'Enter Date',
                                              fieldHintText: 'dd/mm/yyyy',
                                            );
                                            if (d != null) {
                                              setState(() {
                                                _quoteDate = DateTime(
                                                  d.year,
                                                  d.month,
                                                  d.day,
                                                );
                                              });
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Quote Date',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF2563EB),
                                            width: 1.5,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: _isReadOnly
                                            ? Colors.grey.shade100
                                            : const Color(0xFFF8FAFC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      child: Text(
                                        DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_quoteDate),
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Line Items',
                              Icons.inventory_2_outlined,
                              trailing: _isReadOnly
                                  ? null
                                  : ElevatedButton.icon(
                                      onPressed: _showAddItemModal,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Item'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            if (topLevelItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'No items added yet.',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: topLevelItems.length,
                                itemBuilder: (ctx, i) {
                                  final item = topLevelItems[i];
                                  final extras = _itemExtras[item.id] ?? {};
                                  final children = _items
                                      .where(
                                        (c) =>
                                            _itemExtras[c.id]?['parentId'] ==
                                            item.id,
                                      )
                                      .toList();
                                  children.sort(
                                    (a, b) => _items
                                        .indexOf(a)
                                        .compareTo(_items.indexOf(b)),
                                  );

                                  bool isOutOfStock = item.availableStock <= 0;
                                  bool isLowStock =
                                      item.availableStock < item.quantity &&
                                      !isOutOfStock;
                                  Color stockColor = isOutOfStock
                                      ? Colors.red
                                      : (isLowStock
                                            ? Colors.orange
                                            : Colors.green);
                                  String stockText = isOutOfStock
                                      ? 'Out of Stock'
                                      : (isLowStock ? 'Low Stock' : 'In Stock');

                                  String sku = (extras['sku'] ?? '').toString();
                                  String brand = (extras['brand'] ?? '')
                                      .toString();
                                  String model = (extras['model'] ?? '')
                                      .toString();
                                  String itemCode = (extras['itemCode'] ?? '')
                                      .toString();
                                  String nature =
                                      (extras['productNature'] ?? '')
                                          .toString();
                                  String machineType =
                                      (extras['machineType'] ?? '').toString();
                                  List catalogs =
                                      extras['catalogs'] as List? ?? [];
                                  List images = extras['images'] as List? ?? [];
                                  String imgUrl = images.isNotEmpty
                                      ? images.first.toString()
                                      : '';

                                  bool showQtyWarning =
                                      item.quantity > item.availableStock &&
                                      item.productId.isNotEmpty;
                                  bool isMachine =
                                      nature.toLowerCase() == 'machine';

                                  List<String> metaList = [];
                                  if (sku.isNotEmpty) metaList.add('SKU: $sku');
                                  if (itemCode.isNotEmpty)
                                    metaList.add('Code: $itemCode');
                                  if (brand.isNotEmpty)
                                    metaList.add('Brand: $brand');
                                  if (model.isNotEmpty)
                                    metaList.add('Model: $model');

                                  Color natureColor = Colors.grey;
                                  if (nature.toLowerCase() == 'machine')
                                    natureColor = Colors.purple;
                                  else if (nature.toLowerCase() == 'accessory')
                                    natureColor = Colors.orange;
                                  else if (nature.toLowerCase() == 'spare')
                                    natureColor = Colors.blue;
                                  else if (nature.toLowerCase() == 'consumable')
                                    natureColor = Colors.teal;
                                  else if (nature.toLowerCase() ==
                                      'raw material')
                                    natureColor = Colors.brown;

                                  int actualIndex = _items.indexOf(item);

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.02,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (imgUrl.isNotEmpty)
                                                  InkWell(
                                                    onTap: () =>
                                                        _openImage(imgUrl),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: Image.network(
                                                        imgUrl,
                                                        width: 60,
                                                        height: 60,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                if (imgUrl.isNotEmpty)
                                                  const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              item.name,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            '₹${item.totalAmount.toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                              color:
                                                                  primaryColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        spacing: 6,
                                                        runSpacing: 6,
                                                        children: [
                                                          if (nature
                                                                  .isNotEmpty &&
                                                              nature !=
                                                                  'General')
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: natureColor
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                border: Border.all(
                                                                  color: natureColor
                                                                      .withOpacity(
                                                                        0.3,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                nature,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color:
                                                                      natureColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                          if (machineType
                                                              .isNotEmpty)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .purple
                                                                    .shade50,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .purple
                                                                      .shade200,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                'Type: $machineType',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .purple
                                                                      .shade700,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                          if (item
                                                              .productId
                                                              .isNotEmpty)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: stockColor
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                border: Border.all(
                                                                  color: stockColor
                                                                      .withOpacity(
                                                                        0.3,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                '$stockText (${item.availableStock})',
                                                                style: TextStyle(
                                                                  color:
                                                                      stockColor,
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      if (metaList.isNotEmpty)
                                                        Text(
                                                          metaList.join(' | '),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .blueGrey
                                                                .shade600,
                                                          ),
                                                        ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${item.quantity} ${item.uom} x ₹${item.unitPrice.toStringAsFixed(2)}  (Tax: ${item.cgstPercent + item.sgstPercent + item.igstPercent}% | Disc: ${item.discountPercent}%)',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (item
                                                          .hsnCode
                                                          .isNotEmpty)
                                                        Text(
                                                          'HSN/SAC: ${item.hsnCode}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  children: [
                                                    if (!_isReadOnly)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          color:
                                                              Colors.blueGrey,
                                                          size: 18,
                                                        ),
                                                        onPressed: () =>
                                                            _showAddItemModal(
                                                              item,
                                                              actualIndex,
                                                            ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                      ),
                                                    const SizedBox(height: 12),
                                                    if (!_isReadOnly)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                          size: 18,
                                                        ),
                                                        onPressed: () =>
                                                            _onDeleteTopLevelItem(
                                                              item,
                                                            ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (showQtyWarning)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      size: 14,
                                                      color: Colors.orange,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Warning: Quantity exceeds available stock.',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .orange
                                                            .shade800,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (catalogs.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.attach_file,
                                                      size: 14,
                                                      color: accentColor,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${catalogs.length} Catalog(s) Attached',
                                                      style: const TextStyle(
                                                        color: accentColor,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      if (isMachine || children.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                            left: 16,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    'Scope of Supply',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                  if (!_isReadOnly)
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          _showScopeItemModal(
                                                            item.id,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.add,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Add Custom',
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        minimumSize: Size.zero,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const Divider(),
                                              if (children.isEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                      ),
                                                  child: Text(
                                                    'No scope items added.',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                )
                                              else
                                                ...children.map((child) {
                                                  final childExtras =
                                                      _itemExtras[child.id] ??
                                                      {};
                                                  final isIncluded =
                                                      childExtras['isIncluded'] !=
                                                      false;
                                                  final pricingMode =
                                                      childExtras['pricingMode'] ??
                                                      'Included';

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        if (!_isReadOnly)
                                                          SizedBox(
                                                            height: 24,
                                                            width: 24,
                                                            child: Checkbox(
                                                              value: isIncluded,
                                                              onChanged: (v) {
                                                                setState(() {
                                                                  _itemExtras[child
                                                                          .id]?['isIncluded'] =
                                                                      v;
                                                                  _calculateTotals();
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                        if (!_isReadOnly)
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                child.name,
                                                                style: TextStyle(
                                                                  decoration:
                                                                      isIncluded
                                                                      ? null
                                                                      : TextDecoration
                                                                            .lineThrough,
                                                                  color:
                                                                      isIncluded
                                                                      ? Colors
                                                                            .black87
                                                                      : Colors
                                                                            .grey,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                              Text(
                                                                '${child.quantity} ${child.uom} | ${pricingMode == 'Included' ? 'Included' : '₹${child.unitPrice.toStringAsFixed(2)}'}',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (!_isReadOnly)
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .arrow_upward,
                                                                  size: 16,
                                                                ),
                                                                onPressed: () =>
                                                                    _moveScopeItem(
                                                                      child.id,
                                                                      -1,
                                                                    ),
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          4,
                                                                    ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .arrow_downward,
                                                                  size: 16,
                                                                ),
                                                                onPressed: () =>
                                                                    _moveScopeItem(
                                                                      child.id,
                                                                      1,
                                                                    ),
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          4,
                                                                    ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons.edit,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .blueGrey,
                                                                ),
                                                                onPressed: () =>
                                                                    _showScopeItemModal(
                                                                      item.id,
                                                                      child,
                                                                    ),
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          4,
                                                                    ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons.delete,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    _itemExtras
                                                                        .remove(
                                                                          child
                                                                              .id,
                                                                        );
                                                                    _items
                                                                        .remove(
                                                                          child,
                                                                        );
                                                                    _calculateTotals();
                                                                  });
                                                                },
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          4,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            const Divider(height: 32, thickness: 1.5),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 300,
                                child: Column(
                                  children: [
                                    _calcRow('Subtotal', _cachedSubtotal),
                                    _calcRow(
                                      'Item Discounts',
                                      -_cachedItemDiscount,
                                      color: Colors.red,
                                    ),
                                    _calcRow(
                                      'Taxable Value',
                                      _cachedTaxableAmount,
                                      bold: true,
                                    ),
                                    if (!_isInterState) ...[
                                      _calcRow('CGST', _cachedCgst),
                                      _calcRow('SGST', _cachedSgst),
                                    ] else ...[
                                      _calcRow('IGST', _cachedIgst),
                                    ],
                                    if (_cachedRoundOff != 0)
                                      _calcRow('Round Off', _cachedRoundOff),
                                    const Divider(),
                                    _calcRow(
                                      'FINAL TOTAL',
                                      _cachedFinalTotal,
                                      bold: true,
                                      size: 18,
                                      color: primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_isReadOnly)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Packing & Forwarding Extra',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _packingChargesExtra,
                                onChanged: (v) =>
                                    setState(() => _packingChargesExtra = v),
                              ),
                            const Divider(height: 10),
                            _buildSectionHeader(
                              'Terms & Conditions',
                              Icons.gavel_outlined,
                              trailing: _isReadOnly
                                  ? null
                                  : OutlinedButton.icon(
                                      onPressed: () => setState(
                                        () => _dynamicTerms.add(TermRow()),
                                      ),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Term'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: accentColor,
                                        side: const BorderSide(
                                          color: accentColor,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                      ),
                                    ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _dynamicTerms.length,
                              itemBuilder: (ctx, i) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _buildItemTextField(
                                          _dynamicTerms[i].titleCtrl,
                                          'Title (e.g. Payment)',
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 7,
                                        child: _buildItemTextField(
                                          _dynamicTerms[i].valueCtrl,
                                          'Term Detail',
                                          maxLines: null,
                                        ),
                                      ),
                                      if (!_isReadOnly)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            var term = _dynamicTerms[i];
                                            setState(
                                              () => _dynamicTerms.removeAt(i),
                                            );
                                            term.dispose();
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 30),
                            _buildSectionHeader(
                              'Signature Details',
                              Icons.edit_document,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _signNameController,
                                    'Signatory Name',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _signDesignationController,
                                    'Designation',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _signPhoneController,
                                    'Signatory Phone',
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(child: SizedBox()),
                              ],
                            ),
                            const Divider(height: 30),
                            const Text(
                              'Follow-up Schedule',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _isReadOnly
                                        ? null
                                        : () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  _nextFollowUpDate ??
                                                  DateTime.now().add(
                                                    const Duration(days: 3),
                                                  ),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime(2100),
                                            );
                                            if (d != null) {
                                              setState(
                                                () => _nextFollowUpDate = d,
                                              );
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Next Follow-up',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: _isReadOnly
                                            ? Colors.grey.shade100
                                            : Colors.orange.shade50,
                                        isDense: true,
                                      ),
                                      child: Text(
                                        _nextFollowUpDate != null
                                            ? DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(_nextFollowUpDate!)
                                            : 'Select Date',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _followUpNotesController,
                                    'Follow-up Notes',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Final Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '₹ ${_cachedFinalTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_quotationStatus != 'Converted' &&
                            (_approvalStatus == 'Approved' ||
                                _isAdminOrManager) &&
                            widget.quotationId != null)
                          OutlinedButton(
                            onPressed: _convertToInvoice,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: primaryColor),
                              foregroundColor: primaryColor,
                            ),
                            child: const Text('Convert to SO'),
                          ),
                        ElevatedButton.icon(
                          onPressed: _isReadOnly || _isLoading
                              ? null
                              : _saveQuotation,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Save Quotation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
