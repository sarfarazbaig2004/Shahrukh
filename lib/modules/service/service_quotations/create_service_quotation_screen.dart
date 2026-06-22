import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';

import 'service_quotation_pdf_generator.dart';
import 'models/service_quotation_models.dart' as ext_models;
import 'widgets/service_items_section.dart';
import 'widgets/quotation_bottom_action_bar.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);
const Color borderLight = Color(0xFFE2E8F0);
const Color textDark = Color(0xFF0F172A);
const Color textMuted = Color(0xFF64748B);
const String fallbackQuotationSeriesPrefix = 'MEM';

// ===========================================================================
// --- 1. UI MODELS & STATE CLASSES ---
// ===========================================================================

class QuotationTotals {
  final double subtotal;
  final double visitChargesTotal;
  final double itemDiscount;
  final double globalDiscount;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double grandTotal;
  final double finalTotal;
  final double roundOff;

  const QuotationTotals({
    this.subtotal = 0.0,
    this.visitChargesTotal = 0.0,
    this.itemDiscount = 0.0,
    this.globalDiscount = 0.0,
    this.taxableAmount = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.grandTotal = 0.0,
    this.finalTotal = 0.0,
    this.roundOff = 0.0,
  });

  static const QuotationTotals zero = QuotationTotals();
}

class TermRow {
  final String id;
  final TextEditingController titleCtrl;
  final TextEditingController valueCtrl;

  TermRow({String? id, String title = '', String value = ''})
      : id = id ?? const Uuid().v4(),
        titleCtrl = TextEditingController(text: title),
        valueCtrl = TextEditingController(text: value);

  void dispose() {
    titleCtrl.dispose();
    valueCtrl.dispose();
  }
}

class MachineFormState {
  final String machineUid;
  final String? categoryId;
  final String? subcategoryId;
  final String? machineType;
  final String? productId;

  final String model;
  final String serial;
  final String complaint;
  final String customerRemarks;

  final String warrantyStatus;
  final bool isWarranty;
  final String serviceCategory;
  final String severity;
  final List<ext_models.QuotationLineItem> items;
  final QuotationTotals totals;

  MachineFormState({
    required this.machineUid,
    this.categoryId,
    this.subcategoryId,
    this.machineType,
    this.productId,
    required this.model,
    required this.serial,
    required this.complaint,
    this.customerRemarks = '',
    required this.warrantyStatus,
    required this.isWarranty,
    required this.serviceCategory,
    required this.severity,
    this.items = const [],
    this.totals = QuotationTotals.zero,
  });

  MachineFormState copyWith({
    String? machineUid,
    String? categoryId,
    String? subcategoryId,
    String? machineType,
    String? productId,
    String? model,
    String? serial,
    String? complaint,
    String? customerRemarks,
    String? warrantyStatus,
    bool? isWarranty,
    String? serviceCategory,
    String? severity,
    List<ext_models.QuotationLineItem>? items,
    QuotationTotals? totals,
  }) {
    return MachineFormState(
      machineUid: machineUid ?? this.machineUid,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      machineType: machineType ?? this.machineType,
      productId: productId ?? this.productId,
      model: model ?? this.model,
      serial: serial ?? this.serial,
      complaint: complaint ?? this.complaint,
      customerRemarks: customerRemarks ?? this.customerRemarks,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      isWarranty: isWarranty ?? this.isWarranty,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      severity: severity ?? this.severity,
      items: items ?? this.items,
      totals: totals ?? this.totals,
    );
  }

  MachineFormState clearCascade(int level) {
    return MachineFormState(
      machineUid: machineUid,
      categoryId: level <= 1 ? null : categoryId,
      subcategoryId: level <= 2 ? null : subcategoryId,
      machineType: level <= 3 ? null : machineType,
      productId: level <= 4 ? null : productId,
      model: level <= 4 ? '' : model,
      serial: serial,
      complaint: complaint,
      customerRemarks: customerRemarks,
      warrantyStatus: warrantyStatus,
      isWarranty: isWarranty,
      serviceCategory: serviceCategory,
      severity: severity,
      items: items,
      totals: totals,
    );
  }

  Map<String, dynamic> toMap(Map<String, Map<String, dynamic>> extrasMap) {
    return {
      'machineUid': machineUid,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'machineType': machineType,
      'productId': productId,
      'model': model,
      'serial': serial,
      'complaint': complaint,
      'customerRemarks': customerRemarks,
      'warrantyStatus': warrantyStatus,
      'isWarranty': isWarranty,
      'serviceCategory': serviceCategory,
      'severity': severity,
      'items': items.map((e) => {...e.toMap(), ...(extrasMap[e.itemId] ?? {})}).toList(),
      'machineSubtotal': totals.subtotal,
      'machineTaxTotal': totals.cgst + totals.sgst + totals.igst,
      'machineGrandTotal': totals.grandTotal,
    };
  }
}

// ===========================================================================
// --- 2. MAIN SCREEN & INITIALIZATION ---
// ===========================================================================

class CreateServiceQuotationScreen extends StatefulWidget {
  final int? userId;
  final String? currentUserUid;
  final String? companyId;
  final String? quotationId;
  final Map<String, dynamic>? serviceRequestSeed;
  final Map<String, dynamic>? existingQuotation;

  const CreateServiceQuotationScreen({
    super.key,
    this.userId,
    this.currentUserUid,
    this.companyId,
    this.quotationId,
    this.serviceRequestSeed,
    this.existingQuotation,
  });

  @override
  State<CreateServiceQuotationScreen> createState() => _CreateServiceQuotationScreenState();
}

class _CreateServiceQuotationScreenState extends State<CreateServiceQuotationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  // Value Notifiers for State Management
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isReadOnly = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _visitRequired = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _packingChargesExtra = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _createRevisionFlag = ValueNotifier<bool>(false);
  final ValueNotifier<int> _nextSequencePreview = ValueNotifier<int>(1);

  // Core Business Data
  late final ValueNotifier<MachineFormState> _machine;
  final ValueNotifier<List<ext_models.VisitCharge>> _visitCharges = ValueNotifier<List<ext_models.VisitCharge>>([]);
  final ValueNotifier<List<TermRow>> _dynamicTerms = ValueNotifier<List<TermRow>>([]);
  final ValueNotifier<QuotationTotals> _globalTotals = ValueNotifier<QuotationTotals>(QuotationTotals.zero);
  final ValueNotifier<Map<String, dynamic>?> _customerInsights = ValueNotifier<Map<String, dynamic>?>(null);

  // Expansion Tile Controllers
  final ExpansionTileController _customerTileCtrl = ExpansionTileController();
  final ExpansionTileController _machineTileCtrl = ExpansionTileController();
  final ExpansionTileController _itemsTileCtrl = ExpansionTileController();
  final ExpansionTileController _financeTileCtrl = ExpansionTileController();
  final ExpansionTileController _termsTileCtrl = ExpansionTileController();

  // Meta & Context
  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'service';
  String _currentUserName = '';
  int _currentVersion = 1;

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
  String _quotationPrefix = fallbackQuotationSeriesPrefix;
  bool _isInterState = false;

  bool get _isAdminOrManager => ['admin', 'manager', 'director', 'md', 'ceo', 'super_admin'].contains(_currentUserRole.toLowerCase());

  String _approvalStatus = 'Waiting Customer Approval';
  String _quotationStatus = 'Draft';
  String _paymentStatus = 'Pending';
  String _fullExistingQuoteNumber = '';

  DateTime _requestDate = DateTime.now().toUtc();
  DateTime _quoteDate = DateTime.now().toUtc();
  DateTime? _nextFollowUpDate;

  // Caches & Snapshots
  final Map<String, Map<String, dynamic>> _itemExtras = {};
  List<Map<String, dynamic>> _customerAddresses = [];
  List<Map<String, dynamic>> _customerContacts = [];

  String? _selectedCustomerId;
  String? _selectedAddressId;
  String? _selectedContactId;
  Map<String, dynamic>? _selectedAddressData;
  Map<String, dynamic>? _selectedContactData;

  String? _linkedServiceRequestId;
  String? _linkedServiceRequestNumber;
  String _selectedRequestSource = 'Service Request';

  String _customerState = '';
  String _customerPrimaryAddressSnapshot = '';
  String _customerPrimaryCitySnapshot = '';
  String _customerPrimaryStateSnapshot = '';
  String _customerPrimaryPincodeSnapshot = '';
  String _contactPersonSnapshot = '';
  String _contactEmailSnapshot = '';
  String _contactMobileSnapshot = '';
  String _contactDesignationSnapshot = '';

  // Controllers
  late final List<TextEditingController> _allControllers;
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _contactDesignationController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _quotationSequenceController = TextEditingController();
  final TextEditingController _serviceRequestNumberController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _followUpNotesController = TextEditingController();
  final TextEditingController _serviceRefNoteController = TextEditingController();
  final TextEditingController _signNameController = TextEditingController();
  final TextEditingController _signDesignationController = TextEditingController();
  final TextEditingController _signPhoneController = TextEditingController();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference? get _companyDoc => _companyId != null ? _db.collection('companies').doc(_companyId) : null;
  CollectionReference? get _quotesColl => _companyDoc?.collection('service_quotations');
  CollectionReference? get _customersColl => _companyDoc?.collection('customers');
  CollectionReference? get _productsColl => _companyDoc?.collection('products');
  CollectionReference? get _requestsColl => _companyDoc?.collection('service_requests');

  @override
  void initState() {
    super.initState();
    _allControllers = [
      _clientNameController, _addressController, _emailController, _mobileController,
      _contactPersonController, _contactDesignationController, _gstController, _quotationSequenceController,
      _serviceRequestNumberController, _subjectController,
      _followUpNotesController, _serviceRefNoteController,
      _signNameController, _signDesignationController, _signPhoneController
    ];

    _machine = ValueNotifier<MachineFormState>(MachineFormState(
      machineUid: _uuid.v4(),
      model: '',
      serial: '',
      complaint: '',
      warrantyStatus: 'Out Of Warranty',
      isWarranty: false,
      serviceCategory: 'General',
      severity: 'Normal',
    ));

    _initializeScreen();
  }

  // ===========================================================================
  // --- 3. DISPOSE ---
  // ===========================================================================

  @override
  void dispose() {
    _scrollController.dispose();
    for (var ctrl in _allControllers) { ctrl.dispose(); }
    for (var term in _dynamicTerms.value) { term.dispose(); }
    _isLoading.dispose();
    _isReadOnly.dispose();
    _visitRequired.dispose();
    _packingChargesExtra.dispose();
    _createRevisionFlag.dispose();
    _machine.dispose();
    _visitCharges.dispose();
    _dynamicTerms.dispose();
    _globalTotals.dispose();
    _customerInsights.dispose();
    _nextSequencePreview.dispose();
    super.dispose();
  }

  // ===========================================================================
  // --- 4. DATA LOADING & CRM ---
  // ===========================================================================

  Future<void> _initializeScreen() async {
    _isLoading.value = true;
    try {
      await Future.wait([ _loadUserContext(), _loadUserSettings() ]);
      await _loadCompanyProfile();
      await _fetchNextSequencePreview();

      if (widget.existingQuotation != null) {
        await _loadExistingQuotation(widget.existingQuotation!);
      } else {
        await _applyServiceRequestSeedIfNeeded();
      }

      _calculateTotals();

      if (widget.existingQuotation == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _customerTileCtrl.expand();
        });
      }

    } catch (e, st) {
      debugPrint('Initialization Error: $e\n$st');
      _showSnack('Failed to initialize screen properly.', isError: true);
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _loadUserContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No logged-in user.');

    final rootUserDoc = await _db.collection('users').doc(user.uid).get();
    final rootData = rootUserDoc.data() ?? {};

    _currentUserUid = user.uid;
    _companyId = widget.companyId?.trim().isNotEmpty == true
        ? widget.companyId!.trim()
        : (rootData['activeCompanyId'] ?? rootData['companyId'] ?? '').toString().trim();
    _currentUserRole = (rootData['role'] ?? 'service').toString().trim();

    if (_companyDoc != null) {
      final compUserDoc = await _companyDoc!.collection('users').doc(user.uid).get();
      final compData = compUserDoc.exists ? compUserDoc.data() ?? {} : {};
      _currentUserName = (compData['name'] ?? rootData['name'] ?? '').toString().trim();

      if (widget.existingQuotation == null) {
        _signNameController.text = _currentUserName;
        _signDesignationController.text = (compData['designation'] ?? _currentUserRole).toString().toUpperCase();
        _signPhoneController.text = (compData['phone'] ?? user.phoneNumber ?? '').toString();
      }
    }
  }

  Future<void> _loadCompanyProfile() async {
    if (_companyDoc == null) return;
    final doc = await _companyDoc!.get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>? ?? {};

    _companyName = (data['companyName'] ?? data['name'] ?? '').toString();
    _companyState = (data['state'] ?? '').toString().trim().toLowerCase();
    _companyGst = (data['gstin'] ?? data['gstNo'] ?? '').toString();
    _quotationPrefix = (data['quotationPrefix'] ?? fallbackQuotationSeriesPrefix).toString().toUpperCase();

    List<String> addressLines = [];
    final street = (data['streetAddress'] ?? data['address'] ?? '').toString().trim();
    if (street.isNotEmpty) addressLines.add(street);

    final city = (data['city'] ?? data['district'] ?? '').toString().trim();
    final state = (data['state'] ?? '').toString().trim();
    final zip = (data['postalCode'] ?? data['pincode'] ?? data['zip'] ?? '').toString().trim();

    List<String> localityParts = [];
    if (city.isNotEmpty) localityParts.add(city);
    if (state.isNotEmpty) localityParts.add(state);
    if (zip.isNotEmpty) localityParts.add(zip);

    if (localityParts.isNotEmpty) addressLines.add(localityParts.join(', '));
    final country = (data['country'] ?? '').toString().trim();
    if (country.isNotEmpty && country.toLowerCase() != 'india') addressLines.add(country);

    _companyAddress = addressLines.join('\n');
    _companyPhone = (data['phone'] ?? data['mobile'] ?? '').toString();
    _companyEmail = (data['email'] ?? '').toString();
    _companyWebsite = (data['website'] ?? '').toString();
    _companyCin = (data['cin'] ?? '').toString();
    _companyPan = (data['pan'] ?? '').toString();
    _companyBankDetails = (data['bankDetails'] ?? '').toString();
    _companyLogoUrl = (data['logoUrl'] ?? '').toString();
  }

  Future<void> _loadUserSettings() async {
    if (widget.existingQuotation == null) _applyProfessionalDefaultTerms();
    if (_currentUserUid == null) return;
    final doc = await _db.collection('quotationSettings').doc(_currentUserUid).get();
    if (doc.exists && doc.data() != null) {
      _packingChargesExtra.value = doc.data()!['packingChargesExtra'] as bool? ?? true;
    }
  }

  void _applyProfessionalDefaultTerms() {
    _dynamicTerms.value = [
      TermRow(id: _uuid.v4(), title: 'Payment', value: '100% advance against Proforma Invoice before dispatch/visit.'),
      TermRow(id: _uuid.v4(), title: 'Validity', value: '30 Days from the date of this quotation.'),
      TermRow(id: _uuid.v4(), title: 'Service Terms', value: 'Boarding, lodging and local transport of engineer to be arranged by the buyer.'),
      TermRow(id: _uuid.v4(), title: 'Price Basis', value: 'Ex-Works.'),
      TermRow(id: _uuid.v4(), title: 'Freight & Insurance', value: 'Extra at actuals. To be borne by the buyer.'),
    ];
  }

  Future<void> _fetchNextSequencePreview() async {
    if (_companyId == null) return;
    final financialYear = _getFinancialYearFromDate(_quoteDate);
    try {
      final counterRef = _companyDoc!.collection('counters').doc('service_quotation_counter_$financialYear');
      final counterDoc = await counterRef.get();
      final currentSequence = ((counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0);
      _nextSequencePreview.value = currentSequence + 1;
    } catch (e, st) {
      debugPrint('Sequence fetch error: $e\n$st');
      _nextSequencePreview.value = 1;
    }
  }

  String _getLiveQuoteNumberDisplay() {
    if (_fullExistingQuoteNumber.isNotEmpty) return _fullExistingQuoteNumber;
    final fy = _getFinancialYearFromDate(_quoteDate);
    String seqStr = _quotationSequenceController.text.trim();
    if (seqStr.isEmpty) {
      seqStr = _nextSequencePreview.value.toString().padLeft(3, '0');
    } else {
      int? parsed = int.tryParse(seqStr);
      if (parsed != null) seqStr = parsed.toString().padLeft(3, '0');
    }
    return '$_quotationPrefix/SQ/$seqStr/$fy';
  }

  DateTime? _parseSafeDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _deriveWarranty(Map<String, dynamic> machine) {
    final wEnd = _parseSafeDate(machine['warrantyEndDate']);
    final amcEnd = _parseSafeDate(machine['amcEndDate']);
    final now = DateTime.now();

    if (amcEnd != null) return amcEnd.isAfter(now) ? 'AMC Active' : 'AMC Expired';
    if (wEnd != null) return wEnd.isAfter(now) ? 'Under Warranty' : 'Out Of Warranty';
    return (machine['isWarranty'] == true || machine['isWarranty'] == 'true') ? 'Under Warranty' : 'Out Of Warranty';
  }

  String _deriveSeverity(Map<String, dynamic> machine) {
    final priority = (machine['priority'] ?? '').toString();
    final mStatus = (machine['machineStatus'] ?? '').toString();
    final cat = (machine['complaintCategory'] ?? machine['serviceCategory'] ?? '').toString().toLowerCase();

    if (priority == 'Critical' || mStatus == 'Breakdown' || mStatus == 'Shutdown') return 'Emergency';
    if (priority == 'High' || cat.contains('complaint')) return 'Critical';
    if (priority == 'Medium') return 'Important';
    return 'Normal';
  }

  String _getFinancialYearFromDate(DateTime date) {
    int year = date.year;
    int month = date.month;
    if (month >= 4) {
      return '$year-${(year + 1).toString().substring(2)}';
    } else {
      return '${year - 1}-${year.toString().substring(2)}';
    }
  }

  Future<void> _loadExistingQuotation(Map<String, dynamic> data) async {
    _approvalStatus = data['approvalStatus']?.toString() ?? 'Waiting Customer Approval';
    _quotationStatus = data['status']?.toString() ?? 'Draft';
    _paymentStatus = data['paymentStatus']?.toString() ?? 'Pending';
    _currentVersion = data['version'] ?? 1;
    _visitRequired.value = data['visitRequired'] ?? false;
    _packingChargesExtra.value = data['packingChargesExtra'] ?? true;

    if ((_approvalStatus == 'Approved' || _quotationStatus == 'Converted To Work Order') && !_isAdminOrManager) {
      _isReadOnly.value = true;
    }

    _quoteDate = _parseSafeDate(data['quoteDate'])?.toUtc() ?? DateTime.now().toUtc();
    _fullExistingQuoteNumber = data['quoteNumber']?.toString() ?? '';

    final quoteParts = _fullExistingQuoteNumber.split('/');
    if (quoteParts.length >= 3) {
      _quotationSequenceController.text = quoteParts[2];
    } else {
      _quotationSequenceController.text = quoteParts.length > 1 ? quoteParts[1] : '';
    }

    _subjectController.text = data['remarks']?.toString() ?? data['subject']?.toString() ?? '';
    _followUpNotesController.text = data['followUpNotes']?.toString() ?? '';
    _nextFollowUpDate = _parseSafeDate(data['nextFollowUpDate'])?.toUtc();

    _selectedCustomerId = data['customerId']?.toString();
    _selectedAddressId = data['addressId']?.toString();
    _selectedContactId = data['contactId']?.toString();

    if (_selectedCustomerId != null) {
      await _loadCustomerFromFirestore(_selectedCustomerId!, skipOverrides: true);
    }

    if (data['addressSnapshot'] != null && data['addressSnapshot'] is Map) {
      _selectedAddressData = Map<String, dynamic>.from(data['addressSnapshot']);
      _updateAddressSnapshots(_selectedAddressData, restoreMode: true);
    } else {
      _customerPrimaryAddressSnapshot = data['addressLine']?.toString() ?? data['clientAddress']?.toString() ?? '';
      _customerPrimaryCitySnapshot = data['city']?.toString() ?? '';
      _customerPrimaryStateSnapshot = data['state']?.toString() ?? data['customerState']?.toString() ?? '';
      _customerPrimaryPincodeSnapshot = data['pincode']?.toString() ?? '';
      _addressController.text = _customerPrimaryAddressSnapshot;
      _customerState = _customerPrimaryStateSnapshot.toLowerCase();
    }

    if (data['contactSnapshot'] != null && data['contactSnapshot'] is Map) {
      _selectedContactData = Map<String, dynamic>.from(data['contactSnapshot']);
      _updateContactSnapshots(_selectedContactData, restoreMode: true);
    } else {
      _contactPersonSnapshot = data['contactPerson']?.toString() ?? '';
      _contactEmailSnapshot = data['contactEmail']?.toString() ?? data['clientEmail']?.toString() ?? '';
      _contactMobileSnapshot = data['contactMobile']?.toString() ?? data['clientMobile']?.toString() ?? '';
      _contactDesignationSnapshot = data['contactDesignation']?.toString() ?? '';

      _contactPersonController.text = _contactPersonSnapshot;
      _emailController.text = _contactEmailSnapshot;
      _mobileController.text = _contactMobileSnapshot;
      _contactDesignationController.text = _contactDesignationSnapshot;
    }

    _clientNameController.text = data['clientName']?.toString() ?? data['customerName']?.toString() ?? '';
    _gstController.text = data['gstNo']?.toString() ?? '';
    _isInterState = data['isInterState'] as bool? ?? false;

    _linkedServiceRequestId = data['serviceRequestId']?.toString();
    _linkedServiceRequestNumber = data['serviceRequestNumber']?.toString();
    _serviceRequestNumberController.text = _linkedServiceRequestNumber ?? '';

    _selectedRequestSource = data['requestSource']?.toString() ?? data['quotationSource']?.toString() ?? 'Verbal';
    _requestDate = _parseSafeDate(data['requestDate'])?.toUtc() ?? DateTime.now().toUtc();
    _serviceRefNoteController.text = data['serviceReference']?.toString() ?? '';

    _signNameController.text = data['signatureName']?.toString() ?? _signNameController.text;
    _signDesignationController.text = data['signatureDesignation']?.toString() ?? _signDesignationController.text;
    _signPhoneController.text = data['signaturePhone']?.toString() ?? _signPhoneController.text;

    List<ext_models.QuotationLineItem> legacyItems = [];
    if (data['items'] != null && data['items'] is List) {
      legacyItems = await _hydrateItems(data['items'] as List);
    } else if (data['lineItems'] != null && data['lineItems'] is List) {
      legacyItems = await _hydrateItems(data['lineItems'] as List);
    }

    String loadedModel = data['machineModel']?.toString() ?? '';
    if (loadedModel.isEmpty && data['machines'] != null && (data['machines'] as List).isNotEmpty) {
      loadedModel = (data['machines'] as List)[0]['machineModel']?.toString() ?? '';
    }

    _machine.value = MachineFormState(
      machineUid: _uuid.v4(),
      model: loadedModel,
      serial: data['serialNumber']?.toString() ?? '',
      complaint: data['complaintDescription']?.toString() ?? '',
      customerRemarks: '',
      warrantyStatus: data['warrantyStatus']?.toString() ?? 'Out Of Warranty',
      isWarranty: data['isWarranty'] == true,
      serviceCategory: data['serviceCategory'] ?? 'General',
      severity: data['severity'] ?? 'Normal',
      items: legacyItems,
    );

    if (data['visitCharges'] != null && data['visitCharges'] is List) {
      _visitCharges.value = (data['visitCharges'] as List)
          .map((e) => ext_models.VisitCharge.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data['dynamicTerms'] != null && data['dynamicTerms'] is List) {
      _dynamicTerms.value = (data['dynamicTerms'] as List)
          .map((e) => TermRow(id: e['id']?.toString() ?? _uuid.v4(), title: e['title']?.toString() ?? '', value: e['value']?.toString() ?? ''))
          .toList();
    }

    _checkInterState();
  }

  Future<void> _applyServiceRequestSeedIfNeeded() async {
    final seed = widget.serviceRequestSeed;
    if (seed == null || seed.isEmpty) return;

    _linkedServiceRequestId = seed['id']?.toString() ?? seed['serviceRequestId']?.toString();
    _linkedServiceRequestNumber = seed['serviceRequestNumber']?.toString() ?? seed['requestNumber']?.toString();
    _serviceRequestNumberController.text = _linkedServiceRequestNumber ?? '';
    _selectedRequestSource = 'Service Request';

    _requestDate = _parseSafeDate(seed['requestDate'])?.toUtc() ?? _parseSafeDate(seed['createdAt'])?.toUtc() ?? DateTime.now().toUtc();

    _clientNameController.text = (seed['customerName'] ?? seed['companyName'] ?? '').toString().trim();
    _contactPersonController.text = (seed['contactPerson'] ?? '').toString().trim();
    _emailController.text = (seed['email'] ?? '').toString().trim();
    _mobileController.text = (seed['mobileNumber'] ?? seed['mobile'] ?? '').toString().trim();
    _addressController.text = (seed['address'] ?? '').toString().trim();
    _gstController.text = (seed['gstNo'] ?? seed['gst'] ?? '').toString().trim();

    _selectedCustomerId = seed['customerId']?.toString();
    _customerState = (seed['state'] ?? '').toString().toLowerCase();

    _subjectController.text = (seed['subject'] ?? seed['requestSubject'] ?? 'Quotation for Service/Spares').toString().trim();

    final notes = (seed['notes'] ?? seed['description'] ?? seed['serviceReference'] ?? '').toString().trim();
    final loc = (seed['location'] ?? seed['city'] ?? '').toString().trim();
    List<String> combinedNotes = [];
    if (loc.isNotEmpty) combinedNotes.add("Location: $loc");
    if (notes.isNotEmpty) combinedNotes.add("Notes: $notes");
    if (combinedNotes.isNotEmpty) _serviceRefNoteController.text = combinedNotes.join('\n');

    if (_selectedCustomerId != null) {
      await _loadCustomerFromFirestore(_selectedCustomerId!);
    }

    _checkInterState();

    List<ext_models.QuotationLineItem> legacyItems = [];
    if (seed['requiredParts'] != null && seed['requiredParts'] is List) {
      legacyItems = await _hydrateItems(seed['requiredParts'] as List);
    } else if (seed['items'] != null && seed['items'] is List) {
      legacyItems = await _hydrateItems(seed['items'] as List);
    }

    _machine.value = MachineFormState(
      machineUid: _uuid.v4(),
      model: (seed['machineModel'] ?? seed['serviceItemName'] ?? '').toString().trim(),
      serial: (seed['serialNumber'] ?? '').toString().trim(),
      complaint: (seed['complaintDescription'] ?? '').toString().trim(),
      warrantyStatus: _deriveWarranty(seed),
      isWarranty: seed['isWarranty'] == true || seed['isWarranty'] == 'true',
      serviceCategory: seed['complaintCategory'] ?? seed['serviceCategory'] ?? 'General',
      severity: _deriveSeverity(seed),
      items: legacyItems,
    );

    if (mounted) {
      _recalculateTaxes();
    }
  }

  Future<List<ext_models.QuotationLineItem>> _hydrateItems(List rawItems) async {
    List<Future<ext_models.QuotationLineItem?>> tasks = [];
    for (var rawItem in rawItems) {
      if (rawItem is Map) {
        tasks.add(_hydrateSingleItem(Map<String, dynamic>.from(rawItem)));
      }
    }
    final results = await Future.wait(tasks);
    return results.whereType<ext_models.QuotationLineItem>().toList();
  }

  Future<ext_models.QuotationLineItem?> _hydrateSingleItem(Map<String, dynamic> i) async {
    String productId = (i['productId'] ?? i['partId'] ?? i['itemId'] ?? '').toString();
    String name = (i['name'] ?? i['itemName'] ?? i['partName'] ?? i['productName'] ?? '').toString();
    double qty = double.tryParse(i['quantity']?.toString() ?? i['qty']?.toString() ?? '1') ?? 1.0;
    double price = double.tryParse(i['unitPrice']?.toString() ?? i['rate']?.toString() ?? '0') ?? 0.0;
    double disc = double.tryParse(i['discountPercent']?.toString() ?? i['discount']?.toString() ?? '0') ?? 0.0;
    double totalGst = double.tryParse(i['gstPercentage']?.toString() ?? i['tax']?.toString() ?? '18') ?? 18.0;

    final id = (i['id'] ?? i['itemId'] ?? _uuid.v4()).toString();

    _itemExtras[id] = {
      'productId': productId,
      'sku': i['sku'] ?? i['partNo'] ?? i['partCode'] ?? '',
      'brand': i['brand'] ?? '',
      'productNature': i['productNature'] ?? i['itemType'] ?? i['partNature'] ?? 'Spare',
      'baseGst': totalGst,
      'cgstPercent': _isInterState ? 0 : totalGst / 2,
      'sgstPercent': _isInterState ? 0 : totalGst / 2,
      'igstPercent': _isInterState ? totalGst : 0,
      'availableStock': double.tryParse(i['availableStock']?.toString() ?? '0') ?? 0.0,
    };

    return ext_models.QuotationLineItem(
      itemId: id,
      itemName: name,
      itemType: _itemExtras[id]!['productNature'] as String,
      qty: qty,
      rate: price,
      discount: disc,
      amount: (qty * price) * (1 - (disc / 100)),
      partNo: _itemExtras[id]!['sku'] as String,
      hsnCode: (i['hsnCode'] ?? '').toString(),
      uom: (i['uom'] ?? 'Nos').toString(),
    );
  }

  Future<void> _loadCustomerFromFirestore(String customerId, {bool skipOverrides = false}) async {
    if (_customersColl == null) return;
    try {
      final doc = await _customersColl!.doc(customerId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (!skipOverrides) _selectedCustomerId = customerId;

        if (!skipOverrides && _clientNameController.text.trim().isEmpty) {
          _clientNameController.text = (data['companyName'] ?? data['name'] ?? '').toString();
        }
        if (!skipOverrides && _gstController.text.trim().isEmpty) {
          _gstController.text = (data['gstNo'] ?? data['gst'] ?? '').toString();
        }

        if (data['addresses'] != null && data['addresses'] is List) {
          _customerAddresses = List<Map<String, dynamic>>.from(data['addresses']);
        }

        if (data['contacts'] != null && data['contacts'] is List) {
          _customerContacts = List<Map<String, dynamic>>.from(data['contacts']);
        }

        if (!skipOverrides) {
          final primaryBillingMatches = _customerAddresses.where((a) => a['isBillingAddress'] == true && a['isPrimary'] == true);
          final primaryMatches = _customerAddresses.where((a) => a['isPrimary'] == true);

          _selectedAddressData = primaryBillingMatches.isNotEmpty ? primaryBillingMatches.first : (primaryMatches.isNotEmpty ? primaryMatches.first : (_customerAddresses.isNotEmpty ? _customerAddresses.first : null));
          _selectedAddressId = _selectedAddressData?['id'];
          _updateAddressSnapshots(_selectedAddressData);

          if (_selectedContactId == null) {
            final primaryContact = _customerContacts.isNotEmpty ? _customerContacts.first : null;
            if (primaryContact != null) {
              _selectedContactId = primaryContact['id'];
              _selectedContactData = primaryContact;
              _updateContactSnapshots(_selectedContactData);
            } else {
              _emailController.text = (data['email'] ?? '').toString();
              _mobileController.text = (data['mobile'] ?? data['phone'] ?? '').toString();
              _contactPersonController.text = (data['contactPerson'] ?? data['contactName'] ?? '').toString();
              _contactDesignationController.text = (data['designation'] ?? '').toString();

              _contactEmailSnapshot = _emailController.text.trim();
              _contactMobileSnapshot = _mobileController.text.trim();
              _contactPersonSnapshot = _contactPersonController.text.trim();
              _contactDesignationSnapshot = _contactDesignationController.text.trim();
            }
          }
        }

        if (!skipOverrides) _fetchCustomerInsights(customerId);
      }
    } catch (e, st) {
      debugPrint('Customer fetch error: $e\n$st');
    }
  }

  Future<void> _fetchCustomerInsights(String custId) async {
    if (_quotesColl == null) return;
    try {
      final snaps = await _quotesColl!
          .where('customerId', isEqualTo: custId)
          .orderBy('createdAt', descending: true)
          .get();

      double totalVal = 0;
      double lastQuote = 0;
      if (snaps.docs.isNotEmpty) {
        lastQuote = double.tryParse((snaps.docs.first.data() as Map<String, dynamic>)['finalTotal']?.toString() ?? '0') ?? 0.0;
        for (var d in snaps.docs) {
          totalVal += double.tryParse((d.data() as Map<String, dynamic>)['finalTotal']?.toString() ?? '0') ?? 0.0;
        }
      }
      _customerInsights.value = {'count': snaps.docs.length, 'totalValue': totalVal, 'lastQuoteAmount': lastQuote};
    } catch (e, st) {
      debugPrint('Insights lookup error: $e\n$st');
    }
  }

  Future<Map<String, dynamic>?> _selectCustomerDialog() async {
    String searchText = '';
    Timer? debounce;
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Customer', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, or email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (value) {
                    searchText = value.trim().toLowerCase();
                    if (debounce?.isActive ?? false) debounce!.cancel();
                    debounce = Timer(const Duration(milliseconds: 500), () async {
                      if (!ctx.mounted) return;
                      if (searchText.isEmpty) {
                        setDialogState(() { searchResults = []; isSearching = false; });
                        return;
                      }
                      setDialogState(() => isSearching = true);
                      try {
                        if (_customersColl == null) throw Exception("No company context");
                        final snap = await _customersColl!
                            .where('isActive', isEqualTo: true)
                            .where('searchKeywords', arrayContains: searchText)
                            .limit(30)
                            .get();

                        if (ctx.mounted) {
                          setDialogState(() {
                            searchResults = snap.docs.map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)}).toList();
                            isSearching = false;
                          });
                        }
                      } catch (e, st) {
                        debugPrint('Customer search error: $e\n$st');
                        if (ctx.mounted) setDialogState(() => isSearching = false);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : searchResults.isEmpty
                      ? const Center(child: Text('Type to search customers...', style: TextStyle(color: textMuted)))
                      : ListView.separated(
                    itemCount: searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = searchResults[index];
                      final name = (data['companyName'] ?? data['name'] ?? 'Unknown').toString();
                      final phone = (data['phone'] ?? data['mobile'] ?? '').toString();
                      final email = (data['email'] ?? '').toString();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.business, color: primaryColor),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$phone ${email.isNotEmpty ? " | $email" : ""}'),
                        onTap: () {
                          Navigator.pop(context, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
          ],
        ),
      ),
    );
    debounce?.cancel();
    return result;
  }

  void _updateAddressSnapshots(Map<String, dynamic>? address, {bool restoreMode = false}) {
    if (address == null) return;
    final addr = (address['combinedAddress'] ?? address['address'] ?? address['addressLine'] ?? '').toString().trim();
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
      if (_addressController.text.trim().isEmpty && addr.isNotEmpty) _addressController.text = addr;
      if (_customerPrimaryCitySnapshot.trim().isEmpty && city.isNotEmpty) _customerPrimaryCitySnapshot = city;
      if (_customerPrimaryStateSnapshot.trim().isEmpty && state.isNotEmpty) {
        _customerState = state.toLowerCase();
        _customerPrimaryStateSnapshot = state;
      }
      if (_customerPrimaryPincodeSnapshot.trim().isEmpty && pincode.isNotEmpty) _customerPrimaryPincodeSnapshot = pincode;
    }
    _checkInterState();
  }

  void _updateContactSnapshots(Map<String, dynamic>? contactData, {bool restoreMode = false}) {
    if (contactData == null) {
      if (!restoreMode) {
        _contactEmailSnapshot = '';
        _contactMobileSnapshot = '';
        _contactPersonSnapshot = '';
        _contactDesignationSnapshot = '';
        _contactPersonController.clear();
        _emailController.clear();
        _mobileController.clear();
        _contactDesignationController.clear();
      }
      return;
    }

    final cName = (contactData['name'] ?? contactData['contactName'] ?? '').toString().trim();
    final cEmail = (contactData['emailNormalized'] ?? contactData['email'] ?? '').toString().trim();
    final cPhone = (contactData['phoneNormalized'] ?? contactData['phone'] ?? contactData['mobile'] ?? '').toString().trim();
    final cDesig = (contactData['designation'] ?? '').toString().trim();

    if (!restoreMode) {
      _contactPersonController.text = cName;
      _contactPersonSnapshot = cName;
      _emailController.text = cEmail;
      _contactEmailSnapshot = cEmail;
      _mobileController.text = cPhone;
      _contactMobileSnapshot = cPhone;
      _contactDesignationController.text = cDesig;
      _contactDesignationSnapshot = cDesig;
    } else {
      if (_contactPersonController.text.trim().isEmpty && cName.isNotEmpty) _contactPersonController.text = cName;
      if (_emailController.text.trim().isEmpty && cEmail.isNotEmpty) _emailController.text = cEmail;
      if (_mobileController.text.trim().isEmpty && cPhone.isNotEmpty) _mobileController.text = cPhone;
      if (_contactDesignationController.text.trim().isEmpty && cDesig.isNotEmpty) _contactDesignationController.text = cDesig;
    }
  }

  // ===========================================================================
  // --- 5. MACHINE & ITEMS LOGIC ---
  // ===========================================================================

  void _updateMachine(MachineFormState newMachine) {
    _machine.value = newMachine;
  }

  void _onItemsChanged(List<ext_models.QuotationLineItem> extItems) {
    List<ext_models.QuotationLineItem> newInternalItems = [];
    for (var ext in extItems) {
      final existingMatches = _machine.value.items.where((i) => i.itemId == ext.itemId);
      final existing = existingMatches.isNotEmpty ? existingMatches.first : null;
      if (existing != null) {
        newInternalItems.add(existing.copyWith(
          qty: ext.qty,
          rate: ext.rate,
          discount: ext.discount,
        ));
        _itemExtras[existing.itemId] ??= {};
        _itemExtras[existing.itemId]!['productNature'] = ext.itemType;
      } else {
        newInternalItems.add(ext_models.QuotationLineItem(
          itemId: ext.itemId.isNotEmpty ? ext.itemId : _uuid.v4(),
          itemName: ext.itemName,
          itemType: ext.itemType,
          qty: ext.qty,
          rate: ext.rate,
          discount: ext.discount,
          amount: (ext.qty * ext.rate) * (1 - (ext.discount / 100)),
          partNo: ext.partNo,
          hsnCode: ext.hsnCode,
          uom: ext.uom ?? 'Nos',
        ));
        _itemExtras[newInternalItems.last.itemId] = {
          'productNature': ext.itemType,
          'sku': ext.partNo,
          'baseGst': 18.0,
          'cgstPercent': _isInterState ? 0 : 9,
          'sgstPercent': _isInterState ? 0 : 9,
          'igstPercent': _isInterState ? 18 : 0,
        };
      }
    }

    _machine.value = _machine.value.copyWith(items: newInternalItems);
    _recalculateTaxes();
  }

  void _onVisitChargesChanged(List<ext_models.VisitCharge> updatedCharges) {
    _visitCharges.value = updatedCharges;
    _calculateTotals();
  }

  // ===========================================================================
  // --- 6. CALCULATIONS ---
  // ===========================================================================

  Map<String, double> _calculateGstSplits(double totalGst) {
    if (_isInterState) {
      return {'cgst': 0.0, 'sgst': 0.0, 'igst': totalGst};
    } else {
      return {'cgst': totalGst / 2, 'sgst': totalGst / 2, 'igst': 0.0};
    }
  }

  void _checkInterState() {
    _isInterState = _companyState.isNotEmpty && _customerState.isNotEmpty && _companyState != _customerState;
    _recalculateTaxes();
  }

  void _recalculateTaxes() {
    final currentMachine = _machine.value;
    for (var item in currentMachine.items) {
      final extras = _itemExtras[item.itemId] ?? {};
      double totalGst = (double.tryParse(extras['cgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(extras['sgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(extras['igstPercent']?.toString() ?? '0') ?? 0.0);

      if (totalGst == 0) totalGst = double.tryParse(extras['baseGst']?.toString() ?? '0') ?? 0.0;

      if (totalGst > 0) {
        final splits = _calculateGstSplits(totalGst);
        extras['cgstPercent'] = splits['cgst']!;
        extras['sgstPercent'] = splits['sgst']!;
        extras['igstPercent'] = splits['igst']!;
      }
      _itemExtras[item.itemId] = extras;
    }

    // Trigger total calculation naturally
    _machine.value = currentMachine.copyWith();
    _calculateTotals();
  }

  void _calculateTotals() {
    double globalSub = 0.0, globalItemDisc = 0.0, globalCgst = 0.0, globalSgst = 0.0, globalIgst = 0.0;
    double visitTotalAmt = 0.0;

    final currentMachine = _machine.value;
    double mSub = 0, mDisc = 0, mCgst = 0, mSgst = 0, mIgst = 0;

    for (var item in currentMachine.items) {
      double amt = item.qty * item.rate;
      double dAmt = amt * (item.discount / 100);
      double taxable = amt - dAmt;

      mSub += amt;
      mDisc += dAmt;

      final extras = _itemExtras[item.itemId] ?? {};
      double cgstP = double.tryParse(extras['cgstPercent']?.toString() ?? '0') ?? 0.0;
      double sgstP = double.tryParse(extras['sgstPercent']?.toString() ?? '0') ?? 0.0;
      double igstP = double.tryParse(extras['igstPercent']?.toString() ?? '0') ?? 0.0;

      mCgst += taxable * (cgstP / 100);
      mSgst += taxable * (sgstP / 100);
      mIgst += taxable * (igstP / 100);
    }

    double mTaxable = mSub - mDisc;
    double mGrand = mTaxable + mCgst + mSgst + mIgst;

    final mTotals = QuotationTotals(
        subtotal: mSub,
        itemDiscount: mDisc,
        taxableAmount: mTaxable,
        cgst: mCgst, sgst: mSgst, igst: mIgst,
        grandTotal: mGrand
    );

    _machine.value = currentMachine.copyWith(totals: mTotals);

    globalSub += mSub;
    globalItemDisc += mDisc;
    globalCgst += mCgst;
    globalSgst += mSgst;
    globalIgst += mIgst;

    for (var vc in _visitCharges.value) {
      double amt = vc.amount;
      visitTotalAmt += amt;

      const double gstP = 18.0; // Standard GST for visit charges
      final splits = _calculateGstSplits(gstP);

      globalCgst += amt * (splits['cgst']! / 100);
      globalSgst += amt * (splits['sgst']! / 100);
      globalIgst += amt * (splits['igst']! / 100);
    }

    double taxableAmt = (globalSub - globalItemDisc) + visitTotalAmt;
    double grandTot = taxableAmt + globalCgst + globalSgst + globalIgst;
    double finalTot = grandTot.roundToDouble();
    double round = finalTot - grandTot;

    _globalTotals.value = QuotationTotals(
      subtotal: globalSub,
      visitChargesTotal: visitTotalAmt,
      itemDiscount: globalItemDisc,
      taxableAmount: taxableAmt,
      cgst: globalCgst,
      sgst: globalSgst,
      igst: globalIgst,
      grandTotal: grandTot,
      finalTotal: finalTot,
      roundOff: round,
    );
  }

  int get _totalItemsCount => _machine.value.items.length + _visitCharges.value.length;

  // ===========================================================================
  // --- 7. SAVE LOGIC ---
  // ===========================================================================

  bool _isCustomerComplete() {
    return _selectedCustomerId != null || _clientNameController.text.trim().isNotEmpty;
  }

  bool _isMachineComplete() {
    return _machine.value.model.isNotEmpty;
  }

  bool _isItemsComplete() {
    return _machine.value.items.isNotEmpty || _visitCharges.value.isNotEmpty;
  }

  bool _validateBeforeSave() {
    if (_isReadOnly.value) {
      _showSnack('Document is locked for editing.', isError: true);
      return false;
    }
    if (!_isCustomerComplete()) {
      _showSnack('Please complete Customer Information.', isError: true);
      _customerTileCtrl.expand();
      return false;
    }
    if (_contactPersonController.text.trim().isEmpty) {
      _showSnack('Contact Person is required.', isError: true);
      _customerTileCtrl.expand();
      return false;
    }
    if (!_isMachineComplete()) {
      _showSnack('Please specify a Machine Model.', isError: true);
      _machineTileCtrl.expand();
      return false;
    }
    if (!_isItemsComplete()) {
      _showSnack('Add at least one service item or charge.', isError: true);
      _itemsTileCtrl.expand();
      return false;
    }

    final reqDate = DateTime(_requestDate.year, _requestDate.month, _requestDate.day);
    final qDate = DateTime(_quoteDate.year, _quoteDate.month, _quoteDate.day);
    if (qDate.isBefore(reqDate)) {
      _showSnack('Quotation date cannot be earlier than Request date.', isError: true);
      return false;
    }
    return true;
  }

  String _quoteNumberRegistryId(String quoteNumber) {
    return quoteNumber.replaceAll('/', '_').replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }

  Future<void> _ensureExistingQuoteNumberIsUnique(String quoteNumber) async {
    if (_quotesColl == null) return;
    final snap = await _quotesColl!
        .where('quoteNumber', isEqualTo: quoteNumber)
        .limit(2)
        .get();
    final duplicateExists = snap.docs.any((doc) => doc.id != widget.quotationId);
    if (duplicateExists) throw Exception('Quotation number $quoteNumber already exists.');
  }

  Future<void> _saveQuotation() async {
    if (!_validateBeforeSave()) return;
    _isLoading.value = true;

    try {
      final db = _db;
      final bool isUpdate = widget.quotationId != null;
      final bool isRevision = isUpdate && _createRevisionFlag.value;

      if (_quotesColl == null) throw Exception("Company context lost.");

      final docRef = (isUpdate && !isRevision)
          ? _quotesColl!.doc(widget.quotationId)
          : _quotesColl!.doc();

      final financialYear = _getFinancialYearFromDate(_quoteDate);
      String manualSequenceStr = _quotationSequenceController.text.trim();
      int? manualSequence;

      if (manualSequenceStr.isNotEmpty) {
        manualSequence = int.tryParse(manualSequenceStr);
        if (manualSequence == null) throw Exception('Invalid sequence number format.');
        await _ensureExistingQuoteNumberIsUnique('$_quotationPrefix/SQ/${manualSequence.toString().padLeft(3, '0')}/$financialYear');
      }

      Map<String, dynamic> payload = _buildQuotationData(docRef.id);

      final activityLog = {
        'type': isRevision ? 'Revision Created' : (isUpdate ? 'Updated' : 'Created'),
        'status': _quotationStatus,
        'timestamp': Timestamp.now(),
        'byUid': _currentUserUid,
        'byName': _currentUserName,
        'note': isRevision ? 'Revision created from ${widget.quotationId}' : 'Service Quotation saved.',
      };
      payload['activities'] = FieldValue.arrayUnion([activityLog]);

      if (!isUpdate || isRevision) {
        payload['createdBy'] = _currentUserUid;
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['version'] = isRevision ? _currentVersion + 1 : (isUpdate ? _currentVersion : 1);
        payload['isLatest'] = true;
        payload['parentQuotationId'] = isRevision ? widget.quotationId : null;
      }

      bool autoAdjusted = await _executeSaveTransaction(db, docRef, payload, isRevision, manualSequence, financialYear);

      if (!_isReadOnly.value) {
        await db.collection('quotationSettings').doc(_currentUserUid).set({
          'dynamicTerms': _dynamicTerms.value.map((e) => {'id': e.id, 'title': e.titleCtrl.text.trim(), 'value': e.valueCtrl.text.trim()}).toList(),
          'packingChargesExtra': _packingChargesExtra.value,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        if (autoAdjusted) {
          _showSnack('Quotation number already exists. Next available number selected.', isError: false);
        } else {
          _showSnack(isRevision ? 'Revision Created!' : 'Service Quotation Saved!');
        }
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      debugPrint('Save Failed: $e\n$st');
      _showSnack('Save Failed: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<bool> _executeSaveTransaction(FirebaseFirestore db, DocumentReference docRef, Map<String, dynamic> payload, bool isRevision, int? manualSequence, String financialYear) async {
    bool autoAdjusted = false;
    await db.runTransaction((tx) async {
      int? sequenceToSync;
      final counterRef = _companyDoc!.collection('counters').doc('service_quotation_counter_$financialYear');
      final counterDoc = await tx.get(counterRef);
      final currentSequence = ((counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0);

      String safeQuoteNumber = '';
      final allowedReservations = { docRef.id, if (widget.quotationId != null) widget.quotationId! };

      if (isRevision) {
        safeQuoteNumber = _fullExistingQuoteNumber;
        payload['quoteNumber'] = safeQuoteNumber;
        payload['financialYear'] = safeQuoteNumber.split('/').last;
      } else {
        if (manualSequence == null) {
          int nextSequence = currentSequence + 1;
          for (int attempt = 0; attempt < 10000; attempt++) {
            safeQuoteNumber = '$_quotationPrefix/SQ/${nextSequence.toString().padLeft(3, '0')}/$financialYear';
            final numberRef = _companyDoc!.collection('service_quotation_numbers').doc(_quoteNumberRegistryId(safeQuoteNumber));
            final numberDocSnap = await tx.get(numberRef);
            final reservedFor = numberDocSnap.data()?['quotationId']?.toString();

            if (!numberDocSnap.exists || (reservedFor == null) || allowedReservations.contains(reservedFor)) {
              sequenceToSync = nextSequence;
              if (nextSequence > currentSequence + 1) autoAdjusted = true;
              break;
            }
            nextSequence++;
          }
        } else {
          safeQuoteNumber = '$_quotationPrefix/SQ/${manualSequence.toString().padLeft(3, '0')}/$financialYear';
          if (manualSequence > currentSequence) sequenceToSync = manualSequence;

          final numberRef = _companyDoc!.collection('service_quotation_numbers').doc(_quoteNumberRegistryId(safeQuoteNumber));
          final numberDocSnap = await tx.get(numberRef);
          final reservedFor = numberDocSnap.data()?['quotationId']?.toString();

          if (numberDocSnap.exists && reservedFor != null && reservedFor.isNotEmpty && !allowedReservations.contains(reservedFor)) {
            throw Exception('This quotation number already exists.');
          }
        }

        final numberRef = _companyDoc!.collection('service_quotation_numbers').doc(_quoteNumberRegistryId(safeQuoteNumber));
        final numberDocSnapshot = await tx.get(numberRef);

        payload['quoteNumber'] = safeQuoteNumber;
        payload['financialYear'] = safeQuoteNumber.split('/').last;

        tx.set(numberRef, {
          'quoteNumber': safeQuoteNumber,
          'quotationId': docRef.id,
          'companyId': _companyId,
          'sequence': manualSequence ?? sequenceToSync,
          'financialYear': payload['financialYear'],
          'prefix': _quotationPrefix,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!numberDocSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (sequenceToSync != null) {
          tx.set(counterRef, {'sequence': sequenceToSync, 'prefix': _quotationPrefix, 'financialYear': financialYear, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }

      if (isRevision && widget.quotationId != null) {
        final oldRef = _quotesColl!.doc(widget.quotationId);
        tx.set(oldRef, {'isLatest': false, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': _currentUserUid}, SetOptions(merge: true));
      }

      tx.set(docRef, payload, SetOptions(merge: true));
    });
    return autoAdjusted;
  }

  Map<String, dynamic> _buildLegacyPayload(MachineFormState? machine) {
    return {
      'machineModel': machine?.model ?? '',
      'serialNumber': machine?.serial ?? '',
      'complaintDescription': machine?.complaint ?? '',
      'warrantyStatus': machine?.warrantyStatus ?? '',
      'serviceCategory': machine?.serviceCategory ?? '',
      'severity': machine?.severity ?? '',
    };
  }

  Map<String, dynamic> _buildQuotationData(String docId) {
    final machineState = _machine.value;
    final machinesData = [machineState.toMap(_itemExtras)];
    final flatItems = machineState.items.map((e) => {...e.toMap(), ...(_itemExtras[e.itemId] ?? {})}).toList();

    return {
      'id': docId,
      'companyId': _companyId,
      'subject': _subjectController.text.trim(),
      'remarks': _subjectController.text.trim(),
      'quoteDate': Timestamp.fromDate(_quoteDate),
      'status': _quotationStatus,
      'approvalStatus': _approvalStatus,
      'paymentStatus': _paymentStatus,
      'visitRequired': _visitRequired.value,

      ..._buildLegacyPayload(machineState),

      'machines': machinesData,
      'machineCount': 1,

      'customerId': _selectedCustomerId,
      'addressId': _selectedAddressId,
      'contactId': _selectedContactId,
      'addressSnapshot': _selectedAddressData,
      'contactSnapshot': _selectedContactData,
      'clientName': _clientNameController.text.trim(),
      'customerName': _clientNameController.text.trim(),
      'clientAddress': _addressController.text.trim(),
      'addressLine': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : _customerPrimaryAddressSnapshot,
      'city': _customerPrimaryCitySnapshot,
      'state': _customerPrimaryStateSnapshot,
      'pincode': _customerPrimaryPincodeSnapshot,
      'clientEmail': _emailController.text.trim(),
      'clientMobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim().isNotEmpty ? _contactPersonController.text.trim() : _contactPersonSnapshot,
      'contactDesignation': _contactDesignationController.text.trim().isNotEmpty ? _contactDesignationController.text.trim() : _contactDesignationSnapshot,
      'contactEmail': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : _contactEmailSnapshot,
      'contactMobile': _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : _contactMobileSnapshot,
      'gstNo': _gstController.text.trim(),
      'isInterState': _isInterState,
      'customerState': _customerState,
      'contactPersonId': _selectedContactId,

      'serviceRequestId': _linkedServiceRequestId ?? '',
      'serviceRequestNumber': _serviceRequestNumberController.text.trim(),
      'requestSource': _selectedRequestSource,
      'quotationSource': _selectedRequestSource == 'Service Request' ? 'Service Request' : 'Manual',
      'requestDate': Timestamp.fromDate(_requestDate),
      'serviceReference': _serviceRefNoteController.text.trim(),
      'nextFollowUpDate': _nextFollowUpDate != null ? Timestamp.fromDate(_nextFollowUpDate!) : null,
      'followUpNotes': _followUpNotesController.text.trim(),

      'totalSubtotal': _globalTotals.value.subtotal,
      'subtotal': _globalTotals.value.subtotal,
      'totalVisitCharges': _globalTotals.value.visitChargesTotal,
      'totalTaxableAmount': _globalTotals.value.taxableAmount,
      'totalCgst': _globalTotals.value.cgst,
      'totalSgst': _globalTotals.value.sgst,
      'totalIgst': _globalTotals.value.igst,
      'taxAmount': _globalTotals.value.cgst + _globalTotals.value.sgst + _globalTotals.value.igst,
      'grandTotal': _globalTotals.value.grandTotal,
      'finalTotal': _globalTotals.value.finalTotal,
      'roundOff': _globalTotals.value.roundOff,

      'dynamicTerms': _dynamicTerms.value.map((e) => {'id': e.id, 'title': e.titleCtrl.text.trim(), 'value': e.valueCtrl.text.trim()}).toList(),
      'packingChargesExtra': _packingChargesExtra.value,
      'dispatchRequired': _packingChargesExtra.value,
      'items': flatItems,
      'lineItems': flatItems,
      'visitCharges': _visitCharges.value.map((e) => e.toMap()).toList(),

      'signatureName': _signNameController.text.trim(),
      'signatureDesignation': _signDesignationController.text.trim(),
      'signaturePhone': _signPhoneController.text.trim(),
      'updatedBy': _currentUserUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'isDeleted': false,
    };
  }

  ext_models.ServiceQuotationModel _buildExternalModel() {
    return ext_models.ServiceQuotationModel(
      quotationId: widget.quotationId ?? '',
      quotationNumber: _fullExistingQuoteNumber.isNotEmpty ? _fullExistingQuoteNumber : _getLiveQuoteNumberDisplay(),
      requestId: _linkedServiceRequestId ?? '',
      requestNumber: _serviceRequestNumberController.text,
      visitId: '',
      visitNumber: '',
      customerId: _selectedCustomerId ?? '',
      customerName: _clientNameController.text.isNotEmpty ? _clientNameController.text : 'Unknown',
      quotationType: _selectedRequestSource,
      quotationSource: _selectedRequestSource,
      billingType: _isInterState ? 'IGST' : 'CGST/SGST',
      followUpAction: '',
      dispatchRequired: _packingChargesExtra.value,
      installationRequired: false,
      visitRequired: _visitRequired.value,
      status: _quotationStatus,
      paymentStatus: _paymentStatus,
      approvalStatus: _approvalStatus,
      subtotal: _globalTotals.value.subtotal,
      discount: _globalTotals.value.itemDiscount,
      taxAmount: _globalTotals.value.cgst + _globalTotals.value.sgst + _globalTotals.value.igst,
      grandTotal: _globalTotals.value.grandTotal,
      remarks: _subjectController.text,
      machines: [
        ext_models.QuotationMachine(
            machineId: _machine.value.productId ?? _machine.value.machineUid,
            machineName: _machine.value.model,
            machineModel: _machine.value.model,
            serialNumber: _machine.value.serial,
            warrantyStatus: _machine.value.warrantyStatus
        )
      ],
      lineItems: _machine.value.items,
      visitCharges: _visitCharges.value,
      attachments: [],
    );
  }

  // ===========================================================================
  // --- 8. PDF LOGIC ---
  // ===========================================================================

  Map<String, dynamic> _buildPreviewData() {
    final firstMachine = _machine.value;

    return {
      'quoteNumber': _getLiveQuoteNumberDisplay(),
      'quoteDateStr': '${_quoteDate.day.toString().padLeft(2, '0')}/${_quoteDate.month.toString().padLeft(2, '0')}/${_quoteDate.year}',
      'version': _currentVersion.toString(),
      'approvalStatus': _approvalStatus,
      'paymentStatus': _paymentStatus,
      'serviceRequestNumber': _serviceRequestNumberController.text.trim(),
      'subject': _subjectController.text.trim(),
      'remarks': _subjectController.text.trim(),

      ..._buildLegacyPayload(firstMachine),

      'clientName': _clientNameController.text.trim(),
      'customerName': _clientNameController.text.trim(),
      'clientAddress': _addressController.text.trim(),
      'clientEmail': _emailController.text.trim(),
      'clientMobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'gstNo': _gstController.text.trim(),
      'customerState': _customerState,
      'isInterState': _isInterState,
      'addressSnapshot': _selectedAddressData,
      'contactSnapshot': _selectedContactData,

      'totalSubtotal': _globalTotals.value.subtotal,
      'subtotal': _globalTotals.value.subtotal,
      'totalVisitCharges': _globalTotals.value.visitChargesTotal,
      'totalTaxableAmount': _globalTotals.value.taxableAmount,
      'totalCgst': _globalTotals.value.cgst,
      'totalSgst': _globalTotals.value.sgst,
      'totalIgst': _globalTotals.value.igst,
      'taxAmount': _globalTotals.value.cgst + _globalTotals.value.sgst + _globalTotals.value.igst,
      'grandTotal': _globalTotals.value.grandTotal,
      'finalTotal': _globalTotals.value.finalTotal,

      'dynamicTerms': _dynamicTerms.value.map((e) => {'id': e.id, 'title': e.titleCtrl.text.trim(), 'value': e.valueCtrl.text.trim()}).toList(),
      'packingChargesExtra': _packingChargesExtra.value,
      'dispatchRequired': _packingChargesExtra.value,
      'visitCharges': _visitCharges.value.map((e) => e.toMap()).toList(),

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

  void _previewPdf() {
    bool hasAnyItem = _visitCharges.value.isNotEmpty || _machine.value.items.isNotEmpty;
    if (!hasAnyItem) { _showSnack('Add items before previewing.', isError: true); return; }

    final items = _machine.value.items;

    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(
        title: const Text('Quotation Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 1,
      ),
      body: PdfPreview(
        build: (format) => ServiceQuotationPdfGenerator.generateServiceQuotationPdf(_buildPreviewData(), items),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    )));
  }

  // ===========================================================================
  // --- 9. HELPERS (Action Callbacks) ---
  // ===========================================================================

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openRequest() {
    if (_linkedServiceRequestId != null && _linkedServiceRequestId!.isNotEmpty) {
      _showSnack('Opening Linked Request: $_linkedServiceRequestId');
    } else {
      _showSnack('No linked request available.', isError: true);
    }
  }

  void _openVisit() {
    _showSnack('Opening Visit record...');
  }

  void _duplicateQuotation() {
    _showSnack('Duplication module triggered...');
  }

  void _deleteQuotation() {
    _showSnack('Soft delete scheduled...');
  }

  // ===========================================================================
  // --- 10. UI BUILDERS ---
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
        shape: const Border(bottom: BorderSide(color: borderLight, width: 1)),
        title: Text(widget.quotationId != null ? 'Edit Service Quotation' : 'New Service Quotation', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Preview'),
            style: TextButton.styleFrom(foregroundColor: primaryColor, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildReadOnlyBannerIfNecessary(),
                          _buildTopSummaryCard(),
                          const SizedBox(height: 16),

                          _buildCustomerExpansionTile(),
                          const SizedBox(height: 12),

                          _buildMachineExpansionTile(),
                          const SizedBox(height: 12),

                          _buildItemsExpansionTile(),
                          const SizedBox(height: 12),

                          _buildFinancialExpansionTile(),
                          const SizedBox(height: 12),

                          _buildTermsExpansionTile(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, loading, child) {
                return loading ? Container(color: Colors.white.withValues(alpha: 0.7), child: const Center(child: CircularProgressIndicator())) : const SizedBox.shrink();
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyBannerIfNecessary() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isReadOnly,
      builder: (context, readOnly, _) {
        if (!readOnly) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
          child: Row(
            children: [
              Icon(Icons.lock, color: Colors.green.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('This document is $_approvalStatus and locked.', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopSummaryCard() {
    return ValueListenableBuilder<MachineFormState>(
        valueListenable: _machine,
        builder: (context, machineState, _) {
          return ValueListenableBuilder<QuotationTotals>(
              valueListenable: _globalTotals,
              builder: (context, totals, _) {
                final customerName = _clientNameController.text.isNotEmpty ? _clientNameController.text : 'Unknown Customer';
                final machineModel = machineState.model.isNotEmpty ? machineState.model : 'No Machine Selected';
                final int count = _totalItemsCount;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.request_quote_rounded, color: primaryColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                            const SizedBox(height: 4),
                            Text('$machineModel • $count Items', style: const TextStyle(color: textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${totals.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Text(_quotationStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          )
                        ],
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildSectionExpansionTile({
    required ExpansionTileController controller,
    required String title,
    required IconData icon,
    required bool isComplete,
    required Widget child,
    VoidCallback? onNext,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: borderLight)),
      child: ExpansionTile(
        controller: controller,
        maintainState: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: isComplete ? Colors.green : accentColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
        trailing: isComplete
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.expand_more, color: textMuted),
        children: [
          Padding(
            padding: const EdgeInsets.all(20).copyWith(top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                if (onNext != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Next'),
                    ),
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCustomerExpansionTile() {
    return _buildSectionExpansionTile(
        controller: _customerTileCtrl,
        title: '1. Customer Information',
        icon: Icons.business,
        isComplete: _isCustomerComplete(),
        onNext: () {
          _customerTileCtrl.collapse();
          _machineTileCtrl.expand();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isReadOnly.value)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final c = await _selectCustomerDialog();
                    if (c != null && c['id'] != null) await _loadCustomerFromFirestore(c['id']);
                  },
                  icon: const Icon(Icons.search, size: 16), label: const Text('CRM Lookup', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), foregroundColor: primaryColor),
                ),
              ),
            const SizedBox(height: 16),
            _buildItemTextField(_clientNameController, 'Company Name *', validator: (v) => v!.isEmpty ? 'Required' : null),
            Row(
              children: [
                Expanded(child: _buildItemTextField(_contactPersonController, 'Contact Person *', validator: (v) => v!.isEmpty ? 'Required' : null)),
                const SizedBox(width: 16),
                Expanded(child: _buildItemTextField(_contactDesignationController, 'Designation')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildItemTextField(_mobileController, 'Mobile')),
                const SizedBox(width: 16),
                Expanded(child: _buildItemTextField(_emailController, 'Email ID')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildItemTextField(_addressController, 'Billing Address', maxLines: 2)),
                const SizedBox(width: 16),
                Expanded(child: _buildItemTextField(_gstController, 'GSTIN')),
              ],
            ),
          ],
        )
    );
  }

  Widget _buildMachineExpansionTile() {
    return ValueListenableBuilder<MachineFormState>(
        valueListenable: _machine,
        builder: (context, machineState, _) {
          return _buildSectionExpansionTile(
              controller: _machineTileCtrl,
              title: '2. Machine Information',
              icon: Icons.precision_manufacturing,
              isComplete: _isMachineComplete(),
              onNext: () {
                _machineTileCtrl.collapse();
                _itemsTileCtrl.expand();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildCategoryDropdown(machineState)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSubcategoryDropdown(machineState)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMachineTypeDropdown(machineState)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMachineModelDropdown(machineState)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: machineState.serial,
                          readOnly: _isReadOnly.value,
                          decoration: InputDecoration(
                            labelText: 'Serial Number', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                            isDense: true, filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
                          ),
                          onChanged: (v) => _updateMachine(machineState.copyWith(serial: v)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                            value: machineState.warrantyStatus,
                            decoration: InputDecoration(
                              labelText: 'Warranty Status', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                              isDense: true, filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
                            ),
                            items: ['Under Warranty', 'Out Of Warranty', 'AMC Active', 'AMC Expired']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: _isReadOnly.value ? null : (v) {
                              if (v != null) {
                                _updateMachine(machineState.copyWith(
                                    warrantyStatus: v,
                                    isWarranty: v == 'Under Warranty' || v == 'AMC Active'
                                ));
                              }
                            },
                          )
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: machineState.complaint,
                    readOnly: _isReadOnly.value,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Complaint / Requirement', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                      isDense: true, filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
                    ),
                    onChanged: (v) => _updateMachine(machineState.copyWith(complaint: v)),
                  ),
                ],
              )
          );
        }
    );
  }

  Widget _buildItemsExpansionTile() {
    return ValueListenableBuilder<MachineFormState>(
        valueListenable: _machine,
        builder: (context, machineState, _) {
          return ValueListenableBuilder<List<ext_models.VisitCharge>>(
              valueListenable: _visitCharges,
              builder: (context, vCharges, _) {
                return _buildSectionExpansionTile(
                  controller: _itemsTileCtrl,
                  title: '3. Items',
                  icon: Icons.build_circle_outlined,
                  isComplete: _isItemsComplete(),
                  onNext: () {
                    _itemsTileCtrl.collapse();
                    _financeTileCtrl.expand();
                  },
                  child: ServiceItemsSection(
                    companyId: _companyId,
                    selectedMachineModel: machineState.model,
                    machineSerialNumber: machineState.serial,
                    machineWarrantyStatus: machineState.warrantyStatus,
                    lineItems: machineState.items,
                    visitCharges: vCharges,
                    onItemsChanged: _onItemsChanged,
                    onVisitChargesChanged: _onVisitChargesChanged,
                    isReadOnly: _isReadOnly.value,
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildFinancialExpansionTile() {
    return ValueListenableBuilder<QuotationTotals>(
        valueListenable: _globalTotals,
        builder: (context, totals, _) {
          return _buildSectionExpansionTile(
              controller: _financeTileCtrl,
              title: '4. Financial Summary',
              icon: Icons.account_balance_wallet,
              isComplete: true, // Auto computes
              onNext: () {
                _financeTileCtrl.collapse();
                _termsTileCtrl.expand();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: borderLight),
                        borderRadius: BorderRadius.circular(12)
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRowItem('Items Total', totals.subtotal),
                        _buildSummaryRowItem('Charges Total', totals.visitChargesTotal),
                        _buildSummaryRowItem('Discount', -totals.itemDiscount, isDeduction: true),
                        const Divider(height: 24, thickness: 1),
                        _buildSummaryRowItem('Taxable Amount', totals.taxableAmount, isBold: true),
                        if (totals.cgst > 0) _buildSummaryRowItem('CGST', totals.cgst),
                        if (totals.sgst > 0) _buildSummaryRowItem('SGST', totals.sgst),
                        if (totals.igst > 0) _buildSummaryRowItem('IGST', totals.igst),
                        _buildSummaryRowItem('Round Off', totals.roundOff),
                        const Divider(height: 24, thickness: 1),
                        _buildSummaryRowItem('Grand Total', totals.finalTotal, isGrandTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                      valueListenable: _packingChargesExtra,
                      builder: (context, val, _) => SwitchListTile(
                        title: const Text('Packing & Forwarding Extra', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Add remark that packing & transport are extra at actuals', style: TextStyle(fontSize: 12, color: textMuted)),
                        value: val,
                        activeColor: primaryColor,
                        contentPadding: EdgeInsets.zero,
                        onChanged: _isReadOnly.value ? null : (newVal) => _packingChargesExtra.value = newVal,
                      )
                  ),
                  const SizedBox(height: 8),
                  _buildItemTextField(
                      _subjectController,
                      'Remarks (Optional)',
                      maxLines: 2,
                      hint: 'Additional notes or remarks...'
                  ),
                ],
              )
          );
        }
    );
  }

  Widget _buildSummaryRowItem(String label, double amount, {bool isBold = false, bool isGrandTotal = false, bool isDeduction = false}) {
    if (amount == 0 && !isGrandTotal && !isBold) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              label,
              style: TextStyle(
                  fontSize: isGrandTotal ? 16 : 13,
                  fontWeight: (isBold || isGrandTotal) ? FontWeight.bold : FontWeight.normal,
                  color: isGrandTotal ? textDark : textMuted
              )
          ),
          Text(
              '${isDeduction ? '-' : ''}₹${amount.abs().toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: isGrandTotal ? 18 : 13,
                  fontWeight: (isBold || isGrandTotal) ? FontWeight.bold : FontWeight.w600,
                  color: isGrandTotal ? Colors.green : (isDeduction ? Colors.red : textDark)
              )
          ),
        ],
      ),
    );
  }

  Widget _buildTermsExpansionTile() {
    return _buildSectionExpansionTile(
        controller: _termsTileCtrl,
        title: '5. Terms & Conditions',
        icon: Icons.gavel_outlined,
        isComplete: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<bool>(
                valueListenable: _isReadOnly,
                builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : OutlinedButton.icon(
                  onPressed: () {
                    final currentTerms = List<TermRow>.from(_dynamicTerms.value);
                    currentTerms.add(TermRow(id: _uuid.v4()));
                    _dynamicTerms.value = currentTerms;
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Term', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), foregroundColor: textDark, side: const BorderSide(color: borderLight)),
                )
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<List<TermRow>>(
              valueListenable: _dynamicTerms,
              builder: (context, terms, _) {
                return Container(
                    decoration: BoxDecoration(border: Border.all(color: borderLight), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(8)), border: Border(bottom: BorderSide(color: borderLight))),
                          child: const Row(
                            children: [
                              SizedBox(width: 32),
                              Expanded(flex: 3, child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted))),
                              Expanded(flex: 7, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted))),
                              SizedBox(width: 48),
                            ],
                          ),
                        ),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: terms.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final currentTerms = List<TermRow>.from(_dynamicTerms.value);
                            final item = currentTerms.removeAt(oldIndex);
                            currentTerms.insert(newIndex, item);
                            _dynamicTerms.value = currentTerms;
                          },
                          itemBuilder: (ctx, i) {
                            return Material(
                              key: ValueKey(terms[i].id),
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white, border: i != terms.length - 1 ? const Border(bottom: BorderSide(color: borderLight)) : null),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        color: Colors.transparent,
                                        child: const Icon(Icons.drag_indicator, color: textMuted, size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 3, child: TextFormField(
                                      controller: terms[i].titleCtrl,
                                      readOnly: _isReadOnly.value,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textDark),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                    )),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 7, child: TextFormField(
                                      controller: terms[i].valueCtrl,
                                      readOnly: _isReadOnly.value,
                                      maxLines: null,
                                      style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: textDark),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                    )),
                                    SizedBox(
                                      width: 40,
                                      child: ValueListenableBuilder<bool>(
                                          valueListenable: _isReadOnly,
                                          builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () {
                                              final currentTerms = List<TermRow>.from(_dynamicTerms.value);
                                              final removed = currentTerms.removeAt(i);
                                              removed.dispose();
                                              _dynamicTerms.value = currentTerms;
                                            },
                                          )
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      ],
                    )
                );
              },
            ),
          ],
        )
    );
  }

  Widget _buildBottomActionBar() {
    return ValueListenableBuilder<MachineFormState>(
        valueListenable: _machine,
        builder: (ctx, _, __) => ValueListenableBuilder<QuotationTotals>(
            valueListenable: _globalTotals,
            builder: (ctx, ___, ____) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.quotationId != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: _createRevisionFlag,
                            builder: (ctx, isRev, _) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Save as Revision', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900)),
                                  Switch(value: isRev, activeColor: Colors.orange.shade600, onChanged: _isReadOnly.value ? null : (v) => _createRevisionFlag.value = v),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  QuotationBottomActionBar(
                    quotation: _buildExternalModel(),
                    onSaveDraft: () {
                      _quotationStatus = 'Draft';
                      _saveQuotation();
                    },
                    onSendQuote: () {
                      _quotationStatus = 'Sent';
                      _saveQuotation();
                    },
                    onPreviewPdf: _previewPdf,
                    onRefresh: _initializeScreen,
                    onOpenRequest: _openRequest,
                    onOpenVisit: _openVisit,
                    onDuplicate: _duplicateQuotation,
                    onDelete: _deleteQuotation,
                  )
                ]
            )
        )
    );
  }

  // ===========================================================================
  // --- 11. UI COMPONENT HELPERS ---
  // ===========================================================================

  Widget _buildItemTextField(TextEditingController controller, String label, {TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator, int? maxLines = 1, String? hint, Function(String)? onChanged, bool readOnlyOverride = false, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
          const SizedBox(height: 6),
          ValueListenableBuilder<bool>(
            valueListenable: _isReadOnly,
            builder: (context, readOnly, _) {
              bool effReadOnly = readOnly || readOnlyOverride;
              return TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                validator: validator,
                maxLines: maxLines,
                onChanged: onChanged,
                readOnly: effReadOnly,
                style: const TextStyle(fontWeight: FontWeight.w500, color: textDark),
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryColor, width: 2)),
                  isDense: true, filled: true, fillColor: effReadOnly ? Colors.grey.shade50 : Colors.white,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(MachineFormState machine) {
    return StreamBuilder<QuerySnapshot>(
        stream: _companyDoc?.collection('inventory_categories').where('isActive', isEqualTo: true).snapshots(),
        builder: (ctx, snap) {
          List<DropdownMenuItem<String>> items = [];
          if (snap.hasData) {
            items = snap.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text((doc['name'] ?? '').toString(), style: const TextStyle(fontSize: 14)))).toList();
          }

          if (machine.categoryId != null && !items.any((e) => e.value == machine.categoryId)) {
            items.insert(0, DropdownMenuItem(value: machine.categoryId, child: const Text('Unknown Category')));
          }

          return DropdownButtonFormField<String>(
            value: machine.categoryId,
            decoration: InputDecoration(
              labelText: 'Category', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
              isDense: true, filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
            ),
            items: items.isEmpty ? null : items,
            onChanged: _isReadOnly.value ? null : (val) {
              _updateMachine(machine.clearCascade(1).copyWith(categoryId: val));
            },
          );
        }
    );
  }

  Widget _buildSubcategoryDropdown(MachineFormState machine) {
    return StreamBuilder<QuerySnapshot>(
        stream: machine.categoryId != null ? _companyDoc?.collection('inventory_categories').doc(machine.categoryId).collection('subcategories').where('isActive', isEqualTo: true).snapshots() : null,
        builder: (ctx, snap) {
          List<DropdownMenuItem<String>> items = [];
          if (snap.hasData) {
            items = snap.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text((doc['name'] ?? '').toString(), style: const TextStyle(fontSize: 14)))).toList();
          }

          if (machine.subcategoryId != null && !items.any((e) => e.value == machine.subcategoryId)) {
            items.insert(0, DropdownMenuItem(value: machine.subcategoryId, child: const Text('Unknown Subcategory')));
          }

          return DropdownButtonFormField<String>(
            value: machine.subcategoryId,
            decoration: InputDecoration(
              labelText: 'Subcategory', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
              isDense: true, filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
            ),
            items: machine.categoryId == null ? null : items,
            onChanged: _isReadOnly.value ? null : (val) {
              _updateMachine(machine.clearCascade(2).copyWith(subcategoryId: val));
            },
          );
        }
    );
  }

  Widget _buildMachineTypeDropdown(MachineFormState machine) {
    return StreamBuilder<QuerySnapshot>(
        stream: _companyDoc?.collection('inventory_machine_types').where('isActive', isEqualTo: true).snapshots(),
        builder: (ctx, snap) {
          List<DropdownMenuItem<String>> items = [];
          if (snap.hasData) {
            items = snap.data!.docs.map((doc) => DropdownMenuItem(value: (doc['name'] ?? '').toString(), child: Text((doc['name'] ?? '').toString(), style: const TextStyle(fontSize: 14)))).toList();
          }

          if (machine.machineType != null && !items.any((e) => e.value == machine.machineType)) {
            items.insert(0, DropdownMenuItem(value: machine.machineType, child: Text(machine.machineType!)));
          }

          return DropdownButtonFormField<String>(
            value: machine.machineType,
            decoration: InputDecoration(
              labelText: 'Machine Type / Series', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
              isDense: true, filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
            ),
            items: items.isEmpty ? null : items,
            onChanged: _isReadOnly.value ? null : (val) {
              _updateMachine(machine.clearCascade(3).copyWith(machineType: val));
            },
          );
        }
    );
  }

  Widget _buildMachineModelDropdown(MachineFormState machine) {
    Stream<QuerySnapshot>? queryStream;

    if (machine.categoryId != null && machine.subcategoryId != null && machine.machineType != null) {
      queryStream = _companyDoc?.collection('products')
          .where('isActive', isEqualTo: true)
          .where('productNatureLower', isEqualTo: 'machine')
          .where('categoryId', isEqualTo: machine.categoryId)
          .where('subcategoryId', isEqualTo: machine.subcategoryId)
          .where('machineType', isEqualTo: machine.machineType)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
        stream: queryStream,
        builder: (ctx, snap) {
          List<DropdownMenuItem<String>> items = [];
          if (snap.hasData) {
            items = snap.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text((doc['name'] ?? '').toString(), style: const TextStyle(fontSize: 14)))).toList();
          }

          if (machine.productId != null && !items.any((e) => e.value == machine.productId)) {
            items.insert(0, DropdownMenuItem(value: machine.productId, child: Text(machine.model.isNotEmpty ? machine.model : 'Unknown Model')));
          }

          return DropdownButtonFormField<String>(
            value: machine.productId,
            decoration: InputDecoration(
              labelText: 'Machine Model *', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
              isDense: true, filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
            ),
            items: queryStream == null ? null : items,
            onChanged: _isReadOnly.value ? null : (val) {
              if (val != null && snap.hasData) {
                final selectedDoc = snap.data!.docs.firstWhere((d) => d.id == val);
                final modelName = (selectedDoc['name'] ?? '').toString();
                _updateMachine(machine.copyWith(productId: val, model: modelName));
              }
            },
          );
        }
    );
  }
}