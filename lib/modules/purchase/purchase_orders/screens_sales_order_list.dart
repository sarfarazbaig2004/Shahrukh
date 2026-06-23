import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:QUIK/modules/sales/quotations/quotation_pdf_generator.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_screen.dart';

// =========================================================
// CONSTANTS
// =========================================================
const Color _zPrimary = Color(0xFF2563EB);
const Color _zDanger = Color(0xFFEF4444);
const Color _zSuccess = Color(0xFF10B981);
const Color _zWarning = Color(0xFFF59E0B);

// =========================================================
// HELPER METHODS
// =========================================================
double _parseSafeDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val.replaceAll(',', '')) ?? 0.0;
  return 0.0;
}

String _parseSafeString(dynamic val, {String fallback = '-'}) {
  if (val == null) return fallback;
  final str = val.toString().trim();
  return str.isEmpty ? fallback : str;
}

class SalesOrderListScreen extends StatefulWidget {
  final String companyId;

  const SalesOrderListScreen({super.key, required this.companyId});

  @override
  State<SalesOrderListScreen> createState() => _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends State<SalesOrderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  String? _currentUserUid;
  String? _currentUserRole;

  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedSort = 'Latest';

  final List<String> _statusOptions = [
    'All',
    'Draft',
    'Confirmed',
    'Completed',
    'Cancelled',
  ];
  final List<String> _sortOptions = [
    'Latest',
    'Oldest',
    'Highest Amount',
    'Lowest Amount',
  ];

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _salesOrders = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  final Map<String, String> _userNameCache = {};

  bool get _isAdminOrManager {
    if (_currentUserRole == null) return false;
    final role = _currentUserRole!.trim().toLowerCase().replaceAll('_', '');
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserContext();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserUid = user.uid;

        final companyUserDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('users')
            .doc(user.uid)
            .get();

        if (companyUserDoc.exists && companyUserDoc.data() != null) {
          _currentUserRole = companyUserDoc.data()!['role']?.toString();
        } else {
          final globalUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (globalUserDoc.exists && globalUserDoc.data() != null) {
            final data = globalUserDoc.data()!;
            if (data['memberships'] is Map &&
                data['memberships'][widget.companyId] is Map) {
              _currentUserRole = data['memberships'][widget.companyId]['role']
                  ?.toString();
            }
            _currentUserRole ??= data['role']?.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user context: $e');
    }

    _currentUserRole ??= 'sales';
    _fetchInitialData();
  }

  Future<String> _getUserName(String uid) async {
    if (uid.isEmpty) return 'Unknown User';
    if (_userNameCache.containsKey(uid)) {
      return _userNameCache[uid]!;
    }

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data();
        final name = _parseSafeString(data?['name'], fallback: 'Unknown User');
        _userNameCache[uid] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching user name for $uid: $e');
    }

    _userNameCache[uid] = 'Unknown User';
    return 'Unknown User';
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _fetchSalesOrders(refresh: true);
  }

  Future<void> _fetchSalesOrders({bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
      _hasMore = true;
      _errorMessage = null;
    } else if (!_hasMore || _isFetchingMore) {
      return;
    }

    if (!mounted) return;
    setState(() => refresh ? _isLoading = true : _isFetchingMore = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('sales_orders');

      if (_selectedStatus != 'All') {
        query = query.where('status', isEqualTo: _selectedStatus.toLowerCase());
      }

      switch (_selectedSort) {
        case 'Latest':
          query = query.orderBy('createdAt', descending: true);
          break;
        case 'Oldest':
          query = query.orderBy('createdAt', descending: false);
          break;
        case 'Highest Amount':
          query = query.orderBy('grandTotal', descending: true);
          break;
        case 'Lowest Amount':
          query = query.orderBy('grandTotal', descending: false);
          break;
      }

      // Increased to 50 to ensure standard users get a sufficient page size
      // after local RBAC filtering isolates their records.
      query = query.limit(50);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      if (!mounted) return;

      if (refresh) {
        _salesOrders.clear();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newDocs = snapshot.docs.where((doc) {
          return !_salesOrders.any((existing) => existing.id == doc.id);
        }).toList();

        _salesOrders.addAll(newDocs);

        if (snapshot.docs.length < 50) {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        _errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.code == 'permission-denied') {
        _errorMessage =
            'Access denied. You do not have permission to view these records.';
      } else {
        _errorMessage = 'Unable to load sales orders. Please contact support.';
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore &&
          _hasMore &&
          !_isLoading &&
          _errorMessage == null) {
        _fetchSalesOrders();
      }
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _searchQuery != val) {
        setState(() => _searchQuery = val);
      }
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getFilteredOrders() {
    final query = _searchQuery.trim().toLowerCase();

    return _salesOrders.where((doc) {
      final data = doc.data();

      // 1. RBAC Data Isolation
      bool matchesRole = true;
      if (!_isAdminOrManager && _currentUserUid != null) {
        final createdBy = _parseSafeString(data['createdBy']);
        final assignedToUid = _parseSafeString(data['assignedToUid']);
        final assignedToUsers = data['assignedToUsers'] as List<dynamic>? ?? [];

        if (createdBy != _currentUserUid &&
            assignedToUid != _currentUserUid &&
            !assignedToUsers.contains(_currentUserUid)) {
          matchesRole = false;
        }
      }

      if (!matchesRole) return false;

      // 2. Search Text Filtering
      if (query.isNotEmpty) {
        final soNum = _parseSafeString(
          data['salesOrderNumber'] ?? data['soNumber'] ?? data['orderNumber'],
          fallback: '',
        ).toLowerCase();
        final custName = _parseSafeString(
          data['customerName'] ??
              data['clientName'] ??
              data['partyName'] ??
              data['customer'],
          fallback: '',
        ).toLowerCase();
        if (!soNum.contains(query) && !custName.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Map<String, dynamic> prepareSalesOrderForPdf(
    Map<String, dynamic> mergedData,
  ) {
    mergedData['documentType'] = 'Sales Order';

    DateTime? date;
    final dateRaw =
        mergedData['date'] ?? mergedData['createdAt'] ?? mergedData['soDate'];
    if (dateRaw != null && dateRaw is Timestamp) {
      date = dateRaw.toDate();
    } else if (dateRaw is String && dateRaw.isNotEmpty) {
      try {
        date = DateTime.parse(dateRaw);
      } catch (_) {
        date = DateTime.now();
      }
    } else {
      date = DateTime.now();
    }

    final soNumber = _parseSafeString(
      mergedData['salesOrderNumber'] ??
          mergedData['soNumber'] ??
          mergedData['orderNumber'],
      fallback: 'Draft SO',
    );
    final customerName = _parseSafeString(
      mergedData['customerName'] ??
          mergedData['clientName'] ??
          mergedData['partyName'] ??
          mergedData['customer'],
      fallback: 'Unknown Customer',
    );

    mergedData['salesOrderNumberDisplay'] = soNumber;
    mergedData['quoteNumber'] =
        mergedData['quoteNumber'] ?? mergedData['quotationNumber'];
    mergedData['clientName'] = customerName;
    mergedData['quoteDateStr'] = DateFormat('dd/MM/yyyy').format(date);
    mergedData['grandTotal'] = _parseSafeDouble(
      mergedData['grandTotal'] ??
          mergedData['totalAmount'] ??
          mergedData['amount'],
    );
    mergedData['totalTaxableAmount'] = _parseSafeDouble(
      mergedData['subtotal'] ?? mergedData['totalTaxableAmount'],
    );
    mergedData['totalTaxAmount'] = _parseSafeDouble(
      mergedData['tax'] ?? mergedData['totalTaxAmount'],
    );

    return mergedData;
  }

  Future<void> _openSalesOrderPreview(Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _zPrimary)),
    );

    try {
      Map<String, dynamic> mergedData = {};

      final quoteId = _parseSafeString(
        data['referenceQuotationId'] ?? data['quotationId'] ?? data['quoteId'],
      );

      if (quoteId.isNotEmpty && widget.companyId.isNotEmpty) {
        final quoteDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('quotations')
            .doc(quoteId)
            .get();

        if (quoteDoc.exists) {
          final quoteData = quoteDoc.data() ?? {};
          mergedData.addAll(quoteData);
        }
      }

      final originalQuoteNumber =
          mergedData['quoteNumber'] ?? mergedData['quotationNumber'];

      mergedData.addAll(data);

      mergedData['quoteNumber'] = originalQuoteNumber;
      mergedData['quotationNumber'] = originalQuoteNumber;

      final preparedData = prepareSalesOrderForPdf(mergedData);

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (companyDoc.exists) {
        final companyData = companyDoc.data() ?? {};
        preparedData['companyName'] ??=
            companyData['companyName'] ?? companyData['name'] ?? '';
        preparedData['companyAddress'] ??=
            companyData['companyAddress'] ?? companyData['address'] ?? '';
        preparedData['companyPhone'] ??=
            companyData['companyPhone'] ?? companyData['phone'] ?? '';
        preparedData['companyEmail'] ??=
            companyData['companyEmail'] ?? companyData['email'] ?? '';
        preparedData['companyLogoUrl'] ??=
            companyData['companyLogoUrl'] ?? companyData['logoUrl'] ?? '';
        preparedData['companyGst'] ??=
            companyData['companyGst'] ??
            companyData['gstin'] ??
            companyData['gstNo'] ??
            '';
        preparedData['companyPan'] ??=
            companyData['companyPan'] ?? companyData['pan'] ?? '';
        preparedData['companyIec'] ??=
            companyData['companyIec'] ?? companyData['iec'] ?? '';
        preparedData['companyWebsite'] ??=
            companyData['companyWebsite'] ?? companyData['website'] ?? '';
      }

      final bool isInterState = preparedData['isInterState'] == true;
      final itemsList = (preparedData['items'] is List)
          ? (preparedData['items'] as List)
          : [];

      final parsedItems = itemsList.map((e) {
        final itemMap = Map<String, dynamic>.from(e as Map);

        final double gstRate = _parseSafeDouble(
          itemMap['gstRate'] ?? itemMap['taxRate'] ?? itemMap['gst'],
        );
        double cgst = 0.0;
        double sgst = 0.0;
        double igst = 0.0;

        if (isInterState) {
          igst = gstRate;
        } else {
          cgst = gstRate / 2;
          sgst = gstRate / 2;
        }

        return QuotationLineItem(
          id: itemMap['id']?.toString() ?? '',
          productId: itemMap['productId']?.toString() ?? '',
          name:
              itemMap['name']?.toString() ??
              itemMap['itemName']?.toString() ??
              'Item',
          description: itemMap['description']?.toString() ?? '',
          hsnCode: itemMap['hsnCode']?.toString() ?? '',
          quantity: _parseSafeDouble(itemMap['quantity']),
          uom:
              itemMap['unit']?.toString() ??
              itemMap['uom']?.toString() ??
              'Nos',
          unitPrice: _parseSafeDouble(
            itemMap['unitPrice'] ?? itemMap['price'] ?? itemMap['rate'],
          ),
          discountPercent: _parseSafeDouble(
            itemMap['discountPercent'] ?? itemMap['discount'],
          ),
          cgstPercent: cgst,
          sgstPercent: sgst,
          igstPercent: igst,
          availableStock: _parseSafeDouble(
            itemMap['availableStock'] ?? itemMap['stock'],
          ),
        );
      }).toList();

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuotationPreviewScreen(
            quotation: preparedData,
            items: parsedItems,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load preview: $e'),
          backgroundColor: _zDanger,
        ),
      );
    }
  }

  void _createProformaInvoice(Map<String, dynamic> soData) {
    final Map<String, dynamic> mappedData = Map<String, dynamic>.from(soData);

    mappedData['customerName'] = _parseSafeString(
      soData['customerName'] ??
          soData['clientName'] ??
          soData['partyName'] ??
          soData['customer'],
    );
    mappedData['clientName'] = mappedData['customerName'];

    final String inquiryNum = _parseSafeString(
      soData['inquiryNumber'] ??
          soData['inquiryCode'] ??
          soData['referenceInquiryNumber'] ??
          soData['inquiryId'] ??
          '',
      fallback: '',
    );
    final String quoteNum = _parseSafeString(
      soData['quotationNumber'] ??
          soData['quoteNumber'] ??
          soData['referenceQuotationNumber'] ??
          soData['referenceQuotationId'] ??
          soData['quotationId'] ??
          soData['quoteId'] ??
          '',
      fallback: '',
    );

    mappedData['inquiryNumber'] = inquiryNum;
    mappedData['quotationNumber'] = quoteNum;
    mappedData['referenceQuotationId'] = _parseSafeString(
      soData['referenceQuotationId'] ??
          soData['quotationId'] ??
          soData['quoteId'] ??
          '',
      fallback: '',
    );

    mappedData.remove('salesOrderNumber');
    mappedData.remove('soNumber');
    mappedData.remove('orderNumber');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProformaScreen(
          companyId: widget.companyId,
          inquirySeed: mappedData,
        ),
      ),
    );
  }

  Future<void> _handlePOUpload(String docId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileSize = file.size;

      if (fileSize > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File size exceeds 10MB limit.'),
            backgroundColor: _zDanger,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: _zPrimary)),
      );

      Uint8List fileBytes;
      String fileName = file.name;
      final extension = fileName.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png'].contains(extension);

      if (kIsWeb) {
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else {
          throw Exception('Cannot read file data on web.');
        }
      } else {
        if (isImage && file.path != null) {
          final compressed = await FlutterImageCompress.compressWithFile(
            file.path!,
            quality: 60,
          );
          if (compressed == null) throw Exception('Image compression failed');
          fileBytes = compressed;
        } else if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        } else if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else {
          throw Exception('Cannot read file data.');
        }
      }

      final String safeFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'\s+'), '_')}';
      final storageRef = FirebaseStorage.instance.ref().child(
        'companies/${widget.companyId}/sales_orders/$docId/purchase_order/$safeFileName',
      );

      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(
          contentType: isImage ? 'image/$extension' : 'application/pdf',
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final docRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('sales_orders')
          .doc(docId);

      final user = FirebaseAuth.instance.currentUser;
      final currentUserName = user != null
          ? await _getUserName(user.uid)
          : 'System';

      await docRef.update({
        'purchaseOrder': {
          'url': downloadUrl,
          'fileName': fileName,
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
        'updatedByName': currentUserName,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'PO Upload',
            'note': 'Purchase Order ($fileName) uploaded',
            'timestamp': Timestamp.now(),
            'byUid': user?.uid ?? 'system',
          },
        ]),
      });

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase Order uploaded successfully'),
          backgroundColor: _zSuccess,
        ),
      );

      _fetchInitialData();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload PO: $e'),
          backgroundColor: _zDanger,
        ),
      );
    }
  }

  Future<void> _viewPO(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open file'),
            backgroundColor: _zDanger,
          ),
        );
      }
    }
  }

  Future<void> _updateOrderField(
    String docId,
    Map<String, dynamic> updates,
    String logType,
    String logNote,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('sales_orders')
          .doc(docId);

      final user = FirebaseAuth.instance.currentUser;
      final currentUserName = user != null
          ? await _getUserName(user.uid)
          : 'System';

      updates['activities'] = FieldValue.arrayUnion([
        {
          'type': logType,
          'note': logNote,
          'timestamp': Timestamp.now(),
          'byUid': user?.uid ?? 'system',
        },
      ]);
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['updatedBy'] = user?.uid;
      updates['updatedByName'] = currentUserName;

      await docRef.update(updates);
      _fetchInitialData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: _zDanger,
        ),
      );
    }
  }

  void _showApprovalDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data['status'] == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completed orders cannot be modified.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Approve Sales Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Do you want to approve or reject this order? Approved orders will automatically be Confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _zDanger),
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderField(
                doc.id,
                {'approvalStatus': 'rejected', 'status': 'draft'},
                'Approval',
                'Order Rejected by User',
              );
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _zSuccess),
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderField(
                doc.id,
                {'approvalStatus': 'approved', 'status': 'confirmed'},
                'Approval',
                'Order Approved and Confirmed',
              );
            },
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDispatchDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String currentStatus = _parseSafeString(data['status']).toLowerCase();
    final String approvalStatus = _parseSafeString(
      data['approvalStatus'],
    ).toLowerCase();

    if (approvalStatus != 'approved' || currentStatus != 'confirmed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only Approved and Confirmed orders can be dispatched.',
          ),
          backgroundColor: _zWarning,
        ),
      );
      return;
    }

    String selectedDispatch = _parseSafeString(
      data['dispatchStatus'],
      fallback: 'pending',
    );
    selectedDispatch = selectedDispatch.isEmpty
        ? 'Pending'
        : selectedDispatch[0].toUpperCase() +
              selectedDispatch.substring(1).toLowerCase();
    if (![
      'Pending',
      'Packed',
      'Shipped',
      'Delivered',
    ].contains(selectedDispatch)) {
      selectedDispatch = 'Pending';
    }

    final transCtrl = TextEditingController(
      text: _parseSafeString(data['transporterName'], fallback: ''),
    );
    final vehCtrl = TextEditingController(
      text: _parseSafeString(data['vehicleNumber'], fallback: ''),
    );
    final lrCtrl = TextEditingController(
      text: _parseSafeString(data['lrNumber'], fallback: ''),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Update Dispatch Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedDispatch,
                      decoration: const InputDecoration(
                        labelText: 'Dispatch Status',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Pending', 'Packed', 'Shipped', 'Delivered']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedDispatch = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: transCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Transporter Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: vehCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lrCtrl,
                      decoration: const InputDecoration(
                        labelText: 'LR Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _zPrimary),
                  onPressed: () {
                    final updates = <String, dynamic>{
                      'dispatchStatus': selectedDispatch.toLowerCase(),
                      'transporterName': transCtrl.text.trim(),
                      'vehicleNumber': vehCtrl.text.trim(),
                      'lrNumber': lrCtrl.text.trim(),
                    };

                    if (selectedDispatch.toLowerCase() == 'delivered') {
                      updates['status'] = 'completed';
                    }

                    Navigator.pop(ctx);
                    _updateOrderField(
                      doc.id,
                      updates,
                      'Dispatch',
                      'Dispatch updated to $selectedDispatch via ${transCtrl.text.trim()}',
                    );
                  },
                  child: const Text(
                    'Save Dispatch',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _cancelOrder(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String status = _parseSafeString(data['status']).toLowerCase();
    final String dispatchStatus = _parseSafeString(
      data['dispatchStatus'],
    ).toLowerCase();

    if (status == 'completed' ||
        dispatchStatus == 'shipped' ||
        dispatchStatus == 'delivered') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot cancel orders that are shipped, delivered, or completed.',
          ),
          backgroundColor: _zWarning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cancel Order',
          style: TextStyle(color: _zDanger, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this Sales Order? This action cannot be fully undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'No, Keep It',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _zDanger),
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderField(
                doc.id,
                {'status': 'cancelled'},
                'Status Update',
                'Order manually cancelled',
              );
            },
            child: const Text(
              'Yes, Cancel Order',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'All';
      _selectedSort = 'Latest';
    });
    _fetchInitialData();
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'All' || _selectedSort != 'Latest';

  Future<void> _openFilterSheet() async {
    String tempStatus = _selectedStatus;
    String tempSort = _selectedSort;

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
                      items: _statusOptions
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
                          tempSort = value ?? 'Latest';
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
                                _selectedStatus = 'All';
                                _selectedSort = 'Latest';
                              });
                              _fetchInitialData();
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatus = tempStatus;
                                _selectedSort = tempSort;
                              });
                              _fetchInitialData();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _salesOrders.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _salesOrders.isEmpty) {
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

    final filteredDocs = _getFilteredOrders();
    int totalOrders = filteredDocs.length;
    double totalRevenue = 0;
    int confirmedCount = 0;
    int dispatchPendingCount = 0;

    for (var doc in filteredDocs) {
      final data = doc.data();
      totalRevenue += _parseSafeDouble(
        data['grandTotal'] ?? data['totalAmount'] ?? data['amount'],
      );
      final st = _parseSafeString(data['status']).toLowerCase();
      final dst = _parseSafeString(data['dispatchStatus']).toLowerCase();

      if (st == 'confirmed') confirmedCount++;
      if (st == 'confirmed' && dst != 'delivered') dispatchPendingCount++;
    }

    final String formattedRevenue = NumberFormat.compactCurrency(
      symbol: '₹',
      locale: 'en_IN',
    ).format(totalRevenue);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search order or customer...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close, size: 17),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
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
                const Spacer(),
                _MiniStatText(label: 'Total', value: totalOrders.toString()),
                const SizedBox(width: 10),
                _MiniStatText(label: 'Rev', value: formattedRevenue),
                const SizedBox(width: 10),
                _MiniStatText(
                  label: 'Confirmed',
                  value: confirmedCount.toString(),
                ),
                const SizedBox(width: 10),
                _MiniStatText(
                  label: 'Disp Pend',
                  value: dispatchPendingCount.toString(),
                ),
              ],
            ),
          ),
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filteredDocs.isEmpty
                ? _EmptyOrdersState(
                    hasSearch:
                        _searchQuery.trim().isNotEmpty || _hasActiveFilters,
                    onReset: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _resetFilters();
                    },
                  )
                : RefreshIndicator(
                    onRefresh: _fetchInitialData,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: filteredDocs.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == filteredDocs.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final doc = filteredDocs[index];
                        final data = doc.data();

                        return _SalesOrderCard(
                          key: ValueKey(doc.id),
                          document: doc,
                          nameResolver: _getUserName,
                          onViewTap: () => _openSalesOrderPreview(data),
                          onDispatchTap: () => _showDispatchDialog(doc),
                          onApproveTap: () => _showApprovalDialog(doc),
                          onCancelTap: () => _cancelOrder(doc),
                          onUploadPOTap: () => _handlePOUpload(doc.id),
                          onViewPOTap: () {
                            final poData = data['purchaseOrder'];
                            if (poData != null && poData['url'] != null) {
                              _viewPO(poData['url']);
                            }
                          },
                          onCreateProformaTap: () =>
                              _createProformaInvoice(data),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SalesOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final Future<String> Function(String) nameResolver;
  final VoidCallback onViewTap;
  final VoidCallback onDispatchTap;
  final VoidCallback onApproveTap;
  final VoidCallback onCancelTap;
  final VoidCallback onUploadPOTap;
  final VoidCallback onViewPOTap;
  final VoidCallback onCreateProformaTap;

  const _SalesOrderCard({
    super.key,
    required this.document,
    required this.nameResolver,
    required this.onViewTap,
    required this.onDispatchTap,
    required this.onApproveTap,
    required this.onCancelTap,
    required this.onUploadPOTap,
    required this.onViewPOTap,
    required this.onCreateProformaTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final String soNumber = _parseSafeString(
      data['salesOrderNumber'] ?? data['soNumber'] ?? data['orderNumber'],
      fallback: 'Draft SO',
    );
    final String customerName = _parseSafeString(
      data['customerName'] ??
          data['clientName'] ??
          data['partyName'] ??
          data['customer'],
      fallback: 'Unknown Customer',
    );
    final String status = _parseSafeString(
      data['status'],
      fallback: 'draft',
    ).toLowerCase();
    final String approvalStatus = _parseSafeString(
      data['approvalStatus'],
      fallback: 'pending',
    ).toLowerCase();
    final String dispatchStatus = _parseSafeString(
      data['dispatchStatus'],
      fallback: 'pending',
    ).toLowerCase();
    final double grandTotal = _parseSafeDouble(
      data['grandTotal'] ?? data['totalAmount'] ?? data['amount'],
    );

    DateTime? date;
    final dateRaw = data['date'] ?? data['createdAt'] ?? data['soDate'];
    if (dateRaw != null && dateRaw is Timestamp) {
      date = dateRaw.toDate();
    }

    final formattedDate = date != null
        ? DateFormat('dd/MM/yyyy').format(date)
        : '-';
    final formattedAmount = NumberFormat.currency(
      symbol: '₹',
      locale: 'en_IN',
      decimalDigits: grandTotal.truncateToDouble() == grandTotal ? 0 : 2,
    ).format(grandTotal);

    final bool canCancel =
        status != 'completed' &&
        dispatchStatus != 'shipped' &&
        dispatchStatus != 'delivered' &&
        status != 'cancelled';
    final bool canDispatch =
        approvalStatus == 'approved' && status == 'confirmed';
    final bool canApprove =
        status != 'cancelled' &&
        status != 'completed' &&
        approvalStatus != 'approved' &&
        approvalStatus != 'rejected';

    final Map<String, dynamic>? poData = data['purchaseOrder'];
    final bool hasPO =
        poData != null && _parseSafeString(poData['url']).isNotEmpty;

    final String createdByUid = _parseSafeString(data['createdBy']);
    final String explicitlyStoredName =
        data['createdByName']?.toString().trim() ?? '';

    String formattedUpdatedAt = '--';
    final updatedAtRaw = data['updatedAt'];
    if (updatedAtRaw != null && updatedAtRaw is Timestamp) {
      formattedUpdatedAt = DateFormat(
        'dd/MM/yyyy',
      ).format(updatedAtRaw.toDate());
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    customerName.isNotEmpty
                        ? customerName[0].toUpperCase()
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              soNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (hasPO)
                            const Padding(
                              padding: EdgeInsets.only(left: 6.0),
                              child: Icon(
                                Icons.attachment_rounded,
                                size: 14,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    onSelected: (value) {
                      if (value == 'view') onViewTap();
                      if (value == 'dispatch') onDispatchTap();
                      if (value == 'approve') onApproveTap();
                      if (value == 'cancel') onCancelTap();
                      if (value == 'view_po') onViewPOTap();
                      if (value == 'upload_po') onUploadPOTap();
                      if (value == 'create_proforma') onCreateProformaTap();
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Text('View Details'),
                      ),
                      const PopupMenuDivider(),
                      if (hasPO)
                        const PopupMenuItem(
                          value: 'view_po',
                          child: Text(
                            'View PO',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      PopupMenuItem(
                        value: 'upload_po',
                        child: Text(
                          hasPO ? 'Replace PO' : 'Upload PO',
                          style: TextStyle(
                            color: hasPO ? Colors.grey.shade700 : Colors.blue,
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'create_proforma',
                        child: Text('Create Proforma Invoice'),
                      ),
                      const PopupMenuDivider(),
                      if (canApprove)
                        const PopupMenuItem(
                          value: 'approve',
                          child: Text('Approve / Reject'),
                        ),
                      if (canDispatch)
                        const PopupMenuItem(
                          value: 'dispatch',
                          child: Text('Update Dispatch'),
                        ),
                      if (canCancel)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text(
                            'Cancel Order',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusBadge(status: status, type: 'Order'),
                _StatusBadge(status: approvalStatus, type: 'Approval'),
                _StatusBadge(status: dispatchStatus, type: 'Dispatch'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_parseSafeString(
                  data['referenceQuotationId'] ?? data['quotationId'],
                ).isNotEmpty)
                  _InlineInfo(
                    icon: Icons.tag_outlined,
                    text:
                        'Ref: ${_parseSafeString(data['referenceQuotationId'] ?? data['quotationId'])}',
                  ),
                _InlineInfo(
                  icon: Icons.currency_rupee_outlined,
                  text: formattedAmount,
                ),
                if (explicitlyStoredName.isNotEmpty)
                  _InlineInfo(
                    icon: Icons.person_outline,
                    text: explicitlyStoredName,
                  )
                else
                  FutureBuilder<String>(
                    future: nameResolver(createdByUid),
                    builder: (context, snapshot) {
                      return _InlineInfo(
                        icon: Icons.person_outline,
                        text: snapshot.data ?? '...',
                      );
                    },
                  ),
                _InlineInfo(
                  icon: Icons.add_circle_outline,
                  text: 'Created: $formattedDate',
                ),
                if (formattedUpdatedAt != '--')
                  _InlineInfo(
                    icon: Icons.edit_outlined,
                    text: 'Updated: $formattedUpdatedAt',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String type;

  const _StatusBadge({required this.status, required this.type});

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade700;
    String displayStatus = status.toUpperCase();

    final s = status.toLowerCase();

    if (type == 'Approval') {
      if (s == 'approved') {
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
      } else if (s == 'rejected') {
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
      } else {
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        displayStatus = 'PENDING APPR';
      }
    } else if (type == 'Dispatch') {
      if (s == 'delivered') {
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
      } else if (s == 'shipped') {
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
      } else if (s == 'packed') {
        bgColor = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
      } else {
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        displayStatus = 'DISP PENDING';
      }
    } else {
      if (s == 'confirmed') {
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
      } else if (s == 'completed') {
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
      } else if (s == 'cancelled') {
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
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

class _EmptyOrdersState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyOrdersState({required this.hasSearch, required this.onReset});

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
                          ? 'No matching orders found'
                          : 'No orders found',
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
                          : 'No sales order records are available yet.',
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
