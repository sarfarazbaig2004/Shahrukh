// FILE PATH: lib/modules/service/screens/add_service_request_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String _generateMachineUid() {
  final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = math.Random();
  final rStr = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  return 'M-${DateTime.now().millisecondsSinceEpoch}-$rStr';
}

class ServiceItemModel {
  String machineUid;
  String itemNature;
  String? categoryId;
  String? categoryName;
  String? subcategoryId;
  String? subcategoryName;
  String? machineTypeId;
  String? machineTypeName;
  String? itemId;
  String? itemCode;
  String? itemName;
  TextEditingController brandCtrl;
  TextEditingController serialNumberCtrl;
  List<String> availableSerialNumbers;

  String complaintCategory;
  TextEditingController complaintDescCtrl;
  String priority;
  bool isWarranty;

  List<Map<String, dynamic>> requiredParts;

  ServiceItemModel({
    String? machineUid,
    this.itemNature = 'Machine',
    this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.machineTypeId,
    this.machineTypeName,
    this.itemId,
    this.itemCode,
    this.itemName,
    TextEditingController? brandCtrl,
    TextEditingController? serialNumberCtrl,
    List<String>? availableSerialNumbers,
    this.complaintCategory = 'Machine Breakdown',
    TextEditingController? complaintDescCtrl,
    this.priority = 'Medium',
    this.isWarranty = false,
    List<Map<String, dynamic>>? requiredParts,
  })  : machineUid = machineUid ?? _generateMachineUid(),
        brandCtrl = brandCtrl ?? TextEditingController(),
        serialNumberCtrl = serialNumberCtrl ?? TextEditingController(),
        availableSerialNumbers = availableSerialNumbers ?? [],
        complaintDescCtrl = complaintDescCtrl ?? TextEditingController(),
        requiredParts = requiredParts ?? [];

  void dispose() {
    brandCtrl.dispose();
    serialNumberCtrl.dispose();
    complaintDescCtrl.dispose();
  }
}

class AddServiceRequestScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;

  const AddServiceRequestScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    this.existingDocId,
    this.existingData,
  });

  @override
  State<AddServiceRequestScreen> createState() => _AddServiceRequestScreenState();
}

class _AddServiceRequestScreenState extends State<AddServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // --- CUSTOMER & CONTACT STATE ---
  String? _selectedCustomerId;
  String? _selectedCustomerCode;
  String? _selectedContactId;
  String? _selectedAddressId;
  String? _salesPersonId;
  String? _salesPersonName;

  List<Map<String, dynamic>> _customerAddresses = [];
  List<Map<String, dynamic>> _customerContacts = [];
  List<Map<String, dynamic>> _suggestedCustomers = [];
  Map<String, dynamic>? _selectedCustomerData;

  Timer? _debounceTimer;

  // --- SERVICE ASSIGNMENT STATE ---
  String? _assignedToUid;
  String? _assignedToName;
  String? _assignedToEmail;

  // --- MULTI-MACHINE STATE ---
  List<ServiceItemModel> _serviceItems = [];

  // --- GLOBAL REQUEST STATE CONTROLLERS ---
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerCodeCtrl = TextEditingController();
  final TextEditingController _contactPersonCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _gstCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _stateCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  final TextEditingController _salesPersonCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  String _selectedSource = 'Customer Call';
  String _status = 'New';

  final List<String> _categories = [
    'Machine Breakdown', 'Installation Support', 'Technical Support',
    'Warranty Claim', 'Spare Parts Requirement', 'AMC Support',
    'Preventive Maintenance', 'Training Request', 'Other'
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];

  final List<String> _sources = [
    'Customer Call', 'Customer Email', 'Sales Team', 'Service Team',
    'WhatsApp', 'Website', 'AMC', 'Other'
  ];

  // --- FIRESTORE GETTERS ---
  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('inventory_categories');

  CollectionReference<Map<String, dynamic>> _subcategoriesRef(String catId) =>
      _categoriesRef.doc(catId).collection('subcategories');

  CollectionReference<Map<String, dynamic>> get _machineTypesRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('inventory_machine_types');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('products');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users');

  // SAFE ID NORMALIZER
  String? _normalizeId(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    return str.isEmpty ? null : str;
  }

  @override
  void initState() {
    super.initState();
    _customerNameCtrl.addListener(_onCustomerFieldChanged);
    _mobileCtrl.addListener(_onContactFieldTyped);
    _emailCtrl.addListener(_onContactFieldTyped);

    if (widget.existingData != null) {
      final d = widget.existingData!;

      _selectedCustomerId = _normalizeId(d['customerId']);
      _selectedCustomerCode = d['customerCode'];
      _selectedContactId = _normalizeId(d['contactId']);
      _selectedAddressId = _normalizeId(d['selectedAddressId']);
      _salesPersonId = _normalizeId(d['salesPersonId']);
      _salesPersonName = d['salesPersonName'];

      _customerNameCtrl.text = d['customerName'] ?? '';
      _customerCodeCtrl.text = d['customerCode'] ?? '';
      _contactPersonCtrl.text = d['contactPerson'] ?? '';
      _mobileCtrl.text = d['mobileNumber'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _gstCtrl.text = d['gst'] ?? '';
      _addressCtrl.text = d['address'] ?? '';
      _cityCtrl.text = d['city'] ?? '';
      _stateCtrl.text = d['state'] ?? '';
      _pincodeCtrl.text = d['pincode'] ?? '';
      _salesPersonCtrl.text = d['salesPersonName'] ?? '';

      _assignedToUid = _normalizeId(d['assignedToUid']);
      _assignedToName = _normalizeId(d['assignedToName']);
      _assignedToEmail = _normalizeId(d['assignedToEmail']);

      _selectedSource = d['source'] ?? _sources.first;
      _remarksCtrl.text = d['remarks'] ?? '';
      _status = d['status'] ?? 'New';

      // --- DYNAMIC MULTI-MACHINE INITIALIZATION ---
      if (d['serviceItems'] is List && (d['serviceItems'] as List).isNotEmpty) {
        _serviceItems = (d['serviceItems'] as List).map((item) {
          final i = Map<String, dynamic>.from(item);
          return ServiceItemModel(
            machineUid: i['machineUid'] ?? _generateMachineUid(), // Fallback for auto-generating missing machineUid
            itemNature: i['itemNature'] ?? i['machineNature'] ?? 'Machine',
            categoryId: _normalizeId(i['categoryId']),
            categoryName: i['categoryName'],
            subcategoryId: _normalizeId(i['subcategoryId']),
            subcategoryName: i['subcategoryName'],
            machineTypeId: _normalizeId(i['machineTypeId']), // Improved Machine Type Mapping
            machineTypeName: i['machineTypeName'] ?? i['machineType'], // Fallback for old machineType names
            itemId: _normalizeId(i['itemId']),
            itemCode: i['itemCode'],
            itemName: i['itemName'],
            brandCtrl: TextEditingController(text: i['brand'] ?? ''),
            serialNumberCtrl: TextEditingController(text: i['serialNumber'] ?? ''),
            complaintCategory: i['complaintCategory'] ?? _categories.first,
            complaintDescCtrl: TextEditingController(text: i['complaintDescription'] ?? ''),
            priority: i['priority'] ?? _priorities[1],
            isWarranty: i['isWarranty'] ?? false,
            requiredParts: i['requiredParts'] != null ? List<Map<String, dynamic>>.from((i['requiredParts'] as List).map((x) => Map<String, dynamic>.from(x))) : [],
          );
        }).toList();
      } else {
        // --- BACKWARD COMPATIBILITY: Mapping legacy Single Machine structure ---
        _serviceItems.add(ServiceItemModel(
          machineUid: _generateMachineUid(),
          itemNature: d['serviceItemNature'] ?? d['machineNature'] ?? 'Machine',
          categoryId: _normalizeId(d['serviceCategoryId'] ?? d['machineCategoryId']),
          categoryName: d['serviceCategoryName'] ?? d['machineCategory'],
          subcategoryId: _normalizeId(d['serviceSubcategoryId'] ?? d['machineSubcategoryId']),
          subcategoryName: d['serviceSubCategoryName'] ?? d['machineSubCategory'],
          machineTypeId: _normalizeId(d['serviceMachineTypeId'] ?? d['machineTypeId']), // Extract Legacy ID if available
          machineTypeName: d['serviceMachineTypeName'] ?? d['serviceMachineType'] ?? d['machineTypeName'] ?? d['machineType'],
          itemId: _normalizeId(d['serviceItemId'] ?? d['machineId']),
          itemCode: d['serviceItemCode'] ?? d['machineCode'],
          itemName: d['serviceItemName'] ?? d['machineModel'],
          brandCtrl: TextEditingController(text: d['brand'] ?? d['machineBrand'] ?? ''),
          serialNumberCtrl: TextEditingController(text: d['serialNumber'] ?? d['machineSerialNumber'] ?? ''),
          complaintCategory: d['complaintCategory'] ?? _categories.first,
          complaintDescCtrl: TextEditingController(text: d['complaintDescription'] ?? ''),
          priority: d['priority'] ?? _priorities[1],
          isWarranty: d['isWarranty'] ?? false,
          requiredParts: d['requiredParts'] != null ? List<Map<String, dynamic>>.from((d['requiredParts'] as List).map((x) => Map<String, dynamic>.from(x))) : [],
        ));
      }

      if (_selectedCustomerId != null) {
        _fetchCustomerRelatedData(_selectedCustomerId!);
      }
    } else {
      // New record, start with 1 empty machine
      _serviceItems.add(ServiceItemModel());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _customerNameCtrl.removeListener(_onCustomerFieldChanged);
    _mobileCtrl.removeListener(_onContactFieldTyped);
    _emailCtrl.removeListener(_onContactFieldTyped);

    _customerNameCtrl.dispose();
    _customerCodeCtrl.dispose();
    _contactPersonCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _salesPersonCtrl.dispose();
    _remarksCtrl.dispose();

    for (var item in _serviceItems) {
      item.dispose();
    }
    super.dispose();
  }

  // ==========================================
  // UNIFIED CUSTOMER LOOKUP ENGINE
  // ==========================================

  void _onCustomerFieldChanged() {
    if (_customerNameCtrl.text.isEmpty && _selectedCustomerId != null) {
      _clearCustomerSelection();
      return;
    }
    if (_selectedCustomerId != null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _unifiedCustomerLookup();
    });
  }

  void _onContactFieldTyped() {
    if (_selectedCustomerId != null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _unifiedCustomerLookup();
    });
  }

  Future<bool> _performDeepEmailLookup(String email) async {
    final db = FirebaseFirestore.instance;

    try {
      var custSnap = await db.collection('companies').doc(widget.companyId)
          .collection('customers')
          .where('businessEmail', isEqualTo: email)
          .limit(3).get();

      if (custSnap.docs.isEmpty) {
        custSnap = await db.collection('companies').doc(widget.companyId)
            .collection('customers')
            .where('email', isEqualTo: email)
            .limit(3).get();
      }

      final activeCusts = custSnap.docs.where((d) => d.data()['isDeleted'] != true).toList();

      if (activeCusts.isNotEmpty) {
        final custDoc = activeCusts.first;
        _applyCustomer({'id': custDoc.id, ...custDoc.data()});
        return true;
      }

      final contactsSnap = await db.collectionGroup('contacts')
          .where('email', isEqualTo: email)
          .get();

      for (var doc in contactsSnap.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) continue;

        final pathSegments = doc.reference.path.split('/');
        if (pathSegments.length >= 5 && pathSegments[1] == widget.companyId) {
          final matchedCustomerId = pathSegments[3];
          final parentCustDoc = await db.collection('companies')
              .doc(widget.companyId)
              .collection('customers')
              .doc(matchedCustomerId)
              .get();

          if (parentCustDoc.exists) {
            final custData = parentCustDoc.data()!;
            if (custData['isDeleted'] != true) {
              _applyCustomer({'id': matchedCustomerId, ...custData}, preselectContactId: doc.id);
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Deep email lookup error: $e");
    }
    return false;
  }

  Future<void> _unifiedCustomerLookup() async {
    final name = _customerNameCtrl.text.trim().toLowerCase();
    final mobile = _mobileCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    final email = _emailCtrl.text.trim().toLowerCase();

    if (email.length >= 5 && email.contains('@') && _selectedCustomerId == null) {
      bool foundViaEmail = await _performDeepEmailLookup(email);
      if (foundViaEmail) return;
    }

    String queryStr = '';

    if (mobile.length >= 8) {
      queryStr = mobile;
    } else if (email.length >= 5) {
      queryStr = email;
    } else if (name.length >= 2) {
      queryStr = name;
    } else {
      if (_suggestedCustomers.isNotEmpty && mounted) {
        setState(() => _suggestedCustomers.clear());
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers')
          .where('searchKeywords', arrayContains: queryStr)
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          final validDocs = snap.docs.where((d) => d.data()['isDeleted'] != true).toList();
          _suggestedCustomers = validDocs.map((d) => {'id': d.id, ...d.data()}).toList();

          if (_suggestedCustomers.length == 1 && (mobile.length >= 10 || email.length >= 5) && _selectedCustomerId == null) {
            _applyCustomer(_suggestedCustomers.first);
          }
        });
      }
    } catch (e) {
      debugPrint('Search failed: $e');
    }
  }

  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerCode = null;
      _selectedContactId = null;
      _selectedAddressId = null;
      _salesPersonId = null;
      _salesPersonName = null;
      _selectedCustomerData = null;

      _customerCodeCtrl.clear();
      _contactPersonCtrl.clear();
      _mobileCtrl.clear();
      _emailCtrl.clear();
      _gstCtrl.clear();
      _addressCtrl.clear();
      _cityCtrl.clear();
      _stateCtrl.clear();
      _pincodeCtrl.clear();
      _salesPersonCtrl.clear();

      _customerAddresses.clear();
      _customerContacts.clear();
      _suggestedCustomers.clear();
    });
  }

  void _applyCustomer(Map<String, dynamic> customer, {String? preselectContactId}) async {
    setState(() {
      _suggestedCustomers.clear();
      _selectedCustomerData = customer;
      _selectedCustomerId = customer['id'];
      _selectedCustomerCode = customer['customerCode'];

      _customerNameCtrl.text = (customer['companyName'] ?? customer['name'] ?? '').toString();
      _customerCodeCtrl.text = _selectedCustomerCode ?? '';
      _salesPersonId = customer['assignedToUid'];
      _salesPersonName = customer['assignedToName'];
      _salesPersonCtrl.text = _salesPersonName ?? '';
      _gstCtrl.text = (customer['gst'] ?? '').toString();

      if (_mobileCtrl.text.isEmpty) _mobileCtrl.text = (customer['phone'] ?? customer['alternatePhone'] ?? '').toString();
      if (_emailCtrl.text.isEmpty) _emailCtrl.text = (customer['businessEmail'] ?? customer['email'] ?? '').toString();

      final topLevelContact = (customer['contactName'] ?? '').toString();
      if (topLevelContact.isNotEmpty && _contactPersonCtrl.text.isEmpty) {
        _contactPersonCtrl.text = topLevelContact;
      }

      final addresses = customer['addresses'] as List<dynamic>? ?? [];
      if (addresses.isNotEmpty) {
        _customerAddresses = addresses.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final primary = _customerAddresses.firstWhere((a) => a['isPrimary'] == true, orElse: () => _customerAddresses.first);
        _applyAddress(primary['id'] ?? primary['erpAddressCode']);
      } else {
        _customerAddresses.clear();
        _selectedAddressId = null;
        _addressCtrl.text = (customer['street'] ?? customer['address'] ?? '').toString();
        _cityCtrl.text = (customer['city'] ?? '').toString();
        _stateCtrl.text = (customer['state'] ?? '').toString();
        _pincodeCtrl.text = (customer['pincode'] ?? '').toString();
      }
    });

    await _fetchCustomerRelatedData(_selectedCustomerId!, preselectContactId: preselectContactId);
  }

  Future<void> _fetchCustomerRelatedData(String customerId, {String? preselectContactId}) async {
    try {
      final db = FirebaseFirestore.instance;
      final String contactsPath = 'companies/${widget.companyId}/customers/$customerId/contacts';

      final contactsSnap = await db.collection(contactsPath).get();
      final activeContacts = contactsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((c) => c['isDeleted'] != true)
          .toList();

      if (mounted) {
        setState(() {
          _customerContacts = activeContacts;

          bool needsSelection = _selectedContactId == null ||
              _selectedContactId!.trim().isEmpty ||
              !_customerContacts.any((c) => c['id'] == _selectedContactId);

          if (_customerContacts.isNotEmpty && (needsSelection || preselectContactId != null)) {
            if (preselectContactId != null && _customerContacts.any((c) => c['id'] == preselectContactId)) {
              _applyContact(preselectContactId);
            } else {
              final primary = _customerContacts.firstWhere(
                      (c) => c['isPrimary'] == true || c['isPrimary'] == 'true',
                  orElse: () => _customerContacts.first
              );
              _applyContact(primary['id']);
            }
          } else if (_customerContacts.isEmpty) {
            _selectedContactId = null;
            if (_selectedCustomerData != null) {
              _contactPersonCtrl.text = (_selectedCustomerData!['contactName'] ?? '').toString();
              _mobileCtrl.text = (_selectedCustomerData!['phone'] ?? _selectedCustomerData!['alternatePhone'] ?? '').toString();
              _emailCtrl.text = (_selectedCustomerData!['businessEmail'] ?? _selectedCustomerData!['email'] ?? '').toString();
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
    }
  }

  void _applyAddress(String? addressId) {
    if (addressId == null || addressId.trim().isEmpty) return;
    final addr = _customerAddresses.firstWhere((a) => (a['id'] ?? a['erpAddressCode']) == addressId, orElse: () => <String, dynamic>{});
    if (addr.isEmpty) return;

    setState(() {
      _selectedAddressId = addressId;
      _addressCtrl.text = (addr['street'] ?? addr['address'] ?? '').toString();
      _cityCtrl.text = (addr['city'] ?? '').toString();
      _stateCtrl.text = (addr['state'] ?? '').toString();
      _pincodeCtrl.text = (addr['pincode'] ?? addr['zipCode'] ?? '').toString();

      if ((addr['gst'] ?? '').toString().isNotEmpty) {
        _gstCtrl.text = addr['gst'].toString().toUpperCase();
      }
    });
  }

  void _applyContact(String? contactId) {
    if (contactId == null || contactId.trim().isEmpty) return;
    final contact = _customerContacts.firstWhere((c) => c['id'] == contactId, orElse: () => <String, dynamic>{});
    if (contact.isEmpty) return;

    setState(() {
      _selectedContactId = contactId;
      _contactPersonCtrl.text = (contact['name'] ?? contact['contactName'] ?? '').toString();
      _mobileCtrl.text = (contact['phone'] ?? contact['mobile'] ?? '').toString();
      _emailCtrl.text = (contact['email'] ?? '').toString();
    });
  }

  // ==========================================
  // INVENTORY HIERARCHY ENGINE
  // ==========================================

  void _addServiceItem() {
    setState(() {
      _serviceItems.add(ServiceItemModel());
    });
  }

  void _removeServiceItem(int index) {
    if (_serviceItems.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('At least one machine/product is required.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() {
      _serviceItems[index].dispose();
      _serviceItems.removeAt(index);
    });
  }

  void _resetHierarchy(int index, {bool resetCat = false, bool resetSub = false, bool resetType = false}) {
    setState(() {
      final item = _serviceItems[index];
      if (resetCat) {
        item.categoryId = null;
        item.categoryName = null;
      }
      if (resetSub) {
        item.subcategoryId = null;
        item.subcategoryName = null;
      }
      if (resetType) {
        item.machineTypeId = null;
        item.machineTypeName = null;
      }
      item.itemId = null;
      item.itemName = null;
      item.itemCode = null;
      item.brandCtrl.clear();
      item.serialNumberCtrl.clear();
      item.availableSerialNumbers.clear();
      item.isWarranty = false;
    });
  }

  void _applyServiceItemProduct(int index, Map<String, dynamic> product) {
    setState(() {
      final item = _serviceItems[index];
      item.itemId = product['id'];
      item.itemName = (product['name'] ?? '').toString();
      item.itemCode = (product['itemCode'] ?? product['sku'] ?? '').toString();
      item.brandCtrl.text = (product['make'] ?? product['brand'] ?? '').toString();

      if (product['serialNumbers'] is List) {
        item.availableSerialNumbers = List<String>.from(product['serialNumbers']).where((s) => s.isNotEmpty).toList();
      } else {
        item.availableSerialNumbers.clear();
      }

      if (product['warrantyMonths'] != null) {
        item.isWarranty = true;
      }
    });
  }

  // ==========================================
  // SPARES & ACCESSORIES ENGINE
  // ==========================================

  Future<void> _showAddPartModal(int machineIndex) async {
    String? selectedPartId;
    String? selectedPartName;
    String? selectedPartCode;
    String? selectedPartNature;
    final qtyCtrl = TextEditingController(text: '1');
    String searchQuery = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Add Required Part'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Search Spare or Accessory',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val.toLowerCase()),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 250,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _productsRef
                            .where('isActive', isEqualTo: true)
                            .where('productNatureLower', whereIn: ['spare', 'accessory'])
                            .limit(50)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) return const Center(child: Text('Error loading catalog'));

                          var docs = snap.data?.docs ?? [];

                          if (searchQuery.isNotEmpty) {
                            docs = docs.where((d) {
                              final name = (d.data()['name'] ?? '').toString().toLowerCase();
                              final sku = (d.data()['sku'] ?? d.data()['itemCode'] ?? '').toString().toLowerCase();
                              return name.contains(searchQuery) || sku.contains(searchQuery);
                            }).toList();
                          }

                          if (docs.isEmpty) {
                            return const Center(child: Text('No matching parts found', style: TextStyle(color: Colors.grey)));
                          }

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final name = (data['name'] ?? '').toString();
                              final sku = (data['sku'] ?? data['itemCode'] ?? '').toString();
                              final nature = (data['productNature'] ?? 'Spare').toString();
                              final isSelected = selectedPartId == doc.id;

                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.blue.shade50,
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${nature.toUpperCase()} • Code: $sku'),
                                onTap: () {
                                  setDialogState(() {
                                    selectedPartId = doc.id;
                                    selectedPartName = name;
                                    selectedPartCode = sku;
                                    selectedPartNature = nature;
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: qtyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Quantity Required',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (selectedPartId == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a part')));
                      return;
                    }
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Quantity must be > 0')));
                      return;
                    }
                    Navigator.pop(ctx, {
                      'partId': selectedPartId,
                      'partName': selectedPartName,
                      'partCode': selectedPartCode,
                      'partNature': selectedPartNature,
                      'quantity': qty,
                    });
                  },
                  child: const Text('Add Part'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        // Prevent Duplicate Rows - Merge Quantities instead
        final existingIndex = _serviceItems[machineIndex].requiredParts.indexWhere((p) => p['partId'] == result['partId']);
        if (existingIndex >= 0) {
          _serviceItems[machineIndex].requiredParts[existingIndex]['quantity'] += result['quantity'];
        } else {
          _serviceItems[machineIndex].requiredParts.add(result);
        }
      });
    }
  }


  // ==========================================
  // SAVE LOGIC
  // ==========================================

  String _getFinancialYear() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return '${startYear.toString().substring(2)}-${endYear.toString().substring(2)}';
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // Strong Pre-Save Validation per Machine
    for (int i = 0; i < _serviceItems.length; i++) {
      final m = _serviceItems[i];
      if (m.categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Machine/Product #${i + 1} : Category is required'), backgroundColor: Colors.red));
        return;
      }
      if (m.itemId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Machine/Product #${i + 1} : Target Product Model is required'), backgroundColor: Colors.red));
        return;
      }
      if (m.complaintDescCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Machine/Product #${i + 1} : Complaint description required'), backgroundColor: Colors.red));
        return;
      }
    }

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      if (widget.existingDocId == null) {
        final fy = _getFinancialYear();
        final counterRef = db.collection('companies').doc(widget.companyId).collection('counters').doc('service_request_$fy');
        final newDocRef = db.collection('companies').doc(widget.companyId).collection('service_requests').doc();

        await db.runTransaction((transaction) async {
          final counterSnap = await transaction.get(counterRef);
          int nextSeq = 1;

          if (counterSnap.exists) {
            nextSeq = (counterSnap.data()?['sequence'] ?? 0) + 1;
          }

          transaction.set(counterRef, {'sequence': nextSeq}, SetOptions(merge: true));

          final reqNo = 'SR/${nextSeq.toString().padLeft(3, '0')}/$fy';
          final data = _buildPayload(reqNo, newDocRef.id);
          data['createdAt'] = FieldValue.serverTimestamp();
          data['createdBy'] = widget.currentUserUid;
          data['createdByName'] = widget.currentUserName;

          transaction.set(newDocRef, data);
        });
      } else {
        final docRef = db.collection('companies').doc(widget.companyId).collection('service_requests').doc(widget.existingDocId);
        final reqNo = widget.existingData!['requestNumber'] ?? '';
        final data = _buildPayload(reqNo, widget.existingDocId!);

        await docRef.update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Request saved successfully.'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildPayload(String reqNo, String docId) {
    // Generate isolated items array payload
    List<Map<String, dynamic>> serviceItemsPayload = _serviceItems.map((item) {
      return {
        'machineUid': item.machineUid,
        'itemNature': item.itemNature,
        'categoryId': item.categoryId,
        'categoryName': item.categoryName,
        'subcategoryId': item.subcategoryId,
        'subcategoryName': item.subcategoryName,
        'machineTypeId': item.machineTypeId,
        'machineTypeName': item.machineTypeName,
        'itemId': item.itemId,
        'itemCode': item.itemCode,
        'itemName': item.itemName,
        'brand': item.brandCtrl.text.trim(),
        'serialNumber': item.serialNumberCtrl.text.trim(),
        'complaintCategory': item.complaintCategory,
        'complaintDescription': item.complaintDescCtrl.text.trim(),
        'priority': item.priority,
        'isWarranty': item.isWarranty,
        'requiredParts': item.requiredParts,
      };
    }).toList();

    // Safely Merge all Required Parts for Legacy Systems (Grouped by PartId)
    Map<String, Map<String, dynamic>> mergedLegacyParts = {};
    for(var item in serviceItemsPayload) {
      if (item['requiredParts'] != null) {
        for(var part in item['requiredParts']) {
          final pId = part['partId'].toString();
          if (mergedLegacyParts.containsKey(pId)) {
            mergedLegacyParts[pId]!['quantity'] += (part['quantity'] ?? 0);
          } else {
            mergedLegacyParts[pId] = Map<String, dynamic>.from(part);
          }
        }
      }
    }
    List<Map<String, dynamic>> allLegacyParts = mergedLegacyParts.values.toList();

    final first = _serviceItems.first;

    return {
      'id': docId,
      'companyId': widget.companyId,
      'requestNumber': reqNo,

      // CRM Info
      'customerId': _selectedCustomerId ?? '',
      'customerCode': _selectedCustomerCode ?? '',
      'customerName': _customerNameCtrl.text.trim(),
      'contactId': _selectedContactId ?? '',
      'contactPerson': _contactPersonCtrl.text.trim(),
      'selectedAddressId': _selectedAddressId ?? '',
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'mobileNumber': _mobileCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'gst': _gstCtrl.text.trim(),
      'salesPersonId': _salesPersonId ?? '',
      'salesPersonName': _salesPersonName ?? '',

      // Assignment
      'assignedToUid': _assignedToUid,
      'assignedToName': _assignedToName,
      'assignedToEmail': _assignedToEmail,
      'assignedByUid': widget.currentUserUid,
      'assignedByName': widget.currentUserName,
      'assignedAt': _assignedToUid != null
          ? (widget.existingData != null && widget.existingData!['assignedToUid'] == _assignedToUid
          ? widget.existingData!['assignedAt']
          : FieldValue.serverTimestamp())
          : null,

      // --- MULTI-MACHINE ARRAY ---
      'serviceItems': serviceItemsPayload,

      // --- BACKWARD COMPATIBILITY: Legacy First Machine Mappings ---
      'serviceItemNature': first.itemNature,
      'serviceCategoryId': first.categoryId,
      'serviceCategoryName': first.categoryName,
      'serviceSubcategoryId': first.subcategoryId,
      'serviceSubCategoryName': first.subcategoryName,
      'serviceMachineTypeId': first.machineTypeId,
      'serviceMachineTypeName': first.machineTypeName,
      'serviceMachineType': first.itemNature == 'Machine' ? first.machineTypeName : null, // Safely mapped for older queries
      'serviceItemId': first.itemId,
      'serviceItemCode': first.itemCode,
      'serviceItemName': first.itemName,
      'brand': first.brandCtrl.text.trim(),
      'serialNumber': first.serialNumberCtrl.text.trim(),
      'complaintCategory': first.complaintCategory,
      'complaintDescription': first.complaintDescCtrl.text.trim(),
      'priority': first.priority,
      'isWarranty': first.isWarranty,

      // Deep Legacy Mappings
      'machineCategoryId': first.categoryId,
      'machineCategory': first.categoryName,
      'machineSubcategoryId': first.subcategoryId,
      'machineSubCategory': first.subcategoryName,
      'machineTypeId': first.machineTypeId,
      'machineType': first.machineTypeName, // Keep name here for older records
      'machineId': first.itemId,
      'machineCode': first.itemCode,
      'machineModel': first.itemName,
      'machineNature': first.itemNature,
      'machineBrand': first.brandCtrl.text.trim(),
      'machineSerialNumber': first.serialNumberCtrl.text.trim(),

      'requiredParts': allLegacyParts,

      // Global Parameters
      'source': _selectedSource,
      'status': _status,
      'remarks': _remarksCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': widget.currentUserUid,
      'isDeleted': false,
      'searchKeywords': _generateSearchKeywords(reqNo),
    };
  }

  // Generate powerful prefix keywords for search optimization
  List<String> _generateSearchKeywords(String requestNo) {
    Set<String> keywords = {};

    void addPrefixes(String text) {
      if (text.isEmpty) return;
      final words = text.toLowerCase().split(RegExp(r'\s+'));
      for (var word in words) {
        word = word.replaceAll(RegExp(r'[^a-z0-9]'), '');
        for (int i = 2; i <= word.length; i++) {
          keywords.add(word.substring(0, i));
        }
        if (word.isNotEmpty) keywords.add(word);
      }
    }

    addPrefixes(requestNo);
    addPrefixes(_customerNameCtrl.text);
    addPrefixes(_contactPersonCtrl.text);
    addPrefixes(_mobileCtrl.text);
    addPrefixes(_selectedCustomerCode ?? '');
    addPrefixes(_gstCtrl.text);

    for(var item in _serviceItems) {
      addPrefixes(item.itemName ?? '');
      addPrefixes(item.serialNumberCtrl.text);
      // Generate keywords from complaint description to enable free-text searching
      addPrefixes(item.complaintDescCtrl.text);
    }

    return keywords.toList();
  }

  // ==========================================
  // UI BUILDERS & SAFE DROPDOWN FACTORY
  // ==========================================

  Widget _buildSafeStreamDropdown({
    required String label,
    required IconData icon,
    required String? currentValue,
    required String? legacyName,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String valueField,
    required String displayField,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    Set<String> validValues = {};
    List<DropdownMenuItem<String>> items = [];

    for (var doc in docs) {
      final val = valueField == 'id' ? doc.id : doc.data()[valueField]?.toString();
      final display = doc.data()[displayField]?.toString() ?? 'Unknown';

      if (val != null && val.isNotEmpty && !validValues.contains(val)) {
        validValues.add(val);
        items.add(DropdownMenuItem(value: val, child: Text(display)));
      }
    }

    if (currentValue != null && currentValue.isNotEmpty && !validValues.contains(currentValue)) {
      items.add(DropdownMenuItem(
        value: currentValue,
        child: Text('${legacyName ?? 'Unknown'} (Legacy/Deleted)'),
      ));
      validValues.add(currentValue);
    }

    final safeValue = validValues.contains(currentValue) ? currentValue : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: _inputDecoration(label: label, icon: icon),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(widget.existingDocId == null ? 'New Service Request' : 'Edit Service Request', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCustomerInformationSection(),
                        const SizedBox(height: 16),
                        _buildAssignmentSection(),
                        const SizedBox(height: 16),
                        _buildDynamicServiceItemsSection(),
                        const SizedBox(height: 16),
                        _SectionBlock(
                          title: 'Request Information',
                          subtitle: 'Source and internal remarks',
                          child: Column(
                            children: [
                              _buildDropdown(
                                label: 'Source *',
                                icon: Icons.campaign_outlined,
                                value: _selectedSource,
                                items: _sources,
                                onChanged: (v) => setState(() => _selectedSource = v!),
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(label: 'Internal Remarks', controller: _remarksCtrl, icon: Icons.notes_outlined, maxLines: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomSaveBar(),
          ],
        ),
      ),
    );
  }

  // --- COMPONENT: ASSIGNMENT ---
  Widget _buildAssignmentSection() {
    return _SectionBlock(
        title: 'Assignment',
        subtitle: 'Assign this request to a Service Coordinator or Service Manager',
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersRef
                .where('isActive', isEqualTo: true)
                .where('department', isEqualTo: 'Service')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.hasError) {
                return Text('Error loading users: ${snap.error}', style: const TextStyle(color: Colors.red));
              }

              var docs = snap.data?.docs ?? [];

              docs = docs.where((doc) {
                final designation = (doc.data()['designation'] ?? '').toString().toLowerCase().trim();
                return designation == 'service manager' || designation == 'service coordinator';
              }).toList();

              List<DropdownMenuItem<String?>> items = [];
              Set<String> addedIds = {};

              for (var doc in docs) {
                if (addedIds.contains(doc.id)) continue;
                addedIds.add(doc.id);

                final data = doc.data();
                final name = (data['name'] ?? data['fullName'] ?? 'Unknown').toString();
                final designation = (data['designation'] ?? '').toString();
                final label = designation.isNotEmpty ? '$name - $designation' : name;
                items.add(DropdownMenuItem(value: doc.id, child: Text(label)));
              }

              if (_assignedToUid != null && !addedIds.contains(_assignedToUid)) {
                items.add(DropdownMenuItem(
                  value: _assignedToUid,
                  child: Text('${_assignedToName ?? 'Unknown User'} (Legacy/Moved)'),
                ));
                addedIds.add(_assignedToUid!);
              }

              final safeAssignedToUid = addedIds.contains(_assignedToUid) ? _assignedToUid : null;

              return DropdownButtonFormField<String?>(
                value: safeAssignedToUid,
                decoration: _inputDecoration(label: 'Assign To', icon: Icons.person_pin_circle_outlined),
                items: items.isEmpty ? null : items,
                onChanged: (val) {
                  setState(() {
                    _assignedToUid = val;
                    if (val != null && docs.any((d) => d.id == val)) {
                      final selectedDoc = docs.firstWhere((d) => d.id == val);
                      _assignedToName = (selectedDoc.data()['name'] ?? selectedDoc.data()['fullName'] ?? '').toString();
                      _assignedToEmail = (selectedDoc.data()['email'] ?? '').toString();
                    } else if (val == null) {
                      _assignedToName = null;
                      _assignedToEmail = null;
                    }
                  });
                },
              );
            }
        )
    );
  }

  // --- COMPONENT: DYNAMIC SERVICE ITEMS SECTION ---
  Widget _buildDynamicServiceItemsSection() {
    return Column(
      children: [
        ...List.generate(_serviceItems.length, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == _serviceItems.length - 1 ? 0 : 16),
            child: _buildSingleServiceItemCard(index),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _addServiceItem,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Another Machine / Product', style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.blue.shade600, width: 1.5),
              foregroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSingleServiceItemCard(int index) {
    final item = _serviceItems[index];
    bool isMachine = item.itemNature == 'Machine';
    final natureOptions = ['Machine', 'Spare', 'Accessory', 'Consumable'];
    final safeNature = natureOptions.contains(item.itemNature) ? item.itemNature : 'Machine';

    return _SectionBlock(
      title: 'Machine/Product #${index + 1}',
      subtitle: 'Target product and technical details of the issue',
      action: IconButton(
        icon: Icon(Icons.delete_outline, color: _serviceItems.length > 1 ? Colors.red : Colors.grey),
        tooltip: 'Remove Machine',
        onPressed: () => _removeServiceItem(index),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Nature
          DropdownButtonFormField<String>(
            value: safeNature,
            decoration: _inputDecoration(label: 'Product Nature *', icon: Icons.settings_applications_outlined),
            items: natureOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) {
              if (val != null) {
                _resetHierarchy(index, resetCat: true, resetSub: true, resetType: true);
                setState(() => item.itemNature = val);
              }
            },
          ),
          const SizedBox(height: 12),

          // Row 2: Category & Sub Category
          _buildResponsiveRow(
            children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _categoriesRef.orderBy('nameLower').snapshots(),
                builder: (context, snap) {
                  return _buildSafeStreamDropdown(
                    label: 'Category *',
                    icon: Icons.folder_outlined,
                    currentValue: item.categoryId,
                    legacyName: item.categoryName,
                    docs: snap.data?.docs ?? [],
                    valueField: 'id',
                    displayField: 'name',
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (val) {
                      if (val != null) {
                        _resetHierarchy(index, resetSub: true, resetType: true);
                        setState(() {
                          item.categoryId = val;
                          final docs = snap.data?.docs ?? [];
                          if (docs.any((d) => d.id == val)) {
                            item.categoryName = docs.firstWhere((d) => d.id == val).data()['name'];
                          }
                        });
                      }
                    },
                  );
                },
              ),
              if (item.categoryId != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _subcategoriesRef(item.categoryId!).orderBy('nameLower').snapshots(),
                  builder: (context, snap) {
                    return _buildSafeStreamDropdown(
                      label: 'Sub Category',
                      icon: Icons.folder_open_outlined,
                      currentValue: item.subcategoryId,
                      legacyName: item.subcategoryName,
                      docs: snap.data?.docs ?? [],
                      valueField: 'id',
                      displayField: 'name',
                      onChanged: (val) {
                        if (val != null) {
                          _resetHierarchy(index, resetType: true);
                          setState(() {
                            item.subcategoryId = val;
                            final docs = snap.data?.docs ?? [];
                            if (docs.any((d) => d.id == val)) {
                              item.subcategoryName = docs.firstWhere((d) => d.id == val).data()['name'];
                            }
                          });
                        }
                      },
                    );
                  },
                )
              else
                DropdownButtonFormField<String?>(
                  value: null,
                  decoration: _inputDecoration(label: 'Sub Category', icon: Icons.folder_open_outlined),
                  items: const [],
                  onChanged: null,
                )
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Machine Type (conditional) & Product Selection
          _buildResponsiveRow(
            children: [
              if (isMachine)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _machineTypesRef.orderBy('nameLower').snapshots(),
                  builder: (context, snap) {
                    return _buildSafeStreamDropdown(
                      label: 'Machine Type',
                      icon: Icons.precision_manufacturing_outlined,
                      currentValue: item.machineTypeId,
                      legacyName: item.machineTypeName,
                      docs: snap.data?.docs ?? [],
                      valueField: 'id', // Changed to correctly save ID
                      displayField: 'name',
                      onChanged: (val) {
                        if (val != null) {
                          _resetHierarchy(index);
                          setState(() {
                            item.machineTypeId = val;
                            final docs = snap.data?.docs ?? [];
                            if (docs.any((d) => d.id == val)) {
                              item.machineTypeName = docs.firstWhere((d) => d.id == val).data()['name'];
                            }
                          });
                        }
                      },
                    );
                  },
                ),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _productsRef
                    .where('isActive', isEqualTo: true)
                    .where('productNatureLower', isEqualTo: item.itemNature.toLowerCase())
                    .snapshots(),
                builder: (context, snap) {
                  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.data?.docs ?? [];

                  if (item.categoryId != null) {
                    docs = docs.where((d) {
                      final data = d.data();
                      return data['categoryId'] == item.categoryId || (data['category'] != null && data['category'] == item.categoryName);
                    }).toList();
                  }

                  if (item.subcategoryId != null) {
                    docs = docs.where((d) {
                      final data = d.data();
                      return data['subcategoryId'] == item.subcategoryId || (data['subcategory'] != null && data['subcategory'] == item.subcategoryName);
                    }).toList();
                  }

                  if (isMachine && (item.machineTypeId != null || item.machineTypeName != null)) {
                    docs = docs.where((d) {
                      final data = d.data();
                      final pTypeId = data['machineTypeId']?.toString();
                      final pType = data['machineType']?.toString().toLowerCase().trim();
                      final pTypeLower = data['machineTypeLower']?.toString().trim();

                      final iTypeId = item.machineTypeId?.toString();
                      final iTypeName = item.machineTypeName?.toString().toLowerCase().trim();

                      if (pTypeId != null && iTypeId != null && pTypeId == iTypeId) return true;
                      if (pTypeLower != null && iTypeName != null && pTypeLower == iTypeName) return true;
                      if (pType != null && iTypeName != null && pType == iTypeName) return true;

                      return false;
                    }).toList();
                  }

                  // Advanced Customer-Owned Product Filtering Logic
                  // Ensures customer products appear first, but never hides global products completely.
                  if (_selectedCustomerId != null) {
                    List<QueryDocumentSnapshot<Map<String, dynamic>>> customerDocs = [];
                    List<QueryDocumentSnapshot<Map<String, dynamic>>> globalDocs = [];

                    for (var d in docs) {
                      final cId = d.data()['customerId'];
                      if (cId != null && cId.toString() == _selectedCustomerId) {
                        customerDocs.add(d);
                      } else if (cId == null || cId.toString().isEmpty) {
                        globalDocs.add(d);
                      }
                    }
                    docs = [...customerDocs, ...globalDocs];
                  }

                  return _buildSafeStreamDropdown(
                    label: 'Target Product Model *',
                    icon: Icons.memory_outlined,
                    currentValue: item.itemId,
                    legacyName: item.itemName,
                    docs: docs,
                    valueField: 'id',
                    displayField: 'name',
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (val) {
                      if (val != null && docs.any((d) => d.id == val)) {
                        final product = docs.firstWhere((d) => d.id == val).data();
                        product['id'] = val;
                        _applyServiceItemProduct(index, product);
                      }
                    },
                  );
                },
              ),
            ],
          ),

          // Row 4: Brand & Serial Number
          if (isMachine || item.itemNature == 'Spare') ...[
            const SizedBox(height: 12),
            _buildResponsiveRow(
              children: [
                _buildTextField(label: 'Brand / Make', controller: item.brandCtrl, readOnly: true, icon: Icons.branding_watermark),
                if (item.availableSerialNumbers.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final validSerials = item.availableSerialNumbers.where((s) => s.isNotEmpty).toSet().toList();
                      final safeSerial = validSerials.contains(item.serialNumberCtrl.text) ? item.serialNumberCtrl.text : null;

                      return DropdownButtonFormField<String>(
                        value: safeSerial,
                        decoration: _inputDecoration(label: 'Select Serial Number', icon: Icons.tag),
                        items: validSerials.map((sn) => DropdownMenuItem(value: sn, child: Text(sn))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => item.serialNumberCtrl.text = val);
                        },
                      );
                    },
                  )
                else
                  _buildTextField(label: 'Serial Number', controller: item.serialNumberCtrl, icon: Icons.tag_outlined),
              ],
            ),
          ],

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          const Text('Service Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 12),

          _buildResponsiveRow(
            children: [
              _buildDropdown(label: 'Service Category *', icon: Icons.category_outlined, value: item.complaintCategory, items: _categories, onChanged: (v) => setState(() => item.complaintCategory = v!)),
              _buildDropdown(label: 'Priority *', icon: Icons.flag_outlined, value: item.priority, items: _priorities, onChanged: (v) => setState(() => item.priority = v!)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(label: 'Problem Description / Requirement *', controller: item.complaintDescCtrl, icon: Icons.description_outlined, required: true, maxLines: 3),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              title: const Text('Under Warranty?', style: TextStyle(fontSize: 14)),
              value: item.isWarranty,
              onChanged: (val) => setState(() => item.isWarranty = val),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),
          _buildRequiredPartsSection(index),
        ],
      ),
    );
  }

  // --- COMPONENT: SPARES / ACCESSORIES REQUIREMENT PER MACHINE ---
  Widget _buildRequiredPartsSection(int machineIndex) {
    final item = _serviceItems[machineIndex];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Required Parts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Log replacement spares required', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddPartModal(machineIndex),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Part'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade200)
                ),
              ),
            ],
          ),
          if (item.requiredParts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8), color: Colors.white),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1),
                    3: IntrinsicColumnWidth(),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: Color(0xFFE4E7EC)))),
                      children: [
                        Padding(padding: EdgeInsets.all(10), child: Text('Part Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Padding(padding: EdgeInsets.all(10), child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Padding(padding: EdgeInsets.all(10), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Padding(padding: EdgeInsets.all(10), child: Text('Action', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center)),
                      ],
                    ),
                    ...item.requiredParts.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final part = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(border: idx != item.requiredParts.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))) : null),
                        children: [
                          Padding(padding: const EdgeInsets.all(10), child: Text(part['partName'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          Padding(padding: const EdgeInsets.all(10), child: Text((part['partNature'] ?? '').toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
                          Padding(padding: const EdgeInsets.all(10), child: Text(part['quantity'].toString(), style: const TextStyle(fontSize: 13))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              onPressed: () => setState(() => item.requiredParts.removeAt(idx)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- CRM UI BLOCKS ---
  Widget _buildCustomerInformationSection() {
    return _SectionBlock(
      title: 'Customer Information',
      subtitle: 'Identify customer or enter caller details manually',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResponsiveRow(
            children: [
              _buildTextField(
                label: 'Customer Name / Search *',
                controller: _customerNameCtrl,
                icon: Icons.search,
                required: true,
                suffixIcon: _customerNameCtrl.text.isNotEmpty && _selectedCustomerId != null
                    ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clearCustomerSelection,
                  tooltip: 'Clear Customer',
                )
                    : null,
              ),
              _buildTextField(label: 'Customer Code', controller: _customerCodeCtrl, readOnly: true, hintText: 'Auto-generated', icon: Icons.tag),
            ],
          ),

          if (_suggestedCustomers.isNotEmpty && _selectedCustomerId == null)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.person_search, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text('Matching Customers Found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _suggestedCustomers.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final opt = _suggestedCustomers[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(opt['companyName'] ?? opt['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text([opt['customerCode'], opt['phone'] ?? opt['alternatePhone'] ?? opt['companyPhone'], opt['city']].where((e) => e != null && e.toString().isNotEmpty).join(' • '), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade800,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => _applyCustomer(opt),
                          child: const Text('Select'),
                        ),
                        onTap: () => _applyCustomer(opt),
                      );
                    },
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          if (_customerContacts.isNotEmpty) ...[
            Builder(builder: (context) {
              List<DropdownMenuItem<String>> contactItems = [];
              Set<String> addedContacts = {};

              for (var c in _customerContacts) {
                final id = c['id']?.toString();
                if (id != null && !addedContacts.contains(id)) {
                  addedContacts.add(id);
                  final text = '${c['name'] ?? ''} - ${c['designation'] ?? ''} - ${c['phone'] ?? c['mobile'] ?? ''}';
                  contactItems.add(DropdownMenuItem<String>(value: id, child: Text(text, overflow: TextOverflow.ellipsis)));
                }
              }

              if (_selectedContactId != null && !addedContacts.contains(_selectedContactId)) {
                contactItems.add(DropdownMenuItem(value: _selectedContactId, child: Text('${_contactPersonCtrl.text} (Legacy)', overflow: TextOverflow.ellipsis)));
                addedContacts.add(_selectedContactId!);
              }

              final safeContactId = addedContacts.contains(_selectedContactId) ? _selectedContactId : null;

              return DropdownButtonFormField<String>(
                value: safeContactId,
                decoration: _inputDecoration(label: 'Select Contact Person', icon: Icons.contacts_outlined),
                items: contactItems,
                onChanged: _applyContact,
              );
            }),
            const SizedBox(height: 12),
          ],

          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'Contact Person *', controller: _contactPersonCtrl, required: true, icon: Icons.person_outline),
              _buildTextField(label: 'Mobile Number *', controller: _mobileCtrl, required: true, isPhone: true, icon: Icons.phone_outlined),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'Email', controller: _emailCtrl, isEmail: true, icon: Icons.email_outlined),
              _buildTextField(label: 'GST Number', controller: _gstCtrl, icon: Icons.receipt_long_outlined),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'Sales Person', controller: _salesPersonCtrl, readOnly: true, hintText: 'Auto-assigned', icon: Icons.assignment_ind_outlined),
              const SizedBox.shrink(),
            ],
          ),

          if (_customerAddresses.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            Builder(builder: (context) {
              List<DropdownMenuItem<String>> addressItems = [];
              Set<String> addedAddresses = {};

              for (var addr in _customerAddresses) {
                final id = (addr['id'] ?? addr['erpAddressCode'])?.toString();
                if (id != null && !addedAddresses.contains(id)) {
                  addedAddresses.add(id);
                  final text = '${addr['type'] ?? 'Address'} - ${addr['city'] ?? ''} - ${addr['state'] ?? ''}';
                  addressItems.add(DropdownMenuItem<String>(value: id, child: Text(text, overflow: TextOverflow.ellipsis)));
                }
              }

              if (_selectedAddressId != null && !addedAddresses.contains(_selectedAddressId)) {
                addressItems.add(DropdownMenuItem(value: _selectedAddressId, child: const Text('Legacy Address', overflow: TextOverflow.ellipsis)));
                addedAddresses.add(_selectedAddressId!);
              }

              final safeAddressId = addedAddresses.contains(_selectedAddressId) ? _selectedAddressId : null;

              return DropdownButtonFormField<String>(
                value: safeAddressId,
                decoration: _inputDecoration(label: 'Select Address', icon: Icons.location_on_outlined),
                items: addressItems,
                onChanged: _applyAddress,
              );
            }),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 12),
          ],

          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'Address', controller: _addressCtrl, icon: Icons.home_outlined),
              _buildTextField(label: 'City', controller: _cityCtrl, icon: Icons.location_city_outlined),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'State', controller: _stateCtrl, icon: Icons.map_outlined),
              _buildTextField(label: 'Pincode', controller: _pincodeCtrl, icon: Icons.markunread_mailbox_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), offset: const Offset(0, -4), blurRadius: 10)]
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existingDocId != null ? 'Update the service request details.' : 'Save this new service request to CRM.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 170,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveRequest,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : Icon(widget.existingDocId != null ? Icons.save_outlined : Icons.add_circle_outline, size: 18),
                    label: Text(widget.existingDocId != null ? 'Update' : 'Save Request'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildResponsiveRow({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 700;
        if (isStacked) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade600, width: 1.2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade400, width: 1.2)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool required = false,
    bool readOnly = false,
    bool isPhone = false,
    bool isEmail = false,
    int maxLines = 1,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : keyboardType),
      decoration: _inputDecoration(label: label, icon: icon, hintText: hintText).copyWith(
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        suffixIcon: suffixIcon,
      ),
      validator: (val) {
        if (required && !readOnly && (val == null || val.trim().isEmpty)) return 'This field is required';
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    List<String> safeItems = items.where((e) => e.isNotEmpty).toSet().toList();
    if (value.isNotEmpty && !safeItems.contains(value)) safeItems.add(value);
    final safeValue = safeItems.contains(value) ? value : (safeItems.isNotEmpty ? safeItems.first : null);

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: _inputDecoration(label: label, icon: icon),
      items: safeItems.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _SectionBlock({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 0.9),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}