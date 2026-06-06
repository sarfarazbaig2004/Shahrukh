// FILE PATH: lib/modules/service/screens/add_service_request_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // --- GENERIC SERVICE ITEM HIERARCHY STATE ---
  String _serviceItemNature = 'Machine'; // Default to Machine
  String? _serviceCategoryId;
  String? _serviceCategoryName;
  String? _serviceSubcategoryId;
  String? _serviceSubcategoryName;
  String? _serviceMachineType;

  String? _serviceItemId;
  String? _serviceItemCode;
  String? _serviceItemName;
  List<String> _availableSerialNumbers = [];

  List<Map<String, dynamic>> _requiredParts = [];

  // --- CONTROLLERS ---
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

  final TextEditingController _brandCtrl = TextEditingController();
  final TextEditingController _serialNumberCtrl = TextEditingController();
  final TextEditingController _complaintDescCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  String _selectedCategory = 'Machine Breakdown';
  String _selectedPriority = 'Medium';
  String _selectedSource = 'Customer Call';
  bool _isWarranty = false;
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


  @override
  void initState() {
    super.initState();
    _customerNameCtrl.addListener(_onCustomerFieldChanged);
    _mobileCtrl.addListener(_onContactFieldTyped);
    _emailCtrl.addListener(_onContactFieldTyped);

    if (widget.existingData != null) {
      final d = widget.existingData!;

      _selectedCustomerId = d['customerId'];
      _selectedCustomerCode = d['customerCode'];
      _selectedContactId = d['contactId'];
      _selectedAddressId = d['selectedAddressId'];
      _salesPersonId = d['salesPersonId'];
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

      // --- Map Service Assignment ---
      _assignedToUid = d['assignedToUid'];
      _assignedToName = d['assignedToName'];
      _assignedToEmail = d['assignedToEmail'];

      // --- Map Service Item Hierarchy (Safely falling back to legacy machine fields) ---
      _serviceItemNature = d['serviceItemNature'] ?? d['machineNature'] ?? 'Machine';
      _serviceCategoryId = d['serviceCategoryId'] ?? d['machineCategoryId'];
      _serviceCategoryName = d['serviceCategoryName'] ?? d['machineCategory'];
      _serviceSubcategoryId = d['serviceSubcategoryId'] ?? d['machineSubcategoryId'];
      _serviceSubcategoryName = d['serviceSubCategoryName'] ?? d['machineSubCategory'];
      _serviceMachineType = d['serviceMachineType'] ?? d['machineType'];
      _serviceItemId = d['serviceItemId'] ?? d['machineId'];
      _serviceItemCode = d['serviceItemCode'] ?? d['machineCode'];
      _serviceItemName = d['serviceItemName'] ?? d['machineModel'];
      _brandCtrl.text = d['brand'] ?? d['machineBrand'] ?? '';
      _serialNumberCtrl.text = d['serialNumber'] ?? d['machineSerialNumber'] ?? '';

      if (d['requiredParts'] is List) {
        _requiredParts = List<Map<String, dynamic>>.from(
            (d['requiredParts'] as List).map((x) => Map<String, dynamic>.from(x))
        );
      }

      _complaintDescCtrl.text = d['complaintDescription'] ?? '';
      _remarksCtrl.text = d['remarks'] ?? '';
      _selectedCategory = d['complaintCategory'] ?? _categories.first;
      _selectedPriority = d['priority'] ?? _priorities[1];
      _selectedSource = d['source'] ?? _sources.first;
      _isWarranty = d['isWarranty'] ?? false;
      _status = d['status'] ?? 'New';

      if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
        _fetchCustomerRelatedData(_selectedCustomerId!);
      }
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
    _brandCtrl.dispose();
    _serialNumberCtrl.dispose();
    _complaintDescCtrl.dispose();
    _remarksCtrl.dispose();
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

  void _resetHierarchy({bool resetCat = false, bool resetSub = false, bool resetType = false}) {
    setState(() {
      if (resetCat) {
        _serviceCategoryId = null;
        _serviceCategoryName = null;
      }
      if (resetSub) {
        _serviceSubcategoryId = null;
        _serviceSubcategoryName = null;
      }
      if (resetType) {
        _serviceMachineType = null;
      }
      _serviceItemId = null;
      _serviceItemName = null;
      _serviceItemCode = null;
      _brandCtrl.clear();
      _serialNumberCtrl.clear();
      _availableSerialNumbers.clear();
      _isWarranty = false;
    });
  }

  void _applyServiceItemProduct(Map<String, dynamic> product) {
    setState(() {
      _serviceItemId = product['id'];
      _serviceItemName = (product['name'] ?? '').toString();
      _serviceItemCode = (product['itemCode'] ?? product['sku'] ?? '').toString();
      _brandCtrl.text = (product['make'] ?? product['brand'] ?? '').toString();

      // Smart extraction for serial numbers (Array logic)
      if (product['serialNumbers'] is List) {
        _availableSerialNumbers = List<String>.from(product['serialNumbers']).where((s) => s.isNotEmpty).toList();
      } else {
        _availableSerialNumbers.clear();
      }

      // Auto-extract warranty bounds if tracked natively
      if (product['warrantyMonths'] != null) {
        _isWarranty = true;
      }
    });
  }

  // ==========================================
  // SPARES & ACCESSORIES ENGINE
  // ==========================================

  Future<void> _showAddPartModal() async {
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
                            .limit(50) // Progressive load
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

                          // Prevent duplicates
                          docs = docs.where((d) => !_requiredParts.any((ip) => ip['partId'] == d.id)).toList();

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

    if (result != null) {
      setState(() => _requiredParts.add(result));
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
    if (_serviceItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select the Target Item from Inventory.'), backgroundColor: Colors.red));
      return;
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
      'assignedToUid': _assignedToUid ?? '',
      'assignedToName': _assignedToName ?? '',
      'assignedToEmail': _assignedToEmail ?? '',
      'assignedByUid': widget.currentUserUid,
      'assignedByName': widget.currentUserName,
      'assignedAt': (_assignedToUid != null && _assignedToUid!.isNotEmpty)
          ? (widget.existingData != null && widget.existingData!['assignedToUid'] == _assignedToUid
          ? widget.existingData!['assignedAt']
          : FieldValue.serverTimestamp())
          : null,

      // Modern Generic Mapping
      'serviceItemNature': _serviceItemNature,
      'serviceCategoryId': _serviceCategoryId,
      'serviceCategoryName': _serviceCategoryName,
      'serviceSubcategoryId': _serviceSubcategoryId,
      'serviceSubCategoryName': _serviceSubcategoryName,
      'serviceMachineType': _serviceItemNature == 'Machine' ? _serviceMachineType : null,
      'serviceItemId': _serviceItemId,
      'serviceItemCode': _serviceItemCode,
      'serviceItemName': _serviceItemName,
      'brand': _brandCtrl.text.trim(),
      'serialNumber': _serialNumberCtrl.text.trim(),

      // Legacy Mappings (Preserved for backwards compatibility with existing UI/reports)
      'machineCategoryId': _serviceCategoryId,
      'machineCategory': _serviceCategoryName,
      'machineSubcategoryId': _serviceSubcategoryId,
      'machineSubCategory': _serviceSubcategoryName,
      'machineType': _serviceMachineType,
      'machineId': _serviceItemId,
      'machineCode': _serviceItemCode,
      'machineModel': _serviceItemName,
      'machineNature': _serviceItemNature,
      'machineBrand': _brandCtrl.text.trim(),
      'machineSerialNumber': _serialNumberCtrl.text.trim(),

      'requiredParts': _requiredParts,

      'complaintCategory': _selectedCategory,
      'complaintDescription': _complaintDescCtrl.text.trim(),
      'priority': _selectedPriority,
      'source': _selectedSource,
      'status': _status,
      'isWarranty': _isWarranty,
      'remarks': _remarksCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': widget.currentUserUid,
      'isDeleted': false,
      'searchKeywords': _generateSearchKeywords(reqNo),
    };
  }

  List<String> _generateSearchKeywords(String requestNo) {
    final str = '$requestNo ${_customerNameCtrl.text} ${_contactPersonCtrl.text} ${_mobileCtrl.text} ${_serviceItemName ?? ''} ${_serialNumberCtrl.text} ${_selectedCustomerCode ?? ''} ${_gstCtrl.text}'.toLowerCase();
    return str.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet().toList();
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

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
                        _buildServiceItemSection(),
                        const SizedBox(height: 16),
                        _SectionBlock(
                          title: 'Service Details',
                          subtitle: 'Provide technical details of the issue or requirement',
                          child: Column(
                            children: [
                              _buildResponsiveRow(
                                children: [
                                  _buildDropdown(label: 'Service Category *', icon: Icons.category_outlined, value: _selectedCategory, items: _categories, onChanged: (v) => setState(() => _selectedCategory = v!)),
                                  _buildDropdown(label: 'Priority *', icon: Icons.flag_outlined, value: _selectedPriority, items: _priorities, onChanged: (v) => setState(() => _selectedPriority = v!)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(label: 'Problem Description / Requirement *', controller: _complaintDescCtrl, icon: Icons.description_outlined, required: true, maxLines: 3),
                              const SizedBox(height: 12),
                              _buildResponsiveRow(
                                children: [
                                  _buildDropdown(label: 'Source *', icon: Icons.campaign_outlined, value: _selectedSource, items: _sources, onChanged: (v) => setState(() => _selectedSource = v!)),
                                  Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.white),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    child: SwitchListTile(
                                      title: const Text('Under Warranty?', style: TextStyle(fontSize: 14)),
                                      value: _isWarranty,
                                      onChanged: (val) => setState(() => _isWarranty = val),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildRequiredPartsSection(),
                        const SizedBox(height: 16),
                        _SectionBlock(
                          title: 'Additional Information',
                          subtitle: 'Internal remarks and attachments',
                          child: _buildTextField(label: 'Internal Remarks', controller: _remarksCtrl, icon: Icons.notes_outlined, maxLines: 2),
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
        subtitle: 'Assign this request to a service coordinator or engineer',
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersRef.where('isActive', isEqualTo: true).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const LinearProgressIndicator();
              }
              if (snap.hasError) {
                return Text('Error loading users: ${snap.error}', style: const TextStyle(color: Colors.red));
              }

              var docs = snap.data?.docs ?? [];

              // ONLY Service Department users
              docs = docs.where((doc) {
                final dept = (doc.data()['department'] ?? '').toString().toLowerCase().trim();
                return dept.contains('service');
              }).toList();

              List<DropdownMenuItem<String?>> items = [
                const DropdownMenuItem(value: null, child: Text('Unassigned (Leave blank)')),
              ];

              for (var doc in docs) {
                final data = doc.data();
                final name = (data['name'] ?? data['fullName'] ?? 'Unknown').toString();
                final designation = (data['designation'] ?? '').toString();
                final label = designation.isNotEmpty ? '$name - $designation' : name;
                items.add(DropdownMenuItem(value: doc.id, child: Text(label)));
              }

              // Handle case where existing assigned user is no longer active or moved out of service dept
              if (_assignedToUid != null && _assignedToUid!.isNotEmpty && !docs.any((d) => d.id == _assignedToUid)) {
                items.add(DropdownMenuItem(
                  value: _assignedToUid,
                  child: Text('${_assignedToName ?? 'Unknown User'} (Inactive/Moved)'),
                ));
              }

              return DropdownButtonFormField<String?>(
                value: _assignedToUid,
                decoration: _inputDecoration(label: 'Assign To', icon: Icons.person_pin_circle_outlined),
                items: items,
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

  // --- COMPONENT: DYNAMIC SERVICE ITEM HIERARCHY ---
  Widget _buildServiceItemSection() {
    bool isMachine = _serviceItemNature == 'Machine';

    return _SectionBlock(
      title: 'Target Service Item',
      subtitle: 'Select the nature of the product and locate it in inventory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Nature Dropdown
          _buildDropdown(
            label: 'Product Nature *',
            icon: Icons.settings_applications_outlined,
            value: _serviceItemNature,
            items: ['Machine', 'Spare', 'Accessory', 'Consumable'],
            onChanged: (val) {
              if (val != null) {
                _resetHierarchy(resetCat: true, resetSub: true, resetType: true);
                setState(() => _serviceItemNature = val);
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
                  List<DropdownMenuItem<String>> items = [];
                  if (snap.hasData) {
                    items = snap.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc.data()['name'] ?? ''))).toList();
                  }
                  return DropdownButtonFormField<String>(
                    value: _serviceCategoryId,
                    decoration: _inputDecoration(label: 'Category *', icon: Icons.folder_outlined),
                    items: items,
                    onChanged: (val) {
                      if (val != null) {
                        _resetHierarchy(resetSub: true, resetType: true);
                        _serviceCategoryId = val;
                        _serviceCategoryName = snap.data!.docs.firstWhere((d) => d.id == val).data()['name'];
                      }
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  );
                },
              ),
              if (_serviceCategoryId != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _subcategoriesRef(_serviceCategoryId!).orderBy('nameLower').snapshots(),
                  builder: (context, snap) {
                    List<DropdownMenuItem<String>> items = [];
                    if (snap.hasData) {
                      items = snap.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc.data()['name'] ?? ''))).toList();
                    }
                    return DropdownButtonFormField<String>(
                      value: _serviceSubcategoryId,
                      decoration: _inputDecoration(label: 'Sub Category', icon: Icons.folder_open_outlined),
                      items: items,
                      onChanged: (val) {
                        if (val != null) {
                          _resetHierarchy(resetType: true);
                          _serviceSubcategoryId = val;
                          _serviceSubcategoryName = snap.data!.docs.firstWhere((d) => d.id == val).data()['name'];
                        }
                      },
                    );
                  },
                )
              else
                _buildDropdown(label: 'Sub Category', icon: Icons.folder_open_outlined, value: '', items: [''], onChanged: (_) {}),
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
                    List<DropdownMenuItem<String>> items = [];
                    if (snap.hasData) {
                      items = snap.data!.docs.map((doc) => DropdownMenuItem(value: doc.data()['name'] as String, child: Text(doc.data()['name'] ?? ''))).toList();
                    }
                    return DropdownButtonFormField<String>(
                      value: _serviceMachineType,
                      decoration: _inputDecoration(label: 'Machine Type', icon: Icons.precision_manufacturing_outlined),
                      items: items,
                      onChanged: (val) {
                        if (val != null) {
                          _resetHierarchy();
                          _serviceMachineType = val;
                        }
                      },
                    );
                  },
                ),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _productsRef
                    .where('isActive', isEqualTo: true)
                    .where('productNatureLower', isEqualTo: _serviceItemNature.toLowerCase())
                    .snapshots(),
                builder: (context, snap) {
                  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.data?.docs ?? [];

                  // Cascading Filters
                  if (_serviceCategoryId != null) docs = docs.where((d) => d.data()['categoryId'] == _serviceCategoryId).toList();
                  if (_serviceSubcategoryId != null) docs = docs.where((d) => d.data()['subcategoryId'] == _serviceSubcategoryId).toList();
                  if (isMachine && _serviceMachineType != null) docs = docs.where((d) => d.data()['machineType'] == _serviceMachineType).toList();

                  // Customer Ownership Filter (If items are strictly mapped to customers in inventory)
                  if (_selectedCustomerId != null) {
                    docs = docs.where((d) {
                      final cId = d.data()['customerId'];
                      if (cId != null && cId.toString().isNotEmpty) {
                        return cId == _selectedCustomerId; // Restrict if strictly owned
                      }
                      return true; // General catalog item
                    }).toList();
                  }

                  List<DropdownMenuItem<String>> items = docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc.data()['name'] ?? ''))).toList();

                  return DropdownButtonFormField<String>(
                    value: _serviceItemId,
                    decoration: _inputDecoration(label: 'Target Product Model *', icon: Icons.memory_outlined),
                    items: items,
                    onChanged: (val) {
                      if (val != null) {
                        final product = docs.firstWhere((d) => d.id == val).data();
                        product['id'] = val; // Inject ID
                        _applyServiceItemProduct(product);
                      }
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  );
                },
              ),
            ],
          ),

          // Row 4: Brand & Serial Number (Only for Machines, or Spares with Serial)
          if (isMachine || _serviceItemNature == 'Spare') ...[
            const SizedBox(height: 12),
            _buildResponsiveRow(
              children: [
                _buildTextField(label: 'Brand / Make', controller: _brandCtrl, readOnly: true, icon: Icons.branding_watermark),
                if (_availableSerialNumbers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _availableSerialNumbers.contains(_serialNumberCtrl.text) ? _serialNumberCtrl.text : null,
                    decoration: _inputDecoration(label: 'Select Serial Number', icon: Icons.tag),
                    items: _availableSerialNumbers.map((sn) => DropdownMenuItem(value: sn, child: Text(sn))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _serialNumberCtrl.text = val);
                    },
                  )
                else
                  _buildTextField(label: 'Serial Number', controller: _serialNumberCtrl, icon: Icons.tag_outlined),
              ],
            ),
          ]
        ],
      ),
    );
  }

  // --- COMPONENT: SPARES / ACCESSORIES REQUIREMENT ---
  Widget _buildRequiredPartsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Required Parts & Accessories', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Log required replacement spares or accessories', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showAddPartModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Part'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade700, side: BorderSide(color: Colors.blue.shade200)),
              ),
            ],
          ),
          if (_requiredParts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE4E7EC)), borderRadius: BorderRadius.circular(8)),
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
                    ..._requiredParts.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(border: idx != _requiredParts.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))) : null),
                        children: [
                          Padding(padding: const EdgeInsets.all(10), child: Text(item['partName'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          Padding(padding: const EdgeInsets.all(10), child: Text((item['partNature'] ?? '').toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
                          Padding(padding: const EdgeInsets.all(10), child: Text(item['quantity'].toString(), style: const TextStyle(fontSize: 13))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              onPressed: () => setState(() => _requiredParts.removeAt(idx)),
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
            DropdownButtonFormField<String>(
              value: _selectedContactId,
              decoration: _inputDecoration(label: 'Select Contact Person', icon: Icons.contacts_outlined),
              items: _customerContacts.map((c) {
                final text = '${c['name'] ?? ''} - ${c['designation'] ?? ''} - ${c['phone'] ?? c['mobile'] ?? ''}';
                return DropdownMenuItem<String>(value: c['id'], child: Text(text, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: _applyContact,
            ),
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
            DropdownButtonFormField<String>(
              value: _selectedAddressId,
              decoration: _inputDecoration(label: 'Select Address', icon: Icons.location_on_outlined),
              items: _customerAddresses.map((addr) {
                final text = '${addr['type'] ?? 'Address'} - ${addr['city'] ?? ''} - ${addr['state'] ?? ''}';
                return DropdownMenuItem<String>(value: addr['id'] ?? addr['erpAddressCode'], child: Text(text, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: _applyAddress,
            ),
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
    if (!items.contains(value)) items.add(value);
    return DropdownButtonFormField<String>(
      value: value.isEmpty && items.length > 1 ? items.firstWhere((e) => e.isNotEmpty) : value,
      decoration: _inputDecoration(label: label, icon: icon),
      items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e.isEmpty ? 'Select' : e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionBlock({
    required this.title,
    required this.subtitle,
    required this.child,
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
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}