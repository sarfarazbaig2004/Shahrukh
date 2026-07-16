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

// Enterprise sales-order workspace palette.
const Color _zSlate50 = Color(0xFFF8FAFC);
const Color _zSlate100 = Color(0xFFF1F5F9);
const Color _zSlate200 = Color(0xFFE2E8F0);
const Color _zSlate300 = Color(0xFFCBD5E1);
const Color _zSlate400 = Color(0xFF94A3B8);
const Color _zSlate500 = Color(0xFF64748B);
const Color _zSlate600 = Color(0xFF475569);
const Color _zSlate700 = Color(0xFF334155);
const Color _zSlate800 = Color(0xFF1E293B);
const Color _zSoftHoverBorder = Color(0xFFB8C7D9);
const Color _zInquiryBlue = Color(0xFF5F7FA3);
const Color _zErpPrimaryBlue = Color(0xFF2F6EA5);

const double _salesOrderGridMinWidth = 1320;
const double _salesOrderGridHorizontalPadding = 12;
const double _salesOrderGridActionWidth = 48;
const int _salesOrderCustomerFlex = 28;
const int _salesOrderStatusFlex = 11;
const int _salesOrderDispatchFlex = 12;
const int _salesOrderItemsFlex = 15;
const int _salesOrderAmountFlex = 10;
const int _salesOrderOwnerFlex = 11;
const int _salesOrderCreatedFlex = 8;
const int _salesOrderUpdatedFlex = 8;
const int _salesOrderPoFlex = 9;

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

  Widget _buildWorkspaceHeader({
    required int totalOrders,
    required String formattedRevenue,
    required int confirmedCount,
    required int dispatchPendingCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _zSlate200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compactToolbar = constraints.maxWidth < 980;
          final Widget searchBox = _buildToolbarSearchBox();
          final Widget kpiBar = _buildToolbarKpiBar(
            totalOrders: totalOrders,
            formattedRevenue: formattedRevenue,
            confirmedCount: confirmedCount,
            dispatchPendingCount: dispatchPendingCount,
          );
          final Widget actions = _buildToolbarActions();

          if (compactToolbar) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchBox,
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: kpiBar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    actions,
                  ],
                ),
              ],
            );
          }

          final double searchWidth = constraints.maxWidth < 1250 ? 280 : 330;

          return Row(
            children: [
              SizedBox(width: searchWidth, child: searchBox),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: kpiBar,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbarSearchBox() {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 11, color: _zSlate700),
        decoration: InputDecoration(
          hintText: 'Search sales order or customer...',
          hintStyle: const TextStyle(color: _zSlate400, fontSize: 10.8),
          prefixIcon: const Icon(Icons.search, size: 14, color: _zSlate400),
          prefixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIconConstraints: const BoxConstraints(minWidth: 30),
          suffixIcon: _searchQuery.trim().isEmpty
              ? null
              : IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.close, size: 13, color: _zSlate500),
            padding: EdgeInsets.zero,
            onPressed: () {
              _debounce?.cancel();
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _zSlate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _zSlate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _zSlate300),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarKpiBar({
    required int totalOrders,
    required String formattedRevenue,
    required int confirmedCount,
    required int dispatchPendingCount,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnterpriseSalesOrderKpi(title: 'Total', value: totalOrders.toString()),
        const SizedBox(width: 16),
        _EnterpriseSalesOrderKpi(title: 'Revenue', value: formattedRevenue),
        const SizedBox(width: 16),
        _EnterpriseSalesOrderKpi(
          title: 'Confirmed',
          value: confirmedCount.toString(),
        ),
        const SizedBox(width: 16),
        _EnterpriseSalesOrderKpi(
          title: 'Dispatch Pending',
          value: dispatchPendingCount.toString(),
        ),
      ],
    );
  }

  Widget _buildToolbarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SalesOrderToolbarButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          onTap: _fetchInitialData,
        ),
        const SizedBox(width: 6),
        _SalesOrderToolbarButton(
          icon: Icons.filter_list_rounded,
          label: _hasActiveFilters ? 'Filters (Active)' : 'Filters',
          isActive: _hasActiveFilters,
          onTap: _openFilterSheet,
        ),
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _zSlate600,
              ),
            ),
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

    if (_selectedStatus != 'All') {
      chips.add(
        buildChip('Status: $_selectedStatus', () {
          setState(() => _selectedStatus = 'All');
          _fetchInitialData();
        }),
      );
    }

    if (_selectedSort != 'Latest') {
      chips.add(
        buildChip('Sort: $_selectedSort', () {
          setState(() => _selectedSort = 'Latest');
          _fetchInitialData();
        }),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
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
            child: Text(
              'Active filters',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _zSlate500,
              ),
            ),
          ),
          ...chips,
          InkWell(
            onTap: _resetFilters,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'Clear all',
                style: TextStyle(
                  fontSize: 10,
                  color: _zSlate600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOrderTableHeader() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: _salesOrderGridHorizontalPadding),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FA),
        border: Border(bottom: BorderSide(color: _zSlate300, width: 0.9)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: _salesOrderCustomerFlex,
            child: _SalesOrderHeaderText('Sales Order / Customer'),
          ),
          Expanded(
            flex: _salesOrderStatusFlex,
            child: _SalesOrderHeaderText('Order State'),
          ),
          Expanded(
            flex: _salesOrderDispatchFlex,
            child: _SalesOrderHeaderText('Dispatch'),
          ),
          Expanded(
            flex: _salesOrderItemsFlex,
            child: _SalesOrderHeaderText('Items'),
          ),
          Expanded(
            flex: _salesOrderAmountFlex,
            child: _SalesOrderHeaderText('Amount'),
          ),
          Expanded(
            flex: _salesOrderOwnerFlex,
            child: _SalesOrderHeaderText('Created By'),
          ),
          Expanded(
            flex: _salesOrderCreatedFlex,
            child: _SalesOrderHeaderText('Created'),
          ),
          Expanded(
            flex: _salesOrderUpdatedFlex,
            child: _SalesOrderHeaderText('Updated'),
          ),
          Expanded(
            flex: _salesOrderPoFlex,
            child: _SalesOrderHeaderText('Customer PO'),
          ),
          SizedBox(
            width: _salesOrderGridActionWidth,
            child: Center(child: _SalesOrderHeaderText('Actions')),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOrderEmptyState({required bool hasSearchOrFilters}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearchOrFilters
                  ? Icons.search_off_outlined
                  : Icons.receipt_long_outlined,
              size: 42,
              color: _zSlate300,
            ),
            const SizedBox(height: 12),
            Text(
              hasSearchOrFilters
                  ? 'No matching sales orders found'
                  : 'No sales orders found',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _zSlate700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasSearchOrFilters
                  ? 'Try changing the search text or active filters.'
                  : 'Confirmed quotation conversions will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: _zSlate500),
            ),
            if (hasSearchOrFilters) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  _debounce?.cancel();
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _resetFilters();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _zSlate700,
                  side: const BorderSide(color: _zSlate300),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Reset Search & Filters',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalesOrderError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 34, color: Color(0xFF9A5A5A)),
            const SizedBox(height: 10),
            const Text(
              'Unable to load sales orders',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _zSlate800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _zSlate500),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _fetchInitialData,
              style: OutlinedButton.styleFrom(
                foregroundColor: _zSlate700,
                side: const BorderSide(color: _zSlate300),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _salesOrders.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWorkspaceHeader(
              totalOrders: 0,
              formattedRevenue: '₹0',
              confirmedCount: 0,
              dispatchPendingCount: 0,
            ),
            _buildSalesOrderTableHeader(),
            const Expanded(child: _SalesOrderSkeletonList()),
          ],
        ),
      );
    }

    if (_errorMessage != null && _salesOrders.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildSalesOrderError(_errorMessage!),
      );
    }

    final filteredDocs = _getFilteredOrders();
    int totalOrders = filteredDocs.length;
    double totalRevenue = 0;
    int confirmedCount = 0;
    int dispatchPendingCount = 0;

    for (final doc in filteredDocs) {
      final data = doc.data();
      totalRevenue += _parseSafeDouble(
        data['grandTotal'] ?? data['totalAmount'] ?? data['amount'],
      );
      final String status = _parseSafeString(data['status']).toLowerCase();
      final String dispatchStatus = _parseSafeString(
        data['dispatchStatus'],
      ).toLowerCase();

      if (status == 'confirmed') confirmedCount++;
      if (status == 'confirmed' && dispatchStatus != 'delivered') {
        dispatchPendingCount++;
      }
    }

    final String formattedRevenue = NumberFormat.compactCurrency(
      symbol: '₹',
      locale: 'en_IN',
    ).format(totalRevenue);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorkspaceHeader(
            totalOrders: totalOrders,
            formattedRevenue: formattedRevenue,
            confirmedCount: confirmedCount,
            dispatchPendingCount: dispatchPendingCount,
          ),
          _buildActiveFiltersSummary(),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFFFFF8F8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFF9A5A5A)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF7F4D4D)),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchInitialData,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 10.5)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double tableWidth = constraints.maxWidth < _salesOrderGridMinWidth
                    ? _salesOrderGridMinWidth
                    : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSalesOrderTableHeader(),
                        Expanded(
                          child: filteredDocs.isEmpty
                              ? _buildSalesOrderEmptyState(
                            hasSearchOrFilters:
                            _searchQuery.trim().isNotEmpty || _hasActiveFilters,
                          )
                              : RefreshIndicator(
                            onRefresh: _fetchInitialData,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 92),
                              itemCount: filteredDocs.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == filteredDocs.length) {
                                  return const SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _zSlate400,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final doc = filteredDocs[index];
                                final data = doc.data();

                                return _EnterpriseSalesOrderRow(
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
                                    if (poData is Map && poData['url'] != null) {
                                      _viewPO(poData['url'].toString());
                                    }
                                  },
                                  onCreateProformaTap: () => _createProformaInvoice(data),
                                );
                              },
                            ),
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

class _SalesOrderHeaderText extends StatelessWidget {
  final String label;

  const _SalesOrderHeaderText(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(
        fontSize: 10.1,
        fontWeight: FontWeight.w600,
        color: _zSlate600,
        letterSpacing: 0.04,
      ),
    );
  }
}

class _SalesOrderToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _SalesOrderToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: isActive ? _zSlate100 : Colors.white,
          border: Border.all(color: isActive ? _zSlate300 : _zSlate200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? _zSlate700 : _zSlate500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isActive ? _zSlate700 : _zSlate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterpriseSalesOrderKpi extends StatelessWidget {
  final String title;
  final String value;

  const _EnterpriseSalesOrderKpi({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10.2,
            color: _zSlate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _zSlate700,
          ),
        ),
      ],
    );
  }
}

class _SalesOrderSkeletonList extends StatelessWidget {
  const _SalesOrderSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      itemBuilder: (context, index) => _SalesOrderSkeletonRow(index: index),
    );
  }
}

class _SalesOrderSkeletonRow extends StatelessWidget {
  final int index;

  const _SalesOrderSkeletonRow({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: _salesOrderGridHorizontalPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _zSlate100)),
      ),
      child: Row(
        children: [
          Expanded(flex: _salesOrderCustomerFlex, child: _buildDoubleBlock(150, 105)),
          Expanded(flex: _salesOrderStatusFlex, child: _buildDoubleBlock(66, 48)),
          Expanded(flex: _salesOrderDispatchFlex, child: _buildDoubleBlock(72, 54)),
          Expanded(flex: _salesOrderItemsFlex, child: _buildDoubleBlock(100, 58)),
          Expanded(flex: _salesOrderAmountFlex, child: _buildDoubleBlock(78, 42)),
          Expanded(flex: _salesOrderOwnerFlex, child: _buildDoubleBlock(78, 48)),
          Expanded(flex: _salesOrderCreatedFlex, child: _buildBlock(58)),
          Expanded(flex: _salesOrderUpdatedFlex, child: _buildBlock(58)),
          Expanded(flex: _salesOrderPoFlex, child: _buildDoubleBlock(60, 45)),
          const SizedBox(
            width: _salesOrderGridActionWidth,
            child: Icon(Icons.more_vert, size: 15, color: _zSlate200),
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleBlock(double firstWidth, double secondWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBlock(firstWidth),
        const SizedBox(height: 5),
        _buildBlock(secondWidth, height: 7),
      ],
    );
  }

  Widget _buildBlock(double baseWidth, {double height = 9}) {
    final double width = baseWidth * (0.76 + (index % 3) * 0.1);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _zSlate100,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _EnterpriseSalesOrderRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final Future<String> Function(String) nameResolver;
  final VoidCallback onViewTap;
  final VoidCallback onDispatchTap;
  final VoidCallback onApproveTap;
  final VoidCallback onCancelTap;
  final VoidCallback onUploadPOTap;
  final VoidCallback onViewPOTap;
  final VoidCallback onCreateProformaTap;

  const _EnterpriseSalesOrderRow({
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
  State<_EnterpriseSalesOrderRow> createState() => _EnterpriseSalesOrderRowState();
}

class _EnterpriseSalesOrderRowState extends State<_EnterpriseSalesOrderRow> {
  bool _isHovered = false;

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == '-') return fallback;
    return text;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String _dateText(dynamic value) {
    final DateTime? date = _toDate(value);
    return date == null ? '-' : DateFormat('dd/MM/yyyy').format(date);
  }

  String _quantityText(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Color _stateColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'approved':
      case 'completed':
      case 'delivered':
        return const Color(0xFF56745D);
      case 'confirmed':
      case 'shipped':
        return const Color(0xFF557495);
      case 'packed':
        return const Color(0xFF726482);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFF8A4F4F);
      case 'draft':
      case 'pending':
        return const Color(0xFF806B4B);
      default:
        return _zSlate600;
    }
  }

  String _titleCase(String value, {String fallback = '-'}) {
    final String text = value.trim();
    if (text.isEmpty) return fallback;
    return text
        .split(RegExp(r'[\s_]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  Widget _twoLineText({
    required String primary,
    required String secondary,
    Color primaryColor = _zSlate700,
    Color secondaryColor = _zSlate500,
    FontWeight primaryWeight = FontWeight.w500,
    VoidCallback? onPrimaryTap,
  }) {
    final Widget primaryWidget = Text(
      primary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(
        fontSize: 11,
        height: 1.08,
        color: primaryColor,
        fontWeight: primaryWeight,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onPrimaryTap == null)
            primaryWidget
          else
            InkWell(
              onTap: onPrimaryTap,
              borderRadius: BorderRadius.circular(3),
              child: primaryWidget,
            ),
          const SizedBox(height: 3),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 9.8,
              height: 1.05,
              color: secondaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _items(Map<String, dynamic> data) {
    final dynamic raw = data['items'];
    return raw is List ? raw : const <dynamic>[];
  }

  String _firstItemName(List<dynamic> items) {
    if (items.isEmpty) return '-';
    final dynamic first = items.first;
    if (first is Map) {
      return _safeString(
        first['name'] ?? first['itemName'] ?? first['productName'] ?? first['description'],
        fallback: 'Item',
      );
    }
    return _safeString(first, fallback: 'Item');
  }

  double _totalQuantity(List<dynamic> items) {
    double total = 0;
    for (final dynamic item in items) {
      if (item is Map) total += _toDouble(item['quantity'] ?? item['qty']);
    }
    return total;
  }

  String _firstUnit(List<dynamic> items) {
    if (items.isEmpty || items.first is! Map) return '';
    final Map first = items.first as Map;
    return _safeString(first['uom'] ?? first['unit']);
  }

  Widget _buildCreatorCell(String storedName, String uid) {
    if (storedName.isNotEmpty) {
      return _twoLineText(primary: storedName, secondary: 'Order owner');
    }

    return FutureBuilder<String>(
      future: widget.nameResolver(uid),
      builder: (context, snapshot) {
        return _twoLineText(
          primary: snapshot.data ?? 'Loading...',
          secondary: 'Order owner',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = widget.document.data();

    final String soNumber = _safeString(
      data['salesOrderNumber'] ?? data['soNumber'] ?? data['orderNumber'],
      fallback: 'Draft SO',
    );
    final String customerName = _safeString(
      data['customerName'] ?? data['clientName'] ?? data['partyName'] ?? data['customer'],
      fallback: 'Unknown Customer',
    );
    final String quotationRef = _safeString(
      data['referenceQuotationNumber'] ??
          data['quotationNumber'] ??
          data['quoteNumber'] ??
          data['referenceQuotationId'] ??
          data['quotationId'],
      fallback: 'Direct order',
    );

    final String status = _safeString(data['status'], fallback: 'draft').toLowerCase();
    final String approvalStatus = _safeString(
      data['approvalStatus'],
      fallback: 'pending',
    ).toLowerCase();
    final String dispatchStatus = _safeString(
      data['dispatchStatus'],
      fallback: 'pending',
    ).toLowerCase();

    final String transporter = _safeString(data['transporterName']);
    final String vehicle = _safeString(data['vehicleNumber']);
    final String dispatchDetail = transporter.isNotEmpty
        ? transporter
        : vehicle.isNotEmpty
        ? vehicle
        : dispatchStatus == 'pending'
        ? 'Awaiting dispatch'
        : 'Logistics not entered';

    final List<dynamic> items = _items(data);
    final String firstItem = _firstItemName(items);
    final double totalQty = _totalQuantity(items);
    final String unit = _firstUnit(items);
    final String itemSummary = items.isEmpty
        ? 'No items'
        : '$firstItem${items.length > 1 ? ' +${items.length - 1}' : ''}';
    final String quantitySummary = items.isEmpty
        ? '-'
        : 'Qty ${_quantityText(totalQty)}${unit.isEmpty ? '' : ' $unit'}';

    final double grandTotal = _toDouble(
      data['grandTotal'] ?? data['totalAmount'] ?? data['amount'],
    );
    final String formattedAmount = NumberFormat.currency(
      symbol: '₹',
      locale: 'en_IN',
      decimalDigits: grandTotal.truncateToDouble() == grandTotal ? 0 : 2,
    ).format(grandTotal);

    final String createdDate = _dateText(data['date'] ?? data['createdAt'] ?? data['soDate']);
    final String updatedDate = _dateText(data['updatedAt']);
    final String createdByUid = _safeString(data['createdBy']);
    final String storedCreatorName = _safeString(data['createdByName']);

    final Map<String, dynamic>? poData = data['purchaseOrder'] is Map
        ? Map<String, dynamic>.from(data['purchaseOrder'] as Map)
        : null;
    final bool hasPO = poData != null && _safeString(poData['url']).isNotEmpty;
    final String poFileName = hasPO
        ? _safeString(poData['fileName'], fallback: 'Attachment available')
        : 'Not uploaded';

    final bool canCancel = status != 'completed' &&
        dispatchStatus != 'shipped' &&
        dispatchStatus != 'delivered' &&
        status != 'cancelled';
    final bool canDispatch = approvalStatus == 'approved' && status == 'confirmed';
    final bool canApprove = status != 'cancelled' &&
        status != 'completed' &&
        approvalStatus != 'approved' &&
        approvalStatus != 'rejected';

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: _salesOrderGridHorizontalPadding),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFFBFCFE) : Colors.white,
            border: Border(
              bottom: const BorderSide(color: _zSlate100),
              left: BorderSide(
                color: _isHovered ? _zSoftHoverBorder : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: _salesOrderCustomerFlex,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: InkWell(
                              onTap: widget.onViewTap,
                              borderRadius: BorderRadius.circular(3),
                              child: Text(
                                soNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.8,
                                  height: 1.08,
                                  fontWeight: FontWeight.w700,
                                  color: _zErpPrimaryBlue,
                                ),
                              ),
                            ),
                          ),
                          if (hasPO) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.attachment_rounded, size: 12, color: _zInquiryBlue),
                          ],
                          const SizedBox(width: 7),
                          Expanded(
                            flex: 5,
                            child: InkWell(
                              onTap: widget.onViewTap,
                              borderRadius: BorderRadius.circular(3),
                              child: Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.08,
                                  fontWeight: FontWeight.w600,
                                  color: _zSlate800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        quotationRef == 'Direct order' ? quotationRef : 'Quotation: $quotationRef',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.8,
                          height: 1.05,
                          color: _zSlate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: _salesOrderStatusFlex,
                child: _twoLineText(
                  primary: _titleCase(status),
                  secondary: 'Approval: ${_titleCase(approvalStatus)}',
                  primaryColor: _stateColor(status),
                  secondaryColor: _stateColor(approvalStatus),
                  primaryWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                flex: _salesOrderDispatchFlex,
                child: _twoLineText(
                  primary: _titleCase(dispatchStatus),
                  secondary: dispatchDetail,
                  primaryColor: _stateColor(dispatchStatus),
                  primaryWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                flex: _salesOrderItemsFlex,
                child: _twoLineText(primary: itemSummary, secondary: quantitySummary),
              ),
              Expanded(
                flex: _salesOrderAmountFlex,
                child: _twoLineText(
                  primary: formattedAmount,
                  secondary: '${items.length} item${items.length == 1 ? '' : 's'}',
                  primaryColor: _zSlate800,
                  primaryWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                flex: _salesOrderOwnerFlex,
                child: _buildCreatorCell(storedCreatorName, createdByUid),
              ),
              Expanded(
                flex: _salesOrderCreatedFlex,
                child: Text(
                  createdDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.7, color: _zSlate600, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: _salesOrderUpdatedFlex,
                child: Text(
                  updatedDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.7, color: _zSlate600, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: _salesOrderPoFlex,
                child: InkWell(
                  onTap: hasPO ? widget.onViewPOTap : widget.onUploadPOTap,
                  borderRadius: BorderRadius.circular(3),
                  child: _twoLineText(
                    primary: hasPO ? 'Attached' : 'Missing',
                    secondary: poFileName,
                    primaryColor: hasPO ? const Color(0xFF557495) : const Color(0xFF806B4B),
                    primaryWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: _salesOrderGridActionWidth,
                child: Center(
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Actions',
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: _isHovered ? _zSlate600 : _zSlate400.withValues(alpha: 0.62),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: _zSlate200),
                    ),
                    onSelected: (value) {
                      if (value == 'view') widget.onViewTap();
                      if (value == 'dispatch') widget.onDispatchTap();
                      if (value == 'approve') widget.onApproveTap();
                      if (value == 'cancel') widget.onCancelTap();
                      if (value == 'view_po') widget.onViewPOTap();
                      if (value == 'upload_po') widget.onUploadPOTap();
                      if (value == 'create_proforma') widget.onCreateProformaTap();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        height: 32,
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 14, color: _zSlate600),
                            SizedBox(width: 8),
                            Text('View Sales Order', style: TextStyle(fontSize: 11.5, color: _zSlate700)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      if (hasPO)
                        const PopupMenuItem(
                          value: 'view_po',
                          height: 32,
                          child: Row(
                            children: [
                              Icon(Icons.attach_file_rounded, size: 14, color: _zInquiryBlue),
                              SizedBox(width: 8),
                              Text('View Customer PO', style: TextStyle(fontSize: 11.5, color: _zSlate700)),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'upload_po',
                        height: 32,
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file_outlined, size: 14, color: _zSlate600),
                            const SizedBox(width: 8),
                            Text(
                              hasPO ? 'Replace Customer PO' : 'Upload Customer PO',
                              style: const TextStyle(fontSize: 11.5, color: _zSlate700),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      const PopupMenuItem(
                        value: 'create_proforma',
                        height: 32,
                        child: Row(
                          children: [
                            Icon(Icons.request_quote_outlined, size: 14, color: _zSlate600),
                            SizedBox(width: 8),
                            Text('Create Proforma Invoice', style: TextStyle(fontSize: 11.5, color: _zSlate700)),
                          ],
                        ),
                      ),
                      if (canApprove || canDispatch || canCancel)
                        const PopupMenuDivider(height: 8),
                      if (canApprove)
                        const PopupMenuItem(
                          value: 'approve',
                          height: 32,
                          child: Row(
                            children: [
                              Icon(Icons.verified_outlined, size: 14, color: _zSlate600),
                              SizedBox(width: 8),
                              Text('Approve / Reject', style: TextStyle(fontSize: 11.5, color: _zSlate700)),
                            ],
                          ),
                        ),
                      if (canDispatch)
                        const PopupMenuItem(
                          value: 'dispatch',
                          height: 32,
                          child: Row(
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 14, color: _zSlate600),
                              SizedBox(width: 8),
                              Text('Update Dispatch', style: TextStyle(fontSize: 11.5, color: _zSlate700)),
                            ],
                          ),
                        ),
                      if (canCancel)
                        const PopupMenuItem(
                          value: 'cancel',
                          height: 32,
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, size: 14, color: Color(0xFF8A4F4F)),
                              SizedBox(width: 8),
                              Text('Cancel Order', style: TextStyle(fontSize: 11.5, color: Color(0xFF8A4F4F))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
