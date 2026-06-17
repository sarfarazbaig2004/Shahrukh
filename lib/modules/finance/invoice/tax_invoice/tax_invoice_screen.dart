// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// ------------------------------------------------------------------------
/// SINGLE SOURCE OF TRUTH FOR ADMIN ROLE CHECK
/// ------------------------------------------------------------------------
bool isAdminRole(String? role) {
  final r = (role ?? '').toLowerCase().trim();
  return r == 'admin' || r == 'superadmin' || r == 'owner' || r == 'director' ||
      r == 'md' || r == 'ceo' || r == 'sales_manager' || r == 'administrator';
}

/// ------------------------------------------------------------------------
/// TOTALS STATE NOTIFIER (PERFORMANCE OPTIMIZATION)
/// Prevents full screen rebuilds on every keystroke.
/// ------------------------------------------------------------------------
class InvoiceTotals {
  double totalQty = 0, totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalIgst = 0;
  double totalGst = 0, grandTotal = 0, roundOff = 0;
  String amountInWords = "Zero Rupees Only";
}

/// ------------------------------------------------------------------------
/// TAX INVOICE SCREEN (ENTERPRISE ERP ARCHITECTURE)
/// ------------------------------------------------------------------------
class TaxInvoiceScreen extends StatefulWidget {
  final String companyId;
  final String userUid;
  final String currentUserRole;
  final VoidCallback onBack;

  const TaxInvoiceScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.currentUserRole = '',
    required this.onBack,
  });

  @override
  State<TaxInvoiceScreen> createState() => _TaxInvoiceScreenState();
}

class _TaxInvoiceScreenState extends State<TaxInvoiceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _currentUserRole = '';
  bool _isInitializing = true;
  bool get _isAdmin => isAdminRole(_currentUserRole);

  // --- HEADER CONTROLLERS ---
  final _sequenceNoCtrl = TextEditingController();
  final _sequenceFocusNode = FocusNode();
  String _provisionalSequence = '';
  String _financialYear = '';
  final String _invoicePrefix = 'MEMCO';

  final _invoiceDateCtrl = TextEditingController();
  DateTime _selectedInvoiceDate = DateTime.now();

  String _selectedTransportMode = 'By Road';
  final List<String> _transportModes = [
    'By Road', 'By Air', 'By Rail', 'By Sea', 'Courier',
    'Hand Delivery', 'Customer Pickup', 'Transport Agency',
    'Logistics Partner', 'Parcel Service', 'Express Delivery',
    'Surface Transport', 'Multimodal Transport', 'Other'
  ];

  final _vehicleNoCtrl = TextEditingController();
  final _dateOfSupplyCtrl = TextEditingController();
  DateTime? _selectedSupplyDate;
  final _placeOfSupplyCtrl = TextEditingController();
  bool _reverseCharge = false;

  final _irnCtrl = TextEditingController();
  final _ackNoCtrl = TextEditingController();
  final _ackDateCtrl = TextEditingController();
  final _ewayBillNoCtrl = TextEditingController();
  final _ewayBillDateCtrl = TextEditingController();

  // --- SALES REFERENCE CONTROLLERS ---
  final _quotationNoCtrl = TextEditingController();
  final _quotationDateCtrl = TextEditingController();
  final _salesOrderNoCtrl = TextEditingController();
  final _salesOrderDateCtrl = TextEditingController();
  final _customerRefCtrl = TextEditingController();
  final _enquiryRefCtrl = TextEditingController();

  // --- PACKING DETAILS CONTROLLERS ---
  final _noOfPackagesCtrl = TextEditingController();
  final _packageTypeCtrl = TextEditingController();
  final _grossWeightCtrl = TextEditingController();
  final _netWeightCtrl = TextEditingController();
  final _dimensionsCtrl = TextEditingController();

  // --- TRANSPORT DETAILS CONTROLLERS ---
  final _transporterNameCtrl = TextEditingController();
  final _lrNoCtrl = TextEditingController();
  final _lrDateCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverMobileCtrl = TextEditingController();

  // --- CUSTOMER SUMMARY STATE ---
  String? _selectedCustomerId;
  String _selectedCustomerName = '';
  String _selectedCustomerCode = '';
  String _selectedCustomerGstin = '';
  String _selectedCustomerState = '';
  String _selectedCustomerAssignedTo = '';
  double _selectedCustomerOutstanding = 0.0;
  bool _isLoadingCustomerData = false;

  List<Map<String, dynamic>> _customerAddresses = [];
  List<Map<String, dynamic>> _customerContacts = [];

  // --- BILL TO / SHIP TO ---
  Map<String, dynamic>? _selectedBillToAddress;
  Map<String, dynamic>? _selectedBillToContact;
  final _billToCustomerCtrl = TextEditingController();
  final _billToGstinCtrl = TextEditingController();
  final _billToAddressCtrl = TextEditingController();
  final _billToStateCtrl = TextEditingController();
  final _billToStateCodeCtrl = TextEditingController();
  final _billToContactPersonCtrl = TextEditingController();
  final _billToDesignationCtrl = TextEditingController();
  final _billToEmailCtrl = TextEditingController();
  final _billToMobileCtrl = TextEditingController();
  final _poNumberCtrl = TextEditingController();
  final _poDateCtrl = TextEditingController();

  bool _sameAsBillTo = true;
  Map<String, dynamic>? _selectedShipToAddress;
  Map<String, dynamic>? _selectedShipToContact;
  final _shipToCustomerCtrl = TextEditingController();
  final _shipToGstinCtrl = TextEditingController();
  final _shipToAddressCtrl = TextEditingController();
  final _shipToStateCtrl = TextEditingController();
  final _shipToStateCodeCtrl = TextEditingController();
  final _shipToContactPersonCtrl = TextEditingController();
  final _shipToDesignationCtrl = TextEditingController();
  final _shipToEmailCtrl = TextEditingController();
  final _shipToMobileCtrl = TextEditingController();

  // --- EXTRAS & PAYMENT ---
  final _freightCtrl = TextEditingController();
  final _packingCtrl = TextEditingController();
  final _otherChargesCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  final _paymentModeCtrl = TextEditingController();
  final _bankAccNoCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _tncCtrl = TextEditingController();

  // --- STATE ---
  String _sellerState = '';
  String _sellerGstin = '';
  String _sellerName = '';
  bool _isInterState = false;
  List<_InvoiceItem> _items = [];
  bool _isSaving = false;

  // --- TOTALS PERFORMANCE NOTIFIER ---
  final ValueNotifier<InvoiceTotals> _totalsNotifier = ValueNotifier(InvoiceTotals());

  final Map<String, String> _stateNameToCode = {
    'jammu and kashmir': '01', 'himachal pradesh': '02', 'punjab': '03', 'chandigarh': '04', 'uttarakhand': '05', 'haryana': '06', 'delhi': '07', 'rajasthan': '08', 'uttar pradesh': '09', 'bihar': '10', 'sikkim': '11', 'arunachal pradesh': '12', 'nagaland': '13', 'manipur': '14', 'mizoram': '15', 'tripura': '16', 'meghalaya': '17', 'assam': '18', 'west bengal': '19', 'jharkhand': '20', 'odisha': '21', 'chhattisgarh': '22', 'madhya pradesh': '23', 'gujarat': '24', 'daman and diu': '25', 'dadra and nagar haveli': '26', 'maharashtra': '27', 'andhra pradesh': '28', 'karnataka': '29', 'goa': '30', 'lakshadweep': '31', 'kerala': '32', 'tamil nadu': '33', 'puducherry': '34', 'andaman and nicobar islands': '35', 'telangana': '36', 'ladakh': '38'
  };

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentUserRole = widget.currentUserRole;
    _invoiceDateCtrl.text = DateFormat('dd-MM-yyyy').format(_selectedInvoiceDate);
    _financialYear = _calculateFinancialYear(_selectedInvoiceDate);

    _sequenceFocusNode.addListener(() {
      if (!_sequenceFocusNode.hasFocus && _sequenceNoCtrl.text.trim().isNotEmpty) {
        _sequenceNoCtrl.text = _formatSequence(_sequenceNoCtrl.text);
        setState(() {});
      }
    });

    _placeOfSupplyCtrl.addListener(_updateGstType);
    _freightCtrl.addListener(_debouncedCalculateTotals);
    _packingCtrl.addListener(_debouncedCalculateTotals);
    _otherChargesCtrl.addListener(_debouncedCalculateTotals);

    _addNewRow();
    _initScreenData();
  }

  Future<void> _initScreenData() async {
    await _fetchCurrentUserRole();
    await Future.wait([
      _fetchCompanyDetails(),
      _fetchProvisionalSequence(),
      ProductCacheService().loadProducts(widget.companyId),
    ]);
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _fetchCurrentUserRole() async {
    try {
      final doc = await _db.collection('companies').doc(widget.companyId).collection('users').doc(widget.userUid).get();
      if (doc.exists && doc.data() != null) {
        final firestoreRole = (doc.data()!['role'] ?? '').toString();
        if (firestoreRole.isNotEmpty) _currentUserRole = firestoreRole;
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _totalsNotifier.dispose();
    _sequenceNoCtrl.dispose();
    _sequenceFocusNode.dispose();
    _invoiceDateCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _dateOfSupplyCtrl.dispose();
    _placeOfSupplyCtrl.dispose();
    _irnCtrl.dispose();
    _ackNoCtrl.dispose();
    _ackDateCtrl.dispose();
    _ewayBillNoCtrl.dispose();
    _ewayBillDateCtrl.dispose();
    _billToCustomerCtrl.dispose();
    _billToGstinCtrl.dispose();
    _billToAddressCtrl.dispose();
    _billToStateCtrl.dispose();
    _billToStateCodeCtrl.dispose();
    _billToContactPersonCtrl.dispose();
    _billToDesignationCtrl.dispose();
    _billToEmailCtrl.dispose();
    _billToMobileCtrl.dispose();
    _poNumberCtrl.dispose();
    _poDateCtrl.dispose();
    _shipToCustomerCtrl.dispose();
    _shipToGstinCtrl.dispose();
    _shipToAddressCtrl.dispose();
    _shipToStateCtrl.dispose();
    _shipToStateCodeCtrl.dispose();
    _shipToContactPersonCtrl.dispose();
    _shipToDesignationCtrl.dispose();
    _shipToEmailCtrl.dispose();
    _shipToMobileCtrl.dispose();
    _freightCtrl.dispose();
    _packingCtrl.dispose();
    _otherChargesCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _paymentModeCtrl.dispose();
    _bankAccNoCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchCtrl.dispose();
    _ifscCtrl.dispose();
    _remarksCtrl.dispose();
    _tncCtrl.dispose();

    _quotationNoCtrl.dispose(); _quotationDateCtrl.dispose();
    _salesOrderNoCtrl.dispose(); _salesOrderDateCtrl.dispose();
    _customerRefCtrl.dispose(); _enquiryRefCtrl.dispose();

    _noOfPackagesCtrl.dispose(); _packageTypeCtrl.dispose();
    _grossWeightCtrl.dispose(); _netWeightCtrl.dispose(); _dimensionsCtrl.dispose();

    _transporterNameCtrl.dispose(); _lrNoCtrl.dispose();
    _lrDateCtrl.dispose(); _driverNameCtrl.dispose(); _driverMobileCtrl.dispose();

    for (var item in _items) { item.dispose(); }
    super.dispose();
  }

  void _debouncedCalculateTotals() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _calculateTotals);
  }

  String _calculateFinancialYear(DateTime date) {
    int year = date.year;
    int month = date.month;
    return month >= 4 ? '${year.toString().substring(2)}-${(year + 1).toString().substring(2)}'
        : '${(year - 1).toString().substring(2)}-${year.toString().substring(2)}';
  }

  DateTime _calculateDueDate() {
    final terms = _paymentTermsCtrl.text.trim().toLowerCase();
    int days = 0;
    if (terms.contains('15')) days = 15;
    else if (terms.contains('30')) days = 30;
    else if (terms.contains('45')) days = 45;
    else if (terms.contains('60')) days = 60;
    else if (terms.contains('90')) days = 90;
    else if (terms.contains('7')) days = 7;
    return _selectedInvoiceDate.add(Duration(days: days));
  }

  String _formatSequence(String seq) {
    final intSeq = int.tryParse(seq.trim());
    if (intSeq == null) return '001';
    return intSeq < 100 ? intSeq.toString().padLeft(3, '0') : intSeq.toString();
  }

  Future<void> _selectDate(TextEditingController controller, {DateTime? initialDate, Function(DateTime)? onSelect}) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('dd-MM-yyyy').format(picked);
      if (onSelect != null) onSelect(picked);
    }
  }

  String _getStateCode(String stateName) => _stateNameToCode[stateName.trim().toLowerCase()] ?? '';

  Future<void> _fetchCompanyDetails() async {
    try {
      final doc = await _db.collection('companies').doc(widget.companyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _sellerName = data['companyName'] ?? '';
          _sellerState = data['state'] ?? 'Maharashtra';
          _sellerGstin = data['gst'] ?? '';
          _bankNameCtrl.text = data['bankName'] ?? '';
          _bankAccNoCtrl.text = data['accountNumber'] ?? '';
          _ifscCtrl.text = data['ifscCode'] ?? '';
          _branchCtrl.text = data['branch'] ?? '';

          // Auto-load Default Terms & Conditions
          _tncCtrl.text = data['defaultInvoiceTerms'] ?? '1. Goods once sold will not be taken back.\n2. Interest @24% p.a. will be charged on overdue payments.\n3. Subject to Mumbai Jurisdiction.\n4. Warranty as per manufacturer policy.\n5. Transit damage must be reported within 24 hours.\n6. Risk passes to buyer upon delivery.\n7. E&OE.';
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchProvisionalSequence() async {
    try {
      final fyKey = _financialYear.replaceAll('-', '_');
      final counterRef = _db.collection('companies').doc(widget.companyId).collection('metadata').doc('tax_invoice_counter_$fyKey');
      final snapshot = await counterRef.get();
      int currentCount = snapshot.exists ? (snapshot.data()?['count'] ?? 0) : 0;
      if (mounted) {
        setState(() {
          _provisionalSequence = (currentCount + 1).toString();
          if (_sequenceNoCtrl.text.isEmpty) _sequenceNoCtrl.text = '';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCustomerDetails(Map<String, dynamic> customerData) async {
    setState(() {
      _isLoadingCustomerData = true;
      _selectedBillToAddress = null; _selectedShipToAddress = null;
      _selectedBillToContact = null; _selectedShipToContact = null;
      _customerAddresses.clear(); _customerContacts.clear();
    });

    try {
      final customerId = customerData['id'];
      final gst = (customerData['gst'] ?? customerData['gstin'] ?? customerData['gstNumber'] ?? '').toString().toUpperCase();
      final state = (customerData['state'] ?? customerData['stateName'] ?? '').toString();
      final address = (customerData['address'] ?? customerData['billingAddress'] ?? customerData['fullAddress'] ?? customerData['street'] ?? '').toString();
      final contactName = (customerData['contactName'] ?? customerData['primaryContact'] ?? customerData['name'] ?? '').toString();
      final mobile = (customerData['phone'] ?? customerData['mobile'] ?? customerData['contactNumber'] ?? '').toString();
      final email = (customerData['email'] ?? customerData['contactEmail'] ?? customerData['businessEmail'] ?? '').toString();
      final code = (customerData['customerCode'] ?? '').toString();
      final designation = (customerData['designation'] ?? '').toString();

      _selectedCustomerId = customerId;
      _selectedCustomerName = (customerData['companyName'] ?? customerData['name'] ?? '').toString();
      _selectedCustomerCode = code;
      _selectedCustomerGstin = gst;
      _selectedCustomerState = state;
      _selectedCustomerAssignedTo = (customerData['assignedToName'] ?? '').toString();

      _billToCustomerCtrl.text = _selectedCustomerName;
      _shipToCustomerCtrl.text = _selectedCustomerName;

      final rawAddresses = customerData['addresses'] ?? customerData['customerAddresses'];
      if (rawAddresses is List && rawAddresses.isNotEmpty) {
        _customerAddresses = List<Map<String, dynamic>>.from(rawAddresses);
      } else {
        _customerAddresses = [{
          'id': 'root-addr', 'type': 'Head Office', 'street': address, 'city': (customerData['city'] ?? '').toString(),
          'state': state, 'pincode': (customerData['pincode'] ?? '').toString(), 'country': (customerData['country'] ?? '').toString(),
          'gst': gst, 'combinedAddress': [address, customerData['city'], state, customerData['pincode'], customerData['country']].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '),
          'isPrimary': true, 'isBillingAddress': true, 'isShippingAddress': true,
        }];
      }

      final contactsSnap = await _db.collection('companies').doc(widget.companyId).collection('customers').doc(customerId).collection('contacts').where('isActive', isEqualTo: true).get();
      _customerContacts = contactsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      if (_customerContacts.isEmpty && contactName.isNotEmpty) {
        _customerContacts.add({'id': 'legacy-root', 'name': contactName, 'phone': mobile, 'email': email, 'designation': designation, 'isPrimary': true});
      }

      try {
        final outSnap = await _db.collection('companies').doc(widget.companyId).collection('outstanding_ledger').where('customerId', isEqualTo: customerId).where('status', isNotEqualTo: 'PAID').get();
        double totalOut = 0.0;
        for (var doc in outSnap.docs) { totalOut += ((doc.data()['amountOutstanding'] as num?)?.toDouble() ?? 0.0); }
        _selectedCustomerOutstanding = totalOut;
      } catch (_) { _selectedCustomerOutstanding = 0.0; }

      _selectedBillToAddress = _customerAddresses.firstWhere((a) => a['isBillingAddress'] == true, orElse: () => _customerAddresses.firstWhere((a) => a['isPrimary'] == true, orElse: () => _customerAddresses.isNotEmpty ? _customerAddresses.first : {}));
      if (_selectedBillToAddress?.isEmpty ?? true) _selectedBillToAddress = null;

      _selectedShipToAddress = _customerAddresses.firstWhere((a) => a['isShippingAddress'] == true, orElse: () => _customerAddresses.firstWhere((a) => a['isPrimary'] == true, orElse: () => _customerAddresses.isNotEmpty ? _customerAddresses.first : {}));
      if (_selectedShipToAddress?.isEmpty ?? true) _selectedShipToAddress = null;

      _selectedBillToContact = _customerContacts.isNotEmpty ? _customerContacts.firstWhere((c) => c['isPrimary'] == true, orElse: () => _customerContacts.first) : null;
      _selectedShipToContact = _selectedBillToContact;

      if (_selectedBillToAddress != null) _applyAddressSelection(_selectedBillToAddress!, true);
      if (_selectedBillToContact != null) _applyContactSelection(_selectedBillToContact!, true);

      if (_sameAsBillTo) _syncShipTo();
      else {
        if (_selectedShipToAddress != null) _applyAddressSelection(_selectedShipToAddress!, false);
        if (_selectedShipToContact != null) _applyContactSelection(_selectedShipToContact!, false);
      }

      if (_billToGstinCtrl.text.isEmpty && gst.isNotEmpty) _billToGstinCtrl.text = gst;
      if (_billToStateCtrl.text.isEmpty && state.isNotEmpty) {
        _billToStateCtrl.text = state;
        _billToStateCodeCtrl.text = _getStateCode(state);
        _placeOfSupplyCtrl.text = state;
      }
      if (_billToAddressCtrl.text.isEmpty && address.isNotEmpty) _billToAddressCtrl.text = address;
      if (_billToContactPersonCtrl.text.isEmpty && contactName.isNotEmpty) _billToContactPersonCtrl.text = contactName;
      if (_billToMobileCtrl.text.isEmpty && mobile.isNotEmpty) _billToMobileCtrl.text = mobile;
      if (_billToEmailCtrl.text.isEmpty && email.isNotEmpty) _billToEmailCtrl.text = email;

      _updateGstType();
    } catch (e) {
      debugPrint('Error loading customer details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCustomerData = false);
    }
  }

  void _applyAddressSelection(Map<String, dynamic> addr, bool isBillTo) {
    final stateName = (addr['state'] ?? addr['stateName'] ?? '').toString();
    final gst = (addr['gst'] ?? addr['gstin'] ?? addr['gstNumber'] ?? '').toString().toUpperCase();
    String stateCode = (gst.length >= 2 && RegExp(r'^[0-9]{2}$').hasMatch(gst.substring(0, 2))) ? gst.substring(0, 2) : _getStateCode(stateName);
    final combinedAddress = (addr['combinedAddress'] ?? addr['fullAddress'] ?? addr['billingAddress'] ?? addr['address'] ?? addr['street'] ?? '').toString();

    if (isBillTo) {
      _billToAddressCtrl.text = combinedAddress;
      _billToStateCtrl.text = stateName;
      _billToStateCodeCtrl.text = stateCode;
      _billToGstinCtrl.text = gst;
      _placeOfSupplyCtrl.text = stateName;
      _updateGstType();
    } else {
      _shipToAddressCtrl.text = combinedAddress;
      _shipToStateCtrl.text = stateName;
      _shipToStateCodeCtrl.text = stateCode;
      _shipToGstinCtrl.text = gst;
    }
  }

  void _applyContactSelection(Map<String, dynamic> contact, bool isBillTo) {
    final name = (contact['name'] ?? contact['contactName'] ?? contact['primaryContact'] ?? '').toString();
    final designation = (contact['designation'] ?? '').toString();
    final phone = (contact['phone'] ?? contact['mobile'] ?? contact['contactNumber'] ?? '').toString();
    final email = (contact['email'] ?? contact['contactEmail'] ?? contact['businessEmail'] ?? '').toString();

    if (isBillTo) {
      _billToContactPersonCtrl.text = name; _billToDesignationCtrl.text = designation;
      _billToMobileCtrl.text = phone; _billToEmailCtrl.text = email;
    } else {
      _shipToContactPersonCtrl.text = name; _shipToDesignationCtrl.text = designation;
      _shipToMobileCtrl.text = phone; _shipToEmailCtrl.text = email;
    }
  }

  void _syncShipTo() {
    _selectedShipToAddress = _selectedBillToAddress;
    _selectedShipToContact = _selectedBillToContact;
    _shipToCustomerCtrl.text = _billToCustomerCtrl.text;
    _shipToGstinCtrl.text = _billToGstinCtrl.text;
    _shipToAddressCtrl.text = _billToAddressCtrl.text;
    _shipToStateCtrl.text = _billToStateCtrl.text;
    _shipToStateCodeCtrl.text = _billToStateCodeCtrl.text;
    _shipToContactPersonCtrl.text = _billToContactPersonCtrl.text;
    _shipToDesignationCtrl.text = _billToDesignationCtrl.text;
    _shipToMobileCtrl.text = _billToMobileCtrl.text;
    _shipToEmailCtrl.text = _billToEmailCtrl.text;
  }

  void _updateGstType() {
    final pos = _placeOfSupplyCtrl.text.trim().toLowerCase();
    final seller = _sellerState.toLowerCase();
    setState(() => _isInterState = (pos.isNotEmpty && pos != seller));
    _debouncedCalculateTotals();
  }

  void _applyProductToRow(int index, Map<String, dynamic> productData) {
    debugPrint('--- PRODUCT DATA AUDIT ---');
    debugPrint('id = ${productData['id']}');
    debugPrint('name = ${productData['name']}');
    debugPrint('description = ${productData['description']}');
    debugPrint('hsnCode = ${productData['hsnCode']}');
    debugPrint('scopeOfSupply = ${productData['scopeOfSupply']}');
    debugPrint('includedProducts = ${productData['includedProducts']}');

    setState(() {
      _items[index].productId = productData['id'];
      _items[index].sku = productData['sku']?.toString() ?? '';
      _items[index].itemCode = productData['itemCode']?.toString() ?? '';
      _items[index].barcode = productData['barcode']?.toString() ?? '';
      _items[index].productNature = productData['productNature']?.toString() ?? '';
      _items[index].trackInventory = productData['trackInventory'] == true || productData['trackInventory'] == 'true';
      _items[index].availableStock = (productData['stockOnHand'] as num?)?.toDouble() ?? 0.0;

      // Auto-fill Product Info Panel
      _items[index].category = productData['category']?.toString() ?? '';
      _items[index].subCategory = productData['subcategory']?.toString() ?? '';
      _items[index].brand = productData['make']?.toString() ?? '';
      _items[index].machineType = productData['machineType']?.toString() ?? '';

      _items[index].productCtrl.text = productData['name']?.toString() ?? '';
      _items[index].descCtrl.text = productData['description']?.toString() ?? '';

      // Strict serialization mapping for included items / scope of supply
      String scopeVal = '';
      if (productData['includedProducts'] is List) {
        final List incl = productData['includedProducts'] as List;
        scopeVal = incl.map((e) => '${e['qty'] ?? 1} ${e['uom'] ?? ''} ${e['productName'] ?? ''}'.trim()).join('\n').trim();
      } else {
        scopeVal = productData['scopeOfSupply']?.toString() ?? '';
      }
      _items[index].scopeCtrl.text = scopeVal;

      _items[index].hsnCtrl.text = productData['hsnCode']?.toString() ?? '';
      _items[index].uomCtrl.text = productData['uom']?.toString() ?? 'Nos.';

      final unitPrice = (productData['unitPrice'] as num?)?.toDouble() ?? (productData['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      _items[index].rateCtrl.text = unitPrice.toString();
      _items[index].gstCtrl.text = (productData['gstPercentage'] ?? 18).toString();

      _items[index].isExpanded = true; // Auto-expand row on selection to show Info Panel
      _items[index].updateCalculations(_isInterState);
      _debouncedCalculateTotals();
    });
  }

  void _onProductSelected(int index, Map<String, dynamic> productData) {
    RecentProducts.add(productData);
    int existingIndex = _items.indexWhere((item) => item.productId == productData['id'] && _items.indexOf(item) != index);

    if (existingIndex != -1) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Product Already Added'),
              content: const Text('Do you want to merge quantity with the existing row?'),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _applyProductToRow(index, productData);
                      _items[index].descFocus.requestFocus();
                    },
                    child: const Text('Add as New Row')
                ),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _items[existingIndex].qty += 1.0;
                        _items[existingIndex].qtyCtrl.text = _items[existingIndex].qty.toString();
                        _items[existingIndex].updateCalculations(_isInterState);
                        _items[index].clear();
                        _debouncedCalculateTotals();
                      });
                      _items[existingIndex].qtyFocus.requestFocus();
                    },
                    child: const Text('Merge Quantity')
                )
              ]
          )
      );
    } else {
      _applyProductToRow(index, productData);
      _items[index].descFocus.requestFocus();
    }
  }

  void _addNewRow() {
    setState(() => _items.add(_InvoiceItem()));
  }

  void _removeItem(_InvoiceItem item) {
    if (_items.length > 1) {
      FocusScope.of(context).unfocus();
      setState(() {
        item.dispose();
        _items.remove(item);
      });
      _debouncedCalculateTotals();
    }
  }

  void _duplicateItem(_InvoiceItem oldItem) {
    setState(() {
      final index = _items.indexOf(oldItem);
      final newItem = _InvoiceItem();
      newItem.productId = oldItem.productId;
      newItem.sku = oldItem.sku;
      newItem.itemCode = oldItem.itemCode;
      newItem.productNature = oldItem.productNature;
      newItem.trackInventory = oldItem.trackInventory;
      newItem.availableStock = oldItem.availableStock;
      newItem.category = oldItem.category;
      newItem.subCategory = oldItem.subCategory;
      newItem.brand = oldItem.brand;
      newItem.machineType = oldItem.machineType;

      newItem.productCtrl.text = oldItem.productCtrl.text;
      newItem.descCtrl.text = oldItem.descCtrl.text;
      newItem.scopeCtrl.text = oldItem.scopeCtrl.text;
      newItem.serialNoCtrl.text = oldItem.serialNoCtrl.text;
      newItem.warrantyCtrl.text = oldItem.warrantyCtrl.text;
      newItem.hsnCtrl.text = oldItem.hsnCtrl.text;
      newItem.uomCtrl.text = oldItem.uomCtrl.text;
      newItem.qtyCtrl.text = oldItem.qtyCtrl.text;
      newItem.rateCtrl.text = oldItem.rateCtrl.text;
      newItem.discCtrl.text = oldItem.discCtrl.text;
      newItem.gstCtrl.text = oldItem.gstCtrl.text;

      newItem.updateCalculations(_isInterState);
      _items.insert(index + 1, newItem);
    });
    _debouncedCalculateTotals();
  }

  void _moveRow(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  double _parse(String val) => double.tryParse(val.replaceAll(',', '')) ?? 0.0;

  void _calculateTotals() {
    final totals = InvoiceTotals();

    for (var item in _items) {
      item.updateCalculations(_isInterState);
      totals.totalQty += item.qty;
      totals.totalTaxable += item.taxableValue;
      totals.totalCgst += item.cgstAmt;
      totals.totalSgst += item.sgstAmt;
      totals.totalIgst += item.igstAmt;
    }

    totals.totalGst = totals.totalCgst + totals.totalSgst + totals.totalIgst;

    double freight = _parse(_freightCtrl.text);
    double packing = _parse(_packingCtrl.text);
    double others = _parse(_otherChargesCtrl.text);

    double rawTotal = totals.totalTaxable + totals.totalGst + freight + packing + others;
    double rounded = rawTotal.roundToDouble();
    totals.roundOff = rounded - rawTotal;
    totals.grandTotal = rounded;

    totals.amountInWords = _numberToWordsIndian(totals.grandTotal.toInt());

    // Update Notifier instead of global setState
    _totalsNotifier.value = totals;
  }

  String _numberToWordsIndian(int number) {
    if (number == 0) return "Zero Rupees Only";
    final units = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"];
    final tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];
    String convert(int n) {
      if (n < 20) return units[n];
      if (n < 100) return "${tens[n ~/ 10]} ${units[n % 10]}".trim();
      if (n < 1000) return "${units[n ~/ 100]} Hundred ${convert(n % 100)}".trim();
      if (n < 100000) return "${convert(n ~/ 1000)} Thousand ${convert(n % 1000)}".trim();
      if (n < 10000000) return "${convert(n ~/ 100000)} Lakh ${convert(n % 100000)}".trim();
      return "${convert(n ~/ 10000000)} Crore ${convert(n % 10000000)}".trim();
    }
    return "Rupees ${convert(number)} Only";
  }

  Future<void> _submitInvoice(String status) async {
    final shouldDeductStock = status == 'FINAL';

    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Customer from the dropdown.'), backgroundColor: Colors.red));
      return;
    }

    if (_selectedBillToAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Billing Address.'), backgroundColor: Colors.red));
      return;
    }

    if (_items.isEmpty || _items.every((i) => i.productCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one product'), backgroundColor: Colors.red));
      return;
    }

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.productCtrl.text.trim().isEmpty) continue;
      if (item.productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Item ${i+1}: Please select a valid product from the dropdown.'), backgroundColor: Colors.red));
        return;
      }
      if (item.qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Item ${i+1}: Quantity must be > 0'), backgroundColor: Colors.red));
        return;
      }
      if (shouldDeductStock && item.trackInventory && item.qty > item.availableStock) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Item ${i+1}: Insufficient stock for ${item.productCtrl.text}\nAvailable: ${item.availableStock} | Required: ${item.qty}'), backgroundColor: Colors.red));
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final totals = _totalsNotifier.value;
      final fyKey = _financialYear.replaceAll('-', '_');
      final counterRef = _db.collection('companies').doc(widget.companyId).collection('metadata').doc('tax_invoice_counter_$fyKey');

      String manualSeqStr = _sequenceNoCtrl.text.trim();
      String preCheckInvoiceNo = manualSeqStr.isNotEmpty ? '$_invoicePrefix/${_formatSequence(manualSeqStr)}/$_financialYear' : '';

      Map<String, double> requiredQuantities = {};
      if (shouldDeductStock) {
        for (var item in _items) {
          if (item.productCtrl.text.trim().isEmpty) continue;
          if (item.productId != null && item.trackInventory) {
            requiredQuantities[item.productId!] = (requiredQuantities[item.productId!] ?? 0) + item.qty;
          }
        }
      }

      await _db.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);

        Map<String, DocumentSnapshot> productSnaps = {};
        if (shouldDeductStock) {
          for (String pId in requiredQuantities.keys) {
            productSnaps[pId] = await transaction.get(_db.collection('companies').doc(widget.companyId).collection('products').doc(pId));
          }
        }

        int currentCount = counterSnap.exists ? (counterSnap.data()?['count'] ?? 0) : 0;
        String finalSeqStr = manualSeqStr.isEmpty ? _formatSequence((currentCount + 1).toString()) : manualSeqStr;
        String finalInvoiceNo = manualSeqStr.isEmpty ? '$_invoicePrefix/$finalSeqStr/$_financialYear' : preCheckInvoiceNo;

        final lockRef = _db.collection('companies').doc(widget.companyId).collection('invoice_number_locks').doc(finalInvoiceNo.replaceAll('/', '_'));
        final lockSnap = await transaction.get(lockRef);
        if (lockSnap.exists) throw Exception('Invoice Number Already Exists: $finalInvoiceNo');

        Map<String, double> newStockValues = {};
        if (shouldDeductStock) {
          for (String pId in requiredQuantities.keys) {
            final snap = productSnaps[pId]!;
            if (!snap.exists) throw Exception('Product data missing for one of the selected items.');

            final currentStock = ((snap.data() as Map<String, dynamic>? ?? {})['stockOnHand'] as num?)?.toDouble() ?? 0.0;
            final reqQty = requiredQuantities[pId]!;
            if (currentStock < reqQty) throw Exception('Insufficient stock for ${(snap.data() as Map)['name']}.\nAvailable: $currentStock\nRequired: $reqQty');
            newStockValues[pId] = currentStock - reqQty;
          }
        }

        if (manualSeqStr.isEmpty) {
          transaction.set(counterRef, {'count': currentCount + 1}, SetOptions(merge: true));
        } else {
          int parsedUserSeq = int.tryParse(finalSeqStr) ?? 0;
          if (parsedUserSeq > currentCount) transaction.set(counterRef, {'count': parsedUserSeq}, SetOptions(merge: true));
        }

        transaction.set(lockRef, {
          'invoiceNumber': finalInvoiceNo, 'createdAt': FieldValue.serverTimestamp(), 'createdBy': widget.userUid,
          'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': widget.userUid, 'isActive': true, 'isDeleted': false,
        });

        final invoiceRef = _db.collection('companies').doc(widget.companyId).collection('tax_invoices').doc();

        if (shouldDeductStock) {
          for (String pId in requiredQuantities.keys) {
            transaction.update(productSnaps[pId]!.reference, {'stockOnHand': newStockValues[pId]});
          }

          Map<String, double> runningStock = {};
          for (String pId in requiredQuantities.keys) {
            runningStock[pId] = ((productSnaps[pId]!.data() as Map<String, dynamic>? ?? {})['stockOnHand'] as num?)?.toDouble() ?? 0.0;
          }

          for (var item in _items) {
            if (item.productCtrl.text.trim().isEmpty) continue;
            if (item.productId != null && item.trackInventory) {
              final pId = item.productId!;
              final beforeStock = runningStock[pId]!;
              final afterStock = beforeStock - item.qty;
              runningStock[pId] = afterStock;

              final invRef = _db.collection('companies').doc(widget.companyId).collection('inventory_transactions').doc();
              transaction.set(invRef, {
                'id': invRef.id, 'companyId': widget.companyId, 'transactionType': 'SALES_INVOICE',
                'invoiceId': invoiceRef.id, 'invoiceNumber': finalInvoiceNo, 'financialYear': _financialYear,
                'productId': pId, 'productName': item.productCtrl.text.trim(), 'sku': item.sku, 'itemCode': item.itemCode,
                'customerId': _selectedCustomerId, 'customerName': _selectedCustomerName,
                'quantity': item.qty, 'unitPrice': item.rate, 'taxableAmount': item.taxableValue,
                'gstAmount': item.cgstAmt + item.sgstAmt + item.igstAmt, 'totalAmount': item.lineTotal,
                'beforeStock': beforeStock, 'afterStock': afterStock,
                'createdAt': FieldValue.serverTimestamp(), 'createdBy': widget.userUid,
                'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': widget.userUid,
                'isActive': true, 'isDeleted': false,
              });
            }
          }
        }

        final itemsData = _items.where((i) => i.productCtrl.text.trim().isNotEmpty).map((i) => {
          'productId': i.productId, 'productName': i.productCtrl.text.trim(), 'sku': i.sku,
          'itemCode': i.itemCode, 'barcode': i.barcode, 'description': i.descCtrl.text.trim(),
          'scopeOfSupply': i.scopeCtrl.text.trim(), 'productNature': i.productNature,
          'machineSerialNo': i.serialNoCtrl.text.trim(), 'warrantyPeriod': i.warrantyCtrl.text.trim(),
          'trackInventory': i.trackInventory, 'hsnCode': i.hsnCtrl.text.trim(), 'uom': i.uomCtrl.text.trim(),
          'quantity': i.qty, 'unitPrice': i.rate, 'rate': i.rate, 'discountPercent': i.discPct,
          'taxableAmount': i.taxableValue, 'taxableValue': i.taxableValue,
          'gstPercentage': i.gstPct, 'gstPercent': i.gstPct, 'cgstPercent': i.cgstPct, 'cgstAmount': i.cgstAmt,
          'sgstPercent': i.sgstPct, 'sgstAmount': i.sgstAmt, 'igstPercent': i.igstPct, 'igstAmount': i.igstAmt,
          'gstAmount': i.cgstAmt + i.sgstAmt + i.igstAmt, 'totalAmount': i.lineTotal, 'lineTotal': i.lineTotal,
        }).toList();

        final data = {
          'id': invoiceRef.id, 'companyId': widget.companyId, 'invoiceType': 'DOMESTIC', 'status': status,
          'invoiceNumber': finalInvoiceNo, 'prefix': _invoicePrefix, 'sequenceNo': int.tryParse(finalSeqStr) ?? 0, 'financialYear': _financialYear,
          'invoiceDate': _selectedInvoiceDate.toIso8601String(), 'isInterState': _isInterState, 'reverseCharge': _reverseCharge,
          'dateOfSupply': _selectedSupplyDate?.toIso8601String(), 'placeOfSupply': _placeOfSupplyCtrl.text.trim(),
          'ewayBillNumber': _ewayBillNoCtrl.text.trim(), 'ewayBillDate': _ewayBillDateCtrl.text.trim(),
          'irn': _irnCtrl.text.trim(), 'ackNo': _ackNoCtrl.text.trim(), 'ackDate': _ackDateCtrl.text.trim(),
          'customerId': _selectedCustomerId, 'customerName': _selectedCustomerName, 'customerCode': _selectedCustomerCode,
          'billToAddressId': _selectedBillToAddress?['id'], 'billToAddressType': _selectedBillToAddress?['type'],
          'billToAddressSnapshot': _selectedBillToAddress, 'billToContactId': _selectedBillToContact?['id'],
          'billToName': _billToCustomerCtrl.text.trim(), 'billToGstin': _billToGstinCtrl.text.trim(),
          'billToAddress': _billToAddressCtrl.text.trim(), 'billToState': _billToStateCtrl.text.trim(), 'billToStateCode': _billToStateCodeCtrl.text.trim(),
          'billToContactPerson': _billToContactPersonCtrl.text.trim(), 'billToDesignation': _billToDesignationCtrl.text.trim(),
          'billToEmail': _billToEmailCtrl.text.trim(), 'billToMobile': _billToMobileCtrl.text.trim(),
          'poNumber': _poNumberCtrl.text.trim(), 'poDate': _poDateCtrl.text.trim(),
          'shipToAddressId': _selectedShipToAddress?['id'], 'shipToAddressType': _selectedShipToAddress?['type'],
          'shipToAddressSnapshot': _selectedShipToAddress, 'shipToContactId': _selectedShipToContact?['id'],
          'shipToName': _shipToCustomerCtrl.text.trim(), 'shipToGstin': _shipToGstinCtrl.text.trim(),
          'shipToAddress': _shipToAddressCtrl.text.trim(), 'shipToState': _shipToStateCtrl.text.trim(), 'shipToStateCode': _shipToStateCodeCtrl.text.trim(),
          'shipToContactPerson': _shipToContactPersonCtrl.text.trim(), 'shipToDesignation': _shipToDesignationCtrl.text.trim(),
          'shipToMobile': _shipToMobileCtrl.text.trim(), 'shipToEmail': _shipToEmailCtrl.text.trim(),
          'salesReferences': {
            'quotationNumber': _quotationNoCtrl.text.trim(), 'quotationDate': _quotationDateCtrl.text.trim(),
            'salesOrderNumber': _salesOrderNoCtrl.text.trim(), 'salesOrderDate': _salesOrderDateCtrl.text.trim(),
            'customerReference': _customerRefCtrl.text.trim(), 'enquiryReference': _enquiryRefCtrl.text.trim(),
          },
          'packingDetails': {
            'noOfPackages': _noOfPackagesCtrl.text.trim(), 'packageType': _packageTypeCtrl.text.trim(),
            'grossWeight': _grossWeightCtrl.text.trim(), 'netWeight': _netWeightCtrl.text.trim(), 'dimensions': _dimensionsCtrl.text.trim(),
          },
          'transportDetails': {
            'transportMode': _selectedTransportMode, 'vehicleNumber': _vehicleNoCtrl.text.trim(),
            'transporterName': _transporterNameCtrl.text.trim(), 'lrNumber': _lrNoCtrl.text.trim(),
            'lrDate': _lrDateCtrl.text.trim(), 'driverName': _driverNameCtrl.text.trim(), 'driverMobile': _driverMobileCtrl.text.trim(),
          },
          'items': itemsData,
          'totals': {
            'totalQuantity': totals.totalQty, 'totalTaxable': totals.totalTaxable, 'totalCgst': totals.totalCgst, 'totalSgst': totals.totalSgst, 'totalIgst': totals.totalIgst,
            'totalGst': totals.totalGst, 'freight': _parse(_freightCtrl.text), 'packing': _parse(_packingCtrl.text),
            'otherCharges': _parse(_otherChargesCtrl.text), 'roundOff': totals.roundOff, 'grandTotal': totals.grandTotal, 'amountInWords': totals.amountInWords,
          },
          'paymentDetails': {
            'terms': _paymentTermsCtrl.text.trim(), 'mode': _paymentModeCtrl.text.trim(), 'bankName': _bankNameCtrl.text.trim(),
            'accountNumber': _bankAccNoCtrl.text.trim(), 'ifsc': _ifscCtrl.text.trim(), 'branch': _branchCtrl.text.trim(),
          },
          'remarks': _remarksCtrl.text.trim(), 'termsAndConditions': _tncCtrl.text.trim(),
          'inventoryPosted': shouldDeductStock, 'inventoryPostedAt': shouldDeductStock ? FieldValue.serverTimestamp() : null,
          'isCancelled': false, 'cancelledAt': null, 'cancelledBy': null,
          'createdAt': FieldValue.serverTimestamp(), 'createdBy': widget.userUid,
          'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': widget.userUid, 'isActive': true, 'isDeleted': false,
        };

        transaction.set(invoiceRef, data);

        if (status == 'FINAL') {
          transaction.set(_db.collection('companies').doc(widget.companyId).collection('outstanding_ledger').doc(invoiceRef.id), {
            'invoiceId': invoiceRef.id, 'customerId': _selectedCustomerId, 'customerName': _selectedCustomerName,
            'invoiceNumber': finalInvoiceNo, 'invoiceDate': _selectedInvoiceDate.toIso8601String(),
            'dueDate': _calculateDueDate().toIso8601String(), 'invoiceType': 'DOMESTIC',
            'currency': 'INR', 'exchangeRate': 1.0, 'totalAmount': totals.grandTotal, 'amountReceived': 0.0,
            'amountOutstanding': totals.grandTotal, 'baseTotalAmount': totals.grandTotal, 'baseAmountReceived': 0.0,
            'baseAmountOutstanding': totals.grandTotal, 'status': 'UNPAID',
            'createdAt': FieldValue.serverTimestamp(), 'createdBy': widget.userUid,
          });
        }

        transaction.set(_db.collection('companies').doc(widget.companyId).collection('audit_logs').doc(), {
          'action': 'CREATE_INVOICE', 'module': 'TAX_INVOICE', 'invoiceId': invoiceRef.id, 'invoiceNumber': finalInvoiceNo,
          'customerId': _selectedCustomerId, 'customerName': _selectedCustomerName, 'userUid': widget.userUid,
          'companyId': widget.companyId, 'timestamp': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.userUid, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': widget.userUid,
          'isActive': true, 'isDeleted': false,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice saved successfully as $status'), backgroundColor: Colors.green));
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('Exception: ')) msg = msg.split('Exception: ').last;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 1100;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      appBar: AppBar(
        backgroundColor: colorScheme.surface, elevation: 0, scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack),
        title: Text('New Tax Invoice', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Text('DRAFT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: colorScheme.outlineVariant, height: 1)),
      ),
      body: _isInitializing || _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(isDesktop), const SizedBox(height: 16),
                _buildSalesReferenceSection(isDesktop), const SizedBox(height: 16),
                _buildCustomerSummaryCard(), const SizedBox(height: 16),
                _buildPartySection(isDesktop), const SizedBox(height: 16),
                _buildItemTable(), const SizedBox(height: 16),
                _buildTotalsSection(isDesktop), const SizedBox(height: 16),
                _buildPackingAndTransportSection(isDesktop), const SizedBox(height: 16),
                _buildComplianceSection(isDesktop), const SizedBox(height: 16),
                _buildPaymentAndAdditionalSection(isDesktop), const SizedBox(height: 32),
                _buildActionButtons(), const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSummaryCard() {
    if (_selectedCustomerId == null) return const SizedBox.shrink();
    if (_isLoadingCustomerData) {
      return const _BaseErpCard(title: 'Customer Summary', icon: Icons.account_circle_rounded, child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())));
    }
    final colorScheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    return _BaseErpCard(
      title: 'Customer Summary', icon: Icons.assignment_ind_outlined,
      child: Wrap(
        spacing: 24, runSpacing: 16,
        children: [
          _buildSummaryData('Customer Name', _selectedCustomerName, isBold: true),
          _buildSummaryData('Customer Code', _selectedCustomerCode),
          _buildSummaryData('GSTIN', _selectedCustomerGstin),
          _buildSummaryData('State', _selectedCustomerState),
          _buildSummaryData('Outstanding', '₹${fmt.format(_selectedCustomerOutstanding)}', textColor: _selectedCustomerOutstanding > 0 ? colorScheme.error : colorScheme.primary),
          _buildSummaryData('Assigned To', _selectedCustomerAssignedTo.isEmpty ? 'N/A' : _selectedCustomerAssignedTo),
        ],
      ),
    );
  }

  Widget _buildSummaryData(String label, String value, {bool isBold = false, Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value.isEmpty ? 'N/A' : value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: textColor ?? Colors.black87)),
      ],
    );
  }

  Widget _buildInvoiceNumberField() {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice Number *', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(color: Colors.grey.shade200, border: Border.all(color: Colors.grey.shade300), borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))),
                child: Text(_invoicePrefix, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              ),
              Expanded(
                child: TextFormField(
                  controller: _sequenceNoCtrl, focusNode: _sequenceFocusNode, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                  decoration: InputDecoration(hintText: 'Auto', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), border: const OutlineInputBorder(borderRadius: BorderRadius.zero), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2), borderRadius: BorderRadius.zero)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(color: Colors.grey.shade200, border: Border.all(color: Colors.grey.shade300), borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8))),
                child: Text(_financialYear, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransportDropdown({double? width}) {
    Widget field = DropdownButtonFormField<String>(
      value: _selectedTransportMode,
      decoration: InputDecoration(labelText: 'Transport Mode', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true),
      items: _transportModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
      onChanged: (val) { if (val != null) setState(() => _selectedTransportMode = val); },
    );
    if (width != null) return SizedBox(width: width, child: field);
    return field;
  }

  Widget _buildHeaderSection(bool isDesktop) {
    return _BaseErpCard(
      title: 'Invoice Details', icon: Icons.receipt_long_rounded,
      child: Wrap(
        spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          _buildInvoiceNumberField(),
          _buildField('Invoice Date', _invoiceDateCtrl, width: 220, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_invoiceDateCtrl, initialDate: _selectedInvoiceDate, onSelect: (d) => setState(() { _selectedInvoiceDate = d; _financialYear = _calculateFinancialYear(d); _fetchProvisionalSequence(); }))),
          _buildField('Place of Supply', _placeOfSupplyCtrl, width: 220, readOnly: true),
          _buildField('Date of Supply', _dateOfSupplyCtrl, width: 220, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_dateOfSupplyCtrl, initialDate: _selectedSupplyDate, onSelect: (d) => setState(() => _selectedSupplyDate = d))),
          SizedBox(width: 220, child: CheckboxListTile(title: const Text('Reverse Charge', style: TextStyle(fontSize: 13)), value: _reverseCharge, onChanged: (val) => setState(() => _reverseCharge = val ?? false), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, dense: true)),
        ],
      ),
    );
  }

  Widget _buildSalesReferenceSection(bool isDesktop) {
    return _BaseErpCard(
      title: 'Sales References', icon: Icons.bookmark_border_rounded,
      child: Wrap(
        spacing: 16, runSpacing: 16,
        children: [
          _buildField('Quotation No.', _quotationNoCtrl, width: 220),
          _buildField('Quotation Date', _quotationDateCtrl, width: 220, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_quotationDateCtrl)),
          _buildField('Sales Order No.', _salesOrderNoCtrl, width: 220),
          _buildField('Sales Order Date', _salesOrderDateCtrl, width: 220, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_salesOrderDateCtrl)),
          _buildField('Customer Reference', _customerRefCtrl, width: 220),
          _buildField('Enquiry Reference', _enquiryRefCtrl, width: 220),
        ],
      ),
    );
  }

  Widget _buildPackingAndTransportSection(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _BaseErpCard(
          title: 'Packing Details', icon: Icons.inventory_2_outlined,
          child: Wrap(
            spacing: 16, runSpacing: 16,
            children: [
              _buildField('No. of Packages', _noOfPackagesCtrl, width: 180),
              _buildField('Package Type', _packageTypeCtrl, width: 180),
              _buildField('Gross Weight (KG)', _grossWeightCtrl, width: 180),
              _buildField('Net Weight (KG)', _netWeightCtrl, width: 180),
              _buildField('Dimensions', _dimensionsCtrl, width: 180),
            ],
          ),
        )),
        const SizedBox(width: 16),
        Expanded(child: _BaseErpCard(
          title: 'Transport & Logistics', icon: Icons.local_shipping_outlined,
          child: Wrap(
            spacing: 16, runSpacing: 16,
            children: [
              _buildTransportDropdown(width: 220),
              _buildField('Vehicle Number', _vehicleNoCtrl, width: 220),
              _buildField('Transporter Name', _transporterNameCtrl, width: 220),
              _buildField('LR / GR Number', _lrNoCtrl, width: 220),
              _buildField('LR / GR Date', _lrDateCtrl, width: 220, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_lrDateCtrl)),
              _buildField('Driver Name', _driverNameCtrl, width: 220),
              _buildField('Driver Mobile', _driverMobileCtrl, width: 220),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildComplianceSection(bool isDesktop) {
    return _BaseErpCard(
      title: 'E-Invoicing & E-Way Bill (Optional)', icon: Icons.qr_code_scanner_rounded,
      child: Wrap(
        spacing: 16, runSpacing: 16,
        children: [
          _buildField('IRN', _irnCtrl, width: 350), _buildField('Ack No', _ackNoCtrl, width: 220),
          _buildField('Ack Date', _ackDateCtrl, width: 220, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_ackDateCtrl)),
          _buildField('E-Way Bill No', _ewayBillNoCtrl, width: 220), _buildField('E-Way Bill Date', _ewayBillDateCtrl, width: 220, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_ewayBillDateCtrl)),
        ],
      ),
    );
  }

  Widget _buildPartySection(bool isDesktop) {
    if (isDesktop) {
      return Row(children: [Expanded(child: _buildPartyCard(isBillTo: true)), const SizedBox(width: 16), Expanded(child: _buildPartyCard(isBillTo: false))]);
    }
    return Column(children: [_buildPartyCard(isBillTo: true), const SizedBox(height: 16), _buildPartyCard(isBillTo: false)]);
  }

  Widget _buildPartyCard({required bool isBillTo}) {
    final title = isBillTo ? 'Bill To Party' : 'Ship To Party';
    final icon = isBillTo ? Icons.business_rounded : Icons.local_shipping_rounded;
    final customerCtrl = isBillTo ? _billToCustomerCtrl : _shipToCustomerCtrl;
    final gstinCtrl = isBillTo ? _billToGstinCtrl : _shipToGstinCtrl;
    final addressCtrl = isBillTo ? _billToAddressCtrl : _shipToAddressCtrl;
    final stateCtrl = isBillTo ? _billToStateCtrl : _shipToStateCtrl;
    final stateCodeCtrl = isBillTo ? _billToStateCodeCtrl : _shipToStateCodeCtrl;
    final contactPersonCtrl = isBillTo ? _billToContactPersonCtrl : _shipToContactPersonCtrl;
    final designationCtrl = isBillTo ? _billToDesignationCtrl : _shipToDesignationCtrl;
    final emailCtrl = isBillTo ? _billToEmailCtrl : _shipToEmailCtrl;
    final mobileCtrl = isBillTo ? _billToMobileCtrl : _shipToMobileCtrl;
    final selectedAddress = isBillTo ? _selectedBillToAddress : _selectedShipToAddress;
    final selectedContact = isBillTo ? _selectedBillToContact : _selectedShipToContact;

    Widget trailing = isBillTo ? const SizedBox.shrink() : Row(mainAxisSize: MainAxisSize.min, children: [
      Checkbox(value: _sameAsBillTo, onChanged: (val) { setState(() { _sameAsBillTo = val ?? true; if (_sameAsBillTo) _syncShipTo(); }); }),
      const Text('Same As Bill To', style: TextStyle(fontSize: 13)),
    ]);

    if (!isBillTo && _sameAsBillTo) {
      return _BaseErpCard(title: title, icon: icon, headerTrailing: trailing, child: Container(height: 300, alignment: Alignment.center, child: const Text('Shipping details synced from billing.', style: TextStyle(color: Colors.grey))));
    }

    return _BaseErpCard(
      title: title, icon: icon, headerTrailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isBillTo) ...[
            _ErpCustomerAutocomplete(companyId: widget.companyId, userUid: widget.userUid, currentUserRole: _currentUserRole, controller: customerCtrl, label: 'Select Customer *', onSelected: _loadCustomerDetails),
            const SizedBox(height: 16),
          ] else ...[
            _buildField('Customer Name', customerCtrl, readOnly: true), const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Location Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                if (_customerAddresses.isNotEmpty) ...[
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: (selectedAddress != null && _customerAddresses.any((a) => a['id'] == selectedAddress['id'])) ? _customerAddresses.firstWhere((a) => a['id'] == selectedAddress['id']) : null,
                    decoration: InputDecoration(labelText: 'Select Address Type *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true, filled: true, fillColor: Colors.white),
                    items: _customerAddresses.map((addr) {
                      String label = '${addr['type'] == 'Other' ? addr['customType'] : addr['type']} - ${addr['city'] ?? ''}';
                      if (addr['isPrimary'] == true) label += ' (Primary)';
                      else if (addr['isBillingAddress'] == true && isBillTo) label += ' (Billing)';
                      else if (addr['isShippingAddress'] == true && !isBillTo) label += ' (Shipping)';
                      return DropdownMenuItem<Map<String, dynamic>>(value: addr, child: Text(label, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() {
                        if (isBillTo) _selectedBillToAddress = val; else _selectedShipToAddress = val;
                        _applyAddressSelection(val, isBillTo);
                        if (isBillTo && _sameAsBillTo) _syncShipTo();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _buildField('Address', addressCtrl, lines: 2), const SizedBox(height: 12),
                Row(children: [Expanded(child: _buildField('State', stateCtrl, readOnly: true)), const SizedBox(width: 12), Expanded(child: _buildField('State Code', stateCodeCtrl, readOnly: true))]),
                const SizedBox(height: 12), _buildField('GSTIN', gstinCtrl),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact Person Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                if (_customerContacts.isNotEmpty) ...[
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: (selectedContact != null && _customerContacts.any((c) => c['id'] == selectedContact['id'])) ? _customerContacts.firstWhere((c) => c['id'] == selectedContact['id']) : null,
                    decoration: InputDecoration(labelText: 'Select Contact Person', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true, filled: true, fillColor: Colors.white),
                    items: _customerContacts.map((c) {
                      String label = c['name'] ?? c['contactName'] ?? 'Unknown';
                      if ((c['designation'] ?? '').toString().isNotEmpty) label += ' - ${c['designation']}';
                      if (c['isPrimary'] == true) label += ' (Primary)';
                      return DropdownMenuItem<Map<String, dynamic>>(value: c, child: Text(label, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() {
                        if (isBillTo) _selectedBillToContact = val; else _selectedShipToContact = val;
                        _applyContactSelection(val, isBillTo);
                        if (isBillTo && _sameAsBillTo) _syncShipTo();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Row(children: [Expanded(child: _buildField('Name', contactPersonCtrl)), const SizedBox(width: 12), Expanded(child: _buildField('Designation', designationCtrl))]),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: _buildField('Mobile', mobileCtrl)), const SizedBox(width: 12), Expanded(child: _buildField('Email', emailCtrl))]),
              ],
            ),
          ),
          if (isBillTo) ...[
            const Divider(height: 32),
            Row(children: [Expanded(child: _buildField('PO Number', _poNumberCtrl)), const SizedBox(width: 12), Expanded(child: _buildField('PO Date', _poDateCtrl, icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_poDateCtrl)))])
          ]
        ],
      ),
    );
  }

  Widget _buildItemTable() {
    return _BaseErpCard(
      title: 'Item Details', icon: Icons.grid_on, padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: const [
              SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text('Product Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('GST%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
              SizedBox(width: 60),
            ]),
          ),
          ReorderableListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: _moveRow,
            itemBuilder: (context, index) {
              final item = _items[index];
              return _InvoiceRowWidget(
                key: ValueKey(item.rowId),
                index: index,
                item: item,
                isInterState: _isInterState,
                onProductSelected: (res) => _onProductSelected(index, res),
                onRemove: () => _removeItem(item),
                onDuplicate: () => _duplicateItem(item),
                onTotalsChange: _debouncedCalculateTotals,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _addNewRow, icon: const Icon(Icons.add), label: const Text('Add Line Item'))),
          )
        ],
      ),
    );
  }

  Widget _buildTotalsSection(bool isDesktop) {
    if (isDesktop) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: _buildAmountInWords()), const SizedBox(width: 16), Expanded(flex: 5, child: _buildCalculationCard())]);
    return Column(children: [_buildCalculationCard(), const SizedBox(height: 16), _buildAmountInWords()]);
  }

  Widget _buildAmountInWords() => _BaseErpCard(
      title: 'Amount in Words', icon: Icons.text_fields_rounded,
      child: ValueListenableBuilder<InvoiceTotals>(
          valueListenable: _totalsNotifier,
          builder: (context, totals, child) {
            return Text(totals.amountInWords, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));
          }
      )
  );

  Widget _buildCalculationCard() {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    return _BaseErpCard(
      title: 'Invoice Totals', icon: Icons.calculate_outlined,
      child: ValueListenableBuilder<InvoiceTotals>(
          valueListenable: _totalsNotifier,
          builder: (context, totals, child) {
            return Column(
              children: [
                _SummaryRow(label: 'Total Quantity', value: totals.totalQty.toStringAsFixed(2)),
                _SummaryRow(label: 'Total Taxable Value', value: '₹${fmt.format(totals.totalTaxable)}'), const Divider(),
                _SummaryRow(label: 'Total CGST', value: '₹${fmt.format(totals.totalCgst)}'),
                _SummaryRow(label: 'Total SGST', value: '₹${fmt.format(totals.totalSgst)}'),
                _SummaryRow(label: 'Total IGST', value: '₹${fmt.format(totals.totalIgst)}'),
                _SummaryRow(label: 'Total GST Amount', value: '₹${fmt.format(totals.totalGst)}', boldValue: true), const Divider(),
                Row(children: [const Expanded(child: Text('Freight Charges', style: TextStyle(fontSize: 13))), SizedBox(width: 100, child: _buildTableField(_freightCtrl, '0.00', isNumber: true, alignRight: true))]), const SizedBox(height: 8),
                Row(children: [const Expanded(child: Text('Packing Charges', style: TextStyle(fontSize: 13))), SizedBox(width: 100, child: _buildTableField(_packingCtrl, '0.00', isNumber: true, alignRight: true))]), const SizedBox(height: 8),
                Row(children: [const Expanded(child: Text('Other Charges', style: TextStyle(fontSize: 13))), SizedBox(width: 100, child: _buildTableField(_otherChargesCtrl, '0.00', isNumber: true, alignRight: true))]), const Divider(),
                _SummaryRow(label: 'Round Off', value: '₹${totals.roundOff.toStringAsFixed(2)}'), const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Grand Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), Text('₹${fmt.format(totals.grandTotal)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary))])),
              ],
            );
          }
      ),
    );
  }

  Widget _buildPaymentAndAdditionalSection(bool isDesktop) {
    if (isDesktop) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _buildPaymentDetails()), const SizedBox(width: 16), Expanded(child: _buildAdditionalDetails())]);
    return Column(children: [_buildPaymentDetails(), const SizedBox(height: 16), _buildAdditionalDetails()]);
  }

  Widget _buildPaymentDetails() {
    return _BaseErpCard(
      title: 'Payment Details', icon: Icons.account_balance_wallet_rounded,
      child: Column(children: [
        Row(children: [Expanded(child: _buildField('Payment Terms', _paymentTermsCtrl)), const SizedBox(width: 12), Expanded(child: _buildField('Payment Mode', _paymentModeCtrl))]), const SizedBox(height: 12),
        Row(children: [Expanded(child: _buildField('Bank Account Number', _bankAccNoCtrl)), const SizedBox(width: 12), Expanded(child: _buildField('Bank Name', _bankNameCtrl))]), const SizedBox(height: 12),
        Row(children: [Expanded(child: _buildField('Branch', _branchCtrl)), const SizedBox(width: 12), Expanded(child: _buildField('IFSC', _ifscCtrl))]),
      ]),
    );
  }

  Widget _buildAdditionalDetails() {
    return _BaseErpCard(
      title: 'Additional Details', icon: Icons.note_add_rounded,
      child: Column(children: [_buildField('Remarks / Notes', _remarksCtrl, lines: 3), const SizedBox(height: 12), _buildField('Terms & Conditions', _tncCtrl, lines: 6)]),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 16, runSpacing: 16, alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(onPressed: () => _submitInvoice('DRAFT'), icon: const Icon(Icons.save_outlined), label: const Text('Save Draft'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16))),
        FilledButton.icon(onPressed: () => _submitInvoice('FINAL'), icon: const Icon(Icons.send_rounded), label: const Text('Submit Invoice'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16))),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, {IconData? icon, int lines = 1, double? width, bool readOnly = false, VoidCallback? onTap}) {
    Widget field = TextFormField(controller: controller, maxLines: lines, readOnly: readOnly, onTap: onTap, style: const TextStyle(fontSize: 14), decoration: InputDecoration(labelText: label, suffixIcon: icon != null ? Icon(icon, size: 18) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true, filled: readOnly, fillColor: readOnly ? Colors.grey.shade100 : Colors.white));
    if (width != null) return SizedBox(width: width, child: field);
    return field;
  }

  Widget _buildTableField(TextEditingController controller, String hint, {bool isNumber = false, bool alignRight = false, FocusNode? focusNode, TextInputAction? textInputAction}) {
    return TextFormField(controller: controller, focusNode: focusNode, textInputAction: textInputAction, keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, textAlign: alignRight ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 13), decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))));
  }
}

/// ------------------------------------------------------------------------
/// DEDICATED ROW WIDGET (ELIMINATES LAG BY SCOPING SETSTATE)
/// ------------------------------------------------------------------------
class _InvoiceRowWidget extends StatefulWidget {
  final int index;
  final _InvoiceItem item;
  final bool isInterState;
  final Function(Map<String, dynamic>) onProductSelected;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onTotalsChange;

  const _InvoiceRowWidget({
    super.key,
    required this.index,
    required this.item,
    required this.isInterState,
    required this.onProductSelected,
    required this.onRemove,
    required this.onDuplicate,
    required this.onTotalsChange,
  });

  @override
  State<_InvoiceRowWidget> createState() => _InvoiceRowWidgetState();
}

class _InvoiceRowWidgetState extends State<_InvoiceRowWidget> {
  @override
  void initState() {
    super.initState();
    widget.item.qtyCtrl.addListener(_onFieldChanged);
    widget.item.rateCtrl.addListener(_onFieldChanged);
    widget.item.discCtrl.addListener(_onFieldChanged);
    widget.item.gstCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    widget.item.qtyCtrl.removeListener(_onFieldChanged);
    widget.item.rateCtrl.removeListener(_onFieldChanged);
    widget.item.discCtrl.removeListener(_onFieldChanged);
    widget.item.gstCtrl.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {
      widget.item.updateCalculations(widget.isInterState);
    });
    widget.onTotalsChange();
  }

  Widget _buildExpandedField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))
      ),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        const SizedBox(height: 2),
        Text(value.isEmpty ? 'N/A' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200)), color: item.isExpanded ? Colors.blue.shade50.withOpacity(0.3) : Colors.white),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 30, child: ReorderableDragStartListener(index: widget.index, child: const Icon(Icons.drag_indicator, color: Colors.grey, size: 20))),
                Expanded(flex: 3, child: _ErpProductAutocomplete(controller: item.productCtrl, label: 'Search Product', onSelected: widget.onProductSelected)),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: Text(item.trackInventory ? item.availableStock.toString() : 'N/A', style: TextStyle(color: item.trackInventory && item.qty > item.availableStock ? Colors.red : Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: TextFormField(controller: item.qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: TextFormField(controller: item.rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: TextFormField(controller: item.gstCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: Text(item.lineTotal.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                SizedBox(width: 60, child: Row(children: [
                  InkWell(onTap: () => setState(() => item.isExpanded = !item.isExpanded), child: Icon(item.isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.blue)),
                  const SizedBox(width: 8),
                  InkWell(onTap: widget.onRemove, child: const Icon(Icons.delete_outline, size: 20, color: Colors.red)),
                ])),
              ],
            ),
          ),
          if (item.isExpanded) Padding(
            padding: const EdgeInsets.only(left: 46, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Editable Fields
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildExpandedField(item.descCtrl, 'Description')),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: _buildExpandedField(item.hsnCtrl, 'HSN Code')),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: _buildExpandedField(item.uomCtrl, 'UOM')),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2: Scope of Supply
                Row(
                  children: [
                    Expanded(child: _buildExpandedField(item.scopeCtrl, 'Scope Of Supply / Included Items', maxLines: 3)),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 3: Machine Serialization & Warranty
                Row(
                  children: [
                    Expanded(child: _buildExpandedField(item.serialNoCtrl, 'Machine Serial Number (e.g. INV400A-240001)')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildExpandedField(item.warrantyCtrl, 'Warranty Period (e.g. 12 Months)')),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 4: Product Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Product Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 13)),
                          InkWell(
                            onTap: widget.onDuplicate,
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 14, color: Colors.indigo.shade700),
                                const SizedBox(width: 4),
                                Text('Duplicate Row', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const Divider(),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          _buildInfoText('Product Name', item.productCtrl.text.isEmpty ? 'N/A' : item.productCtrl.text),
                          _buildInfoText('Category', item.category),
                          _buildInfoText('Sub Category', item.subCategory),
                          _buildInfoText('Brand / Make', item.brand),
                          _buildInfoText('Machine Type', item.machineType),
                          _buildInfoText('Product Nature', item.productNature),
                          _buildInfoText('SKU', item.sku),
                          _buildInfoText('Item Code', item.itemCode),
                          _buildInfoText('HSN', item.hsnCtrl.text),
                          _buildInfoText('GST', '${item.gstCtrl.text}%'),
                          _buildInfoText('UOM', item.uomCtrl.text),
                          _buildInfoText('Current Stock', '${item.availableStock} ${item.trackInventory ? '' : '(Not Tracked)'}'),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _InvoiceItem {
  final String rowId = UniqueKey().toString();
  bool isExpanded = false;
  String? productId;
  String sku = '';
  String itemCode = '';
  String barcode = '';
  String productNature = '';

  // Extra Meta Information
  String category = '';
  String subCategory = '';
  String brand = '';
  String machineType = '';

  bool trackInventory = false;
  double availableStock = 0.0;
  double reorderLevel = 0.0;
  double minStockLevel = 0.0;

  final TextEditingController productCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController scopeCtrl = TextEditingController();

  // Extra Tracking Controllers
  final TextEditingController serialNoCtrl = TextEditingController();
  final TextEditingController warrantyCtrl = TextEditingController();

  final TextEditingController hsnCtrl = TextEditingController();
  final TextEditingController uomCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController rateCtrl = TextEditingController(text: '0');
  final TextEditingController discCtrl = TextEditingController(text: '0');
  final TextEditingController gstCtrl = TextEditingController(text: '0');

  final FocusNode qtyFocus = FocusNode();
  final FocusNode rateFocus = FocusNode();
  final FocusNode discFocus = FocusNode();
  final FocusNode gstFocus = FocusNode();
  final FocusNode descFocus = FocusNode();
  final FocusNode scopeFocus = FocusNode();
  final FocusNode hsnFocus = FocusNode();
  final FocusNode uomFocus = FocusNode();

  double qty = 0, rate = 0, discPct = 0, gstPct = 0;
  double taxableValue = 0, cgstPct = 0, sgstPct = 0, igstPct = 0;
  double cgstAmt = 0, sgstAmt = 0, igstAmt = 0, lineTotal = 0;

  _InvoiceItem();

  void clear() {
    productId = null; sku = ''; itemCode = ''; barcode = ''; productNature = ''; trackInventory = false; availableStock = 0.0; reorderLevel = 0.0; minStockLevel = 0.0;
    category = ''; subCategory = ''; brand = ''; machineType = '';
    productCtrl.clear(); descCtrl.clear(); scopeCtrl.clear(); serialNoCtrl.clear(); warrantyCtrl.clear(); hsnCtrl.clear(); uomCtrl.clear(); qtyCtrl.text = '1'; rateCtrl.text = '0'; discCtrl.text = '0'; gstCtrl.text = '0';
    updateCalculations(false);
  }

  void updateCalculations(bool isInterState) {
    qty = double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? 0.0;
    rate = double.tryParse(rateCtrl.text.replaceAll(',', '')) ?? 0.0;
    discPct = double.tryParse(discCtrl.text.replaceAll(',', '')) ?? 0.0;
    gstPct = double.tryParse(gstCtrl.text.replaceAll(',', '')) ?? 0.0;

    double baseValue = qty * rate;
    double discountAmt = baseValue * (discPct / 100);
    taxableValue = baseValue - discountAmt;

    if (isInterState) { igstPct = gstPct; cgstPct = 0; sgstPct = 0; }
    else { igstPct = 0; cgstPct = gstPct / 2; sgstPct = gstPct / 2; }

    igstAmt = taxableValue * (igstPct / 100);
    cgstAmt = taxableValue * (cgstPct / 100);
    sgstAmt = taxableValue * (sgstPct / 100);
    lineTotal = taxableValue + igstAmt + cgstAmt + sgstAmt;
  }

  void dispose() {
    productCtrl.dispose(); descCtrl.dispose(); scopeCtrl.dispose(); serialNoCtrl.dispose(); warrantyCtrl.dispose(); hsnCtrl.dispose(); uomCtrl.dispose(); qtyCtrl.dispose(); rateCtrl.dispose(); discCtrl.dispose(); gstCtrl.dispose();
    qtyFocus.dispose(); rateFocus.dispose(); discFocus.dispose(); gstFocus.dispose(); descFocus.dispose(); scopeFocus.dispose(); hsnFocus.dispose(); uomFocus.dispose();
  }
}

class _BaseErpCard extends StatelessWidget {
  final String title; final IconData icon; final Widget child; final EdgeInsetsGeometry? padding; final Widget? headerTrailing;
  const _BaseErpCard({required this.title, required this.icon, required this.child, this.padding, this.headerTrailing});
  @override Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(elevation: 0, color: colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colorScheme.outlineVariant)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), border: Border(bottom: BorderSide(color: colorScheme.outlineVariant))), child: Row(children: [Icon(icon, size: 20, color: colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))), if (headerTrailing != null) headerTrailing!])), Padding(padding: padding ?? const EdgeInsets.all(16.0), child: child)]));
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value; final bool boldValue;
  const _SummaryRow({required this.label, required this.value, this.boldValue = false});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)), Text(value, style: TextStyle(fontWeight: boldValue ? FontWeight.bold : FontWeight.w600, fontSize: 14))]));
}

class _ErpCustomerAutocomplete extends StatefulWidget {
  final String companyId; final String? userUid; final String currentUserRole; final TextEditingController controller; final String label; final Function(Map<String, dynamic>) onSelected;
  const _ErpCustomerAutocomplete({required this.companyId, this.userUid, required this.currentUserRole, required this.controller, required this.label, required this.onSelected});
  @override State<_ErpCustomerAutocomplete> createState() => _ErpCustomerAutocompleteState();
}

class _ErpCustomerAutocompleteState extends State<_ErpCustomerAutocomplete> {
  List<Map<String, dynamic>> _customerCache = [];
  bool _isLoadingCache = true; double _fieldWidth = 0;
  final FocusNode _focusNode = FocusNode();

  @override void initState() {
    super.initState();
    _loadInitialCache();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.controller.text.isEmpty) {
        final current = widget.controller.value;
        widget.controller.value = current.copyWith(text: ' '); widget.controller.value = current.copyWith(text: '');
      }
    });
  }

  @override void dispose() { _focusNode.dispose(); super.dispose(); }

  Query<Map<String, dynamic>> _buildBaseQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('customers');
    if (!isAdminRole(widget.currentUserRole) && (widget.userUid ?? '').isNotEmpty) query = query.where('assignedToUid', isEqualTo: widget.userUid);
    return query;
  }

  bool _passesLocalFilter(Map<String, dynamic> data) {
    if (data['isDeleted'] == true || data['isDeleted'] == 'true') return false;
    if (isAdminRole(widget.currentUserRole)) return true;
    if ((widget.userUid ?? '').isNotEmpty && (data['assignedToUid'] ?? data['assignedTo'] ?? '').toString() == widget.userUid) return true;
    return false;
  }

  Future<void> _loadInitialCache() async {
    try {
      List<Map<String, dynamic>> loaded = [];
      DocumentSnapshot? lastDoc; bool fetchMore = true;
      while (fetchMore) {
        Query<Map<String, dynamic>> q = _buildBaseQuery().limit(500);
        if (lastDoc != null) q = q.startAfterDocument(lastDoc!);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        lastDoc = snap.docs.last;
        if (snap.docs.length < 500) fetchMore = false;
        for (var doc in snap.docs) { if (_passesLocalFilter(doc.data())) loaded.add({'id': doc.id, ...doc.data()}); }
      }
      if (mounted) setState(() { _customerCache = loaded; _isLoadingCache = false; });
    } catch (_) { if (mounted) setState(() => _isLoadingCache = false); }
  }

  int _scoreMatch(Map<String, dynamic> c, String q) {
    int score = 0;
    final name = (c['companyName'] ?? c['name'] ?? '').toString().toLowerCase();
    final code = (c['customerCode'] ?? '').toString().toLowerCase();
    final phone = (c['phone'] ?? c['companyPhone'] ?? c['mobile'] ?? '').toString().toLowerCase();
    final email = (c['email'] ?? c['businessEmail'] ?? '').toString().toLowerCase();
    final gst = (c['gst'] ?? c['gstin'] ?? '').toString().toLowerCase();
    if (name == q) score += 100; else if (name.startsWith(q)) score += 80; else if (name.contains(q)) score += 50;
    if (code == q) score += 90; else if (code.startsWith(q)) score += 70; else if (code.contains(q)) score += 40;
    if (phone.contains(q)) score += 60; if (email.contains(q)) score += 60; if (gst.contains(q)) score += 60;
    return score;
  }

  Future<Iterable<Map<String, dynamic>>> _getOptions(TextEditingValue textEditingValue) async {
    final query = textEditingValue.text.trim().toLowerCase();
    if (query.isEmpty) return _customerCache.isEmpty ? [{'isEmpty': true}] : _customerCache;
    var localMatches = _customerCache.where((c) => _scoreMatch(c, query) > 0).toList();
    localMatches.sort((a, b) => _scoreMatch(b, query).compareTo(_scoreMatch(a, query)));
    return localMatches.isEmpty ? [{'isEmpty': true}] : localMatches;
  }

  @override Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) {
        _fieldWidth = constraints.maxWidth;
        return RawAutocomplete<Map<String, dynamic>>(
          focusNode: _focusNode, textEditingController: widget.controller,
          displayStringForOption: (opt) => opt['companyName']?.toString() ?? opt['name']?.toString() ?? '',
          optionsBuilder: _getOptions, onSelected: widget.onSelected,
          fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
            controller: ctrl, focusNode: focus, textInputAction: TextInputAction.next, style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(labelText: widget.label, suffixIcon: _isLoadingCache ? const SizedBox(width: 14, height: 14, child: Padding(padding: EdgeInsets.all(14.0), child: CircularProgressIndicator(strokeWidth: 2))) : const Icon(Icons.search, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true),
            onFieldSubmitted: (v) => onSub(),
          ),
          optionsViewBuilder: (ctx, onSel, options) {
            final colorScheme = Theme.of(context).colorScheme;
            if (options.first.containsKey('isEmpty')) return Align(alignment: Alignment.topLeft, child: Material(elevation: 8, borderRadius: BorderRadius.circular(8), color: colorScheme.surface, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: _fieldWidth), child: const Padding(padding: EdgeInsets.all(16.0), child: Text('No customers found.', style: TextStyle(color: Colors.grey))))));
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8, borderRadius: BorderRadius.circular(8), color: colorScheme.surface, clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _fieldWidth, maxHeight: 300),
                  child: ListView.builder(
                    padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                    itemBuilder: (ctx, index) {
                      final option = options.elementAt(index);
                      final compName = option['companyName']?.toString() ?? option['name']?.toString() ?? 'Unknown';
                      final custCode = option['customerCode']?.toString() ?? '';
                      final phone = option['phone']?.toString() ?? option['companyPhone']?.toString() ?? option['mobile']?.toString() ?? '';
                      String subtitle = custCode; if (subtitle.isNotEmpty && phone.isNotEmpty) subtitle += ' • '; subtitle += phone;
                      return InkWell(
                        onTap: () => onSel(option), hoverColor: colorScheme.primaryContainer.withOpacity(0.5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(compName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), if (subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(subtitle, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)))]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      }
  );
}

class _ErpProductAutocomplete extends StatefulWidget {
  final TextEditingController controller; final String label; final Function(Map<String, dynamic>) onSelected;
  const _ErpProductAutocomplete({required this.controller, required this.label, required this.onSelected});
  @override State<_ErpProductAutocomplete> createState() => _ErpProductAutocompleteState();
}

class _ErpProductAutocompleteState extends State<_ErpProductAutocomplete> {
  final FocusNode _focusNode = FocusNode();
  @override void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.controller.text.isEmpty) {
        final current = widget.controller.value;
        widget.controller.value = current.copyWith(text: ' '); widget.controller.value = current.copyWith(text: '');
      }
    });
  }
  @override void dispose() { _focusNode.dispose(); super.dispose(); }

  int _scoreMatch(Map<String, dynamic> p, String query) {
    int score = 0;
    if ((p['barcode'] ?? '').toString().toLowerCase() == query) return 1000;
    final searchKey = (p['searchKey'] ?? '').toString();
    if (searchKey.contains(query)) score += 50;

    final name = (p['name'] ?? '').toString().toLowerCase();
    if (name == query) score += 100; else if (name.startsWith(query)) score += 80;

    final sku = (p['sku'] ?? '').toString().toLowerCase();
    if (sku == query) score += 90; else if (sku.startsWith(query)) score += 70;

    final itemCode = (p['itemCode'] ?? '').toString().toLowerCase();
    if (itemCode == query) score += 90; else if (itemCode.startsWith(query)) score += 70;

    return score;
  }

  Future<Iterable<Map<String, dynamic>>> _getOptions(TextEditingValue textEditingValue) async {
    final queryText = textEditingValue.text.trim().toLowerCase();
    if (queryText.isEmpty) {
      List<Map<String, dynamic>> results = [];
      if (RecentProducts.items.isNotEmpty) { results.add({'isHeader': true, 'title': 'Recently Selected'}); results.addAll(RecentProducts.items); }
      final topSelling = ProductCacheService().products.take(10).toList();
      if (topSelling.isNotEmpty) { results.add({'isHeader': true, 'title': 'Top Products'}); results.addAll(topSelling); }
      return results.isEmpty ? [{'isEmpty': true}] : results;
    }
    var localMatches = ProductCacheService().products.where((p) => _scoreMatch(p, queryText) > 0).toList();
    localMatches.sort((a, b) => _scoreMatch(b, queryText).compareTo(_scoreMatch(a, queryText)));
    return localMatches.isEmpty ? [{'isEmpty': true}] : localMatches.take(100);
  }

  @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    return RawAutocomplete<Map<String, dynamic>>(
      focusNode: _focusNode, textEditingController: widget.controller,
      displayStringForOption: (opt) => opt.containsKey('isHeader') ? '' : opt['name']?.toString() ?? '',
      optionsBuilder: _getOptions, onSelected: (res) { if (!res.containsKey('isHeader')) widget.onSelected(res); },
      fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
        controller: ctrl, focusNode: focus, textInputAction: TextInputAction.next, style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(hintText: widget.label, suffixIcon: const Icon(Icons.search, size: 16), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
        onFieldSubmitted: (v) => onSub(),
      ),
      optionsViewBuilder: (ctx, onSel, options) {
        final colorScheme = Theme.of(context).colorScheme;
        if (options.first.containsKey('isEmpty')) return Align(alignment: Alignment.topLeft, child: Material(elevation: 8, borderRadius: BorderRadius.circular(8), color: colorScheme.surface, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: constraints.maxWidth), child: const Padding(padding: EdgeInsets.all(16.0), child: Text('No products found.', style: TextStyle(color: Colors.grey, fontSize: 13))))));
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8, borderRadius: BorderRadius.circular(8), color: colorScheme.surface, clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450, maxHeight: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                itemBuilder: (ctx, index) {
                  final option = options.elementAt(index);
                  if (option.containsKey('isHeader')) return Container(color: Colors.grey.shade50, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(option['title'], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 11, letterSpacing: 0.5)));

                  final name = option['name']?.toString() ?? 'Unknown';
                  final sku = option['sku']?.toString() ?? option['itemCode']?.toString() ?? '';
                  final price = (option['unitPrice'] as num?)?.toDouble() ?? 0.0;
                  final stock = (option['stockOnHand'] as num?)?.toDouble() ?? 0.0;
                  final minStock = (option['minStockLevel'] as num?)?.toDouble() ?? 0.0;
                  final reorder = (option['reorderLevel'] as num?)?.toDouble() ?? 0.0;
                  final gst = (option['gstPercentage'] as num?)?.toDouble() ?? 0.0;
                  final make = option['make']?.toString() ?? '';
                  final cat = option['category']?.toString() ?? '';
                  final track = option['trackInventory'] == true;

                  Color stockColor = Colors.green; String stockStatus = 'In Stock';
                  if (track) {
                    final threshold = minStock > 0 ? minStock : reorder;
                    if (stock <= 0) { stockColor = Colors.red; stockStatus = 'Out of Stock'; }
                    else if (threshold > 0 && stock <= threshold) { stockColor = Colors.orange; stockStatus = 'Low Stock'; }
                  } else { stockColor = Colors.grey; stockStatus = 'Not Tracked'; }

                  return InkWell(
                    onTap: () => onSel(option), hoverColor: colorScheme.primaryContainer.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              if (sku.isNotEmpty) Text('SKU: $sku', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              if (cat.isNotEmpty) Text('Cat: $cat', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              if (make.isNotEmpty) Text('Make: $make', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              Text('GST: $gst%', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                            ])
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: stockColor)), const SizedBox(width: 4), Text(track ? '$stock avail' : 'Non-Stock', style: TextStyle(fontSize: 11, color: stockColor, fontWeight: FontWeight.bold))])
                          ])
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  });
}

class ProductCacheService {
  static final ProductCacheService _instance = ProductCacheService._internal();
  factory ProductCacheService() => _instance;
  ProductCacheService._internal();

  List<Map<String, dynamic>> _products = [];
  bool _isLoaded = false;
  String? _loadedCompanyId;

  Future<void> loadProducts(String companyId) async {
    if (_isLoaded && _loadedCompanyId == companyId) return;
    _loadedCompanyId = companyId;

    try {
      debugPrint('--- PRODUCT CACHE LOADING ---');
      List<Map<String, dynamic>> loaded = [];
      DocumentSnapshot? lastDoc; bool fetchMore = true;

      while (fetchMore) {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('products')
            .where('isActive', isEqualTo: true).where('isSaleable', isEqualTo: true).limit(2000);

        if (lastDoc != null) query = query.startAfterDocument(lastDoc!);
        final snap = await query.get();
        if (snap.docs.isEmpty) break;
        lastDoc = snap.docs.last;
        if (snap.docs.length < 2000) fetchMore = false;

        for (var doc in snap.docs) {
          final data = doc.data();

          // Strict exact field names from screens_add_product.dart
          String desc = (data['description'] ?? '').toString();
          String scope = '';
          if (data['includedProducts'] is List) {
            final List incl = data['includedProducts'] as List;
            scope = incl.map((e) => '${e['qty'] ?? 1} ${e['uom'] ?? ''} ${e['productName'] ?? ''}').join('\n').trim();
          }

          final name = (data['name'] ?? '').toString();
          final sku = (data['sku'] ?? '').toString();
          final itemCode = (data['itemCode'] ?? '').toString();
          final cat = (data['category'] ?? '').toString();
          final subCat = (data['subcategory'] ?? '').toString();
          final make = (data['make'] ?? data['brand'] ?? '').toString(); // Keep brand for legacy
          final mType = (data['machineType'] ?? data['type'] ?? '').toString();
          final hsn = (data['hsnCode'] ?? '').toString();

          // Pre-compiled O(1) Search Key
          String searchKey = '$name $sku $itemCode $cat $subCat $make $mType $desc $scope $hsn'.toLowerCase();

          loaded.add({
            'id': doc.id,
            'name': name,
            'description': desc,
            'scopeOfSupply': scope,
            'includedProducts': data['includedProducts'], // Preserve original for raw access if needed
            'sku': sku,
            'itemCode': itemCode,
            'category': cat,
            'subcategory': subCat,
            'make': make,
            'machineType': mType,
            'barcode': data['barcode'] ?? '',
            'hsnCode': hsn,
            'uom': data['uom'] ?? 'Nos.',
            'unitPrice': (data['unitPrice'] as num?)?.toDouble() ?? (data['sellingPrice'] as num?)?.toDouble() ?? 0.0,
            'gstPercentage': (data['gstPercentage'] as num?)?.toDouble() ?? 0.0,
            'stockOnHand': (data['stockOnHand'] as num?)?.toDouble() ?? 0.0,
            'reorderLevel': (data['reorderLevel'] as num?)?.toDouble() ?? 0.0,
            'minStockLevel': (data['minStockLevel'] as num?)?.toDouble() ?? 0.0,
            'maxStockLevel': (data['maxStockLevel'] as num?)?.toDouble() ?? 0.0,
            'trackInventory': data['trackInventory'] == true || data['trackInventory'] == 'true',
            'productNature': data['productNature'] ?? '',
            'searchKey': searchKey,
          });
        }
      }

      _products = loaded;
      _isLoaded = true;
      debugPrint('--- PRODUCT CACHE LOADED: ${_products.length} PRODUCTS ---');
    } catch (e) {
      debugPrint('Error loading product cache: $e');
    }
  }

  Future<void> refreshProducts(String companyId) async {
    clear();
    await loadProducts(companyId);
  }

  List<Map<String, dynamic>> get products => _products;

  void clear() {
    _products.clear();
    _isLoaded = false;
    _loadedCompanyId = null;
  }
}

class RecentProducts {
  static List<Map<String, dynamic>> items = [];
  static void add(Map<String, dynamic> item) {
    items.removeWhere((i) => i['id'] == item['id']);
    items.insert(0, item);
    if (items.length > 5) items.removeLast();
  }
}