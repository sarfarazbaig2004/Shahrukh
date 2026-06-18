// FILE PATH: lib/modules/sales/quotations/create_service_quotation_screen.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';

import 'service_quotation_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);
const Color borderLight = Color(0xFFE2E8F0);
const Color textDark = Color(0xFF0F172A);
const Color textMuted = Color(0xFF64748B);
const String fallbackQuotationSeriesPrefix = 'MEM';

// ===========================================================================
// MODELS
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

class VisitChargeItem {
  final String id;
  String type;
  double quantity;
  double rate;
  double gstPercent;

  VisitChargeItem({
    required this.id,
    this.type = '',
    this.quantity = 1.0,
    this.rate = 0.0,
    this.gstPercent = 18.0,
  });

  double get amount => quantity * rate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'quantity': quantity,
      'rate': rate,
      'gstPercent': gstPercent,
      'amount': amount,
    };
  }

  factory VisitChargeItem.fromMap(Map<String, dynamic> map) {
    return VisitChargeItem(
      id: map['id']?.toString() ?? const Uuid().v4(),
      type: map['type']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '1.0') ?? 1.0,
      rate: double.tryParse(map['rate']?.toString() ?? '0.0') ?? 0.0,
      gstPercent: double.tryParse(map['gstPercent']?.toString() ?? '18.0') ?? 18.0,
    );
  }
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

class QuotationLineItem {
  final String id;
  final String productId;
  final String name;
  final String description;
  final String hsnCode;
  final double quantity;
  final String uom;
  final double unitPrice;
  final double discountPercent;
  double cgstPercent;
  double sgstPercent;
  double igstPercent;
  final double availableStock;

  QuotationLineItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.description,
    required this.hsnCode,
    required this.quantity,
    required this.uom,
    required this.unitPrice,
    required this.discountPercent,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.igstPercent,
    required this.availableStock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'description': description,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'uom': uom,
      'unitPrice': unitPrice,
      'discountPercent': discountPercent,
      'cgstPercent': cgstPercent,
      'sgstPercent': sgstPercent,
      'igstPercent': igstPercent,
      'availableStock': availableStock,
    };
  }

  factory QuotationLineItem.fromMap(Map<String, dynamic> map) {
    return QuotationLineItem(
      id: map['id']?.toString() ?? const Uuid().v4(),
      productId: map['productId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      hsnCode: map['hsnCode']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '1') ?? 1.0,
      uom: map['uom']?.toString() ?? 'Nos',
      unitPrice: double.tryParse(map['unitPrice']?.toString() ?? '0') ?? 0.0,
      discountPercent: double.tryParse(map['discountPercent']?.toString() ?? '0') ?? 0.0,
      cgstPercent: double.tryParse(map['cgstPercent']?.toString() ?? '0') ?? 0.0,
      sgstPercent: double.tryParse(map['sgstPercent']?.toString() ?? '0') ?? 0.0,
      igstPercent: double.tryParse(map['igstPercent']?.toString() ?? '0') ?? 0.0,
      availableStock: double.tryParse(map['availableStock']?.toString() ?? '0') ?? 0.0,
    );
  }
}

// ===========================================================================
// MAIN SCREEN
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
  // --- Core Form & State ---
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isReadOnly = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _visitRequired = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _packingChargesExtra = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _createRevisionFlag = ValueNotifier<bool>(false);

  final ValueNotifier<List<QuotationLineItem>> _items = ValueNotifier<List<QuotationLineItem>>([]);
  final ValueNotifier<List<VisitChargeItem>> _visitCharges = ValueNotifier<List<VisitChargeItem>>([]);
  final ValueNotifier<List<TermRow>> _dynamicTerms = ValueNotifier<List<TermRow>>([]);
  final ValueNotifier<QuotationTotals> _totals = ValueNotifier<QuotationTotals>(QuotationTotals.zero);
  final ValueNotifier<Map<String, dynamic>?> _customerInsights = ValueNotifier<Map<String, dynamic>?>(null);

  // --- Context & Meta ---
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

  bool get _isAdminOrManager => ['admin', 'manager', 'director', 'md', 'ceo', 'super_admin']
      .contains(_currentUserRole.toLowerCase());

  // --- Status Fields ---
  String _approvalStatus = 'Waiting Customer Approval';
  String _quotationStatus = 'Draft';
  String _paymentStatus = 'Pending';
  String _fullExistingQuoteNumber = '';
  int _nextSequencePreview = 1;

  // --- Date Fields ---
  DateTime _requestDate = DateTime.now().toUtc();
  DateTime _quoteDate = DateTime.now().toUtc();
  DateTime? _nextFollowUpDate;

  // --- Caches ---
  final Map<String, Map<String, dynamic>> _productCache = {};
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
  String _selectedRequestSource = 'Verbal';

  // --- Snapshots ---
  String _customerState = '';
  String _customerPrimaryAddressSnapshot = '';
  String _customerPrimaryCitySnapshot = '';
  String _customerPrimaryStateSnapshot = '';
  String _customerPrimaryPincodeSnapshot = '';
  String _contactPersonSnapshot = '';
  String _contactEmailSnapshot = '';
  String _contactMobileSnapshot = '';

  // --- Text Controllers ---
  late final List<TextEditingController> _allControllers;

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _quotationSequenceController = TextEditingController();
  final TextEditingController _serviceRequestNumberController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _machineModelController = TextEditingController();
  final TextEditingController _machineSerialController = TextEditingController();
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _followUpNotesController = TextEditingController();
  final TextEditingController _serviceRefNoteController = TextEditingController();
  final TextEditingController _signNameController = TextEditingController();
  final TextEditingController _signDesignationController = TextEditingController();
  final TextEditingController _signPhoneController = TextEditingController();

  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _allControllers = [
      _clientNameController, _addressController, _emailController, _mobileController,
      _contactPersonController, _gstController, _quotationSequenceController,
      _serviceRequestNumberController, _subjectController,
      _machineModelController, _machineSerialController, _complaintController,
      _followUpNotesController, _serviceRefNoteController,
      _signNameController, _signDesignationController, _signPhoneController
    ];

    _quotationSequenceController.addListener(() {
      if (mounted) setState(() {});
    });

    _initializeScreen();
  }

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
    _items.dispose();
    _visitCharges.dispose();
    _dynamicTerms.dispose();
    _totals.dispose();
    _customerInsights.dispose();
    super.dispose();
  }

  // ===========================================================================
  // INITIALIZATION & DATA LOADING
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
    } catch (e, st) {
      developer.log('Initialization Error', error: e, stackTrace: st);
      _showSnack('Failed to initialize screen properly.', isError: true);
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _loadUserContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No logged-in user.');

    final rootUserDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final rootData = rootUserDoc.data() ?? {};

    _currentUserUid = user.uid;
    _companyId = widget.companyId?.trim().isNotEmpty == true
        ? widget.companyId!.trim()
        : (rootData['activeCompanyId'] ?? rootData['companyId'] ?? '').toString().trim();
    _currentUserRole = (rootData['role'] ?? 'service').toString().trim();

    if (_companyId != null && _companyId!.isNotEmpty) {
      final compUserDoc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('users').doc(user.uid).get();
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
    if (_companyId == null || _companyId!.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).get();
    if (!doc.exists) return;
    final data = doc.data() ?? {};

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
    final doc = await FirebaseFirestore.instance.collection('quotationSettings').doc(_currentUserUid).get();
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
      final counterRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('counters').doc('service_quotation_counter_$financialYear');
      final counterDoc = await counterRef.get();
      final currentSequence = ((counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0);
      setState(() {
        _nextSequencePreview = currentSequence + 1;
      });
    } catch (_) {
      setState(() => _nextSequencePreview = 1);
    }
  }

  String _getLiveQuoteNumberDisplay() {
    final fy = _getFinancialYearFromDate(_quoteDate);
    String seqStr = _quotationSequenceController.text.trim();
    if (seqStr.isEmpty) {
      seqStr = _nextSequencePreview.toString().padLeft(3, '0');
    } else {
      int? parsed = int.tryParse(seqStr);
      if (parsed != null) seqStr = parsed.toString().padLeft(3, '0');
    }
    return '$_quotationPrefix/SQ/$seqStr/$fy';
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

    _quoteDate = (data['quoteDate'] as Timestamp?)?.toDate().toUtc() ?? DateTime.now().toUtc();
    _fullExistingQuoteNumber = data['quoteNumber']?.toString() ?? '';

    final quoteParts = _fullExistingQuoteNumber.split('/');
    if (quoteParts.length >= 3) {
      _quotationSequenceController.text = quoteParts[2];
    } else {
      _quotationSequenceController.text = quoteParts.elementAtOrNull(1) ?? '';
    }

    _subjectController.text = data['subject']?.toString() ?? '';
    _machineModelController.text = data['machineModel']?.toString() ?? '';
    _machineSerialController.text = data['serialNumber']?.toString() ?? '';
    _complaintController.text = data['complaintDescription']?.toString() ?? '';
    _followUpNotesController.text = data['followUpNotes']?.toString() ?? '';
    _nextFollowUpDate = (data['nextFollowUpDate'] as Timestamp?)?.toDate().toUtc();

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
      _contactPersonController.text = _contactPersonSnapshot;
      _emailController.text = _contactEmailSnapshot;
      _mobileController.text = _contactMobileSnapshot;
    }

    _clientNameController.text = data['clientName']?.toString() ?? '';
    _gstController.text = data['gstNo']?.toString() ?? '';
    _isInterState = data['isInterState'] as bool? ?? false;

    _linkedServiceRequestId = data['serviceRequestId']?.toString();
    _linkedServiceRequestNumber = data['serviceRequestNumber']?.toString();
    _serviceRequestNumberController.text = _linkedServiceRequestNumber ?? '';

    _selectedRequestSource = data['requestSource']?.toString() ?? 'Verbal';
    _requestDate = (data['requestDate'] as Timestamp?)?.toDate().toUtc() ?? DateTime.now().toUtc();
    _serviceRefNoteController.text = data['serviceReference']?.toString() ?? '';

    _signNameController.text = data['signatureName']?.toString() ?? _signNameController.text;
    _signDesignationController.text = data['signatureDesignation']?.toString() ?? _signDesignationController.text;
    _signPhoneController.text = data['signaturePhone']?.toString() ?? _signPhoneController.text;

    if (data['items'] != null && data['items'] is List) {
      _items.value = await _hydrateItems(data['items'] as List);
    }

    if (data['visitCharges'] != null && data['visitCharges'] is List) {
      _visitCharges.value = (data['visitCharges'] as List)
          .map((e) => VisitChargeItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data['dynamicTerms'] != null && data['dynamicTerms'] is List) {
      _dynamicTerms.value = (data['dynamicTerms'] as List)
          .map((e) => TermRow(id: e['id']?.toString() ?? _uuid.v4(), title: e['title']?.toString() ?? '', value: e['value']?.toString() ?? ''))
          .toList();
    }

    _checkInterState();
    if (_selectedCustomerId != null) _fetchCustomerInsights(_selectedCustomerId!);
  }

  Future<void> _applyServiceRequestSeedIfNeeded() async {
    final seed = widget.serviceRequestSeed;
    if (seed == null || seed.isEmpty) return;

    _linkedServiceRequestId = seed['id']?.toString() ?? seed['serviceRequestId']?.toString();
    _linkedServiceRequestNumber = seed['serviceRequestNumber']?.toString() ?? seed['requestNo']?.toString();
    _serviceRequestNumberController.text = _linkedServiceRequestNumber ?? '';

    if (seed['requestDate'] != null && seed['requestDate'] is Timestamp) {
      _requestDate = (seed['requestDate'] as Timestamp).toDate().toUtc();
    } else if (seed['createdAt'] != null && seed['createdAt'] is Timestamp) {
      _requestDate = (seed['createdAt'] as Timestamp).toDate().toUtc();
    }

    _clientNameController.text = (seed['customerName'] ?? seed['companyName'] ?? '').toString().trim();
    _contactPersonController.text = (seed['contactPerson'] ?? '').toString().trim();
    _emailController.text = (seed['email'] ?? '').toString().trim();
    _mobileController.text = (seed['mobile'] ?? '').toString().trim();
    _addressController.text = (seed['address'] ?? '').toString().trim();
    _gstController.text = (seed['gstNo'] ?? '').toString().trim();

    _machineModelController.text = (seed['machineModel'] ?? '').toString().trim();
    _machineSerialController.text = (seed['serialNumber'] ?? '').toString().trim();
    _complaintController.text = (seed['complaintDescription'] ?? '').toString().trim();

    _selectedCustomerId = seed['customerId']?.toString();
    _customerState = (seed['state'] ?? '').toString().toLowerCase();

    _subjectController.text = (seed['subject'] ?? seed['requestSubject'] ?? 'Quotation for Service/Spares').toString().trim();

    final notes = (seed['notes'] ?? seed['description'] ?? seed['serviceReference'] ?? '').toString().trim();
    final loc = (seed['location'] ?? seed['customerPrimaryCity'] ?? '').toString().trim();
    List<String> combinedNotes = [];
    if (loc.isNotEmpty) combinedNotes.add("Location: $loc");
    if (notes.isNotEmpty) combinedNotes.add("Notes: $notes");
    if (combinedNotes.isNotEmpty) _serviceRefNoteController.text = combinedNotes.join('\n');

    if (_selectedCustomerId != null) {
      await _loadCustomerFromFirestore(_selectedCustomerId!);
    }

    _checkInterState();
    if (_selectedCustomerId != null) _fetchCustomerInsights(_selectedCustomerId!);

    final rawItems = seed['items'] ?? seed['products'];
    if (rawItems != null && rawItems is List) {
      _items.value = await _hydrateItems(rawItems);
      _recalculateTaxes();
    }
  }

  // ===========================================================================
  // DATA HYDRATION, CUSTOMERS & CALCULATIONS
  // ===========================================================================

  Future<List<QuotationLineItem>> _hydrateItems(List rawItems) async {
    List<Future<QuotationLineItem?>> tasks = [];
    for (var rawItem in rawItems) {
      if (rawItem is Map) {
        tasks.add(_hydrateSingleItem(Map<String, dynamic>.from(rawItem)));
      }
    }
    final results = await Future.wait(tasks);
    return results.whereType<QuotationLineItem>().toList();
  }

  Future<QuotationLineItem?> _hydrateSingleItem(Map<String, dynamic> i) async {
    String productId = (i['productId'] ?? i['itemId'] ?? '').toString();
    String name = (i['name'] ?? i['productName'] ?? '').toString();
    double qty = double.tryParse(i['quantity']?.toString() ?? '1') ?? 1.0;
    double price = double.tryParse(i['unitPrice']?.toString() ?? i['rate']?.toString() ?? '0') ?? 0.0;
    double disc = double.tryParse(i['discountPercent']?.toString() ?? '0') ?? 0.0;
    double totalGst = double.tryParse(i['gstPercentage']?.toString() ?? i['tax']?.toString() ?? '18') ?? 18.0;

    final id = (i['id'] ?? _uuid.v4()).toString();

    _itemExtras[id] = {
      'sku': i['sku'] ?? '',
      'brand': i['brand'] ?? '',
      'productNature': i['productNature'] ?? 'General',
      'baseGst': totalGst,
      'isScopeItem': i['isScopeItem'] ?? false,
      'parentId': i['parentId'],
      'isIncluded': i['isIncluded'] ?? true,
      'pricingMode': i['pricingMode'] ?? 'Included',
    };

    return QuotationLineItem(
      id: id,
      productId: productId,
      name: name,
      description: (i['description'] ?? '').toString(),
      hsnCode: (i['hsnCode'] ?? '').toString(),
      quantity: qty,
      uom: (i['uom'] ?? 'Nos').toString(),
      unitPrice: price,
      discountPercent: disc,
      cgstPercent: 0,
      sgstPercent: 0,
      igstPercent: totalGst,
      availableStock: 0,
    );
  }

  void _checkInterState() {
    _isInterState = _companyState.isNotEmpty && _customerState.isNotEmpty && _companyState != _customerState;
    _recalculateTaxes();
  }

  void _recalculateTaxes() {
    final updatedItems = List<QuotationLineItem>.from(_items.value);
    for (var item in updatedItems) {
      final extras = _itemExtras[item.id] ?? {};
      double totalGst = item.cgstPercent + item.sgstPercent + item.igstPercent;
      if (totalGst == 0) totalGst = double.tryParse(extras['baseGst']?.toString() ?? '0') ?? 0.0;

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
    _items.value = updatedItems;
    _calculateTotals();
  }

  void _calculateTotals() {
    double sub = 0.0, itemDisc = 0.0, cgst = 0.0, sgst = 0.0, igst = 0.0;
    double visitTotalAmt = 0.0;

    for (var item in _items.value) {
      final extras = _itemExtras[item.id] ?? {};
      if (extras['isScopeItem'] == true && extras['pricingMode'] == 'Included') continue;

      double amt = item.quantity * item.unitPrice;
      double dAmt = amt * (item.discountPercent / 100);
      double taxable = amt - dAmt;

      sub += amt;
      itemDisc += dAmt;
      cgst += taxable * (item.cgstPercent / 100);
      sgst += taxable * (item.sgstPercent / 100);
      igst += taxable * (item.igstPercent / 100);
    }

    for (var vc in _visitCharges.value) {
      double amt = vc.amount;
      visitTotalAmt += amt;
      double vCgst = 0.0, vSgst = 0.0, vIgst = 0.0;
      if (_isInterState) {
        vIgst = amt * (vc.gstPercent / 100);
      } else {
        vCgst = amt * ((vc.gstPercent / 2) / 100);
        vSgst = amt * ((vc.gstPercent / 2) / 100);
      }
      cgst += vCgst;
      sgst += vSgst;
      igst += vIgst;
    }

    double taxableAmt = (sub - itemDisc) + visitTotalAmt;
    double grandTot = taxableAmt + cgst + sgst + igst;
    double finalTot = grandTot.roundToDouble();
    double round = finalTot - grandTot;

    _totals.value = QuotationTotals(
      subtotal: sub,
      visitChargesTotal: visitTotalAmt,
      itemDiscount: itemDisc,
      taxableAmount: taxableAmt,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      grandTotal: grandTot,
      finalTotal: finalTot,
      roundOff: round,
    );
  }

  Future<void> _fetchCustomerInsights(String custId) async {
    if (_companyId == null) return;
    try {
      final snaps = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('service_quotations')
          .where('customerId', isEqualTo: custId)
          .orderBy('createdAt', descending: true)
          .get();

      double totalVal = 0;
      double lastQuote = 0;
      if (snaps.docs.isNotEmpty) {
        lastQuote = double.tryParse(snaps.docs.first.data()['finalTotal']?.toString() ?? '0') ?? 0.0;
        for (var d in snaps.docs) {
          totalVal += double.tryParse(d.data()['finalTotal']?.toString() ?? '0') ?? 0.0;
        }
      }
      _customerInsights.value = {'count': snaps.docs.length, 'totalValue': totalVal, 'lastQuoteAmount': lastQuote};
    } catch (_) {}
  }

  Future<void> _loadCustomerFromFirestore(String customerId, {bool skipOverrides = false}) async {
    if (_companyId == null || _companyId!.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('customers').doc(customerId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
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

              _contactEmailSnapshot = _emailController.text.trim();
              _contactMobileSnapshot = _mobileController.text.trim();
              _contactPersonSnapshot = _contactPersonController.text.trim();
            }
          }
        } else {
          if (_selectedAddressId != null && _customerAddresses.isNotEmpty) {
            try { _selectedAddressData = _customerAddresses.firstWhere((a) => a['id'] == _selectedAddressId); } catch(_) {}
          }
          if (_selectedContactId != null && _customerContacts.isNotEmpty) {
            try { _selectedContactData = _customerContacts.firstWhere((c) => c['id'] == _selectedContactId); } catch(_) {}
          }
        }

        if (mounted) setState(() {});
        if (!skipOverrides) _fetchCustomerInsights(customerId);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _selectCustomerDialog() async {
    String searchText = '';
    Timer? debounce;
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    return showDialog<Map<String, dynamic>>(
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
                      if (searchText.isEmpty) {
                        setDialogState(() { searchResults = []; isSearching = false; });
                        return;
                      }
                      setDialogState(() => isSearching = true);
                      try {
                        final snap = await FirebaseFirestore.instance
                            .collection('companies')
                            .doc(_companyId)
                            .collection('customers')
                            .where('isActive', isEqualTo: true)
                            .where('searchKeywords', arrayContains: searchText)
                            .limit(30)
                            .get();

                        setDialogState(() {
                          searchResults = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
                          isSearching = false;
                        });
                      } catch (e) {
                        setDialogState(() => isSearching = false);
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
                          backgroundColor: primaryColor.withOpacity(0.1),
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
        _contactPersonController.clear();
        _emailController.clear();
        _mobileController.clear();
      }
      return;
    }

    final cName = (contactData['name'] ?? contactData['contactName'] ?? '').toString().trim();
    final cEmail = (contactData['emailNormalized'] ?? contactData['email'] ?? '').toString().trim();
    final cPhone = (contactData['phoneNormalized'] ?? contactData['phone'] ?? contactData['mobile'] ?? '').toString().trim();

    if (!restoreMode) {
      _contactPersonController.text = cName;
      _contactPersonSnapshot = cName;
      _emailController.text = cEmail;
      _contactEmailSnapshot = cEmail;
      _mobileController.text = cPhone;
      _contactMobileSnapshot = cPhone;
    } else {
      if (_contactPersonController.text.trim().isEmpty && cName.isNotEmpty) _contactPersonController.text = cName;
      if (_emailController.text.trim().isEmpty && cEmail.isNotEmpty) _emailController.text = cEmail;
      if (_mobileController.text.trim().isEmpty && cPhone.isNotEmpty) _mobileController.text = cPhone;
    }
  }

  // ===========================================================================
  // LINE ITEM MODALS & HIERARCHY
  // ===========================================================================

  String _normalizeNature(String nature) {
    String lower = nature.toLowerCase().trim();
    if (lower.contains('accessory')) return 'Accessory';
    if (lower.contains('spare')) return 'Spare';
    if (lower.contains('consumable')) return 'Consumable';
    if (lower.contains('machine')) return 'Machine';
    return 'General';
  }

  Future<Map<String, dynamic>?> _selectProductDialog() async {
    String searchText = '';
    Timer? debounce;
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Service/Spares Master', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 700, height: 600,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(hintText: 'Search by name, SKU, or Code...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  onChanged: (value) {
                    searchText = value.trim().toLowerCase();
                    if (debounce?.isActive ?? false) debounce!.cancel();
                    debounce = Timer(const Duration(milliseconds: 500), () async {
                      if (searchText.isEmpty) {
                        setDialogState(() { searchResults = []; isSearching = false; });
                        return;
                      }
                      setDialogState(() => isSearching = true);
                      try {
                        final snap = await FirebaseFirestore.instance
                            .collection('companies')
                            .doc(_companyId)
                            .collection('products')
                            .where('isActive', isEqualTo: true)
                            .where('searchKeywords', arrayContains: searchText)
                            .limit(50)
                            .get();

                        final filtered = snap.docs.where((doc) {
                          final data = doc.data();
                          final n = _normalizeNature(data['productNature']?.toString() ?? '');
                          return ['Accessory', 'Spare', 'Consumable', 'Service'].contains(n) || n == 'General';
                        }).map((d) => {'id': d.id, ...d.data()}).toList();

                        setDialogState(() {
                          searchResults = filtered;
                          isSearching = false;
                        });
                      } catch (e) {
                        setDialogState(() => isSearching = false);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : searchResults.isEmpty
                      ? const Center(child: Text('Type to search Spares/Accessories/Services...', style: TextStyle(color: textMuted)))
                      : ListView.separated(
                    itemCount: searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = searchResults[index];
                      final stock = double.tryParse(data['stockOnHand']?.toString() ?? data['availableStock']?.toString() ?? data['qty']?.toString() ?? '0') ?? 0;
                      final nature = _normalizeNature(data['productNature']?.toString() ?? 'General');
                      final sellingPrice = double.tryParse(data['sellingPrice']?.toString() ?? data['price']?.toString() ?? '0') ?? 0.0;
                      final gst = data['gstPercentage']?.toString() ?? data['tax']?.toString() ?? '18';
                      final uom = (data['uom'] ?? 'Nos').toString();

                      Color natureColor = nature == 'Service' ? Colors.indigo : Colors.blue;

                      return ListTile(
                        leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: natureColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(nature == 'Service' ? Icons.build_circle : Icons.inventory_2, color: natureColor, size: 20)),
                        title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Price: ₹$sellingPrice | Tax: $gst% | Stock: $stock $uom'),
                        trailing: (stock <= 0 && nature != 'Service') ? const Icon(Icons.warning, color: Colors.orange) : const Icon(Icons.check_circle, color: Colors.green),
                        onTap: () {
                          _productCache[data['id']] = data;
                          Navigator.pop(context, {'stock': stock, ...data});
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }

  void _showAddItemModal([QuotationLineItem? itemToEdit, int? index]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: itemToEdit?.description ?? '');
    final hsnCtrl = TextEditingController(text: itemToEdit?.hsnCode ?? '');
    final qtyCtrl = TextEditingController(text: itemToEdit?.quantity.toString() ?? '1');
    final priceCtrl = TextEditingController(text: itemToEdit?.unitPrice.toString() ?? '');
    final uomCtrl = TextEditingController(text: itemToEdit?.uom ?? 'Nos');
    final discCtrl = TextEditingController(text: itemToEdit?.discountPercent.toString() ?? '0');

    double totalGst = (itemToEdit?.cgstPercent ?? 0) + (itemToEdit?.sgstPercent ?? 0) + (itemToEdit?.igstPercent ?? 0);
    final gstCtrl = TextEditingController(text: itemToEdit != null ? (totalGst > 0 ? totalGst.toString() : '18') : '18');

    String currentId = itemToEdit?.id ?? _uuid.v4();
    String productId = itemToEdit?.productId ?? '';
    double currentStock = itemToEdit?.availableStock ?? 0;

    String sku = _itemExtras[currentId]?['sku']?.toString() ?? '';
    String productNature = _itemExtras[currentId]?['productNature']?.toString() ?? 'General';
    List includedProducts = _itemExtras[currentId]?['includedProducts'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Form(
          key: formKey,
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(itemToEdit == null ? 'Add Service/Spare' : 'Edit Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                        TextButton.icon(
                          icon: const Icon(Icons.inventory_2),
                          label: const Text('Pick from Master'),
                          onPressed: () async {
                            final p = await _selectProductDialog();
                            if (p != null) {
                              setModalState(() {
                                productId = p['id'];
                                if (nameCtrl.text.isEmpty) nameCtrl.text = p['name'] ?? '';
                                if (descCtrl.text.isEmpty) descCtrl.text = p['description'] ?? '';
                                if (hsnCtrl.text.isEmpty) hsnCtrl.text = p['hsnCode'] ?? '';
                                double pPrice = double.tryParse(p['sellingPrice']?.toString() ?? '0') ?? 0.0;
                                if (priceCtrl.text.isEmpty || priceCtrl.text == '0') priceCtrl.text = pPrice.toString();
                                uomCtrl.text = p['uom'] ?? 'Nos';
                                gstCtrl.text = (p['gstPercentage'] ?? '18').toString();
                                currentStock = double.tryParse(p['stockOnHand']?.toString() ?? p['availableStock']?.toString() ?? '0') ?? 0.0;
                                productNature = _normalizeNature(p['productNature'] ?? 'General');
                                sku = p['sku'] ?? p['itemCode'] ?? '';
                                includedProducts = p['includedProducts'] as List? ?? [];
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildItemTextField(nameCtrl, 'Item Name *', validator: (v) => v!.isEmpty ? 'Required' : null),
                    _buildItemTextField(hsnCtrl, 'HSN / SAC Code'),
                    _buildItemTextField(descCtrl, 'Specification / Description', maxLines: null),
                    Row(
                      children: [
                        Expanded(child: _buildItemTextField(qtyCtrl, 'Quantity *', keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? '> 0 required' : null)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildItemTextField(uomCtrl, 'UOM')),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildItemTextField(priceCtrl, 'Unit Price *', keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildItemTextField(discCtrl, 'Discount (%)', keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null)),
                      ],
                    ),
                    _buildItemTextField(gstCtrl, 'GST (%)', keyboardType: TextInputType.number, validator: (v) {
                      double? g = double.tryParse(v ?? '');
                      if (g == null || g < 0 || g > 100) return '0-100 allowed';
                      return null;
                    }),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        double inputQty = double.tryParse(qtyCtrl.text) ?? 1;

                        if (productId.isNotEmpty && productNature != 'Service' && inputQty > currentStock) {
                          bool? proceed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Low Stock Warning'),
                                content: Text('You are adding $inputQty but available stock is only $currentStock. Proceed anyway?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
                                ],
                              )
                          );
                          if (proceed != true) return;
                        }

                        double gstVal = double.tryParse(gstCtrl.text) ?? 18;
                        double cgst = _isInterState ? 0 : gstVal / 2;
                        double sgst = _isInterState ? 0 : gstVal / 2;
                        double igst = _isInterState ? gstVal : 0;

                        final newItem = QuotationLineItem(
                          id: currentId,
                          productId: productId,
                          name: nameCtrl.text,
                          description: descCtrl.text,
                          hsnCode: hsnCtrl.text,
                          quantity: inputQty,
                          uom: uomCtrl.text.isEmpty ? 'Nos' : uomCtrl.text,
                          unitPrice: double.tryParse(priceCtrl.text) ?? 0,
                          discountPercent: double.tryParse(discCtrl.text) ?? 0,
                          cgstPercent: cgst,
                          sgstPercent: sgst,
                          igstPercent: igst,
                          availableStock: currentStock,
                        );

                        _itemExtras[currentId] = {
                          'sku': sku,
                          'productNature': productNature,
                          'baseGst': gstVal,
                          'parentId': null,
                          'isScopeItem': false,
                          'includedProducts': includedProducts,
                        };

                        final updatedList = List<QuotationLineItem>.from(_items.value);
                        if (index != null) updatedList[index] = newItem; else updatedList.add(newItem);
                        _items.value = updatedList;
                        _calculateTotals();
                        if (mounted) Navigator.pop(context);

                        if (index == null && productId.isNotEmpty) {
                          _triggerMachineAutomations(newItem, _productCache[productId] ?? {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: const Text('Save Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showScopeItemModal(String parentId, [QuotationLineItem? itemToEdit]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: itemToEdit?.description ?? '');
    final qtyCtrl = TextEditingController(text: itemToEdit?.quantity.toString() ?? '1');
    final uomCtrl = TextEditingController(text: itemToEdit?.uom ?? 'Nos');

    final childExtras = itemToEdit != null ? (_itemExtras[itemToEdit.id] ?? {}) : {};
    bool isIncluded = childExtras['isIncluded'] ?? true;
    String pricingMode = childExtras['pricingMode'] ?? 'Included';

    final priceCtrl = TextEditingController(text: itemToEdit?.unitPrice.toString() ?? '0');
    final discCtrl = TextEditingController(text: itemToEdit?.discountPercent.toString() ?? '0');

    double totalGst = (itemToEdit?.cgstPercent ?? 0) + (itemToEdit?.sgstPercent ?? 0) + (itemToEdit?.igstPercent ?? 0);
    if (totalGst == 0 && childExtras['baseGst'] != null) totalGst = double.tryParse(childExtras['baseGst'].toString()) ?? 0.0;
    final gstCtrl = TextEditingController(text: totalGst > 0 ? totalGst.toString() : '18');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Form(
          key: formKey,
          child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(itemToEdit == null ? 'Add Sub-Item' : 'Edit Sub-Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Included in Scope (Print in PDF)', style: TextStyle(fontWeight: FontWeight.w500)),
                        value: isIncluded,
                        activeColor: accentColor,
                        onChanged: (v) => setModalState(() => isIncluded = v ?? true),
                      ),
                      const SizedBox(height: 12),
                      _buildItemTextField(nameCtrl, 'Item Name *', validator: (v) => v!.isEmpty ? 'Required' : null),
                      _buildItemTextField(descCtrl, 'Description', maxLines: null),
                      Row(
                        children: [
                          Expanded(child: _buildItemTextField(qtyCtrl, 'Quantity', keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildItemTextField(uomCtrl, 'UOM')),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: pricingMode,
                        decoration: InputDecoration(labelText: 'Pricing Mode', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                        items: const [DropdownMenuItem(value: 'Included', child: Text('Included in Machine Price')), DropdownMenuItem(value: 'Separate', child: Text('Charge Separately'))],
                        onChanged: (v) => setModalState(() => pricingMode = v!),
                      ),
                      const SizedBox(height: 16),
                      if (pricingMode == 'Separate') ...[
                        Row(
                          children: [
                            Expanded(child: _buildItemTextField(priceCtrl, 'Unit Price', keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildItemTextField(discCtrl, 'Discount (%)', keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null)),
                          ],
                        ),
                        _buildItemTextField(gstCtrl, 'GST (%)', keyboardType: TextInputType.number, validator: (v) {
                          double? g = double.tryParse(v ?? '');
                          if (g == null || g < 0 || g > 100) return '0-100 allowed';
                          return null;
                        }),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;

                          double gstVal = double.tryParse(gstCtrl.text) ?? 18;
                          double cgst = _isInterState ? 0 : gstVal / 2;
                          double sgst = _isInterState ? 0 : gstVal / 2;
                          double igst = _isInterState ? gstVal : 0;

                          final newItem = QuotationLineItem(
                            id: itemToEdit?.id ?? _uuid.v4(),
                            productId: itemToEdit?.productId ?? '',
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            hsnCode: itemToEdit?.hsnCode ?? '',
                            quantity: double.tryParse(qtyCtrl.text) ?? 1,
                            uom: uomCtrl.text.isEmpty ? 'Nos' : uomCtrl.text,
                            unitPrice: double.tryParse(priceCtrl.text) ?? 0,
                            discountPercent: pricingMode == 'Separate' ? (double.tryParse(discCtrl.text) ?? 0) : 0,
                            cgstPercent: cgst,
                            sgstPercent: sgst,
                            igstPercent: igst,
                            availableStock: itemToEdit?.availableStock ?? 0,
                          );

                          _itemExtras[newItem.id] = {
                            ...?_itemExtras[newItem.id],
                            'baseGst': gstVal,
                            'isScopeItem': true,
                            'parentId': parentId,
                            'isIncluded': isIncluded,
                            'pricingMode': pricingMode,
                          };

                          final currentItems = List<QuotationLineItem>.from(_items.value);
                          if (itemToEdit != null) {
                            int idx = currentItems.indexWhere((i) => i.id == itemToEdit.id);
                            if (idx >= 0) currentItems[idx] = newItem;
                          } else {
                            int parentIdx = currentItems.indexWhere((i) => i.id == parentId);
                            if (parentIdx >= 0) {
                              int lastChildIdx = parentIdx;
                              for (int k = parentIdx + 1; k < currentItems.length; k++) {
                                if (_itemExtras[currentItems[k].id]?['parentId'] == parentId) lastChildIdx = k;
                                else break;
                              }
                              currentItems.insert(lastChildIdx + 1, newItem);
                            } else {
                              currentItems.add(newItem);
                            }
                          }
                          _items.value = currentItems;
                          _calculateTotals();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Save Scope Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }
          ),
        ),
      ),
    );
  }

  void _moveScopeItem(String childId, int direction) {
    int index = _items.value.indexWhere((i) => i.id == childId);
    if (index < 0) return;

    final child = _items.value[index];
    final parentId = _itemExtras[childId]?['parentId'];
    final children = _items.value.where((i) => _itemExtras[i.id]?['parentId'] == parentId).toList();
    children.sort((a,b) => _items.value.indexOf(a).compareTo(_items.value.indexOf(b)));

    int childListIndex = children.indexWhere((i) => i.id == childId);
    if (direction == -1 && childListIndex > 0) {
      final swapWith = children[childListIndex - 1];
      int swapIndex = _items.value.indexOf(swapWith);
      final currentList = List<QuotationLineItem>.from(_items.value);
      currentList[index] = swapWith;
      currentList[swapIndex] = child;
      _items.value = currentList;
    } else if (direction == 1 && childListIndex < children.length - 1) {
      final swapWith = children[childListIndex + 1];
      int swapIndex = _items.value.indexOf(swapWith);
      final currentList = List<QuotationLineItem>.from(_items.value);
      currentList[index] = swapWith;
      currentList[swapIndex] = child;
      _items.value = currentList;
    }
  }

  void _onDeleteTopLevelItem(QuotationLineItem item) {
    final children = _items.value.where((i) => _itemExtras[i.id]?['parentId'] == item.id).toList();
    if (children.isNotEmpty) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Linked Items?'),
              content: const Text('This item has sub-items. Delete them as well?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      final currentList = List<QuotationLineItem>.from(_items.value);
                      for (var c in children) {
                        _itemExtras[c.id]?['parentId'] = null;
                        _itemExtras[c.id]?['isScopeItem'] = false;
                      }
                      _itemExtras.remove(item.id);
                      currentList.remove(item);
                      _items.value = currentList;
                      _calculateTotals();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Keep Sub-Items')
                ),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      final currentList = List<QuotationLineItem>.from(_items.value);
                      for (var c in children) {
                        _itemExtras.remove(c.id);
                        currentList.remove(c);
                      }
                      _itemExtras.remove(item.id);
                      currentList.remove(item);
                      _items.value = currentList;
                      _calculateTotals();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Delete All')
                )
              ]
          )
      );
    } else {
      final currentList = List<QuotationLineItem>.from(_items.value);
      _itemExtras.remove(item.id);
      currentList.remove(item);
      _items.value = currentList;
      _calculateTotals();
    }
  }

  Future<void> _triggerMachineAutomations(QuotationLineItem machine, Map<String, dynamic> extras) async {
    List included = extras['includedProducts'] as List? ?? [];
    if (included.isNotEmpty) {
      bool? addScope = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Scope of Supply Found'),
              content: Text('This item contains ${included.length} sub-items in its scope. Add them to quotation?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add All')),
              ]
          )
      );
      if (addScope == true) await _addIncludedProducts(included, machine.id);
    }
  }

  Future<void> _addIncludedProducts(List included, String parentId) async {
    final currentList = List<QuotationLineItem>.from(_items.value);
    int insertIdx = currentList.length;

    int parentIdx = currentList.indexWhere((i) => i.id == parentId);
    if (parentIdx >= 0) {
      int lastChildIdx = parentIdx;
      for (int k = parentIdx + 1; k < currentList.length; k++) {
        if (_itemExtras[currentList[k].id]?['parentId'] == parentId) lastChildIdx = k;
        else break;
      }
      insertIdx = lastChildIdx + 1;
    }

    for (var inc in included) {
      String pId = '';
      double incQty = 1.0;
      String incName = '';
      if (inc is String) pId = inc;
      else if (inc is Map) {
        pId = (inc['productId'] ?? inc['id'] ?? '').toString();
        incQty = double.tryParse(inc['quantity']?.toString() ?? '1') ?? 1.0;
        incName = (inc['name'] ?? '').toString();
      }

      if (pId.isEmpty && incName.isEmpty) continue;

      Map<String, dynamic> pData = {};
      if (pId.isNotEmpty) {
        final cachedData = await _getProductData(pId);
        if (cachedData != null) pData = cachedData;
      }

      String finalName = (pData['name'] ?? incName).toString();
      if (finalName.isEmpty) continue;

      double finalGst = double.tryParse(pData['gstPercentage']?.toString() ?? '18') ?? 18.0;
      double cgst = 0, sgst = 0, igst = 0;
      if (finalGst > 0) {
        if (_isInterState) igst = finalGst;
        else { cgst = finalGst / 2; sgst = finalGst / 2; }
      }

      final newItem = QuotationLineItem(
        id: _uuid.v4(),
        productId: pId,
        name: finalName,
        description: (pData['description'] ?? '').toString(),
        hsnCode: (pData['hsnCode'] ?? '').toString(),
        quantity: incQty,
        uom: (pData['uom'] ?? 'Nos').toString(),
        unitPrice: double.tryParse(pData['sellingPrice']?.toString() ?? '0') ?? 0.0,
        discountPercent: 0,
        cgstPercent: cgst,
        sgstPercent: sgst,
        igstPercent: igst,
        availableStock: 0,
      );

      _itemExtras[newItem.id] = {
        'baseGst': finalGst,
        'isScopeItem': true,
        'parentId': parentId,
        'isIncluded': true,
        'pricingMode': 'Included',
      };

      currentList.insert(insertIdx++, newItem);
    }

    _items.value = currentList;
    _calculateTotals();
  }

  Future<Map<String, dynamic>?> _getProductData(String productId) async {
    if (_companyId == null || productId.isEmpty) return null;
    if (_productCache.containsKey(productId)) return _productCache[productId];
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('products').doc(productId).get();
      if (doc.exists && doc.data() != null) {
        _productCache[productId] = {'id': doc.id, ...doc.data()!};
        return _productCache[productId];
      }
    } catch (_) {}
    return null;
  }

  // ===========================================================================
  // SAVING & VALIDATION
  // ===========================================================================

  bool _validateBeforeSave() {
    if (_isReadOnly.value) {
      _showSnack('Document is locked for editing.', isError: true);
      return false;
    }
    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fill all required fields.', isError: true);
      return false;
    }
    if (_items.value.isEmpty && _visitCharges.value.isEmpty) {
      _showSnack('Add at least one service item or visit charge.', isError: true);
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

  String _getFinancialYearFromDate(DateTime date) {
    final localDate = date.toLocal();
    final startYear = localDate.month >= 4 ? localDate.year : localDate.year - 1;
    final startYY = startYear.toString().substring(2);
    final endYY = (startYear + 1).toString().substring(2);
    return '$startYY-$endYY';
  }

  String _quoteNumberRegistryId(String quoteNumber) {
    return quoteNumber.replaceAll('/', '_').replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }

  Future<void> _ensureExistingQuoteNumberIsUnique(String quoteNumber) async {
    final snap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('service_quotations')
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
      final db = FirebaseFirestore.instance;
      final bool isUpdate = widget.quotationId != null;
      final bool isRevision = isUpdate && _createRevisionFlag.value;

      final docRef = (isUpdate && !isRevision)
          ? db.collection('companies').doc(_companyId).collection('service_quotations').doc(widget.quotationId)
          : db.collection('companies').doc(_companyId).collection('service_quotations').doc();

      final financialYear = _getFinancialYearFromDate(_quoteDate);
      String manualSequenceStr = _quotationSequenceController.text.trim();
      int? manualSequence;

      bool autoAdjusted = false;

      if (manualSequenceStr.isNotEmpty) {
        manualSequence = int.tryParse(manualSequenceStr);
        if (manualSequence == null) throw Exception('Invalid sequence number format. Must be digits only.');
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

      await db.runTransaction((tx) async {
        int? sequenceToSync;
        final counterRef = db.collection('companies').doc(_companyId).collection('counters').doc('service_quotation_counter_$financialYear');
        final counterDoc = await tx.get(counterRef);
        final currentSequence = ((counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0);

        String safeQuoteNumber = '';
        final allowedReservations = { docRef.id, if (widget.quotationId != null) widget.quotationId! };

        if (isRevision) {
          safeQuoteNumber = _fullExistingQuoteNumber; // inherit old string
          payload['quoteNumber'] = safeQuoteNumber;
          payload['financialYear'] = safeQuoteNumber.split('/').last;
        } else {
          if (manualSequence == null) {
            int nextSequence = currentSequence + 1;
            while(true) {
              safeQuoteNumber = '$_quotationPrefix/SQ/${nextSequence.toString().padLeft(3, '0')}/$financialYear';
              final numberRef = db.collection('companies').doc(_companyId).collection('service_quotation_numbers').doc(_quoteNumberRegistryId(safeQuoteNumber));
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

            final numberRef = db.collection('companies').doc(_companyId).collection('service_quotation_numbers').doc(_quoteNumberRegistryId(safeQuoteNumber));
            final numberDocSnap = await tx.get(numberRef);
            final reservedFor = numberDocSnap.data()?['quotationId']?.toString();

            if (numberDocSnap.exists && reservedFor != null && reservedFor.isNotEmpty && !allowedReservations.contains(reservedFor)) {
              throw Exception('This quotation number already exists.');
            }
          }

          final numberRef = db.collection('companies').doc(_companyId).collection('service_quotation_numbers').doc(_quoteNumberRegistryId(safeQuoteNumber));
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

        if (isRevision) {
          final oldRef = db.collection('companies').doc(_companyId).collection('service_quotations').doc(widget.quotationId);
          tx.set(oldRef, {'isLatest': false, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': _currentUserUid}, SetOptions(merge: true));
        }

        tx.set(docRef, payload, SetOptions(merge: true));

        // Mark Service Request Quoted
        final resolvedReqId = _linkedServiceRequestId;
        if (resolvedReqId != null && resolvedReqId.isNotEmpty) {
          final reqRef = db.collection('companies').doc(_companyId).collection('service_requests').doc(resolvedReqId);
          tx.set(reqRef, {'status': 'Quoted', 'quotationId': docRef.id}, SetOptions(merge: true));
        }
      });

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
    } catch (e) {
      _showSnack('Save Failed: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Map<String, dynamic> _buildQuotationData(String docId) {
    return {
      'id': docId,
      'companyId': _companyId,
      'subject': _subjectController.text.trim(),
      'quoteDate': Timestamp.fromDate(_quoteDate),
      'status': _quotationStatus,
      'approvalStatus': _approvalStatus,
      'paymentStatus': _paymentStatus,
      'visitRequired': _visitRequired.value,
      'machineModel': _machineModelController.text.trim(),
      'serialNumber': _machineSerialController.text.trim(),
      'complaintDescription': _complaintController.text.trim(),
      'customerId': _selectedCustomerId,
      'addressId': _selectedAddressId,
      'contactId': _selectedContactId,
      'addressSnapshot': _selectedAddressData,
      'contactSnapshot': _selectedContactData,
      'clientName': _clientNameController.text.trim(),
      'clientAddress': _addressController.text.trim(),
      'addressLine': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : _customerPrimaryAddressSnapshot,
      'city': _customerPrimaryCitySnapshot,
      'state': _customerPrimaryStateSnapshot,
      'pincode': _customerPrimaryPincodeSnapshot,
      'clientEmail': _emailController.text.trim(),
      'clientMobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim().isNotEmpty ? _contactPersonController.text.trim() : _contactPersonSnapshot,
      'contactEmail': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : _contactEmailSnapshot,
      'contactMobile': _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : _contactMobileSnapshot,
      'gstNo': _gstController.text.trim(),
      'isInterState': _isInterState,
      'customerState': _customerState,
      'serviceRequestId': _linkedServiceRequestId ?? '',
      'serviceRequestNumber': _serviceRequestNumberController.text.trim(),
      'requestSource': _selectedRequestSource,
      'requestDate': Timestamp.fromDate(_requestDate),
      'serviceReference': _serviceRefNoteController.text.trim(),
      'nextFollowUpDate': _nextFollowUpDate != null ? Timestamp.fromDate(_nextFollowUpDate!) : null,
      'followUpNotes': _followUpNotesController.text.trim(),
      'totalSubtotal': _totals.value.subtotal,
      'totalVisitCharges': _totals.value.visitChargesTotal,
      'totalTaxableAmount': _totals.value.taxableAmount,
      'totalCgst': _totals.value.cgst,
      'totalSgst': _totals.value.sgst,
      'totalIgst': _totals.value.igst,
      'grandTotal': _totals.value.grandTotal,
      'finalTotal': _totals.value.finalTotal,
      'roundOff': _totals.value.roundOff,
      'dynamicTerms': _dynamicTerms.value.map((e) => {'id': e.id, 'title': e.titleCtrl.text.trim(), 'value': e.valueCtrl.text.trim()}).toList(),
      'packingChargesExtra': _packingChargesExtra.value,
      'items': _items.value.map((e) => {...e.toMap(), ...(_itemExtras[e.id] ?? {})}).toList(),
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

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green));
  }

  // ===========================================================================
  // UI BUILDERS
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
            onPressed: () {
              if (_items.value.isEmpty && _visitCharges.value.isEmpty) { _showSnack('Add items before previewing.', isError: true); return; }
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationPreviewScreen(
                quotation: _buildPreviewData(),
                items: _items.value.map((e) => QuotationLineItem.fromMap(Map<String,dynamic>.from(e.toMap()..addAll(_itemExtras[e.id] ?? {})))).toList(),
              )));
            },
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
                          _buildReadOnlyBanner(),
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          _buildCustomerSection(),
                          const SizedBox(height: 16),
                          _buildEquipmentSection(),
                          const SizedBox(height: 16),
                          _buildItemsSection(),
                          const SizedBox(height: 16),
                          _buildVisitChargesSection(),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildTermsSection()),
                              const SizedBox(width: 16),
                              Expanded(flex: 4, child: _buildSummarySection()),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomButtons(),
              ],
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, loading, child) {
                return loading ? Container(color: Colors.white.withOpacity(0.7), child: const Center(child: CircularProgressIndicator())) : const SizedBox.shrink();
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
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

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader('Quotation Details', Icons.receipt_long, 'Basic information and quotation numbering'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(_getLiveQuoteNumberDisplay(), style: const TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 16, letterSpacing: 0.5)),
                )
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quotation Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderLight),
                          borderRadius: BorderRadius.circular(8),
                          color: _isReadOnly.value ? Colors.grey.shade50 : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.horizontal(left: Radius.circular(8))),
                              child: Text('$_quotationPrefix/SQ/', style: const TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _quotationSequenceController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                readOnly: _isReadOnly.value,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  hintText: 'Auto',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.horizontal(right: Radius.circular(8))),
                              child: Text('/${_getFinancialYearFromDate(_quoteDate)}', style: const TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _isReadOnly.value ? null : () async {
                      final d = await showDatePicker(context: context, initialDate: _quoteDate, firstDate: _requestDate, lastDate: DateTime(2100));
                      if (d != null) setState(() => _quoteDate = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Quote Date', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                        filled: true, fillColor: _isReadOnly.value ? Colors.grey.shade50 : Colors.white, isDense: true,
                      ),
                      child: Text(DateFormat('dd MMM yyyy').format(_quoteDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildItemTextField(_serviceRequestNumberController, 'Service Request Number', hint: 'SR/001')),
                const SizedBox(width: 16),
                Expanded(child: _buildItemTextField(_subjectController, 'Subject Line (Optional)')),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader('Customer Details', Icons.business, 'Billing and contact information'),
                ),
                if (!_isReadOnly.value)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final c = await _selectCustomerDialog();
                      if (c != null && c['id'] != null) await _loadCustomerFromFirestore(c['id']);
                    },
                    icon: const Icon(Icons.search, size: 16), label: const Text('CRM Lookup', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), foregroundColor: primaryColor),
                  )
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: _customerInsights,
                builder: (context, insights, _) {
                  if (insights == null) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [Text('Total Quotes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800)), const SizedBox(height: 2), Text('${insights['count']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]),
                        Column(children: [Text('Last Quote', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800)), const SizedBox(height: 2), Text('₹${insights['lastQuoteAmount']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]),
                        Column(children: [Text('Lifetime Value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800)), const SizedBox(height: 2), Text('₹${insights['totalValue']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]),
                      ],
                    ),
                  );
                }
            ),

            _buildItemTextField(_clientNameController, 'Company Name *', validator: (v) => v!.isEmpty ? 'Required' : null),

            if (_customerAddresses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isReadOnly,
                  builder: (context, readOnly, _) => DropdownButtonFormField<String>(
                    value: _selectedAddressId,
                    decoration: InputDecoration(
                      labelText: 'Select Address', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                      filled: true,
                      fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
                      isDense: true,
                    ),
                    items: _customerAddresses.map((a) {
                      final label = (a['addressLabel'] ?? a['label'] ?? a['addressLine'] ?? a['combinedAddress'] ?? 'Address').toString();
                      return DropdownMenuItem(
                        value: a['id']?.toString(),
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: readOnly ? null : (val) {
                      if (val == null) return;
                      final addr = _customerAddresses.firstWhere((a) => a['id'] == val);
                      setState(() {
                        _selectedAddressId = val;
                        _selectedAddressData = addr;
                        _updateAddressSnapshots(addr);
                      });
                    },
                  ),
                ),
              ),

            if (_customerContacts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isReadOnly,
                  builder: (context, readOnly, _) => DropdownButtonFormField<String>(
                    value: _selectedContactId,
                    decoration: InputDecoration(
                      labelText: 'Select Contact Person', labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderLight)),
                      filled: true,
                      fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
                      isDense: true,
                    ),
                    items: _customerContacts.map((c) {
                      final label = (c['name'] ?? c['contactName'] ?? 'Contact').toString();
                      return DropdownMenuItem(
                        value: c['id']?.toString(),
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: readOnly ? null : (val) {
                      if (val == null) return;
                      final contact = _customerContacts.firstWhere((c) => c['id'] == val);
                      setState(() {
                        _selectedContactId = val;
                        _selectedContactData = contact;
                        _updateContactSnapshots(contact);
                      });
                    },
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(child: _buildItemTextField(_contactPersonController, 'Contact Person')),
                const SizedBox(width: 16),
                Expanded(child: _buildItemTextField(_mobileController, 'Mobile')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildItemTextField(_emailController, 'Email ID')),
                const SizedBox(width: 16),
                Expanded(child: _buildItemTextField(_gstController, 'GSTIN')),
              ],
            ),
            _buildItemTextField(_addressController, 'Billing Address', maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Equipment Details', Icons.precision_manufacturing, 'Machine info & service requirements'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildItemTextField(_machineModelController, 'Machine Model')),
                const SizedBox(width: 16),
                Expanded(child: _buildItemTextField(_machineSerialController, 'Serial Number')),
              ],
            ),
            _buildItemTextField(_complaintController, 'Complaint / Fault Description', maxLines: 2),
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border.all(color: borderLight), borderRadius: BorderRadius.circular(8), color: Colors.white),
              child: ValueListenableBuilder<bool>(
                valueListenable: _visitRequired,
                builder: (context, visitReq, _) {
                  return SwitchListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    title: const Text('Engineer Visit Required?', style: TextStyle(fontWeight: FontWeight.w600, color: textDark)),
                    subtitle: const Text('Toggle if an on-site visit is needed for this service.', style: TextStyle(fontSize: 12, color: textMuted)),
                    value: visitReq,
                    activeColor: accentColor,
                    onChanged: _isReadOnly.value ? null : (v) => _visitRequired.value = v,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader('Service Charges & Spares', Icons.inventory_2_outlined, 'Add services or select spares from inventory'),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _isReadOnly,
                  builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : ElevatedButton.icon(
                    onPressed: _showAddItemModal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<List<QuotationLineItem>>(
              valueListenable: _items,
              builder: (context, items, _) {
                if (items.isEmpty) return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderLight, style: BorderStyle.solid)),
                  child: const Center(child: Text('No service items or spares added yet.', style: TextStyle(color: textMuted, fontWeight: FontWeight.w500))),
                );

                final topLevelItems = items.where((i) => _itemExtras[i.id]?['parentId'] == null).toList();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topLevelItems.length,
                  itemBuilder: (ctx, i) {
                    final item = topLevelItems[i];
                    final children = items.where((c) => _itemExtras[c.id]?['parentId'] == item.id).toList();
                    children.sort((a,b) => items.indexOf(a).compareTo(items.indexOf(b)));

                    int actualIndex = items.indexOf(item);
                    final nature = _itemExtras[item.id]?['productNature']?.toString() ?? 'General';
                    final isService = nature == 'Service';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(border: Border.all(color: borderLight), borderRadius: BorderRadius.circular(12), color: Colors.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(backgroundColor: isService ? Colors.indigo.shade50 : Colors.blue.shade50, child: Icon(isService ? Icons.build_circle : Icons.inventory_2, color: isService ? Colors.indigo : Colors.blue, size: 20)),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${item.quantity} ${item.uom}  •  Rate: ₹${item.unitPrice}  •  Tax: ${item.cgstPercent+item.sgstPercent+item.igstPercent}%', style: const TextStyle(color: textMuted, fontWeight: FontWeight.w500)),
                            ),
                            trailing: ValueListenableBuilder<bool>(
                              valueListenable: _isReadOnly,
                              builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showAddItemModal(item, actualIndex), tooltip: 'Edit', splashRadius: 20),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _onDeleteTopLevelItem(item), tooltip: 'Delete', splashRadius: 20),
                                ],
                              ),
                            ),
                          ),
                          if (children.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: borderLight)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Scope of Supply / Sub-Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted)),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _isReadOnly,
                                        builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : InkWell(
                                          onTap: () => _showScopeItemModal(item.id),
                                          child: const Row(children: [Icon(Icons.add, size: 14, color: accentColor), SizedBox(width: 4), Text('Add Sub-Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor))]),
                                        ),
                                      )
                                    ],
                                  ),
                                  const Divider(height: 16, color: borderLight),
                                  ...children.map((child) {
                                    final childExtras = _itemExtras[child.id] ?? {};
                                    final pricingMode = childExtras['pricingMode'] ?? 'Included';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey.shade400),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('${child.name} (${child.quantity} ${child.uom})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textDark)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: pricingMode == 'Included' ? Colors.green.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                            child: Text(pricingMode == 'Included' ? 'Included' : '₹${child.unitPrice}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pricingMode == 'Included' ? Colors.green.shade700 : Colors.blue.shade700)),
                                          ),
                                          const SizedBox(width: 8),
                                          ValueListenableBuilder<bool>(
                                              valueListenable: _isReadOnly,
                                              builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  InkWell(onTap: () => _moveScopeItem(child.id, -1), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.arrow_upward, size: 14, color: textMuted))),
                                                  InkWell(onTap: () => _moveScopeItem(child.id, 1), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.arrow_downward, size: 14, color: textMuted))),
                                                  InkWell(onTap: () => _showScopeItemModal(item.id, child), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit_outlined, size: 14, color: Colors.blue))),
                                                  InkWell(onTap: () {
                                                    final currentItems = List<QuotationLineItem>.from(_items.value);
                                                    _itemExtras.remove(child.id);
                                                    currentItems.remove(child);
                                                    _items.value = currentItems;
                                                    _calculateTotals();
                                                  }, child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline, size: 14, color: Colors.red))),
                                                ],
                                              )
                                          )
                                        ],
                                      ),
                                    );
                                  }).toList()
                                ],
                              ),
                            )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitChargesSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader('Engineer Visit Charges', Icons.commute_outlined, 'Log boarding, lodging, transport expenses'),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _isReadOnly,
                  builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : ElevatedButton.icon(
                    onPressed: () {
                      final current = List<VisitChargeItem>.from(_visitCharges.value);
                      current.add(VisitChargeItem(id: _uuid.v4()));
                      _visitCharges.value = current;
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: textDark, side: const BorderSide(color: borderLight), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<List<VisitChargeItem>>(
              valueListenable: _visitCharges,
              builder: (context, visitCharges, _) {
                if (visitCharges.isEmpty) return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderLight, style: BorderStyle.solid)),
                  child: const Center(child: Text('No visit expenses added.', style: TextStyle(color: textMuted, fontWeight: FontWeight.w500))),
                );

                return Container(
                  decoration: BoxDecoration(border: Border.all(color: borderLight), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(8)), border: Border(bottom: BorderSide(color: borderLight))),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('Expense Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted))),
                            Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted))),
                            Expanded(flex: 2, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted))),
                            Expanded(flex: 1, child: Text('GST %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted))),
                            Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted), textAlign: TextAlign.right)),
                            SizedBox(width: 48), // Action spacer
                          ],
                        ),
                      ),
                      ...visitCharges.asMap().entries.map((entry) {
                        int idx = entry.key;
                        VisitChargeItem vc = entry.value;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(border: idx != visitCharges.length - 1 ? const Border(bottom: BorderSide(color: borderLight)) : null),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: TextFormField(
                                initialValue: vc.type,
                                readOnly: _isReadOnly.value,
                                decoration: const InputDecoration(hintText: 'e.g. Lodging', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                onChanged: (v) { vc.type = v; _calculateTotals(); },
                              )),
                              const SizedBox(width: 8),
                              Expanded(flex: 1, child: TextFormField(
                                initialValue: vc.quantity.toString(),
                                readOnly: _isReadOnly.value,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                onChanged: (v) { vc.quantity = double.tryParse(v) ?? 1; _calculateTotals(); },
                              )),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: TextFormField(
                                initialValue: vc.rate.toString(),
                                readOnly: _isReadOnly.value,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                onChanged: (v) { vc.rate = double.tryParse(v) ?? 0; _calculateTotals(); },
                              )),
                              const SizedBox(width: 8),
                              Expanded(flex: 1, child: TextFormField(
                                initialValue: vc.gstPercent.toString(),
                                readOnly: _isReadOnly.value,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                onChanged: (v) { vc.gstPercent = double.tryParse(v) ?? 18; _calculateTotals(); },
                              )),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text('₹${vc.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right)),
                              SizedBox(
                                width: 48,
                                child: ValueListenableBuilder<bool>(
                                    valueListenable: _isReadOnly,
                                    builder: (ctx, readOnly, _) => readOnly ? const SizedBox.shrink() : IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () {
                                        final current = List<VisitChargeItem>.from(_visitCharges.value);
                                        current.removeAt(idx);
                                        _visitCharges.value = current;
                                        _calculateTotals();
                                      },
                                    )
                                ),
                              )
                            ],
                          ),
                        );
                      }).toList()
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
            const Divider(height: 24, color: borderLight),
            ValueListenableBuilder<QuotationTotals>(
              valueListenable: _totals,
              builder: (context, totals, _) {
                return Column(
                  children: [
                    _calcRow('Subtotal (Items)', totals.subtotal),
                    if (totals.itemDiscount > 0) _calcRow('Item Discount', -totals.itemDiscount, color: Colors.red.shade700),
                    if (totals.visitChargesTotal > 0) _calcRow('Visit Charges', totals.visitChargesTotal),
                    const Divider(height: 16, color: borderLight),
                    _calcRow('Taxable Value', totals.taxableAmount, bold: true, color: textDark),
                    const SizedBox(height: 8),
                    if (!_isInterState) ...[
                      _calcRow('CGST', totals.cgst, color: textMuted),
                      _calcRow('SGST', totals.sgst, color: textMuted),
                    ] else
                      _calcRow('IGST', totals.igst, color: textMuted),
                    if (totals.roundOff != 0) _calcRow('Round Off', totals.roundOff, color: textMuted),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderLight)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                          Text('₹${totals.finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: primaryColor)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader('Terms & Conditions', Icons.gavel_outlined, 'Standard business terms'),
                ),
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
                )
              ],
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
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: borderLight)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))]),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<QuotationTotals>(
              valueListenable: _totals,
              builder: (ctx, totals, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Final Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                  Text('₹ ${totals.finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark)),
                ],
              ),
            ),
            Row(
              children: [
                if (widget.quotationId != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: _createRevisionFlag,
                    builder: (ctx, isRev, _) => Container(
                      margin: const EdgeInsets.only(right: 16),
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
                ValueListenableBuilder<bool>(
                  valueListenable: _isReadOnly,
                  builder: (ctx, readOnly, _) => FilledButton.icon(
                    onPressed: readOnly ? null : _saveQuotation,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Save Quotation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: FilledButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
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

  Widget _buildSectionHeader(String title, IconData icon, String subtitle) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accentColor, size: 22)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500)),
          ],
        )),
      ],
    );
  }

  Widget _calcRow(String label, double amount, {bool bold = false, double size = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: size, color: color ?? textMuted)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.bold, fontSize: size, color: color ?? textDark)),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildPreviewData() {
    return {
      'quoteNumber': _getLiveQuoteNumberDisplay(),
      'quoteDateStr': '${_quoteDate.day.toString().padLeft(2, '0')}/${_quoteDate.month.toString().padLeft(2, '0')}/${_quoteDate.year}',
      'version': _currentVersion.toString(),
      'approvalStatus': _approvalStatus,
      'paymentStatus': _paymentStatus,
      'serviceRequestNumber': _serviceRequestNumberController.text.trim(),
      'subject': _subjectController.text.trim(),
      'machineModel': _machineModelController.text.trim(),
      'serialNumber': _machineSerialController.text.trim(),
      'complaintDescription': _complaintController.text.trim(),
      'clientName': _clientNameController.text.trim(),
      'clientAddress': _addressController.text.trim(),
      'clientEmail': _emailController.text.trim(),
      'clientMobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'gstNo': _gstController.text.trim(),
      'customerState': _customerState,
      'isInterState': _isInterState,
      'addressSnapshot': _selectedAddressData,
      'contactSnapshot': _selectedContactData,
      'totalSubtotal': _totals.value.subtotal,
      'totalVisitCharges': _totals.value.visitChargesTotal,
      'totalTaxableAmount': _totals.value.taxableAmount,
      'totalCgst': _totals.value.cgst,
      'totalSgst': _totals.value.sgst,
      'totalIgst': _totals.value.igst,
      'grandTotal': _totals.value.grandTotal,
      'finalTotal': _totals.value.finalTotal,
      'dynamicTerms': _dynamicTerms.value.map((e) => {'id': e.id, 'title': e.titleCtrl.text.trim(), 'value': e.valueCtrl.text.trim()}).toList(),
      'packingChargesExtra': _packingChargesExtra.value,
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
}

// ===========================================================================
// PREVIEW SCREEN
// ===========================================================================

class QuotationPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> quotation;
  final List<QuotationLineItem> items;

  const QuotationPreviewScreen({
    super.key,
    required this.quotation,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 1,
      ),
      body: PdfPreview(
        build: (format) => ServiceQuotationPdfGenerator.generateServiceQuotationPdf(quotation, items),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}